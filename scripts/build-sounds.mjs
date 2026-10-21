// Builds ONE sound atlas from the VoxeLibre sounds [владелец 21.10: «замени все звуки на VoxeLibre»]:
//   assets/thirdparty/voxelibre/sounds/*.ogg  →  assets/sounds/build/atlas.ogg + assets/sounds/manifest.json
// and writes every sound's variants (start, length in the atlas) into assets/sounds/ids.json → files[name].
// One file for everything because Roblox lets an unverified account upload only 10 audio assets a month:
// the owner uploads atlas.ogg once (scripts/upload-audio.mjs) and every sound plays its segment of it
// (Sound.TimePosition, stopped after the length). Variants lose their leading silence and are
// peak-normalised one by one, measured AFTER processing (the old per-file build measured before trimming,
// so its segments drifted), then concatenated with a short gap.
// Minecraft semantics [ваниль]: "hit" = the block's step sound while digging (every 4 ticks, pitch ×0.5,
// volume 1/4), "break" = the block's dig sound when it goes (pitch 0.8), steps while walking.
// Usage: node scripts/build-sounds.mjs   (needs ffmpeg/ffprobe on PATH or in the winget package folder)
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
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
const n = (i) => [1, 2, 3, 4].slice(0, i);

// Sound name → VoxeLibre source files (without .ogg). Block sound types follow Minecraft [ваниль]:
// stone/ores → STONE, dirt/gravel → GRAVEL, grass/leaves → GRASS, sand → SAND, logs/planks/melon → WOOD,
// glass, metal blocks, ice, wool, snow.
const SOUNDS = {
  stone_hit: n(3).map((i) => `default_hard_footstep.${i}`),
  stone_break: n(3).map((i) => `default_dig_cracky.${i}`),
  gravel_hit: n(4).map((i) => `default_gravel_footstep.${i}`),
  gravel_break: n(3).map((i) => `default_gravel_dug.${i}`),
  grass: n(3).map((i) => `default_grass_footstep.${i}`),
  leaves_break: ["default_dig_snappy"],
  sand: n(3).map((i) => `default_sand_footstep.${i}`),
  wood_hit: n(2).map((i) => `default_wood_footstep.${i}`),
  wood_break: n(3).map((i) => `default_dig_choppy.${i}`),
  glass_hit: ["default_glass_footstep"],
  glass_break: n(3).map((i) => `default_break_glass.${i}`),
  metal_hit: n(3).map((i) => `default_metal_footstep.${i}`),
  metal_break: n(2).map((i) => `default_dug_metal.${i}`),
  ice_hit: n(3).map((i) => `default_ice_footstep.${i}`),
  ice_break: ["default_ice_dug"],
  wool: n(4).map((i) => `mcl_sounds_cloth.${i}`),
  snow: n(4).map((i) => `pedology_snow_soft_footstep.${i}`),
  water_step: n(3).map((i) => `default_water_footstep.${i}`),
  place: n(3).map((i) => `default_place_node.${i}`),
  player_hurt: ["player_damage"],
  player_fall: ["player_falling_damage"],
  eat: n(2).map((i) => `mcl_hunger_bite.${i}`),
  pickup: ["item_drop_pickup"],
  xp: ["mcl_experience"],
  level_up: ["mcl_experience_level_up"],
  chest_open: ["default_chest_open"],
  chest_close: ["default_chest_close"],
  ender_open: ["mcl_chests_enderchest_open"],
  ender_close: ["mcl_chests_enderchest_close"],
  enchant: [0, 1, 2].map((i) => `mcl_enchanting_enchant.${i}`),
  armor_equip: ["mcl_armor_equip_generic"],
  armor_equip_leather: ["mcl_armor_equip_leather"],
  armor_equip_chain: ["mcl_armor_equip_chainmail"],
  armor_equip_iron: ["mcl_armor_equip_iron"],
  armor_equip_diamond: ["mcl_armor_equip_diamond"],
  tool_break: ["default_tool_breaks"],
};
const GAP = 0.15; // silence between segments (no bleed when a segment is cut a little late)
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "coco-sfx-"));
const probe = (file) =>
  parseFloat(execFileSync(ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]).toString());

