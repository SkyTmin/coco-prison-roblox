# Persistence and shared-storage audit — 2026-11-02

Read-only follow-up to the economy audit. Baseline code: `a3ffec7`; source anchors below concern the persistence/storage paths reviewed before any fixes. The coordinating agent may be editing unrelated settings concurrently. No Studio, real datastore calls, profile mutations, production edits, tooling installation, commits or publishing were performed by this reviewer.

## Findings

### S1 — P1: A failed faction-storage read becomes a writable empty replacement

**Source:** `src/server/Services/FactionStorageService.luau:50–81,89–100,103–124`; mutation caller `src/server/Services/CaseService.luau:725–786,789–792`.

**Failure sequence:**

1. The durable `FactionStorage_v1/<faction>` record contains items in several chests.
2. Startup `GetAsync` fails transiently. `load` has already initialized eight empty chests; it only warns on failure, then unconditionally assigns them to `data[faction]` and clears `loading`.
3. A faction member opens the apparently empty chest and deposits an apple. `Chest` returns the cached empty table without retry, and `CaseService.move` marks it dirty.
4. The next successful 30-second save calls `SetAsync(faction, out)` with that empty-plus-apple cache. It overwrites the original entire eight-chest record.

**Consequence:** A temporary read outage can permanently erase an entire faction's stored possessions, even with exactly one game server. No recovery record or failed-load flag protects this store. A syntactically valid no-op CaseMove can also mark the faction dirty because MarkDirty is unconditional after the mutation callback; an actual deposit is not essential to the overwrite.

**Expected boundary:** A failed read must never publish an empty writable cache. Keep the storage unavailable until a confirmed read succeeds, distinguish an absent record from an unreadable one, and forbid saves from failed/uninitialized loads.

**Confidence/evidence:** High; the coordinating agent additionally reproduced this with the **actual FactionStorageService Luau source** using [`scripts/qa-storage-load-failure.luau`](../../scripts/qa-storage-load-failure.luau). The harness compiles the source inside a temporary isolated ModuleScript, substitutes mock-only DataStore/task/require/game dependencies, injects a read failure and advances the save scheduler after MarkDirty. It does not use `loadstring` or enable it. Reported runtime result:

```json
{
  "readFailureWarned": true,
  "exposedEmptyAfterFailure": true,
  "writes": 1,
  "previousStackLost": true,
  "realDataStoresUsed": false
}
```

The seeded stack existed only in the mock store. No real profiles, shared-storage keys or DataStores were mutated; the temporary ModuleScript was cleaned up. This confirms the empty-cache/write behavior in the real Luau module, while real-service outage timing and a corrected implementation still require separate validation. The earlier local JS model also reached the same outcome.

### S2 — P1: Shared-chest transfers have no durable transaction across the two inventories

**Source:** `src/server/Services/CaseService.luau:725–786,789–792`; `FactionStorageService.luau:103–124,139–145`; `GangChestService.luau:148–173,267–273`; `ProfileService.luau:37,461–496,1001–1013`. Gang save gap is 6 seconds (`src/shared/Config/gangs.json`, `base.chest.saveGapSeconds`), faction save interval 30 seconds, profile autosave 120 seconds.

**Failure sequence A — duplicate on deposit:**

1. Durable player inventory owns X; durable shared chest does not.
2. A normal CaseMove removes X from the in-memory player inventory and inserts X into the live shared table in one non-yielding callback.
3. The shared-store write succeeds after its save gap. The profile has not yet saved.
4. The server crashes. On reload, the old durable profile still owns X and the new durable shared chest also owns X.

**Failure sequence B — duplicate on withdrawal:**

1. Durable shared chest owns X; player does not.
2. Player withdraws X and leaves; `PlayerRemoving` durably saves their new inventory.
3. The server crashes before the chest's dirty snapshot is written (or that write fails).
4. The saved player owns X and the old saved chest still owns X. Reversing which side persisted first can instead destroy the item.

