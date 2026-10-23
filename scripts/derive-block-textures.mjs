// Derives the missing block textures from our own ones (assets/textures/blocks, Codex pixel art 20.10),
// so the new blocks keep the same look [владелец 22.10: «где текстуры угольного блока и руды?»]:
//   gold_ore   = coal_ore with the dark lumps recoloured to gold;
//   coal_block = stone remapped to a dark anthracite range with a faint blue sheen;
//   iron_block / lapis_block / diamond_block = gold_block recoloured.
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
// [владелец 22.10: рудная шахта Подвала] iron / lapis / diamond blocks: our gold block's pattern (bevel, rivets,
// shine) with its brightness mapped onto each metal's dark → light range
function metal(dark, light) {
	return (r, g, b) => {
		const n = Math.max(0, Math.min(1, (lum(r, g, b) - 60) / 170));
		return dark.map((d, i) => clamp(d + (light[i] - d) * n));
	};
}
await remap("gold_block.png", "iron_block.png", metal([110, 110, 112], [235, 235, 235]));
await remap("gold_block.png", "lapis_block.png", metal([18, 40, 120], [80, 130, 230]));
await remap("gold_block.png", "diamond_block.png", metal([30, 140, 135], [190, 255, 245]));
// [Подножье горы, бедленды] red sand from our sand, red sandstone from our sandstone, and a pale neutral terracotta
// that the map tints into the strata colours (orange, red, yellow, white, brown bands)
await remap("sand.png", "red_sand.png", (r, g, b) => {
	const l = lum(r, g, b) / 255;
	return [clamp(120 + 125 * l), clamp(45 + 70 * l), clamp(15 + 35 * l)];
});
await remap("sandstone.png", "red_sandstone.png", (r, g, b) => {
	const l = lum(r, g, b) / 255;
	return [clamp(105 + 120 * l), clamp(40 + 70 * l), clamp(12 + 38 * l)];
});
await remap("terracotta.png", "terracotta_pale.png", (r, g, b) => {
	const l = lum(r, g, b);
	const v = clamp(150 + (l - 110) * 0.9);
	return [v, clamp(v * 0.96), clamp(v * 0.9)];
});

