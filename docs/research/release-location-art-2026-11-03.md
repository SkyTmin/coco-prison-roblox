# Location illustrations — 03 November 2026

Owner requested one consistent illustration style for every location, with very close resemblance to the built game. Three art agents worked on disjoint sets of nine locations; the parent integrated the three original locations and reviewed stricter replacements.

- **30 final illustrations**, covering every id in `Config.locations`, saved in `assets/previews` and uploaded through Studio MCP. Asset ids are in `assets/previews/ids.json`; generated `Config/previews.json` consumes them.
- [Review gallery](../../assets/previews/release-art-gallery.html): searchable cards, actual-game / illustration switch and full-size viewing. [Final manifest](../../assets/previews/release-art-final-manifest.json) gives each exact filename, factual screenshot, dimensions and prompt manifest.
- Built-in imagegen used exclusively. Prompts and image roles are recorded in `release-art-group-a.json`, `release-art-group-b.json`, `release-art-group-c.json`, and `release-art-root-v2.json` beside the assets. Each asset had its own generation/edit call. Final PNGs are direct copies of generated outputs; no external rescaling or painting.
- The factual screenshots control camera, map footprint, mining area, landmarks, materials and palette. The Ghetto/Courtyards original art supplies rendering style only. Revised original locations use `-v2.png`; the earlier files remain as style-reference provenance.
- Reviews rejected added cars, extra mines, an invented boat and misplaced room furniture. Final images preserve the recognizable in-game layout. Small texture details are interpreted; the small source image of Courtyards limits exact playground-detail matching.
- Native aspect ratios are retained. The gallery displays full images without cropping; the client location-preview renderer uses `Fit` so wide Ghetto and gang-interior landmarks remain visible.

Validation: 30 unique location ids; all final files/references present; 30 successful upload ids; generated configuration rebuilt; gallery's 95 local links and inline JavaScript syntax checked. Roblox moderation/content loading and actual menu rendering are separate live checks, not implied by upload success. Publishing was not performed.

Live follow-up: [typed client preload evidence](release-art-preload-2026-11-03.json) confirms30/30 configured illustration assets return Success. A control comparison found that raw string-ID requests incorrectly fail for both old working icons and new images, whereas ImageLabel requests succeed. The loading screen now uses typed instances. Gallery search, actual-reference toggle and full-image modal were checked interactively. In-game menu composition remains a separate visual acceptance step.
