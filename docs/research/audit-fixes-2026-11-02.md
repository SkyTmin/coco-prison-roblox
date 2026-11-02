# Whole-game audit corrections — 2026-11-02

Owner instruction: “Исправь все!” after the audit at `a1f0465`. All **23 confirmed source findings** now have implemented corrections [сеть: audit/verification]. The conditional teleport/fall risk and additional shared-transfer integration races were also corrected. This closes the source repair backlog; it does not declare every feature accepted on real phones, multiple production servers or a full boss group.

## Coverage

| Audit findings | Delivered behavior | Detailed evidence |
| --- | --- | --- |
| E1–E4 | Area mining advances achievements; earned booster rewards survive a full store; Silk Touch yields one whole melon; the final selling multiplier respects the existing cap. | [Economy/mining report](audit-fixes-economy-2026-11-02.md) |
| SB-01–SB-04 | Reject non-finite economic inputs; grounded cosmetic snapshots cannot create critical hits; intact cells block mining rays; full server dig deadlines are enforced while retaining the fast removal transport. | Economy and [combat/world report](audit-fixes-combat-world-2026-11-02.md) |
| S1–S4 | Failed shared-storage reads stay unavailable; shared transfers recover from a durable journal; page revisions reject stale writers; exact profile acquisition tokens fence every save/release. | Persistence protocol below; [independent integration review](audit-fixes-storage-review-2026-11-02.md) |
| CW-01–CW-06 | Private mine entry spends a pass only on successful arrival; Trainer Strength/Agility work; Tank swaps cannot heal; point Haste survives respawn and respects faction changes; Flame respects current Fire Resistance; Ghetto has bat spawn anchors. | Combat/world report |
| UI-01–UI-05 | Third-person bow reticle persists; HUD/menu editing blocks gameplay; missing-character effects callbacks are safe; shared chest paging cannot retarget a selected stack; auction uses readable reflow/scrolling instead of scaling the entire window down. | [UI report](audit-fixes-ui-2026-11-02.md) |

The earlier brightness/mouse/touch local-preview correction remains in place. Its renderer, settings persistence and existing numeric ranges were preserved. The clean/orange/type-counter rule remains **100 actual cells at ×2 → 100 clean, 200 orange and 200 applicable upgrade progress** [владелец].

## Shared-storage and profile protocol

`SharedStorageService` retains the existing `GangChest_v1` and `FactionStorage_v1` stores/keys. Legacy faction pages are wrapped into a record on the first successful write. Reads return unavailable after failure, never a writable empty replacement. There are no delayed whole-cache saves or expiry-triggered stale flushes.

Each page has a monotonically increasing revision. `UpdateAsync` compares the expected revision and records the outcome under an operation GUID; retries return that same outcome. A page conflict refunds the original player escrow rather than applying an old page snapshot. Different pages can commit independently within the same record. Cached snapshots are copied and short-lived; an old snapshot can only be rejected, not overwrite new contents.

`StorageTransferService` keeps ownership in the player's durable journal:

1. Reserve the affected inventory slots, including all metadata, and save the prepared operation before touching the shared record.
2. Commit the shared page with its revision and idempotent receipt. An unknown response retains escrow and retries the same GUID.
3. `ProfileService.MutateDurable` saves an immutable transformed profile before exposing incoming items/coins. It then applies the transformation to current live state, preserving concurrently occupied slots. Overflow remains pending until space is available.
4. Confirm the delivered marker before clearing the journal and acknowledging the shared receipt. Rejoin resumes a prepared/delivering operation or cleans a delivered marker without granting it again.

Profile acquisition uses a fresh GUID in addition to JobId. Every save and release positively requires that exact token; an absent lock no longer authorizes an obsolete writer. The save snapshot recursively copies nested inventory metadata, cases and artifacts. Invalid numeric state is rejected instead of replacing valid saved data.

