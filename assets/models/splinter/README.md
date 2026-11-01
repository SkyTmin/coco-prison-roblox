# Splinter / rat king — articulated motion v2

Owner request, 29 October 2026: make a concept image, build the boss in Blender, consult the wiki for skills and show the actual Blender result. Blender was run **headlessly with `-b` only**; neither Blender UI nor Roblox Studio was opened.

**1 November 2026 revision [owner]:** improve the rat king's animations to the standard of the new Zombar and Basalt Guardian. In this project the Basement rat boss is Splinter. The existing sculpture, palette and texture are preserved; all eleven clips were re-authored. Work remains headless, without Studio or desktop notifications.

## Files and provenance

- `splinter-reference.png`: generated with the built-in imagegen tool, using our ordinary rat reference only as a style guide. Full prompt in `concept-prompt.txt`. Original generated file remains in Codex's generated_images folder.
- `splinter.py`, `motion.py` + `../blockmob.py`: reproducible geometry, rig and original animation poses; `splinter.blend` is the editable scene. No original game's models, textures or keyframes were copied.
- `splinter-v2-showcase.png`, `splinter-v2-death-poses.png`, `v2-preview-*.png`: **actual Blender renders**. The source previews use Blender curves; the showcase/video use the decoded game export.
- `splinter-v2-motion.mp4`, `splinter-v2-death.gif`: current motion review at 20 fps [decision]. Shows local animation; gameplay root travel, projectiles and spider AI are not simulated. Older unprefixed previews and `splinter-motion.gif` are historical.
- `../../../src/shared/Models/splinter.json`: exported game rig, 316 cuboid parts / 33 joints / 11 clips [implementation]. Animation data lives in `splinter_locomotion.json`, `splinter_attacks.json` and `splinter_ritual.json`; the largest module is 115,695 characters [measured], below Roblox's 200k limit. `BlockRig.prepare` loads the three modules and retains compatibility with self-contained older models.
- `../splinter_spider/`: separately authored small spider, 23 parts / 10 joints [implementation]. Temporary summons use this rig and the existing MobAnimator.
- Both models reuse the uploaded rat noise tile `rbxassetid://93131048217957`; no new upload is necessary. `fur-noise.png` uses exactly the same noise generator. Fur, eyes and bottles are matte; no chest PointLight.

## Evidence versus decisions

Source: [RESOURCEPACK-BOSSES.md](../../../wiki/client-audit/RESOURCEPACK-BOSSES.md), Splinter row; machine-readable durations in `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`. The audit establishes **names and durations**, not original attack effects, damage, cooldowns, projectile physics or summon counts. Our interpretation of `shoot` as spit and `potion` as a poison pool is a gameplay decision, not a recovered fact.

| Clip | Duration [client audit] | Our implementation [decision] |
| --- | ---: | --- |
| attack → melee | 1 s | Right claw; hit at 13/30 s, 2 HP (previous owner balance) |
| swoop | 1.1 s | Warn, then lunge up to 22 studs; wall collision, one 4 HP hit per player |
| potion | 1.55 s | Fixed marked destination, throw at 1 s, radius 4.5; 4 × 1 HP ticks, 0.7 s apart |
| shoot | 2.25 s | Fixed aim, release at 1.5 s, speed 34 studs/s, range 40; first player hit takes 4 HP |
| summon | 4 s | At 3 s spawn 3 spiders (4 below half health), cap 6 alive; each 6 HP, lives 16 s, hit 1 HP / 1.8 s |
| death | 4 s | Collapse onto side, keep final pose until removal; cancel all effects and adds immediately |

Additional original clips: idle, walk, roar, jump, stunned. Boss HP 600, money/star/powder rewards and respawn retained. Ordinary attacks and casts stay vulnerable; only the pre-existing short spawn shield remains. Legacy golem fields in the common config remain for compatibility but are not selected by Splinter's four-skill cycle.

The `blockmob.py` exporter now keeps fractional frames so 1.55 and 2.25 seconds do not truncate to 1.5333 and 2.2333. Integer-frame models are unchanged.

V2 adds chest, knees, fingers/thumbs and cloth joints without changing the rest geometry. Legs use a two-bone solve with a planted stance; the authored stride drives walk playback speed. The torso leads the claw, with elbow/wrist follow-through. Swoop compresses before the existing windup, extends in flight and absorbs the landing. Potion reaches to the belt before the throw; shoot has inhalation and recoil; summon raises both paws then drops the body's weight. Death recoils, loses a knee, attempts a brace, falls onto the shoulder/hip, relaxes the upper paw and settles ears/tail. The full joint pose is held until removal.

The Blender bake uses quarter-frame sampling, bounded curve simplification and packed keys. `CLIP_FILES` splits dense data into modules instead of reducing fidelity; `GROUND_SUBSTEPS=4` keeps floor correction stable through support changes. Release origins for the existing potion/shoot timings are exported from the hand/mouth poses. `SplinterAbilities` converts them through the rig's ground-origin Motor6D C0, so it does not assume a duplicated root height. Damage, cooldowns, ranges, summon counts, rewards and respawn are unchanged.

## Rebuild (CLI, no windows)

```powershell
$blenderCli = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blenderCli -b -t 4 -P assets/models/splinter/splinter.py -- build
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/splinter.py -- export
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/splinter.py -- compare
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/render_motion.py
python assets/models/splinter/assemble_motion.py
node scripts/model-tools/validate-splinter.cjs
```

Use the analogous build/export commands for `splinter_spider`. `assemble_motion.py` needs Pillow, FFmpeg and a Segoe UI font; previews target Windows. Render frames are ignored. Add `-- --validate-only` to `render_motion.py` to measure the export without rendering.

## Verification and evening acceptance

Offline: inspected hero/front/side/back and attack poses, Blender build/export/render, model contract validation (finite sizes, joint references, unit quaternions, loop seams, exact durations, module budget, generated config agreement), Selene, StyLua, Rojo build and `git diff --check`.

**V2 offline results, 1 November:** all 316 rest-pose cuboids and their palette/shape match the preceding model. 6,450 keys across eleven clips [implementation]. Sampling the exported clips against Blender at 60 Hz gives maximum local errors of 0.0080 studs / 0.370 degrees; death-floor deviation is −0.0106 to +0.0090 studs, hand/mouth release-origin error 0.0154 studs, walk stance-position error 0.0768 studs [measured, `motion-validation.json`]. Final support is the shoulder/hip mass, rather than a claw or tail tip. These checks do not establish live Roblox performance.

**Studio update, 29 October:** synced and observed the model and natural attack cycle in the Basement; 17 isolated ability checks passed (hits, walls, windup cancellation, summon cap, spider damage/expiry). See [the QA report](../../../docs/research/studio-qa-2026-10-29.md) for exact coverage. Two-client rewards, all in-flight death cases, moving-player timing and real-phone graphics/performance remain unverified. No map rebuild or new asset upload is needed solely for this boss.

**V2 is not yet synced or runtime-tested.** Evening: full source sync in Edit, including the three new animation modules, then restart Play. Run `scripts/qa-splinter-runtime.luau` in Play/Server; it now checks loading all clips and actual projectile sockets as well as the previous ability cases. This revised script has not run during the headless session. Inspect walking at real speed, hand/mouth release, interruption into death during every skill, floor/wall clearance, two clients and phone FPS. The source-only Rojo review build must not replace the full cloud map.
