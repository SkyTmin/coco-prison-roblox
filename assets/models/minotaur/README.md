# Minotaur — original model and articulated motion

Owner request, 2026-11-01: continue with the next boss after Splinter. The next unfinished boss by location progression is **Минотавр / Minotaur**, level 5 at Подножье горы [menu]. This work uses Blender **headlessly (`-b`)**, with no Studio, Blender window, desktop notification, publication, or purchased asset.

## Sources and decisions

- [In-game handbook](../../../wiki/in-game-wiki/HANDBOOK-WIKI.md): brown horned guardian, sleeping in chains, awakening and breaking his bonds [wiki].
- [Boss cards](../../../wiki/in-game-wiki/BOSS-CARDS.md): location and description [menu].
- [Resource-pack audit](../../../wiki/client-audit/RESOURCEPACK-BOSSES.md) and [animation inventory](../../../wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json): names/durations, the rooted dirt projectile, and collision/stun sounds [client]. All animation events are empty: **contact times, poses, hit volumes and exact server mechanics were not recovered**.
- The axe described in `docs/research/boss-from-instruments.md` belongs to another project's Minotaur. This model has free hands, horns and hooves.
- Store candidates remain in [BOSS-ASSET-SHOPS.md](../../../wiki/web-research/BOSS-ASSET-SHOPS.md). Neither candidate is established as Cristalix's original. No commercial geometry or animation was downloaded or copied.

`minotaur-reference.png` is an original concept generated with the built-in image generator, followed by our own cuboid sculpture and keyframes. The exact prompt is in `concept-prompt.txt`. The reference is a design guide, not a promise of pixel-identical views. The existing uploaded gray fur-noise tile is reused without alteration (`rbxassetid://93131048217957`); no Roblox image upload is needed.

## Clips

| Our clip | Audited clip / duration [client] | Authored behavior [decision] |
| --- | --- | --- |
| idle | idle, 5.83333 s | Breathing, head weight, delayed ears, beard and tail |
| walk | walk, 1.08333 s | Constant-speed planted hoof phase, knee/ankle IK, shoulder counter-rotation |
| run | run, 0.66667 s | Longer stride and greater compression; plays during fast pursuit |
| melee | attack_horns, 1.125 s | Crouch, muzzle lowered, upward horn blow; contact 0.55 s |
| impact | impact, 1.16667 s | Hoof raised, ground strike at 0.6 s, compress/recover |
| double_attack | double_attack, 1.66667 s | Opposite-hand blows at 0.55 / 1.05 s, torso leads each hand |
| throws_the_ground | throws_the_ground, 3.58333 s | Dig/lift, two-hand hold above the head, release at 2.25 s |
| minotaur_rush | minotaur_rush, 4.125 s | Lowered horns, windup 1.35 s, charge and braking |
| stun | stun, 3.79167 s | Collision recoil, buckling knees, shaking head, recovery |
| sleep | sleeping_minotaur idle, 8.58333 s | Kneeling, breathing, lowered head, loose shackles |
| awakening | sleeping_minotaur awakening, 9.83333 s | Look up, tense arms, pull apart, rise, roar and settle |
| death | death, 12.95833 s | Recoil, failing stance, knees, failed recovery, brace, side impact, settling |
| hurt_1 / hurt_2 | 0.375 s each | Authored left/right flinch assets, reserved for future hit reactions |
| jump / roar | Extra project utility clips | Existing chase jump / resumed-fight roar support |

The sculpture has **456 cuboids and 34 joints [implementation]**: pelvis, chest, head, jaw, beard, ears, articulated arms/hands/fingers/thumbs, thighs/shins/hooves, two sections of each hanging chain, loincloth and four tail sections. Dark fur continues over the shoulders and the closed back. No Neon eyes or body lamp.

Two-hand IK is solved throughout the lift, including between acting poses; the server samples the same exported wrists to carry the clod. Loose wrist chains compensate for the forearm rotation and hang down when the arms are raised. Their tips, ears, beard and tail respond later than the torso. Death stays articulated and holds its final pose; the rig is never physically dismantled or toppled as a rigid object.

The authored walk speed is 2.7692 studs/s and run speed 9 studs/s [implementation]. The client scales their phase to actual movement and chooses the running clip for fast pursuit. Charge is an authored forward burst, not general walking; the server moves its root. Preview videos show local articulation, without in-game root travel or combat effects; the throw preview includes the carried clod until release.

## Server integration

