# UI, input and mobile omission audit — 2026-11-02

Baseline: `stage-1`, `a3ffec7`. Review performed against repository source. This agent did not operate Studio, change a player profile, publish, commit or push. The parent agent separately investigated the owner's later report that brightness and possibly mouse sensitivity do not work; its live evidence must remain distinct from this static audit.

Read `CLAUDE.md`, the latest `docs/PROGRESS.md` journal entries and relevant `docs/GAME-DESIGN.md` inventory/combat/settings/body/chat/storage sections. Historical TODOs were not treated as current failures.

## Confirmed defects

### UI-01 — P2: third-person bow crosshair is hidden every frame

- **Confidence:** high; conflicting assignments in the same script.
- **Locations:** `src/client/init.client.luau:3666`, `:100`, `:2776`; `src/client/BowController.luau:114`.
- **Trigger:** on desktop, select a bow, remain in third person and hold the right mouse button to aim.
- **Cause:** `renderCameraButton()` includes `BowController.Drawing()` and is called when drawing changes. The unconditional RenderStepped assignment at line 3666 subsequently accepts only `firstPerson or isMobile()`. It overwrites the bow's crosshair before ongoing rendering.
- **Consequence:** the shot uses `ViewportPointToRay(viewport.X/2, viewport.Y/2)` while the center aiming mark is invisible. The mouse cursor is not the shot direction.
- **Correction:** centralize crosshair visibility and retain the bow-drawing condition while a gameplay-blocking overlay is closed.
- **Verification:** third-person desktop bow draw/release, first person, touch, menus; confirm both the center mark and real ray direction.

### UI-02 — P2: HUD editing suspends movement but leaves gameplay input active

- **Confidence:** high; auto-dig provides a deterministic path independent of GUI hit-testing behavior.
- **Locations:** `src/client/init.client.luau:3594`, `:2559`, `:2587`, `:2638`, `:2706`, `:2715`, `:2779`; `src/client/HudLayout.luau:340`.
- **Trigger:** enable the existing PRIS+ auto-dig option, aim at a mine block and press H/open the layout editor. Alternatively keep attacking while opening H or draw a bow from the editor.
- **Cause:** opening the editor calls `closeWindow()` and sets only `HudLayout.isEditing()`. `WindowInput` correctly blocks movement using both states, but digging, repeated melee, `onDig` and the `BowController` blocked callback test only `currentWindowKind`. The automatic dig expression continues independently of pointer events. Editor drag handles are Frames, whereas the custom mouse exclusion only recognizes GuiButtons and ScrollingFrames.
- **Consequence:** the player can keep mining/attacking while arranging controls, and input can affect gameplay beneath the editor. Eating, consumables and wheel selection already use the editing guard, making the mismatch especially clear.
- **Correction:** use one gameplay-input blocked predicate for windows and the editor, and cancel active mining/melee/bow state when either opens.
- **Verification:** auto-dig and held attack/bow must stop on H, no gameplay requests while dragging, normal input resumes after Done/Reset.

### UI-03 — P2: the effects render callback dereferences a missing character

- **Confidence:** high; explicit nil-safe handling immediately above is bypassed by one expression.
- **Location:** `src/client/EffectsHud.luau:281` (within the render binding beginning at line 252).
- **Trigger:** any rendered interval with `Players.LocalPlayer.Character == nil`, such as initial character loading or a character replacement/removal.
- **Cause:** `level()` safely handles a missing character, but the sprint multiplier directly calls `character:GetAttribute("Sprinting")`.
- **Consequence:** a client error repeats every rendered frame during that interval and the rest of the callback, including FOV restoration/interpolation, does not run. This is a transient lifecycle failure, not a claim of a permanent crash.
- **Correction:** guard the sprint attribute read and reset/decay the camera effects consistently when no character exists.
- **Verification:** remove/replace the character in an isolated QA client after a sprint/bow/hurt effect; verify zero callback errors and neutral FOV before the new character arrives.

### UI-04 — P2: gang chest paging silently retargets a picked-up stack

- **Confidence:** high; client selection and server page replacement have matching address semantics.
- **Locations:** `src/client/ChestWindow.luau:216`–`:220`, `:90`–`:100`, `:339`; `src/client/DragDrop.luau:39`, `:202`–`:224`; `src/server/Services/CaseService.luau:825`–`:831`.
- **Trigger:** put different items A/B in slot 1 on gang chest pages 1/2. Pick/tap A, turn to page 2 without cancelling the selection, then click an empty inventory slot.
- **Cause:** the held address contains only a container and slot index. Gang paging does not call `drag.Clear()`. The server changes `session.index` and replaces `profile.caseContents.gangChest`; the existing window refreshes in place, so the selected address now reads B. Ender-chest tabs already clear selection at line 160, showing the intended protection.
- **Consequence:** the next move acts on B rather than the item originally selected. If the equivalent new-page slot is empty the action silently cancels instead. No duplication or loss bypass is alleged.
- **Correction:** clear drag state before requesting a page change and again when the acknowledged page changes; preferably include a page/session identity in moves to reject stale requests.
- **Verification:** mouse and touch selection, partial stack, rapid page changes and page replacement by a server update.

