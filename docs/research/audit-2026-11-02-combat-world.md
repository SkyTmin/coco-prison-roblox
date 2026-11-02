# Combat and world audit — 2026-11-02

Baseline: `stage-1`, `a3ffec7`. Read-only source/config/build-script audit, with isolated arithmetic/state models in Node. No Studio access, live profile/map mutation, production changes, commits or publishing. Severity: P1 = broken progression or significant exploit; P2 = material gameplay/content defect; P3 = minor mismatch. Confidence concerns the source conclusion, not whether the current cloud map has received every builder.

## Coverage and current implementation

Read `CLAUDE.md`, the recent journal in `docs/PROGRESS.md`, relevant combat/needs/death/location/faction/gang sections of `docs/GAME-DESIGN.md`, and targeted sources located through `docs/INDEX.md`. Reviewed Combat/Bow/Book damage interactions; BossService, BossDamage, DamageImmunity and BossLoot; MobService and animation dispatch; Fall/Lava/Hunger/Needs/Death; Location/Faction/GangHouse/Ghetto/GhettoMine/Warzone; MineService registration and builders. Gang financial transactions/storage and general economy are covered by the other audit.

Current implementation is substantially beyond the old PLAN and old opening paragraphs of PROGRESS/GAME-DESIGN:

- All **19** configured bosses have an existing authored model and their ID appears in a map builder. HP is **280–3500**, with **Splinter 1800** in the middle. No missing boss is claimed.
- All **30** configured locations have a corresponding builder, including all **25** normal progression locations through Paradise level 49. Presence is not a claim that each current cloud map is synchronized, navigable or performant.
- Bosses bypass stale ForceField/Shielded defenses; the retained Java hurt window is per attacker on bosses. The newer no-block owner decision supersedes old comments describing casting immunity.
- Wiki drop ranges, powder and last-hit special items are implemented. The implementation sends public boss ranking damage/share/money; item rewards are private toasts. Exact star-allocation semantics still need reconciliation below.
- Boss fixture, client animation and real-arena solo lifecycle results are already recorded. `docs/PROGRESS.md:76–82` and `assets/models/reaper/studio-validation.json:1–46` explicitly retain partial acceptance: the real character was refilled, phase thresholds forced and lifecycle waits accelerated. These do not establish 4–6-player survival/balance, native phone input or load behavior.
- Basement has rat/zombie/bat spawning, mines and Splinter. Faction base, separate gang houses, Ghetto trades/private mines, Warzone points and late mining locations exist. Old descriptions saying these systems are wholly absent are stale.

## Confirmed defects and omissions

### CW-01 — P1: Ghetto private-mine entry consumes a pass but always fails its teleport validation

**Primary:** `scripts/build-ghetto.luau:1638–1640`; `src/server/Services/LocationService.luau:281`.

**Trigger:** A gang with the Ghetto upgrade and three online members uses its mine NPC while carrying a gang mine pass. `GhettoMineService.luau:75–87` consumes the pass, assigns ownership and a 10-minute lease, starts rebuilding and calls `Locations.Request(player, "ghetto", arrival)`. The room's Arrival has `LocationId = "ghetto"` and the `GhettoMineExit` tag, but never the `LocationSpawn` tag. Every completed channel requires that tag at LocationService line 281 and therefore cancels after five seconds. The same failure affects free repeat entries into the already leased room.

**Consequence:** The player spends the pass, receives an opened-mine message, and cannot enter; the lease continues to expire. This is a deterministic mismatch between the checked destination contract and all four constructed rooms.

**Confidence/evidence:** High. Inspected the complete room block and every LocationSpawn occurrence in the builder; source check reports `privateArrivalHasLocationSpawn=false`, `privateArrivalHasExit=true`. No alternate service adds LocationSpawn to these parts. Live-map state was not inspected.

**Follow-up evidence from the parent auditor:** A read-only check of the connected live world confirmed all four `Ghetto.GangMineRooms.*.Arrival` parts have `GhettoMineExit` and lack `LocationSpawn`. No pass was spent and no teleport/profile mutation was used for that check. This closes the uncertainty about cloud-only tags for this finding.

