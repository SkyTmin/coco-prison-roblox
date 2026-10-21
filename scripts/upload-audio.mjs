// Uploads the sound atlas (assets/sounds/build/atlas.ogg, see scripts/build-sounds.mjs) to Roblox through the
// Open Cloud Assets API and writes its id into assets/sounds/ids.json → atlasId and every files[name].id.
// The owner runs this (it needs their API key); Claude/Codex never handle the key.
//
//   1. https://create.roblox.com/dashboard/credentials → "Create API key": add the "Assets" API system with
//      the Write permission, IP restriction 0.0.0.0/0 (or your IP), copy the key.
//   2. In PowerShell:  $env:ROBLOX_API_KEY = "<key>"; $env:ROBLOX_USER_ID = "<your numeric user id>"
//      (or $env:ROBLOX_GROUP_ID for a group-owned experience), then  node scripts/upload-audio.mjs
//   3. node scripts/build-configs.mjs  → sync to Studio (the game reads Config.effects.sounds.files).
//
// Audio uploads: free, but unverified accounts are limited to 10 per month — the atlas needs ONE. Roblox moderates
// audio; a file stays unavailable until it is approved (usually minutes).
// Without the environment variables the script asks for the key in the terminal (the owner pastes it there,
// nobody else handles it); the user id defaults to the owner's account (coco_shamill).
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline/promises";

const OWNER_USER_ID = "6182034556"; // coco_shamill, owner of the experience (placeId 92594200898716)
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
let key = process.env.ROBLOX_API_KEY;
const groupId = process.env.ROBLOX_GROUP_ID;
const userId = process.env.ROBLOX_USER_ID || (groupId ? undefined : OWNER_USER_ID);
if (!key) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  key = (await rl.question("Вставьте ключ Open Cloud и нажмите Enter: ")).trim();
  rl.close();
}
if (!key) {
  console.error("Нет ключа — загрузка отменена.");
  process.exit(1);
}
const manifest = JSON.parse(fs.readFileSync(path.join(root, "assets/sounds/manifest.json"), "utf8"));
const idsPath = path.join(root, "assets/sounds/ids.json");
const ids = JSON.parse(fs.readFileSync(idsPath, "utf8"));
ids.files = ids.files || {};

async function upload(name, file) {
  const form = new FormData();
  form.append("request", JSON.stringify({
    assetType: "Audio",
    displayName: `coco-prison sounds ${name}`,
    description: "Game sounds atlas (VoxeLibre sounds, CC BY-SA 3.0/4.0, CC BY 3.0, CC0 — see repo ATTRIBUTION)",
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

// One upload: the atlas with every sound (scripts/build-sounds.mjs); each sound keeps its segments.
if (ids.atlasId && !process.argv.includes("--force")) {
  console.log("atlas already uploaded:", ids.atlasId, "(pass --force to upload a rebuilt atlas)");
} else {
  const assetId = await upload("atlas", path.join(root, manifest.atlas.file));
  ids.atlasId = `rbxassetid://${assetId}`;
  console.log("atlas →", assetId);
}
for (const entry of Object.values(ids.files)) entry.id = ids.atlasId;
// one line per sound entry, as scripts/build-sounds.mjs writes it
const compact = JSON.stringify(ids, null, 2).replace(/"(\w+)": \{\n\s+"id"[\s\S]*?\n {4}\}/g, (m) => m.replace(/\s*\n\s*/g, " "));
fs.writeFileSync(idsPath, compact + "\n");
console.log("done; now: node scripts/build-configs.mjs and sync to Studio");
