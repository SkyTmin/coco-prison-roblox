# Gameplay HUD defaults — 2026-11-03

> Superseded visual proposal: the owner rejected the overall arrangement after native screenshots and is manually arranging the HUD. Do not treat the rectangle/test passes below as visual acceptance, change other zones, or sync/restart while that arrangement is in progress. Copy the owner's saved positions only after they explicitly finish.

## Narrow bottom-edge follow-up (code only, not synced)

Removed the8px extra bottom margin from the hotbar; View and inventory now align with the same safe bottom on phone and desktop. Health/hunger/armor inherit the hotbar's movement. Attack, Jump, other zones and saved custom positions remain unchanged. Actual-source layout checks now4987 PASS; scoped Selene0/0 and diff check clean. No Studio/profile operation was performed.

Roblox documents [Camera.ViewportSize](https://create.roblox.com/docs/reference/engine/classes/Camera#ViewportSize) as device-safe dimensions, including the top bar area but excluding device cutouts. [ScreenGui.IgnoreGuiInset](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#IgnoreGuiInset) selects DeviceSafeInsets when enabled from the default mode. Therefore the observed GUI origin−58 is a coordinate offset, not58px of spare bottom room; this change keeps the existing device-safe bounds/clipping and adds no compensating positive inset.

Scope: gameplay overlays and controls only. Full inventory, upgrade, menu and other window layouts were not changed. No real profile was reset by this agent; the parent reset only the owner's desktop/mobile HUD layout through the ordinary settings remote.

## Corrected behavior

- Phone defaults use physical 44px action targets and a 70px native Roblox jump button. View stays left of the hotbar, inventory right. The optional attack and sprint controls retain their previous hidden defaults, with non-overlapping reserved positions when enabled. The inventory opener uses the existing inventory icon.
- Nine hotbar slots use32–36px on640px+ landscape screens; the extreme568px fallback uses28px. Health/hunger retain readable numeric bars; the geometry reserves the complete armor/health band60px above the hotbar.
- Requirements stay in an explicit left-hand lane. Default width210px (180 on narrow landscape),20px content rows,18px genuine item icons and12px text; excess onboarding instructions remain accessible through the existing vertical scroll. Saved manual position/scale still takes precedence.
- Automatic obstacle collection now uses visible ThumbstickStart/ThumbstickEnd rather than the382×287px invisible DynamicThumbstickFrame. It no longer hides the requirements card because of the input capture region.
- Phone stats retain12px text at base scale1, using six compact icon/value rows. Desktop retains labels and the title. Requirements sit below the desktop menu buttons and boosters below the requirements lane.
- All transient/critical notices share a published lane in GuiObject.AbsolutePosition coordinates. On the observed705×338 A06, logical y66 plus PrisonHud origin−58 publishes y8. Consumers must not apply GuiInset twice.
- HudNotices gives critical combat cards priority during gameplay; menu results bypass that priority. The queue holds at most8 waiting messages, each expires20s after creation and gets3s of visible time. HudToastActive follows actual visibility, including editor/settings transitions. The noninteractive toast draws above full windows so menu errors remain visible.

Coordinated modules owned by other agents: AuctionBanner (shared lane, pausing), BossHud/WarzoneHud (critical priority), FavoriteCard (full-menu-only), BoosterHud/EffectsHud (bounded compact summaries). Those modules have separate focused tests and reports: compact Booster/Effects107 checks and Auction73 checks passed. This document does not claim their pending native acceptance.

## Validation

- scripts/qa-hud-defaults-offline.luau:4876 assertions passed against the actual HudDefaults module, the actual init.client updateLayout closure and actual HudLayout.apply. Cases include568/600/639/640/667/705/750/844/874/1024/1280 widths,0/58/64px insets; pairwise simultaneous landscape rectangles include optional controls, requirements, stats, booster/effect reservations, notification, full meter band and observed74px joystick. Saved coordinate/scale/anchor regressions pass. Whole client source compiles within Luau register limits.
- scripts/qa-tutorial-panel-offline.luau:183 assertions passed, actual Config/Strings/Panel in four locales, including dense rows, scroll access and actual visible-thumbstick obstacle conversion.
- scripts/qa-hud-toasts-offline.luau:12 actual-module checks passed for bounded queue, expiry, pause/resume, menu bypass, settings/editor and loading visibility.
- Existing qa-hint-layout-offline:35 passed (actual handlers and simulated durable settings/reload); qa-inventory-layout-offline:524 passed.
- Independent economy-agent review executed mobile→desktop→mobile updateLayout and16 additional landscape rectangle matrices without new findings.
- Scoped Selene:0 errors/warnings; formatting and diff checks performed.

These are deterministic source/boundary tests, not native pixel rendering or physical touch proof. The primary supported game orientation is landscape. Portrait fallback is bounded but has not been accepted for simultaneous play. Parent performs native iPhone7/A06/iPhone17Pro/iPad/PC screenshots, visible hit rectangles, and simultaneous notifications/boosts/effects acceptance. Full-menu layouts and persisted customizations must remain unchanged.
