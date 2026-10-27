// The pixel grid of our item sprites for the Blender voxel items (assets/models/items/items.py) [владелец 27.10:
// «вообще через блендер надо все предметы сделать»]. A 128×128 sprite from draw-icons / armor-icons is a 16×16 grid
// drawn ×8: its cell centres are read directly. Any other size (the hand-drawn keys, coins, food) gets its cell size
// and phase from the colour edges: the column / row profile of colour jumps repeats every cell, the smallest lag with
// a strong autocorrelation is the cell, the phase that puts the most jumps on cell borders is the offset.
// Usage: node scripts/sprite-grids.mjs [id,id,…] [--dir <sprites dir>] [--write] → assets/models/items/grids.json
//   --dir reads <dir>/<id>.png instead of assets/icons/items (the Codex cells, scripts/split-codex-sheet.mjs);
//   --cell <px> forces the cell size (a Codex sheet is drawn at one scale; the phase is still found per sprite);
//   --write also draws the clean sprite from the grid (square, hard pixels, ≤ 256 px) into assets/icons/items/<id>.png.
//   (id → { w, h, px: ["rrggbb" | "" (empty) …] row by row from the top }); no ids = every sprite in
//   assets/icons/items except tools, booster bottles and hud/effect icons (those stay flat UI pictures).
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require(
	process.env.SHARP_PATH ||
		path.join(
			process.env.LOCALAPPDATA || "",
			"Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp",
		),
);

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, "$1")), "..");
const args = process.argv.slice(2);
const flag = (name) => args.indexOf(name);
const DIR = flag("--dir") >= 0 ? path.resolve(ROOT, args[flag("--dir") + 1]) : path.join(ROOT, "assets/icons/items");
const WRITE = flag("--write") >= 0;
const CELL = flag("--cell") >= 0 ? Number(args[flag("--cell") + 1]) : null;
const positional = args.filter((a, i) => !a.startsWith("--") && !(i > 0 && ["--dir", "--cell"].includes(args[i - 1])));
const OUT = path.join(ROOT, "assets/models/items/grids.json");
const SKIP = /^(pickaxe|axe|shovel|sword|shears|bow|booster_|hud_|effect_|top_|shovel_wood2)/;

const ids = positional[0]
	? positional[0].split(",")
	: fs
			.readdirSync(DIR)
			.filter((f) => f.endsWith(".png"))
			.map((f) => f.slice(0, -4))
			.filter((id) => !SKIP.test(id));

