# Poseidon — Sunken Lighthouse

Original generated concept and original headless Blender sculpture: 521 cuboids, 35 articulated joints, 18 clips [implementation]. Matte blue-gray skin, bronze/patina armor, independently moving beard, hair, cloth, fingers and trident. No commercial geometry or animation was copied. Noise is byte-identical to the already uploaded tile (SHA256 in `ids.json`).

Review artifacts: `poseidon-motion.mp4`, `poseidon-death.mp4`, `poseidon-death.gif`, `poseidon-showcase.png`, `poseidon-death-poses.png`, orthographic `compare-front/side/back.png`. Motion videos render the exported Roblox quaternion tracks, not a separate polished animation. Blender runs in background only.

## Evidence and decisions

- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`, `poseidon/mso_poseidon.model`: swing/swing_2 1 s; stab/wave_clash 1.3 s; epicenter 1.7 s; torpedo/swim/swim_idle/swim_attack 1 s; walk/run 1.2 s; idle 2.5 s; idle_sitting 3 s; kneel static. Our swim_attack plays once; swimming poses loop. No death clip appears in the audit.
- [wiki/menu] Sunken Lighthouse level 13, sea king, trident lightning/storm/tidal waves, 2 h respawn. Existing loot: $0–3800, stars 4–7, powder label 1–10%. Exact original powder formula remains unknown; existing loot decisions are preserved. Sources: `wiki/in-game-wiki/HANDBOOK-WIKI.md`, `BOSS-CARDS.md`, `wiki/client-audit/BOSS-MENU-RECOVERY.md`.
- [decision] Existing balance retained: 1120 HP, ordinary attacks 12 raw damage, wave/lightning/thrust 19, water rush 24. Armor and existing burst limiter still apply. [owner] No block or immunity during any action. Chat lists only participant damage and dollars; item rewards remain private.
- [decision] Two alternating trident swings contact at .48/.51 s. Four specials cycle: moving wave (26 studs, width 8, speed 24), ground lightning (range 18, radius 3.5), torpedo rush (18 studs) and forward thrust (11 studs, half-angle 25 degrees). These contact times, ranges and shapes interpret source action names; they are not claimed recovered server mechanics.
- [decision] Lightning locks warning locations before the strike; phase two can select two distinct fighters. The water rush has .65 s preparation, 1 s travel and a 1 s finishing thrust, with at most one 24-damage hit per fighter for the entire move. Wave damage is also once per fighter. Current positions, line of sight, arena bounds, swept body/wave volumes, low walls and initial overlaps are checked. A released wave survives the next attack but is cancelled when the boss dies or clears.
- [decision] Awakening is 3.2 s and vulnerable. Death is 4.8 s: knees lose support, spine/head fall with separate motion, hands open, legs unfold, and the released trident settles independently. Seated/awakening grip IK keeps the trident above the floor. Secondary motion follows the main action instead of rotating the whole model rigidly.
- Effects use a small fixed set of matte parts with cleanup; no lights, Neon or recoloring the entire boss.

## Validation

- Source-snapshot Studio QA: 32 isolated scenarios / 60 assertions PASS (all four skills, two normal hits, dodging, walls/low walls/initial overlap/dynamic walls, death/clear cancellation, wave lifetime, phase-two targets, effect cleanup, vulnerable awakening). Temporary distant fixtures do not mutate real profiles or rewards.
- Export sampler checks every clip at 60 Hz: maximum local position error .00797 studs, rotation .363 degrees, stance error .02107 studs. Death body-floor range −.02165 to +.00719 studs; full death/awakening/seated support within .08 studs. See `motion-validation.json`.
- Installed Katorga QA: 35 isolated cases / 68 assertions PASS, including unanchored post-cast ownership and coincident target facing; actual client animation 15 checks PASS (max .00000906 studs / .02798 degrees). Live appearance reviewed in the flooded arena.
- A 90-second live encounter passed 424 samples with 129 unanchored samples, all four specials observed, server ownership explicit, one intact model and constant root Y=7503.4985. Another 50 sampled frames deliberately overlapped the player and boss horizontally without invalid transforms. Root-deletion recovery preserved 800 HP, produced exactly one model and no death/reward, then original 1120 HP was restored. Player position and Creative restored.
- Debugging found two physics faults: unanchoring resets ownership to automatic (Roblox documentation), and CFrame.lookAt(p,p) returns NaN rotation entries (reproduced in Studio). The latter is reachable when the rush ends exactly on the player. Shared BossPhysics now preserves facing at tiny/nonfinite offsets and reclaims server ownership after anchored casts (also Knight, Skeleton, Piglin, Minotaur, Splinter and legacy charges). BossService recreates an unexpectedly lost living assembly with its HP and contributions; old callbacks cannot award a kill on the new instance. Cast arena clamping cannot create an oversized cross-map ray.
- Prior live run failed its 15-stud vertical bound before the coincident-facing correction; it is not counted as a pass. Final run retains the original 15-stud limit and validates all transform components. Regression: Knight 52 cases/156 checks, Skeleton 61 checks, boss no-block 43 checks PASS. No new production console errors; known asset 203785492 type warning persists.
- Engine ownership reference: https://create.roblox.com/docs/physics/network-ownership
- High-resolution preview export exhausted this PC's available memory. `--data-only` writes valid export data without previews; deliverables render those data at 640×480 with two threads and Play stopped. Never run multiple Blender processes here.
- Real group/mobile/load tests remain open; previous Skeleton cold-start timed-suite discrepancy remains unresolved in `docs/research/boss-production-queue.md`.

## Rebuild

Blender 5.2: `-b -P poseidon.py -- build`, then `-b poseidon.blend -t 2 -P poseidon.py -- export --data-only`; `-- compare` for reference views. Run `render_motion.py` on the blend, then `assemble_motion.py` using the Codex Python executable. `--lifecycle-only` updates the final four clips in the existing frame manifest; `--validate-only` checks curves without rendering.

`configure_runtime.py` changes only this boss object in `scripts/design-decisions.json`; regenerate with `node scripts/build-configs.mjs`. Sync all five `poseidon*.json` modules plus BossCast, PoseidonAbilities, BossService and generated bosses config. Each data module remains below 200000 characters.
