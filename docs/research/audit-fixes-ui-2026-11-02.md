# UI audit corrections — 2026-11-02

Owner instruction: “Исправь все!” after the whole-game omission audit. This report closes the code corrections for UI-01–UI-05 from `audit-2026-11-02-ui-mobile.md`; it does not replace native-phone/visual acceptance. This reviewer used static/offline checks only and did not operate Studio, mutate a real profile, publish or push. Parent subsequently integrated and synced the changes; current delivery and live checks are in `audit-fixes-2026-11-02.md`. Server shared-storage transactions belong to the parent agent.

## Changes

| Finding | Correction | Main source |
| --- | --- | --- |
| UI-01: third-person bow reticle overwritten every frame | Frame visibility now includes active bow draw and the common gameplay-block predicate. | `src/client/init.client.luau`, final HUD RenderStepped callback |
| UI-02: HUD editor allowed gameplay actions | `WindowInput.GameplayBlocked` covers open windows, HUD editing, text entry and missing/dead characters. Dig targeting/auto-dig, mouse/controller attacks, repeated attacks, bow/eating callbacks, touch start/hold and item throwing use it. Entering the editor cancels held dig/attack/bow state. Focus loss also clears held melee. Bow release independently checks blocking, covering an input release between menu opening and the next Heartbeat. | `src/client/WindowInput.luau:9`, `init.client.luau`, `BowController.luau:138` |
| UI-03: characterless effects callback error | A missing character resets nausea/blindness/hurt/FOV state, hides the darkness overlay and returns safely. The existing pre-camera roll undo remains intact. | `src/client/EffectsHud.luau:269` |
| UI-04: selected gang slot retargeted on paging | Clear drag before requesting a page, disable selection/moves while pending, and clear again on acknowledged page change. Moves use `profile.casePages.gangChest`, replicated atomically with contents, as the final CaseMove argument. Root's server validates it against the current session page. Request timer identity prevents an old timeout releasing a later request for the same page. | `src/client/ChestWindow.luau` |
| UI-05: unreadable uniformly scaled auction | Auction window is sized to the viewport at native pixel scale and recentered on rotation. Lots reflow into adaptive columns in a scrolling grid; compact mode has a filter pane toggle. Personal listings and sale forms scroll; returned items scroll horizontally. Sale inventory reflows above its form on narrow screens. Fonts are at least 13px on controls/14px on labels, and action/close targets are 44px. Filter, sorting, listing, purchase confirmation, returns and pagination behavior remains. | `src/client/AuctionLayout.luau`, `AuctionWindow.luau`, `init.client.luau:637`, `Strings/Part5.luau` |

The new `auction_filters` label has Russian, English, Spanish and French translations. Dimensions/timings here are implementation choices [решение]; game prices, slot counts and server validation are unchanged.

## Shared-storage integration

`StorageTransferUi` owns the small client pending/queue state. A shared move immediately disables additional selection rather than waiting for `SharedStorageBusy` replication. It releases only after the monotonic `profile.storageSettled` revision advances and the server is idle. Inventory-to-inventory moves do not wait for a shared-storage transaction.

Shared “Take All” now pumps one quick transfer at a time. After its durable acknowledgement, the next nonempty slot is considered from the latest profile. This avoids the previous burst of 27 requests being rejected by a newly busy journal. DragDrop's optional batch callback also preserves a desktop split-across-several-slots gesture: its complete destination list is queued and sent sequentially. Normal inventory builders retain the existing callback behavior. Queues are pinned to their page and cancel on page replacement, character removal, window destruction or a 15-second unanswered-request timeout [решение]. Timeouts compare request identities; an old timeout cannot cancel a newer operation. A still-busy server continues to block selection after a local timeout. Explicit busy transitions clear held selection; a deferred clear prevents DragDrop's partial-stack continuation from recreating an in-flight ghost.

Required parent-owned protocol: `casePages.gangChest` and contents change in the same Profile.Mutate; `CaseMove` validates the acknowledged page; final durable completion advances `storageSettled` before the confirming save, and the busy flag clears only once that save succeeds. A valid no-op shared move (empty/stale slot or full inventory) also needs a processed-request acknowledgement so the UI does not wait for its timeout. Server transaction/crash-recovery evidence is recorded by the parent, separately from these UI checks.

## Offline verification

Run `lune run scripts/qa-ui-regressions.luau` from the repository. The available executable was `C:/Users/user/AppData/Local/Temp/coco-case-warzone-qa/lune.exe`.