**Fix direction:** Register a valid private arrival before consuming the pass and distinguish it from public Ghetto spawns. Simply adding LocationSpawn without a private-arrival exclusion can let ordinary Ghetto teleport choose a private room. Validate normal entry, cancellation, same-gang repeat entry, stranger rejection and expiry using the real NPC path.

### CW-02 — P1: Purchased Trainer Strength and Agility do not affect combat

**Primary:** `src/server/Services/TrainerService.luau:50–53,100–104`; `src/server/Services/CombatService.luau:77–90,119–135,387–432`.

**Trigger:** Buy either of the two combat training branches. The upgrade subtracts coins and increments `p.trainer[stat]`. The only exported combat hook, `TrainerService.multiplier`, has no caller anywhere in the server. Neither incoming damage nor melee/arrow damage reads these trainer levels. `BookService.incoming` (`BookService.luau:524–544`) rolls the Shnyr book, but contains no trainer Agility roll.

**Consequence:** Users pay for damage/dodge progression that has no effect in PvP, boss or ordinary-mob combat. At level 20 the documented effects are +40% damage and 20% dodge, so this also invalidates balance expectations based on fully trained players.

**Confidence/evidence:** High. Repository search finds `TrainerService.multiplier(` only in its declaration; no `trainer.strength` or `trainer.agility` combat readers. Config still promises 0.02/0.01 per level (`src/shared/Config/trainer.json:3–19`), UI describes stronger hits/dodging (`src/shared/Strings/Part1.luau:162–173`), and GAME-DESIGN section 7 repeats those effects. Needs training is wired separately at `NeedsService.luau:479–484`, so this is specifically the two combat branches.

**Fix direction:** Define how training composes with Java base damage, crits, armor and books, then connect the paid benefits to the authoritative common damage paths. Verify trained versus untrained equal-loadout melee, bow, PvP and boss/mob cases.

### CW-03 — P1: Cycling Tank armor gives free repeatable healing

**Primary:** `src/server/init.server.luau:218–225`.

**Trigger:** While hurt, equip Tank-enchanted armor, wait for the one-second MaxHealth update, remove it, wait for the next update, repeat. `BookService.luau:591–592` adds two HP per Tank level. Whenever maximum health rises, the update adds the whole positive delta to current health; when it falls, current health is only clamped. Equip and unequip perform only inventory/armor swaps (`InventoryService.luau:237–275`), reachable through ordinary remotes (`EconomyService.luau:329–359`).

**Consequence:** One Tank III piece heals six HP per equip/remove cycle, without food, potion, cooldown or consumed resource. Multiple eligible pieces increase the amount. This works even with no hunger regeneration and substantially undermines boss/PvP survival balance.

**Confidence/evidence:** High. A source-derived arithmetic model with base MaxHealth 20 and HP 1 gives HP **7, 13, 19, 20** after four complete Tank III cycles. This is a model of the exact health-update expression, not a Studio runtime test. The initial-spawn/level-up intention in the surrounding comment does not distinguish equipment changes.

**Fix direction:** Separate legitimate spawn/level-up healing from equipment capacity changes; preserve appropriate health state when toggling bonus-health gear. Regression should include repeated swaps while injured and with zero hunger.

### CW-04 — P2: Warzone Haste is lost on death and retained after leaving its owning faction

**Primary:** `src/server/Services/WarzoneService.luau:114–121,309–311`; `src/server/Services/NeedsService.luau:643–648`.

**Trigger A:** Receive Haste from the faction-owned point, then die. Warzone caches `hasteGiven[player] = point.untilAt`; Needs clears all timed effects on CharacterAdded. The next Warzone tick sees the same cached end time and never restores Haste for that hold period.

**Trigger B:** Receive Haste, then leave/change faction. FactionService clears the faction and evicts from faction-only locations (`FactionService.luau`, leave handler), but never revokes the timed Haste. Warzone only grants; it has no revocation path. The ex-member retains the remaining benefit, potentially almost 30 minutes.

