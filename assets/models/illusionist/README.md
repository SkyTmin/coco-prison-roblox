# Illusionist — Empty Fortress

Original matte voxel stage magician: 359 cuboids, 34 joints and 16 clips [implementation]. Separate fingers, wrists, jaw, fringe, three-segment coat tails, top hat, dagger and cards. Original summoned rabbit: 72 cuboids, 12 joints, five clips [implementation]. All geometry/poses authored in headless Blender; no commercial mesh or animation copied.

Review: `illusionist-motion.mp4`, `illusionist-death.mp4`, `illusionist-death.gif`, `illusionist-showcase.png`, `illusionist-death-poses.png`, and orthographic `compare-front/side/back.png`. Videos sample the exported Roblox tracks. Generated concept `illusionist-reference.png` used built-in image_gen; exact prompt/mode/date in `concept-prompt.txt`. Proportions were adapted for an economical articulated game model. Face fringe was shortened after reviewing the first render so the eyes remain visible.

## Evidence and decisions

- [wiki/menu] Empty Fortress, unlock 15, 3-hour respawn, stars 5–9, money $0–6500, powder label 1–12%. Sources: `wiki/in-game-wiki/HANDBOOK-WIKI.md`, `BOSS-CARDS.md`, `wiki/client-audit/BOSS-MENU-RECOVERY.md`. The exact original powder formula is unknown; existing reward decisions are unchanged. Chat still reports only damage and dollars.
- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`, `illusionist/illusionist.model`: dagger 1.3375s, cards 2.006s, box 2.2s, rabbits 3.35s, card phase 1s, regeneration 5.9s, active 1.8s, death 8s; rabbit explosion/death 3.5s. Clip names/durations are evidence; server geometry, damage timing and behavior below are our interpretation, not recovered server code.
- [decision] Existing HP1340, ordinary damage14, special22/heavy28 and respawn/loot retained. Two alternating one-second dagger swings contact at .46/.50s. Shared armor, hit immunity and boss burst limit remain in force. [owner] All actions are vulnerable; no defensive blocks.
- [decision] Dagger release .71s, range34, speed24. Card fan release1.02s, range30, speed20, three/five cards separated by12 degrees. A fan can damage each fighter at most once. Projectiles use swept collision, stop at walls and arena bounds, originate at the exported animated hand, and cannot start across a wall. Projectiles survive the next cast but die with their encounter.
- [decision] Box locks a ground warning within22 studs, radius4.2; after1.21s it deals28 damage and four matte panels fold outward. Ground effects reject walls, empty space and a different floor; moving out of the warning avoids the hit.
- [decision] Summon creates three rabbits, four in phase two, maximum four living. Each has10 HP, speed10, lifetime14s. Within4 studs it stops and shows a4.5-stud warning for2.5s, then deals14 damage once. Killing it before the release cancels the explosion. Ear/body/paw warning and3.5s articulated death are client animated; no falling physics debris. Death/clear removes all encounter adds and effects. No summon reward farm is introduced.
- [decision] Card phase is a vulnerable six-stud lateral movement with a marked endpoint and swept wall/low-obstacle checks. It produces no character/boss clone and refuses an unsupported endpoint.
- [decision] Regeneration lasts5.9s, starts after1.3s, heals2% max HP four times at .8s intervals (maximum8%=107.2 HP). Accumulating40 damage interrupts it with a flinch; it cannot overheal and stops without opponents, on death or clear. Next special is at least1.5s after the cast's scheduled end.
- [decision] Eight-second death: stagger, knees fold, torso falls, head/hands settle with delayed motion; dagger/cards/hat detach separately. Locomotion uses planted-foot IK and trailing cloth motion. All effects use bounded matte parts, no lights/Neon/bloom.

## Validation

- Exported tracks at60Hz: max local position error .00798 studs, rotation .365 degrees, stance error .01803 studs; death full-model/body floor error below .021 studs. `motion-validation.json` records the measurements.
- Initial installed Katorga suite:40 isolated scenarios /82 assertions PASS. Actual client animator:14 checks PASS, position error .00000912 studs and rotation .0396 degrees; includes real MobAnimator rabbit fuse/death.
- Initial90-second live fight:425 samples,100 unanchored, all six specials observed, one complete boss, server ownership explicit, rootY9004.4971 constant. Owner returned, Creative on, mouse.5 retained; one client character. Initial console had a transient startup Sfx WaitForChild warning, then client/server ready; known asset203785492 type warning remains.
- Final revision installed: 44 scenarios / 92 server checks PASS, including missing floor and support removed during a cast. Client animation 14 checks PASS (max position .00000917 studs, rotation .0396 degrees). Repeated 90-second fight: 424 samples, 102 unanchored, all six specials, one intact boss, server ownership, constant Y9004.4971. No-block regression 43 checks PASS. Server inventory contains exactly one of each of the 19 bosses; client has one own character, zero equipment glints, Bloom/ColorGrading off. Player returned to spawn, Creative on, saved mouse .5 preserved.
- Final model/curve renders and front/side/back comparison reviewed. Selene, StyLua, Rojo build, Python syntax, module-size and diff checks pass. Nothing published to Roblox; repository scripts installed into the owner-confirmed Katorga place.
- Real group/mobile/load tests remain open. Headless only; one Blender process at a time.

## Rebuild

Blender5.2: `-b -t 2 -P illusionist.py -- build`, then `-b illusionist.blend -t 2 -P illusionist.py -- export --data-only`; `-- compare` renders the reference views. `render_motion.py` then `assemble_motion.py` produce review videos from exported tracks. Rabbit uses `illusionist_rabbit.py` with the same build/export commands. Run `configure_runtime.py`, then `node scripts/build-configs.mjs`; sync IllusionistAbilities, BossService, bosses and all six illusionist model modules. `integrate_runtime.py` records the guarded one-time BossService edit, not an every-build command.

Noise is byte-identical to the existing uploaded tile; see `ids.json`. Every model/clip module stays below200000 characters.