function hex(r, g, b) {
	return [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("");
}

// the strongest repeat of a profile: the smallest lag within 85 % of the best autocorrelation
function period(profile, lo, hi) {
	const n = profile.length;
	const mean = profile.reduce((a, b) => a + b, 0) / n;
	const p = profile.map((v) => v - mean);
	const score = [];
	for (let lag = lo; lag <= hi; lag++) {
		let s = 0;
		for (let i = 0; i + lag < n; i++) s += p[i] * p[i + lag];
		score[lag] = s / (n - lag);
	}
	const best = Math.max(...score.filter((v) => v !== undefined));
	for (let lag = lo; lag <= hi; lag++) if (score[lag] >= best * 0.85) return refine(p, lag);
	return lo;
}

// a fractional cell size near the integer lag: the one whose multiples hit the most edge energy
function refine(p, lag) {
	let best = lag;
	let bestScore = -Infinity;
	for (let s = lag - 0.9; s <= lag + 0.9; s += 0.05) {
		const { score } = phase(p, s);
		if (score > bestScore) [best, bestScore] = [s, score];
	}
	return best;
}

function phase(profile, size) {
	let best = 0;
	let bestScore = -Infinity;
	for (let o = 0; o < size; o += 0.25) {
		let s = 0;
		for (let x = o; x < profile.length; x += size) s += profile[Math.round(x)] || 0;
		if (s > bestScore) [best, bestScore] = [o, s];
	}
	return { offset: best, score: bestScore };
}

async function grid(id) {
	const { data, info } = await sharp(path.join(DIR, id + ".png"))
		.ensureAlpha()
		.raw()
		.toBuffer({ resolveWithObject: true });
	const W = info.width;
	const H = info.height;
	const at = (x, y) => {
		const i = (y * W + x) * 4;
		return [data[i], data[i + 1], data[i + 2], data[i + 3]];
	};
	let cx, cy, ox, oy, cols, rows;
	if (W === 128 && H === 128) {
		[cx, cy, ox, oy, cols, rows] = [8, 8, 0, 0, 16, 16];
	} else {
		// colour jumps between neighbours (alpha counts as a colour)
		const colP = new Array(W).fill(0);
		const rowP = new Array(H).fill(0);
		for (let y = 0; y < H - 1; y++)
			for (let x = 0; x < W - 1; x++) {
				const a = at(x, y);
				const r = at(x + 1, y);
				const d = at(x, y + 1);
				const jump = (q) => Math.abs(a[0] - q[0]) + Math.abs(a[1] - q[1]) + Math.abs(a[2] - q[2]) + Math.abs(a[3] - q[3]);
				colP[x + 1] += jump(r);
				rowP[y + 1] += jump(d);
			}
		const s = CELL || (period(colP, 6, 48) + period(rowP, 6, 48)) / 2; // square pixels
		cx = cy = s;
		ox = phase(colP, s).offset;
		oy = phase(rowP, s).offset;
		cols = Math.floor((W - ox) / s);
		rows = Math.floor((H - oy) / s);
	}
	// each cell: the most common colour of its inner 60 %
	const px = [];
	for (let r = 0; r < rows; r++)
		for (let c = 0; c < cols; c++) {
			const x0 = ox + c * cx;
			const y0 = oy + r * cy;
			const votes = new Map();
			let opaque = 0;
			let total = 0;
			for (let y = Math.ceil(y0 + cy * 0.2); y < y0 + cy * 0.8; y++)
				for (let x = Math.ceil(x0 + cx * 0.2); x < x0 + cx * 0.8; x++) {
					if (x >= W || y >= H) continue;
					const [R, G, B, A] = at(x, y);
					total++;
					if (A < 128) continue;
					opaque++;
					const k = hex(R & 0xf8, G & 0xf8, B & 0xf8);
					const v = votes.get(k) || { n: 0, r: 0, g: 0, b: 0 };
					v.n++;
					v.r += R;
					v.g += G;
					v.b += B;
					votes.set(k, v);
				}
			if (total === 0 || opaque * 2 < total) {
				px.push("");
				continue;
			}
			const v = [...votes.values()].sort((a, b) => b.n - a.n)[0];
			px.push(hex(Math.round(v.r / v.n), Math.round(v.g / v.n), Math.round(v.b / v.n)));
		}
	// crop to the drawn cells
	let [minX, minY, maxX, maxY] = [cols, rows, -1, -1];
	for (let r = 0; r < rows; r++)
		for (let c = 0; c < cols; c++)
			if (px[r * cols + c]) [minX, minY, maxX, maxY] = [Math.min(minX, c), Math.min(minY, r), Math.max(maxX, c), Math.max(maxY, r)];
	const fixed = W === 128 && H === 128; // keep the 16×16 frame of drawn sprites
	if (!fixed) {
		const w = maxX - minX + 1;
		const h = maxY - minY + 1;
		const out = [];
		for (let r = minY; r <= maxY; r++) for (let c = minX; c <= maxX; c++) out.push(px[r * cols + c]);
		return { w, h, cell: Math.round(cx * 100) / 100, px: out };
	}
	return { w: cols, h: rows, px };
}

// the clean sprite: every cell a square of hard pixels, centred on a square canvas with a thin margin
async function writeSprite(id, g) {
	const n = Math.max(g.w, g.h) + 2 * Math.max(0, Math.round(Math.max(g.w, g.h) / 16));
	const k = Math.max(1, Math.floor(256 / n));
	const size = n * k;
	const buf = Buffer.alloc(size * size * 4);
	const ox = Math.floor((n - g.w) / 2);
	const oy = Math.floor((n - g.h) / 2);
	g.px.forEach((col, i) => {
		if (!col) return;
		const [r, gg, b] = [0, 2, 4].map((o) => parseInt(col.slice(o, o + 2), 16));
		const cx = (ox + (i % g.w)) * k;
		const cy = (oy + Math.floor(i / g.w)) * k;
		for (let y = 0; y < k; y++)
			for (let x = 0; x < k; x++) {
				const j = ((cy + y) * size + cx + x) * 4;
				[buf[j], buf[j + 1], buf[j + 2], buf[j + 3]] = [r, gg, b, 255];
			}
	});
	await sharp(buf, { raw: { width: size, height: size, channels: 4 } })
		.png()
		.toFile(path.join(ROOT, "assets/icons/items", id + ".png"));
}

const all = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, "utf8")) : {};
for (const id of ids) {
	all[id] = await grid(id);
	console.log(id, all[id].w + "×" + all[id].h, all[id].cell ? "cell " + all[id].cell : "");
	if (WRITE) await writeSprite(id, all[id]);
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, "{\n" + Object.keys(all).sort().map((k) => JSON.stringify(k) + ":" + JSON.stringify(all[k])).join(",\n") + "\n}\n");
