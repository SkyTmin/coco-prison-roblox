# Release namespace and receipt boundary review — 2026-11-03

The owner authorized a complete reset of test progress before release. The implementation uses a new gameplay namespace; it does not delete or rewrite the old stores, change profile schema versions, or import old gameplay. This review independently checked all runtime storage acquisitions and MessagingService publishers/subscribers under `src` after the economy agent's namespace change.

The final helper is `src/shared/StorageNames.luau`: epoch `release1_20261103`, Studio prefix `K_S_release1_20261103_`, live prefix `K_L_release1_20261103_`. Every name below uses `StorageNames.progress(base)`. Negative Studio QA profile/mailbox stores additionally retain their per-run scope.

## Complete runtime checklist

| Kind | Base names | Owning source |
|---|---|---|
| DataStore | `PlayerProfiles_v3` | `ProfileService.luau:42` |
| DataStore | `PlayerTransfers_v1` | `PlayerTransferService.luau:386` |
| DataStore | `AuctionLots_v1` | `AuctionService.luau:74` |
| DataStore | `Gangs_v1`, `GangTags_v1` | `GangService.luau:38` |
| DataStore | `GangChest_v1`, `FactionStorage_v1` | `SharedStorageService.luau:16` |
| DataStore | `Referrals_v1` | `ReferralService.luau:43` |
| DataStore | `TopNames_v1` | `LeaderboardService.luau:262` |
| OrderedDataStore | `Top_ratsClean_v1`, `Top_money_v1`, `Top_level_v1`, `Top_blocksClean_v1`, `Top_deaths_v1` | `LeaderboardService.luau:241` applies the helper to each board's configured name |
| MemoryStore sorted map | `AuctionIndex_v1`, `SharedBoosters_v1` | `AuctionService.luau:75`, `GlobalBoosterService.luau:22` |
| MemoryStore hash map | `AuctionAnnounce_v1`, `GangInvites_v1` | `AuctionService.luau:931`, `GangService.luau:40` |
| MemoryStore hash map | `ServerAffinity_v1`, `ServerPresence_v1`, `ServerInvites_v1` | `ServerAffinityService.luau:175` |
| Messaging topic | `ProfileRelease` | `ProfileService.luau:47` |
| Messaging topic | `AuctionSold`, `AuctionAnnounce` | `AuctionService.luau:76`, `AuctionService.luau:932` |
| Messaging topic | `Gangs_v1` | `GangService.luau:41` |
| Messaging topic | `SharedBoosters` | `GlobalBoosterService.luau:24` |
| Messaging topic | `Referrals_v1` | `ReferralService.luau:44` |
| Messaging topic | `Chat_v1` | `src/shared/Chat.luau:11`, consumed by `ChatService` |
| Per-run QA DataStore | `PlayerProfiles_v3_QA`, `PlayerTransfers_QA_v1` | `ProfileService.luau:62`, `PlayerTransferService.luau:30`; retain `TestSessionScope` |

Totals: **9 gameplay DataStores, 5 OrderedDataStores, 7 MemoryStore maps, 7 Messaging topics, 2 QA store names**. No `GetQueue` or `GetGlobalDataStore` runtime call exists. No additional external HTTP order/payment integration or Roblox game-pass ownership API was found under `src`; existing purchases use Developer Products via `DonateService`. No omitted runtime namespace was found in the final scan.

Why the less obvious names matter:

- `ProfileRelease` carries a targeted user/job lock-release request; a recipient can kick the matching session. It must be isolated alongside the profile store.
- Auction sold/announcement messages carry lot/seller and announcement payloads. Both messages and announcement deduplication map are isolated, alongside durable lots and search index.
- Gang messages carry refresh, invitation and localized announcement payloads. Gang records, tag registry, invitations, chest pages and messages all change together.
- Shared booster activation records and operation IDs live in the sorted map. The topic carries an entry for announcements and triggers refresh. Neither route reaches the old environment after the change.
- Referral messages carry the inviter ID and trigger recovery from the referral store. The profile and referral store are both fresh in the new epoch.
- Affinity, presence and invite token maps all change together; old invitation tokens do not resolve in the new maps. There is no old global BossState acquisition: boss lifecycle is server-local, and per-player reward cooldown/receipts/pending records are in the versioned profile.
- Player-transfer mailboxes and profile outboxes, shared-storage receipts and profile escrow, auction journals, gang operations and pending booster journals are gameplay data in the corresponding new stores. No old outbox is imported into the new epoch.

Leaderboard source also excludes Studio, nonpositive users, failed profiles and currently Creative players from writes and live overlays; cached rows for an online excluded player are suppressed. This was a source peer check; the economy agent owns its focused fixture and final manifest.

## Receipt boundary implemented

The one deliberate exception is `StorageNames.LegacyProfileStore = "PlayerProfiles_v3"`. New `src/server/Services/LegacyReceiptGuard.luau` reads `User_<UserId>` from that archive with `GetAsync` and checks only its `receipts` list. It never writes the archive, acquires its lock, copies profile fields or grants a reward.

`DonateService.processReceipt` retains its existing current-profile receipt check and durable-grant transaction. Immediately after the current receipt check:

1. An archived matching receipt returns `PurchaseGranted` without another reward or purchase notification.
2. A failed read/open or malformed record/list returns `NotProcessedYet` without modifying gameplay.
3. Confirmed absence proceeds through the existing durable reward/receipt checkpoint. Since the archive read can yield, the handler rechecks the same current profile and its real-loaded state before proceeding.

Old inventory, crystals, rubies, passes and paid entitlement fields are **not migrated**, as explicitly requested. The guard does not cache absent results. `DataStoreGetOptions.UseCache = false` bypasses Roblox's local GetAsync cache; this option and its behavior were verified against [Roblox's official caching documentation](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching).

**Cutover prerequisite:** stop old local Play and restart old public servers before allowing purchases on the new epoch. A fresh read cannot fence an old server which commits its receipt *after* that read. This scoped read-only guard therefore recognizes already committed receipts; it is not a cross-epoch transaction coordinator. No old-profile lease or data was modified to manufacture that guarantee. The public rollout/restart is the root agent's release procedure, not performed by this review.

## Verification

- `scripts/qa-release-receipts-offline.luau`: **37 PASS**, loading the actual StorageNames, LegacyReceiptGuard and DonateService sources with local fake services. Cases cover archived match and repeated callback; absent/new pack and item; no old gameplay import; noncached exact store/key; read/open failure then retry; malformed data; current receipt fast path and SaveNow failure; no negative cache; profile replacement/detach during the yielded read; durable failure before/after checkpoint and single-grant recovery.
- Existing `scripts/qa-release-items-offline.luau`: **197 PASS** after adding its new dependency seam and loading actual StorageNames. Its original paid-item, booster-capacity, receipt serialization and durable-fault assertions remain intact. This suite mocks legacy absence; the new boundary suite tests the actual legacy guard.
- Scoped Selene: **0 errors, 0 warnings**. Scoped StyLua and `git diff --check`: PASS.
- All tests are offline. No Studio, real DataStore reads/writes, purchase prompts, resets, publication or live receipt callback was invoked by this work.

Files changed by this follow-up: `LegacyReceiptGuard.luau`, narrow `DonateService.luau` integration, the new receipt fixture, two dependency additions in the existing release-items fixture, and this report. Namespace, leaderboard, deployment and release manifest changes belong to the economy/root agents.