The final harness passed **579 assertions**. It compiles the entire client and auction module, loads real `WindowInput`, `AuctionLayout`, and `StorageTransferUi`, and executes actual input/reticle/effects and drag/transfer callback source with isolated services. It does not replace these handlers with copies of their intended logic.

- Actual mouse and touch entry handlers send no action/aim intent with a window, HUD editor, focused text box, absent character or dead humanoid. Normal handlers still operate when unblocked. Held input is canceled, and a bow released immediately after UI blocking cancels instead of shooting.
- Third-person bow visibility stays on during draw and off when idle. Sixty characterless effects frames complete without error and reset the active FOV/darkness state.
- Shared transfer tests cover stale revisions, idle attribute without revision, newer revision while busy, completion, one request in flight, timeout identity, page change, queue exhaustion and no slot beyond 27. The actual DragDrop distribution callback delegates all three test destinations, and the actual ChestWindow queue preserves their counts and sends each only after its predecessor settles.
- Layout checks verify every lot/inventory cell is inside its scrolling canvas, inventory cells do not overlap, the form fits and the grid clears header/pager at these viewports:

| Viewport / inset | Window | Lot columns / scroll viewport height | Sale form width |
| --- | --- | --- | --- |
| 390×844 / 58 | 366×650 | 7 / 426px | 346px |
| 844×390 / 58 | 820×308 | 10 / 84px | 356px |
| 1280×720 / 58 | 900×638 | 10 / 414px | 436px |

Lots remain 46px and sale inventory cells 44px in each layout. The landscape lot list intentionally scrolls vertically instead of scaling down the complete interface.

Selene on the changed client modules: zero errors, warnings or parse errors. StyLua and whitespace checks pass. A full Rojo source build to a temporary `.rbxl` passed. No production place/map replacement was performed.

## Parent live QA / remaining acceptance

1. Sync `init.client`, `WindowInput`, `BowController`, `EffectsHud`, `ChestWindow`, `StorageTransferUi`, `DragDrop`, `AuctionWindow`, `AuctionLayout`, `Strings`, and the parent's paired storage/profile server changes; restart Play as authorized.
2. Desktop third-person bow: draw/release; open a menu or H just before release. Check center reticle and that the blocked release cancels. With PRIS+ auto-dig or held melee active, open H, move HUD handles, close H; a fresh gameplay press is required.
3. Remove/replace the QA character after sprint/bow/hurt, checking output for frame errors and neutral camera effects.
4. Use an isolated gang with different first-slot items on two pages. Tap/drag an item, request another page, attempt a drop while waiting, then after acknowledgement. No item should transfer until a new selection is made. Test a stale page move, partial stacks, full inventory, failed/slow storage save, rapid inputs and Take All; do not use the owner's real inventory for artificial fixtures.
5. At 390×844 and 844×390, open all three auction tabs; scroll all lots/filters, change category/sort/range/search, paginate, view purchase confirmation, select inventory, edit count/price/currency and inspect personal listings/returns. Rotate an already-open auction both ways. Confirm server results through normal isolated fixtures.
6. Native phone keyboard overlap, gesture competition, font rendering in all four locales and owner readability/visual acceptance remain pending. Arithmetic and mocked callbacks are not a claim of native-device acceptance.

Brightness/mouse/touch preview corrections and their 17-check harness are documented in the earlier audit. This batch leaves the proven ColorCorrection renderer and engine mouse scaling unchanged.

## Additional independent profile-boundary verification

At the parent's subsequent request, `scripts/qa-profile-persistence-offline.luau` runs the actual ProfileService private acquire/save/migrate functions through a test-only return-seam injection. It also loads actual Persistence, Numbers, InventoryService and StorageTransferService. No production source is changed by instrumentation and no real DataStore is contacted.

All **39 checks pass**: A→B stale-lock takeover and B release still reject A's stale save/release; the same job cannot reuse a different acquisition token; deep nested inventory/cases/artifacts remain frozen while UpdateAsync yields; grants remain unavailable before successful persistence acknowledgement; both precommit and applied-but-error outcomes withhold the live grant; retry and rejoin yield exactly one grant; the real delivery transform preserves a concurrently occupied destination and saves the merged result; migration retains progress without marking unpaid achievement tiers as paid. The storage service's larger crash/receipt fixture remains parent-owned.
