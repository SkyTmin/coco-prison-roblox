--!nocheck
-- Builds the Рай, level 49, PvP, the seventh and last sky mine [меню]. Mine: гриб (красный) 100 % [меню: mine-shares]
-- — the scarlet heart in front of the white rose, the only saturated spot of the level. No boss: a summit (the
-- innermost tier by the pillar of light) instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/paradise/concept-v2.webp — a huge white ROSE of concentric tiers like Doré's Empyrean on a
-- round island over shining clouds: twelve rays of white steps climb the tiers to the crown — a ring of slender white
-- spires with gold banners round the pillar of light; thrones, candles and red flowers on the tiers; angel statues with
-- raised wings in a ring; the golden river round the rose (water under yellow glass, walked on); the mine of red
-- mushroom blocks in a white pit in front with a yellow-and-white buyer stall; white birches with white wool crowns,
-- a marble peristyle with vines and lanterns, banners of birds of paradise; floating islets with gazebos, fountains and
-- blue waterfalls joined by white bridges; end rod beams pointing up. Almost monochrome — white concrete, quartz,
-- calcite, snow, white wool differ by texture; gold accents; brightest level of the game.
-- Ideas: docs/research/location-ideas.md («Рай (49)»).
-- Generated: node scripts/bundle-location.mjs paradise → scripts/build-paradise.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Paradise.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the plaza; the arrival is in the south; mirror-symmetric in x):
--   island        a disc centre (0, 0), r ≈ 236, ragged
--   the ROSE      centre (0, -84): the golden river r 108..120 (bed y -4, water to y -0.8, yellow glass on top at
--                 y 0 — walkable); tiers rising one block each: y 4 inside r 108, 8 < 92, 12 < 76, 16 < 60, 20 < 44,
--                 the crown y 24 inside r 28 (the SUMMIT by the pillar of light at the centre); 12 rays of steps
--   mine          32×12×32 blocks, hole x -64..64, z 60..188 (centre 0, 124)
--   arrival       (0, 0, 214) facing north to the pit; the buyer's stall west of it at (-36, 216)
--   islets        W/E (±296, 0) r 40; NW/NE (±226, -176) r 32; SW/SE (±226, 176) r 32; bridges at y 0 (BRIDGES)
--   zones         ROSE part: d < 124 from the rose centre (the river, the tiers, the rays, the crown, the angels);
--                 PLAZA part: the rest of the main island (round the pit, the peristyle, birches, the south edge);
--                 SKY part: the islets and bridges, under the islands, floating islets, clouds
local LOC = "paradise"
local ROOT_NAME = "Paradise"
local BX, BY, BZ = 24400, 34500, 0 -- floor 15 [docs/research/floor-brief.md]
local SEED = 2026102649
