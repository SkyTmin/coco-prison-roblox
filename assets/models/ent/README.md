# Groot / Ent King — original offline checkpoint

02 November2026, baseline450a60c. **Studio fixture/animation suites passed on 02.11 after the owner resumed QA; full arena/group/mobile acceptance remains open.** Blender ran headlessly with two threads; no desktop controls, GUI launch or notifications.

## Evidence and balance

- [wiki/menu] Farm, unlock31; ancient wooden forest guardian. Respawn5h30m, money$0–15000, stars11–17, Lunar Steel. Existing reward interpretation and public damage/share/dollars-only chat retained [owner].
- [primary] [SamusDev Ent Pack](https://mcmodels.net/products/11019/ent-pack), checked02.11: Ent King has two melee attacks and four skills, Twisted Branch, Branch Wave, Leaf Storm, Tree Minions. A separate Ent Guardian exists in that pack; do not equate it with our later Forest Guardian without evidence. Minecraft pack only; no commercial geometry/animation imported and no Roblox redistribution rights assumed.
- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`: ent idle2, walk1.0288, rightpunch1.5292, leftpunch1.5358, stomp2.2931, shout1.9355, rise2.4173, death3.3084; branch1.6667; minion idle2/walk.6667/attack1.0833/death2.2917/spawn1.8333. Full source notes in `research-notes.md`.
- [owner/decision] Existing3160HP, damage35/46/58, combat regeneration8HP/s and rewards unchanged. Contact times, damage budgets, interrupt rules, warnings, cap and lifetime below are original authored decisions, not recovered server facts. Our death4.4s, leafstorm5.2s and spawn2.4s are deliberate new timings.

## Model and motion [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Oak king |1298|54|12|
| Young oak minion |164|22|6|
| Emerging branch |8|4|1|
| Leaf swirl |24|4|1|

Original generated turnaround and exact prompt retained. Closed stepped timber trunk/back, layered bark, ring scars, knot face, hinged jaw and root beard, independent root fingers/toes, six articulated crown branches, leaves on supporting stems, hanging vines and shelf fungi. Original compact young-tree summon, emerging root and leaf prop. No emissive geometry/lights, player clones or unrelated highlights; uploaded gray noise reused byte-identically.

Planted IK stride fits the client speed-rate cap. Both punches use hand IK, torso weight shift and recovery; stomp lifts one root foot and compresses on contact. Branch raise and sustained leaf storm animate arms, jaw, crown and vines. Death4.4s recoils, loses knee support, catches with an arm, falls forward and relaxes fingers/jaw; no rigid whole-body spin. Minion has its own2.2917s collapse. Body parts remain immutable at runtime; only joints and roots move. Dense bark geometry still needs real mobile/FPS profiling.

## Encounter [authored decisions]

All damage below is raw, before armor/books, ordinary hurt immunity and the existing shared burst cap. No block, cast immunity or camera control.

| Move | Timing | Behavior / counterplay |
|---|---|---|
| Right / left punch |1.5292/.92 and1.5358/.96s duration/contact|35 damage, radius8,70° half-arc; alternate hands, leave reach/front|
| Twisted Branch |rise2.4173s, release1.5, emergence contact+.4333|three locked patches/five in phase two, radius3.1/range26;46 shared damage even on overlaps; leave warnings or use cover|
| Branch Wave |stomp2.2931s, release1.35|six marked points spaced4studs out to24; progression12studs/s, emergence+.4333, radius2.5;46 shared damage; sidestep, walls/support loss stop later points|
| Leaf Storm |5.2s, contacts2.1/3.2/4.3|58 total across three pulses; radius17, safe inner radius4,70° safe wedge on boss right, jump above4.3 relative to floor; cover works;140 net HP loss interrupts into1s vulnerable stagger|
| Tree Minions |shout1.9355s, release1.15, stagger.15|two/three in phase two; at most four living summons; each60HP,12damage, speed8, reach4.1/contact.65/cooldown1.7|

Special recovery1.8s; existing phase-two cooldown scale retained. Minions spawn1.8333s, live at most24s after spawn (death timer also cancels a late bite), then play2.2917s death. Server network ownership, ordinary Mob targets, no boss rewards. Boss death/leash/root replacement destroys the encounter and cancels damage. No floor/headroom means no root summon; floor height, walls and ceilings are checked again before damage. Branch-wave effects can finish after the short casting animation; lifetime and shared hit budget remain bounded. Warnings/impact fragments are matte, leaves are a small animated prop instead of particle emitters.

## Verification and handoff

All20 clips rendered from the exported Roblox tracks. Four blends/10 JSON modules, largest152231 characters. Main local position error<.008stud, rotation<.352°, planted stance<.022stud, final torso-to-floor distance<.072stud and full death silhouette error<.02stud. Minion position<.008stud/rotation<.35°, stance<.005stud, final torso floor error<.003stud. Leaf/branch reports retained. The original reference contains more fine detail than this cuboid game rig.

`audit.py` checks target-only settings against450a60c, finite/sorted curves, normalized quaternions, module names/budgets, contact/death timing, gait playback rates, texture hash and complete render manifests. Selene/StyLua/Rojo and boss balance simulation pass. This is offline consistency, not live combat/FPS/multiplayer validation.

**Studio update02.11, Katorga92594200898716:** source/models-only sync preserved the cloud map. `qa-ent-runtime.luau` PASS: 41cases/123checks; `qa-ent-animation-client.luau` PASS: 15checks on actual client Motor6Ds. No-block43checks and ordinary-mob bite regression pass. Boss transforms now update in PreSimulation (see [Roblox timing](https://create.roblox.com/docs/reference/engine/classes/Motor6D)); all six pending client suites pass, including fast props. Full live arena encounters, real4–6-player combat, phone/load tests and owner visual acceptance remain open. `studio-validation.json` is PARTIAL and lists the remaining work. Fixtures removed, default viewport/camera and Creative restored; no publishing.

## Media / rebuild

`ent-motion.mp4`, `ent-death.mp4`/`.gif`, `ent-death-poses.png`, `ent-showcase.png`, front/side/back comparisons; minion/branch/leaves videos and previews. Rebuild one Blender process at a time: `-b -t 2 --python-exit-code 1 -P <id>.py -- build`, then `-b <id>.blend ... -- export`. Main `render_motion.py`; companions `review_summons.py -- <id>`; main `-- compare`; Python `assemble_motion.py`, `audit.py`. Edit `scripts/design-decisions.json`, regenerate with `node scripts/build-configs.mjs`; never hand-edit generated configs. Raw frames/logs/backups ignored.
