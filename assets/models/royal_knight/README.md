# Royal Garden Knight

Original generated concept and original headless Blender sculpture, 415 cuboids, 30 articulated joints, 25 clips [implementation]. The reference is a design guide; no purchased or recovered commercial geometry/animation is included. Sword, shield, neck, fingers, plume and three cape segments move independently. Matte metal, no lamps/Neon. Noise is byte-identical to the already uploaded texture (see `ids.json`).

Review: `knight-motion.mp4`, `knight-death.mp4`, `knight-death.gif`, `knight-showcase.png`, `knight-death-poses.png`, orthographic `compare-front/side/back.png`. These are renders of exported Roblox quaternion tracks, not a separate polished animation. Blender remains background-only. `royal_knight.blend` and the Python files reproduce the model and poses.

## Evidence and decisions

- [client] `wiki/client-audit/RESOURCEPACK-BOSSES.md` and `content-analysis/resourcepack/boss-model-animations.json`, key `knight/knight.model`: c1/c2/c3 .65 s, c4 .95, c5 1; dash front/left/right .65, back .8; leap 2; spin loop .25, pierce .6977; barrier loop .8; bulwark 1.5; fury1 2.9, fury2 2.75; vicious strike 4.75; flinch 2.5; death 3.85; opening 1.5 [client]. Original pose curves were not copied.
- [wiki/menu] Royal Garden level 11, 1 h 45 respawn; money 0–3100, stars 3–5, powder label 1–8%. The exact original powder formula remains unknown; existing loot decisions unchanged. Sources: `BOSS-CARDS.md`, `BOSS-MENU-RECOVERY.md`.
- [decision] 920 HP is the current intermediate balance; [owner] all bosses have no blocks/defensive immunity, even during skills or arrival (02.11). The barrier is a visual preparation followed by a shield bash; it never rejects damage. Chat stays damage and dollars only, rewards stay private.
- [decision] Five ordinary sword actions cycle individually at the existing 1.9 s cooldown, 10 damage; contacts .30/.31/.33/.50/.56 s. Fury cuts split 16 damage across two contacts; leap and vicious impact deal 20. Whirlwind spreads 12 across three contacts and adds an 8-damage forward thrust. Guard/bash deals 10. All are raw before armor and the existing burst limiter. Phase 2 retains the existing shorter special cooldown, no extra unannounced hit.
- [decision] Seven special actions cycle: leap, fury1, spin/pierce, guard/bash, directional dash, fury2, vicious ground impact. Dash directions cycle front/left/right/back. It deals no contact damage; walls cause a 2.5 s flinch. Range/angles/radii/contact times and interpretation of ability names are our mechanics, not claimed recovered server behavior.
- [decision] Root movement checks arena boundaries, swept body volume, low obstacles and overlaps. Damage checks current position/line of sight; dying or clearing cancels all delayed contacts and effects. No model recoloring, extra lights, or costly per-part physics. Impact debris is eight separate matte cuboids.

## Validation

- 52 isolated Studio scenarios / 156 assertions PASS: all damage skills, dodge, existing/new walls, death cancellation, five normal contacts, no melee starvation of specials, four dash directions including initial overlap, recovery, arrival. Fixtures do not alter real profiles or rewards.
- 22 actual client animation checks PASS after the final death refinement, maximum joint error .000015 studs / .040 degrees. Includes the real-time spin and guard loops.
- Export sampler checks all clips at 60 Hz; `motion-validation.json` records curve error, stance error and death ground contact. Sword and shield are released and grounded independently. The knees buckle, the torso rolls forward, palms settle, and the corpse lies on the ground. Support review: helmet .251 studs, knee .078, palms .139 above the floor; cloth/props touch it. Export errors: .00805 studs/.374 degrees; stance .01681 studs; floor -0.02282 to +0.00659 studs.
- Royal Garden front/back inspected in the owner-confirmed Katorga, PlaceId 92594200898716. Camera restored after brief checks. No publication.
- One preview export hit a system-memory/GPU allocation failure; its already-written data passed the 60 Hz sampler, and the deliverable previews/videos were regenerated successfully from those exported tracks after stopping Play. Real group/mobile/load playtesting remains open. Previous Skeleton cold-start timed-suite discrepancy remains unresolved, tracked in `docs/research/boss-production-queue.md`.

## Rebuild

Run Blender 5.2 `-b -P royal_knight.py -- build`, then `-b royal_knight.blend -P royal_knight.py -- export`, `-- compare`. Run `render_motion.py` on the blend, then `assemble_motion.py` with the Codex Python executable. `--death-only` reuses the prior review manifest. `configure_runtime.py` edits only this boss's object in design-decisions; regenerate configs with `node scripts/build-configs.mjs`.

Sync all `royal_knight*.json` modules alongside KnightAbilities, BossService, BossAnimator and generated bosses config. Each data module stays below the 200000-character ModuleScript limit.
