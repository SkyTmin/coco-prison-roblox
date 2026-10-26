--!nocheck
-- Builds the Врата, level 47, PvP, the sixth sky mine [меню]. Mine: гладкий песчаник 100 % [меню: mine-shares] — the
-- paved parade square in front of the gates. No boss: a summit (the top of the steps at the open gates) instead of an
-- arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/gate/concept-v2.webp — a strictly symmetric island on one axis over a sea of clouds: the
-- arrival in the south, the mine of smooth sandstone in a sandstone pit, then the road of gold under yellow glass
-- («золото как стекло») between rows of torch pylons shrinking toward the gates (forced perspective) and banners of the
-- 12 tribes, the great stair up to the terrace and the PEARLY GATES — an arch of white quartz, calcite-white and gold
-- with pearl-white leaves standing open, set in a wall of «jasper» (prismarine, dark prismarine, white quartz
-- stripes), iron-and-gold gate bars, nothing but light beyond them and a beacon beam rising behind; two giant guardian
-- angels with spears and halos on the sides; the gatekeeper's lectern with a book; 12 foundation stones of different
-- colours; fountains and blue-glass waterfalls down the terrace; satellite islets with pylons and fountains joined by
-- bridges; cypress-like trees; cloud steps; a yellow-and-white buyer stall. Bright white noon.
-- Ideas: docs/research/location-ideas.md («Врата (47)»).
-- Generated: node scripts/bundle-location.mjs gate → scripts/build-gate.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Gate.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the square; the arrival is in the south; mirror-symmetric in x):
--   island        a superellipse centre (0, -20), half-axes 170 × 210 (z -230..190), ragged symmetrically
--   mine          32×12×32 blocks, hole x -64..64, z 6..134 (centre 0, 70)
--   arrival       (0, 0, 162) facing north to the pit; the buyer's stall west of it at (-34, 166)
--   ROAD          the golden road x -12..12 from the pit's north side (z -2) to the great stair (z -70), y 0
--   STAIR         x -20..20, z -118..-70, y 0 → 24 (the great stair to the gates)
--   TERRACE       |x| ≤ 120, z ≤ -118 at y 24 (the SUMMIT: the top of the steps at the gates)
--   GATE          the arch x -24..24 in the jasper wall x -112..112, z -164..-156, up to ≈ y 100; beyond it light
--                 (z -164..-230) and the beacon beam at (0, -196); the guardian angels at x ±48, z -140
--   islets        WEST_A (-240, 60) r 40, EAST_A (240, 60) r 40, WEST_B (-216, -120) r 32, EAST_B (216, -120) r 32,
--                 bridges at y 0 (BRIDGES)
--   zones         GATE part: |x| ≤ 130, z < -66 (the stair, the terrace, the wall and the gates, the angels, the light
--                 beyond); SQUARE part: the rest of the main island (round the pit, the road, the pylons, the banners,
--                 the fountains, the south edge); SKY part: the islets and bridges, under the islands, clouds
local LOC = "gate"
local ROOT_NAME = "Gate"
local BX, BY, BZ = 23400, 33000, 0 -- floor 14 [docs/research/floor-brief.md]
local SEED = 2026102647
