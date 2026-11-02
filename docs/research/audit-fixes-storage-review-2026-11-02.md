# Shared-storage integration review and death boundary — 2026-11-02

Independent source review of the parent's CaseService, SharedStorageRecord, SharedStorageService, StorageTransferService and ProfileService.MutateDurable changes. No Studio, live profiles, live stores, commits or publishing were used.

## Findings fixed during review

- **Cross-page duplication during a yielding read:** move captured the page contents/revision before Storage.Snapshot yielded, but used the same session's mutable page index for the eventual transfer. A page change could withdraw an item from the old snapshot while committing to another page. Parent now captures and rechecks the immutable page and pending state before any mutation.
- **Stale page/open responses:** a delayed page read could update a closed/replaced session; an older shared-chest open could overwrite a newer window and empty its case contents. The final page-count read also yielded after installing a session, allowing a close to leave a nil session dereference. Parent added open epochs, rechecks, pre-install page-count reads, and current gang-house permission checks.
- **Death could bypass the pending export barrier:** DeathService could export victim coins/world loot while a transformed durable profile snapshot still held the same assets. This agent added a profile-owned death queue and escrow for deaths that occur while shared transfer/death settlement is pending. Parent connected the transfer delivery hook and included the death queue in CanExport/busy handling.

## Deferred death behavior

At death, only the character's current droppable inventory and the applicable PvP coin loss are put in `storageDeath.queue`. Kept tools/armor remain equipped/in inventory. The active shared transfer id is attached to the first applicable queued death. `DeathService.HoldTransfer` routes that transfer's resolved droppable result directly into its original death escrow; later respawn/mining rewards stay outside it. Multiple deaths have separate records.

Settlement waits for `storageTransfer` to clear, persists consumption of the death record through MutateDurable, then emits world drops and pays an eligible online killer. An absent or uncreditable killer at settlement causes the loss to be refunded in the durable consumption instead. An unfit refund stays in escrow. OnLoaded and periodic recovery resume persisted queues without requiring the chest to reopen.

The protocol intentionally favors **at-most-once export**: a crash after durable consumption but before world drops/payout can lose that ephemeral output, including a killer disappearing during the final write. A saved consumed record cannot emit again on retry/rejoin. This gap is explicit; it does not claim a cross-profile/world atomic transaction. Ordinary deaths with no shared operation/queued death retain the pre-existing immediate behavior.

The parent added the `HoldTransfer` call inside StorageTransferService's durable delivery transform, blocked new transfer Begin while CanExport is false, and included storageDeath in profile export and busy gates. This agent changed only DeathService and the two fixtures below during this follow-up.

## Validation

- `scripts/qa-shared-case-offline.luau`: **17 passing checks** [fixture result]. Loads actual CaseService, InventoryService, Numbers, Persistence and Vault. Controlled reentrant read hooks exercise the actual UI entrypoints. The durable transfer boundary is mocked and tested separately by the economy agent's storage harness.
- `scripts/qa-death-storage-offline.luau`: **18 passing checks** [fixture result]. Loads actual DeathService with deterministic durable-profile/world mocks. Checks deferred exports, current inventory/coin escrow, kept items, held transfer output, post-respawn items, online/offline killer, wallet-capacity changes during refund persistence, retries/rejoin, failed consumption before/after persistence, multiple deaths, and ordinary non-pending behavior.
- DeathService passes Selene with zero errors/warnings/parse errors; changed Luau passes StyLua; `git diff --check` is clean [tool results].

The atomic storage/receipt review found no additional independent defect after the parent corrections: page CAS and immutable snapshots prevent stale writes, rejected CAS restores original escrow, uncertain outcomes retry the same operation id, delivery is persisted before exposure, and page revision monotonicity prevents the original transform replaying after receipt cleanup. This is source/fixture evidence, not real distributed-service or Roblox latency acceptance.
