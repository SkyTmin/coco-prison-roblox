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
// [Паучье логово] our own cobweb, drawn as pixel lines: the mine block «Паутина» (white strands over a dark
// stone shadow, 32 px grid ×12), two transparent decals for the decor — an orb web (64 px ×8) and a corner web
// anchored at the top-left (a quarter fan) — used as Decals on invisible plates; a dark oak bark and a
// moss-dark forest floor for the location
{
	function web(n, cx, cy, spokes, rings, rng, startA = 0, endA = Math.PI * 2) {
		const px = new Uint8Array(n * n);
		const plot = (x, y) => {
			x = Math.round(x); y = Math.round(y);
			if (x >= 0 && y >= 0 && x < n && y < n) px[y * n + x] = 1;
		};
		const line = (x0, y0, x1, y1) => {
			const steps = Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))) + 1;
			for (let s = 0; s <= steps; s++) plot(x0 + (x1 - x0) * s / steps, y0 + (y1 - y0) * s / steps);
		};
		const full = endA - startA >= Math.PI * 2 - 1e-6;
		const angles = [];
		for (let k = 0; k < spokes; k++) angles.push(startA + (endA - startA) * (full ? k / spokes : k / (spokes - 1)) + (rng() - 0.5) * 0.12);
		const reach = n * 1.5;
		for (const a of angles) line(cx, cy, cx + Math.cos(a) * reach, cy + Math.sin(a) * reach);
		for (const r of rings) {
			const pts = angles.map((a) => { const rr = r * (0.92 + rng() * 0.16); return [cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]; });
			for (let k = 0; k < pts.length - (full ? 0 : 1); k++) {
				const [x0, y0] = pts[k], [x1, y1] = pts[(k + 1) % pts.length];
				// the thread sags a little between the spokes
				const mx = (x0 + x1) / 2 + (cx - (x0 + x1) / 2) * 0.08, my = (y0 + y1) / 2 + (cy - (y0 + y1) / 2) * 0.08;
				line(x0, y0, mx, my); line(mx, my, x1, y1);
			}
		}
		return px;
	}
	let seed = 1717;
	const rng = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
	// the block
	{
		const n = 32;
		const base = await sharp(path.join(dir, "stone.png")).resize(n, n, { kernel: "nearest" }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
		const { data, info } = base;
		const mask = web(n, 15.5, 15.5, 8, [6, 11.5, 17], rng);
		for (let i = 0; i < n * n; i++) {
			const l = lum(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]) / 255;
			const c = mask[i] ? [236 + 14 * l, 236 + 14 * l, 242 + 10 * l] : [38 + 34 * l, 38 + 34 * l, 46 + 36 * l];
			data[i * 4] = clamp(c[0]); data[i * 4 + 1] = clamp(c[1]); data[i * 4 + 2] = clamp(c[2]);
		}
		await sharp(data, { raw: info }).resize(384, 384, { kernel: "nearest" }).png().toFile(path.join(dir, "cobweb.png"));
		console.log("wrote cobweb.png");
	}
	// the decals (transparent)
	const decalDir = path.join(root, "assets/textures/decals");
	fs.mkdirSync(decalDir, { recursive: true });
	for (const [name, mask, n] of [
		["web_orb.png", web(64, 31.5, 31.5, 12, [4, 8, 12.5, 17, 21.5, 26, 30.5], rng), 64],
		["web_corner.png", web(64, 0, 0, 7, [8, 16, 25, 34, 44, 54], rng, 0, Math.PI / 2), 64],
	]) {
		const data = Buffer.alloc(n * n * 4);
		for (let i = 0; i < n * n; i++) {
			if (mask[i]) {
				data[i * 4] = 245; data[i * 4 + 1] = 245; data[i * 4 + 2] = 250; data[i * 4 + 3] = 225;
			}
		}
		await sharp(data, { raw: { width: n, height: n, channels: 4 } }).resize(n * 8, n * 8, { kernel: "nearest" }).png().toFile(path.join(decalDir, name));
		console.log("wrote", name);
	}
}
await recolor("oak_log_side.png", "dark_oak_log.png", [[0, [30, 20, 12]], [0.5, [56, 40, 26]], [1, [90, 68, 46]]]);
await recolor("grass_top.png", "forest_floor.png", [[0, [26, 34, 20]], [0.5, [44, 56, 32]], [1, [70, 84, 50]]]);
// [Рынок] red wool: our white wool is nearly flat, tinted red it blurred into a carpet in the game (Studio 26.10) —
// the higher-contrast pattern of our yellow wool on a red ramp instead
await recolor("yellow_wool.png", "red_wool.png", [[0, [110, 22, 18]], [0.5, [168, 36, 30]], [1, [214, 64, 54]]]);
// [Лепреконовая долина] yellow concrete: our smooth stone tinted yellow read as dull mustard tiles with frames (Studio
// 26.10) — our concrete floor on a bright yellow ramp, like the cyan concrete
await recolor("concrete_floor.png", "yellow_concrete.png", [[0, [214, 150, 14]], [0.5, [238, 178, 24]], [1, [250, 200, 52]]], 0.7);
// Замок: the quartz mine block — a warm white of our own (the white tint over smooth stone read as grey concrete)
await recolor("smooth_stone.png", "quartz_block.png", [[0, [200, 194, 182]], [0.5, [230, 225, 214]], [1, [248, 245, 236]]], 0.8);
// Киото / Ферма: the tinted wool and hay read flat or wrong on the floors checked in Studio (red wool, yellow concrete,
// quartz) — our own ramps from the start: pink and green wool on our yellow wool's pattern, the pumpkin drawn
await recolor("yellow_wool.png", "pink_wool.png", [[0, [186, 88, 128]], [0.5, [230, 138, 174]], [1, [248, 188, 212]]]);
await recolor("yellow_wool.png", "green_wool.png", [[0, [50, 74, 18]], [0.5, [82, 110, 30]], [1, [112, 142, 48]]]);
// the pumpkin: our hay read as diagonal straw — 16×16 texels of vertical ribs (a groove every 4 columns, a lit crest
// between), a seeded ±noise per texel, scaled up pixel-sharp like the other blocks
{
	const N = 16;
	const S = 19; // 304 px
	let seed = 20261026;
	const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
	const rib = [[150, 70, 10], [206, 116, 22], [232, 148, 40], [214, 126, 28]];
	const data = Buffer.alloc(N * S * N * S * 4);
	for (let y = 0; y < N; y++) {
		for (let x = 0; x < N; x++) {
			const k = 0.9 + rnd() * 0.2 - (y === 0 || y === N - 1 ? 0.08 : 0);
			const c = rib[x % 4].map((v) => Math.max(0, Math.min(255, Math.round(v * k))));
			for (let yy = 0; yy < S; yy++) {
				for (let xx = 0; xx < S; xx++) {
					const i = ((y * S + yy) * N * S + x * S + xx) * 4;
					data[i] = c[0];
					data[i + 1] = c[1];
					data[i + 2] = c[2];
					data[i + 3] = 255;
				}
			}
		}
	}
	await sharp(data, { raw: { width: N * S, height: N * S, channels: 4 } }).png().toFile(path.join(dir, "pumpkin.png"));
	console.log("wrote pumpkin.png");
}
// Изнанка: dark oak leaves — our hedge darkened by a tint read as a black pit in the red dusk (Studio 26.10)
await recolor("grass_top.png", "dark_oak_leaves.png", [[0, [22, 50, 20]], [0.5, [40, 80, 32]], [1, [72, 118, 52]]]);
// Амбар: the jack o'lantern — our pumpkin ribs with a carved face glowing from inside (triangle eyes, a nose, a
// toothy grin); a MaterialVariant shows it on every side, so the mine is a field of grinning lanterns
{
	const N = 16;
	const S = 19;
	let seed = 20261027;
	const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
	const rib = [[150, 70, 10], [206, 116, 22], [232, 148, 40], [214, 126, 28]];
	const face = [
		"................",
		"................",
		"................",
		"...###....###...",
		"...###....###...",
		"....##....##....",
		"................",
		".......##.......",
		"................",
		"..#..........#..",
		"..############..",
		"..##.######.##..",
		"...##.#..#.##...",
		"....###..###....",
		"................",
		"................",
	];
	const carved = (x, y) => face[y]?.[x] === "#";
	const data = Buffer.alloc(N * S * N * S * 4);
	for (let y = 0; y < N; y++) {
		for (let x = 0; x < N; x++) {
			const k = 0.9 + rnd() * 0.2 - (y === 0 || y === N - 1 ? 0.08 : 0);
			let c = rib[x % 4].map((v) => Math.max(0, Math.min(255, Math.round(v * k))));
			if (carved(x, y)) {
				// the light inside: hot yellow in the middle of a carving, orange where it meets the rind
				const edge = !carved(x, y - 1) || !carved(x, y + 1);
				c = edge ? [255, 196, 64] : [255, 240, 140];
			} else if (carved(x - 1, y) || carved(x + 1, y) || carved(x, y - 1) || carved(x, y + 1)) {
				c = [110, 46, 6]; // the cut rind round a carving, in shadow
			}
			for (let yy = 0; yy < S; yy++) {
				for (let xx = 0; xx < S; xx++) {
					const i = ((y * S + yy) * N * S + x * S + xx) * 4;
					data[i] = c[0];
					data[i + 1] = c[1];
					data[i + 2] = c[2];
					data[i + 3] = 255;
				}
			}
		}
	}
	await sharp(data, { raw: { width: N * S, height: N * S, channels: 4 } }).png().toFile(path.join(dir, "jack_o_lantern.png"));
	console.log("wrote jack_o_lantern.png");
}
// Врата края / Древо: magenta and white concrete — our concrete floor on their own ramps, like the yellow and cyan
// concrete (the tinted smooth stone read near-black purple in the End night, Studio 26.10)
await recolor("concrete_floor.png", "magenta_concrete.png", [[0, [150, 40, 140]], [0.5, [192, 66, 182]], [1, [218, 100, 208]]], 0.7);
await recolor("concrete_floor.png", "white_concrete.png", [[0, [206, 210, 212]], [0.5, [228, 231, 232]], [1, [244, 246, 246]]], 0.7);
