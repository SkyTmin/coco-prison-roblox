// A scaled copy of a BlockRig model (src/shared/Models/<id>.json) with clip aliases — a boss made from a mob
// until it has its own Blender model [решение 22.10: Сплинтер = крыса ×3].
//   node scripts/model-tools/scale-model.cjs <from> <to> <scale> [alias=clip,...]
// Scales joint pivots, part centres and sizes, clip offsets and the texture tile; aliases copy clips under the
// names BossAnimator plays (melee, roar, jump, blade_raise, blade_sweep, spikes_raise, spikes_slam, charge,
// stunned).
const fs = require("fs");
const path = require("path");

const [from, to, scaleArg, aliasArg] = process.argv.slice(2);
if (!from || !to || !scaleArg) {
	console.error("usage: scale-model.cjs <from> <to> <scale> [alias=clip,...]");
	process.exit(1);
}
const dir = path.join(__dirname, "..", "..", "src", "shared", "Models");
const def = JSON.parse(fs.readFileSync(path.join(dir, from + ".json"), "utf8"));
if (def.format === 2) {
	console.error("format 2 (indexed) models are not supported");
	process.exit(1);
}
const s = Number(scaleArg);
const mul = (v) => v.map((x) => Math.round(x * s * 10000) / 10000);

def._source = `scale-model.cjs: ${from}.json × ${s} (${def._source || ""})`;
if (def.texture && def.texture.studsPerTile) def.texture.studsPerTile *= s;
for (const j of def.joints) j.pivot = mul(j.pivot);
for (const p of def.parts) {
	p.centre = mul(p.centre);
	p.size = mul(p.size);
}
for (const clip of Object.values(def.clips)) {
	for (const keys of Object.values(clip.tracks)) for (const k of keys) if (k.p) k.p = mul(k.p);
}
for (const pair of (aliasArg || "").split(",").filter(Boolean)) {
	const [alias, clip] = pair.split("=");
	if (!def.clips[clip]) throw new Error("no clip " + clip);
	def.clips[alias] = JSON.parse(JSON.stringify(def.clips[clip]));
}
fs.writeFileSync(path.join(dir, to + ".json"), JSON.stringify(def));
console.log(`${to}.json: ${def.parts.length} parts, clips ${Object.keys(def.clips).join(" ")}`);
