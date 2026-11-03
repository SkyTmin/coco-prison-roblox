# Release items, upgrades, auction and donate verification

Scope from the owner/coordinator: rotten flesh, Silk Touch, Springs extra jump, UpgradeWindow continuity, every auction sorting mode, and donate catalog/grant/receipt paths. Source fixes and offline actual-module tests only. This reviewer did not use Studio, purchase anything, mutate real profiles/DataStores, edit generated configs/design-decisions, commit, or publish.

## Implemented

| Area | Source finding and final behavior | Evidence |
| --- | --- | --- |
| Rotten flesh | FoodService previously always applied configured effects, and rotten flesh had no effect configuration. It now evaluates each effect's probability and applies Hunger through the existing tracked status mechanism. BookService.GiveHunger works under spawn protection, refreshes rather than adds duration, and preserves an existing stronger/longer Hunger. Root added the configured 80% Hunger I/30s entry and corrected hungerPerSecond to 0.025. Existing food=4, saturation=0.8, 1.6s consumption remain. | Real FoodService before/after timer, probability boundary 0.79999/0.8, full-hunger refusal, status duration and actual HungerService saturation drain/expiry. |
| Silk Touch | No new defect found after the prior single-whole-melon correction. MiningDrops changes only item ID/count; Config.breakTime remains based on tool/material/efficiency/haste. The earlier owner rule explicitly allows wrong-tool/under-tier drops at slower timing; coordinator reconfirmed preserving it. | Real Config, BookService and MiningDrops on stone, under-tier iron ore, high-level pickaxe, sand and melon. Same speed with/without Silk, one original block, slower under-tier mining. Prior economy suite also exercises ordinary/AoE melon drops. |
| Springs | There was no midair-jump controller; BookService only changed ordinary jump height. New SpringJump uses the server-published SpringsJumpHeight, accepts one additional airborne press after release, resets its charge on landing/other ground movement, and changes Y only. Sprint retains its intent through a brief airborne MoveDirection gap, while a stationary landing still cancels normally. UI agent wires start() in init.client. | Real server height publishing/unequip; real client JumpRequest, input release and state events; exact X/Z=(22,7) preservation, no held-button repeat/third jump/no-boots jump; actual Sprint input/heartbeat tests. |
| UpgradeWindow | Profile refresh retained the old viewed level after the selected item upgraded, leaving a preview/disabled action. It now follows the new current level immediately while preserving selected slot and scroll. Owned-item row is a horizontal ScrollingFrame; all 20 tested entries remain reachable. Upgrade action has stable name TutorialUpgrade for the tutorial highlight. | Actual module build: selected slot12, next upgrade, scroll X=320 preserved, insufficient-funds button remains visible, removed-item fallback, action inside its card. |
| Donate receipts | Grants previously became spendable before SaveNow confirmed them; an error followed by export/crash/retry could duplicate value. Receipt IDs were also discarded after50 entries, so a delayed unresolved receipt could be granted again. Receipt delivery now uses ProfileService.MutateDurable and rechecks its ID inside the transform. IDs are retained. A reward/refund plan chosen on the staged checkpoint is replayed unchanged live; confirmed paid boosters survive capacity filling during persistence. | Actual DonateService with isolated durable-checkpoint mocks: failure before write and applied-but-lost-response, no unconfirmed live grant, rejoin/replay once, >50 receipts, concurrent completion before transform, full inventory stash, full booster refund, capacity freed/filled during the two checkpoint passes. |
| Marketplace mismatch | Root's read-only live query found all five crystal products had older names/quantities/prices than the current catalog. Old IDs now resolve through receipt-only legacyPacks, preserving their advertised quantities; current packs await new IDs. Before prompting, the server validates product name and configured base price against GetProductInfoAsync. Mismatches and failed reads fail closed with translated messages; a bounded cache allows later repairs to recover. Live unregistered pack buttons are disabled. | Actual handlers with recorded live metadata reject all five wrong pack mappings. Matching metadata, price/name mismatch, cache refresh, failed-read retry and base-price discounts tested. Existing paid legacy receipts still grant without current Marketplace availability. |

