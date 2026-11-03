# Reset and initial loader — independent peer review

Read-only production review of `src/first`, `ProgressReset`, `ProfileService`, `PlayerTransferService`, Creative's reset call site, main client input dispatch and `WindowInput`. The UI agent made the production corrections. This reviewer added only an isolated actual-source regression script and this report. No owner reset, real profile/store access, Play control, commit or publication was performed.

## Concrete findings and final result

1. **Fixed: valid recovery could leave initial input blocked forever.** The old loader compared the root with a one-time `ArrivalPosition`, even after mine/world recovery moved the same character more than 32 studs before the client observed that arrival or while assets loaded. Retrying did not refresh an already-ready server arrival. `ProfileService` now refreshes authoritative arrival proof on bootstrap only after restoration finishes; the loader invalidates work after displacement and retries through the normal bootstrap. Relevant current boundaries: `ProfileService.luau:1132`, `LoadingController.luau:199`, `LoadingController.luau:273`. Both before-observation and during-preload +64 Y recovery cases now release the loader after server acknowledgement.

2. **Fixed: an old streamed floor could authorize release at a new unsupported position.** The original asynchronous asset completion checked generation and character identity, but the same character could leave the loaded area without either changing. The loader now checks position and actual collidable floor after streaming, after preload and before completion. A −20 Y displacement with the floor removed during preload remains blocked. This test intentionally does not treat a successful streaming request as proof of collision.

3. **Fixed: confirmed reset could re-save the old advanced-location position.** `ResetOwnProgress` durably cleared `lastPosition`, then released `session.resetting`; Creative replaced the old body in a deferred task. The five-second/leave position recorder still considered that body restored and could save its advanced-map position into a level-one prison profile. The next join would restore that saved position. `ProfileService.luau:620` now remembers the old body in ephemeral `session.resetCharacter` before releasing the reset guard. `rememberPosition` at line 1027 ignores precisely that body. The arrival callback at line 1064 clears the guard only for a replacement body; an old callback cannot announce readiness. Leave/save/reacquire before replacement retains no old position, while replacement tracking and persistence resume normally.

No additional confirmed release blocker was found in the reviewed reset/export/input paths. This is bounded source review, not a claim that native networking and every UI route have been accepted.

## Clean checks and limits

- Reset clears all personal physical containers, stash, active/stored personal boosters and settled gift/auction overflow. Activated entitlements, paid currency, receipts, daily/referral anti-repeat records and boss cooldowns are intentionally retained under the owner's clarified policy. Reset is rejected while external transactions, reward/death settlement or gang membership remain active.
- External player-transfer generations prevent delayed pre-reset/legacy packets from restoring deleted assets. The durable transform rechecks the live recipient generation; a permanent receipt acknowledges discarded old packets, and new-generation gifts remain valid. The existing 120-case transfer suite was rerun successfully.
- Failed default profiles cannot unlock initial loading: readiness requires the explicit successful snapshot proof. Same-token failed-acquisition retries and concurrent position restoration are covered by the loader suite.
- Main window opening, keyboard and hotbar-wheel paths check `LoadingBlocked`; custom gameplay input uses `WindowInput`. Initial camera/control ownership stays blocked until real readiness. `RuntimeReady` is also required before release. The loader is for initial entry; ordinary respawn/teleport overlays are not part of its contract.
- Item visual replication is deliberately stubbed in the reset-position fixture. Reset, durable transformation, acquisition/save/reacquire, and the extracted unmodified position/arrival functions execute actual source. Engine geometry, networking and native inputs remain mocked. A source-only test does not verify an actual StreamingEnabled device, floor replication timing, visual readability or owner account state.

## Verification

`scripts/qa-loading-peer-review.luau`: **6 regression scenarios PASS**. It reuses isolated fixture factories without running or editing production data, executes current loader code, and covers the three loader outcomes above plus old-body leave/rejoin, stale arrival callback rejection and replacement position persistence. These cases fail the pre-fix behavior at the relevant boundary.

Latest reruns: `qa-loading-offline.luau` **98 PASS**; `qa-player-transfer-offline.luau` **120 PASS**. The peer script is formatted and linted. The location-safety report separately records the parent's persisted cloud geometry checks; no live fall or loader acceptance is inferred from those checks.

Parent acceptance still needs a fresh ordinary join, restored mine/remote-map join followed by a legitimate rescue, forced asset/profile failure and Retry, ordinary respawn input, native small-screen layout, and a disposable confirmed reset followed by leave/rejoin while replacement is delayed. Real owner reset is not needed for these tests.
