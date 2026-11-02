# Raven Knight — original code/model checkpoint, Studio pending

Prepared 02 November 2026. The owner explicitly deferred Studio until evening. **No Studio or desktop-control calls were made for this checkpoint; no in-game pass is claimed.** Four headless Blender rigs and server/client code are ready for that verification.

## Evidence and authorship

- [wiki/menu] Castle unlock25, respawn6h, bank$0–9000, stars9–15, Ancient Powder label1–35%: `wiki/in-game-wiki/HANDBOOK-WIKI.md`94/116/136, `BOSS-CARDS.md`42/64 and `wiki/client-audit/BOSS-MENU-RECOVERY.md`22. Existing eligibility, payout/loot interpretation and regeneration remain unchanged. Public chat stays participant damage/share/dollars only [owner].
- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`, prefix `raven/`: knight simplecombo/simplecombo2 (1.9s), fastcombo (4.35s), comboflyattack (4.25s), explosion (6s); reaper basicattack1.75/chargeattack2.55/fogcombo3/summonaxe2.04167/spikesattack2.75. These are clip names/durations, **not proof of damage/contact rules**.
- [primary web] [Ryyk Raven Knights Boss Pack](https://mcmodels.net/products/12369/raven-knights-boss-pack), checked02.11, lists Crow Knight and Crow Reaper separately with matching axe/fog/spike/swarm effects. Co-occurrence does not establish a transformation. We use a killable retainer [decision], consistent with the local localization; do not present it as a confirmed Cristalix mechanic.
- All cuboids, poses and combat mechanics here are original. No commercial meshes, textures or animation tracks were purchased/imported. Reference: `raven-knight-reference.png`, generated with built-in `image_gen`; exact prompt/mode/date: `concept-prompt.txt`.

## Models and motion [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Raven Knight |721|40|14|
| Crow Reaper retainer |671|40|10|
| Raven |48|11|3|
| Floating axe |20|2|2|

Matte charcoal plate, complete back armor, layered feather mantle/cloak, individual finger groups, hinged pauldrons, boots and released weapon. No emissive parts, lights or bloom. One existing gray texture is reused byte-for-byte (SHA256 in `ids.json`); no new upload. The reference has more fine ornament than the economical cuboid model; the main silhouette, raven helmet, open hand, feather layers and worn metal palette are retained.

Gait uses planted two-bone IK, alternating stance/swing, torso counterrotation and delayed feather motion. Attacks have separate preparation, contact, follow-through and recovery. Death5.2s [decision] loses balance, kneels, releases the weapon, catches on a shoulder, rolls forward and settles the mantle/limbs. Source death10.83333s is deliberately condensed, not copied. A retainer review caught an inward/upward axe blade hidden by its torso; its head now hangs outside/below the fist, matching the authored contact arc. Ankle mail and the chipped sword tip were closed so no detached-looking gaps remain. Normal contacts were separated by.6s to leave margin beyond the existing.5s hurt-immunity window; the prepared server suite also exercises actual CombatService immunity. Review cameras were widened so the complete back and feet fit.

Review deliverables play **exported Roblox tracks**, not just Blender source curves:

- `raven-knight-motion.mp4`, `raven-knight-death.mp4`/`.gif`, `raven-knight-death-poses.png`.
- `raven-knight-showcase.png`, `raven-knight-summons.png`, `compare-front/side/back.png`.
- `crow-reaper-motion.mp4`, `raven-motion.mp4`, `crow-axe-motion.mp4`; all29 clips rendered.

## Encounter [authored decisions]

Existing2550HP, normal26/special37/heavy46, combat regeneration4HP/s, arena and wiki rewards retained. Damage is raw before armor/books, normal hurt immunity and the shared boss burst cap. A combo's number is its **total** budget divided over its visible contacts; a player can avoid later contacts. One raven volley shares one37-damage budget per player, including phase two.

| Attack | Timing / behavior |
|---|---|
| Alternating normal cuts |1.9s; contacts.8/1.4s,13 each, radius8,65° half-angle|
| Fast combo |4.35s;1.2/1.9/2.6/3.3s,9.25 each, radius9|
| Fly strike |4.25s; move1.4–2.5s, range21, warned landing radius5.5,37 damage|
| Explosion |6s;3s warning, radius12,46 damage|
| Raven call |3.2s; release1.6s;3/5 birds, cap5, speed22/range35,37 shared damage|
| Retainer |Phase two call; max1,160HP,11 speed,42s life,60s call cooldown, five attack families,14–20 raw damage|

The fly arc is visual, with a grounded collision root. Destination/path checks reject unsupported ground and walls; dynamic support is rechecked during travel and before impact. Projectiles sweep against walls/players, enforce range/arena bounds, and cannot damage after their owner dies. Props are non-queryable; no full-screen fog. Reaper root/physics are server-owned, it is an ordinary `Mob`, and it has no boss reward registration or shielding effect. Death/leash/replacement clear the encounter. `MobAnimator` now accepts server Action/ActionAt/ActionLen for authored minions while preserving ordinary bite/spawn/death behavior; a regression check is prepared.

## Verification and remaining work

Offline: Selene src0 errors/warnings/parse errors; StyLua src check; Rojo build; Python AST, finite/sorted tracks, normalized quaternions, module limits, no-glow geometry, exact clip/config durations and target-only decision diff pass. `audit.py` checks changes against c9ab15e and records `offline-validation.json`. Sixteen JSON modules, all below180000 characters. Primary motion error <.0081stud/<.36°; walk stance error <.016stud; final torso floor <.002stud; full death silhouette penetration <.031stud. Retainer/raven/axe each have their own measured curve reports. These measurements do not establish Roblox runtime behavior or mobile performance.

**Pending evening in Katorga92594200898716:** `scripts/qa-raven-knight-runtime.luau` disposable server scenarios; `qa-raven-knight-animation-client.luau` actual Motor6Ds plus ordinary-mob regression; no-block suite; live Castle fight in both phases; real damage timing/ownership/cancellation/leash/respawn and appearance. `studio-validation.json` deliberately says PENDING. Real4–6-player/mobile/load combat remains open. No map replacement or publish.

## Rebuild

One headless Blender5.2 process/two threads, no GUI/notifications; do not control Studio while the owner's code-only instruction applies. For each of `raven_knight`, `crow_reaper`, `raven`, `crow_axe`: `blender -b -t 2 --python-exit-code 1 -P <id>.py -- build`, then `blender -b <id>.blend -t 2 --python-exit-code 1 -P <id>.py -- export`. Main `render_motion.py`; companions `review_summons.py -- <id>`; then Python `assemble_motion.py`, `audit.py`. Main `-- compare` renders full orthographic views. Raw render frames/logs are ignored. `configure_runtime.py` is target-only; run `node scripts/build-configs.mjs`. `integrate_runtime.py` records the guarded one-time BossService integration.
