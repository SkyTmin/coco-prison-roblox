# Tutorial: final owner steering, 2026-11-03

This replaces the earlier one-block / ten-block tutorial descriptions. The proposed Beginner achievement and its $5 grant were cancelled by the owner and removed completely, including config, durable special branch, temporary stat and translated reward text. No first-shovel balance override remains. Existing ordinary mining achievements remain unchanged.

## Production behavior

New profiles start Tutorial v2 at internal step3: the real next shovel upgrade. The card reads Config and actual credited counters/available money, currently shovel1→2 requires gravel20, dirt15, sand15 and $5 (50,000 internal units). It shows each resource separately in all four locales. Incomplete resources never direct the player to purchase. Guidance targets the seller only after all resource requirements are complete AND current money plus the exact SellAll quote covers the purchase. One block, one missing resource, or an insufficient bag keeps the player mining. Otherwise it targets an existing exposed spawn-mine block of the needed material, or a real exposed clearance block when that material is buried.

Once ready, animated guidance follows Menu → Upgrade → actual shovel selector → Buy. Successful server item upgrade starts internal step4, showing the actual next-level goal (level2 currently470 orange blocks and $5). The card then guides mining/selling and Menu → Level → LevelUp. Only confirmed LevelUp completes step5; UI/beam/markers hide. There is no client completion remote. Dig/Sell compatibility hooks do not mint money or synthetic progress.

TutorialService saves confirmed upgrade/level checkpoints. Completed/legacy v1 profiles remain complete; unfinished v1 steps map to current tasks. A full authorized progress reset creates fresh upgrade requirements with no reward. Actual ProfileService reset/rejoin is covered by isolated fake-store tests; no owner's profile was reset.

World guidance uses a player-to-target Beam plus a bobbing arrow. A valid target is cached, with one exposure ray per refresh; removal or fast local hiding invalidates it immediately. Retargeting is throttled to0.5s and raycasts at most32 nearest requested-material candidates plus32 fallback candidates. It does not raycast every mine cell. A 12,000-part boundary regression confirms the bound and cache behavior. LoadingBlocked must be false before guidance appears. The selector observer attaches before its final Name is assigned, matching actual GUI construction ordering.

New production file: `src/shared/Strings/ReleaseTutorial.luau`, included by Strings/init. Other changes are Tutorial, TutorialService, TutorialGuide, the narrow EconomyService.OnLevelUp hook, and UpgradeWindow selector metadata. SpringJump separately honors the loading gate; Upgrade/Auction slot rendering calls the UI agent's EnchantmentVisual helper.

## Verification

- `qa-release-tutorial-goals-offline.luau`:37 checks, actual Tutorial/TutorialService/Config/ProfileService, fake persistence; exact boundary readiness, no cancelled award, checkpoint/rejoin/reset and legacy semantics.
- `qa-release-tutorial-guide-offline.luau`:14 checks executing unchanged Guide closures against fake UI/geometry;12k target budget, invalidation/fallback, Menu→item→Buy and late-named real Activated observer.
- `qa-release-ui-onboarding.luau`:295 checks plus nested39 Profile persistence checks; latest tutorial semantics included.
- `qa-release-upgrade-offline.luau`:9 checks, actual window, selection/scroll/next-upgrade behavior.
- `qa-release-items-offline.luau`:197 checks, including Spring loading gate preserving the unused extra-jump charge.
- `qa-economy-audit-offline.luau`:49 checks, unchanged clean100/orange200/type200 and mining safety regressions.
- `qa-release-localization-offline.luau`:1,584 entries /6,336 locale values, no missing keys or placeholder issues.
- `qa-release-tutorial-harness-offline.luau`:27 compilation/installer/transport/no-grant guards. These are fixture checks, not a claim of live execution.

Selene on the changed production modules:0 errors,0 warnings,0 parse errors. StyLua checks pass. Root owns Studio execution; this reviewer did not run Studio or real purchases.

## Live tutorial QA handoff

1. In the intended place, sync current production first. Retain actual `Workspace.Prison`, main mine anchor, seller NPCs and normal loading gate. Use a fresh isolated TestSessionScope and one negative STS actor.
2. Generate an Edit-only installer with `node scripts/make-release-tutorial-qa.mjs`, execute that output, then start `StudioTestService:ExecuteMultiplayerTestAsync(1, "release-tutorial-v1")`.
3. Startup has client55s/server60s ACK/retry and LoadingBlocked evidence. Overall watchdog is1,200s. The scripts wait asynchronously; no long tool busy-wait is needed. `ReplicatedStorage.QAReleaseTutorial` updates Mined, Coins and Stage every50 cells for progress inspection.
4. The server refuses nonfresh profiles rather than resetting them. It records real first-entry card/marker/beam, ordinary DigStart→DigAccepted→timed removal and clean+1, actual Sell near the real seller, exact readiness, ordinary UpgradeItem and LevelUp. The actual shovel selector is clicked via CreateVirtualInput, with logged geometry/input evidence. Purchases themselves use the same ordinary remotes as UI callbacks and are explicitly marked as such, not native click acceptance.
5. All money/counters come from actual game mining/selling. There are no P.Mutate grants, synthetic Tutorial hooks or resource fixtures. Existing normal mining-achievement money is separately reported as `digs.ordinaryMiningAchievementIncome`; actual sales total `saleIncome`. Scripted movement stands on an adjacent real unmined top block; it is not proof of physically walking the path. Natural mine reset waits use the same os.clock as MineService.
6. The report records completion, scoped save confirmation, per-stage rendered evidence and sampled mining details (full failing-cell evidence if any). It does not claim screenshot pixel comparison, touchscreen acceptance or cross-session live reset. Remove the two exact-named QA scripts using `node scripts/make-release-tutorial-qa.mjs --cleanup` in Edit mode.

Live Tutorial result remains pending root execution. The earlier Items baseline is not a pass; its revised harness and60-check isolated validation are described in `release-items-economy-2026-11-02.md`.