// 1. every variant → trimmed, normalised mono wav, measured after trimming
const pieces = []; // { name, wav, duration }
for (const [name, variants] of Object.entries(SOUNDS)) {
  variants.forEach((v, i) => {
    const file = path.join(src, v + ".ogg");
    if (!fs.existsSync(file)) throw new Error(`missing ${file}`);
    const wav = path.join(tmp, `${name}.${i}.wav`);
    execFileSync(ffmpeg, [
      "-y", "-v", "error", "-i", file,
      // only the leading silence is cut (the sound starts at once); tails stay — quiet decays such as the
      // end of a stone crack were cut away as "silence" otherwise
      "-af",
      "aformat=sample_rates=44100:channel_layouts=mono,silenceremove=start_periods=1:start_threshold=-60dB,alimiter=limit=0.9,volume=-3dB",
      "-c:a", "pcm_s16le", wav,
    ]);
    pieces.push({ name, wav, duration: probe(wav) });
  });
}
// 2. concatenate with gaps (concat demuxer over same-format wavs keeps exact offsets)
const silence = path.join(tmp, "gap.wav");
execFileSync(ffmpeg, ["-y", "-v", "error", "-f", "lavfi", "-i", `anullsrc=r=44100:cl=mono`, "-t", String(GAP), "-c:a", "pcm_s16le", silence]);
const list = [];
const segments = {}; // name → [[start, length], …]
let offset = 0;
for (const p of pieces) {
  list.push(`file '${p.wav.replace(/\\/g, "/")}'`, `file '${silence.replace(/\\/g, "/")}'`);
  (segments[p.name] ||= []).push([Math.round(offset * 1000) / 1000, Math.round(p.duration * 1000) / 1000]);
  offset += p.duration + GAP;
}
const listFile = path.join(tmp, "list.txt");
fs.writeFileSync(listFile, list.join("\n"));
const atlas = path.join(out, "atlas.ogg");
execFileSync(ffmpeg, ["-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", listFile, "-c:a", "libvorbis", "-q:a", "6", atlas]);
const total = probe(atlas);
fs.rmSync(tmp, { recursive: true, force: true });
// the old per-material files are no longer used
for (const f of fs.readdirSync(out)) if (f !== "atlas.ogg") fs.rmSync(path.join(out, f));

fs.writeFileSync(
  path.join(root, "assets/sounds/manifest.json"),
  JSON.stringify({ _source: "scripts/build-sounds.mjs — VoxeLibre sounds (assets/thirdparty/voxelibre/ATTRIBUTION.md)", atlas: { file: "assets/sounds/build/atlas.ogg", duration: Math.round(total * 1000) / 1000 }, segments }, null, 2) + "\n",
);

// 3. ids.json: every sound points at the atlas (id filled by upload-audio.mjs), keeps its fallback
const idsPath = path.join(root, "assets/sounds/ids.json");
const ids = JSON.parse(fs.readFileSync(idsPath, "utf8"));
const files = {};
for (const name of Object.keys(SOUNDS)) {
  const old = (ids.files || {})[name] || {};
  files[name] = { id: ids.atlasId || "", segments: segments[name], ...(old.fallback ? { fallback: old.fallback } : {}) };
}
ids.files = files;
ids.atlasId = ids.atlasId || "";
// keep one line per sound entry (readable diffs)
const compact = JSON.stringify(ids, (k, v) => v, 2).replace(/"(\w+)": \{\n\s+"id"[\s\S]*?\n {4}\}/g, (m) => m.replace(/\s*\n\s*/g, " "));
fs.writeFileSync(idsPath, compact + "\n");
console.log(`atlas ${total.toFixed(1)} s, ${Object.keys(SOUNDS).length} sounds, ${pieces.length} variants, ${Math.round(fs.statSync(atlas).size / 1024)} KB`);
