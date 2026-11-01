# Skeletron — original Pyramid boss

01 November 2026. Owner requested the next boss after King of Piglins. **Скелетон / Skeletron**, Pyramid, level 9 [menu]. The existing overall balance remains **740 HP, melee 8, respawn 2700 s** [owner progression / project decisions].

## Sources and boundaries

- [In-game handbook](../../../wiki/in-game-wiki/HANDBOOK-WIKI.md): fallen commander of a forgotten army, giant brown-bone skeleton; location, respawn and rewards [wiki].
- [Resource-pack audit](../../../wiki/client-audit/RESOURCEPACK-BOSSES.md), `boss-model-animations.json`: boss/minion/trap/poison clip names, lengths and related assets [client]. Boss event tracks are empty; exact poses, contact times and original server parameters were not recovered.
- [Skeleton Boss, amonde](https://mcmodels.net/products/14423/skeleton-boss), checked 01 November: alternating hand swipes, claw strikes creating skeletal traps, damaging/pushing poison, roar summoning skeletal warriors [author's public description]. No commercial asset was purchased, downloaded or copied.
- `skeleton-reference.png` is our generated turnaround from the built-in image tool; exact prompt: `concept-prompt.txt`. Geometry, keyframes and server implementation are original. All Blender commands use `-b`, no application window or desktop notification.

## Model and animation

**570 cuboids, 36 joints, 12 clips** [implementation]. Six pairs of open ribs curve around both front and rear; segmented spine, scapulae, hollow pelvis, recessed eye sockets, separate jaw/teeth, paired forearm/shin bones, three articulated fingers with independent tips, thumb, clawed toes and cloth strips. Bones are matte brown/tan with sparse bronze bindings; no Neon or body lamp. The separate warrior is **81 cuboids**, not a full boss duplicated for every summon.

| Clip | Length [client] | Authored movement and contact [decision] |
| --- | ---: | --- |
| idle | 2 s | Rib/chest movement, neck/head counter-motion, delayed fingers |
| walk | 4 s | Planted-foot IK, weight transfer, pelvis/shoulder counter-rotation |
| atkrswipe / atklswipe | 1.25 s each | Torso leads shoulder, elbow/wrist extension, contact 0.58 s, overshoot and recovery |
| sklrstomp / skllstomp | 2 s each | Raise claw, fold hips/knees, drive palm toward floor at 0.9 s, push back up |
| sklpoisonbreath | 3.5088 s | Contract/expand ribs, raise skull, jaw opens, exhale at 1.45 s, settle |
| sklroar | 5 s | Crouch, raise arms, open jaw, pulse/recoil at summon 2.4 s |
| death | 5.008 s | Recoil, knees fail, hand brace, side fall, shoulder impact, fingers and skull relax separately |

Additional original run (1.2 s), hurt (0.8 s) and jump (0.9 s) support the existing chase/animation system [decision]. Walk/run authored speed is 1.4 / 5 studs/s; client phase scales with actual movement. Death holds its final articulated pose. Skull and neck lower after the shoulder lands instead of remaining stiff above the floor.

Warrior clips: idle 3.0075, walk 1.5038, attack 1, emergence 3, death 2.5 s [client], plus original hurt 0.5 s. `MobSpawnAt` lets the real client animator play emergence; warriors cannot move or hit until it finishes. Their attacks use the sampled 0.464 s contact [decision].

## Combat

`SkeletonAbilities` replaces generic lava blade/spikes/charge behavior for this boss. Two alternating normal swipes; special rotation right ground strike → poison → left ground strike → roar. All casts remain damageable. Ordinary melee cannot postpone the special timer. Boss health/damage/reward progression is retained.

- Swipes: 8 raw damage, 8-stud range, 70-degree half-angle; walls and height checked.
- Ground strike: marked target position within 16 studs; traps last 2.5 s, radius 3.1, 13 raw damage over three 0.65 s ticks. Phase two marks up to three separated fighters. On an accepted contact, Slowness VI for 0.45 s gives a brief 90% movement reduction [decision adapting the author's stun; no permanent anchoring]. Six pairs of small bones rise, curl inward and withdraw.
- Poison: 18-stud target range, radius 4.5, 16 raw damage over six 0.8 s ticks, lifetime 5 s. Mouth origin comes from the same exported jaw animation. Checks root-to-mouth, flight path and arrival again if a wall appeared during flight. Cloud damage checks target height and line of sight. Push is horizontal, no repeated upward launch. Five low-opacity particles/s, no light emission.
- Roar: two warriors, three below half health, maximum four alive. Each has 22 HP, 4 damage, speed 5.8, 18 s active lifetime following 3 s emergence [decision]. They have their own staggered attacks and death pose, stay inside the arena and cannot hit through walls.

Hazards and minions belong to the encounter, so they survive another ordinary cast; death/replacement cancels everything. Per-cast tokens cancel windups and restore the original movement/anchor state. All damage uses shared armor, hurt immunity and boss burst limits. No profile or money mutation occurs inside the ability module.

Money bank **0–2200**, stars **1–3**, powder label **1–5%** [wiki/menu] are unchanged. The powder's exact current original roll remains unconfirmed; our existing share-based decision is documented in the [balance audit](../../../docs/research/boss-balance-2026-11-01.md). Public boss chat continues to show only damage/share/dollars; no item drops added.

## Rebuild and review

- Source: `skeleton_king.py`, `skeleton_motion.py`, `skeleton_king.blend`; warrior source/blend beside them. The common `blockmob.py` pipeline is reused.
- Generated runtime data: `skeleton_king.json` plus `_locomotion`, `_attacks`, `_ritual`, `_lifecycle`; `skeleton_minion.json`. Sync all chunks. Existing uploaded noise `rbxassetid://93131048217957` is reused byte-for-byte, recorded in `ids.json`.
- Review: `skeleton-showcase.png`, `skeleton-motion.mp4`, `skeleton-death.mp4`, `skeleton-death.gif`, `skeleton-death-poses.png`; front/side/rear comparison images. Videos show exported local articulation; server effects and root pursuit are inspected separately in Studio.
- `render_motion.py` decodes exported tracks, checks against Blender at 60 Hz, verifies planted stance and floor contact, then renders. `--validate-only` skips frames; `--death-only` updates just death frames in an existing manifest. `assemble_motion.py` produces the review files. Intermediate frames are ignored by Git.
- The common floor bake now samples the exact non-integral final frame, preventing a final reset to an uncorrected root height at lengths such as 5.008 s. Integer-duration exports are unchanged. A suspected rotated-dimension issue was checked and **not confirmed**; that speculative code change was removed.

Run headless Blender 5.2 `-b -t 4 -P assets/models/skeleton_king/skeleton_king.py -- build`, then `-b assets/models/skeleton_king/skeleton_king.blend -t 4 -P assets/models/skeleton_king/skeleton_king.py -- export`; repeat for `skeleton_minion`. Run `render_motion.py` with the king blend, then Python `assemble_motion.py`. `configure_runtime.py` reapplies only this boss's authored decisions before `node scripts/build-configs.mjs`.

Measured export error ≤0.007889 stud / 0.35388 degrees, planted-foot error 0.02668 stud; death support −0.01666…+0.02252 stud [measurement]. `validate-skeleton.cjs` checks hierarchy/keys/loops, actual audited durations, configured contacts, module limits, texture reuse, minion lifecycle and retained balance. Packed king data: 6380 keys / 311117 characters across modules, largest 97760; warrior 108458 characters, below 200000 [measurement]. `inspect_pose.py` also verifies that the skull relaxes near the floor.

Correct Studio place **92594200898716**, full source sync, Play: `qa-skeleton-runtime.luau` **61 PASS across 26 cases**; real client `qa-skeleton-animation-client.luau` **11 PASS**. Client joints matched exported swipes/stomps/breath/roar/hurt/jump/death within 0.000035 stud / 0.049 degrees; warrior emergence and held death pose passed. Actual Pyramid boss inspected in its arena lighting. Local/distant test rigs removed, camera restored, profiles/rewards untouched. Balance regression 103 PASS; Selene 0 errors/warnings, StyLua, Rojo build, model validator, balance/economy simulators and diff check pass. Existing map preserved; no publication.

A test run launched immediately during Play startup failed three assertions for complete periodic damage; the same final suite passed after loading finished. The exact startup scheduling cause is not established. This is not a stress-test certification: multi-client gameplay, startup/load behavior and real-phone frame time still need a separate session.