**Consequence:** Normal storage interaction followed by a crash or one write failure produces duplication or loss. This affects gang and faction chests and does **not** depend on concurrent servers or a broken lock. `ProfileService.Mutate` makes the in-memory edit synchronous; it does not make two DataStore keys atomic. No transfer ID, pending operation, reservation or replay/reconciliation path exists in these modules. The `SaveNow` elsewhere in CaseService is for purchasing an ender-chest section, not shared-item transfers.

**Expected boundary:** Journal a transfer/reservation durably before publishing its outside effect and make each side idempotent/recoverable. Saving both snapshots in sequence without a journal still leaves a crash window. Existing AuctionService pending-operation design is a useful local reference, but simply copying its calls is not sufficient without defining chest item ownership during recovery.

**Confidence/evidence:** High, explicit separate write paths. A local JS model reproduced two durable copies after the shared side alone committed. No crash was induced in a real server.

### S3 — P1: An expired gang-storage owner can overwrite the new owner's data

**Source:** `src/server/Services/GangChestService.luau:148–165,257–289,336–342`; acquisition timing `191–214`. Configuration: lock 60 seconds, renewal 20 seconds, local validity cutoff 50 seconds.

**Failure sequence:**

1. Server A holds a gang's lease and has unsaved page changes.
2. A stalls or its store operation blocks long enough for the 60-second MemoryStore lease to expire.
3. B acquires the lease, loads the durable chest, changes it and saves successfully.
4. A resumes. `tick` calls `save(id, chest)` for dirty data **before** attempting renewal or calculating `lost`.
5. `save` uses `DataStore:UpdateAsync(id, function() return data end)`. It ignores the current value and has no owner, lease epoch or version predicate, so A replaces B's newer pages. A may only discover the lost lock afterward.

**Additional paths to the same defect:** The lost/idle branch explicitly tries to save before dropping cached pages; BindToClose also saves dirty pages without checking ownership. Initial acquisition records `lockedAt = os.clock()` after the potentially slow `GetAsync`, not at confirmed lease acquisition, so a delayed load can overstate how long the lease is still held.

**Consequence:** Lease expiry does not fence writes. Stale data can erase a new owner's deposits or resurrect their withdrawals; depending on player inventory state this causes loss/duplication. The local `Valid` gate closes UI actions after a timeout, but cannot protect unconditional asynchronous durable writes.

**Expected boundary:** Reject writes from lost ownership, with a generation/epoch that the durable store itself checks. Renewal-before-save and early UI closure are useful but cannot by themselves fence a write delayed past lease expiry. Treat lost ownership as a recovery event instead of flushing the old cache over the current owner.

**Confidence/evidence:** High, the renewal/validity order and unconditional write are directly visible. A local source-sequence model overwrote B's newly stored item with A's stale pages. Exact Roblox outage scheduling remains to be tested in isolated staging.

### S4 — P1: Profile save accepts a missing lock after another owner has finished

**Source:** `src/server/Services/ProfileService.luau:38,351–376,487–496`; release path `1001–1013`.

**Failure sequence:**

1. A holds a player's profile but stalls or has a delayed save past the 300-second stale-lock threshold.
2. B takes the profile over, plays with the newer state, then saves and cleanly releases it. The saved record now has `_lock = nil`.
3. A's old save/final-release operation runs afterward.
4. The save predicate rejects only `typeof(lock) == "table" and lock.job ~= JOB_ID`. Because the lock is now absent, that test is false and A replaces the record with its stale snapshot.

**Consequence:** A stale session can revert a newer session's inventory, currencies and transaction notes once the newer session has released its lock. The normal different-job check works while B remains locked, but not after B leaves. This can also undermine Auction/Donate correctness even though those services use pending records or receipt markers inside the profile.

**Expected boundary:** A writer must positively prove it still owns the exact acquisition, including release saves. Missing lock means no current ownership, not permission for an old session to write. Keep a per-acquisition token/version rather than relying only on JobId; reject old writes even when the latest owner has already released.

