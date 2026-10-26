// Inventory icons of our armor: our own 16×16 pixel sprites in the item style the owner showed [владелец 27.10, the
// Minecraft armor icons as the example]: a dark outline, light from the upper left, the helmet as a cap round the face
// opening, the chestplate with shoulders and a neck notch, the leggings as a waistband on two legs, a pair of boots.
// The shapes are drawn below (K = outline, 1 … 5 = the material's shades from assets/models/armor/armor.py PALETTES,
// "." = open), not copied from any texture; each material only recolours them, the chainmail adds its mesh of dark
// links, the diamond a sparkle.
// Usage: node scripts/armor-icons.mjs → assets/icons/armor/<piece>_<material>.png (128×128, ×8, transparent), and the
// same sprites as the 3D item held in the hand: assets/icons/voxels.json <piece>_<material> (same-colour rectangles).
// sharp: SHARP_PATH or the old scratchpad's imgtools (as scripts/model-tools).
import { createRequire } from "node:module";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const require = createRequire(import.meta.url);
const sharp = require(
	process.env.SHARP_PATH ||
		join(
			process.env.LOCALAPPDATA || "",
			"Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp",
		),
);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(root, "assets", "icons", "armor");
mkdirSync(out, { recursive: true });

// shades 0 … 5 as in armor.py (0 is not used here: the outline is darker than any shade)
const PALETTES = {
	wood: ["#3a2213", "#5b3920", "#744a2a", "#8d5b34", "#a7703f", "#c2874f"],
	stone: ["#2b2e32", "#4b4f55", "#6b7077", "#8e939a", "#b2b6bc", "#d2d5d9"],
	iron: ["#3e4144", "#6a6e72", "#8e9296", "#b3b7ba", "#d4d7d9", "#eff1f2"],
	diamond: ["#0d4850", "#197784", "#25a0ab", "#3dc5cd", "#80e2e5", "#cbfbfb"],
};
const OUTLINE = "#141414";
const SPARKLE = "#f4ffff";

// narrow and tall like the Minecraft item sprites [владелец 27.10: «иконки брони слишком широкие … сделай их длиннее и уже»]
const SHAPES = {
	helmet: [
		"....KKKKKKKK....",
		"...K55544443K...",
		"...K54444332K...",
		"...K44333322K...",
		"...K43333221K...",
		"...K43322221K...",
		"...K4KKKKKK1K...",
		"...K4K....K1K...",
		"...K3K....K1K...",
		"...KKK....KKK...",
	],
	chestplate: [
		"..KKKK....KKKK..",
		"..K554KKKK433K..",
		"..K5544444332K..",
		"..K5443333322K..",
		"..KK43333332KK..",
		"...K43333322K...",
		"...K43333221K...",
		"...K43332221K...",
		"...K33332221K...",
		"...K33322211K...",
		"...K33222211K...",
		"...K32222211K...",
		"...KKKKKKKKKK...",
	],
	leggings: [
		"...KKKKKKKKKK...",
		"...K55444433K...",
		"...K54433322K...",
		"...K443KK322K...",
		"...K43K..K21K...",
		"...K43K..K21K...",
		"...K43K..K21K...",
		"...K43K..K21K...",
		"...K33K..K21K...",
		"...K33K..K11K...",
		"...K32K..K11K...",
		"...K32K..K11K...",
		"...K32K..K11K...",
		"...KKKK..KKKK...",
	],
	boots: [
		"..KKKK....KKKK..",
		"..K54K....K43K..",
		"..K43K....K32K..",
		"..K43K....K32K..",
		"..K43K....K32K..",
		".KK43K....K32KK.",
		".K543K....K321K.",
		".K432K....K211K.",
		".KKKKK....KKKKK.",
	],
};

function hex(h) {
	return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
}

// same-colour runs of a 16×16 grid of hex colours (null = open) merged into rectangles: [x, y, w, h, paletteIndex, …]
function rectangles(grid) {
	const p = [];
	const r = [];
	const done = new Set();
	for (let y = 0; y < 16; y++) {
		for (let x = 0; x < 16; x++) {
			const c = grid[y][x];
			if (!c || done.has(y * 16 + x)) continue;
			let w = 1;
			while (x + w < 16 && grid[y][x + w] === c && !done.has(y * 16 + x + w)) w++;
			let h = 1;
			while (y + h < 16 && [...Array(w).keys()].every((i) => grid[y + h][x + i] === c && !done.has((y + h) * 16 + x + i))) h++;
			for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) done.add((y + j) * 16 + x + i);
			if (!p.includes(c)) p.push(c);
			r.push(x, y, w, h, p.indexOf(c));
		}
	}
	return { w: 16, h: 16, p, r };
}

const voxelsPath = join(root, "assets", "icons", "voxels.json");
const voxels = JSON.parse(readFileSync(voxelsPath, "utf8"));

for (const material of Object.keys(PALETTES)) {
	const shades = PALETTES[material];
	for (const [piece, rows] of Object.entries(SHAPES)) {
		const top = Math.floor((16 - rows.length) / 2);
		const px = Buffer.alloc(16 * 16 * 4);
		let sparkled = false;
		const grid = Array.from({ length: 16 }, () => Array(16).fill(null));
		rows.forEach((row, ry) => {
			[...row].forEach((ch, x) => {
				if (ch === ".") return;
				const y = ry + top;
				let colour;
				if (ch === "K") colour = OUTLINE;
				else {
					let shade = Number(ch);
					// the chainmail's mesh: every other pixel a dark link, the rest the shaded rings
					if (material === "stone" && (x + y) % 2 === 0) shade = Math.max(1, shade - 2);
					colour = shades[shade];
					if (material === "diamond" && ch === "5" && !sparkled) {
						colour = SPARKLE; // one sparkle in the brightest corner
						sparkled = true;
					}
				}
				grid[y][x] = colour.slice(1).toUpperCase();
				const [r, g, b] = hex(colour);
				px.set([r, g, b, 255], (y * 16 + x) * 4);
			});
		});
		await sharp(px, { raw: { width: 16, height: 16, channels: 4 } })
			.resize(128, 128, { kernel: "nearest" })
			.png()
			.toFile(join(out, `${piece}_${material}.png`));
		voxels.items[`${piece}_${material}`] = rectangles(grid);
	}
}
writeFileSync(voxelsPath, JSON.stringify(voxels));
console.log("wrote", out);
