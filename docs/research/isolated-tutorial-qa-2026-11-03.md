# Disposable local tutorial QA — 2026-11-03

## Why this fixture exists

The recovered cloud map remains intact and must not be detached or used for a memory-heavy full-map multiplayer run on this machine. This workflow uses a separately opened byte-for-byte local copy of the native full version-428 backup. It does not save, publish, restore, or modify the cloud DataModel. Only the root agent operates Studio through MCP; no PC mouse/keyboard automation is needed.

Native backup: `place/recovery-2026-11-03/version-428/katorga-full-version-428.rbxl`.

SHA256: `da82e4c0a83933c0b074cafac50b447ecf73ea115fbb04739377373ecd8ca4a0`.

Disposable document: `place/qa-2026-11-03/Katorga-Tutorial-QA-2026-11-03.rbxl`. Its required runtime identity in Edit is exactly `game.Name == "Katorga-Tutorial-QA-2026-11-03.rbxl"`, `PlaceId == 0`, `GameId == 0`, no players and not running. The root agent confirmed this exact native name, including the extension, after opening the byte copy. If native identity differs, stop and inspect; do not weaken the guards or set production place/universe IDs.

## Minimal operator steps

1. Verify the cloud recovery/save separately. Keep the complete native backup untouched. Copy it byte-for-byte to the disposable path and open only that copy using the root agent's official Studio document API. Confirm the exact document in `list_roblox_studios` and verify the Edit identity above.
2. Generate the current-source installer: `node scripts/make-isolated-tutorial-qa.mjs --output place/qa-2026-11-03/tutorial-install.luau`. It verifies the native backup checksum, embeds all current source and the existing tutorial harness, and never writes an `.rbxl` file. The generated Lua belongs to ignored `place/`, not production source.
3. Execute that installer only in the exact local document. With the existing loopback repository transport, load `http://127.0.0.1:8766/place/qa-2026-11-03/tutorial-install.luau` and execute its returned chunk. Expect `status = "READY"`, 461 source scripts, 29 removed scenery roots, and `storageMode = "SESSION_MEMORY"` [current repository snapshot]. The actual Prison subtree, mine anchor and SpawnLocation remain. The backup's exact `DebugDraw` WireframeHandleAdornment is removed; unexpected root names/classes are rejected before edits. Root deletion yields between roots. No nil-parent parking or restoration closure is used.
4. Execute `scripts/run-isolated-tutorial-qa.luau` in the same local Edit document. It starts exactly one negative-ID actor with `release-tutorial-v1`. Inspect `ServerStorage.QAIsolatedTutorialResult` after completion. The test's server progress remains `ReplicatedStorage.QAReleaseTutorial` (`FlowPhase`, RPC id/op/status, counters), with client `QAReleaseTutorialPhase`.
5. Require the complete nested test report to pass. A missing/failed result, absent session-memory evidence, interrupted `running` report or changed retained Prison produces no success claim. Close the disposable document without saving/publishing when finished; the native backup and authoring place need no restore operation.

The full installer is deliberately single-use. To replace gameplay source or retry an interrupted installation, reopen a fresh byte-for-byte disposable copy; do not invoke the retired map lease. For a QA-server-harness-only fix on the same gameplay snapshot, use `node scripts/make-isolated-tutorial-qa.mjs --harness-only --output place/qa-2026-11-03/tutorial-harness-refresh.luau`, then execute that file only after the pending test has ended and the exact local document is in Edit. It validates the original marker and gameplay-source fingerprint, updates only `QAReleaseTutorialServer.Source` plus marker metadata, and does not repeat synchronization or map pruning. Both session-memory report substitutions are retained. Completed test runs can be repeated in the already prepared local fixture because each STS server receives fresh session memory and a fresh TestSessionScope.

## Storage boundary and limits

A PlaceId/GameId-zero local file cannot use the game's real DataStores. The normal ProfileService then correctly marks a failed load, so simply running the original harness there cannot complete loading or satisfy `ProfileService.IsReal`.

The local installer changes exactly one dependency declaration in each local `ProfileService` and `PlayerTransferService`: their DataStoreService handle becomes `ServerStorage.QAIsolatedTutorialStore`. Every other byte of those repository modules remains unchanged. The transfer dependency is necessary because its Start function acquires a mailbox before the bootstrap finishes; no transfer feature is tested here. All other gameplay code, Config, mining timers, eligibility rules, inventory mutations, economics and TutorialService remain current source. No progress/item grants, resets or synthetic tutorial-completion calls are introduced.

The adapter allows only the existing profile/mailbox store names, the current `Run_…` namespace and strictly negative `User_-…` / `Inbox_-…` keys. Production handles may be obtained during normal service setup but cannot read or write records. Positive IDs, zero including `-0`, wrong prefixes and other scopes are refused. Records are copied on read and commit; nil/error transforms do not alter the previous record. No cloud service is called by this adapter.

The ordinary server/client harness still performs genuine DigStart/DigAccepted, Sell, UpgradeItem and LevelUp operations. The client harness is byte-identical. Only local server report labels/evidence are adjusted: its final SaveNow verifies a **session-memory checkpoint**, not cloud durability. Local reports explicitly set `cloudPersistenceTested = false`; that limitation must accompany any eventual PASS. This test cannot establish reconnect durability, cloud failure handling or production DataStore behavior.

Roblox's in-engine VirtualInput used by the existing harness operates its simulated client UI; this workflow does not drive the PC cursor or keyboard. Scripted actor poses/camera framing remain fixture actions. A pass is not physical-phone usability acceptance, manual walking-route acceptance or a two-player test.

## Offline validation

`lune run scripts/qa-isolated-tutorial-offline.luau`: **73/73 PASS**. It executes the generated installer, server-only refresh and runner on synthetic Roblox instances, checks all identity guards before mutations (including rejection of the old extensionless name), the retained Prison and DebugDraw handling, the full source sync, exact storage-only local substitutions, unchanged client harness, adapter isolation/copy/cancellation behavior, coordinator error propagation, and the unchanged native backup checksum. Refresh tests prove exactly one Script source changes, no instances are pruned/reinstalled, and a different gameplay fingerprint is rejected. The generated installer and installed harness modules compile. Node syntax and scoped StyLua checks pass.

The root agent's isolated native attempt 2 loaded a negative actor successfully but stalled before the first dig. A read-only native reproduction found a fixture bug: a ray from `(-54, 5, -178)` ending exactly at target top face `(-58, 0, -178)` returned nil; extending it 0.1 stud along the same direction hit the expected part. `chooseCell` now extends only this QA selection probe and still requires `hit.Instance == part`. The actual mining intent, reach, line-of-sight checks and time rules are unchanged. The extracted real closure has six new regressions: old endpoint miss, target selection, separate real support, precise 0.1 extension, different occluder rejection and nil rejection. Tutorial harness suite: **58/58 PASS**. This fix requires the root agent's next native run; the earlier stalled run is not successful acceptance.

Report-only review found the same endpoint pattern in the Items harness at `qa-release-items-server.luau:648` and `:703`, with subsequent checks requiring the expected ray target. Those files were not changed by this task.

No Studio access, real account data access, native memory benchmark, cloud persistence test or complete in-game newcomer route was performed by this offline suite. The root agent owns the subsequent actual STS execution and its result.
