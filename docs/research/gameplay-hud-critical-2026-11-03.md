# Critical gameplay HUD notices — 2026-11-03

Owner scope: responsive default gameplay HUD; preserve full menu layouts and reticle damage/autosell feedback.

## Fix

`BossHud` previously forced a 340×46 bar at centered y4 every heartbeat: it extended outside a 320px viewport. `WarzoneHud` occupied 90% of the screen width at y54–104, intersecting the new upper HUD lanes. Both now consume the shared notification rectangle without changing boss proximity, health, capture-state or world-board behavior.

Priority is Boss → Warzone → ordinary toast → auction announcement. The two critical modules own separate `HudBossActive` and `HudWarzoneActive` attributes. A newly visible boss immediately hides an existing Warzone hint, including between its 250ms refreshes. An eligible Warzone hint resumes after the boss disappears. `HudGameplayOpen == false` immediately hides both and clears both flags, so menu actions can show errors/success messages near a live boss. Toast/Auction queue handling belongs to the UI/world agents.

## Coordinate contract

`HudNotificationX/Y` are **raw `GuiObject.AbsolutePosition` coordinates**, not OS/window/device pixels. `HudNotificationWidth/Height` are rectangle dimensions in the same unscaled pixel units. Consumers subtract their own ScreenGui `AbsolutePosition` to obtain local offsets. They must not add or clamp to `GetGuiInset()` a second time.

Observed A06 coordinate example: PrisonHud origin `(0, -58)` plus local lane `(236, 66)` publishes `(236, 8)`. Auction's CoreUISafeInsets origin `(0, 0)` consumes local `(236, 8)`. Native VirtualInput conversion separately adds the 58px top inset, producing device y66. That input conversion is not part of the HUD attribute contract.

## Verification and limits

`scripts/qa-critical-hud-offline.luau` executes actual BossHud/WarzoneHud source with isolated GUI, player, world-state and clock boundaries: **34 checks pass**. Coverage includes actual HP text, near/floor eligibility, immediate priority preemption, captured-point release, menu hide/resume, disabled GUI flags, exact A06 negative-origin conversion, widths 320/568/705/812/1280 and pre-layout fallback. Scoped Selene, StyLua and diff whitespace checks pass.

These checks do not prove native text fitting, touch usability or rendered GUI safe-area behavior. Root's native HUD observer/near-boss run remains required, including concurrent requirements, stats, six boosters, twelve effects, toast and auction. The read-only review also sent UI the measured 568×320 classification, portrait overlap, actual armor-width and native Jump proxy integration hazards; final HUD-default acceptance depends on the UI agent's completed geometry and integration tests.

Final UI checkpoint independently reran `qa-hud-defaults-offline.luau`: **4,876 checks pass**. An additional isolated invocation of its actual `updateLayout` closure verified mobile→desktop→mobile View/hotbar/Effects anchor behavior and the desktop View right-edge formula. Sixteen landscape geometry matrices (568/600/639/640/640×360/705/812/1024 widths with 58/64px insets) passed independent pairwise overlap/bounds checks. Portrait remains bounds-only fallback under the root's landscape-only acceptance decision. Actual compact Booster/Effects child rendering was still being completed by the world agent at this checkpoint; rectangle tests alone cannot validate those populations.

## Automatic favorite promotion

Root extended the narrow scope to `FavoriteCard`: its 360×128 automatic card at y64 otherwise covers gameplay for 40 seconds. It now starts only with explicit `HudMenuOpen == true`, excluding loading/editor states. Closing the menu or entering loading hides it immediately; reopening resumes the same card. Menu action toasts take priority over the promotion. The existing 40-second allowance counts visible time, and once-per-session behavior, dimensions, buttons, favorite prompt result and `Favorite` response persistence remain intact.

`scripts/qa-favorite-hud-offline.luau` runs the actual module against fake clock/GUI/prompt/remotes: **33 checks pass**, including delayed eligibility, loading/editor gates, immediate hide/resume, toast priority, 40 visible seconds, no repeated session popup, and Later/success/cancel/API-error response paths. No real Roblox prompt or favorite mutation was invoked. Native rendering remains pending with the root.
