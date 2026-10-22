// Two-view silhouette INFLATION into voxels [владелец 22.10: «у тебя модели плоские, когда разворачиваешь; рука
// по краям на квадратик меньше, где-то ещё меньше — нужна логика»]. The idea of Teddy (Igarashi et al.,
// SIGGRAPH 1999) and Puffball (Twarog et al., MIT): a 2D silhouette inflates into a rounded volume — fat where it
// is wide, thin where it is narrow, round at the edges. Here per body part and from BOTH views of the sheet:
//   - the front view inflates the part in depth: at a front cell the half-depth is R_y · circle(d / R), d = the
//     cell's distance to the part's edge in the front view, R = the part's half-width there;
//   - the side view inflates it in width the same way;
//   - a voxel stays when it is inside both inflated silhouettes, so limbs taper in steps towards their ends and
//     edges, bellies and heads are round, and the front and side silhouettes still match the sheet.
// Colours: the front-most voxel of a column takes the front pixel, the outermost voxels on the sides the side
// pixel, the rest the front pixel; a 12–16 colour k-means palette; glowing cells (lava / pus) stay Neon.
// Usage: node scripts/model-tools/inflate.cjs assets/models/<id>/inflate.json → <dir>/voxels.json (Blender space:
// X = (front.centreX − x) / S, Y = (side.centreX − x) / S, Z = (groundY − y) / S).
const fs = require("fs");
const path = require("path");
const sharp = require(process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp"));

const cfgPath = process.argv[2];
const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
const dir = path.dirname(cfgPath);
const C = cfg.cell, S = cfg.scale, bg = cfg.background, tol = cfg.tolerance;
const lum = (c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
const isGlow = (m) =>
	cfg.glowRule === "pus" ? m[1] > 195 && m[0] > 160 && m[2] < 130 : (m[0] > 225 && m[1] > 160) || (m[0] > 150 && m[0] - m[2] > 90);
const glowColour = (m) => (lum(m) >= 200 ? cfg.glow.hot : m[1] >= 140 ? cfg.glow.bright : m[0] >= 200 ? cfg.glow.warm : cfg.glow.deep);

(async () => {
	const { data, info } = await sharp(path.join(dir, cfg.reference)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
	const W = info.width;
	const px = (x, y) => {
		const i = (y * W + x) * 3;
		return [data[i], data[i + 1], data[i + 2]];
	};
	const isFg = (q) => Math.abs(q[0] - bg[0]) + Math.abs(q[1] - bg[1]) + Math.abs(q[2] - bg[2]) > tol;

	// palette (k-means over both views)
	const samples = [];
	for (const rect of [cfg.front.rect, cfg.side.rect])
		for (let y = rect[1]; y < rect[3]; y += 3)
			for (let x = rect[0]; x < rect[2]; x += 3) {
				const q = px(x, y);
				if (isFg(q) && !isGlow(q)) samples.push(q);
			}
	samples.sort((a, b) => lum(a) - lum(b));
	const K = cfg.palette || 12;
	let centres = Array.from({ length: K }, (_, k) => samples[Math.floor(((k + 0.5) / K) * samples.length)].slice());
	for (let it = 0; it < 12; it++) {
		const sums = centres.map(() => [0, 0, 0, 0]);
		for (const q of samples) {
			let best = 0, bd = Infinity;
			centres.forEach((c, k) => {
				const d = (c[0] - q[0]) ** 2 + (c[1] - q[1]) ** 2 + (c[2] - q[2]) ** 2;
				if (d < bd) (bd = d), (best = k);
			});
			const t = sums[best];
			(t[0] += q[0]), (t[1] += q[1]), (t[2] += q[2]), t[3]++;
		}
		centres = centres.map((c, k) => (sums[k][3] ? sums[k].slice(0, 3).map((v) => Math.round(v / sums[k][3])) : c));
	}
	const tone = (m) => {
		let best = centres[0], bd = Infinity;
		for (const c of centres) {
			const d = (c[0] - m[0]) ** 2 + (c[1] - m[1]) ** 2 + (c[2] - m[2]) ** 2;
			if (d < bd) (bd = d), (best = c);
		}
		return best;
	};

	// cell grids of a view: {mask, colour, glow, joints}
	function grid(view, key) {
		const [x0, y0, x1, y1] = view.rect;
		const cols = Math.floor((x1 - x0) / C), rows = Math.floor((y1 - y0) / C);
		const g = [];
		for (let r = 0; r < rows; r++) {
			const row = [];
			for (let c = 0; c < cols; c++) {
				const list = [];
				let n = 0;
				for (let y = y0 + r * C; y < y0 + (r + 1) * C; y++)
					for (let x = x0 + c * C; x < x0 + (c + 1) * C; x++) {
						n++;
						const q = px(x, y);
						if (isFg(q)) list.push(q);
					}
				if (list.length < n * 0.5) {
					row.push(null);
					continue;
				}
				list.sort((a, b) => lum(a) - lum(b));
				let m = list[Math.floor(list.length / 2)];
				const bright = list[Math.floor(list.length * 0.8)];
				if (!isGlow(m) && isGlow(bright) && cfg.thinGlow) m = bright; // thin cracks / drips survive
				const glow = isGlow(m);
				const sx = x0 + (c + 0.5) * C, sy = y0 + (r + 0.5) * C;
				const reg = view.regions.find((q) => sx >= q.rect[0] && sx < q.rect[2] && sy >= q.rect[1] && sy < q.rect[3]);
				if (!reg) {
					row.push(null);
					continue;
				}
				row.push({ colour: glow ? glowColour(m) : tone(m), glow, joints: reg[key] });
			}
			g.push(row);
		}
		return { g, cols, rows, x0, y0 };
	}
	const F = grid(cfg.front, "joints");
	const Sd = grid(cfg.side, "joints");

	// chamfer distance (cells) to the nearest cell outside the joint's mask
	function distance(G, joint) {
		const { rows, cols } = G;
		const d = [];
		for (let r = 0; r < rows; r++) d.push(G.g[r].map((cell) => (cell && cell.joints.includes(joint) ? 1e9 : 0)));
		const pass = (rs, cs, nb) => {
			for (const r of rs)
				for (const c of cs) {
					if (!d[r][c]) continue;
					let v = d[r][c];
					for (const [dr, dc, w] of nb) {
						const rr = r + dr, cc = c + dc;
						const o = rr < 0 || cc < 0 || rr >= rows || cc >= cols ? 0 : d[rr][cc];
						v = Math.min(v, o + w);
					}
					d[r][c] = v;
				}
		};
		const R = [...Array(rows).keys()], Cs = [...Array(cols).keys()];
		pass(R, Cs, [[-1, -1, 1.4], [-1, 0, 1], [-1, 1, 1.4], [0, -1, 1]]);
		pass(R.reverse(), Cs.reverse(), [[1, 1, 1.4], [1, 0, 1], [1, -1, 1.4], [0, 1, 1]]);
		return d;
	}
	// circle profile: 0 at the edge, 1 from the radius inwards; `power` < 1 keeps the parts fuller
	const circle = (d, R) => {
		const t = Math.min(1, Math.max(0, (d - 0.5) / Math.max(0.5, R)));
		return Math.pow(Math.sqrt(1 - (1 - t) * (1 - t)), cfg.power || 1);
	};

	const fx = (c) => (cfg.front.centreX - (F.x0 + (c + 0.5) * C)) / S; // front column → X
	const fz = (r) => (cfg.front.groundY - (F.y0 + (r + 0.5) * C)) / S; // front row → Z
	const sy = (s) => (cfg.side.centreX - (Sd.x0 + (s + 0.5) * C)) / S; // side column → Y
	const sideRow = (z) => Math.floor((cfg.side.groundY - z * S - Sd.y0) / C);
	const v = C / S;
	const minFill = cfg.minFill ?? 0.35; // even an edge keeps this share of the part's depth / width

	const voxels = []; // {joint, c, r, s, colour, glow}
	const joints = [...new Set(cfg.front.regions.flatMap((q) => q.joints))];
	for (const j of joints) {
		const dF = distance(F, j), dS = distance(Sd, j);
		const fallback = (cfg.depthFallback || {})[j];
		// per front row: the part's columns (X centre / radius), the row's largest distance (local radius)
		for (let r = 0; r < F.rows; r++) {
			const cs = [];
			for (let c = 0; c < F.cols; c++) if (dF[r][c]) cs.push(c);
			if (!cs.length) continue;
			const z = fz(r);
			// the side row for this height (or the nearest one that has the part)
			let sr = sideRow(z), ss = [];
			for (const k of [0, -1, 1, -2, 2, -3, 3]) {
				const rr = sr + k;
				if (rr < 0 || rr >= Sd.rows) continue;
				const list = [];
				for (let s = 0; s < Sd.cols; s++) if (dS[rr][s]) list.push(s);
				if (list.length) {
					sr = rr;
					ss = list;
					break;
				}
			}
			let yRange;
			if (ss.length) yRange = [sy(Math.max(...ss)) - v / 2, sy(Math.min(...ss)) + v / 2];
			else if (fallback) {
				yRange = fallback;
				ss = [];
				for (let s = 0; s < Sd.cols; s++) if (sy(s) >= fallback[0] && sy(s) <= fallback[1]) ss.push(s);
				sr = -1;
			} else continue;
			const yC = (yRange[0] + yRange[1]) / 2, yR = (yRange[1] - yRange[0]) / 2;
			const xs = cs.map(fx);
			const xC = (Math.min(...xs) + Math.max(...xs)) / 2, xR = (Math.max(...xs) - Math.min(...xs)) / 2 + v / 2;
			const rowRadF = Math.max(...cs.map((c) => dF[r][c]));
			const rowRadS = sr >= 0 ? Math.max(...ss.map((s) => dS[sr][s])) : 1;
			for (const c of cs) {
				const gF = Math.max(minFill, circle(dF[r][c], rowRadF)); // depth share at this front cell
				for (const s of ss) {
					const gS = sr >= 0 ? Math.max(minFill, circle(dS[sr][s], rowRadS)) : 1; // width share
					const y = sy(s), x = fx(c);
					if (Math.abs(y - yC) > yR * gF + v * 0.5) continue;
					if (Math.abs(x - xC) > xR * gS + v * 0.5) continue;
					voxels.push({ joint: j, c, r, s, sr });
				}
			}
		}
	}

	// a front cell may belong to several parts (the head and the body behind it): where two parts claim the same
	// voxel, the one listed first in cfg.priority keeps it — no hollow behind the head or the arms
	{
		const order = cfg.priority || joints;
		const rank = (j) => (order.indexOf(j) < 0 ? 99 : order.indexOf(j));
		const owner = new Map();
		for (const vx of voxels) {
			const k = vx.c + "|" + vx.r + "|" + vx.s;
			const cur = owner.get(k);
			if (!cur || rank(vx.joint) < rank(cur.joint)) owner.set(k, vx);
		}
		voxels.length = 0;
		for (const vx of owner.values()) voxels.push(vx);
	}
	// colours: front-most of a column → front pixel; outermost on a side line → side pixel; others → front pixel
	const key = (a, b, c) => a + "," + b + "," + c;
	const frontMost = new Map(), xMin = new Map(), xMax = new Map();
	for (const vx of voxels) {
		const k1 = vx.joint + "|" + vx.c + "|" + vx.r;
		if (!frontMost.has(k1) || vx.s < frontMost.get(k1)) frontMost.set(k1, vx.s);
		const k2 = vx.joint + "|" + vx.r + "|" + vx.s;
		if (!xMin.has(k2) || vx.c < xMin.get(k2)) xMin.set(k2, vx.c);
		if (!xMax.has(k2) || vx.c > xMax.get(k2)) xMax.set(k2, vx.c);
	}
	// the main (most common, not glowing) side colour of a joint in a side row
	const domCache = new Map();
	const dominant = (joint, sr) => {
		if (sr < 0 || !Sd.g[sr]) return null;
		const k = joint + "|" + sr;
		if (domCache.has(k)) return domCache.get(k);
		const counts = new Map();
		for (const cell of Sd.g[sr]) {
			if (!cell || cell.glow || !cell.joints.includes(joint)) continue;
			const ck = cell.colour.join(",");
			counts.set(ck, (counts.get(ck) || 0) + 1);
		}
		let best = null, n = 0;
		for (const [ck, cnt] of counts) if (cnt > n) (n = cnt), (best = ck.split(",").map(Number));
		domCache.set(k, best);
		return best;
	};
	for (const vx of voxels) {
		const front = F.g[vx.r][vx.c];
		const side = vx.sr >= 0 && Sd.g[vx.sr] ? Sd.g[vx.sr][vx.s] : null;
		const k2 = vx.joint + "|" + vx.r + "|" + vx.s;
		const outer = vx.c === xMin.get(k2) || vx.c === xMax.get(k2);
		const isFront = vx.s === frontMost.get(vx.joint + "|" + vx.c + "|" + vx.r);
		if (isFront) {
			vx.colour = front.colour;
			vx.glow = front.glow;
		} else if (outer && side) {
			vx.colour = side.colour;
			vx.glow = side.glow;
		} else {
			// inside (seen only from above / below): the row's main colour on the side view, never glowing —
			// a front pus spot must not streak along a whole arm
			const main = dominant(vx.joint, vx.sr) || (front.glow ? null : front.colour);
			vx.colour = main || front.colour;
			vx.glow = false;
		}
	}

	// merge: along the depth (s) in a column, then identical runs across columns, then across rows
	const colKey = (q) => [q.joint, q.colour.join(","), q.glow].join("|");
	const byCol = new Map();
	for (const vx of voxels) {
		const k = vx.joint + "|" + vx.c + "|" + vx.r;
		if (!byCol.has(k)) byCol.set(k, []);
		byCol.get(k).push(vx);
	}
	let runs = [];
	for (const list of byCol.values()) {
		list.sort((a, b) => a.s - b.s);
		let cur = null;
		for (const q of list) {
			if (cur && q.s === cur.s1 && colKey(q) === colKey(cur)) cur.s1 = q.s + 1;
			else {
				if (cur) runs.push(cur);
				cur = { ...q, s0: q.s, s1: q.s + 1, c0: q.c, c1: q.c + 1, r0: q.r, r1: q.r + 1 };
			}
		}
		if (cur) runs.push(cur);
	}
	const mergeAlong = (list, axis) => {
		const k = (q) => colKey(q) + "|" + q.s0 + "|" + q.s1 + "|" + (axis === "c" ? q.r0 + "|" + q.r1 : q.c0 + "|" + q.c1);
		const groups = new Map();
		for (const q of list) {
			const kk = k(q);
			if (!groups.has(kk)) groups.set(kk, []);
			groups.get(kk).push(q);
		}
		const out = [];
		for (const g of groups.values()) {
			g.sort((a, b) => (axis === "c" ? a.c0 - b.c0 : a.r0 - b.r0));
			let cur = null;
			for (const q of g) {
				if (cur && (axis === "c" ? q.c0 === cur.c1 : q.r0 === cur.r1)) {
					if (axis === "c") cur.c1 = q.c1;
					else cur.r1 = q.r1;
				} else {
					if (cur) out.push(cur);
					cur = { ...q };
				}
			}
			if (cur) out.push(cur);
		}
		return out;
	};
	runs = mergeAlong(mergeAlong(runs, "c"), "r");
	const boxes = runs.map((q) => {
		const xa = (cfg.front.centreX - (F.x0 + q.c0 * C)) / S, xb = (cfg.front.centreX - (F.x0 + q.c1 * C)) / S;
		const ya = (cfg.side.centreX - (Sd.x0 + q.s0 * C)) / S, yb = (cfg.side.centreX - (Sd.x0 + q.s1 * C)) / S;
		const za = (cfg.front.groundY - (F.y0 + q.r1 * C)) / S, zb = (cfg.front.groundY - (F.y0 + q.r0 * C)) / S;
		const r4 = (n) => +n.toFixed(4);
		return { joint: q.joint, x: [r4(Math.min(xa, xb)), r4(Math.max(xa, xb))], y: [r4(Math.min(ya, yb)), r4(Math.max(ya, yb))], z: [r4(za), r4(zb)], colour: q.colour, glow: q.glow };
	});
	fs.writeFileSync(path.join(dir, "voxels.json"), JSON.stringify({ source: cfg.reference, method: "inflate", cell: v, boxes }));
	const by = {};
	boxes.forEach((b) => (by[b.joint] = (by[b.joint] || 0) + 1));
	console.log("voxels", voxels.length, "→", boxes.length, "boxes", JSON.stringify(by));
})();
