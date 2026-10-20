// Uploads the built block sounds (assets/sounds/build/*.ogg, see scripts/build-sounds.mjs) to Roblox through
// the Open Cloud Assets API and writes the asset ids into assets/sounds/ids.json → files[name].id.
// The owner runs this (it needs their API key); Claude/Codex never see the key.
//
//   1. https://create.roblox.com/dashboard/credentials → "Create API key": add the "Assets" API system with
//      the Write permission, IP restriction 0.0.0.0/0 (or your IP), copy the key.
//   2. In PowerShell:  $env:ROBLOX_API_KEY = "<key>"; $env:ROBLOX_USER_ID = "<your numeric user id>"
//      (or $env:ROBLOX_GROUP_ID for a group-owned experience), then  node scripts/upload-audio.mjs
//   3. node scripts/build-configs.mjs  → sync to Studio (the game reads Config.effects.sounds.files).
//
// Audio uploads: free, but unverified accounts are limited to 10 per month (this needs 8). Roblox moderates
// audio; a file stays unavailable until it is approved (usually minutes).
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const key = process.env.ROBLOX_API_KEY;
const userId = process.env.ROBLOX_USER_ID;
const groupId = process.env.ROBLOX_GROUP_ID;
if (!key || (!userId && !groupId)) {
  console.error("Set ROBLOX_API_KEY and ROBLOX_USER_ID (or ROBLOX_GROUP_ID) in the environment first.");
  process.exit(1);
}
const only = process.argv.slice(2); // optional: names to (re)upload
const manifest = JSON.parse(fs.readFileSync(path.join(root, "assets/sounds/manifest.json"), "utf8"));
const idsPath = path.join(root, "assets/sounds/ids.json");
const ids = JSON.parse(fs.readFileSync(idsPath, "utf8"));
ids.files = ids.files || {};

async function upload(name, file) {
  const form = new FormData();
  form.append("request", JSON.stringify({
    assetType: "Audio",
    displayName: `coco-prison block ${name}`,
    description: "Block dig/break sound (VoxeLibre mcl_sounds, CC BY-SA 3.0 / CC BY 3.0 / CC0 — see repo README)",
    creationContext: { creator: groupId ? { groupId } : { userId } },
  }));
  form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "audio/ogg" }), path.basename(file));
  const res = await fetch("https://apis.roblox.com/assets/v1/assets", { method: "POST", headers: { "x-api-key": key }, body: form });
  if (!res.ok) throw new Error(`${name}: upload HTTP ${res.status} ${await res.text()}`);
  const op = await res.json();
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const poll = await fetch(`https://apis.roblox.com/assets/v1/${op.path}`, { headers: { "x-api-key": key } });
    if (!poll.ok) throw new Error(`${name}: poll HTTP ${poll.status} ${await poll.text()}`);
    const status = await poll.json();
    if (status.done) {
      if (status.error) throw new Error(`${name}: ${JSON.stringify(status.error)}`);
      return status.response.assetId;
    }
  }
  throw new Error(`${name}: operation did not finish`);
}

for (const [name, entry] of Object.entries(manifest.files)) {
  if (only.length && !only.includes(name)) continue;
  if (!only.length && ids.files[name] && ids.files[name].id) { console.log(name, "already uploaded:", ids.files[name].id); continue; }
  const assetId = await upload(name, path.join(root, entry.file));
  ids.files[name] = { id: `rbxassetid://${assetId}`, duration: entry.duration, segments: entry.segments.map((s) => [s.start, s.length]) };
  fs.writeFileSync(idsPath, JSON.stringify(ids, null, 2) + "\n");
  console.log(name, "→", assetId);
}
console.log("done; now: node scripts/build-configs.mjs");