**Consequence:** Current members lose their earned faction benefit after respawning, while former members keep it. A grant attempted before NeedsService has a player state is also cached before `GiveEffect` confirms success, creating the same missing-buff shape for early initialization.

**Confidence/evidence:** High for death/faction transitions; initialization timing is conditional. Cache is cleared only on PlayerRemoving. The isolated state model confirms the cached end timestamp survives the respawn effect reset and prevents another grant.

**Fix direction:** Track the benefit by source and current character/faction, refresh after respawn, and revoke only the point-owned effect on entitlement loss without deleting a stronger independent potion.

### CW-05 — P2: Bow Flame burns through Fire Resistance

**Primary:** `src/server/Services/BowService.luau:459–475`.

**Trigger:** A player with active FireResistance is hit by a Flame bow, or drinks the fireproof potion during arrow burning. `ignite` creates the entry and `burn` routes each player tick straight to `CombatService.ApplyDamage`; neither path checks FireResistance. ApplyDamage checks protection, hurt immunity, armor and defensive books, not fire resistance or damage type.

**Consequence:** The advertised fireproof effect protects against lava and book fire but does not protect against the bow's fire damage. The initial arrow impact may correctly hurt; the subsequent burn ticks should be handled separately.

**Confidence/evidence:** High. Compare the explicit protection checks in `LavaService.luau:134–141` and `BookService.luau:875–878`; GAME-DESIGN line 111 explicitly says Fire Resistance protects against lava and burning. No live shot was performed.

**Fix direction:** Apply consistent fire-source immunity to Flame ticks, including resistance acquired after ignition. Test both scenarios and expiration; retain ordinary arrow impact damage.

### CW-06 — P2 content omission: Ghetto has no bats

**Primary:** `scripts/build-ghetto.luau:1650–1677`.

**Trigger:** Visit Ghetto to fight the owner-requested three ordinary mob types. The entire mob construction section places eight rats and groups of zombies, with no bat call or dynamic Ghetto bat-spawn service. The bat model and ordinary bat runtime already exist; Basement uses them (`build-basement.luau:1943,1947`).

**Consequence:** Ghetto lacks the requested bat encounters and a local source of bat progression.

**Confidence/evidence:** High for the authored map. This is supported by the explicit owner evidence, not just an old TODO: `docs/research/remaining-features-facts.md:104` lists zombies, bats and rats; `remaining-features-design.md:127–129` carries that request forward. Config's bat locations also omit Ghetto. Cloud map was not inspected, so manual cloud-only additions cannot be excluded.

## High-risk conditional finding needing a controlled runtime trace

### CW-07 — Potential P1: downwards teleport is counted as a long fall

**Primary:** `src/server/Services/FallService.luau:22,52–64`; `src/server/Services/LocationService.luau:227,289`.

FallService keeps eight recent heights and carries the maximum into the first airborne frame. A normal teleport moves the same character to destination +4 studs and clears velocity, but does not clear fall apex/history. No teleport-reset API or discontinuity exclusion exists in FallService. A destination airborne frame within those eight samples therefore inherits the previous high location's Y and landing computes lethal damage.

**Isolated arithmetic/state evidence:** Eight grounded samples at Y=1504, then a teleported airborne sample at Y=4, then grounded Y=3 gives `ceil((1504-3)/4 - 3 - 0.1) = 373` damage. A still-active ForceField would hide it, as would eight grounded post-teleport frames before Air is observed. Actual FloorMaterial/physics ordering is precisely what this static audit cannot establish.

**Risk:** Ordinary travel from elevated progression maps to lower maps/Prison, faction eviction and private-room entry after CW-01 is fixed. Prior QA frequently used fresh ForceFields or healed characters; that is not evidence this edge is safe.

**Required test:** Use a disposable character with ForceField disabled, record Y/FloorMaterial/apex around an ordinary descending LocationService teleport, and verify no fall damage. Repeat void rescue and mine rebuild rescue. Do not count the arithmetic model as observed live damage.

## Acceptance gaps and design questions

