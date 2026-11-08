# Gameplay notification lane — 2026-11-03

Scope: bounded audit of ordinary toast/boost placement and production changes to `AuctionBanner.luau`, `BoosterHud.luau` and the HUD-render prefix of `EffectsHud.luau`. UI agent owns the main HUD/default layout/toast publisher; economy agent owns BossHud/WarzoneHud. No menu, purchase behavior, Studio, operating-system input, real announcement or resource mutation was performed here.

## Before and after

The previous mobile toast occupied a centered up-to-520×66 rectangle at Y12; the separate auction ScreenGui placed its 400×52 banner at Y4. Those rectangles could cover each other, while boosters began at Y64. Each module chose coordinates independently. The auction's fixed eight-second timeout also continued while any other UI covered it.

AuctionBanner now consumes the coordinated notification rectangle in **raw GuiObject.AbsolutePosition coordinates**, intersects it only with its own CoreUISafeInsets GUI bounds, and converts back to local coordinates. Native A06 clarified the distinction: producer GUI origin `(0,−58)` plus local Y66 publishes **raw Y8**, not Y66. The separate physical VirtualInput conversion is irrelevant to layout. The initial implementation incorrectly clamped raw Y8 to GuiInset58; that was corrected before final acceptance and is covered explicitly for a consumer origin of both−58 and0. No second GuiInset is added. The UI agent publishes the lane so surrounding requirement/boost/control panels can reserve it. Missing metadata falls back to this GUI's own top+4; an unusable lane narrower than170 or shorter than52 hides and pauses the ad instead of spilling into neighboring controls.

At a compact 210–260px width, the card retains its seller, item, count, enchantments and price in three bounded rows with 12–14px fonts and truncation. The icon becomes28px; the redundant Open hint is omitted. The close target stays44×44, with a separate open target ending before it. Width is capped at400 and height remains52. Entrance/exit sliding through neighboring HUD is removed. Only the card's targets consume touches; there is no fullscreen input surface.

## Shared contract

All attributes are on `Players.LocalPlayer`.

| Attributes | Owner / behavior |
| --- | --- |
| `HudNotificationX`, `HudNotificationY`, `HudNotificationWidth`, `HudNotificationHeight` | Main HUD publishes its reserved rectangle in raw `GuiObject.AbsolutePosition` pixels. Auction converts using its own `AbsolutePosition`; these are not physical input pixels. |
| `HudBossActive` | BossHud sets actual visibility; highest-priority shared-lane notice. |
| `HudWarzoneActive` | WarzoneHud sets actual visibility, yielding to the boss. |
| `HudToastActive` | Main HUD publishes actual ordinary-toast visibility; ordinary toasts yield to critical notices. |
| `HudAuctionActive` | AuctionBanner publishes true only while its ad is visible. |
| `LoadingBlocked` | Existing initial-loading guard; auctions remain hidden while true. |
| `HudGameplayOpen` | Auction pauses while false (menu/editor/loading); its separate announcement-offer dialog is unchanged. |

Auction display pauses immediately while any higher-priority flag is true. Hidden time does not consume the existing eight visible seconds. The same ad resumes before the next queued ad, preserving the existing queue bound and item-search action. Listener connections are removed after each card. The auction's payment/announcement-offer dialog remains unchanged and outside this gameplay-HUD task.

## Compact boosters and effects

Both factories read their frame's `Compact` attribute, which the main layout sets for phones and short desktops. BoosterHud uses one **100×44** storage button with the first running boost's icon, multiplier and timer plus the total active count; all six desktop rows are hidden in this mode. Zero boosts and the existing hideBoosters setting hide the entire frame. Returning to desktop restores its200px row width and automatic row height.

EffectsHud uses a **132×44** strip with two44px targets, harmful effects first, followed by a44px `+N` target. The overflow action cycles through the remaining effects one per tap, showing `index/N`, existing localized name, level and duration in the ordinary toast. This agreed pagination keeps all details reachable without clipping a dozen lines in the52px toast or overfilling its queue. There is no new menu or new translation key. Zero effects hide the frame; HUD editing retains the existing sample icons. Desktop restores264px width and wraps each beneficial/harmful class after six effects. Everything from the `-- screen effects` marker onward, including camera and combat feedback, was left untouched; the parent's native preview may clone the real prefix and return its frame without any production QA export.

Latest owner clarification: the permanent injection (`NeedsFree` / `needs_free`) has no HUD display. EffectsHud filters it from its local presentation list before layout, visible-icon selection and overflow counting in both modes. The character attribute, Shared.Effects catalog and mechanics remain unchanged. Injection alone leaves the effect HUD hidden; injection plus two ordinary effects shows both ordinary icons without `+1`.

## Verification

`scripts/qa-hud-notifications-offline.luau`: **73 PASS** against the actual complete AuctionBanner module, with deterministic GUI geometry/signals/clock. Cases include exact A06 rawY8 with different producer/consumer origins and210px lane, 320px/390px portraits, narrow landscape, a landscape cutout and desktop; bounded readable text and44px close/open targets; missing/late lane metadata; toast present before and during an ad; retained visible duration; ordered queue advancement; Open/Close behavior; menu/loading/boss/Warzone priority; too-small lanes and live rotation.

`scripts/qa-compact-status-hud-offline.luau`: **110 PASS** against actual BoosterHud and the actual EffectsHud render prefix. It uses fake profiles/character attributes plus actual Shared.Effects and existing four-language catalogs. Six boosters fit one tile, the existing storage action is invoked once, all18 displayed effects render within compact/desktop bounds, the16 hidden effects remain reachable in every locale, rotation restores desktop geometry, and empty/settings-hidden/editor cases behave correctly. Eight focused injection checks prove hidden display/counting in both modes while the actual Shared.Effects mechanical query still returns its active level. Camera hooks and real character attributes are not executed or changed.

Selene reports zero errors/warnings; StyLua and the production file's scoped diff-whitespace check pass. These are actual-source logic/geometry tests with mocked engine layout and TextService, not native font rendering, finger input or an acceptance of the entire HUD. Parent native QA should inspect A06 and portrait with a boss/Warzone notice, ordinary toast, active boosts and a queued announcement together; confirm exactly one notice is visible, the ad resumes afterward, text stays legible and the44px close target works. Publish the shared lane and priority flags with the sibling changes before evaluating overlap in Play.
