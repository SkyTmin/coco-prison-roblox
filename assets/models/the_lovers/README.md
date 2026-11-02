# Samurai Hanashiguro / The Lovers — offline checkpoint

Prepared 02 November 2026 under the owner's code-only instruction. **Studio fixtures, client animation suites and actual-arena solo lifecycle checks passed on 02.11. Group/mobile/load and owner acceptance remain open.** Blender ran headlessly, two threads, no GUI or desktop notifications.

## Sources and retained balance

- [wiki/menu] Kyoto, unlock29; Samurai and his beloved's spirit, blade/bow, red/gold armor. Respawn8h, money$0–10000, stars10–16, Ancient Powder label1–50%, Fire Shard. Existing reward interpretation/eligibility and public damage/share/dollars-only chat remain unchanged [owner].
- [client] `wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json`: Lovers phase1/2/3, spirit archer, arrow/spear/shuriken/kusarigama and dequip effect families. Exact recovered names/durations are in `research-notes.md`. They do not disclose the original server's mechanics or damage.
- [primary web] [MC Garage / The Lovers](https://mcmodels.net/products/11448/the-lovers-samurai-boss), checked02.11: three phases,14 models,50+animations,40attacks, Minecraft ModelEngine/MythicMobs pack. Source identification only; no purchased assets imported or Roblox redistribution rights assumed.
- [owner/decision] Keep2970HP, normal/area/heavy budgets32/43/54, combat regeneration7HP/s. Our condensed original moves, thresholds, timings, projectiles and spirit rules are authored decisions, not a claim to reproduce all40 source attacks.

## Original models and motion [implementation]

| Rig | Parts | Joints | Clips |
|---|---:|---:|---:|
| Samurai |874|43|21|
| Spirit archer |483|39|9|
| Arrow |5|2|1|
| Spear |3|2|1|
| Shuriken |9|2|1|
| Sickle |11|2|1|

Original imagegen turnarounds and exact prompts are retained. Complete red/gold lamellar armor over a dark underrobe, human face, segmented kabuto/sode, scabbard, curved katana and independent fingers. Spirit: opaque matte pale kimono, layered sleeves/skirt/hair, red sash, articulated asymmetric yumi with two-handed IK and drawn string. No emissive parts, attached lights, player clones or unrelated mob highlighting. Existing gray noise texture reused byte-identically (`ids.json`).

Established original pipeline/gait/IK is reused; sword choreography, two vulnerable phase changes, bow draw/release and layered secondary motion are authored here. Samurai death5.2s recoils, buckles, releases the katana, lands forward and relaxes the hands/cloth. Spirit death4s folds the knees, rolls forward, releases the bow and settles. Weapon drops are baked joint movement, no per-box physics. Armor remains worn in all three phases: transitions change stance and attacks, without rebuilding/fading the full rendered rig.

The spirit's four nocked-arrow boxes are separated before the rig enters Workspace:479 immutable body boxes plus a tiny external four-box prop welded to J_arrow. Reload/release creates/destroys only this prop. Animation still drives the original arrow joint. Review renders hide it at the matching release; Studio fixtures and the live Kyoto encounter confirm the separate nocked prop without changing the main body part count.

Shared `blockmob.py` grounding now treats a detached articulated prop's full joint subtree as one object. Previously the bow limbs/string held the torso off the floor while only the handle was corrected. All eight previous detached-prop rigs have leaf-only detached joints, so their group membership/calculation is unchanged; the structural regression is recorded in `offline-validation.json`. Spirit sleeves/front folds were adjusted so they do not hold up the torso.

## Encounter [authored decisions]

Single authoritative boss. Permanent progressive phases at50% and25% HP, even if it later heals; phase transitions3.6/3.3s remain vulnerable. Phase one uses six specials, phase two unlocks all nine and one killable spirit. Phase three shortens the spirit recovery from2.2 to1.65s. Existing boss phase-two cooldown scaling remains. No defensive blocks or shielding.

| Move | Duration / contact seconds | Raw damage | Counterplay |
|---|---|---:|---|
| Alternating cuts |1.5/.75 and1.65/.85|32|radius8,70° half-arc; leave reach/front|
| Triple cut |3.6 /1.1,1.8,2.5|43 total|three equal contacts,0.7s apart, radius9|
| Sweep |2.8/1.35|43|warned radius10; leave the circle|
| Thrust |2.32/1.2|43|grounded rush, range12,35° half-arc|
| Dash cut |2.48/1.65|54|range24; locked destination, step away|
| Sky cut |3/1.75|54|range14/radius6.5; body jump is animated while collision root follows supported ground|
| Stars |3/1.15|43 shared|five swept projectiles,9° spacing, speed30/range34|
| Returning sickle |3.48/1.35|43 once|speed26/range24 outward, then returns along the same line; cover stops it|
| Spears |2.8/1.4|43 shared|three projectiles,7° spacing, speed26/range32|
| Paired arrow rain |3.72/1.45 command|43 shared|spirit prepares for another2.24s; three locked marks, dodge or use overhead cover; kill spirit to cancel|

Amounts pass through normal armor/books, hurt immunity and the existing shared boss burst cap. Special recovery1.7s. All projectiles use swept collision, range/arena/cover checks, shared per-volley hit budgets and a16-live-projectile cap. Grounded rushes recheck support and obstructions during travel; rain checks support/headroom again before release. Warning marks and bounded impact fragments are matte.

Spirit110HP, speed8, spawn3.24s, lifetime60s, death4s, at least25s before resummoning. One living spirit, ordinary Mob target with no boss reward registration, server network ownership. Normal shot16, fan18 shared, rain21 shared, spectral spear19. Paired rain temporarily replaces the spirit's current attack, preserving recovery after it completes. Boss death stops damage immediately and lets the spirit finish its4s death; leash/root replacement clears the encounter immediately. No map edits or new player-facing strings.

## Offline checks and evening handoff

All34 clips rendered from exported Roblox tracks, not only source Blender actions. Six blends,20 JSON modules; largest70325 characters. Main local position error<.008stud, rotation<.361°, planted stance<.016stud; final armored torso floor error<.0007stud. Spirit position<.008stud, rotation<.357°, stance<.013stud, final torso floor distance<.054stud. Full death silhouettes stay within.025stud of floor. Individual measured reports and videos are retained.

`audit.py` checks model hierarchy, finite/ordered curves, quaternions, module budgets, timing/config correspondence, walk playback caps, reused texture, all clip renders and target-only changes against95e3852. Selene/StyLua/Rojo and boss-balance simulation pass. These establish offline consistency, not actual FPS, live counterplay or group balance.

**Studio update02.11, Katorga92594200898716:** source/models-only sync preserved the cloud map. `qa-lovers-runtime.luau` PASS: 80cases/318checks; `qa-lovers-animation-client.luau` PASS: 29checks on actual client Motor6Ds. No-block43checks and ordinary-mob bite regression pass. Boss transforms now update in PreSimulation (see [Roblox timing](https://create.roblox.com/docs/reference/engine/classes/Motor6D)); all six pending client suites pass, including fast props. Actual-arena solo lifecycle now PASS: 27 checks, 32 real damage samples, all required natural AI actions, phase thresholds, server-owned chase, leash cleanup/heal, articulated death and scheduled fresh respawn. No duplicate model or body-part loss observed. Automatic HP refill and shortened lifecycle waits mean this is not a survival/balance test. Real4–6-player combat, native phone/load tests and owner visual acceptance remain open. `studio-validation.json` is PARTIAL and lists the remaining work. Fixtures removed, default viewport/camera and Creative restored; no publishing.

## Files and rebuild

- `samurai-motion.mp4`, `samurai-death.mp4`/`.gif`, `samurai-death-poses.png`, `samurai-showcase.png`; `compare-front/side/back.png`.
- `lover-spirit-motion.mp4`, `spirit-death.mp4`, `spirit-showcase.png`; four projectile review movies.
- One Blender process at a time: `blender -b -t 2 --python-exit-code 1 -P <id>.py -- build`, then `blender -b <id>.blend -t 2 --python-exit-code 1 -P <id>.py -- export`.
- Main `render_motion.py`; companions `review_summons.py -- <id>` (optional `--clips a,b`), main `-- compare`; Python `assemble_motion.py`, `audit.py`.
- Source settings in `scripts/design-decisions.json`, generated via `node scripts/build-configs.mjs`; one-time integration/configuration scripts kept for provenance. Raw frames/logs/blend backups ignored.
