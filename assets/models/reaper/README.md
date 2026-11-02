# Reaper — original offline checkpoint

02 November 2026, baseline d51e07c. **Code/models only; all Studio checks pending evening at the owner's request.** Headless Blender with two threads, no desktop controls or notifications.

## Evidence and balance

[wiki/menu] Edge Gate, unlock 35; respawn 12 h, money $0–18500, stars 12–19, Ancient Powder label 1–50%, Fire Shard. Exact shard probability/count distribution is unknown; existing interpretation retained. HP 3500, raw damage 40/52/64 and combat regeneration 12 HP/s unchanged [owner/decision]. Chat remains damage/share/dollars only. The existing analytical balance model targets 4–6 appropriately equipped players; real group balance still needs playtesting.

[client] `reaper/reaper.model`: idle 5.24, idle3 3.24, walk 3.28, attack1 .7273, attack2 .6993, soul1 4.92, circleattack 1.0526, groundattack 1.6941, teleportinto 1.1271, teleportout .7333, explosion 2.06, death 4.28, spawn 5.6; circlespin 10 loop and hurt 3.28 loop. Separate circle.model has spawn2 6 loop. Source metadata/families inform our timing; all motion is original. Our hit reaction .7 s and vulnerable stun 1 s are deliberate choices; circle rotation lives on a separate 6 s looping prop. Source notes in `research-notes.md`.

[primary, uncertain match] [AnonymousDevs Reaper Boss](https://mcmodels.net/products/11230/reaper-boss-only-boss-bundle) describes a configured boss with 14 animations; [full bundle](https://mcmodels.net/model/reaper-boss-full-bundle/) adds a usable scythe. Product image was unavailable through the web tool; identity with Cristalix is unconfirmed. EliteCreatures' similarly named Reaper lists different mechanics and is not treated as the source. No commercial assets imported.

## Model and animation [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Hooded Reaper |755|43|15|
| Matte circle |38|4|1|
| Soul mask |17|4|1|

Original generated four-view reference and exact prompt retained. Closed hood/back and robe, small recessed skull/jaw, bronze crown, layered mantle, embroidered cuffs, individual fingers, eight articulated robe sections and a gripped scythe with a child blade. Stepped fabric overlaps around the hips and lower robe. Matte jade/bone/charcoal palette; no neon, bloom, lights, player clones or full-rig visibility/material mutations. Gray noise texture reused byte-identically.

Walk 3.28 s contains two planted stride cycles, matching the client playback-rate cap. Quick cuts use world-space hand IK and weight shift. Soul casting pulses the free hand; teleport folds and opens the robe; ground/circular attacks and explosion have their own windup/contact/recovery. Death 4.28 s recoils, buckles the knees, folds the robe, releases the scythe as one joint subtree, braces/falls and relaxes fingers/jaw. Body and detached weapon are grounded independently. Main source animations and physics are separate: only root/joints move at runtime.

## Encounter [authored decisions]

Raw damage is before armor/books, normal hurt immunity and the existing shared boss burst cap. No block or defensive immunity in any phase.

| Move | Duration/contact | Behavior and escape |
|---|---|---|
| Two quick cuts |.7273/.4 and .6993/.38 s|40 damage, radius 8,75° half-arc; alternate cuts, leave reach/front or use cover; existing melee cooldown 1.6 s|
| Souls |4.92 s; launches 1.4 then every .7 s|three/five bolts in phase two, total 52 damage split across the volley; round-robin target selection, locked straight flights, range 36/speed 24, swept collision and arena checks, cap 16 live projectiles; 160 net HP loss interrupts into 1 s vulnerable stagger and cancels this spell's bolts|
| Circular sweep |1.0526/.67 s|52 damage once, radius 10; ground warning, cover works|
| Ground slash |1.6941/1.1 s, .12 s progression|five marked patches spaced 4 out to 20, radius 3; 52 shared damage across overlaps; sidestep, use walls, support loss stops progression|
| Teleport |1.1271 into +.7333 out|up to 18 studs, flank offset 8; landing warning, volume/headroom/floor/arena/wall/player checks repeated before movement; no damage or camera effect|
| Explosion |2.06/1.5 s|64 damage, radius 18; safe inner radius 4,70° sector on boss left, or jump above 4.3 relative to floor; walls protect|

Special recovery 1.8 s, existing phase-two cooldown scaling retained. Teleport is a root relocation with continuous articulated fold/open clips; no large-rig fade. Released soul projectiles can finish after the casting clip; finite range/lifetime and encounter guards remain active. Death/leash/root replacement clears props and damage. Small matte circles and eight-fragment impacts replace emissive effects; ordinary large-rig body parts remain immutable.

## Offline verification / evening handoff

Three blends, 17 exported clips rendered, nine JSON modules. Main curve comparison at 60 Hz: position error <.008 stud, rotation <.367°, planted stance <.028 stud; final torso and released scythe floor errors <.003 stud. Full death silhouette floor error <.03 stud. Companion curve reports retained. `audit.py` checks finite/sorted curves, normalized quaternions, module names/budgets, timings/gait, full render manifests, texture hash and target-only config against d51e07c. Hash comparison confirms the final robe-fold edit changes only the death clip. Selene, StyLua, Rojo and boss balance simulation pass. These are offline checks, not live combat/replication/FPS results.

**PENDING evening:** source/models-only sync into Katorga 92594200898716; run `qa-reaper-runtime.luau`, `qa-reaper-animation-client.luau`, no-block regression and an actual Edge Gate encounter in both phases. Check volley interruption/collision/expiry, all warning escapes, dynamic obstacles and landing occupancy during teleport, ownership, death/leash/respawn and console. Real 4–6-player and phone/load checks remain open. Render preflight before screenshots; preserve map, never publish, restore Creative/camera, remove fixtures. `studio-validation.json` stays PENDING. Forest Guardian's pending fixture was also corrected to use an arena radius smaller than its one-stud ground margin; no gameplay tuning changed.

## Media and rebuild

`reaper-motion.mp4`, `reaper-death.mp4`/`.gif`, `reaper-showcase.png`, `reaper-death-poses.png`, front/side/back comparisons and two prop videos. Rebuild one Blender process at a time: `-b -t 2 --python-exit-code 1 -P <model>.py -- build`, then `-b <model>.blend ... -- export`. Main `render_motion.py`; props `review_props.py -- <id>`; main `-- compare`; Python `assemble_motion.py` and `audit.py`. Raw frames/logs/backups ignored. Edit design-decisions, run build-configs; generated configs are never edited directly.
