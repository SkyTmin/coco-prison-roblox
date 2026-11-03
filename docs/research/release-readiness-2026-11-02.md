# Release preparation — integration and acceptance record

Owner requested implementation and live verification, with PvP first. Baseline `3b85880`; cloud Katorga PlaceId `92594200898716`. Publishing, advertising, store-page artwork and the final global progress wipe are a later phase. Never execute a reset on the owner's real profile merely to test it.

## Work and ownership

| Work | Owner | Current status |
| --- | --- | --- |
| PvP damage/audio/knockback/health + two-client PC/mobile QA | root | Source fixed; two-client32-check PASS including native PC attack, falling critical, running target and rapid hits. Physical phone input pending. |
| Ghetto NPCs, one random capture point, mine lighting | audit_combat_world | Source fixes43-check PASS;40 mine anchors/120 soft lights patched in actual cloud map; full NPC playthrough pending. |
| Rotten flesh, Silk Touch, Spring jump, upgrade scroll, auction sorts, donate | audit_economy | Source fixes and isolated suites pass; first live102-check run exposed14 fixture/integration failures. Corrected harness awaits rerun. |
| Tutorial, Actions, confirmed own reset, Creative book groups | audit_ui_mobile + audit_economy | Source implemented; tutorial being revised to actual upgrade requirements then level-up, no10-block reward. Reset and loading independent review active. Actions corrected paired rerun blocked by child-client OS1455 memory failure. |
| Per-server shared bosses, cross-server reward cooldown, affinity/friends | audit_combat_world | Implemented;61 isolated server-policy checks +22 death/storage checks pass. Real cross-server routing requires published test servers. |
| Location illustrations from our actual scenes | root + three art agents | All30 generated, uploaded and committed2d424de; comparison gallery verified. Actual client typed ImageLabel preload30/30 PASS; menu appearance verification pending. |
| Four-locale completeness and integration/build/QA/report | root + reviewers | Locale suites pass; latest tutorial/loader/enchanted-item changes still require final integrated checks. |
| Location exterior boundaries | audit_combat_world |230 isolated checks pass; actual cloud patch covers35 regions. Four pre-existing misplaced legacy walls in MountainFoot/Pyramid repaired. Separate live Prison/Quarry recovery and ladder-depth test17/17 PASS; native walking around every location remains distinct. |

## New owner steering, 03 November

- A reset must remove personal items from inventory, vault, case overflow and unclaimed stores, regardless of whether those item IDs also occur in the donate catalogue. Keep payment receipts/entitlements to avoid replaying purchases; never reset the real account as a fixture.
- Gameplay begins only after profile, avatar, current-location collision/assets and server/client bootstrap are ready. Show the dark inventory-style loading panel and a recoverable retry state instead of an invented timed percentage.
- Tutorial task card uses the exact selected item's upgrade price and credited block requirements. World lines retarget existing diggable blocks; arrows guide seller and menu controls. Upgrade arrows appear only when requirements are met; a confirmed upgrade unlocks the next-level task. Completion requires a confirmed level-up.
- The initially requested beginner10-block/$5 achievement was explicitly cancelled. No gift money or simplified upgrade requirements. Earn upgrade money by mining/selling.
- Enchantments must be recognizable in inventory and in hand, while retaining the earlier removal of blinding glow. Use truthful enchant metadata and matte UI/model effects, not Neon/lights/Bloom.

## Recorded integration evidence

- `release-pvp-native-input-2026-11-03.json`:32 PASS. Ordinary4HP, critical6HP, exactly one victim impact/sound/primary impulse; rapid requests respect server cooldown. Local input-to-confirm about130–150ms includes attack upswing. No simulated network latency and no large-server capacity claim.
- `release-actions-baseline-2026-11-03.json`:25/30 pass. Gifts/metadata/replay/conservation and390×844/844×390 layout checks pass. Three money assertions used the wrong currency scale; native recipient observation watched a button destroyed by a legitimate UI rebuild. Fixtures corrected. Later run did not reach checks because child clients exhausted Windows commit memory; it does not establish a product regression or a pass.
- `release-items-baseline-2026-11-03.json`:88/102 pass. Real Space input preserved20.8-stud/s horizontal velocity on the second Spring jump; food/Hunger and12 auction-sort comparisons pass. Wrong ordinary third-jump timing, unsafe fixture teleports/standing positions and upgrade click targeting were corrected for rerun; do not claim full live acceptance yet.
- Thirty-scene map was temporarily parked only during isolated multi-client tests and restored in each finally path. Actual scene roots verified restored; no publication or global wipe.
- `release-art-preload-2026-11-03.json`:30/30 actual client asset requests succeed using typed ImageLabel instances. A paired probe reproduced `PreloadAsync({idString})` Failure for the same image whose ImageLabel preload succeeds and whose existing hotbar IsLoaded is true. The early string-based probe was a QA/loader API error, not30 broken uploads; loader correction follows the typed path.
- `release-items-loader-fixed-2026-11-03.json`:48/48 completed checks pass after loader correction: real food/Hunger, sprint/Spring, native PC item upgrades retaining selected slot12/scroll320,12 auction comparisons. Silk trial did not begin because the fixture required an inaccessible outside rim; selector now uses an adjacent real unmined support cell and awaits rerun.
- `release-actions-typed-loader-2026-11-03.json`:28/30 pass; exact money/metadata/replay checks now pass. Native clicks missed by the exact58px GUI inset; fixture input coordinates corrected. This is not a completed native Actions pass.
- `release-safety-live-2026-11-03.json`:17/17 PASS with one fresh negative actor and real retained Prison/Quarry. Actual wall collision queries, ordinary heartbeat recovery after below-floor fast falls, unchanged HP, legal deep/mid ladder poses. Scripted positioning is explicitly not physical-input acceptance;29 parked roots restored afterward.

