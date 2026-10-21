// Derives the missing block textures from our own ones (assets/textures/blocks, Codex pixel art 20.10),
// so the new blocks keep the same look [владелец 22.10: «где текстуры угольного блока и руды?»]:
//   gold_ore   = coal_ore with the dark lumps recoloured to gold;
//   coal_block = stone remapped to a dark anthracite range with a faint blue sheen.
// Usage: node scripts/derive-block-textures.mjs  → assets/textures/blocks/<id>.png (then upload_image → ids.json)
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const sharpPath = process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp");
const sharp = require(fs.existsSync(sharpPath) ? sharpPath : "sharp");
const dir = path.join(root, "assets/textures/blocks");

async function remap(src, dst, fn) {
	const { data, info } = await sharp(path.join(dir, src)).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	for (let i = 0; i < data.length; i += 4) {
		const [r, g, b] = fn(data[i], data[i + 1], data[i + 2]);
		data[i] = r; data[i + 1] = g; data[i + 2] = b;
	}
	await sharp(data, { raw: info }).png().toFile(path.join(dir, dst));
	console.log("wrote", dst);
}
const lum = (r, g, b) => 0.299 * r + 0.587 * g + 0.114 * b;
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));

// gold ore: the coal lumps (dark pixels) become gold, the stone stays
await remap("coal_ore.png", "gold_ore.png", (r, g, b) => {
	const l = lum(r, g, b);
	if (l > 95) return [r, g, b];
	const k = l / 95; // 0 (darkest) .. 1
	return [clamp(150 + 105 * k), clamp(105 + 110 * k), clamp(20 + 40 * k)];
});
// coal block: the stone pattern stretched into a dark anthracite range (contrast kept, faint blue sheen)
await remap("stone.png", "coal_block.png", (r, g, b) => {
	const n = Math.max(0, Math.min(1, (lum(r, g, b) / 255 - 0.42) / 0.36)); // stone spans ~0.42..0.78
	const v = 10 + 78 * n * n;
	return [clamp(v), clamp(v + 3), clamp(v + 10)];
});
