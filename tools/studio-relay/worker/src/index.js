// Studio Relay: a tiny mailbox between a cloud agent and the "Studio Relay" plugin in Roblox Studio.
// Neither side accepts incoming connections, so both poll this Worker. One Durable Object ("main")
// keeps the command queues, results and logs in memory; plugin tokens and pairing live in its storage.
//
// Agent side (Authorization: Bearer <AGENT_TOKEN secret>):
//   GET  /agent/status                         -> which Studio DataModels polled recently
//   POST /agent/pair?code=123456               -> confirm a pairing code shown in the plugin
//   POST /agent/revoke                         -> forget every paired plugin
//   POST /agent/cmd?target=edit&kind=run&timeout=60   body = payload (raw text) -> {id}
//   GET  /agent/result?id=..&wait=25           -> 200 raw result body (headers X-Ok, X-Kind) | 202 pending
//   GET  /agent/logs?target=edit&since=0       -> {seq, logs:[{seq,t,type,msg}]}
// Plugin side (Authorization: Bearer <plugin token> except pairing):
//   POST /plugin/pair/start                    -> {pairId, code}
//   GET  /plugin/pair/poll?pairId=..           -> {status:"pending"|"ok"|"expired", token?}
//   GET  /plugin/next?targets=edit&wait=20&...  -> 200 raw payload (headers X-Id, X-Kind, X-Timeout) | 204
//   POST /plugin/result?id=..&ok=1             body = raw result
//   POST /plugin/logs?target=edit              body = JSON [{t,type,msg}]
//   POST /plugin/unpair
//   GET  /plugin/code                          -> newest plugin build offered by the agent (X-Build) | 204
//   POST /agent/code?build=N                   body = plugin source (offered, applied only by the owner)

const MAX_WAIT = 25; // seconds a long-poll may hold the request
const RESULT_TTL = 60 * 60 * 1000;
const PAIR_TTL = 10 * 60 * 1000;
const LOG_KEEP = 3000;

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		if (url.pathname === "/" || url.pathname === "/health") {
			return new Response("studio-relay ok\n");
		}
		const id = env.RELAY.idFromName("main");
		return env.RELAY.get(id).fetch(request);
	},
};

function json(obj, status = 200) {
	return new Response(JSON.stringify(obj), {
		status,
		headers: { "content-type": "application/json" },
	});
}

function bearer(request) {
	const h = request.headers.get("authorization") || "";
	const m = h.match(/^Bearer\s+(.+)$/i);
	return m ? m[1].trim() : "";
}

function safeEqual(a, b) {
	if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length || a.length === 0) return false;
	let diff = 0;
	for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
	return diff === 0;
}