**Confidence/evidence:** High for the predicate and consequence; trigger needs a sufficiently delayed/stalled old writer. A local JS evaluation of the exact guard rejects `_lock.job = B` for writer A but accepts `_lock = nil`, confirming the boundary hole. No real datastore timing claim is made.

## Explicitly declared limitation: faction storage is single-server-only

`FactionStorageService.luau:4–6` openly states that multiple servers use last-writer-wins and that this was accepted while the game runs one server. Each server reads every faction once at startup (`load` caches forever), then writes the whole cached faction record with SetAsync. If A and B load the same item, both can withdraw it; a later write can also overwrite the other server's deposits. There is no ownership lease, revision check or cross-server refresh.

This is **not presented as an accidental violation of the original single-server implementation**. It is a known deployment blocker before running more than one writable server. `MaxPlayers`/a small population do not enforce a universe-wide one-server limit, and these modules contain no such enforcement. Single-server deployment also does not solve S1 or S2. Gang storage claims to support all servers and has a lease mechanism, so S3 is a defect in that intended guarantee rather than the same declared limitation.

## Adjacent boundaries checked

- **Profile load failure:** A failed profile load is marked `loadFailed`, skipped by `save`, and rejected by `SaveNow`/`IsReal`. This is the protection missing from faction-storage load; it is not evidence that shared transfers are safe.
- **Auction:** Uses per-player pending sells/buys, SaveNow before outside lot mutations, atomic per-lot UpdateAsync, operation IDs and tombstones for uncertain listings. Buyer/seller recovery was inspected around `AuctionService.luau:379–608,638–842`. No additional high-confidence defect was promoted during this bounded pass. Its guarantees still depend on profile ownership and durable snapshot integrity, including S4.
- **Donate receipts:** `DonateService.luau:228–274` requires a real profile, records the receipt with the grant and waits for SaveNow before PurchaseGranted. That is stronger than shared-chest moves. Real retries, delayed acknowledgements and receipt retention need staging validation; this pass does not call them proven safe or report a speculative duplicate as a fifth finding.
- **Failed-profile access to shared actions:** CaseService's chest open/move path does not check `ProfileService.IsReal`. Default failed-load profiles therefore are not explicitly barred from durable shared inventory effects once normal membership/access prerequisites are reached. This is an additional boundary to cover when implementing S2; not counted as an independent fifth defect because the practical access sequence was not exercised.

## Required isolated tests

1. Seed non-empty faction storage, fail only its read, then restore writes. Chest opening/moving must remain unavailable; no write may replace the seed. Retry read successfully and verify all eight chests unchanged.
2. For deposit and withdrawal, stop execution after every durable step of the proposed journal protocol and restart with fresh in-memory state. Across profile+chest+pending records, total ownership must always resolve to exactly one item; include full inventory, retry and repeated recovery.
3. Gang A/B fake-clock lease test: expire A, let B acquire and commit a unique item, then resume A's periodic, idle/lost and shutdown saves separately. Every stale write must be rejected. Include a delayed initial read beyond the lease duration.
4. Profile A/B takeover: let B acquire, mutate, save and release; then retry A's stale save and stale release. Both must reject, and B's state must survive. Also exercise same-job later acquisition with distinct session tokens if the implementation permits it.
5. If multiple live servers are planned, explicitly test/enforce the chosen faction-storage ownership model before opening access. A two-player single-server fixture does not validate cross-server storage.
6. After storage transaction changes, run auction purchase/list/cancel/recovery and developer-receipt save-failure tests with throwaway accounts/keys, because all share profile persistence.

## Evidence limits

All four findings follow directly from reachable code paths and explicit persistence boundaries. This reviewer performed read-only source searches plus a small local JS state-machine reproduction. The coordinating agent then executed S1's actual Luau module in the isolated mock-only harness described above; the script was inspected and the reported runtime output is recorded here. S2–S4 remain static/source-model findings: their JS snippets do not execute Luau or emulate Roblox DataStore concurrency, serialization, network failures or server lifecycle. No real data was touched by these checks. Testing remains necessary to validate a fix and its recovery behavior, not to reinterpret in-memory atomicity as durable atomicity.