// [Преисподняя] the Nether set. Each source's brightness is normalised to its own 2..98 % range (t = 0..1), then
// mapped through a colour ramp, so the pattern (cracks, mortar, grain) of our own texture stays and only the
// palette changes. Lumps of coal ore become quartz / gold; the dark mortar of cobblestone becomes magma cracks.
async function lumRange(src) {
	const { data } = await sharp(path.join(dir, src)).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	const ls = [];
	for (let i = 0; i < data.length; i += 4) ls.push(lum(data[i], data[i + 1], data[i + 2]));
	ls.sort((a, b) => a - b);
	return [ls[Math.floor(ls.length * 0.02)], ls[Math.floor(ls.length * 0.98)]];
}
function ramp(stops, t) {
	t = Math.max(0, Math.min(1, t));
	for (let i = 1; i < stops.length; i++) {
		if (t <= stops[i][0]) {
			const [t0, c0] = stops[i - 1];
			const [t1, c1] = stops[i];
			const k = (t - t0) / (t1 - t0 || 1);
			return c0.map((c, j) => clamp(c + (c1[j] - c) * k));
		}
	}
	return stops[stops.length - 1][1].map(clamp);
}
async function recolor(src, dst, stops, gamma = 1) {
	const [lo, hi] = await lumRange(src);
	await remap(src, dst, (r, g, b) => ramp(stops, Math.pow((lum(r, g, b) - lo) / (hi - lo), gamma)));
}
const NETHERRACK = [[0, [62, 18, 20]], [0.45, [112, 36, 36]], [0.8, [150, 60, 56]], [1, [178, 86, 78]]];
// «Незерит» of the menu is the rough red Nether rock of the mine [меню: Незерит 75 % — the Nether stone]
await recolor("stone.png", "netherite.png", NETHERRACK);
await recolor("cobblestone.png", "netherrack_cobble.png", NETHERRACK, 0.9); // rubble, ruined walls
// quartz ore: the stone of coal ore → netherrack, the dark lumps → milky quartz
{
	const [lo, hi] = await lumRange("coal_ore.png");
	await remap("coal_ore.png", "quartz_ore.png", (r, g, b) => {
		const l = lum(r, g, b);
		if (l > 95) return ramp(NETHERRACK, (l - 95) / (hi - 95));
		return ramp([[0, [196, 184, 170]], [0.6, [232, 224, 212]], [1, [250, 246, 238]]], (l - lo) / (95 - lo));
	});
	await remap("coal_ore.png", "gilded_blackstone.png", (r, g, b) => {
		const l = lum(r, g, b);
		if (l > 95) return ramp([[0, [22, 18, 24]], [1, [70, 62, 74]]], (l - 95) / (hi - 95));
		return ramp([[0, [170, 110, 20]], [1, [255, 214, 80]]], (l - lo) / (95 - lo));
	});
}
await recolor("gravel.png", "soul_sand.png", [[0, [40, 28, 22]], [0.5, [78, 58, 46]], [1, [120, 96, 78]]]);
await recolor("dirt.png", "soul_soil.png", [[0, [44, 32, 26]], [0.6, [76, 58, 46]], [1, [100, 80, 64]]]);
await recolor("red_brick.png", "nether_bricks.png", [[0, [22, 10, 14]], [0.5, [52, 22, 28]], [1, [86, 38, 44]]]);
await recolor("stone_bricks.png", "blackstone_bricks.png", [[0, [16, 14, 18]], [0.55, [42, 38, 46]], [1, [74, 68, 80]]]);
await recolor("cobblestone.png", "blackstone.png", [[0, [14, 12, 16]], [0.5, [38, 34, 42]], [1, [70, 64, 76]]]);
await recolor("stone.png", "basalt.png", [[0, [40, 40, 44]], [0.5, [78, 78, 84]], [1, [124, 124, 130]]]);
await recolor("sand.png", "glowstone.png", [[0, [150, 96, 40]], [0.4, [214, 160, 70]], [0.8, [250, 214, 120]], [1, [255, 240, 180]]], 0.8);
await recolor("stone.png", "obsidian.png", [[0, [8, 5, 14]], [0.6, [26, 16, 40]], [0.92, [60, 36, 92]], [1, [110, 80, 150]]], 1.4);
await recolor("grass_top.png", "crimson_nylium.png", [[0, [70, 8, 12]], [0.5, [130, 22, 26]], [1, [190, 50, 50]]]);
await recolor("grass_top.png", "warped_nylium.png", [[0, [12, 60, 58]], [0.5, [24, 110, 100]], [1, [50, 170, 150]]]);
await recolor("oak_log_side.png", "crimson_stem.png", [[0, [48, 16, 30]], [0.5, [100, 34, 56]], [1, [160, 70, 90]]]);
await recolor("oak_log_side.png", "warped_stem.png", [[0, [20, 40, 46]], [0.5, [44, 90, 96]], [1, [80, 150, 150]]]);
await recolor("white_wool.png", "nether_wart.png", [[0, [80, 4, 6]], [0.5, [130, 12, 14]], [1, [180, 36, 30]]]);
await recolor("white_wool.png", "warped_wart.png", [[0, [10, 80, 76]], [0.5, [20, 128, 116]], [1, [60, 180, 160]]]);
await recolor("hay.png", "shroomlight.png", [[0, [190, 90, 30]], [0.5, [240, 150, 60]], [1, [255, 214, 140]]]);
await recolor("water.png", "lava.png", [[0, [190, 50, 10]], [0.45, [240, 110, 20]], [0.8, [255, 170, 40]], [1, [255, 230, 120]]]);
// [Пирамида] cut sandstone (the sandstone pattern flattened into a narrow light range), its red twin, a
// lapis-blue glazed terracotta for the tomb's painted bands, and a hieroglyph panel: our own glyphs (an eye,
// a bird, an ankh-like key, water, a beetle, a reed) drawn as pixel masks over the cut sandstone
await recolor("sandstone.png", "cut_sandstone.png", [[0, [196, 176, 120]], [0.5, [222, 204, 150]], [1, [238, 224, 176]]], 0.6);
await recolor("red_sandstone.png", "cut_red_sandstone.png", [[0, [150, 70, 30]], [0.5, [182, 92, 44]], [1, [206, 116, 62]]], 0.6);
await recolor("terracotta.png", "terracotta_blue.png", [[0, [20, 40, 100]], [0.5, [40, 76, 160]], [1, [90, 130, 210]]]);
{
	const G = [
		["................", "................", "....XXXXXXXX....", "..XX........XX..", ".X....XXXX....X.", "X....XX..XX....X", ".X....XXXX....X.", "..XX........XX..", "....XXXXXXXX....", ".......X........", "......X.X.......", ".....X...X......", "....X.....XX....", "................", "................", "................"],
		["................", "......XX........", ".....XXXX.......", "....XX.XX.......", "......XXX.......", ".....XXXXX......", "....XXXXXXX.....", "...XXXXXXXXX....", "..XXXXXXXXXXX...", "......XXXXXXXX..", "......X..X......", "......X..X......", ".....XX..XX.....", "................", "................", "................"],
		["................", "......XXXX......", ".....X....X.....", ".....X....X.....", "......X..X......", ".......XX.......", "..XXXXXXXXXXXX..", ".......XX.......", ".......XX.......", ".......XX.......", ".......XX.......", ".......XX.......", "......XXXX......", "................", "................", "................"],
		["................", "................", "................", ".X...X...X...X..", "X.X.X.X.X.X.X.X.", "...X...X...X...X", "................", ".X...X...X...X..", "X.X.X.X.X.X.X.X.", "...X...X...X...X", "................", ".X...X...X...X..", "X.X.X.X.X.X.X.X.", "...X...X...X...X", "................", "................"],
		["................", "...X........X...", "....X..XX..X....", ".....XXXXXX.....", "....XXXXXXXX....", "...XX.XXXX.XX...", "..X..XXXXXX..X..", ".....XXXXXX.....", "..X..XXXXXX..X..", "...XX.XXXX.XX...", "....XXXXXXXX....", ".....XXXXXX.....", "......XXXX......", "................", "................", "................"],
		["................", ".......X........", "......XXX.......", ".....X.X.X......", ".......X........", "....X..X..X.....", ".....X.X.X......", "......XXX.......", ".......X........", ".......X........", ".......X........", ".......X........", "......XXX.......", "................", "................", "................"],
	];
	const base = await sharp(path.join(dir, "cut_sandstone.png")).resize(48, 48, { kernel: "nearest" }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	const { data, info } = base;
	for (let g = 0; g < 9; g++) {
		const ox = (g % 3) * 16, oy = Math.floor(g / 3) * 16;
		for (let y = 0; y < 16; y++) {
			for (let x = 0; x < 16; x++) {
				const i = ((oy + y) * info.width + ox + x) * 4;
				if (G[(g + Math.floor(g / 3)) % 6][y][x] === "X") {
					data[i] = 96; data[i + 1] = 66; data[i + 2] = 34;
				} else if (y === 0 || y === 15 || x === 0) {
					data[i] = 176; data[i + 1] = 150; data[i + 2] = 96; // the carved frame lines between glyphs
				}
			}
		}
	}
	await sharp(data, { raw: info }).resize(384, 384, { kernel: "nearest" }).png().toFile(path.join(dir, "hieroglyphs.png"));
	console.log("wrote hieroglyphs.png");
}
// [Королевский сад] wisteria leaves (the mine block: pink-violet), cherry leaves, clipped hedge, cherry bark and
// planks, white palace stone — the leafy ones from our grass top, the wood from our oak and planks
await recolor("grass_top.png", "wisteria_leaves.png", [[0, [120, 60, 130]], [0.45, [190, 110, 190]], [0.8, [230, 160, 220]], [1, [250, 205, 240]]]);
await recolor("grass_top.png", "cherry_leaves.png", [[0, [200, 100, 140]], [0.5, [240, 160, 190]], [1, [255, 215, 230]]]);
await recolor("grass_top.png", "hedge.png", [[0, [24, 60, 26]], [0.5, [44, 96, 40]], [1, [80, 140, 64]]]);
await recolor("oak_log_side.png", "cherry_log.png", [[0, [38, 18, 22]], [0.5, [70, 36, 40]], [1, [110, 66, 66]]]);
await recolor("planks.png", "cherry_planks.png", [[0, [170, 100, 96]], [0.5, [214, 150, 140]], [1, [240, 196, 184]]]);
await recolor("stone_bricks.png", "white_stone_bricks.png", [[0, [170, 170, 176]], [0.5, [222, 222, 226]], [1, [246, 246, 248]]]);
// [Затопленный маяк] cyan concrete (the mine block: a flat cyan with a faint grain), prismarine (teal, mottled),
// prismarine bricks, dark prismarine, sea lantern (pale glowing blue), a pale coral base the map tints
await recolor("concrete_floor.png", "cyan_concrete.png", [[0, [20, 110, 120]], [0.5, [30, 130, 140]], [1, [44, 150, 160]]], 0.7);
await recolor("cobblestone.png", "prismarine.png", [[0, [40, 90, 84]], [0.4, [70, 140, 126]], [0.75, [100, 170, 150]], [1, [140, 200, 180]]]);
await recolor("stone_bricks.png", "prismarine_bricks.png", [[0, [40, 96, 88]], [0.5, [84, 156, 140]], [1, [130, 196, 176]]]);
await recolor("stone_bricks.png", "dark_prismarine.png", [[0, [18, 44, 40]], [0.5, [36, 80, 70]], [1, [62, 116, 100]]]);
await recolor("glowstone.png", "sea_lantern.png", [[0, [120, 170, 180]], [0.5, [190, 225, 225]], [1, [245, 255, 250]]]);
await recolor("sand.png", "coral.png", [[0, [150, 150, 150]], [0.5, [210, 210, 210]], [1, [250, 250, 250]]]);
// [Пустотная крепость] end stone (the islands), end stone bricks and purpur (the mine blocks), a purpur pillar,
// chorus (the plants)
await recolor("cobblestone.png", "end_stone.png", [[0, [180, 176, 120]], [0.5, [218, 214, 160]], [1, [240, 238, 190]]], 0.8);
await recolor("stone_bricks.png", "end_stone_bricks.png", [[0, [170, 166, 112]], [0.5, [215, 212, 156]], [1, [238, 236, 186]]]);
await recolor("smooth_stone.png", "purpur.png", [[0, [120, 80, 120]], [0.5, [168, 120, 168]], [1, [200, 160, 200]]], 0.9);
await recolor("oak_log_side.png", "purpur_pillar.png", [[0, [124, 84, 124]], [0.5, [170, 124, 170]], [1, [206, 166, 206]]]);
await recolor("grass_top.png", "chorus.png", [[0, [70, 50, 80]], [0.5, [110, 84, 120]], [1, [170, 140, 175]]]);
// magma: the dark mortar of cobblestone glows, the stones stay dark
{
	const [lo, hi] = await lumRange("cobblestone.png");
	await remap("cobblestone.png", "magma.png", (r, g, b) => {
		const t = (lum(r, g, b) - lo) / (hi - lo);
		if (t < 0.3) return ramp([[0, [255, 190, 60]], [1, [220, 80, 20]]], t / 0.3);
		return ramp([[0, [90, 30, 16]], [1, [60, 18, 12]]], (t - 0.3) / 0.7);
	});
}