async function sha256(text) {
	const data = new TextEncoder().encode(text);
	const hash = await crypto.subtle.digest("SHA-256", data);
	return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomToken(bytes = 24) {
	const a = new Uint8Array(bytes);
	crypto.getRandomValues(a);
	return [...a].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Roblox HttpService may gzip large bodies (Compress = Gzip); accept both plain and gzipped text.
async function readText(request) {
	const buf = new Uint8Array(await request.arrayBuffer());
	if (buf.length >= 2 && buf[0] === 0x1f && buf[1] === 0x8b) {
		const stream = new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"));
		return await new Response(stream).text();
	}
	return new TextDecoder().decode(buf);
}

function clampWait(v, def) {
	const n = Number(v);
	if (!Number.isFinite(n)) return def;
	return Math.max(0, Math.min(MAX_WAIT, n));
}

export class Relay {
	constructor(ctx, env) {
		this.ctx = ctx;
		this.env = env;
		this.queue = []; // {id, target, kind, timeout, payload, created}
		this.inflight = new Map(); // id -> cmd (taken by a plugin, no result yet)
		this.results = new Map(); // id -> {ok, kind, body, at}
		this.cmdWaiters = []; // {targets:Set, resolve}
		this.resultWaiters = new Map(); // id -> [resolve]
		this.pairWaiters = new Map(); // pairId -> [resolve]
		this.logs = new Map(); // target -> [{seq,t,type,msg}]
		this.logSeq = 0;
		this.seen = new Map(); // target -> {at, place, placeId, user, version}
		this.counter = 0;
	}

	async fetch(request) {
		const url = new URL(request.url);
		const p = url.pathname;
		try {
			if (p.startsWith("/agent/")) {
				if (!safeEqual(bearer(request), this.env.AGENT_TOKEN || "")) return json({ error: "unauthorized" }, 401);
				return await this.agent(p, url, request);
			}
			if (p === "/plugin/pair/start") return await this.pairStart();
			if (p === "/plugin/pair/poll") return await this.pairPoll(url);
			if (p.startsWith("/plugin/")) {
				const tok = bearer(request);
				if (!tok || !(await this.ctx.storage.get("ptok:" + (await sha256(tok))))) {
					return json({ error: "unauthorized" }, 401);
				}
				return await this.plugin(p, url, request, tok);
			}
			return json({ error: "not found" }, 404);
		} catch (e) {
			return json({ error: String(e && e.stack ? e.stack : e) }, 500);
		}
	}

	// ---------- agent ----------
	async agent(p, url, request) {
		this.prune();
		if (p === "/agent/status") {
			const now = Date.now();
			const dms = {};
			for (const [t, s] of this.seen) dms[t] = { ...s, agoSec: Math.round((now - s.at) / 1000) };
			const paired = (await this.ctx.storage.list({ prefix: "ptok:" })).size;
			return json({
				paired,
				datamodels: dms,
				queued: this.queue.map((c) => ({ id: c.id, target: c.target, kind: c.kind })),
				inflight: [...this.inflight.values()].map((c) => ({ id: c.id, target: c.target, kind: c.kind })),
			});
		}
		if (p === "/agent/pair") {
			const code = (url.searchParams.get("code") || "").replace(/\D/g, "");
			const pairs = await this.ctx.storage.list({ prefix: "pair:" });
			for (const [key, rec] of pairs) {
				if (Date.now() - rec.created > PAIR_TTL) {
					await this.ctx.storage.delete(key);
					continue;
				}
				if (rec.code === code && !rec.token) {
					const token = randomToken();
					await this.ctx.storage.put("ptok:" + (await sha256(token)), { created: Date.now() });
					rec.token = token;
					await this.ctx.storage.put(key, rec);
					const pairId = key.slice(5);
					for (const r of this.pairWaiters.get(pairId) || []) r();
					this.pairWaiters.delete(pairId);
					return json({ ok: true });
				}
			}
			return json({ ok: false, error: "code not found or expired" }, 404);
		}
		if (p === "/agent/code" && request.method === "POST") {
			// a newer plugin build; the plugin only OFFERS it, the owner applies it with a button
			const build = Number(url.searchParams.get("build"));
			if (!Number.isInteger(build) || build < 1) return json({ error: "build required" }, 400);
			const source = await readText(request);
			await this.ctx.storage.put("code", { build, source, at: Date.now() });
			return json({ ok: true, build, bytes: source.length });
		}
		if (p === "/agent/asset" && request.method === "POST") {
			// auxiliary plugin data (e.g. the bitmap font) for builds applied through «Обновить»
			const name = (url.searchParams.get("name") || "").replace(/[^a-z0-9_-]/gi, "");
			if (!name) return json({ error: "name required" }, 400);
			const text = await readText(request);
			const parts = Math.ceil(text.length / 900000) || 1;
			for (let i = 0; i < parts; i++) await this.ctx.storage.put(`asset:${name}:${i}`, text.slice(i * 900000, (i + 1) * 900000));
			await this.ctx.storage.put(`asset:${name}`, { parts, bytes: text.length });
			return json({ ok: true, name, bytes: text.length });
		}
		if (p === "/agent/revoke") {
			const toks = await this.ctx.storage.list({ prefix: "ptok:" });
			await this.ctx.storage.delete([...toks.keys()]);
			return json({ ok: true, revoked: toks.size });
		}
		if (p === "/agent/cmd" && request.method === "POST") {
			const target = url.searchParams.get("target") || "edit";
			const kind = url.searchParams.get("kind") || "run";
			const timeout = Math.max(1, Math.min(600, Number(url.searchParams.get("timeout")) || 60));
			const payload = await readText(request);
			const id = Date.now().toString(36) + "-" + (++this.counter).toString(36) + "-" + randomToken(3);
			const cmd = { id, target, kind, timeout, payload, created: Date.now() };
			this.queue.push(cmd);
			this.wakeCommand(cmd);
			return json({ id });
		}
		if (p === "/agent/result") {
			const id = url.searchParams.get("id") || "";
			const wait = clampWait(url.searchParams.get("wait"), 20);
			let res = this.results.get(id);
			if (!res && wait > 0) {
				await this.waitFor(this.resultWaiters, id, wait);
				res = this.results.get(id);
			}
			if (!res) {
				const state = this.inflight.has(id) ? "running" : this.queue.some((c) => c.id === id) ? "queued" : "unknown";
				return json({ pending: true, state }, 202);
			}
			return new Response(res.body, {
				headers: { "x-ok": res.ok ? "1" : "0", "x-kind": res.kind, "content-type": "text/plain; charset=utf-8" },
			});
		}
		if (p === "/agent/cancel") {
			const id = url.searchParams.get("id") || "";
			this.queue = this.queue.filter((c) => c.id !== id);
			return json({ ok: true });
		}
		if (p === "/agent/logs") {
			const target = url.searchParams.get("target") || "";
			const since = Number(url.searchParams.get("since")) || 0;
			const out = [];
			for (const [t, arr] of this.logs) {
				if (target && t !== target) continue;
				for (const l of arr) if (l.seq > since) out.push({ ...l, target: t });
			}
			out.sort((a, b) => a.seq - b.seq);
			return json({ seq: this.logSeq, logs: out });
		}
		return json({ error: "not found" }, 404);
	}

	// ---------- plugin ----------
	async pairStart() {
		const pairId = randomToken(12);
		const code = String(100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000));
		await this.ctx.storage.put("pair:" + pairId, { code, created: Date.now() });
		return json({ pairId, code });
	}

	async pairPoll(url) {
		const pairId = url.searchParams.get("pairId") || "";
		const key = "pair:" + pairId;
		let rec = await this.ctx.storage.get(key);
		if (!rec || Date.now() - rec.created > PAIR_TTL) return json({ status: "expired" });
		if (!rec.token) {
			await this.waitFor(this.pairWaiters, pairId, 20);
			rec = await this.ctx.storage.get(key);
		}
		if (rec && rec.token) {
			await this.ctx.storage.delete(key);
			return json({ status: "ok", token: rec.token });
		}
		return json({ status: "pending" });
	}

	async plugin(p, url, request, tok) {
		if (p === "/plugin/next") {
			const targets = new Set((url.searchParams.get("targets") || "edit").split(",").filter(Boolean));
			const info = {
				at: Date.now(),
				place: url.searchParams.get("place") || "",
				placeId: url.searchParams.get("placeId") || "",
				user: url.searchParams.get("user") || "",
				version: url.searchParams.get("v") || "",
			};
			for (const t of targets) this.seen.set(t, info);
			const wait = clampWait(url.searchParams.get("wait"), 20);
			let cmd = this.take(targets);
			if (!cmd && wait > 0) {
				await new Promise((resolve) => {
					const w = { targets, resolve };
					this.cmdWaiters.push(w);
					setTimeout(() => {
						this.cmdWaiters = this.cmdWaiters.filter((x) => x !== w);
						resolve();
					}, wait * 1000);
				});
				for (const t of targets) this.seen.set(t, { ...info, at: Date.now() });
				cmd = this.take(targets);
			}
			if (!cmd) return new Response(null, { status: 204 });
			this.inflight.set(cmd.id, cmd);
			return new Response(cmd.payload, {
				headers: {
					"x-id": cmd.id,
					"x-kind": cmd.kind,
					"x-target": cmd.target,
					"x-timeout": String(cmd.timeout),
					"content-type": "text/plain; charset=utf-8",
				},
			});
		}
		if (p === "/plugin/result" && request.method === "POST") {
			const id = url.searchParams.get("id") || "";
			const cmd = this.inflight.get(id);
			this.inflight.delete(id);
			const body = await readText(request);
			this.results.set(id, {
				ok: url.searchParams.get("ok") === "1",
				kind: cmd ? cmd.kind : url.searchParams.get("kind") || "",
				body,
				at: Date.now(),
			});
			for (const r of this.resultWaiters.get(id) || []) r();
			this.resultWaiters.delete(id);
			return json({ ok: true });
		}
		if (p === "/plugin/logs" && request.method === "POST") {
			const target = url.searchParams.get("target") || "edit";
			let items = [];
			try {
				items = JSON.parse(await readText(request));
			} catch {
				return json({ error: "bad json" }, 400);
			}
			const arr = this.logs.get(target) || [];
			for (const it of Array.isArray(items) ? items : []) {
				arr.push({ seq: ++this.logSeq, t: Number(it.t) || 0, type: String(it.type || ""), msg: String(it.msg || "").slice(0, 4000) });
			}
			if (arr.length > LOG_KEEP) arr.splice(0, arr.length - LOG_KEEP);
			this.logs.set(target, arr);
			return json({ ok: true, seq: this.logSeq });
		}
		if (p === "/plugin/code") {
			const rec = await this.ctx.storage.get("code");
			if (!rec) return new Response(null, { status: 204 });
			return new Response(rec.source, {
				headers: { "x-build": String(rec.build), "content-type": "text/plain; charset=utf-8" },
			});
		}
		if (p === "/plugin/asset") {
			const name = (url.searchParams.get("name") || "").replace(/[^a-z0-9_-]/gi, "");
			const meta = await this.ctx.storage.get(`asset:${name}`);
			if (!meta) return new Response(null, { status: 404 });
			let text = "";
			for (let i = 0; i < meta.parts; i++) text += (await this.ctx.storage.get(`asset:${name}:${i}`)) || "";
			return new Response(text, { headers: { "content-type": "text/plain; charset=utf-8" } });
		}
		if (p === "/plugin/unpair" && request.method === "POST") {
			await this.ctx.storage.delete("ptok:" + (await sha256(tok)));
			return json({ ok: true });
		}
		return json({ error: "not found" }, 404);
	}

	// ---------- helpers ----------
	take(targets) {
		const i = this.queue.findIndex((c) => targets.has(c.target));
		if (i < 0) return null;
		return this.queue.splice(i, 1)[0];
	}

	wakeCommand(cmd) {
		const i = this.cmdWaiters.findIndex((w) => w.targets.has(cmd.target));
		if (i >= 0) {
			const w = this.cmdWaiters.splice(i, 1)[0];
			w.resolve();
		}
	}

	waitFor(map, key, seconds) {
		return new Promise((resolve) => {
			const list = map.get(key) || [];
			list.push(resolve);
			map.set(key, list);
			setTimeout(resolve, seconds * 1000);
		});
	}

	prune() {
		const now = Date.now();
		for (const [id, r] of this.results) if (now - r.at > RESULT_TTL) this.results.delete(id);
		for (const [id, c] of this.inflight) if (now - c.created > (c.timeout + 120) * 1000) this.inflight.delete(id);
		this.queue = this.queue.filter((c) => now - c.created < 30 * 60 * 1000);
	}
}
