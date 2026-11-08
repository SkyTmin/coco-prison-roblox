# Paid random items and player exchange restrictions — server implementation

Implemented from the owner's explicit pre-release request. No Studio session, real PolicyService request, purchase, profile/cloud mutation, publish, or server restart was performed by this work.

## Policy authority

`src/server/Services/CommercePolicyService.luau` owns the session policy. `Start()` queries existing/new players, publishes `PolicyState` (`pending`, `ready`, `error`), `PaidRandomAllowed`, and `PaidTradeAllowed`. `CanRandom` / `CanTrade` read private server state rather than trusting attributes. `RequireRandom` / `RequireTrade` also send the localized `policy_loading`, `policy_random_unavailable`, or `policy_trade_unavailable` toast.

Both returned fields must be booleans. Permission requires `ArePaidRandomItemsRestricted == false` and, independently, `IsPaidItemTradingAllowed == true`. Unknown players, initial loading, malformed data, exceptions, timeouts and departed players are denied. API calls time out after 15 seconds; retries wait 5, 10, 20, 40, then at most 60 seconds. Removal cancels pending requests/timers, and generation checks discard late results. Successful policy is held for the player session.

This follows the [Roblox PolicyService reference](https://create.roblox.com/docs/reference/engine/classes/PolicyService/GetPolicyInfoForPlayerAsync) and [paid random items guidance](https://create.roblox.com/docs/production/monetization/paid-random-items): the restriction covers random generators bought directly with Robux or with purchasable currency. Permission does not replace the separate requirement to disclose actual numerical odds; the other release work adds those previews.

## Enforced entry points

| Path | New action boundary | Preserved behavior |
| --- | --- | --- |
| DonateService | Crystal/ruby spending and direct Robux prompts for random-input goods; prompt eligibility checked again after yielding Marketplace metadata | Deterministic goods/currency packs; all already-paid receipt delivery and replay/legacy protection |
| AuctionService | Listing and buying require trade permission; seller authorization is recorded; online seller and buyer are checked inside the final authoritative update after save yields | Cancels, own returns, pending purchase/listing settlement |
| PlayerTransferService | `/pay`, `/rubb`, `/gift` and equivalent UI intents require both sender and receiver permission before debit/outbox | Accepted outbox/inbox recovery, even after a participant leaves or becomes restricted |
| StorageTransferService | New gang/faction page deposits and withdrawals require permission before escrow | Personal vault and accepted journal recovery |
| ItemDropService | Manual throws require permission; another player's drops require captured source permission plus current receiver/current online source permission | Own death/drop recovery and natural mob/treasure loot; merges cannot mix ownership/authorization classes |
| GangService | Treasury deposits and withdrawals require permission before a new operation | Existing operation settlement and system-generated gang benefits |
| GangBaseService | Library book donation requires trade permission; chance-based book forge requires random permission | Earned gang rewards and existing ordinary combat effects |
| GhettoService | Trader/black-market purchases of keys, stars and powder require random permission before spending | Deterministic black-market goods and earned treasure rewards |
| DeathService | New victim-to-killer cash loss requires both policies before an immediate debit or deferred death journal | Kill/death statistics, item drops, already-debited death settlement |

The root agent owns CaseService case opening/shared-page UI entry guards, BookService chance-below-100 application checks, startup ordering and Strings integration. Guaranteed book application and deterministic powder application remain available. The combat agent owns the analogous stuck-arrow pickup boundary in BowService. Client button explanations and odds previews are separate team-owned edits.

`src/shared/CommercePolicy.luau` exposes `RequiresRandomPurchase(donateId)` and `IsRandomInput(itemId)` to keep purchase presentation consistent. Inputs are the four sold case keys, ancient stars (including the bundle), powder and ancient books. Dispeller, ordinary food/needs items, potion recharge, deterministic perks and boosters remain outside this predicate. Currency acquisition itself is deterministic; spending it on restricted inputs and consuming random generators are guarded separately.

No paid provenance exists on current stacks/currency. The approved conservative rule therefore gates all interplayer ownership exchange at these boundaries, including ordinary items, rather than guessing which copy was paid for. This does not gate mining, ordinary NPC selling, mob loot, earned achievements/referrals, or system-created `/thx` rewards.

## Offline seller and ground-item authorization

Roblox accepts a Player instance for the policy lookup, not an offline user ID. A newly listed auction record stores `paidTradeAuthorized=true` and `paidTradeAuthorizedAt` after the seller's verified permission. That bounded authorization lasts only through the listing's existing expiration. Missing/malformed/NaN timestamps and old unverified listings cannot be newly purchased. A locally online seller is checked again on purchase, including inside the non-yielding UpdateAsync transform. Other-server/offline sellers rely on their recorded listing authorization; there is no claim of a fresh offline geolocation lookup. Old listings remain cancellable/returnable.

Ephemeral player drops likewise remember their originating user and permission at spawn. A current local source denial overrides captured permission; a departed source uses the captured value. Own recovery bypasses exchange checks. Natural loot has no player owner. Merging preserves these distinctions so a restricted player drop cannot become unrestricted natural loot.

## Actual-source offline evidence

All service methods below run from repository source under isolated fake profiles, services and scheduler/physics adapters. No actual purchases or cloud keys are involved.

| Suite | Result | Meaningful coverage |
| --- | ---: | --- |
| `qa-commerce-policy-offline.luau` | 49 PASS | Pending/allowed/denied/malformed/exception states; independent flags; attribute spoof resistance; retry delays/cap; timeout; stale response/removal cleanup |
| `qa-commerce-actions-offline.luau` | 30 PASS | Actual auction sell/buy/cancel, post-save seller/buyer policy changes and refunds, offline authorization, malformed legacy records; real drop spawn/pickup/merge; forge/library/treasury and NPC purchases |
| `qa-player-transfer-offline.luau` | 161 PASS | Existing durable transport faults plus both-side denial for money/rubies/items; accepted recovery under later restriction |
| `qa-storage-transfers-offline.luau` | 58 PASS | Existing crash/CAS/replay faults plus denied shared deposit/withdraw/manual throw and accepted journal recovery |
| `qa-death-storage-offline.luau` | 35 PASS | Immediate/deferred cash eligibility for victim and killer; unchanged statistics/loot; accepted death cash settles once |
| `qa-release-items-offline.luau` | 236 PASS at handoff to root | Entire Donate catalog; restricted random-input crystal/ruby purchases and prompts never debit; deterministic goods still grant; already-paid restricted receipt persists once; original mining/food/spring/sort checks |
| `qa-release-receipts-offline.luau` | 37 PASS | Actual legacy/current receipt boundary with a policy guard that deliberately throws if receipt processing calls it |
| `qa-release-world-offline.luau` | 43 PASS | Existing world/NPC tests adapted to an explicitly allowed policy dependency |
| `qa-economy-audit-offline.luau` | 49 PASS | Existing numeric/progression/mining regressions preserved |

Root later extends the release-items suite with Case/Book checks; its final count supersedes this handoff count. Scoped server source is Selene-clean and formatted. A full source check during parallel UI work had only two transient formatting warnings in CasePreviewWindow; root runs the integrated final checks.

Native acceptance remains separate: verify actual Roblox policy attributes on a test session, disabled UI explanations and accessible odds previews, permitted actions when eligible, and denied forged remote requests without debit. A real policy exception must remain closed with retry; never add a Studio/QA/creative permission bypass to production. Receipt testing remains mocked and must not trigger real purchases.
