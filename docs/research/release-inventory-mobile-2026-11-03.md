# Inventory sizing and clean camera smoke

## Confirmed mobile defect and bounded fix

The actual iPhone 17 Pro landscape emulator reported a 750×381 client viewport. The previous inventory used a fixed 512 px height with the avatar/equipment/stats section above the bag. The global window fitter shrank the entire window to its available height, including item slots and text. Root's screenshot showed approximately 22 px slots.

Only `buildInventory` in `src/client/init.client.luau` changed. On a short, wide viewport the same equipment and avatar cards form a sidebar, with the four statistics in a compact 2×2 card below them; the 9-column backpack and hotbar sit alongside it. Desktop keeps the previous composition. Narrow portrait screens select the slot width from the available width while preserving label font sizes. Window height now includes the real bottom of the hotbar instead of a fixed constant.

The item/armor addresses, drag handlers, preview renderer and profile refresh behavior remain the same. A viewport/camera change defers one rebuild of the currently open inventory; destroying the old window cancels its drag and preview animation. A deferred rebuild cannot reopen an inventory that has already been closed.

`scripts/qa-inventory-layout-offline.luau` executes the actual inventory builder and actual `fitWindow` function with GUI/service boundaries mocked. **524 assertions passed**, covering all 36 inventory and 4 armor slots, unique drag addresses, containment, statistic label bounds/font sizes, coalesced orientation events and close-before-resize behavior.

| Client viewport | Window | Slot size | Whole-window scale |
| --- | --- | --- | --- |
| 750×381 | 652×308 | 44 px | 1 |
| 844×390 | 652×308 | 44 px | 1 |
| 390×844 | 364×468 | 36 px | 1 |
| 360×800 | 337×456 | 33 px | 1 |
| 1280×720 | 472×526 | 44 px | 1 |

These are actual-source layout results, not native touch/font acceptance. Root will restart/resync and verify iPhone and A06 emulators. Scoped Selene and source build passed. No Studio or real profile operations were performed by this agent.

## Camera report correction

An earlier menu smoke appeared to leave `Workspace.CurrentCamera.CameraType` set to Scriptable. Root subsequently found MCP's `ExecuteLuauActions` log explicitly restoring the camera type captured before an overlapping command. The test had been contaminated by that command's cleanup.

Root reran the actual LocalScript smoke with **no parallel MCP calls until completion**: **19/19 checks passed**, including first-person opening/closing of all eight menus, actual brightness and mouse-sensitivity settings, and the installed touch camera adapter. **WindowInput was not changed.**

`scripts/qa-window-input-offline.luau` separately passes 39 ordinary checks against actual WindowInput and reports two potential synthetic edge cases: a camera A→B→A switch while held, and a suspended controls Enable. Their diagnostics explicitly state `productionTriggerProven=false`; neither is evidence that the clean native smoke failed or a reason to claim a production fix.
