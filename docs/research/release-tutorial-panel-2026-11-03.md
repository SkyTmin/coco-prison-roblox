# Compact tutorial task panel

Owner request, 2026-11-03: move the tutorial task card to the right and match the upgrade requirements presentation, with individual resource icons, names, exact counts, completion ticks, and a separate money row. Also stop sending a new player to the buyer after every mined block.

## Changes

- `src/client/TutorialPanel.luau` is a presentation-only renderer. The normal card is 250 px wide, with dark resource rows, a localized requirements header and completed/total count, green actual/required values, and a tick only for a completed requirement. Its icons use `Config.counterIcon`, the same helper as UpgradeWindow; this resolves the genuine gravel, dirt and sand assets through `Config.iconFor`. No asset or requirement was invented.
- The goal title, exact required counts and money come directly from the shared Tutorial goal. Actual spendable money stays separate from the explicitly labeled projected amount after selling. The level-up task uses the same renderer with its real total-block requirement. Reused rows reset their dimensions when the task changes or progression is reset.
- Placement prefers the right edge. It considers visible buttons, the actual Scoreboard and hotbar rectangles, the movable jump proxy, and Roblox's native jump/joystick areas. It tries a clear adjacent column when necessary. A short available region scrolls the card's contents at readable text sizes; it never overlays controls as a fallback. Menu shortcuts retain a 44 px touch target. The only unrelated-looking client entry-point change is the stable `Scoreboard` name used to recognize that existing HUD panel.
- `TutorialGuide` retains its target selection, ray budget, beam, control highlights, input observation and persisted step semantics. Both mining phases now select the buyer only when the shared goal says `saleReady`; upgrade/level UI guidance still requires `ready`, based on actual coins. The shared sale estimate and server SellAll implementation are owned by the economy change and use the same `Selling.quote` calculation. The guide no longer treats any sellable bag item as a reason to leave the mine.
- New compact labels and projected-sale instructions are present in Russian, English, Spanish and French in `Strings/ReleaseTutorial.luau`.

## Verification

- `qa-tutorial-panel-offline.luau`: **91 assertions passed** against the actual panel module, actual Config and full Strings catalog, with GUI/event boundaries mocked. Covers all four locales, the three real starter icons, exact counts and completion ticks, actual versus projected money, the ordinary menu shortcut, task/reset row reuse, obstacle visibility, and placement at 1280×720, 390×844 and 844×390. A fully obstructed HUD produces no overlapping fallback panel.
- `qa-release-tutorial-guide-offline.luau`: **14 existing targeting/input-observation checks passed**, including the bounded scan of 12,000 candidate cells, removed/hidden target replacement, and the menu → item selection → buy highlights.
- `qa-release-ui-onboarding.luau`: **295 assertions passed**, plus its **39** actual profile persistence boundary checks.
- Scoped Selene: **0 errors / 0 warnings**. Scoped StyLua check passed. Rojo source build passed. The full workspace whitespace check reported unrelated in-progress sword design documentation; those files were left to their owning agent.

These are offline source and layout checks, not a claim of native font rendering, touch acceptance, or completed live onboarding. Root owns the Studio restart/resync and actual first-login mine → sell → upgrade → level acceptance.

## Actions input fixture checkpoint

The preceding live Actions run passed 28/30 checks, including pay/gift conservation, replay checks and layout. Both remaining native UI failures had an exact 58 px discrepancy between the requested point and `UserInputService` coordinates, matching the top GUI inset. The fixture now adds `GuiService:GetGuiInset()` to the point sent through `VirtualInput` while keeping hit tests and clipping in GUI coordinates. It records requested logical coordinates, actual input coordinates, inset and input events. No production Actions UI behavior changed for this fixture issue; root will rerun it.
