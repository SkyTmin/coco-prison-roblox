--!nocheck
-- Builds the Киото, level 29, PvP [меню]. «Город цветущей сакуры и древних храмов. На его улицах бьётся самурай
-- Ханасигуро» [меню]; «Под тенью сакуры и сводами храмов скрываются ресурсы. Шот-шахта» [вики 26.10].
-- Mine: розовая шерсть 90 %, морской фонарь 10 % [меню]. Boss: Самурай (the_lovers) — «[MCGarage] The Lovers»: three
-- phases, rain of arrows, ghost spears, kusarigama, shuriken, the ghost of his beloved [клиент: RESOURCEPACK-BOSSES.md];
-- the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/kyoto/concept-v2.webp — a terraced round island of grey stone cliffs under blooming cherry
-- trees: the mine in a cobbled square at the bottom with small dark-wood shop houses, lanterns and a red-white buyer
-- stall; a long stone staircase under a tunnel of red torii climbs north to a temple hall on the top terrace whose
-- wooden stage stands on a grid of tall log stilts over a koi pond (three waterfalls fall from under the stage, a red
-- arched bridge crosses the pond); a five-storey pagoda behind the temple (hero); bamboo groves, a dry zen garden,
-- stone lanterns, fox statues; the boss arena is a round wooden terrace on the north-west top with a red-white motif,
-- four red pillars capped with dark curved roofs and lanterns, red fences. Ideas: docs/research/location-ideas.md
-- (Kiyomizu-dera, Fushimi Inari).
-- Generated: node scripts/bundle-location.mjs kyoto → scripts/build-kyoto.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Kyoto.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the lower square; the arrival is in the south):
--   island      round, r ≈ 232 with a ragged edge; three terraces: L0 y 0 (the south half), L1 y 16 (the middle
--               band z -72..-8 west of x 56), L2 y 32 (the north, z < -72); grey stone cliffs between them
--   mine        32×12×32 blocks, hole x -88..40, z 24..152 (centre -24, 88); pit walls 2 blocks thick
--   square      cobbles x -120..72, z -8..216 round the pit (shops, lanterns — the town part)
--   arrival     (-24, 0, 182) facing north to the pit; the buyer's red-white stall east of it at (8, 0, 186)
--   main stair  x 24..44: flight A z 12 → -8 (y 0 → 16; the pit rim starts at z 16), landing on L1 z -8..-40, flight B z -40 → -72 (y 16 → 32);
--               a tunnel of red torii over both flights (the temple part)
--   west stair  x -180..-164, z 24 → -8 (y 0 → 16); arena stair x -96..-80, z -40 → -72 (y 16 → 32)
--   temple      the hall x 64..176, z -124..-76 on L2; the STAGE deck x 72..176, z -72..-16 at y 32 on log stilts
--               standing on L0 (x ≥ 56, z -72..-8 stays at y 0 under the stage); three waterfalls from the stage
--               edge into the POND (124, 24) r 36 (bed y -8, water to y -1); a red arched bridge over the pond
--   pagoda      five storeys at (110, -160) on L2 (hero)
--   arena       round wooden terrace on L2 at (-88, -128), r 56; ways in: the arena stair from L1 (south), the top
--               terrace from the temple (east) and from the west path
--   zones       TEMPLE part: x ≥ 56 and z ≤ 64, plus the main stair x 20..48, z -76..14;
--               HILL part: x < 56 and z < -8 (L1, L2 west, the arena) except the main stair;
--               TOWN part: the rest (z ≥ -8 outside the temple zone): the square, the shops, the south and west
local LOC = "kyoto"
local ROOT_NAME = "Kyoto"
local BX, BY, BZ = 14400, 19500, 0 -- floor 5 [docs/research/floor-brief.md]
local SEED = 2026102629
