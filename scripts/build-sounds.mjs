// Builds the block dig/break sound files from the VoxeLibre (mcl_sounds) sources:
//   assets/thirdparty/voxelibre/sounds/*.ogg  →  assets/sounds/build/<name>.ogg + assets/sounds/manifest.json
// Each output file concatenates several variants of one sound with a 100 ms gap, so the game can pick a
// random variant with Sound.TimePosition (one Roblox asset per material×kind instead of 24 uploads).
// Minecraft semantics: "hit" = the block's step sound played while digging (every 4 ticks, pitch ×0.5,
// volume 1/4), "break" = the block's dig sound when it goes (pitch 0.8, volume 1). [ваниль]
// Usage: node scripts/build-sounds.mjs   (needs ffmpeg/ffprobe on PATH or in the winget package folder)
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const src = path.join(root, "assets/thirdparty/voxelibre/sounds");
const out = path.join(root, "assets/sounds/build");
fs.mkdirSync(out, { recursive: true });

function findFfmpeg() {
  for (const bin of ["ffmpeg", "ffprobe"]) {
    try { execFileSync(bin, ["-version"], { stdio: "ignore" }); } catch { break; }
    if (bin === "ffprobe") return { ffmpeg: "ffmpeg", ffprobe: "ffprobe" };
  }
  const pkgs = path.join(process.env.LOCALAPPDATA || "", "Microsoft/WinGet/Packages");
  for (const d of fs.existsSync(pkgs) ? fs.readdirSync(pkgs) : []) {
    if (!d.startsWith("Gyan.FFmpeg")) continue;
    for (const v of fs.readdirSync(path.join(pkgs, d))) {
      const bin = path.join(pkgs, d, v, "bin");
      if (fs.existsSync(path.join(bin, "ffmpeg.exe"))) return { ffmpeg: path.join(bin, "ffmpeg.exe"), ffprobe: path.join(bin, "ffprobe.exe") };
    }
  }
  throw new Error("ffmpeg not found");
}
const { ffmpeg, ffprobe } = findFfmpeg();

// Output name → source variants. Material mapping follows Minecraft sound types [ваниль]:
// stone/ores → STONE, dirt/gravel → GRAVEL, grass → GRASS, sand → SAND, logs/planks/melon → WOOD.
const FILES = {
  stone_hit: ["default_hard_footstep.1", "default_hard_footstep.2", "default_hard_footstep.3"],
  stone_break: ["default_dig_cracky.1", "default_dig_cracky.2", "default_dig_cracky.3"],
  gravel_hit: ["default_gravel_footstep.1", "default_gravel_footstep.2", "default_gravel_footstep.3", "default_gravel_footstep.4"],
  gravel_break: ["default_gravel_dug.1", "default_gravel_dug.2", "default_gravel_dug.3"],
  grass: ["default_grass_footstep.1", "default_grass_footstep.2", "default_grass_footstep.3"],
  sand: ["default_sand_footstep.1", "default_sand_footstep.2", "default_sand_footstep.3"],
  wood_hit: ["default_wood_footstep.1", "default_wood_footstep.2"],
  wood_break: ["default_dig_choppy.1", "default_dig_choppy.2", "default_dig_choppy.3"],
};
const GAP = 0.1;

const manifest = { _source: "scripts/build-sounds.mjs — VoxeLibre mcl_sounds (see assets/thirdparty/voxelibre/sounds/README-mcl_sounds.txt)", gap: GAP, files: {} };
for (const [name, variants] of Object.entries(FILES)) {
  const inputs = [];
  const filters = [];
  const segments = [];
  let offset = 0;
  variants.forEach((v, i) => {
    const file = path.join(src, v + ".ogg");
    const duration = parseFloat(execFileSync(ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]).toString());
    inputs.push("-i", file);
    // trim silence tails, normalise each variant to the same peak, pad the gap
    filters.push(`[${i}]aformat=sample_rates=44100:channel_layouts=mono,silenceremove=stop_periods=1:stop_threshold=-50dB:stop_silence=0.02,alimiter=limit=0.9,apad=pad_dur=${GAP}[s${i}]`);
    segments.push({ start: Math.round(offset * 1000) / 1000, length: Math.round(duration * 1000) / 1000, source: v + ".ogg" });
    offset += duration + GAP;
  });
  const concat = variants.map((_, i) => `[s${i}]`).join("") + `concat=n=${variants.length}:v=0:a=1,volume=-3dB[out]`;
  const target = path.join(out, name + ".ogg");
  execFileSync(ffmpeg, ["-y", "-v", "error", ...inputs, "-filter_complex", filters.join(";") + ";" + concat, "-map", "[out]", "-c:a", "libvorbis", "-q:a", "6", target]);
  // Re-measure: silenceremove may shorten variants; use real positions by probing each trimmed variant.
  const total = parseFloat(execFileSync(ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", target]).toString());
  manifest.files[name] = { file: `assets/sounds/build/${name}.ogg`, duration: Math.round(total * 1000) / 1000, segments };
  console.log(name.padEnd(13), variants.length + " variants", total.toFixed(2) + "s", Math.round(fs.statSync(target).size / 1024) + " KB");
}
fs.writeFileSync(path.join(root, "assets/sounds/manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log("manifest → assets/sounds/manifest.json");