### UI-05 — P2: auction still shrinks the desktop layout to unreadable phone text

- **Confidence:** high for the layout arithmetic; actual device readability and keyboard overlap still require acceptance.
- **Locations:** `src/client/AuctionWindow.luau:35`–`:39`, `:75`–`:83`, `:124`; `src/client/init.client.luau:638`–`:641`.
- **Trigger:** open the auction at a 390-pixel-wide portrait viewport.
- **Cause:** the auction remains 724×500 with a 196-pixel filter sidebar and ten columns. The common window fitter scales the whole window rather than reflowing its content. At width 390 the scale is at most `(390-20)/724 = 0.511`; its 14-pixel form text becomes approximately 7.15 pixels, 46-pixel slots become 23.5 pixels and 28-pixel buttons become 14.3 pixels high. At landscape 844×390 with a 58-pixel top inset, height similarly limits the scale to 0.64.
- **Consequence:** purchasing/listing/filtering remain technically reachable but use very small text and touch targets. The settings window's recent responsive layout does not fix the auction or other legacy fixed-size windows.
- **Correction:** compact/reflow the auction (fewer columns, scrolling filters/form, preserved font and control sizes) rather than lowering its uniform scale.
- **Verification:** native portrait/landscape phone, all four locales, filter entry and on-screen keyboard. The same common-fit mechanism should be checked in inventory/chests/location/exchange/artifact windows; this finding uses the auction as its reproducible example.

## Brightness and sensitivity investigation

The owner reported ineffective brightness during this audit and suspected mouse sensitivity. These are priority reports, but static evidence does not establish that either setting is ignored:

- `ProfileService.luau:867`–`:885` accepts the four numeric preference ranges, normalizes them and clones the settings table for profile delta replication. There is no setting-specific rate limiter dropping these requests.
- At the audited baseline, `SettingsWindow.luau:90`–`:94` updated its displayed value immediately while `PlayerPreferences.Apply()` ran on the server profile roundtrip. This produced a response delay; a focused working-tree change below removes that mismatch.
- `PlayerPreferences.luau:46`–`:53` creates a separate `PlayerBrightness` ColorCorrectionEffect with brightness `(value-1)*0.3`, thus -0.15 to +0.15 for the full setting range. `IndoorLighting` changes scene lighting and its own `VolumeTint`; no repository code was found that disables/overwrites `PlayerBrightness`.
- Mouse sensitivity is applied via `UserInputService.MouseDeltaSensitivity`; touch wraps the installed `CameraInput.getRotation`. The parent observed that installed camera code uses `InputObject.Delta`. That alone does **not** prove that the mouse property is ineffective: Roblox's [official source documentation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UserInputService.yaml#L213-L225) describes scaling mouse movement event deltas as well. Fake injection directly into CameraInput bypasses that engine layer and cannot settle the issue.
- Required evidence: same scene/camera rendered at brightness 50/100/150, actual native or virtual mouse movement with raw InputChanged deltas and final camera yaw at 50/100/200, and touch rotation on a real device. Confirm server storage and client property values alongside the visual/input result. Root owns this live QA and any resulting focused fix.

Follow-up after the owner clarified that the percentage changes but the picture does not (live evidence supplied by the parent agent):

