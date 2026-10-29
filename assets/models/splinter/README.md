# Splinter — original Blender boss

Owner request, 29 October 2026: make a concept image, build the boss in Blender, consult the wiki for skills and show the actual Blender result. Blender was run **headlessly with `-b` only**; neither Blender UI nor Roblox Studio was opened.

## Files and provenance

- `splinter-reference.png`: generated with the built-in imagegen tool, using our ordinary rat reference only as a style guide. Full prompt in `concept-prompt.txt`. Original generated file remains in Codex's generated_images folder.
- `splinter.py` + `../blockmob.py`: reproducible geometry, rig, materials and original animation poses; `splinter.blend` is the editable scene. No original game's models, textures or animation keyframes were copied.
- `splinter-showcase.png`, `preview-*.png`, `compare-*.png`: **actual Blender renders**, not generated concept art.
- `splinter-motion.gif`: real Blender animation frames, assembled with Pillow. Does not simulate gameplay movement, projectiles or spider AI.
- `../../../src/shared/Models/splinter.json`: exported game rig, 316 cuboid parts / 23 joints / 11 clips [implementation]. Compact format 2, about 47k characters, below Roblox's 200k module limit.
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

## Rebuild (CLI, no windows)

```powershell
$blenderCli = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blenderCli -b -t 4 -P assets/models/splinter/splinter.py -- build
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/splinter.py -- export
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/splinter.py -- compare
& $blenderCli -b -t 4 assets/models/splinter/splinter.blend -P assets/models/splinter/render_showcase.py
python assets/models/splinter/assemble_showcase.py
node scripts/model-tools/validate-splinter.cjs
```

Use the analogous build/export commands for `splinter_spider`. `assemble_showcase.py` needs Pillow and a Segoe UI font; previews target Windows. Render frames are ignored, GIF and contact sheet are kept.

## Verification and evening acceptance

Offline: inspected hero/front/side/back and attack poses, Blender build/export/render, model contract validation (finite sizes, joint references, unit quaternions, loop seams, exact durations, module budget, generated config agreement), Selene, StyLua, Rojo build and `git diff --check`.

**Not tested in Studio or on a phone.** Evening: full source sync in Edit mode, then enter the Basement arena. Check feet on floor, silhouette/scale, texture permissions, movement and all five attacks against moving players, dodge/wall blocking, melee hit timing, spiders taking weapon damage, no more than six summons, expiry, death during each windup/projectile/lunge, no leftover anchored boss or damage after death, four-second death clip, existing payouts and respawn. Check on two clients and phone graphics/performance. No map rebuild or new asset upload is needed solely for this boss.
