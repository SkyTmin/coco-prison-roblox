// Our own block textures drawn in code (16×16 pixel art, ×20 nearest-neighbour → 320 px like the Codex
// block sheet): assets/textures/blocks/<id>.png, then upload_image → assets/textures/ids.json → build-configs.
// Usage: node scripts/draw-block-textures.mjs [id ...]   (needs sharp, see draw-icons.mjs)
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const sharpPath = process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp");
const sharp = require(fs.existsSync(sharpPath) ? sharpPath : "sharp");
const out = path.join(root, "assets/textures/blocks");
const N = 16;
const SCALE = 20;

// a small seeded generator, so the same picture comes out every run
function rng(seed) {
	let s = seed >>> 0;
	return () => {
		s = (s * 1664525 + 1013904223) >>> 0;
		return s / 4294967296;
	};
}

const TEXTURES = {
	// Верх арбуза [владелец 22.10, скриншот Малой шахты: сверху арбуз светло-жёлто-зелёный с прожилками от
	// середины]: a light centre, dark green veins running out to the corners and the edge middles, a darker rim
	melon_top: () => {
		const r = rng(7);
		const light = [0xb4, 0xd0, 0x3c];
		const mid = [0x8c, 0xb8, 0x2e];
		const vein = [0x52, 0x8c, 0x22];
		const rim = [0x6a, 0x9e, 0x26];
		const grid = [];
		for (let i = 0; i < N * N; i++) grid.push(r() < 0.55 ? light : mid);
		// veins: lines from the middle out to the four corners and the four edge middles
		const ends = [[0, 0], [15, 0], [0, 15], [15, 15], [7.5, 0], [7.5, 15], [0, 7.5], [15, 7.5]];
		for (const [ex, ey] of ends) {
			for (let t = 0.18; t <= 1; t += 0.02) {
				const x = Math.round(7.5 + (ex - 7.5) * t);
				const y = Math.round(7.5 + (ey - 7.5) * t);
				grid[y * N + x] = vein;
			}
		}
		for (let y = 0; y < N; y++)
			for (let x = 0; x < N; x++)
				if (x === 0 || y === 0 || x === N - 1 || y === N - 1) grid[y * N + x] = r() < 0.65 ? rim : vein;
		for (const [x, y] of [[7, 7], [8, 7], [7, 8], [8, 8]]) grid[y * N + x] = light;
		const px = grid;
		return px;
	},
};

const want = process.argv.slice(2);
for (const [id, draw] of Object.entries(TEXTURES)) {
	if (want.length && !want.includes(id)) continue;
	const px = draw();
	const S = N * SCALE;
	const buf = Buffer.alloc(S * S * 3);
	for (let y = 0; y < S; y++)
		for (let x = 0; x < S; x++) {
			const c = px[Math.floor(y / SCALE) * N + Math.floor(x / SCALE)];
			buf.set(c, (y * S + x) * 3);
		}
	await sharp(buf, { raw: { width: S, height: S, channels: 3 } }).png().toFile(path.join(out, id + ".png"));
	console.log("wrote", path.join("assets/textures/blocks", id + ".png"));
}
