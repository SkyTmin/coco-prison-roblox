// Cut a Codex icon sheet into item sprites [владелец 27.10: «пробуй кодекс»; «кодекс нарисовал слишком мультяшно» →
// the sheets are asked for in the blocky item-sprite style of our tool icons, on a flat #FF00FF background].
// The magenta background and its anti-aliased fringe become transparent, the sheet is cut into cols × rows cells and
// each cell is cropped to its drawing: assets/icons/codex/cells/<name>.png. Then
// `node scripts/sprite-grids.mjs <names> --dir assets/icons/codex/cells --write` reads the pixel grid and writes the
// clean sprites into assets/icons/items.
// Usage: node scripts/split-codex-sheet.mjs <sheet.png> <cols> <rows> <name,name,…> ("-" skips a cell)
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
const OUT = path.join(ROOT, "assets/icons/codex/cells");
const [sheet, colsArg, rowsArg, namesArg] = process.argv.slice(2);
const cols = +colsArg;
const rows = +rowsArg;
const names = namesArg.split(",");

const { data, info } = await sharp(sheet).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const W = info.width;
const H = info.height;
// background: magenta and the pink/purple blend at the drawing's edge
for (let i = 0; i < data.length; i += 4) {
	const [r, g, b] = [data[i], data[i + 1], data[i + 2]];
	if (Math.min(r, b) - g > 90 && Math.abs(r - b) < 40) data[i + 3] = 0; // purple items keep b ≫ r
}
fs.mkdirSync(OUT, { recursive: true });
const cw = W / cols;
const ch = H / rows;
for (let n = 0; n < names.length; n++) {
	if (names[n] === "-") continue;
	const c0 = Math.round((n % cols) * cw);
	const r0 = Math.round(Math.floor(n / cols) * ch);
	const w = Math.round(cw);
	const h = Math.round(ch);
	let [minX, minY, maxX, maxY] = [w, h, -1, -1];
	for (let y = 0; y < h; y++)
		for (let x = 0; x < w; x++) {
			const X = c0 + x;
			const Y = r0 + y;
			if (X < W && Y < H && data[(Y * W + X) * 4 + 3] > 0)
				[minX, minY, maxX, maxY] = [Math.min(minX, x), Math.min(minY, y), Math.max(maxX, x), Math.max(maxY, y)];
		}
	if (maxX < 0) {
		console.log(names[n], "empty");
		continue;
	}
	const cw2 = maxX - minX + 1;
	const ch2 = maxY - minY + 1;
	const out = Buffer.alloc(cw2 * ch2 * 4);
	for (let y = 0; y < ch2; y++)
		data.copy(out, y * cw2 * 4, ((r0 + minY + y) * W + c0 + minX) * 4, ((r0 + minY + y) * W + c0 + minX + cw2) * 4);
	await sharp(out, { raw: { width: cw2, height: ch2, channels: 4 } })
		.png()
		.toFile(path.join(OUT, names[n] + ".png"));
	console.log(names[n], cw2 + "×" + ch2);
}