Main anchors: FoodService effect loop; BookService.GiveHunger and springs; HungerService.update; SpringJump.request/bind; Sprint heartbeat; UpgradeWindow.refresh; DonateService.processReceipt/give. New strings are in `src/shared/Strings/ReleaseItems.luau` (four locales); root loads this after existing string parts.

The Hunger drain uses the game's existing continuous food-point representation: 0.005 exhaustion/tick ×20 ticks/s ÷4 exhaustion/food-point =0.025 food points/s at level I. Thirty seconds therefore adds the equivalent of3 exhaustion (0.75 saturation/food points); it is not merely a HUD effect. This change does not rewrite the broader hunger system into Minecraft's discrete exhaustion accumulator.

## Auction source audit and tests

No comparator correction was needed. The actual AuctionService query supports time, price and item level, each ascending/descending. Equal values consistently tie-break by lot ID. Price ordering intentionally groups money first and rubies second rather than inventing an exchange rate. Queries run the comparator again after local cache insertion/replacement; removal is reflected too. All six modes were tested before and after adding a lot, with ties, missing level, mixed currencies, combined category/search/price/level filters and multi-page output without duplicates/omissions.

These checks run the real query, indexSet and indexRemove over isolated caches. They do not prove live MemoryStore propagation latency between servers or physical clicks on sorting controls.

## Donate catalog coverage and registration work

Current catalog:31 item entries,30 reachable through six main tabs plus `auction_announce` from the auction offer, and5 current crystal packs. All31 crystal purchases delivered their declared goods/entitlements and charged the declared crystal price in isolated actual-source tests. All24 configured direct-item ProductIds and5 receipt-only legacy pack ProductIds resolve uniquely and deliver correctly. Item overflow goes to stash; booster-capacity receipt refusal compensates the declared crystal price. PRIS+, no-fee, rubies and announcement credits grant their account state rather than an inventory stack. No configured item was found with an absent grant branch. Skins/promocodes/gifting are future catalog notes, not displayed buyable stub entries.

Six direct Robux products still have productId=0 at this review checkpoint:

| Item ID | Product name | Required price |
| --- | --- | ---: |
| needs_injection | Инъекция «Без нужд» |399 R$|
| autosell | Авто-продажа |549 R$|
| stand_recharge | Перезарядка стойки |39 R$|
| pris_plus | Авторитет на30 дней |999 R$|
| auction_no_fee | Удаление комиссии на Аукционе |199 R$|
| auction_announce | Объявление на аукционе |10 R$|

Their crystal-purchase paths already work; live DonateWindow marks unregistered Robux items unavailable. `rubies_100` is intentionally crystal-only (robux=0), not a missing registration.

Root then retrieved the real29-product list for universe10772144679, without buying anything. All24 direct-item products matched; **all5 crystal products disagreed**. Evidence: [release-product-metadata-2026-11-03.json](release-product-metadata-2026-11-03.json).

| Existing product ID | Actual old quantity / Robux price | Required current quantity / price |
| --- | ---: | ---: |
|3723068679|100 /99 R$|80 /80 R$|
|3723068693|550 /499 R$|440 /400 R$|
|3723068701|1200 /999 R$|960 /800 R$|
|3723068712|2600 /1999 R$|2210 /1700 R$|
|3723068729|7000 /4999 R$|6300 /4500 R$|

These old IDs must **never be repurposed to grant the smaller current amounts**: an outstanding paid receipt could otherwise be under-delivered. Root versioned them into donate.legacyPacks with their real old quantities/prices, and reset current pack productId values to0. Donate.byProduct accepts legacy entries for receipt fulfillment; Donate.packs and the client expose only the current catalog. An old100-crystal receipt still grants100 exactly once, even during a Marketplace outage.

