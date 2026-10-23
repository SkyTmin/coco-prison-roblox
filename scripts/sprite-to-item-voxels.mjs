// Block sprites → 3D extruded item models, the way Minecraft draws a cross-model block (cobweb) as an item:
// the block texture as a flat generated item. Reads an RGBA PNG whose side is a multiple of 16 (nearest
// sample per texel), merges same-colour rectangles and writes items.<name> into assets/icons/voxels.json.
// Usage: node scripts/sprite-to-item-voxels.mjs [name=path ...]   (default: cobweb=assets/textures/sprites/cobweb.png)
import { readFileSync, writeFileSync } from "node:fs";
import { inflateSync } from "node:zlib";

const SIZE = 16;
const OUT = "assets/icons/voxels.json";

function decodePng(file) {
	const buf = readFileSync(file);
	let pos = 8;
	let width = 0;
	let height = 0;
	const idat = [];
	while (pos < buf.length) {
		const len = buf.readUInt32BE(pos);
		const type = buf.toString("ascii", pos + 4, pos + 8);
		const data = buf.subarray(pos + 8, pos + 8 + len);
		if (type === "IHDR") {
			width = data.readUInt32BE(0);
			height = data.readUInt32BE(4);
			if (data[8] !== 8 || data[9] !== 6 || data[12] !== 0) throw new Error(`${file}: need 8-bit RGBA, not interlaced`);
		} else if (type === "IDAT") idat.push(data);
		pos += 12 + len;
	}
	const raw = inflateSync(Buffer.concat(idat));
	const stride = width * 4;
	const px = Buffer.alloc(stride * height);
	for (let y = 0; y < height; y++) {
		const filter = raw[y * (stride + 1)];
		const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
		for (let i = 0; i < stride; i++) {
			const a = i >= 4 ? px[y * stride + i - 4] : 0;
			const b = y > 0 ? px[(y - 1) * stride + i] : 0;
			const c = i >= 4 && y > 0 ? px[(y - 1) * stride + i - 4] : 0;
			let v = line[i];
			if (filter === 1) v += a;
			else if (filter === 2) v += b;
			else if (filter === 3) v += (a + b) >> 1;
			else if (filter === 4) {
				const p = a + b - c;
				const pa = Math.abs(p - a);
				const pb = Math.abs(p - b);
				const pc = Math.abs(p - c);
				v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
			}
			px[y * stride + i] = v & 255;
		}
	}
	return { width, height, px };
}

function toVoxels(file) {
	const { width, height, px } = decodePng(file);
	const cell = width / SIZE;
	const grid = [];
	for (let y = 0; y < SIZE; y++) {
		const row = [];
		for (let x = 0; x < SIZE; x++) {
			const sx = Math.floor((x + 0.5) * cell);
			const sy = Math.floor(((y + 0.5) * height) / SIZE);
			const i = (sy * width + sx) * 4;
			row.push(px[i + 3] > 100 ? [0, 1, 2].map((k) => px[i + k].toString(16).padStart(2, "0")).join("").toUpperCase() : null);
		}
		grid.push(row);
	}
	const palette = [];
	const r = [];
	const used = grid.map((row) => row.map(() => false));
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const color = grid[y][x];
			if (!color || used[y][x]) continue;
			let w = 1;
			while (x + w < SIZE && grid[y][x + w] === color && !used[y][x + w]) w++;
			let h = 1;
			grow: while (y + h < SIZE) {
				for (let k = 0; k < w; k++) if (grid[y + h][x + k] !== color || used[y + h][x + k]) break grow;
				h++;
			}
			for (let dy = 0; dy < h; dy++) for (let dx = 0; dx < w; dx++) used[y + dy][x + dx] = true;
			if (!palette.includes(color)) palette.push(color);
			r.push(x, y, w, h, palette.indexOf(color));
		}
	}
	return { w: SIZE, h: SIZE, p: palette, r };
}

const args = process.argv.slice(2);
const pairs = (args.length ? args : ["cobweb=assets/textures/sprites/cobweb.png"]).map((a) => a.split("="));
const json = JSON.parse(readFileSync(OUT, "utf8").replace(/^﻿/, ""));
for (const [name, file] of pairs) {
	json.items[name] = toVoxels(file);
	console.log(`${name}: ${json.items[name].r.length / 5} rectangles, ${json.items[name].p.length} colours`);
}
writeFileSync(OUT, JSON.stringify(json));