`Profile.CanExport` blocks outgoing world drops, payments, relevant auction actions, gifts and shared donations while transfer/death settlement is pending. Same-profile work and incoming activity can continue. CaseService pairs page identity with contents, rechecks sessions after yielding reads and invalidates stale opens. The client sends that acknowledged page and sequences Take All/multi-slot gestures after durable acknowledgements. Valid no-op requests also settle the UI queue.

A death during a pending operation escrows its current droppable belongings and applicable money loss. The resolved pre-death transfer is attached to that death; newly earned post-respawn items are not swept into it. Deferred exports wait for durable consumption. This is deliberately **at-most-once export**: a crash after consumption but before world loot/killer payment can lose that ephemeral output. It is not a cross-profile/world atomic transaction. The review report gives the exact scope and failure tests.

Deployment boundary: all shared-storage writers must use this protocol. Legacy servers performing whole-cache writes must be drained before a future production rollout; mixing those writers cannot be made safe by only upgrading new servers. This session updated the authorized Studio place and did not publish.

## Verification

Seven actual-source offline suites pass **800 assertions** [сеть: fixture outputs]. They exercise real Luau modules with isolated stores/profiles, deterministic time and fault injection, including commit-before-error, missing acknowledgements, stale sessions, full bags, death and rejoin. Counts: economy 49, storage 54, Case 17, profile 39, UI 579, combat/world 44, death/storage 18 [сеть]. Full Selene has zero errors/warnings/parse errors; StyLua, Rojo build and whitespace checks pass.

In the confirmed Katorga place (`92594200898716`), source-only synchronization updated **51 modules** and Play restarted [сеть]. The idempotent Ghetto patch repaired **4 private arrivals** and added **5 bat anchors**; a repeat added none [сеть]. No scenery rebuild/map replacement occurred.

Studio checks [сеть]:

- Shared read-failure regression: **4 checks**, saved mock stack retained, no write after failed read; no real shared keys touched.
- Mining regression: **19 checks**, including a full mixed layer and boosted material requirements. One ordinary live quarry DigStart gave **+1 clean, +1.13 orange and +1.13 stone upgrade progress**; its normal reward was retained and the character returned to its pre-test position.
- Auction rendered on desktop and a temporary compact window; filters and sale layout were inspected. Via the actual Device Simulator API, Galaxy A06 landscape rendered the auction, sale inventory and scrollable sale actions; iPhone 17 Pro landscape rendered personal listings. Action targets retained **44 px**, inventory cells **44 px**, lots **46 px** [решение/сеть]. The game uses LandscapeSensor and DeviceSafeInsets. Some automated clicks missed after viewport scaling; the attempted iPhone filter click is not counted as passed. No listing/purchase was submitted.
- With the owner's existing bow, drawing in third person kept the reticle visible. Opening settings and releasing canceled the shot; arrow count stayed **4**, cursor was visible and free [сеть]. Original selected slot restored.
- Final state: Creative enabled, no test windows/held dig, CameraType Custom, device simulator reset to default. No new production script errors or Sfx infinite-yield warning. The existing asset-type warning for **203785492** remains; a temporary MCP camera-restoration diagnostic was separately resolved and verified.

[Machine-readable results and limits](audit-fixes-validation-2026-11-02.json). Economy simulation ran through the existing time cap, reaching level **26** when requested through **50**; its model excludes boosts/books. Boss simulation ran, but its existing analytical model excludes the newly connected Trainer effects. Neither substitutes for full progression or group balance acceptance.

## Remaining acceptance and separate decisions

Native phone gestures/keyboard overlap, physical mouse sensitivity, actual distributed DataStore outages, group boss survival/balance and startup frame-time remain unverified acceptance scenarios. Windows native capture timed out twice; the independent Studio simulator API succeeded afterward. Simulated layout is not physical touch acceptance.

Unconfirmed design questions from the audit remain separate: per-cell AoE XP/chance semantics, artifact-case persistence, boss star allocation/ownership, and paused industrial scope. No new balance or feature decision was invented to close these questions. Historical missing events that were never saved cannot be reconstructed; saved unclaimed counter milestones now catch up without repaying explicitly claimed ones.