**Registration blocker:11 products need registration**—six items above and five current replacement packs. Concrete path: root/owner creates or reuses the matching new-name entries, writes returned IDs into `scripts/design-decisions.json` and regenerates configs. Existing `scripts/create-dev-products.mjs` does this, matching ID/name to avoid duplicates and supporting `--dry`; it requires Developer Products read/write Open Cloud access. It iterates current packs, not legacyPacks, so versioned old products are preserved. This reviewer did not run registration or access credentials. Root reported the required Open Cloud key unavailable in its environment; Creator Hub/account capability is the remaining external step. Accepted owner prices were not changed to match the stale storefront.

Server metadata checks cache a confirmed response/mismatch for60s and a read failure for5s, with one in-flight lookup per product. They compare Name and UserBasePriceInRobux when supplied (otherwise PriceInRobux), allowing a discount from a correct configured base price. A cache expiry lets a corrected registration recover without restarting. Existing paid receipts do not depend on the current price/availability check.

Historical receipt IDs already pruned by older versions cannot be reconstructed by this source fix. Retention prevents future evictions; very high lifetime purchase volume may eventually justify a separate durable receipt ledger rather than profile-array growth.

## Verification

- `scripts/qa-release-items-offline.luau`: **197 checks PASS** with the regenerated workspace config. Actual FoodService, HungerService, BookService, SpringJump, Sprint, Config/Books/MiningDrops/Boosters/Potions, AuctionService, DonateService and shared donate rules; isolated profiles, clocks, events, caches and persistence boundary mocks. The Marketplace boundary is a fake metadata API/prompt recorder; no actual prompts or purchases occur. The five observed mismatches are replayed from root's saved read-only evidence.
- `scripts/qa-release-upgrade-offline.luau`: **9 checks PASS**, real UpgradeWindow against an isolated GUI/event boundary.
- Prior `scripts/qa-economy-audit-offline.luau`: **49 checks PASS**, with a mock TutorialService dependency for the new coordinator-owned dig hook.
- Selene:0 errors/warnings/parse errors on this reviewer's10 changed production modules. StyLua and whitespace checks run on changed modules/tests.

Run with `C:/Users/user/AppData/Local/Temp/coco-case-warzone-qa/lune.exe run <script>` from the repository root. The release fixtures reuse only the isolated setup prefix of the earlier economy fixture; their modules are compiled from current source.

Remaining acceptance: real desktop/mobile jump event ordering, exact second-jump trajectory and sprint feel, live scroller/button interaction, real cross-server auction propagation, and creation/validation of the11 unavailable current products. No claim of those live passes is made here.

## Prepared live Studio harness (not executed by this reviewer)

`node scripts/make-release-items-qa.mjs` emits an Edit-only installer for four temporary instances. Run the generated snippet only in the intended Studio place, then `StudioTestService:ExecuteMultiplayerTestAsync(1, "release-items-v1")`. `node scripts/make-release-items-qa.mjs --cleanup` emits their exact-name cleanup. The installer snapshots current SpringJump/AuctionService source into disposable modules and does not edit production modules or the PvP harness. The two runtime scripts are `scripts/qa-release-items-server.luau` and `scripts/qa-release-items-client.luau`; both compile under Lune and pass Selene. The coordinator runs Studio and records the actual result separately.

The harness refuses nonnegative user IDs before any fixture mutation and restores its one negative simulated profile/position/Creative flag. It does not reset an owner profile, buy products, create auction listings, or write an auction index. Normal game services in the test session may still access their configured stores; this is not a promise that the entire running game avoids every DataStore call.

Physics trials compare an ordinary sprint jump, an attempted extra without boots, Springs single jump, and Springs second jump with a rejected third. The report records the real Humanoid trajectory, velocity before/after the extra press, sprint flag, apex and landing. The preferred path uses the documented `UserInputService:CreateVirtualInput()` / `VirtualInput:SendKey()` to exercise production Space handlers. If unavailable or ineffective, the report identifies a fallback that only exports the private request/release/bind boundary from a source-identical SpringJump clone; real engine physics still runs, but UIS delivery is not claimed. GUI clicks similarly record whether VirtualInput worked or the explicit UpgradeItem remote fallback was used.

