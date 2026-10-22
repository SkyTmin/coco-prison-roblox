// Reference sheet vs our renders, one row per view: [reference panel | our render | 50/50 mix].
// The sheet is 1536×1024 with four 768×512 panels: side (top-left), front (top-right), top (bottom-left),
// three-quarter (bottom-right); the renders are <dir>/compare-<view>.png from `blender … -- compare`.
// Usage: node scripts/model-tools/cmp.cjs <modelDir> <reference.png> <out.png> [side,front,top,34] [scale 0.6]
const path = require("path");
const sharp = require(process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp"));
const [dir, refPath, out, viewList, scaleArg] = process.argv.slice(2);
const views = (viewList || "side,front,top,34").split(",");
const S = +(scaleArg || 0.6);
const pos = { side: [0, 0], front: [768, 0], top: [0, 512], 34: [768, 512] };
(async () => {
	const comps = [];
	let row = 0;
	for (const v of views) {
		const [l, t] = pos[v];
		const ref = await sharp(refPath).extract({ left: l, top: t, width: 768, height: 512 }).removeAlpha().raw().toBuffer();
		const ours = await sharp(path.join(dir, "compare-" + v + ".png")).resize(768, 512).removeAlpha().raw().toBuffer();
		const mix = Buffer.alloc(ref.length);
		for (let i = 0; i < ref.length; i++) mix[i] = (ref[i] + ours[i]) >> 1;
		const o = { raw: { width: 768, height: 512, channels: 3 } };
		comps.push({ input: ref, ...o, left: 0, top: row * 512 }, { input: ours, ...o, left: 768, top: row * 512 }, { input: mix, ...o, left: 1536, top: row * 512 });
		row++;
	}
	const big = await sharp({ create: { width: 2304, height: 512 * views.length, channels: 3, background: "#fff" } }).composite(comps).png().toBuffer();
	await sharp(big).resize(Math.round(2304 * S)).png().toFile(out);
})();
