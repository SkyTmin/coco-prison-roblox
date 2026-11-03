# Tutorial and pinned requirements — 2026-11-03

## Scope and sources inspected

Read the current `Tutorial`, `TutorialService`, `TutorialGuide`, `TutorialPanel`, upgrade and level windows, `HudLayout`, settings validation/profile persistence, first-case transaction and personal-progress reset paths. The previous implementation already had truthful requirement counts, camera-directed exposed-block selection, and a first-sale checkpoint. These were retained.

The remaining defects were: highlighting individual blocks after the first sale; treating another equipment upgrade as the shovel tutorial's completion; no unconditional end at level 2; no held-key-only case guidance; triangle-only pointers; no persistent user-selected requirements card.

Roblox's own [Connect the beam tutorial](https://github.com/Roblox/creator-docs/blob/main/content/en-us/education/build-it-play-it-mansion-of-wonder/connect-the-beam.md) provides texture `5886559421`, but the root agent's native preload returned Failure while this project's own block icons loaded successfully. That external dependency was removed. The final path uses our own local geometry: each arrow has a shaft and two wings, with at most 12 arrows / 36 passive Parts, updated at 5 Hz and projected onto the ground. A thin stock Beam connects endpoints without an external texture. UI pointers also have a shaft and two wings. The [Beam reference](https://create.roblox.com/docs/reference/engine/classes/Beam) was used for endpoint behavior; no downloaded geometry/code or external image is shipped.

## Implemented behavior

- Fresh level-1/zero-block spawn faces the actual main-prison mine anchor once. Returning from a completed state to a personal reset re-arms this one-time view.
- Resource gathering completes before the first sale. After that real sale, money gathering has a clear short message and no individual block highlight. Another seller trip is offered when the bag's actual sale quote covers the remaining upgrade price.
- Only a successful shovel upgrade advances onboarding to the level task. Existing case completion is preserved. At level 2 all onboarding, including unopened-case arrows, ends.
- Level guidance uses credited block counts and actual money. It points to the mine area without marking individual blocks; a sufficient bag points to the seller; available money points to Menu, the level tile and the real LevelUp button.
- An ordinary key temporarily points to the ordinary case only while selected in hand and before the first successful opening. The actual successful case transaction sets that checkpoint.
- Equipment and level menus have a pin button. `settings.trackedUpgrade` and `hideRequirements` persist; equipment tracking follows item type/tier across inventory moves and armor equip. Successful upgrades advance a pinned tier, preventing an identical lower-tier spare from replacing the next-upgrade card. Requirements use actual Config rules and server-confirmed counts.
- The card has a small X, settings visibility toggle and a route to the existing HUD editor. Saved positions are retained if safe; after a viewport change they are clamped or relocated away from controls. Personal reset clears only these new tutorial-specific settings, preserving other personal preferences.
- Added text is present in Russian, English, Spanish and French.

Independent review found one further target-selection defect: 32 nearer occluded blocks could permanently hide the 33rd visible candidate. Selection now continues through bounded pages between guide updates, probes nearby candidates for newly exposed surfaces, and retains a still-valid target while the next page is examined. It does not cast thousands of rays every frame. Regression cases cover the 33rd and 97th wanted candidate, fallback starvation, newly exposed blocks, retained targets, cadence and ray budgets. The reviewer independently reran all 39 checks successfully.

## Offline verification completed

All commands use the actual repository Luau modules/closures with fake GUI, stores and actors where applicable. No real account was reset or granted items.

