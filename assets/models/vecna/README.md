# Vecna — original rig and encounter

Prepared 02 November 2026 under the owner's code-only instruction. **Studio fixture/animation suites passed on 02.11 after the owner resumed QA; full arena/group/mobile acceptance remains open.** Blender ran headlessly with two threads, no notifications.

## Evidence and scope

- [wiki/menu] `wiki/in-game-wiki/HANDBOOK-WIKI.md`85/107/127: Inside Out/Изнанка, unlock27, respawn4h, bank$0–6400, stars7–12, Ancient Powder label1–25%. Existing reward interpretation, eligibility, HP2770, damage29/40/50, combat regeneration6HP/s and progression remain unchanged. Public boss chat contains participant damage/share/dollars only [owner].
- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`, `strangerthings/pa_vecna1`: idle4s, walk1.25s, attack1=.5s, attack2=4s, death4.7s marked looping; flower is looping with unknown duration. Related clock/portal/demogorgon/hound/bat families establish visual vocabulary, not server mechanics. Details in `research-notes.md`.
- [decision] Our claw lasts.85s for readable preparation; flower5.5s, clockcast2.7s, portalcast3.5s and non-looping death4.7s are authored choices. No claim that their timing, damage, counterplay or summon rules reproduce unrecovered source code.
- Original concept generated with built-in image_gen: `vecna-reference.png`; exact prompt in `concept-prompt.txt`. No third-party geometry, animation or purchased pack imported. Public searches did not establish a verified seller of this exact source family; unrelated D&D/STL packs were excluded.

## Models and animation [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Vecna |725|64|13|
| Stalker |112|22|6|
| Hound |85|24|6|
| Bat |57|15|6|
| Clock |31|6|4|
| Portal |48|10|3|

Brown matte anatomy, stepped muscle volumes, front/back ribs and spine, asymmetric hand with individually moving digits, six dorsal tendrils with six joints each. The reference has finer surface detail than this economical cuboid rig; silhouette, palette and anatomy guide the model. Existing gray noise texture is reused byte-identically; SHA256 in `ids.json`. No new texture upload, emissive geometry or attached lights.

Main gait uses planted IK with opposing torso/arm movement. Tendril motion travels along the chains. Death4.7s recoils, loses knee support, catches on the shoulder, settles forward, relaxes the hands and lays the tendrils beside the body. Initial fingers/legs propped up the torso; the review corrected them. Minions have independent layered movement and final collapse poses. Hound/stalker strides match the client playback-rate range; lower-side limbs/wing tips no longer suspend their bodies. The clock rocks, tips onto its back and settles; portal segments open and close without an opaque screen plane.

All38 clips are rendered from **exported Roblox tracks**, with review videos and contact sheets:

- `vecna-motion.mp4`, `vecna-death.mp4`/`.gif`, `vecna-death-poses.png`.
- `vecna-showcase.png`, `vecna-summons.png`, `compare-front/side/back.png`.
- Five `vecna-<companion>-motion.mp4` videos and individual clip previews.

## Encounter [authored decisions]

All amounts below are raw, before armor/books, ordinary hurt immunity and the existing shared boss burst cap. The boss never gains block/immunity, never takes over the camera, and does not clone players or highlight unrelated mobs.

| Attack | Behavior and counterplay |
|---|---|
| Claw |.85s, contact.5s,29 damage, radius8,70° half-angle; step outside the arc|
| Tendril patches |4s, contact2.1s,3 patches/5 in phase two, radius3.1, range25; warnings lock before impact,40 shared damage per player even where patches overlap|
| Flower wave |5.5s, release2.3s, speed10/radius17/width2;60° safe wedge toward the boss's right side, jump above4.1 studs relative to floor,40 damage once; walls stop its sectors|
| Clock curse |2.7s cast/release1.25s; one80HP clock,6s fuse, radius8,50 damage; destroy it, leave its warning or use cover. Support loss/height change cancels it|
| Portal |3.5s/release1.5s;110 net HP loss interrupts the vulnerable cast into1s stagger;2 creatures/3 in phase two, stagger.45s, cap4 living adds. Interruption stops future spawns; already spawned adds remain killable|

Stalker42HP/10damage/speed10/life22s; hound30HP/9damage/speed13/life22s; bat16HP/7damage/speed10/life18s [decision]. Each has a visible contact delay, finite lifetime and death animation. Ground minions are server-owned ordinary Mob targets, with no boss reward registration. The bat is server-controlled with swept obstruction checks. Portal is a non-queryable BossProp; clocks are vulnerable Mob targets. Death/leash/root replacement clears the whole encounter. Walls, arena radius, support and headroom are checked; clock headroom is checked again at release. Persistent waves/clocks recheck floor height. Effect parts are bounded matte fragments, not particle storms.

## Verification

Offline Selene/StyLua/Rojo plus Python/JSON/model/config checks pass. `audit.py` compares decisions against checkpoint bee4a8c, permits only this boss's authored model/mechanics fields, checks finite sorted curves, quaternion normalization, 14 modules (largest118782 characters), clip/config timings, companion filename separation and review manifests. Main position error<.0081stud, rotation<.36°, planted-foot error<.018stud, final torso floor error<.00005stud; full death silhouette error<.017stud. Each companion has its own measured report. These checks do not establish Roblox behavior, actual FPS or multiplayer balance.

**Studio update02.11, Katorga92594200898716:** source/models-only sync preserved the cloud map. `qa-vecna-runtime.luau` PASS: 60cases/189checks; `qa-vecna-animation-client.luau` PASS: 24checks on actual client Motor6Ds. No-block43checks and ordinary-mob bite regression pass. Boss transforms now update in PreSimulation (see [Roblox timing](https://create.roblox.com/docs/reference/engine/classes/Motor6D)); all six pending client suites pass, including fast props. Full live arena encounters, real4–6-player combat, phone/load tests and owner visual acceptance remain open. `studio-validation.json` is PARTIAL and lists the remaining work. Fixtures removed, default viewport/camera and Creative restored; no publishing.

## Rebuild

One Blender5.2 process at a time: `blender -b -t 2 --python-exit-code 1 -P <id>.py -- build`, then `blender -b <id>.blend -t 2 --python-exit-code 1 -P <id>.py -- export`. Main review `render_motion.py`; companions `review_summons.py -- <id>`; main `-- compare`; then Python `assemble_motion.py` and `audit.py`. Main clock/portal spell chunks are named `vecna_clockspell`/`vecna_portalspell` to avoid colliding with companion model modules. Config source is `configure_runtime.py`/`scripts/design-decisions.json`, followed by `node scripts/build-configs.mjs`; generated JSON is never edited by hand. Raw frames/logs are ignored.
