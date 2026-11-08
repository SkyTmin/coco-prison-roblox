# Small, stable requirements card

Owner steering, 2026-11-03: the requirements card must take less space by default, allow direct mouse/touch placement and resizing, and retain its chosen position.

## Cause and change

`TutorialGuide` previously called `TutorialPanel.relocate` every 0.25 seconds even when `HudLayout.moved("requirements")` was true. That helper performed automatic obstacle avoidance again. Meanwhile `HudLayout.apply` restored saved screen fractions on profile/viewport updates. Changing touch-control rectangles could therefore move a saved card to a different automatic column.

Manual placement now has one owner: HudLayout. Panel updates only clamp it to the screen when necessary; changing HUD obstacles never sends it back to automatic placement. The automatic position is also stable within a viewport, with content scrolling in the chosen column rather than selecting a new position on every count/phase update. It is recomputed after viewport changes, explicit layout reset or a change between compact/wide card formats. Layout application does not overwrite an element while that element is being edited.

The pinned level card is **220×100 px at default scale**. It shows its goal and two icon/count rows. The redundant requirements heading/count, explanatory footer and menu shortcut are hidden for manually tracked goals. Mobile cards are at most 220 px wide. The normal tutorial still retains its action instruction. Existing resource/settings icons are reused; no assets were invented.

The header has a small settings icon with a localized tooltip and a separate close icon. Their 44×44 touch hit areas do not overlap. The settings icon opens the existing HUD editor restricted to this card; only its header is the drag grip. Minus/plus controls are immediately visible and remain 44 px high independently of card scaling. The user finishes with **Lock / Закрепить**. Scale uses the existing 0.5–2 range and 0.1 increments. Reset removes only the requirements entry, preserving other HUD positions.

Saving uses the existing `SetHudLayout` remote and `hudLayout[mobile|desktop].requirements = {x, y, shown, scale}`. No new profile/settings schema or server behavior was introduced. The filtered editor clones other entries before submitting, so changing this card does not erase the rest of the HUD layout. The client entry-point change only wires the card's edit callback to this existing editor.

## Verification

- `qa-hint-layout-offline.luau`: **33 checks passed** using the actual TutorialPanel, HudLayout mouse/touch/scale/lock/reset handlers, the actual server SetHudLayout handler, and actual ProfileService save/release/reacquisition under an isolated fake store. Covers default 220×100 geometry; compact content; four tooltip locales; separate hit areas; default-position stability; direct-editor filtering; 50% limit and 10% scaling steps; matching-touch identity; unrelated-finger rejection; profile refresh during editing; lock preserving other entries; obstacle changes after pinning; and saved coordinates/scale after reacquisition and application by a fresh HudLayout module.
- Existing actual Panel/Config/Strings checks: **141 passed**. The old expectation that manually placed cards should automatically relocate around controls was deliberately replaced by the owner's newer requirement: clamp to the screen without choosing another position.
- Inventory builder/fitter regression: **524 passed**, unchanged by the editor wiring.
- Scoped Selene, StyLua and whitespace checks passed. No Studio, OS input or real profile operations were performed by this agent.

Native rendering and engine input are root-owned acceptance. Root's prepared LocalScript uses `CreateVirtualInput` and the normal save remote; its result must be recorded separately from these mocked boundary tests.

## Native QA identifiers

Card `FirstSteps`; settings button `EditRequirementsLayout`; close `HideRequirements`; tooltip `RequirementsLayoutTooltip`; header `RequirementsDragHeader`; editor `HudLayoutEditor`; handle `Handle_requirements`; minus `Smaller`; plus `Bigger`; finish `LockLayout`; reset `ResetLayout`. Profile state can be verified through a normal resend after finishing the editor. Test restoration should restore only the QA actor's original HUD layout; the editor's own reset is scoped to the requirements entry.
