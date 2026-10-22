// Silhouette bounding boxes of the four panels of a 1536×1024 reference sheet (background = the corner colour),
// to check that the views agree: side/front heights, side/top depth, front/top width.
// Usage: node scripts/model-tools/bbox.cjs <sheet.png> [tolerance 40]
const path = require("path");
const sharp = require(process.env.SHARP_PATH || path.join(process.env.LOCALAPPDATA || "", "Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp"));
const [file, tolArg] = process.argv.slice(2);
const tol = +(tolArg || 40);
(async () => {
	const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
	const W = info.width;
	const bg = [data[0], data[1], data[2]];
	const panels = { side: [0, 0], front: [768, 0], top: [0, 512], "3/4": [768, 512] };
	for (const [name, [l, t]] of Object.entries(panels)) {
		let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
		const rowsCount = {};
		for (let y = t; y < t + 512; y++)
			for (let x = l; x < l + 768; x++) {
				const i = (y * W + x) * 3;
				if (Math.abs(data[i] - bg[0]) + Math.abs(data[i + 1] - bg[1]) + Math.abs(data[i + 2] - bg[2]) > tol) {
					x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
				}
			}
		console.log(name.padEnd(5), "x", x0, "-", x1, "(w", x1 - x0 + 1 + ")", " y", y0, "-", y1, "(h", y1 - y0 + 1 + ")");
	}
})();
