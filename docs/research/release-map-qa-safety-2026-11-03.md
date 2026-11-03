# Release QA map preservation — 2026-11-03

## Incident and decision

The old `qa-release-scene-session.luau` removed scenery roots from the DataModel (`Parent = nil`) and kept the only references in a Lua closure attached to `QAReleaseMapLease`. The interrupted Studio session persisted the reduced scene. On reopening, the serialized BindableFunction had no restore callback and the scenery was absent. A `finally` restoration path could not protect against process exit, save/autosave, or disconnection before it ran.

The root agent is handling recovery of the authoring map separately. These changes **prevent recurrence; they do not recover missing geometry**. No Studio operation, save, publish, map rebuild or real-map edit was performed by this implementation task.

The unsafe entry point is now retired and fails before changing any instances. Its error is `UNSAFE_SCENE_LEASE_DISABLED`. Existing callers cannot silently continue the old detachment workflow.

## Current supported test path

`run-release-tutorial-qa.luau`, `run-release-pvp-qa.luau` and `run-release-actions-qa.luau` run STS against the complete map in place. They never park or detach scenery, change Archivable, or invoke a restore closure. Tutorial uses one simulated client; PvP and Actions use two [existing QA configuration].

Before STS, the shared read-only `qa-release-full-map-preflight.luau` requires the confirmed Katorga PlaceId and Edit mode. It rejects a legacy lease or staging model and missing, empty, duplicated, non-Archivable, or incorrectly typed expected scenery roots. The expected set contains the same 30 map roots used by the existing recovery check [repository map contract]. It records root classes and descendant counts before and after the test. This is a structural check, not a proof that every texture, position or authored detail matches a backup.

The result explicitly reports `mode = "FULL_MAP"`, `sceneryMoved = false`, `memoryReduction = false`, and `mapIntact`. A failed preflight never launches STS. A test failure is retained as failure even when the map remains structurally intact. A previously interrupted `running` report prevents another run until inspected; no automatic retry or automatic map repair is attempted.

**Memory reduction from the old lease is intentionally gone.** Full-map STS still clones a server and simulated clients and can exceed the machine's available memory. No native RAM benchmark or full-map test was run for this change. If insufficient memory prevents a run, stop that test and prepare an isolated QA file; never remove roots from the authoring DataModel to make it fit.

## Backup and reduced-memory alternatives

- A ServerStorage folder with Archivable enabled keeps scenery in the saved DataModel, but its contents still belong to the test server. It avoids client replication, not the server copy. It is not equivalent to the previous memory reduction. [Roblox ServerStorage reference](https://create.roblox.com/docs/reference/engine/classes/ServerStorage).
- Setting Archivable to false is unsafe for parking: Roblox excludes that instance from both cloning and saved/published places. [Official Instance documentation source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Instance.yaml).
- `AssetService.SavePlaceAsync` is a remote place save/overwrite operation, not a local `.rbxl` backup writer; its default also publishes. It is not used here. [Official AssetService documentation source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AssetService.yaml).
- The planned reduced-memory path starts with a verified complete local `.rbxl` backup, preserves that input unchanged with its checksum/manifest, and produces a separate disposable QA file. Geometry can be omitted only from that separate copy. The available Lune binary place serialization API can support the offline conversion; this task does **not** yet ship that converter or claim fidelity against the real map. [Lune Roblox serialization documentation](https://lune-org.github.io/docs/api-reference/roblox/).

## Verification

Run `lune run scripts/qa-release-map-safety-offline.luau` from the repository root. Result: **155/155 PASS**. It executes the actual helpers against synthetic Roblox DataModels and performs real binary place serialization/deserialization. The tests check:

- Legacy entry point fails with no instance count/parent changes.
- Complete map passes; invalid maps and stale callback-less lease fail without mutations or STS launch.
- All three coordinators preserve full scenery in memory at the simulated test boundary.
- Saving/reopening that boundary snapshot retains every root, representative CFrame/size data, attributes and cross-root ObjectValue references during successful, failed and interrupted runs.
- Interruption leaves an unfinished report, with no restore callback needed to recover scenery from the saved snapshot.
- A structural map change during the synthetic test is reported through `mapIntact = false`.

This is a synthetic binary persistence regression, not a native Studio crash/RAM test. The only newly created/reparented object in a real helper run is its own QA result StringValue in ServerStorage; map instances remain where they were. The tutorial harness compile suite also includes all three coordinators, the disabled legacy entry point, preflight and the unchanged root-owned recovery helper: **52/52 PASS**. StyLua checks and scoped `git diff --check` passed.

## Live acceptance after recovery

1. Complete the root agent's recovery and verify the full map against a trustworthy version or backup. The preflight's presence/count check alone cannot prove recovery fidelity.
2. Run the read-only preflight in Edit; expect FULL_MAP and the complete root list, with no lease/staging remnants. Keep the recovered complete backup before testing.
3. Install the relevant test scripts and use the corresponding full-map coordinator only if memory permits. Expect unchanged root/descendant counts, `mapIntact = true`, and the test's separate result.
4. If the process or test cannot complete because of memory, record that limitation and use the future isolated-copy workflow. Do not re-enable the retired lease.