`MinotaurAbilities` replaces the generic blade/spikes/charge rotation only for this boss. Horns are its normal melee attack; the four special attacks rotate through stomp, double strike, rooted clod, and rush. Damage remains **2 melee, 4 total per stomp/double/clod, 5 rush**, with existing **1000 HP, 450 maximum base bank and 1500 s respawn [earlier project decisions]**. The two fist contacts each deal 2. Exact geometry, flight and timing are new decisions in `scripts/design-decisions.json`, not claimed original server data.

Fresh full-health spawns sleep until a fighter enters the arena. Awakening locks movement for its full audited duration; the initial awakening is shielded [decision]. Existing decorative arena chains drop/fade at the arms-apart key, 142/30 s, and return on respawn; broken wrist links remain on the model. A saved wounded boss resumes awake. The previous shield during special casts remains; collision removes it immediately for the stun window. Horn melee does not add invulnerability. Every cast can be cancelled by death or replacement.

The ground throw has a fixed warning circle, a two-hand carried clod with four small root strips, then a swept ballistic flight. Walls block launch/flight and area damage. Rush sweeps the boss volume, checks walls added during travel, remains inside the arena, damages a fighter at most once, and switches to `stun` on an obstacle. The original 1.7× stunned damage multiplier remains; the new stun window is the audited 3.79167 s [decision to align gameplay with this clip]. Generation tokens cancel delayed hits, projectiles and movement on death or replacement. Only eight dust particles per impact; visual effects are outside the boss model.

## Files and validation

- Source: `minotaur.py`, `motion.py`, `minotaur.blend`; headless pipeline `../blockmob.py`.
- Game data: `src/shared/Models/minotaur.json` plus `minotaur_locomotion`, `minotaur_combat`, `minotaur_rush`, `minotaur_awakening`, `minotaur_death` JSON modules. All five chunks must be synced.
- Review: `minotaur-motion.mp4`, `minotaur-awakening.mp4`, `minotaur-death.mp4`, `minotaur-death.gif`, `minotaur-showcase.png`, `minotaur-death-poses.png`.
- `render_motion.py` decodes the **exported** tracks and compares them with Blender at 60 Hz, measures ground contact, hoof stance, release socket and two-hand spacing, then renders the decoded clips. `motion-validation.json` records measured results. `assemble_motion.py` builds the media from these frames.
- `node scripts/model-tools/validate-minotaur.cjs` checks hierarchy, finite/normalized keys, loops, actual audit durations, per-module size, generated configuration, retained HP/damage/rewards, and byte-identical reuse of the uploaded texture.

The optional `BATCH_SAMPLE` exporter path evaluates the Blender scene once per time sample for all joints, instead of once per joint. Existing models retain their old path. Curve baking/simplification tolerances remain unchanged; this makes the long awakening/death clips practical without discarding motion detail.

Measured at 60 Hz: maximum local export error **0.00796 stud / 0.372°**, planted-hoof error **0.04586 stud**, carried-clod hand-spacing error **0.01689 stud**, and release-socket error **0.00239 stud**. Death-floor minimum/maximum **−0.01479 / +0.00946 stud**; final shoulder/hip support is on the floor. The abdomen naturally remains above it because the shoulder is wider. Current packed data: **11,339 keys / 524,398 characters total**, largest module **148,665** [measurement].

The rush supplements swept collision with starting-volume overlap checks, including a wall inserted during travel; see the [Roblox WorldRoot query API](https://create.roblox.com/docs/reference/engine/classes/WorldRoot) and [OverlapParams](https://create.roblox.com/docs/reference/engine/datatypes/OverlapParams). This behavior still needs the prepared Studio runtime tests.

Rebuild from repository root (PowerShell, no GUI):

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 -P assets/models/minotaur/minotaur.py -- build
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b assets/models/minotaur/minotaur.blend -t 4 -P assets/models/minotaur/minotaur.py -- export
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b assets/models/minotaur/minotaur.blend -t 4 -P assets/models/minotaur/render_motion.py
& 'C:/Users/user/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' assets/models/minotaur/assemble_motion.py
node scripts/model-tools/validate-minotaur.cjs
```

**Studio QA has not run.** In the evening: full source sync, restart Play, run `scripts/qa-minotaur-runtime.luau` on the server and read `ServerStorage.QAMinotaurResult`; it uses distant disposable fixtures and does not mutate profiles or rewards. Then inspect the real mountain arena: sleep/awakening/chains, foot placement on the slab, pursuit cadence, clod clearance and wall hits, a dynamic obstacle during rush, stun damage, death during every skill, restoration after respawn, two clients, streaming, and phone frame time. A source-only Rojo build does not update the saved map or publish the game.
