// Part-by-part voxel model from a reference sheet [владелец 22.10: «делай его по частям: отдельно руки, ноги и
// так далее, смотри каждую часть с нужной стороны, а потом соедини»]. Every body part (head, body, each arm,
// each leg) is built on its own from the views that show it:
//   - the FRONT view gives its silhouette across (X) and up (Z) — the part's box in X and Z;
//   - the SIDE view gives its depth (Y): absolute Y from the side panel, its height stretched to the part's front
//     Z range (AI sheets draw the views at slightly different heights);
//   - the TOP view (optional) gives its outline from above, stretched to the part's X and Y ranges (Codex draws
//     top views at another scale — fitting each part separately removes that);
//   - a voxel of the part stays when it is inside every silhouette (the part's visual hull), so arms are round
//     tubes with stepped ends, the belly round from above, not extrusions;
//   - faces take the colour of the view they face: the front-most voxel the front pixel, the top-most the top
//     pixel, the outermost left / right the side pixel; inner voxels the part's main colour (no streaks);
//   - the parts are joined in one frame; where two parts claim a voxel, cfg.priority decides.
// Usage: node scripts/model-tools/parts.cjs assets/models/<id>/parts.json → <dir>/voxels.json (Blender space:
// X = (front.centreX − x) / S, Y = (side.centreX − x) / S, Z = (front.groundY − y) / S).
const fs = require("fs");
const path = require("path");
const sharp = require(process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp"));

const cfgPath = process.argv[2];
const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
const dir = path.dirname(cfgPath);
const C = cfg.cell, S = cfg.scale, bg = cfg.background, tol = cfg.tolerance;
const v = C / S; // voxel size, studs
const lum = (c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
const isGlow = (m) =>
	cfg.glowRule === "pus" ? m[1] > 195 && m[0] > 160 && m[2] < 130 : (m[0] > 225 && m[1] > 160) || (m[0] > 150 && m[0] - m[2] > 90);
const glowColour = (m) => (lum(m) >= 200 ? cfg.glow.hot : m[1] >= 140 ? cfg.glow.bright : m[0] >= 200 ? cfg.glow.warm : cfg.glow.deep);

(async () => {
	const { data, info } = await sharp(path.join(dir, cfg.reference)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
	const W = info.width, H = info.height;
	const pix = (x, y) => {
		x = Math.max(0, Math.min(W - 1, Math.round(x)));
		y = Math.max(0, Math.min(H - 1, Math.round(y)));
		const i = (y * W + x) * 3;
		return [data[i], data[i + 1], data[i + 2]];
	};
	const isFg = (q) => Math.abs(q[0] - bg[0]) + Math.abs(q[1] - bg[1]) + Math.abs(q[2] - bg[2]) > tol;

	// the palette: k-means over every part rect of every view
	const samples = [];
	for (const p of cfg.parts)
		for (const rect of [p.front, p.side, p.top].filter(Boolean))
			for (let y = rect[1]; y < rect[3]; y += 3)
				for (let x = rect[0]; x < rect[2]; x += 3) {
					const q = pix(x, y);
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
		centres = centres.map((c, k) => (sums[k][3] ? sums[k].slice(0, 3).map((x) => Math.round(x / sums[k][3])) : c));
	}
	const tone = (m) => {
		let best = centres[0], bd = Infinity;
		for (const c of centres) {
			const d = (c[0] - m[0]) ** 2 + (c[1] - m[1]) ** 2 + (c[2] - m[2]) ** 2;
			if (d < bd) (bd = d), (best = c);
		}
		return best;
	};
	// colour of a small window around a sheet point: the median, glowing when its brighter part glows
	const colourAt = (x, y, r) => {
		const list = [];
		for (let yy = y - r; yy <= y + r; yy += 2)
			for (let xx = x - r; xx <= x + r; xx += 2) {
				const q = pix(xx, yy);
				if (isFg(q)) list.push(q);
			}
		if (!list.length) return null;
		list.sort((a, b) => lum(a) - lum(b));
		let m = list[Math.floor(list.length / 2)];
		const bright = list[Math.floor(list.length * 0.8)];
		if (!isGlow(m) && isGlow(bright) && cfg.thinGlow) m = bright;
		const glow = isGlow(m);
		return { colour: glow ? glowColour(m) : tone(m), glow };
	};
	// a silhouette mask of a rect at cell resolution and its bounding box (sheet px)
	function mask(rect) {
		const [x0, y0, x1, y1] = rect;
		const cols = Math.floor((x1 - x0) / C), rows = Math.floor((y1 - y0) / C);
		const m = [];
		let bx0 = Infinity, by0 = Infinity, bx1 = -Infinity, by1 = -Infinity;
		for (let r = 0; r < rows; r++) {
			const row = [];
			for (let c = 0; c < cols; c++) {
				let n = 0, fg = 0;
				for (let y = y0 + r * C; y < y0 + (r + 1) * C; y += 2)
					for (let x = x0 + c * C; x < x0 + (c + 1) * C; x += 2) {
						n++;
						if (isFg(pix(x, y))) fg++;
					}
				const on = fg >= n * 0.5;
				row.push(on);
				if (on) {
					bx0 = Math.min(bx0, x0 + c * C);
					bx1 = Math.max(bx1, x0 + (c + 1) * C);
					by0 = Math.min(by0, y0 + r * C);
					by1 = Math.max(by1, y0 + (r + 1) * C);
				}
			}
			m.push(row);
		}
		const at = (x, y) => {
			const c = Math.floor((x - x0) / C), r = Math.floor((y - y0) / C);
			return r >= 0 && c >= 0 && r < rows && c < cols && m[r][c];
		};
		// the run of the mask through a sheet point, along x (row) or y (column), in sheet px
		const run = (x, y, alongX) => {
			const c = Math.floor((x - x0) / C), r = Math.floor((y - y0) / C);
			if (!(r >= 0 && c >= 0 && r < rows && c < cols && m[r][c])) return null;
			let a = alongX ? c : r, b = a;
			if (alongX) {
				while (a > 0 && m[r][a - 1]) a--;
				while (b < cols - 1 && m[r][b + 1]) b++;
				return [x0 + a * C, x0 + (b + 1) * C];
			}
			while (a > 0 && m[a - 1][c]) a--;
			while (b < rows - 1 && m[b + 1][c]) b++;
			return [y0 + a * C, y0 + (b + 1) * C];
		};
		return { at, run, box: [bx0, by0, bx1, by1] };
	}

	const voxels = new Map(); // "i|k|j" (X index, Y index, Z index) → voxel
	const rank = (j) => {
		const o = cfg.priority || [];
		return o.indexOf(j) < 0 ? 99 : o.indexOf(j);
	};
	const fx = (x) => (cfg.front.centreX - x) / S;
	const fz = (y) => (cfg.front.groundY - y) / S;
	const sy = (x) => (cfg.side.centreX - x) / S;
	const parts = [];
	for (const p of cfg.parts) {
		const F = mask(p.front), Sm = mask(p.side), T = p.top ? mask(p.top) : null;
		// the part's 3D box: X and Z from the front view, Y from the side view
		const X0 = fx(F.box[2]), X1 = fx(F.box[0]); // left edge in px = larger X
		const Z0 = fz(F.box[3]), Z1 = fz(F.box[1]);
		const Y0 = sy(Sm.box[2]), Y1 = sy(Sm.box[0]);
		parts.push({ joint: p.joint, X: [X0, X1], Y: [Y0, Y1], Z: [Z0, Z1] });
		// view lookups: world (x, y, z) → is it inside the part's silhouette in that view, and the sheet point
		const frontPt = (x, z) => [cfg.front.centreX - x * S, cfg.front.groundY - z * S];
		const sidePt = (y, z) => {
			// Z stretched from the part's front range to its side box
			const t = (z - Z0) / Math.max(1e-6, Z1 - Z0);
			return [cfg.side.centreX - y * S, Sm.box[3] - t * (Sm.box[3] - Sm.box[1])];
		};
		const topPt = (x, y) => {
			// forward (larger Y) is to the left of the top panel; +X goes down (or up with xSign −1)
			const ty = (Y1 - y) / Math.max(1e-6, Y1 - Y0);
			const tx = (x - X0) / Math.max(1e-6, X1 - X0);
			const px = T.box[0] + ty * (T.box[2] - T.box[0]);
			const py = (cfg.topXSign || 1) > 0 ? T.box[1] + tx * (T.box[3] - T.box[1]) : T.box[3] - tx * (T.box[3] - T.box[1]);
			return [px, py];
		};
		const iX0 = Math.floor(X0 / v), iX1 = Math.ceil(X1 / v);
		const iY0 = Math.floor(Y0 / v), iY1 = Math.ceil(Y1 / v);
		const iZ0 = Math.floor(Z0 / v), iZ1 = Math.ceil(Z1 / v);
		for (let i = iX0; i < iX1; i++)
			for (let k = iZ0; k < iZ1; k++) {
				const x = (i + 0.5) * v, z = (k + 0.5) * v;
				if (!F.at(...frontPt(x, z))) continue;
				for (let j = iY0; j < iY1; j++) {
					const y = (j + 0.5) * v;
					if (!Sm.at(...sidePt(y, z))) continue;
					if (T && !T.at(...topPt(x, y))) continue;
					// a rounded cross-section (superellipse, exponent p.round): along Z for upright parts — width from
					// the front row, depth from the side row; along Y for limbs pointing forward — width from the
					// front row, height from the side column
					if (p.round) {
						const fp = frontPt(x, z), sp = sidePt(y, z);
						const fr = F.run(fp[0], fp[1], true); // front row run → X extent
						let ok = true;
						if (fr) {
							const xa = fx(fr[1]), xb = fx(fr[0]);
							const xc = (xa + xb) / 2, ax = Math.max(v, (xb - xa) / 2);
							let tB = 0;
							if ((p.axis || "z") === "z") {
								const sr = Sm.run(sp[0], sp[1], true); // side row run → Y extent
								if (sr) {
									const ya = sy(sr[1]), yb = sy(sr[0]);
									tB = Math.abs(y - (ya + yb) / 2) / Math.max(v, (yb - ya) / 2);
								}
							} else {
								const sc = Sm.run(sp[0], sp[1], false); // side column run → Z extent (stretched)
								if (sc) {
									const t0 = (Sm.box[3] - sc[1]) / Math.max(1e-6, Sm.box[3] - Sm.box[1]);
									const t1 = (Sm.box[3] - sc[0]) / Math.max(1e-6, Sm.box[3] - Sm.box[1]);
									const za = Z0 + t0 * (Z1 - Z0), zb = Z0 + t1 * (Z1 - Z0);
									tB = Math.abs(z - (za + zb) / 2) / Math.max(v, (zb - za) / 2);
								}
							}
							const tA = Math.abs(x - xc) / ax;
							ok = Math.pow(tA, p.round) + Math.pow(tB, p.round) <= 1.02;
						}
						if (!ok) continue;
					}
					const key = i + "|" + j + "|" + k;
					const cur = voxels.get(key);
					if (cur && rank(cur.joint) <= rank(p.joint)) continue;
					voxels.set(key, { joint: p.joint, i, j, k, frontPt, sidePt, topPt: T ? topPt : null });
				}
			}
	}

	// colours by the face direction
	const has = (i, j, k, joint) => {
		const q = voxels.get(i + "|" + j + "|" + k);
		return q && q.joint === joint;
	};
	const R = Math.floor(C / 2);
	const mainColour = new Map(); // joint|k → the part's commonest non-glowing colour at that height (front view)
	const all = [...voxels.values()];
	for (const q of all) {
		const front = colourAt(...q.frontPt((q.i + 0.5) * v, (q.k + 0.5) * v), R);
		q.frontColour = front;
		const mk = q.joint + "|" + q.k;
		if (front && !front.glow) {
			const m = mainColour.get(mk) || new Map();
			const ck = front.colour.join(",");
			m.set(ck, (m.get(ck) || 0) + 1);
			mainColour.set(mk, m);
		}
	}
	const main = (joint, k) => {
		const m = mainColour.get(joint + "|" + k);
		if (!m) return null;
		let best = null, n = 0;
		for (const [ck, cnt] of m) if (cnt > n) (n = cnt), (best = ck.split(",").map(Number));
		return best;
	};
	for (const q of all) {
		const x = (q.i + 0.5) * v, y = (q.j + 0.5) * v, z = (q.k + 0.5) * v;
		let col = null;
		if (!has(q.i, q.j + 1, q.k, q.joint)) col = q.frontColour; // facing forward (+Y)
		else if (!has(q.i, q.j - 1, q.k, q.joint)) {
			// the back: its side-view colour, never glowing (a side pus spot would streak across the whole back)
			const sc = colourAt(...q.sidePt(y, z), R);
			col = sc && !sc.glow ? sc : null;
		}
		else if (!has(q.i, q.j, q.k + 1, q.joint) && q.topPt) col = colourAt(...q.topPt(x, y), R); // facing up
		else if (!has(q.i + 1, q.j, q.k, q.joint) || !has(q.i - 1, q.j, q.k, q.joint)) col = colourAt(...q.sidePt(y, z), R);
		if (!col) {
			const m = main(q.joint, q.k);
			col = m ? { colour: m, glow: false } : q.frontColour || { colour: centres[0], glow: false };
		}
		q.colour = col.colour;
		// cfg.neonOnly = "hot": only the brightest pus / lava tone glows (Neon), the rest keep the colour unlit
		q.glow = col.glow && (cfg.neonOnly !== "hot" || col.colour === cfg.glow.hot);
	}

	// merge: along Y in a column, identical runs across X, then across Z
	const ck = (q) => q.joint + "|" + q.colour.join(",") + "|" + q.glow;
	const cols = new Map();
	for (const q of all) {
		const kk = q.joint + "|" + q.i + "|" + q.k;
		if (!cols.has(kk)) cols.set(kk, []);
		cols.get(kk).push(q);
	}
	let runs = [];
	for (const list of cols.values()) {
		list.sort((a, b) => a.j - b.j);
		let cur = null;
		for (const q of list) {
			if (cur && q.j === cur.j1 && ck(q) === ck(cur)) cur.j1 = q.j + 1;
			else {
				if (cur) runs.push(cur);
				cur = { joint: q.joint, colour: q.colour, glow: q.glow, i0: q.i, i1: q.i + 1, j0: q.j, j1: q.j + 1, k0: q.k, k1: q.k + 1 };
			}
		}
		if (cur) runs.push(cur);
	}
	const merge = (list, axis) => {
		const groups = new Map();
		for (const q of list) {
			const kk = ck(q) + "|" + q.j0 + "|" + q.j1 + "|" + (axis === "i" ? q.k0 + "|" + q.k1 : q.i0 + "|" + q.i1);
			if (!groups.has(kk)) groups.set(kk, []);
			groups.get(kk).push(q);
		}
		const out = [];
		for (const g of groups.values()) {
			g.sort((a, b) => (axis === "i" ? a.i0 - b.i0 : a.k0 - b.k0));
			let cur = null;
			for (const q of g) {
				if (cur && (axis === "i" ? q.i0 === cur.i1 : q.k0 === cur.k1)) {
					if (axis === "i") cur.i1 = q.i1;
					else cur.k1 = q.k1;
				} else {
					if (cur) out.push(cur);
					cur = { ...q };
				}
			}
			if (cur) out.push(cur);
		}
		return out;
	};
	runs = merge(merge(runs, "i"), "k");
	const r4 = (n) => +n.toFixed(4);
	const boxes = runs.map((q) => ({
		joint: q.joint,
		x: [r4(q.i0 * v), r4(q.i1 * v)],
		y: [r4(q.j0 * v), r4(q.j1 * v)],
		z: [r4(q.k0 * v), r4(q.k1 * v)],
		colour: q.colour,
		glow: q.glow,
	}));
	fs.writeFileSync(path.join(dir, "voxels.json"), JSON.stringify({ source: cfg.reference, method: "parts", cell: v, parts, boxes }));
	const by = {};
	boxes.forEach((b) => (by[b.joint] = (by[b.joint] || 0) + 1));
	console.log("voxels", all.length, "→", boxes.length, "boxes", JSON.stringify(by));
	for (const p of parts) console.log(p.joint.padEnd(6), "X", p.X.map((n) => n.toFixed(2)).join("..") , "Y", p.Y.map((n) => n.toFixed(2)).join(".."), "Z", p.Z.map((n) => n.toFixed(2)).join(".."));
})();