- Normal `SetSetting` requests produced an enabled live correction with brightness -0.15/+0.15 at 50/150. The parent's subsequent **fixed-camera** screenshots conclusively showed the world changing between those values. Initial moving-camera screenshots and concurrent owner setting changes were not valid A/B evidence. The correction renderer is therefore working in this tested Studio client.
- Official [PostEffect documentation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/PostEffect.yaml#L9-L22) says some effects differ or do not render at low quality, and that post effects do not affect GUI objects. That generic caveat does not establish a defect in this client. [ColorCorrectionEffect documentation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ColorCorrectionEffect.yaml#L17-L25) confirms that multiple corrections compose. The rendering algorithm was retained after the positive fixed-camera result.
- The root's Studio mouse tool changed pointer position but emitted only zero input deltas. That test cannot establish real physical mouse sensitivity. Mouse scaling remains `MouseDeltaSensitivity`; no second multiplier was added.

Focused working-tree change requested after those results:

- `SettingsWindow.send()` now previews brightness/mouse/touch through `PlayerPreferences.Preview()` before sending the normal validated/persisted `SetSetting` request.
- Effects and percentage labels use the same pending value. Old profile patches still update the latest confirmed state but cannot overwrite the preview.
- Each setting reconciles five seconds after its latest local edit; superseded timers are inert. A matching value alone is deliberately not treated as a request acknowledgement, because an older update can match the latest value after a sequence such as 100→110→120→110. If the request is rejected/unanswered, both output and the open window roll back to the latest confirmed state. Reopening a window retains the pending preview; destroying it disconnects its rollback listener.
- `SettingsWindow.of()` remains authoritative/pure, so the normal profile render never feeds pending values back into acknowledgement state. Server validation/persistence, the brightness formula and camera scaling remain unchanged.
- `scripts/qa-settings-preview.luau` loads the actual preference module and real range validation with fake input/lighting/instance services and a deterministic clock. Its 17 checks cover immediate output, stale profile/label protection, rapid return to an earlier value, superseded timeout, latest-confirmed rollback, independent mouse/touch settings, unchanged mouse rotation multiplier, invalid inputs and one-time adapter setup. All 17 passed offline under Lune through a temporary Studio-object adapter; the harness itself runs in privileged Studio without `loadstring` and changes no real player state.
- Selene on both changed modules reports zero errors/warnings/parse errors; StyLua check on both modules plus the harness and `git diff --check` pass. Parent owns actual menu-click runtime verification and the full source build.

## Coverage and already-implemented safeguards

| Area | Inspected / result |
| --- | --- |
| First/third person, menus, pointer | `WindowInput`, `FirstPersonVisibility`, `FirstPersonHand`, `init.client`; menu pointer release, movement disable, camera restore and first-person body hiding are implemented. Bow visibility defect UI-01 remains. |
| Camera/hurt effects | `EffectsHud`, `CombatFeel`, `BowController`, `BowState`; roll is explicitly undone before camera control and hurt does not add pitch. Do not reopen the historic downward-drift bug without new evidence. UI-03 is a separate nil-character path. |
| Touch and HUD | `init.client`, `HudLayout`, `Sprint`; hold/drag distinction, focus-loss dig cancellation, menu grid, camera button left of hotbar, optional attack/sprint controls and jump proxy are present. HUD editor isolation defect UI-02 remains. Hybrid keyboard/touch switching and native multi-touch remain acceptance work. |
| Inventory/storage | `DragDrop`, `ChestWindow`, inventory builder, `SlotView`, `ItemTooltip`; drag module disconnects global connections on window destruction, clears on focus loss, supports partial/distributed/quick moves. Ender tabs clear selection; gang pages do not (UI-04). Transfer outcome correctness remains server review scope. |
| Settings | `SettingsWindow`, `PlayerPreferences`, `Preferences`, `ProfileService` setter, `IndoorLighting`, `PrisPerks`; six categories, icons, finite numeric ranges and four-language strings are present. Parent fixed-camera comparison confirmed rendered brightness. Immediate local preview is now implemented pending its live UI QA. |
| Damage/autosell feedback | `CombatFeel`, `EffectsHud`, `AutoSellFx`; server HitConfirm drives hit feedback, red area-sale text has exact 1.15 scale, stronger outline/ZIndex and +0.5s life; ordinary labels cannot evict all red labels. Visual acceptance remains separate. |
| Menu/auction/chat/cases | `MenuWindow`, `AuctionWindow`, `ChatWindow`, `ChatCommands`, `AncientRoulette`, `CasePreviewWindow`; auction query responses reject stale requests and disconnect update listeners on close. Roulette has owned cleanup/watchdog and does not replace a subsequently opened menu. No claim that profile/persistence auction semantics were fully audited here. |
| Body/held visuals | `HeldItem`, `ArmorVisual`, inventory preview; registries clear prior rigs, remove visuals and disconnect player listeners. Preview clones belong to a ViewportFrame WorldModel and reset transparency. Equipment glint is removed; intentional combat/roulette Highlights are not equipment-glow regressions. No confirmed duplicate-live-character defect found. |
| Localization | Offline static scan found 1,444 entries across Strings Part1–Part5; every parsed entry contains ru/en/es/fr. All 510 literal `T`/`t`/`Strings.t` client call sites resolve. Dynamic key construction, formatting correctness and actual clipping are not covered by that scan. |
| Lifecycle/performance | Window listener destruction paths sampled across all `*Window` files, plus body/held render registries. No new high-confidence unbounded listener leak identified. Full streaming re-entry, long-session memory and phone FPS remain runtime acceptance. |

## Remaining acceptance, not confirmed code defects

- Native phone gestures: simultaneous joystick + camera + dig/attack/eat, drag/split/double-tap/throw, real keyboard opening and orientation changes. Studio ForceMobile and injected taps do not certify these.
- Cursor/camera return after window sequences, death/respawn, text entry and engine/CoreGui menus in both camera modes.
- Actual mouse/touch rotation response on physical input and preview reconciliation under delayed profile updates; rendered brightness has a positive fixed-camera Studio comparison, as above.
- Sustained full multiplayer/mobile load, streaming in/out of avatars, items and mobs, repeated menu opening and memory/connection trends.
- Owner acceptance of first-person hand scale, hurt/sale text prominence, no duplicate character, equipment-glow removal and current category icons.

The focused settings-preview change above was applied in the working tree at the parent's request; UI-01–UI-05 remain audit findings. Findings and offline checks are not claims of completed native-phone acceptance.
