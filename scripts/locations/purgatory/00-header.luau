--!nocheck
-- Builds the Чистилище, level 41, PvP, the third sky mine [меню]. «Чистилище, где души ждут своего часа. Шахта для
-- тех, кто готов к долгому труду» [меню]. Mine: резной песчаник 100 % [меню: mine-shares]. No boss: a summit (the
-- plaza with the angel) instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/purgatory/concept-v2.webp — a round sandstone mountain of 7 terraces (Dante) on a floating
-- island in a hazy orange sunset: red sandstone at the foot → sandstone → smooth/cut sandstone at the top, terrace
-- walls with cut sandstone edges, fences and overhangs; at the foot in the south a bay with the mine of chiseled
-- sandstone where pale translucent souls haul stones, a buyer under a red-and-white awning, giant hourglasses of
-- glass and sand in wooden frames; on the bay's back wall 7 carved relief slabs (one per sin); a zigzag stairway with
-- fountains and a water channel on the landings (Bom Jesus do Monte) up the wall; obelisks with red banners, braziers
-- of fire and blue soul fire, cypresses, dead orange bushes, decorated pots, benches, queues of souls waiting; on top
-- the SUMMIT plaza with a red-and-white checkered floor, a gate with three steps, braziers and the great angel statue
-- with golden halo and wings. Melancholic and quiet.
-- Ideas: docs/research/location-ideas.md («Чистилище (41)»).
-- Generated: node scripts/bundle-location.mjs purgatory → scripts/build-purgatory.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Purgatory.
--
-- THE PLAN (local studs; +X east, +Z south; the arrival is in the south):
--   island        a disc centre (0, 10), r ≈ 220, ragged
--   terraces      concentric round PEAK (0, -80): level L = the number of RINGS {200, 168, 138, 110, 84, 50} the
--                 distance d is inside; ground y = 8 L (L0 y 0 … L6 y 48 = the summit plaza, d < 50); quantised to
--                 the core's 8-stud cells (cellY gives the ground of any point)
--   the BAY       x -92..92, z ≥ -10 is cut down to L0 (y 0): the mine, the arrival, the buyer; its north edge is the
--                 terrace wall (40 high at x 0, 24 at x ±92) with the 7 relief slabs
--   mine          32×12×32 blocks, hole x -64..64, z 46..174 (centre 0, 110)
--   arrival       (0, 0, 204) facing north to the pit; the buyer's stall west of it at (-34, 200)
--   ZIGZAG        x -52..52, z -10..34 on the bay floor: the zigzag stair with fountains up the bay wall from y 0 to
--                 the L5 terrace (y 40) at z -10; MAIN_UP x -10..10, z -34..-10: one flight on to the summit (y 48)
--   ring stairs   16 wide, at the east (x = +r), west (x = -r) and north (z = -80 - r) crossing of the rings r 138, 110,
--                 84, 50 where on the island (MOUNT part builds them); between L0, L1 and L2 the RIM part places its own
--   zones         BAY part: the bay, ZIGZAG and MAIN_UP; MOUNT part: d < 138 outside the bay (terraces L3..L6, the
--                 summit, the angel, the fixed ring stairs); RIM part: d ≥ 138 outside the bay (L0..L2), under the
--                 island, the sky
local LOC = "purgatory"
local ROOT_NAME = "Purgatory"
local BX, BY, BZ = 20400, 28500, 0 -- floor 11 [docs/research/floor-brief.md]
local SEED = 2026102641