The current matrix uses six normal/Silk pairs (12 actual cells): quarry stone at tier5 and tier16, coal tier5, iron tier1 and tier5, plus prison_small melon with axe1. Config break times range from50ms to7.5s. The profile is placed in each mine's actual normal location. The fixture stands on a separately verified real, unmined adjacent top cell, resets FallService immediately before authoritative reposition, records character/death lifecycle and per-dig pose/health/raycast/reach diagnostics, and requires actual removal, acceptance duration, drop identity/count and clean+1. Server listeners exist before the published Ready folder; ACK/retry, LoadingBlocked readiness and explicit55/60s startup evidence cover races. Overall deadline is240s.

Root's first live run is recorded in `release-items-baseline-2026-11-03.json`:102 checks,14 failing. Spring's real extra jump retained20.8 horizontal speed and travelled17.3 studs versus8–9 without it. An ordinary third press occurred after landing, so that old assertion was invalid; the revised third-press test requires an airborne precondition. Two native upgrade clicks and2/12 Silk cells did not complete in that run; they are **not recorded as live passes**. Revised clicks record absolute geometry, hit paths and actual server UpgradeItem intent; inset retry is allowed only when no first intent was delivered. Revised mining diagnostics and stable poses investigate the failures rather than waive them. The isolated actual-source harness suite passes60 checks. Physical touchscreen acceptance and cross-server auction propagation remain outside the harness.

## Sources

Mojang's primary [Taking Inventory: Rotten Flesh](https://www.minecraft.net/es-es/article/taking-inventory--rotten-flesh) confirms the food/hunger-debuff behavior. Per the owner's explicit request, exact vanilla values were checked against [Minecraft Wiki: Rotten Flesh](https://minecraft.wiki/w/Rotten_flesh) and [Hunger effect](https://minecraft.wiki/w/Hunger_%28effect%29). Their search-indexed pages were available; direct opens were robots-blocked. Tool/tier/speed distinctions were compared with [Minecraft Wiki: Breaking](https://minecraft.wiki/w/Mining_speed); the game's separately confirmed wrong-tool-drop rule is preserved.

Roblox's primary [MarketplaceService.ProcessReceipt documentation](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt) describes nondeterministic ordering of pending receipts, retries on another purchase/rejoin, and simultaneous-server callback risk. Those behaviors motivate durable grants and retained receipt identity; mocked tests are not actual purchases.

The primary [GetProductInfoAsync reference](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#GetProductInfoAsync) describes Name, PriceInRobux, UserBasePriceInRobux and product metadata retrieval used by the prompt guard. Product versioning is an application design choice to preserve historical paid quantities.

The live harness uses Roblox's official [VirtualInput methods](https://create.roblox.com/docs/reference/engine/classes/VirtualInput) and [UserInputService.CreateVirtualInput](https://create.roblox.com/docs/reference/engine/classes/UserInputService#CreateVirtualInput), with runtime availability checked rather than assumed.


Latest root rerun:48 checks passed before Silk selection aborted without consuming a cell (release-items-loader-fixed-2026-11-03.json). The quarry rim had no valid fixture pose despite available materials. The selector now uses an adjacent genuine collidable top cell, a downward support ray and ordinary eye-to-target LoS; it creates no platform. This revised selector passes its isolated actual-source fixture and awaits live rerun. VirtualInput now prefers GUI logical coordinates plus the confirmed top-left inset; logical hit-test coordinates remain separate. Tutorial applies the same conversion. No CUA/window control was used by this reviewer.

Fixture-only endpoint correction: root's native tutorial probe found that a ray ending exactly on a target's top face can return nil. The Items selector and per-trial diagnostic now extend the original direction by0.1 stud, with a nonzero-length guard. Selection still requires the original face distance ≤18 studs and `hit.Instance == part`; production DigService LoS and timing are untouched. The existing isolated harness now passes66 checks, including an open-end ray boundary that rejects the old exact endpoint, the precise0.1 extension, unchanged reach rejection, actual diagnostic target recognition, intervening obstruction and zero-length handling. Regenerate `scripts/make-release-items-qa.mjs` output before root's native12-cell Silk rerun. That live rerun remains pending; no additional Studio or map action was performed by this reviewer.
