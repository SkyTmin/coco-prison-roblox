// Splits assets/textures/faction-blocks-sheet.png (Codex image gen 22.10.2026, 4×4 grid, the style of our
// prison-blocks-sheet) into assets/textures/blocks/<id>.png, full resolution like the other block textures — the new
// blocks of the faction base (База фракций). Usage: node scripts/split-faction-sheet.mjs, then upload_image →
// assets/textures/ids.json → node scripts/build-configs.mjs → scripts/build-textures.luau.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const sharpPath = process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp");
const sharp = require(fs.existsSync(sharpPath) ? sharpPath : "sharp");

const IDS = [
	["stone_bricks", "mossy_cobblestone", "mossy_stone_bricks", "smooth_stone"],
	["white_wool", "yellow_wool", "brown_wool", "gray_wool"],
	["birch_log", "spruce_planks", "dark_oak_planks", "terracotta"],
	["sandstone", "hay", "roof_tiles", "gold_block"],
];
const sheet = path.join(root, "assets/textures/faction-blocks-sheet.png");
const { width, height } = await sharp(sheet).metadata();
const cw = width / 4, ch = height / 4;
const inset = 3; // trims a stray seam pixel at the cell borders
for (let r = 0; r < 4; r++) {
	for (let c = 0; c < 4; c++) {
		const left = Math.round(c * cw) + inset, top = Math.round(r * ch) + inset;
		const w = Math.floor(cw) - 2 * inset, h = Math.floor(ch) - 2 * inset;
		const out = path.join(root, "assets/textures/blocks", IDS[r][c] + ".png");
		await sharp(sheet).extract({ left, top, width: w, height: h }).png().toFile(out);
		console.log("wrote", IDS[r][c]);
	}
}
