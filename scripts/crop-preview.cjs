// Crops a Studio screen_capture to the largest 1.9:1 rectangle without sky (sky = sky-blue pixels connected to
// the border), upscaled to 760 px wide. Usage: node scripts/crop-preview.cjs <capture.jpg> assets/previews/topdown-<id>.png
const fs = require('fs');
const sharpPath = process.env.SHARP_PATH || (process.env.LOCALAPPDATA + '/Temp/claude/C--Users-user-Desktop--------claud/5519c892-7982-41f2-b081-ec30cc78a89a/scratchpad/imgtools/node_modules/sharp');
const sharp = require(fs.existsSync(sharpPath) ? sharpPath : 'sharp');
const [src, dst] = process.argv.slice(2);
(async () => {
  const { data, info } = await sharp(src).raw().toBuffer({ resolveWithObject: true });
  const W = info.width, H = info.height, C = info.channels;
  // sky = sky-coloured pixels connected to the image border (water and blue things inside the map are kept)
  const isSkyColor = (x, y) => { const i = (y * W + x) * C, r = data[i], g = data[i + 1], b = data[i + 2]; return b > 150 && b > r + 25 && g >= r; };
  const mask = new Uint8Array(W * H);
  const stack = [];
  for (let x = 0; x < W; x++) { stack.push([x, 0], [x, H - 1]); }
  for (let y = 0; y < H; y++) { stack.push([0, y], [W - 1, y]); }
  while (stack.length) {
    const [x, y] = stack.pop();
    if (x < 0 || y < 0 || x >= W || y >= H || mask[y * W + x] || !isSkyColor(x, y)) continue;
    mask[y * W + x] = 1;
    stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  const sky = new Int32Array((W + 1) * (H + 1));
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    sky[(y + 1) * (W + 1) + x + 1] = mask[y * W + x] + sky[y * (W + 1) + x + 1] + sky[(y + 1) * (W + 1) + x] - sky[y * (W + 1) + x];
  }
  const sum = (x0, y0, x1, y1) => sky[y1 * (W + 1) + x1] - sky[y0 * (W + 1) + x1] - sky[y1 * (W + 1) + x0] + sky[y0 * (W + 1) + x0];
  let best = null;
  for (let h = H; h >= 60 && !best; h -= 2) {
    const w = Math.round(h * 1.9);
    if (w > W) continue;
    let pick = null;
    for (let y = 0; y + h <= H; y += 2) for (let x = 0; x + w <= W; x += 2) {
      if (sum(x, y, x + w, y + h) === 0) {
        const d = Math.abs(x + w / 2 - W / 2) + Math.abs(y + h / 2 - H / 2) * 0.5;
        if (!pick || d < pick.d) pick = { x, y, w, h, d };
      }
    }
    best = pick;
  }
  if (!best) throw new Error('no sky-free rectangle');
  await sharp(src).extract({ left: best.x, top: best.y, width: best.w, height: best.h }).resize({ width: 760, kernel: 'lanczos3' }).png().toFile(dst);
  console.log(dst, JSON.stringify(best));
})();
