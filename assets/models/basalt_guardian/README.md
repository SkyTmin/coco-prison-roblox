# Basalt Guardian v2 — quarry boss

Owner request, 2026-11-01: rebuild the quarry boss like the new Zombar, with particular care for the animations and the boss's actual abilities. Blender runs headlessly (`-b`); no Studio or desktop notifications during this work.

## What is confirmed

The wiki describes a stone giant guarding the quarry, a hardened-lava sword, and basalt spikes erupting under its blows [menu: `wiki/in-game-wiki/BOSS-CARDS.md`]. The client audit contains these clips [client: `wiki/client-audit/RESOURCEPACK-BOSSES.md`, `content-analysis/resourcepack/boss-model-animations.json`]:

| Source clip | Duration | Our implementation |
| --- | ---: | --- |
| idle | 3.25 s | Subtle chest, head and shoulder-plate movement |
| walk | 1.5 s | Planted stance, lifted swing foot, knee/ankle solve, weight shift |
| attack_1 | 1.5 s | Diagonal one-handed chop (`melee`), impact at 0.62 s |
| sword_slash | 1.8 s | Coiled torso, broad sweep, lava wave released at 0.7 s |
| sword_smash | 3.5 s | Two-hand grip, preparation, ground strike at 1.9 s, heavy recovery |
| sword_spike | 4 s | Sword plant, channel, spike burst at 2.15 s, extraction |
| death | 4 s | Blade support, knees buckle, body lists and collapses, plates settle |

**Names and clip durations are facts; exact poses, release times, ranges, effects and interpretation are our decisions.** The audit does not recover server hit geometry. The generic Minotaur charge is no longer selected for this boss; slash/smash/spike replace that generic rotation. The old `fight.charge` fields remain for shared fallback code. HP 200, melee damage 0.2, special damage 0.5 and respawn 20 minutes remain unchanged [earlier owner settings]. Existing shield during casts remains.

## Model and motion

Original concept: `basalt-reference-v2.png`. Editable source: `basalt_guardian.py` / `basalt_guardian.blend`. The 422 cuboids and 24 joints [implementation] include pelvis/chest/head, independent shoulder plates, elbows, wrists, stone fingers, thighs, shins, feet, back plate and sword. The shoulders and back are solid stepped volumes. Orange glow is confined to narrow seams; the old root PointLight is disabled [decision]. The existing uploaded stone noise is unchanged, so no Roblox upload is needed. No third-party geometry or keyframes were imported.

The two-hand smash uses analytic arm IK throughout the fast downward stroke, keeping the hands on the same grip. Large strokes lead from the torso, extend the elbow, then settle the wrist and armour plates. Walk phase follows the authored stride speed; the sword clears the ground during locomotion. Curves use the shared opt-in Blender bake and packed export added for Zombar. Death folds the knees and torso, relaxes the arms onto the ground, opens the hand and lays the sword beside the body. It holds the final pose and never topples or physically dismantles the entire rig.

`render_motion.py` decodes the exported Roblox clips, compares their transforms to Blender at 60 Hz and checks death-floor contact, initial foot placement, final torso clearance and two-hand grip spacing before rendering. The fixed camera for each clip fits the entire swept model including the sword. `motion-validation.json` records measured errors. The preview has no in-game projectiles or spike effects: it shows the model animation itself.

Death uses the shared pipeline's opt-in `GROUND_SUBSTEPS=4` [decision]: support height is baked at 120 Hz with linear correction keys, so switching support from feet to blade to torso does not introduce spline overshoot. The default remains one sample per Blender frame for existing models.

Review: `basalt-showcase.png`, `basalt-motion.mp4`, `basalt-death.gif`, `basalt-death-poses.png`, `v2-review-*.png` and `v2-compare-*.png`. Older references, voxel data and unprefixed previews in this folder are historical, not inputs to v2.

## Gameplay integration and checks

`BasaltAbilities` owns a cancellable cast session. Death clears telegraphs, projectiles and spikes; every delayed impact rechecks that the same live boss still owns the cast. Server-side geometry checks prevent hits through walls, above/below the arena, and repeated hits from overlapping spikes. Spike locations are capped at 18 with three small columns each [decision]. Damage and temporary control locks are server-owned. Existing bosses retain their previous ability paths.

Offline checks: `node scripts/model-tools/validate-basalt.cjs`, the Zombar/Splinter validators, Selene, StyLua, Rojo build, Python syntax and rendered-pose inspection. The Basalt validator compares durations directly with the recovered client JSON.

Final measured export: 3,920 keys, 173,097 JSON characters; maximum local difference from Blender 0.00794 studs / 0.354 degrees. Ground-contact deviation during death is −0.0292 to +0.0282 studs; two-hand grip-spacing error during the smash is at most 0.0147 studs [measured, `motion-validation.json`]. These are offline animation measurements, not a Roblox performance or live-combat test.

Evening **Play/Server** check: execute `scripts/qa-basalt-runtime.luau` (wrap in `task.spawn` when using MCP); inspect `ServerStorage.QABasaltResult`. It creates distant fixtures and checks each ability's hit, wall, death cancellation, dodge and movement restoration without editing player profiles or rewards. **This runtime test has been prepared but not executed** because Studio is forbidden for this session.

Full source sync in Edit, then restart Play. No map rebuild or `.blend` import is required. On the real quarry arena check sword clearance, two-hand grip during transitions, impact timing versus telegraphs, wall/corner behavior, death during every attack, one reward, respawn, two clients/streaming and phone FPS. Regression-check Zombar and Splinter. Do not save the source-only Rojo build over the full cloud map.

## Headless reproduction

```powershell
$blenderExe = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blenderExe -b -t 4 --python-exit-code 1 -P assets/models/basalt_guardian/basalt_guardian.py -- build
& $blenderExe -b assets/models/basalt_guardian/basalt_guardian.blend -t 4 --python-exit-code 1 -P assets/models/basalt_guardian/basalt_guardian.py -- export
& $blenderExe -b assets/models/basalt_guardian/basalt_guardian.blend -t 4 --python-exit-code 1 -P assets/models/basalt_guardian/render_motion.py
python assets/models/basalt_guardian/assemble_motion.py
& $blenderExe -b assets/models/basalt_guardian/basalt_guardian.blend -t 4 --python-exit-code 1 -P assets/models/basalt_guardian/basalt_guardian.py -- compare
```

Assembly needs Pillow and FFmpeg. Review video is 20 fps [decision for size]; Roblox samples animations every simulation frame. Frame folders and logs are ignored.
