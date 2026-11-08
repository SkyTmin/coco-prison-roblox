# Owner-arranged HUD defaults — 2026-11-03

This supersedes the rejected autonomous arrangement documented in release-hud-defaults-2026-11-03.md. The reference is the owner's actual saved750×381 layout in owner-hud-layout-2026-11-03.json; this change is a translation of that arrangement, not a fresh design.

## Changes

- Default menu is on the left at the owner's chosen upper row, with the booster summary immediately beside it. Requirements sit beneath at approximately(25,117) and retain the chosen60% scale. Effects retain70% scale. Default user size is separate from base scaling, so saved0.6 and0.7 values are never multiplied twice.
- Restored the Scoreboard title and all six existing localized labels. On phones it is190×116, with12px title and11px labels/values in distinct columns. Long values truncate within their column; hover/touch reveals the full rich-text value.
- A saved right-side stats position is clamped on display after its width increases. Effects that would overlap those restored labels move beneath the stats. Neither adjustment mutates the saved profile.
- Hotbar remains flush with the device-safe bottom. View/inventory defaults align with that edge; saved controls already within24px of that edge dock to it while retaining X. Higher custom placements remain untouched.
- The touch menu grid now chooses its opening side from the actual menu position and clamps within the viewport. The owner's left menu opens right; a saved right menu opens left.
- Boss placement and NeedsFree icon removal are separate agents' changes and were not edited here. No Studio, profile writes, sync, restart, commit or publish was performed by this agent.

## Verification

scripts/qa-hud-defaults-offline.luau now focuses on100 actual-source assertions: actual HudDefaults, init.client updateLayout and HudLayout, the exact saved owner JSON, five landscape screens, restored label/value columns, top-right clamp, default versus saved scales, menu direction, bottom docking and immutable saved data. Whole init.client compiles within Luau register limits.

Existing qa-hint-layout-offline35 actual-handler/profile-roundtrip assertions still pass. Scoped Selene0/0, StyLua and git diff checks pass. Native rendering, text readability and final owner acceptance are explicitly pending parent QA; deterministic bounds do not establish visual acceptance.
