// Creates the donate shop's Developer Products in the owner's experience and writes their ids into
// scripts/design-decisions.json (donate.packs[].productId, donate.items.<id>.productId), then rebuilds the configs.
// [владелец 28.10: «дай мне четкую инструкцию … хочу, чтобы игрок мог покупать сами предметы. Даже за 10 роблакс»]
//
// The OWNER runs it with their own Open Cloud API key (Creator Dashboard → Open Cloud → API Keys, API system
// «Developer Products», read + write, scoped to this experience). The key is read from the environment and never
// printed or saved:
//   PowerShell:  $env:ROBLOX_API_KEY = "<key>";  node scripts/create-dev-products.mjs
//   --dry        show what would be created / changed, touch nothing
//   --universe N another experience (default: the game's universe 10772144679, place 92594200898716)
//
// Safe to run again: products are matched by the id already in the config, else by name; a missing one is created
// (name, description, price, icon from assets/icons), an existing one with another name or price gets them from the
// config (the crystal packs were renamed and repriced 28.10 to match the Robux packages); ids already written stay.
// Roblox cannot delete Developer Products — a wrong one can only be renamed or taken off sale in the Dashboard.
// API: Open Cloud developer products v2 (multipart/form-data: name, description, price, isForSale, imageFile;
// write limit 3 requests a second).
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const decisionsFile = join(root, "scripts", "design-decisions.json");
const args = process.argv.slice(2);
const dry = args.includes("--dry");
const universeArg = args.indexOf("--universe");
const universe = universeArg >= 0 ? args[universeArg + 1] : "10772144679";
const key = process.env.ROBLOX_API_KEY;
const base = `https://apis.roblox.com/developer-products/v2/universes/${universe}/developer-products`;

if (!key && !dry) {
	console.error('No key. PowerShell: $env:ROBLOX_API_KEY = "<key>"; node scripts/create-dev-products.mjs');
	process.exit(1);
}

const raw = readFileSync(decisionsFile, "utf8");
const newline = raw.includes("\r\n") ? "\r\n" : "\n";
const decisions = JSON.parse(raw);
const donate = decisions.donate;

function save() {
	writeFileSync(decisionsFile, JSON.stringify(decisions, null, 2).replace(/\n/g, newline) + newline);
}

function iconFile(icon) {
	for (const dir of ["assets/icons/items3d", "assets/icons/boosters", "assets/icons/items"]) {
		const file = join(root, dir, `${icon}.png`);
		if (existsSync(file)) return file;
	}
	return null;
}

// everything the shop sells for Robux: the crystal packs and every item (one piece)
const goods = [
	...donate.packs.map((pack) => ({
		entry: pack,
		name: pack.productName,
		price: pack.robux,
		description: `Донат-магазин: ${pack.crystals} кристаллов — валюта магазина.`,
		icon: pack.icon,
	})),
	...Object.entries(donate.items).map(([id, item]) => ({
		entry: item,
		name: item.productName,
		price: item.robux,
		description: `Донат-магазин: ${item.productName}, 1 шт.`,
		icon: item.icon ?? item.give ?? id,
	})),
];

async function api(url, init = {}) {
	const res = await fetch(url, { ...init, headers: { "x-api-key": key, ...(init.headers ?? {}) } });
	const text = await res.text();
	let body = null;
	try {
		body = text ? JSON.parse(text) : null;
	} catch {
		body = text;
	}
	if (!res.ok) throw new Error(`HTTP ${res.status}: ${typeof body === "string" ? body : JSON.stringify(body)}`);
	return body;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const idOf = (p) => Number(p.productId ?? p.developerProductId ?? p.id ?? 0);
const priceOf = (p) =>
	Number(p.price ?? p.priceInRobux ?? p.priceInformation?.defaultPriceInRobux ?? p.priceConfiguration?.priceInRobux ?? NaN);

// the products the experience already has, by name (and by id under "#<id>")
async function existing() {
	const byName = new Map();
	let token = "";
	do {
		const page = await api(`${base}/creator?pageSize=100${token ? `&pageToken=${encodeURIComponent(token)}` : ""}`);
		const list = Array.isArray(page) ? page : Object.values(page ?? {}).find(Array.isArray) ?? [];
		for (const p of list) {
			if (p?.name) byName.set(p.name, p);
			if (idOf(p)) byName.set(`#${idOf(p)}`, p);
		}
		token = page?.nextPageToken ?? "";
	} while (token);
	return byName;
}

function form(good, withIcon) {
	const f = new FormData();
	f.append("name", good.name);
	f.append("description", good.description);
	f.append("price", String(good.price));
	f.append("isForSale", "true");
	const file = withIcon ? iconFile(good.icon) : null;
	if (file) f.append("imageFile", new Blob([readFileSync(file)], { type: "image/png" }), basename(file));
	return f;
}

const have = dry && !key ? new Map() : await existing();
let created = 0;
let repriced = 0;
let kept = 0;
for (const good of goods) {
	if (!good.name || !(good.price >= 1)) {
		console.warn(`skip: no name or price < 1 R$ — ${JSON.stringify(good.entry)}`);
		continue;
	}
	const found = (good.entry.productId && have.get(`#${good.entry.productId}`)) || have.get(good.name);
	if (!found) {
		console.log(`${dry ? "would create" : "create"}: ${good.name} — ${good.price} R$ (icon ${iconFile(good.icon) ? good.icon : "none"})`);
		if (dry) continue;
		// a 5xx / 429 may still have created it (the 504 «upstream request timeout» of 28.10): look it up by name
		// before trying again, so no product is made twice
		let made = null;
		for (let attempt = 1; !made; attempt++) {
			try {
				made = await api(base, { method: "POST", body: form(good, true) });
			} catch (err) {
				const status = Number(/^HTTP (\d+)/.exec(err.message)?.[1] ?? 0);
				if (attempt >= 4 || !(status >= 500 || status === 429)) throw err;
				console.log(`  ${err.message.slice(0, 80)} — retry ${attempt} in ${attempt * 5} s`);
				await sleep(attempt * 5000);
				made = (await existing()).get(good.name) ?? null;
			}
		}
		good.entry.productId = idOf(made);
		if (!good.entry.productId) throw new Error(`no product id in the answer: ${JSON.stringify(made)}`);
		save(); // after every product: a stop half-way keeps the ids made so far
		created += 1;
		await sleep(400);
		continue;
	}
	good.entry.productId = idOf(found);
	if (priceOf(found) !== good.price || found.name !== good.name) {
		console.log(`${dry ? "would update" : "update"}: ${found.name} ${priceOf(found)} R$ → ${good.name} ${good.price} R$`);
		if (!dry) {
			const f = new FormData();
			if (found.name !== good.name) {
				f.append("name", good.name);
				f.append("description", good.description);
			}
			f.append("price", String(good.price));
			f.append("isForSale", "true");
			await api(`${base}/${good.entry.productId}`, { method: "PATCH", body: f });
			repriced += 1;
			await sleep(400);
		}
	} else {
		kept += 1;
	}
}

if (dry) {
	console.log(`dry run: ${goods.length} goods, nothing changed`);
} else {
	save();
	execFileSync(process.execPath, [join(root, "scripts", "build-configs.mjs")], { cwd: root, stdio: "ignore" });
	console.log(`done: ${created} created, ${repriced} repriced, ${kept} unchanged; ids written to design-decisions.json, configs rebuilt`);
}
