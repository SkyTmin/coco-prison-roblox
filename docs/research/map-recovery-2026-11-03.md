# Incomplete authoring scene — recovery record, 3 November 2026

## Confirmed state

The owner renewed Studio access in the evening. The confirmed Katorga place `92594200898716`, version `430`, opened in Edit with four Workspace roots: `Prison`, `Terrain`, `Camera`, `QAReleaseStaging`. All29 other expected location roots were missing. The serialized `ServerStorage.QAReleaseMapLease` remained, but its Lua closure did not survive reopening. The bounded recovery invocation timed out without restoring any geometry. Evidence: [native report](map-recovery-2026-11-03.json).

This is an agent QA infrastructure defect: the previous scene lease temporarily assigned non-retained Workspace roots to `Parent=nil`, holding the only references in a Lua closure. A save/reopen while the test was interrupted cannot retain those objects. The exact save mechanism (manual, automatic or recovery) is not established. Do not attribute it to the owner or claim that all cloud versions are damaged.

No new Play test, geometry rebuild, cloud save or publication was performed in this recovery session. The source-sync installer was generated locally but not executed. Latest gameplay code remains committed in the repository.

## Preserved local files

These are exact byte copies, not Lune re-serializations, under the ignored `place/recovery-2026-11-03/` directory:

| File | Bytes | Source timestamp, Moscow | SHA256 |
|---|---:|---|---|
| `katorga-full-autorecovery-2026-10-30.rbxl` | 5464731 | 30 October,00:02:00 | `F9CDF4C418267B428C6E7BCE9EBB8BA9C7FF5CF2C6CE0EC6B1155C064B02188D` |
| `katorga-partial-sts-2026-11-03.rbxl` | 3231611 | 3 November,06:41:11 | `BE294E21B7B61180EEFFFF3CA37354559187697FB45D87F0520E9A9A6B6E0A5D` |

Full-copy source: `C:/Users/user/AppData/Local/Roblox/RobloxStudio/AutoSaves/92594200898716_AutoRecovery_0.rbxl`. Independent read-only inventory found342995 descendants and all30 location roots, including Quarry, Ghetto, Warzone, Basement and late locations. This is an older fallback, not the accepted latest geometry. No newer complete local place was found; the Rojo validation files contain source only.

Lune warned that `Terrain.VoxelGridAssetContentMap` has an unknown type. Use that parser for read-only inventory only; do not round-trip this real place through it because terrain fidelity is unverified. Native Studio should open any recovery candidate.

## Required next action

Use a recent complete cloud version from before the interrupted03.11 06:40 MSK test. Roblox documents opening it via **Window → Version History → ⋮ → Open Local Copy**, separately from restoring/saving/publishing: [official Version History](https://create.roblox.com/docs/projects/version-history). Open and inspect a candidate before applying it. Native window clicks returned `coordinate input geometry is unavailable` twice after fresh window selection; keyboard navigation did not open the menu. The owner has been asked to open the copy. The fallback browser reached sign-in and was closed without entering credentials.

Verify all30 roots, actual contents and accepted Quarry redesign. Retain current source and any newer geometry; do not blindly replace the whole place with the30October backup. Only after complete map recovery should source sync and fresh-player QA resume. Recovery is currently **NOT COMPLETED**.

## Recurrence prevention

The old scene-lease entry point now fails without mutating instances. Tutorial, PvP and Actions coordinators retain the full authoring scene, reject missing/empty/duplicate map roots and legacy lease/staging, and check structure after the test. No `Parent=nil` or non-Archivable parking is used. Native memory demand is not reduced. A smaller test copy must be a separate file derived from a verified complete backup, never the cloud authoring scene.

Offline verification:155 map-safety checks with synthetic binary save/reopen and cross-root references, plus52 tutorial-harness checks. These tests validate recurrence prevention; they do not restore the missing real map. Details: [QA safety](release-map-qa-safety-2026-11-03.md).
