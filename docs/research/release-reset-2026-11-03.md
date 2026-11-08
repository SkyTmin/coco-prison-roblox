# Full pre-release test-progress reset

Owner confirmed: “Полный сброс тестового прогресса перед релизом.” Implementation is a namespace cutover, not deletion. No global DataStore writes, Studio actions, real profile reset or publication were performed by this agent.

## Mechanism and scope

`Shared.StorageNames` reads `RunService:IsStudio()` once. Epoch `release1_20261103` uses `K_L_release1_20261103_` in live servers and `K_S_release1_20261103_` in Studio. The prefix covers all gameplay DataStores, OrderedDataStores, MemoryStore maps and MessagingService topics. Positive real accounts in Studio are isolated too; negative StudioTestService actors additionally retain their per-run scope. Profile schema remains 3.

The machine-readable [manifest](release-reset-namespaces-2026-11-03.json) enumerates 9 standard stores, 5 ordered stores, 7 memory maps, 7 topics and 2 scoped QA store names. It is generated locally by `lune run scripts/reset-release-manifest.luau`, without Roblox calls. The old 9 standard and 5 ordered stores remain untouched as the archive. Old MemoryStore values retain their existing expiry; messages are ephemeral, not an archival backup.

Fresh profiles therefore reset all test gameplay: level, money/currencies, physical items, personal/shared storage, equipment, professions, achievements, skills, faction/gang membership, auction lots/returns, active and stored boosters, reward journals/claims, referrals, daily state, tutorial and saved position. Existing owner HUD defaults are already in source, so a new profile receives them normally. No old gameplay, balances, entitlements or settings are imported. Roblox platform-owned game passes are not mutated; existing ownership checks remain responsible for platform access.

The single legacy exception is `StorageNames.LegacyProfileStore = PlayerProfiles_v3`, read-only by `LegacyReceiptGuard` on a purchase receipt. It checks old receipt IDs, preventing a previously granted purchase from being granted again after cutover. An unavailable legacy read fails closed as NotProcessedYet. The guard does not migrate items/currencies or modify old records. The world agent owns this implementation and its separate 37-check suite. This is not evidence that any particular account had or had not spent real Robux; no historical purchase was made or refunded here.

`LeaderboardService` now excludes Studio, nonpositive user IDs, failed/resetting sessions and current Creative players from both persistent writes and live publication. Cached rows for online excluded users are suppressed too. Old pre-release top entries cannot appear because their namespace is different.

## Why the existing reset/version was insufficient

- `ResetOwnProgress` is an explicitly confirmed own-account operation. It preserves paid/idempotency fields, blocks active journals/gang/auction operations and increments incoming-transfer generation; it is not a global release reset.
- Clearing only five leaderboards would repopulate from unchanged profiles on the next write/live refresh.
- Incrementing `SCHEMA_VERSION` would deliberately discard mismatched records through the development migration path, including receipt history. It would also leave old external auction/mail/shared-storage claims available. No schema increment was made.
- Changing only the profile store would leave auctions, mail, gang/faction storage, referral rewards and shared boosters in the old economy. All relevant stores and buses must switch together.

## Safe cutover and backup plan

1. Keep the current source and untouched old namespace names as the rollback/archive reference. Do not delete old keys or run RemoveAsync. OrderedDataStore entries have no built-in version history, making preservation of the old store preferable to destructive cleanup. [Roblox GlobalDataStore documentation](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore)
2. Root may run `scripts/reset-release-preflight.luau` in the **old** confirmed Katorga Studio Play. It is standalone and checks one page/key from each new live persistent namespace (9 lists + 5 ordered reads), plus an uncached new-live owner-profile read. It writes only the ephemeral `ServerStorage.ReleaseResetPreflight` report, never a DataStore. Any read failure or populated namespace returns REVIEW_REQUIRED; no reset follows automatically.
3. Stop the old local Play before synchronizing all namespace consumers, helper and receipt guard. Restart Studio: verify fresh level 1 / coins 0 / starter shovel level 1 / empty vault / no gang / five empty top boards. This exercises **Studio** storage and cannot seed live release profiles.
4. Publication remains a separate root/owner action. The live reset takes effect only when servers run the new published build. Retire/restart all old public servers during cutover and prevent old/new receipt writers overlapping; old servers still hold the old namespace/receipt policy. Do not claim that syncing Studio already reset the published game.
5. Keep the production epoch fixed after launch. Future code rollbacks should retain the release namespace unless a separately reviewed data rollback is intended. Reverting to unprefixed names would restore test progress and split new release progress.

The preflight does not enumerate every archived key or alter any archive. Its empty-store claim applies only if every new-live persistent read succeeds; it does not enumerate MemoryStore contents. Standard-store version history is an additional recovery facility, with documented retention limits, not the backup mechanism used here. [Roblox data-store versioning](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching)

## Verification

`scripts/reset-release-offline.luau`: **231 checks PASS**. Actual-source isolated tests cover namespace uniqueness/length, one-time Studio detection, all leaderboard eligibility paths including cached rows, old high-score exclusion without archive mutation, and real ProfileService acquire/save/rejoin separating positive Studio and live accounts. Fresh profiles retain schema 3 and do not import old loot; a Studio grant remains Studio-only. The standalone preflight is executed against read-only fakes in empty/occupied/failing cases and checked against the complete persistent manifest.

Supporting regressions: profile persistence 39 PASS, player transfers 150 PASS, shared storage transfers 54 PASS, server affinity/rewards 61 PASS, isolated tutorial adapter/installer 73 PASS; world agent reported receipt guard 37 PASS and release-items 197 PASS. Full source Selene, StyLua and Rojo build pass. All data/state tests above use isolated mocks; native preflight/fresh Studio evidence belongs to the root's subsequent run.

## Root native verification, completed 03 November

Correct Katorga (Place 92594200898716 / Universe 10772144679): normal stop of the old Play, source-only sync of 13 scripts, start with the fresh Studio prefix. No map replacement, OS input, publication or deletion of archived keys. Read-only live preflight passed before and after the Studio run: all nine regular and five ordered stores empty, owner live profile nil. MemoryStore contents were not enumerated.

Fresh entry: 28 assertions passed, including level 1 / coins 0 / blocks 0 / only starter shovel / no inventory overflow, vault contents, equipment, books, keys, achievements, faction/gang, boosters or old gameplay stats / five empty leaderboards. Tutorial requirement rows are visible and incomplete; loading screen is gone; owner Creative access remains available. Native screenshot confirms the fresh HUD. Normal Stop → Play rejoin passed and did not restore old items. Current-session playSeconds legitimately accrues; deserialization creates an empty ancientCase container, so the item count rather than container presence was checked.

Machine-readable evidence: [release-reset-native-2026-11-03.json](release-reset-native-2026-11-03.json). Studio remains in Play using the clean Studio-only profile. These results do not claim the published game has switched epochs; the release build must still be saved/published deliberately and all old servers retired as described above.
