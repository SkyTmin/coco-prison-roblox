# King of Piglins — original Blender boss

01 November 2026. Next boss after Minotaur, Underworld level 7 [menu]. Original concept generated with the built-in image tool (`concept-prompt.txt`), original cuboids and keyframes. Blender runs headlessly; no purchased geometry or animation was copied. The commercial reference is [The Piglin Glutton, PeachTree](https://mcmodels.net/products/13093/the-piglin-glutton); see the repository's [resource-pack audit](../../../wiki/client-audit/RESOURCEPACK-BOSSES.md).

## Model and motion

The king has 708 cuboids and 33 joints [implementation]: articulated pelvis/chest, shoulders/elbows/wrists/fingers, knees/hooves, ears, jaw, tail, cloth, pouch, medal and a separate axe. Matte brown skin, rounded closed back, asymmetric gold armor and burgundy cloth. No Neon parts or body light. Guards use a separate 113-part model with the same joint conventions.

| Clip | Duration [client audit] | Authored motion / gameplay [decision] |
| --- | ---: | --- |
| idle / walk | 8.4167 / 2 s | Breathing, delayed ears/tail, planted hooves |
| spawn | 5.6667 s | Heavy arrival, stand, display axe, recover |
| verticalatk / horizontalatk | 3.0246 / 3.0303 s | Alternating weight-shifted axe blows; contact 1.35 / 1.4 s |
| footstomp | 2.5 s | Lift hoof, lean onto support leg, impact 1.1 s |
| spinslam | 5 s | Turn torso/axe, low sweep at 1.8 s, impact at 2.7 s |
| bodyslam | 5 s | Crouch, jump forward, belly landing, push back up |
| upchuck | 6.0095 s | Inhale, retch, release from animated mouth at 2.5 s |
| charge | 10.0059 s | Lower body, burst at 2 s, brake, recover |
| healing | 7.0813 s | Reach food to mouth; heal at 3.6 s, interruptible |
| summoningchant | 4.0064 s | Raise arms, chest rhythm, summon guards |
| hurt | 1.5 s | Flinch after interrupted eating |
| death | 5 s | Knees buckle, brace, side fall, release axe, separate settling |

Extra original utility clips: run 1 s and jump 0.8 s [decision]. Guard idle/walk/bite/hurt/death follow the audited minion durations; bite contact is 0.297577 s [decision]. Pose curves and exact attack events were not recovered from the original server; only clip names/durations and related assets are evidence.

`king_motion.py` authors continuous poses, foot IK and delayed secondary motion. `render_motion.py` samples the exported Roblox tracks at 60 Hz and renders those tracks, not a separate prettier animation. Walk/run phase scales with actual root speed. Server effects sample the exported hand/mouth sockets. Death stays articulated and holds its last pose; it does not rotate a rigid model. Optional `GROUND_DETACHED` in the common exporter floors the released axe separately without changing old models.

## Gameplay and rewards

Current balance: **580 HP, melee 6, stomp 10, spin 5 + 10, belly/charge 12, spit 10 total over three ticks** [decision, owner requested overall progression]. Healing restores 10% maximum HP but losing 8% maximum HP during its windup interrupts it. Summons two guards, three below half HP, at most four alive: 18 HP, 3 damage, 18 s lifetime. All skill ranges/contact times are in `scripts/design-decisions.json` under `bosses.piglin.fight.piglin`.

Seven specials rotate separately from alternating melee. Ordinary melee cannot postpone the special timer. Casts are vulnerable, restore movement and cancel delayed damage/effects on death or replacement. Guards survive between casts and disappear with the encounter. Swept charge checks existing/new walls, starting overlaps and the circular arena boundary. Ground impacts and poison check walls/line of sight. Effects remain outside the model, with bounded particles.

Money bank 0–420 and powder label 1–3% [wiki/menu] remain unchanged. The percentage's exact current server interpretation is not recovered; our share-based roll is explicitly a decision. Chat only lists participants' damage and dollars. See [all-boss balance and loot audit](../../../docs/research/boss-balance-2026-11-01.md).

## Deliverables and validation

- Editable sources: `piglin_king.py`, `king_motion.py`, `piglin_king.blend`, `piglin_guard.py`, `piglin_guard.blend`.
- Review: `piglin-king-showcase.png`, `piglin-king-motion.mp4`, `piglin-king-death.mp4`, `piglin-king-death.gif`, `piglin-king-death-poses.png`, complete front/side/back renders.
- Runtime: `piglin_king.json` plus six animation chunks (axe, charge, heavy, lifecycle, locomotion, special), and `piglin_guard.json`. Sync every chunk.
- `noise.png` is byte-identical to the already uploaded Minotaur tile; `ids.json` records reuse, no upload needed.
- Export: 10,835 keys; king modules total 513,849 characters, largest 92,793; guard module 114,417 [measurement], below the 200,000-character script limit.
- Maximum sampled export error: 0.007929 stud / 0.36477 degrees; hoof stance error 0.01693 stud. Death body floor −0.00760…+0.02006 stud; released axe floor −0.02891…+0.00638 [measurement]. Full data: `motion-validation.json`.
- `validate-piglin.cjs` passed hierarchy, keys, loop seams, audited duration, configured contacts, floor proof, module budget and identical texture checks.
- Correct Studio place **92594200898716**, full repository sync, Play: `qa-piglin-runtime.luau` **63 checks across 24 isolated cases PASS**. Includes all attack families, wall blocking, dodge, death cancellation, interruptible/uninterrupted healing, phase-two summons, guard persistence/cleanup and movement restoration. Actual Underworld king inspected in game lighting. Disposable fixtures do not mutate profiles/rewards.
- Real multi-client fights and phone frame-time measurements remain to be tested. No game publication.

Rebuild from repository root with Blender 5.2 `-b -t 4 -P assets/models/piglin_king/piglin_king.py -- build`, then `-b assets/models/piglin_king/piglin_king.blend -t 4 -P assets/models/piglin_king/piglin_king.py -- export`. Guard follows the same commands with `piglin_guard`. Run `render_motion.py` with the king blend, then `assemble_motion.py` with Python/Pillow/ffmpeg. `node scripts/model-tools/validate-piglin.cjs` validates exported data. Intermediate `render-frames/` is intentionally ignored by Git.
