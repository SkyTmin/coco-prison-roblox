// Front-view voxeliser for reference sheets drawn as voxel sculptures (bosses, golems): every CELL×CELL pixel
// cell of the reference's front view becomes a box of its own colour (stone tones or glowing lava), extruded in
// depth over its body region's range and rounded towards the silhouette (bevel), then merged into rectangles.
// The result matches the front view pixel for pixel. Depth: with a "side" block, each joint's depth at each
// height is its silhouette on the side view (sheet facing left: Y = (side.centreX − x) / scale); otherwise
// (or where the side view has no pixels for it) the region's y range.
// Usage: node scripts/model-tools/voxelize-front.cjs assets/models/<id>/voxelize.json
// Config: { reference, panel: [left, top, width, height], scale (px a stud), centreX, groundY, cell,
//           background: [r, g, b], tolerance, bevelStep, stone: [[r,g,b]...], lava: {...}, regions: [
//           { joint, rect: [x0, y0, x1, y1] (sheet px, first match wins), y: [back, front] studs, bevel } ],
//           side: { centreX, groundY, regions: [ { joints: [..], rect: [x0, y0, x1, y1] } ] } }
// Output: <dir>/voxels.json — boxes in Blender space (X = (centreX − x) / scale, Z = (groundY − y) / scale).
const fs = require("fs");
const path = require("path");
const sharp = require(process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp"));

const cfgPath = process.argv[2];
const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
const dir = path.dirname(cfgPath);

(async () => {
	const [pl, pt, pw, ph] = cfg.panel;
	const { data, info } = await sharp(path.join(dir, cfg.reference)).extract({ left: pl, top: pt, width: pw, height: ph }).removeAlpha().raw().toBuffer({ resolveWithObject: true });
	const C = cfg.cell;
	const cols = Math.floor(pw / C), rows = Math.floor(ph / C);
	const bg = cfg.background, tol = cfg.tolerance;
	const lum = (c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
	// glowing cells: molten lava (orange) or, with glowRule "pus", bright yellow-green pus
	const isLava = (m) =>
		cfg.glowRule === "pus"
			? m[1] > 195 && m[0] > 160 && m[2] < 130
			: (m[0] > 225 && m[1] > 160) || (m[0] > 150 && m[0] - m[2] > 90);
	// lava tones by brightness (cfg.lava.deep / warm / bright / hot): white-yellow core → orange → dark red edge
	const lavaColour = (m) => {
		if (!cfg.lava.bright) return m[0] > 225 && m[1] > 160 ? cfg.lava.hot : cfg.lava.warm;
		if (lum(m) >= 200) return cfg.lava.hot;
		if (m[1] >= 140) return cfg.lava.bright;
		if (m[0] >= 200) return cfg.lava.warm;
		return cfg.lava.deep;
	};
	// cells of some joints (a blade with a thin molten core) count as lava when their brighter part is lava
	const pick = (px, joint) => {
		const m = px[Math.floor(px.length / 2)];
		const bias = (cfg.lavaBias || {})[joint];
		if (bias && !isLava(m)) {
			const b = px[Math.min(px.length - 1, Math.floor(px.length * bias))];
			if (isLava(b)) return b;
		}
		return m;
	};
	// side profiles: joint → sheet row → [min x, max x] of the silhouette inside its side rect
	const profiles = {};
	if (cfg.side) {
		const full = await sharp(path.join(dir, cfg.reference)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
		const W = full.info.width;
		for (const sr of cfg.side.regions) {
			const rowsMap = {};
			for (let y = sr.rect[1]; y < sr.rect[3]; y++) {
				let mn = Infinity, mx = -Infinity;
				for (let x = sr.rect[0]; x < sr.rect[2]; x++) {
					const i = (y * W + x) * 3;
					const d = Math.abs(full.data[i] - bg[0]) + Math.abs(full.data[i + 1] - bg[1]) + Math.abs(full.data[i + 2] - bg[2]);
					if (d > tol) {
						mn = Math.min(mn, x);
						mx = Math.max(mx, x);
					}
				}
				if (mx >= mn) rowsMap[y] = [mn, mx + 1];
			}
			for (const j of sr.joints) profiles[j] = rowsMap;
		}
	}
	const sideDepth = (joint, z) => {
		const prof = profiles[joint];
		if (!prof) return null;
		const y = Math.round(cfg.side.groundY - z * cfg.scale);
		for (let k = 0; k <= C; k++) {
			const e = prof[y - k] || prof[y + k];
			if (e) return [(cfg.side.centreX - e[1]) / cfg.scale, (cfg.side.centreX - e[0]) / cfg.scale];
		}
		return null;
	};
	// palette: with cfg.palette = N the solid colours are the N main colours of the front panel (k-means), so
	// a many-coloured model (skin, shirt, trousers, rot) keeps its hues; otherwise stone tones by luminance
	let palette = null;
	if (cfg.palette) {
		const samples = [];
		for (let y = 0; y < info.height; y += 3)
			for (let x = 0; x < info.width; x += 3) {
				const i = (y * info.width + x) * 3;
				const q = [data[i], data[i + 1], data[i + 2]];
				if (Math.abs(q[0] - bg[0]) + Math.abs(q[1] - bg[1]) + Math.abs(q[2] - bg[2]) > tol && !isLava(q)) samples.push(q);
			}
		samples.sort((a, b) => lum(a) - lum(b));
		let centres = Array.from({ length: cfg.palette }, (_, k) => samples[Math.floor(((k + 0.5) / cfg.palette) * samples.length)].slice());
		for (let it = 0; it < 12; it++) {
			const sums = centres.map(() => [0, 0, 0, 0]);
			for (const q of samples) {
				let best = 0, bd = Infinity;
				centres.forEach((c, k) => {
					const d = (c[0] - q[0]) ** 2 + (c[1] - q[1]) ** 2 + (c[2] - q[2]) ** 2;
					if (d < bd) (bd = d), (best = k);
				});
				const t = sums[best];
				t[0] += q[0], t[1] += q[1], t[2] += q[2], t[3]++;
			}
			centres = centres.map((c, k) => (sums[k][3] ? sums[k].slice(0, 3).map((v) => Math.round(v / sums[k][3])) : c));
		}
		palette = centres;
	}
	const toneOf = (m, joint) => {
		if (palette) {
			let best = palette[0], bd = Infinity;
			for (const c of palette) {
				const d = (c[0] - m[0]) ** 2 + (c[1] - m[1]) ** 2 + (c[2] - m[2]) ** 2;
				if (d < bd) (bd = d), (best = c);
			}
			return best;
		}
		const L = lum(m);
		return ((cfg.stoneByJoint || {})[joint] || cfg.stone).reduce((best, t) => (Math.abs(lum(t) - L) < Math.abs(lum(best) - L) ? t : best));
	};
	// 1. cells: foreground share + median colour of the centre
	const cells = [];
	for (let r = 0; r < rows; r++) {
		const row = [];
		for (let c = 0; c < cols; c++) {
			let fg = 0, n = 0;
			const px = [];
			for (let y = r * C; y < (r + 1) * C; y++)
				for (let x = c * C; x < (c + 1) * C; x++) {
					const i = (y * info.width + x) * 3;
					const p = [data[i], data[i + 1], data[i + 2]];
					n++;
					if (Math.abs(p[0] - bg[0]) + Math.abs(p[1] - bg[1]) + Math.abs(p[2] - bg[2]) > tol) {
						fg++;
						px.push(p);
					}
				}
			if (fg / n < 0.5) {
				row.push(null);
				continue;
			}
			px.sort((a, b) => lum(a) - lum(b));
			const sx0 = pl + c * C + C / 2, sy0 = pt + r * C + C / 2;
			const reg0 = cfg.regions.find((g) => sx0 >= g.rect[0] && sx0 < g.rect[2] && sy0 >= g.rect[1] && sy0 < g.rect[3]);
			const m = pick(px, reg0 && reg0.joint);
			// glowing lava: orange-red with a strong red-blue gap
			const lava = isLava(m);
			let colour, glow = false;
			if (lava) {
				colour = lavaColour(m);
				glow = true;
			} else {
				colour = toneOf(m, reg0 && reg0.joint);
			}
			const sx = pl + c * C + C / 2, sy = pt + r * C + C / 2; // sheet coordinates of the cell centre
			const region = cfg.regions.find((g) => sx >= g.rect[0] && sx < g.rect[2] && sy >= g.rect[1] && sy < g.rect[3]);
			row.push({ colour, glow, region });
		}
		cells.push(row);
	}
	// 2. distance (chessboard) to the background, for the rounding
	const dist = cells.map((row) => row.map((c) => (c ? 99 : 0)));
	for (let pass = 0; pass < 2; pass++) {
		for (let r = 0; r < rows; r++)
			for (let c = 0; c < cols; c++) {
				if (!dist[r][c]) continue;
				let best = dist[r][c];
				for (let dr = -1; dr <= 1; dr++)
					for (let dc = -1; dc <= 1; dc++) {
						const rr = r + dr, cc = c + dc;
						const v = rr < 0 || cc < 0 || rr >= rows || cc >= cols ? 0 : dist[rr][cc];
						best = Math.min(best, v + 1);
					}
				dist[r][c] = best;
			}
		// second sweep in reverse so the transform converges
		dist.reverse().forEach((row) => row.reverse());
		cells.reverse().forEach((row) => row.reverse());
	}
	// 3. per cell depth ranges (side profile or region range, rounded towards the silhouette)
	const spec = cells.map((row, r) => row.map((cell, c) => {
		if (!cell || !cell.region) return null;
		const g = cell.region;
		const inset = Math.max(0, (g.bevel || 0) - Math.min(dist[r][c], g.bevel || 0)) * (cfg.bevelStep || 0.18);
		const zMid = (cfg.groundY - (pt + r * C + C / 2)) / cfg.scale;
		const range = sideDepth(g.joint, zMid) || g.y;
		const y1 = range[1] - inset;
		const y0 = Math.min(range[0] + inset, y1 - 0.1);
		return { joint: g.joint, colour: cell.colour, glow: cell.glow, y0, y1 };
	}));
	// round cross-sections (cfg.round[joint] = strength): a column's depth shrinks towards the part's sides like an
	// ellipse, so a belly or a head is round from above instead of a box
	if (cfg.round) {
		for (let r = 0; r < rows; r++) {
			const byJoint = {};
			spec[r].forEach((sp, c) => sp && (byJoint[sp.joint] = byJoint[sp.joint] || []).push(c));
			for (const [j, cs] of Object.entries(byJoint)) {
				const k = cfg.round[j];
				if (!k) continue;
				const lo = Math.min(...cs), hi = Math.max(...cs);
				const mid = (lo + hi) / 2, half = Math.max(1, (hi - lo + 1) / 2);
				for (const c of cs) {
					const sp = spec[r][c];
					const t = (c - mid) / half;
					const f = Math.sqrt(Math.max(0.12, 1 - k * t * t));
					const cy = (sp.y0 + sp.y1) / 2, hy = (sp.y1 - sp.y0) / 2;
					sp.y0 = cy - hy * f;
					sp.y1 = cy + hy * f;
				}
			}
		}
	}
	// 4. boxes: with caps, the exact front colour is a thin front layer and the rest of the depth is one stone
	// tone (the texture gives it grain) — no front pixels streaking along the sides
	const capDepth = cfg.capDepth || 0;
	const layers = [];
	// side regions with voxel: true (a blade): voxels along the side-view cells of the matching row; the outer
	// columns take the side-view colours, so the flat of the blade shows its own core and teeth
	const sideCells = {};
	if (cfg.side) {
		const full = await sharp(path.join(dir, cfg.reference)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
		const W = full.info.width;
		for (const sr of cfg.side.regions.filter((g) => g.voxel)) {
			const grid = [];
			const SC = cfg.sideCell || C; // coarser side cells: fewer, longer boxes along the depth
			for (let y = sr.rect[1]; y + SC <= sr.rect[3]; y += SC) {
				const row = [];
				for (let x = sr.rect[0]; x + SC <= sr.rect[2]; x += SC) {
					const px = [];
					for (let yy = y; yy < y + SC; yy++)
						for (let xx = x; xx < x + SC; xx++) {
							const i = (yy * W + xx) * 3;
							const q = [full.data[i], full.data[i + 1], full.data[i + 2]];
							if (Math.abs(q[0] - bg[0]) + Math.abs(q[1] - bg[1]) + Math.abs(q[2] - bg[2]) > tol) px.push(q);
						}
					if (px.length < SC * SC * 0.3) continue;
					px.sort((u, v) => lum(u) - lum(v));
					const m = pick(px, sr.joints[0]);
					const lava = isLava(m);
					const colour = lava ? lavaColour(m) : toneOf(m, sr.joints[0]);
					row.push({ y0: (cfg.side.centreX - (x + SC)) / cfg.scale, y1: (cfg.side.centreX - x) / cfg.scale, colour, glow: lava });
				}
				grid.push({ z: (cfg.side.groundY - (y + SC / 2)) / cfg.scale, row });
			}
			for (const j of sr.joints) sideCells[j] = grid;
		}
	}
	const sideRowAt = (j, z) => {
		let best = null;
		for (const g of sideCells[j]) if (g.row.length && (!best || Math.abs(g.z - z) < Math.abs(best.z - z))) best = g;
		return best && Math.abs(best.z - z) < (0.75 * (cfg.sideCell || C)) / cfg.scale ? best.row : null;
	};
	for (let r = 0; r < rows; r++)
		for (let c = 0; c < cols; c++) {
			const sp = spec[r][c];
			if (!sp) continue;
			if (sideCells[sp.joint]) {
				const zMid = (cfg.groundY - (pt + r * C + C / 2)) / cfg.scale;
				const srow = sideRowAt(sp.joint, zMid);
				if (!srow && sp.glow) continue; // a thin drip with nothing on the side view at its height
				if (srow) {
					const inRow = spec[r].map((q, k) => (q && q.joint === sp.joint ? k : -1)).filter((k) => k >= 0);
					const outer = c === Math.min(...inRow) || c === Math.max(...inRow);
					// consecutive side cells of one colour become one box along the depth
					let run = null;
					// only the side cells inside this column's (rounded) depth
					const inside = srow
						.filter((sc) => sc.y1 > sp.y0 && sc.y0 < sp.y1)
						.map((sc) => ({ ...sc, y0: Math.max(sc.y0, sp.y0), y1: Math.min(sc.y1, sp.y1) }));
					for (const sc of inside.sort((u, v) => u.y0 - v.y0)) {
						const col = outer ? sc : sp;
						if (run && run.colour === col.colour && Math.abs(run.y1 - sc.y0) < 1e-6) run.y1 = sc.y1;
						else {
							if (run) layers.push(run);
							run = { joint: sp.joint, colour: col.colour, glow: col.glow, y0: sc.y0, y1: sc.y1, r, c };
						}
					}
					if (run) layers.push(run);
					continue;
				}
			}
			if (capDepth > 0 && sp.y1 - sp.y0 > capDepth + 0.05) {
				layers.push({ ...sp, y0: sp.y1 - capDepth, r, c });
				layers.push({ joint: sp.joint, colour: (cfg.bodyTones || {})[sp.joint] || cfg.bodyTone, glow: false, y0: sp.y0, y1: sp.y1 - capDepth, r, c });
			} else {
				layers.push({ ...sp, r, c });
			}
		}
	const key = (b) => [b.joint, b.colour.join(","), b.glow, b.y0.toFixed(3), b.y1.toFixed(3)].join("|");
	// merge: runs along a row, then identical runs down the rows
	const byRow = new Map();
	for (const l of layers) {
		const k = l.r + "|" + key(l);
		if (!byRow.has(k)) byRow.set(k, []);
		byRow.get(k).push(l);
	}
	const runs = [];
	for (const list of byRow.values()) {
		list.sort((x, y) => x.c - y.c);
		let cur = null;
		for (const l of list) {
			if (cur && l.c === cur.c1) cur.c1 = l.c + 1;
			else {
				if (cur) runs.push(cur);
				cur = { ...l, c0: l.c, c1: l.c + 1, r0: l.r, r1: l.r + 1 };
			}
		}
		if (cur) runs.push(cur);
	}
	const merged = [];
	const open = new Map();
	for (const run of runs.sort((x, y) => x.r0 - y.r0 || x.c0 - y.c0)) {
		const k = key(run) + "|" + run.c0 + "|" + run.c1;
		const prev = open.get(k);
		if (prev && prev.r1 === run.r0) prev.r1 = run.r1;
		else {
			if (prev) merged.push(prev);
			open.set(k, run);
		}
	}
	for (const v of open.values()) merged.push(v);
	const S = cfg.scale;
	const boxes = merged.map((b) => {
		const xa = (cfg.centreX - (pl + b.c0 * C)) / S, xb = (cfg.centreX - (pl + b.c1 * C)) / S;
		const za = (cfg.groundY - (pt + b.r1 * C)) / S, zb = (cfg.groundY - (pt + b.r0 * C)) / S;
		return { joint: b.joint, x: [Math.min(xa, xb), Math.max(xa, xb)].map((v) => +v.toFixed(4)), y: [+b.y0.toFixed(4), +b.y1.toFixed(4)], z: [+za.toFixed(4), +zb.toFixed(4)], colour: b.colour, glow: b.glow };
	});
	// 5. lava cracks of the side view, laid on the outer side faces of the matching columns (both sides)
	if (cfg.side && cfg.sideLava) {
		const full = await sharp(path.join(dir, cfg.reference)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
		const W = full.info.width;
		const half = C / 2 / S;
		for (const sr of cfg.side.regions) {
			for (let y = sr.rect[1]; y + C <= sr.rect[3]; y += C)
				for (let x = sr.rect[0]; x + C <= sr.rect[2]; x += C) {
					const px = [];
					for (let yy = y; yy < y + C; yy++)
						for (let xx = x; xx < x + C; xx++) {
							const i = (yy * W + xx) * 3;
							px.push([full.data[i], full.data[i + 1], full.data[i + 2]]);
						}
					px.sort((u, v) => lum(u) - lum(v));
					const m = px[Math.floor(px.length * 0.75)]; // the brighter half: thin cracks still count
					const hot = m[0] > 225 && m[1] > 160;
					if (!(hot || (m[0] > 150 && m[0] - m[2] > 90))) continue;
					const Y = (cfg.side.centreX - (x + C / 2)) / S;
					const Z = (cfg.side.groundY - (y + C / 2)) / S;
					const r = Math.floor((cfg.groundY - Z * S - pt) / C);
					if (r < 0 || r >= rows) continue;
					let cMin = -1, cMax = -1;
					for (let c = 0; c < cols; c++) {
						const sp = spec[r][c];
						if (sp && sr.joints.includes(sp.joint) && Y >= sp.y0 && Y <= sp.y1) {
							if (cMin < 0) cMin = c;
							cMax = c;
						}
					}
					if (cMin < 0) continue;
					const colour = lavaColour(m);
					const xHi = (cfg.centreX - (pl + cMin * C)) / S; // the +X outer face
					const xLo = (cfg.centreX - (pl + (cMax + 1) * C)) / S; // the −X outer face
					for (const [xr, c] of [[[xHi - 0.02, xHi + 0.05], cMin], [[xLo - 0.05, xLo + 0.02], cMax]])
						boxes.push({ joint: spec[r][c].joint, x: xr.map((v) => +v.toFixed(4)), y: [+(Y - half).toFixed(4), +(Y + half).toFixed(4)], z: [+(Z - half).toFixed(4), +(Z + half).toFixed(4)], colour, glow: true });
				}
		}
	}
	fs.writeFileSync(path.join(dir, "voxels.json"), JSON.stringify({ source: cfg.reference, cell: C / S, boxes }, null, 0));
	const byJoint = {};
	boxes.forEach((b) => (byJoint[b.joint] = (byJoint[b.joint] || 0) + 1));
	console.log("cells", cols, "x", rows, "→", boxes.length, "boxes", JSON.stringify(byJoint));
})();
