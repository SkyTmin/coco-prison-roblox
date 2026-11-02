# Forest Guardian — original offline checkpoint

02 November2026, baseline598a6c9. **Studio fixture/animation suites passed on 02.11 after the owner resumed QA; full arena/group/mobile acceptance remains open.** Blender ran headlessly with two threads; no desktop control, GUI or notifications.

## Evidence and balance

[wiki/menu] Barn unlock33, respawn12h, money$0–17300, stars11–18, Ancient Powder label1–50%, Fire Shard. Exact shard probability/count distribution remains unknown; existing reward interpretation retained. HP3340, raw damage38/49/61 and combat regeneration10HP/s unchanged [owner/decision]. Public chat remains damage/share/dollars only.

[client] `forest/tree_forest_guardian.model`: idle1.5, walk1.5, attack2, big_punch1.08333, summon3, death2. `magic_creature_minion.model`: spawn1.625, idle/walk1.5, attack1.08333, death1.83333. Menu image02.png informs the root body, green mantle, red right shoulder and blue left wrist. Details in `research-notes.md`. Exact commercial seller unconfirmed; no purchased assets imported.

[owner priority] Wiki's immunity while creatures live is deliberately omitted: all bosses must remain vulnerable. Additional root sweep, contact times, damage budgets and encounter bounds are authored decisions, not recovered source mechanics.

## Geometry and motion [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Root guardian |1147|56|11|
| Leaf-pod creature |138|22|6|
| Emerging root |8|4|1|

Original generated turnaround and prompt retained. Enclosed braided root trunk/back and limbs, layered leaf mantle with separate joints, curled root fingers, articulated crown/vines/toes, matte shoulder fungi and wrist lichen. Shared original oak skeleton/IK helpers reused; geometry and attack performance authored for this boss. The small familiar has its own leaf-pod body and short root limbs; shared original small-tree lifecycle motion is retimed to its source families. No neon, emissive geometry, lights or player clones. Existing gray noise reused byte-identically.

Walk1.5s is planted and fits the client's four-times animation-rate cap. Alternating ordinary sweeps and a faster heavy fist use hand IK, torso rotation, recoil and recovery. Summon raises both arms and settles the foliage in layers. Original4.8s death loses knee support, braces on a hand, falls diagonally, compresses the mantle and relaxes the fingers/jaw. The death's final torso is on the floor, not supported in the air by a leaf. Familiar death1.83333s is separately rendered. Runtime body geometry/materials remain immutable; only joints/root move.

## Encounter [authored decisions]

| Move | Duration / contact | Behavior and escape |
|---|---|---|
| Right/left sweep |2 /1.1s|38 raw damage, radius8,75° half-arc; alternating arms, leave front/reach or use cover|
| Heavy punch |1.08333 /.72s|61 raw damage, radius9,65° half-arc; warning, requires ground, cover works|
| Root sweep |2.8 /1.5s release, root contact+.4333|three/five locked patches in a70° fan, range6–18, radius3.1;49 shared damage even if patches overlap; leave marks; walls, ceiling, lost support or cancellation prevent damage|
| Creature summon |3 /1.65s release, stagger.2|two/three in phase two, cap four alive; each80HP,14damage, speed8, reach4.1, contact.65, cooldown1.7|

Special recovery1.8s. Summons spawn1.625s, live at most24s afterwards, death1.83333s. Explicit expiry timer cancels late attacks; server-owned ordinary Mob targets, no boss rewards or immunity. Boss death/leash/root replacement clears the encounter. Existing shared armor/book mitigation, hurt immunity and boss burst cap still apply. Tiny matte root/impact props have finite lifetimes; no full-screen effects or camera manipulation.

## Offline verification / evening handoff

All18 exported Roblox clips rendered. Three blends/eight JSON modules; largest145443 characters. Main60Hz curve comparison: position<.008stud, rotation<.354°, planted stance<.014stud, final torso-floor error<.001stud; full death floor error<.015stud. Familiar: position<.008stud, rotation<.348°, stance<.008stud, torso-floor error<.001stud. `audit.py` validates curves, module budgets/names, timings, gait rates, texture hash, render completeness and target-only config against598a6c9. Selene, StyLua, Rojo build and boss-balance simulation pass. This does not establish live damage, replication or mobile performance.

**Studio update02.11, Katorga92594200898716:** source/models-only sync preserved the cloud map. `qa-forest-guardian-runtime.luau` PASS: 27cases/85checks; `qa-forest-guardian-animation-client.luau` PASS: 13checks on actual client Motor6Ds. No-block43checks and ordinary-mob bite regression pass. Boss transforms now update in PreSimulation (see [Roblox timing](https://create.roblox.com/docs/reference/engine/classes/Motor6D)); all six pending client suites pass, including fast props. Full live arena encounters, real4–6-player combat, phone/load tests and owner visual acceptance remain open. `studio-validation.json` is PARTIAL and lists the remaining work. Fixtures removed, default viewport/camera and Creative restored; no publishing.

## Deliverables

`guardian-motion.mp4`, `guardian-death.mp4`/`.gif`, `guardian-showcase.png`, `guardian-death-poses.png`, orthographic front/side/back and companion videos/previews. Rebuild one Blender process at a time: `-b -t 2 --python-exit-code 1 -P <model>.py -- build`, then `-b <model>.blend ... -- export`; main `render_motion.py`, companions `review_summons.py -- <id>`, main `-- compare`, Python `assemble_motion.py` and `audit.py`. Generated config comes only from `scripts/design-decisions.json` via build-configs. Raw frames/logs/backups ignored.
