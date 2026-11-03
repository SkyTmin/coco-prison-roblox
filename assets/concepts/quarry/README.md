# Quarry — accepted open-air concept

Owner accepted `accepted-open-air-2026-11-03.png` on 03 November 2026 and requested the closest practical in-game match. It supersedes every cave and earlier open-air proposal in this session.

Generated with built-in Codex `image_gen`. The exact final prompt is `accepted-open-air.prompt.txt`. Style reference: `assets/screenshots/style-ref-mountain-foot.jpg`. Prompt structure follows Claude's checked-in `docs/research/location-prompts.json` and `scripts/build-location-prompts.mjs`: location-specific districts, full-block game style and player scale, gameplay requirements, and four consistent views.

Binding owner constraints: unchanged 40 × 40 block excavation, depth 16; expand the surrounding location instead. Fully open sky, readable daylight, substantial traversable terraces, generous circulation, detailed western loading yard and hoist, shared eastern Basalt Guardian arena. No cave roof, floor gaps, cramped edge paths or decorative objects in the mining volume.

Implementation: `scripts/build-quarry.luau`. Uses the same mine IDs, composition, economy, boss ID and combat radius. The buyer is near arrival, to its right as in the accepted image. The map uses an independent altitude to keep other locations off the open horizon. Exact terrain dimensions/elevations are implementation decisions; generated art is a visual guide, not a reliable block-count specification.

The earlier `concept-v3-*` image is a rejected historical cave proposal, not an implementation target. Live visual/geometry validation is recorded separately from player interaction and boss combat QA.
