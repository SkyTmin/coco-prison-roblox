--!nocheck
-- Builds the Церковь, level 39, PvP, the second sky mine [меню]. «Тихая церковь над облаками. Под её сводами добывают
-- редкие светлые породы» [меню]. Mine: глина 100 % [меню: mine-shares]. No boss: a summit (the belfry with the bell)
-- instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/church/concept-v2.webp — one big floating island of white stone over the clouds: in the
-- south a paved square with the mine of clay in a brick-walled pit behind a fence, a buyer under a blue-and-white
-- awning, lantern pillars with blue banners with a white cross; a wide stair up to the white gothic cathedral in the
-- north (Sainte-Chapelle: between the buttresses stained glass from the floor to the vault, blue, cyan and white
-- with a little gold; a rose window over the portal; a steep dark slate roof with pinnacles; inside a blue-and-white
-- mosaic floor, pews, an altar with candles, an organ, a pulpit and a lectern); the bell tower east of the facade with
-- a big bell in an open belfry (the SUMMIT) under a slate spire; graveyards with crosses, stone brick walls, iron
-- fences and cypresses on both sides; flying buttresses, gargoyles; waterfalls off the edges; small floating islets
-- with graves, an arch and a ruined chapel, two of them joined by arched stone bridges; white wool clouds. Noon.
-- Ideas: docs/research/location-ideas.md («Церковь (39)»).
-- Generated: node scripts/bundle-location.mjs church → scripts/build-church.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Church.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the ground; the arrival is in the south):
--   island        an ellipse centre (0, -10), radii 190 (x) and 222 (z), ragged; y 0
--   mine          32×12×32 blocks, hole x -64..64, z 6..134 (centre 0, 70); brick pit walls
--   arrival       (0, 0, 164) facing north to the pit; the buyer's stall west of it at (-32, 168)
--   square        paved x -104..104, z -44..196 round the pit (the PLAZA)
--   cathedral     the CHURCH x -40..40, z -190..-70 (nave floor y 8 on a 2-block plinth, the portal on the south
--                 face at x -12..12), steps z -70..-48 down to the square; the BELL TOWER x 48..76, z -98..-70 to
--                 ≈ y 180, the belfry floor (the SUMMIT) at y 104 reached by a stair inside the tower
--   walks         WEST x -180..-104, z -24..-4 and EAST x 104..180, z -24..-4 to the bridges
--   islets        WEST (-266, -14) r 34 and EAST (266, -14) r 34 at y 0, joined by arched stone BRIDGES
--                 x -236..-176 and 176..236, z -22..-6
--   zones         CHURCH part: x -110..110, z < -40 (the cathedral, the tower, the steps); PLAZA part: |x| < 110,
--                 z ≥ -40 (the square round the pit); YARD part: |x| ≥ 110 (the graveyards), the walks, the
--                 bridges, the islets, the waterfalls, the floating islets, the clouds, under the island
local LOC = "church"
local ROOT_NAME = "Church"
local BX, BY, BZ = 19400, 27000, 0 -- floor 10 [docs/research/floor-brief.md]
local SEED = 2026102639