| Check | Result |
|---|---:|
| `qa-tutorial-tracking-offline.luau` | 61 PASS |
| `qa-tutorial-path-offline.luau` | 128 PASS; geometry pool, 12-ray limit, cadence and cleanup |
| `qa-tutorial-panel-offline.luau` | 165 PASS |
| `qa-release-tutorial-guide-offline.luau` | 39 PASS, independently rerun by the review agent |
| `qa-release-tutorial-goals-offline.luau` | 44 PASS |
| `qa-release-upgrade-offline.luau` | 11 PASS |
| `qa-release-ui-onboarding.luau`, including near-transfer checks | 323 PASS, plus profile39 |
| `qa-shared-case-offline.luau` | 17 PASS |
| `qa-profile-persistence-offline.luau` | 39 PASS |
| `qa-release-localization-offline.luau` | 1601 entries / 6404 translations, zero issues |
| `qa-release-tutorial-harness-offline.luau` | 52 PASS; installer/embedded source/cleanup/all full-map helpers compile, bounded RPC execution and failure regressions |
| `qa-release-map-safety-offline.luau` | 155 PASS; actual helper execution and synthetic binary place save/reopen, including interrupted runs |
| Full `selene src`, `stylua --check src`, `rojo build` on the final shared source | PASS; zero Selene errors/warnings/parse errors |

Layout fixtures cover 320×568, 568×320, 360×640, 640×360, 390×844, 844×390, 768×1024 and 1024×768, including saved positions over movement/attack/hotbar controls. These are dimension/collision checks, not claims of testing physical phones.

## Native checks completed and fresh-flow interruption

`scripts/qa-tutorial-tracking-native.luau` runs in Client context after source sync. It creates an isolated ScreenGui, invokes the real Panel/Strings/Config with deterministic fake-profile goals, measures native text/layout/icons in all locales and preloads the project's own block icons. The updated script also exercises the actual local arrow renderer at 6, 0 and 12 arrows, checks its passive properties and removes its separate `__QATutorialDirectionArrows` folder. It neither reads nor changes the real profile, calls remotes, starts another Guide singleton, or registers another HudLayout entry. Result: `_G.QATutorialTrackingNativeReport`.

The initial native card pass had 281 PASS / 1 FAIL; the sole failure was the now-removed external arrow image. The subsequent actual Studio run completed **323 PASS / 0 FAIL**, saved in [the native report](tutorial-tracking-native-2026-11-03.json). Its actual viewport was 1809×633 with a 58-pixel inset. All four locales' native text/rows/card bounds passed, the project's three block icons preloaded successfully, and the geometry arrow pool, passive properties and cleanup passed. The report records zero remote calls and no real-profile access. These observations do not imply a physical phone test or a clicked X/menu shortcut.

By default the preview GUI is removed on completion. For a screenshot, set `_G.QATutorialTrackingPreviewSeconds = 15` before execution; the card remains for 15 seconds and then destroys itself. Its X only hides the QA GUI and records `report.closeClicked`. The report explicitly separates the actual viewport from dimension fixtures. No synthetic `Activated` event or physical-touch claim is made.

The existing `qa-release-tutorial-server/client.luau` harness already mined through the real server requirements and used ordinary Sell/UpgradeItem/LevelUp remotes. It was extended, not replaced:

1. Capture initial mine-facing camera before scripted framing; verify the action caption and asset-free directional path.
2. Mine genuine exposed blocks with actual starter tool/time/LoS/range checks, retaining the real Prison map and natural resets.
3. Verify the first sale occurs only after every resource requirement. After sale, check `upgradeSold`, earning message, absent highlight and absent beam; repeat after one more genuine block.
4. Gather a complete cash batch, verify the Menu arrow before opening Menu, then upgrade tile, actual shovel selection and upgrade button. The same Menu-first check applies to level 2.
5. If mining naturally supplies an ordinary key in hotbar slots 1–9, ordinary SelectSlot verifies in-hand case arrows and their disappearance when the shovel is reselected. The key is neither granted nor consumed. If absent, this is explicitly NOT_OBSERVED; no forced loot is introduced. Actual first case opening remains a separate live acceptance step.
6. Verify level2 hides the card, world marker, highlight, beam and UI strokes, including held-key guidance if a natural key was observed.

