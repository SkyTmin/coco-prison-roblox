# Startup and tutorial follow-up — 2026-11-03

The owner accepted the manually arranged HUD, then requested automatic startup language, a loading spinner, menus above requirements, and a stable block marker.

- Automatic language uses the Roblox account locale, normalizes ru/en/es/fr regional variants, and falls back to English for other languages. Stored manual selections win. Automatic selection stays session-only and reaches server messages through a validated remote, with one retry after the initial loaded profile. Native owner session reported account en-us, automatic en, stored manual ru, effective ru. The early loader used account language, then switched to the saved manual language when the profile arrived.
- The existing loading screen now has a 28px amber circle made from 12 frames. It rotates in the existing render callback, requires no image download, pauses on failure, and disappears with the loading screen. Native observation recorded 21 samples, changing rotation, in-bounds geometry and normal completion. Readiness and retry gates remain unchanged.
- The phone menu has a higher root ZIndex than the requirements panel. Opening it immediately hides the requirements panel; TutorialGuide keeps it hidden until the menu closes. Native rendering state confirmed the layer, hidden card, visible grid and returning card. VirtualInput clicks did not activate the control in this session, so these are rendering/state checks, not a passed physical-touch test.
- A selected mining target is retained through camera rotation, walking, temporary occlusion and newly exposed closer blocks. It is released when removed/hidden/streamed out, its own requirement is satisfied, or the tutorial context changes. Completing another resource requirement does not release a still-needed target. New target selection retains the previous nearest/forward/exposed-block rules.

Validation: 43 locale checks, 98 loading checks, 39 profile persistence checks, 6 loader peer regressions and 48 actual-source target selection cases passed. Selene, StyLua and Rojo build passed. Native startup observer was removed from the edit map; a clean final Play is running in the confirmed Katorga place with creative restored. No progress reset or publication occurred. Existing asset203785492 mismatch is still reported by Roblox and is unrelated to these changes.

Evidence: release-startup-and-target-2026-11-03.json. Broader release acceptance is not implied by this focused follow-up.

Final Studio preview remains the owner's iPhone17Pro emulator. Client-only ForceMobile=true is retained because native VirtualInput exposes a keyboard; no production Workspace attribute or input-mode logic was changed. The override disappears at the next Play restart.