## Platform work that cannot be marked complete yet

- Current server capacity is60. General documented caps do not prove the maximum offered to this account; inspect Creator Dashboard/Experience Settings and then load-test that chosen cap.
- Read-only product metadata found six missing direct products and five mismatched legacy crystal packs. Legacy IDs now remain receipt-only with their original grants;11 new registrations are needed. No authenticated Open Cloud key is available. Unregistered purchases stay disabled; no real Robux was spent.
- Validate reward locks and six-hour affinity on two real test servers: same species within respawn interval may assist without repeat rewards or share dilution; a different species retains independent eligibility; friend join overrides routing only. Full/closed server falls back once. Studio mocks cannot establish live teleport delivery.
- Physical-phone touch gestures, camera/sensitivity, full Ghetto interactions, four-to-six-player late bosses and final native UI appearance remain separate acceptance checks.

## Accepted server/boss behavior

- Every server has its own shared bosses; no solo instances [владелец].
- Per-player reward lock is keyed by boss species across servers; duration equals that boss's configured respawn, starting at the kill [владелец, explicit follow-up]. Another species has a separate lock.
- A locked player may help friends damage the same species but receives no repeat reward and must not dilute eligible players' reward shares [решение]. Persist reward eligibility atomically with the reward grant.
- Prefer returning to the same available server for six hours from the initial assignment [владелец]. Explicit friend joins may override routing; reward locks remain authoritative. A full/closed server needs a bounded fallback, not an infinite teleport loop [решение].
- Maximum available server capacity needs platform/configuration verification and a separate load limit assessment; small test sessions do not prove maximum-capacity performance.

## Evidence boundaries

Keep actual-source fixtures, paired Studio clients, device-simulator layouts, physical mobile input and real cross-server teleports separate. Initial network simulation settings were all zero [сеть]. Studio supports the device simulator API. Store purchases will be tested through receipt fixtures/read-only product metadata; no real Robux spending. Final report must list exact uncompleted manual scenarios and expected results.

## Remaining acceptance steps before publication

1. **PC and phone combat:** two real accounts in a PvP zone; alternate stationary, sprinting, descending-jump and rapid attacks. Expect the same accepted hit to update HP, one victim sound/impulse and attacker feedback; cooldown requests must not replay damage. Test camera/menu release with native touch separately from the recorded PC VirtualInput pass.
2. **Ghetto and capture:** walk to every trader/black market/miner/pass/treasure interaction at allowed and denied progression. Verify quoted cost, exact inventory change and translated failure. Observe one active capture point; dig eligible blocks to capture, verify benefits while held and only one next point after its hold interval. Inspect mine-floor visibility in each region; geometry patches alone are not an eye test.
3. **Items:** regenerate `make-release-items-qa.mjs`, retain actual Prison+Quarry, run one negative actor with `release-items-v1`, then restore the scene and remove the exact QA instances. Expect all12 paired Silk cells to be mined through normal DigStart with equal ordinary-tool timing/tier restrictions and only appropriate drop changes. Food/Spring/repeat-upgrade/sort portions already have48 live passing checks.
4. **Newcomer:** regenerate `make-release-tutorial-qa.mjs`, retain actual Prison, run `release-tutorial-v1` with one fresh negative actor. Expect compact right-side resource rows; first and intermediate blocks keep the mining line, another player's removal selects an existing block, all resource/value requirements lead to one sale, then item upgrade and level-up. No cancelled10-block reward. Separately walk this route on a phone; card and pointers must avoid controls. Never reset the real owner profile to manufacture this fixture.
5. **Actions:** reinstall the latest two Actions scripts and run two negative actors with `release-actions-v1`. The corrected inset path must reach review/confirmation and debit/credit exactly the displayed amount once. Then repeat recipient/item/count selection with real phone input. Do not send an actual social invite as an unattended test.
6. **Reset/loading/UI:** on a disposable authorized account, fill hotbar/backpack/vault/overflow, request reset, verify the deletion list and separate confirmation, rejoin and check fresh tutorial/no old items. Paid receipts stay retained. Wait for the loading gate; successful profile/character/collision/typed assets release controls. A real unavailable asset/load must offer Retry. Verify enchanted vs ordinary tool, in hand and each inventory view; no emissive lights. New diamond sword tier16 displays SharpIII and reaches the documented12 damage under the game's existing enhanced curve.
7. **Public servers/platform:** register the11 outstanding product IDs and verify read-only metadata; select the account's maximum available player cap and load-test it. On serverA kill a boss, then joinB within its respawn interval: assisting is allowed, repeat reward and dilution are not. Different species remains eligible. Explicit friend join overrides routing; returning normally within six hours prefers the original live nonfull server, otherwise bounded fallback. These require real published test servers, not a new public release announcement.
8. **Final build and publication gate:** run current Selene/StyLua/Rojo and the actual-source suites after any further changes; resolve remaining live failures, snapshot the accepted cloud map and confirm exact release data-reset scope. Publishing, store-page/advertising work and global wipe remain separate owner-requested stages.

Latest synchronization before acceptance:96 scripts, cloud PlaceId92594200898716,33 scene roots restored and no map lease. A narrow subsequent InventoryService guard must also be included. After frequent owner Play restarts, the legitimate profile lock rejected one join; wait for clean release/expiry rather than deleting or bypassing it. Native CUA window control was stopped with Escape; no later native window-control actions were attempted.