The existing installer remains `node scripts/make-release-tutorial-qa.mjs`; run its output in Studio Edit, then use `scripts/run-release-tutorial-qa.luau`. The coordinator validates the complete map with read-only preflight and calls `ExecuteMultiplayerTestAsync(1, "release-tutorial-v1")` without moving any scenery. It refuses real/nonfresh actors and requires `TestSessionScope`. It has a 60-second startup deadline and a 1200-second overall deadline. Runtime progress is `ReplicatedStorage.QAReleaseTutorial` attributes `FlowPhase`, `Mined`, `Coins`, `Stage`, plus client `QAReleaseTutorialPhase`; final structured report comes from EndTest. Cleanup: installer with `--cleanup`, in Edit. Full-map memory usage is not reduced; see [map QA safety](release-map-qa-safety-2026-11-03.md) before resuming.

The first fresh-flow attempt was invalid because the QA scene contained an additional SpawnLocation and the fresh actor did not use the real Prison spawn. The root agent changed the scene fixture to create a temporary spawn only when there is no real spawn; the server harness now asserts proximity to the actual Prison SpawnLocation. The second attempt reached `rpc_inspect` with a real `Mine_prison.sand` target, then Studio access was disconnected by the user. It is **INTERRUPTED / NOT COMPLETED**, not PASS and not sufficient evidence of a gameplay defect. No completed mining → sale → upgrade → level-2 acceptance result exists from these attempts.

The final EndTest request could not be sent after disconnection. On reopening, the root agent found a persisted partial scene and a stale serialized `QAReleaseMapLease` without its Lua closure. Map recovery is a separate root-agent task; this tutorial flow must not resume on that scene. The unsafe lease entry point is now disabled, and all three QA coordinators use a complete map without detachment. The unchanged recovery helper can report absent roots or restore a surviving in-memory lease, but cannot reconstruct lost geometry from a serialized BindableFunction. Do not save/publish the partial map or treat the earlier fixture checks as successful full-flow acceptance.

## Harness hang audit after disconnection

Only QA scripts were changed in this follow-up; no Studio/UI operation or gameplay source edit was performed. All client RPCs previously waited without their own deadline. The new wrapper records operation/id, deadline, elapsed time and last client subphase, and retains the latest 12 entries. It fails explicitly on timeout or client error and never retries an action that may already have executed. A late answer cannot turn a failed operation into success. Best-effort worker cancellation is not claimed to undo an action already accepted by the game server.

Budgets are 20 seconds for inspect/upgrade, 10 seconds for pose/sell/level, 5 seconds for selection, and the greater of 15 seconds or configured mining time plus 12 seconds for digging. Best-effort stop has 3 seconds. `FlowPhase` exists from startup; `RpcId`, `RpcOp`, `RpcStatus`, `RpcStarted` and `RpcTimeout` expose the pending operation. Client inspection reports before window close/open, guide settling, camera framing, rendered-frame wait and UI collection. Failure to settle within 6 seconds or render two frames within 3 seconds is an explicit failure rather than a silently collected partial observation.

The stream request now supplies an explicit 10-second engine timeout and records `StreamStatus`/`StreamTimeout`. Roblox documents the omitted/default timeout as effectively infinite and does not guarantee that a returned request contains every required object; the harness still validates the actual client mining target afterwards. Source: [Player.RequestStreamAroundAsync](https://create.roblox.com/docs/reference/engine/classes/Player#RequestStreamAroundAsync).

The offline harness test executes the actual extracted RPC wrapper with a deterministic scheduler: timely response, hang, client exception, test abort, cancellation failure with a late reply, no retry, mining-time allowance and bounded history. It also compiles all full-map coordinators/preflight, the retired legacy entry point, unchanged recovery helper, installer, embedded scripts and cleanup. Result: **52/52 PASS**. These watchdog changes still require their first native STS execution after full-map recovery.

## Remaining acceptance

After confirming map restoration, repeat the fresh STS flow and record its final structured result. Physical PC/touch operation, visual arrow placement around real menu windows, actual ordinary-case first opening, and an actual reconnect of pinned settings are not claimed from the offline suites. Existing whole-window scaling on small phones also needs visual acceptance for the new pin buttons; the compact card's own layout checks do not prove the whole upgrade window's touch ergonomics.
