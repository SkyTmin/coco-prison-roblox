--!nocheck
-- Builds the Херувимы, level 45, PvP, the fifth sky mine [меню]. «Обитель херувимов, сияющая золотом. Здесь копают
-- только самые упорные» [меню]. Mine: снег 100 % [меню: mine-shares] — a cloud field in the middle of the rings. No
-- boss: a summit (the gallery under the dome) instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/cherubim/concept-v2.webp — a round island of gold and white over the clouds inside giant
-- tilted golden rings («колесо в колесе») with eye-like observers along them and lanterns hanging under them; a
-- checkered gold-and-white plaza round the mine of snow in a stone pit; a buyer under a gold-and-white awning; trumpet
-- angel statues with halos and wings, harps of chains and iron bars, gold lantern posts with banners; in the north the
-- domed ROTUNDA (white columns, gold arches, a ribbed gold dome with windows, four six-winged cherubs on the dome, a
-- halo of gold with end rods above) — inside a checkered floor, golden piers with winged angels, chandeliers, the ark
-- with two cherubs on its lid on a stepped dais, and the GALLERY under the dome (the SUMMIT); small gold-domed
-- pavilions on islets east and west joined by bridges; a golden stair-causeway to the south; cloud puffs. Golden hour.
-- Ideas: docs/research/location-ideas.md («Херувимы (45)»).
-- Generated: node scripts/bundle-location.mjs cherubim → scripts/build-cherubim.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Cherubim.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the plaza; the arrival is in the south):
--   island        a disc centre (0, 0), r ≈ 184, ragged; the whole top paved (gold / white checker)
--   mine          32×12×32 blocks, hole x -64..64, z -4..124 (centre 0, 60)
--   arrival       (0, 0, 152) facing north to the pit; the buyer's stall east of it at (34, 156)
--   ROTUNDA       centre (0, -112), r 44, floor y 8 on a plinth with steps on the south (z -68..-56), the dome to
--                 ≈ y 120; the GALLERY (the SUMMIT) round the inside at y 48 (r 34..44), stairs up inside the walls
--   islets        WEST (-250, -20) r 36 and EAST (250, -20) r 36 at y 0 with pavilions; BRIDGES x -218..-178 and
--                 178..218, z -28..-12
--   the RINGS     3 giant tilted golden rings round the island (radius ≈ 170–200, centre y ≈ 100, lowest point ≥ y 12),
--                 no collision
--   zones         ROTUNDA part: |x| < 100, z < -56 (the rotunda, its steps and forecourt); PLAZA part: the rest of the
--                 main island (the square round the pit, statues, the south edge and the causeway); SKY part: the rings,
--                 the islets and bridges, under the island, the floating islets, the clouds
local LOC = "cherubim"
local ROOT_NAME = "Cherubim"
local BX, BY, BZ = 22400, 31500, 0 -- floor 13 [docs/research/floor-brief.md]
local SEED = 2026102645
