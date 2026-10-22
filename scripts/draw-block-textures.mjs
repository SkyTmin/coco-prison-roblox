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
	// Листья дуба [владелец 22.10: в малой шахте должна быть листва]: clumps of leaves in four greens with dark
	// gaps between them (opaque — the "fast graphics" look of Minecraft leaves)
	oak_leaves: () => {
		const r = rng(42);
		const greens = [
			[0x2e, 0x5c, 0x1f],
			[0x3d, 0x74, 0x28],
			[0x4c, 0x8a, 0x30],
			[0x5f, 0xa0, 0x3a],
		];
		const gap = [0x1c, 0x36, 0x13];
		// clumps: random 3×3 cells (wrapping, so the tile repeats seamlessly) pick a tone, texels vary around it
		const cells = Array.from({ length: 36 }, () => Math.floor(r() * 4));
		const px = [];
		for (let y = 0; y < N; y++) {
			for (let x = 0; x < N; x++) {
				const clump = cells[(Math.floor(((y + (x % 3)) % N) / 3) % 6) * 6 + (Math.floor(x / 3) % 6)];
				let c;
				if (r() < 0.16) c = gap;
				else c = greens[Math.max(0, Math.min(3, clump + (r() < 0.5 ? 0 : r() < 0.5 ? -1 : 1)))];
				px.push(c);
			}
		}
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