1. **Real group balance and native phone/load acceptance remain open.** Keep existing 19-boss fixture/animation/lifecycle passes. Require actual 4–6-player late encounters, normal health, ordinary weapons/training/books, interruption/contribution/reward behavior, mobile touch and frame time under representative mobs/projectiles/mines. CW-02 and CW-03 must be settled before interpreting survival balance. Simulated DPS and heal-assisted solo encounters cannot close this requirement.

2. **Boss persistence is explicitly single-server only.** `BossService.luau:14–18` acknowledges one global record per boss and last-writer-wins; lines 618–641 use `SetAsync(boss.id, ...)`/`GetAsync(id)`, with no server namespace, lease or shared live encounter synchronization. Example: A saves a death timer, while a still-alive copy on B later saves live HP/zero respawn; C then loads B's state. Conversely a new C can wait on A's kill while B still has a living boss. This is a concrete cross-server state race, but whether the intended design is global bosses or per-server encounters is unresolved; classify as a release architecture/acceptance blocker for multiple servers, not as missing boss implementation. Test multi-server restart/hop/reward behavior after choosing ownership semantics.

3. **Death leaderboard contract disagrees with code.** `DeathService.luau:47–49` increments deaths for every Humanoid.Died. Fall and Lava merely clear LastHitBy; that suppresses PvP attribution, not the counter. `GAME-DESIGN.md:352` and Fall/Lava file headers say falls/lava do not count. Decide whether every death should count; if the stated rule remains, death needs a damage/death cause. Loot-on-every-death is a separate, later owner rule already correctly represented by `dropInPvpOnly=false` and should not be reverted to the old section-12 prose.

4. **Boss star quantity semantics are not reconciled.** `BossLoot.luau:11–13` chooses uniformly from the card's star range for each eligible player, independently of share (except the 5% threshold and later Prospector bonus). `wiki/in-game-wiki/BOSS-CARDS.md:49` interprets quantity as depending on damage share, while older GAME-DESIGN text incorrectly still mentions top three. Exact allocation formula is not recovered. Confirm the intended rule rather than invent a formula or treat the old top-three paragraph as current acceptance.

5. **Oil refinery/industrial and Quarry progression remain scoped omissions, not regressions.** They are absent from the 30 current location configs/builders. GAME-DESIGN section 11.8 explicitly records the owner pause for the oil refinery; `remaining-features-design.md:262–264` explicitly labels normal stone/iron as temporary stand-ins until Quarries. Track these for full-game scope and obtain a current scope decision, rather than reporting old implementation-plan bullets as newly broken features. Shot-mode removal is an explicit 29.10 owner decision and must stay removed.

6. **Survival reset semantics need an explicit acceptance case.** Hunger/saturation persist in the profile; neither DeathService nor HungerService resets them on respawn. Thus dying at zero hunger resumes starvation (direct Health reduction, even during spawn ForceField) and no sprint. This may be an intended prison penalty, but differs from a broad promise of Minecraft-style respawn and is not specified precisely enough to call an implementation bug here.

7. **Ordinary-mob obstruction/cleanup deserve targeted regression.** `MobService.luau:243–244` applies bites by range without line-of-sight, unlike melee and modern boss projectile obstruction checks. Closely separated player/mob positions on opposite sides of a thin wall can receive bites. Ordinary mobs also lack BossService's deleted-root recovery branch. These are source-supported lower-priority robustness candidates; not promoted above the stronger progression defects without a concrete affected arena trace.

## Local checks performed

Read-only Node checks against the actual current files returned:

```text
bossCount=19; hpMin=280; hpMax=3500
missingBossModels=[]; bossIdsAbsentFromBuilders=[]
locationCount=30; locationsMissingBuilders=[]
ghettoPrivateArrivalHasLocationSpawn=false
ghettoPrivateArrivalHasExit=true; ghettoHasBatSpawn=false
trainerMultiplierFiles=[TrainerService.luau]  // declaration only
Tank III complete-cycle HP from 1/20: [7,13,19,20]
Haste regrant with unchanged cached ownership end after respawn: false
Conditional downward-teleport trace damage: 373
```

These are configuration/source assertions and small faithful state/arithmetic models. They are not Roblox runtime, mobile, WAN, group balance, cloud-map inventory or load tests. Production source was unchanged.
