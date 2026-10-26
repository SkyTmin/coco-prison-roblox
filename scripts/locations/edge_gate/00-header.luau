--!nocheck
-- Builds the Врата края, level 35, PvP [меню]. «Врата Края стоят среди хорусовых плантаций и странных минералов, а каждый
-- шаг рядом ощущается как испытание» [меню]; «Хорусовые плантации и странные минералы вокруг. Каждый шаг рядом —
-- испытание. Шот-шахта» [вики 26.10]. Mine: пурпурный цемент 91 %, чёрное стекло 9 % [меню]. Boss: Жнец (reaper) —
-- death with a scythe: teleports in and out, draws a soul circle on the ground, spins, slams the ground [клиент:
-- RESOURCEPACK-BOSSES.md]; the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/edge_gate/concept-v2.webp — a cluster of end stone islands over the void with purpur
-- stalactites under them, joined by railless purpur bridges: the mine of magenta concrete and black glass on the main
-- island behind a purpur fence, end rods and candles, dark-wood huts with shulker boxes and chests, a buyer stall,
-- crystal spires (black glass at the base, magenta at the top); a grand end-stone staircase climbs north to the arena
-- island: a round obsidian platform with a ring of glowing magenta runes and candles, flanked by obsidian towers with
-- magenta crystal crowns and banners; behind it the monumental obsidian gate arch with purpur columns and a shimmering
-- black-violet portal film (hero); a chorus plantation in rows like a vineyard on the west island; a dragon head
-- statue on the east island; small floating islets all round; a reaper's scythe stuck in the stone. Night, quiet.
-- Ideas: docs/research/location-ideas.md.
-- Generated: node scripts/bundle-location.mjs edge_gate → scripts/build-edge-gate.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.EdgeGate.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the main island; the arrival is in the south):
--   main island  an ellipse centre (0, 74), radii 160 (x) and 150 (z), ragged; y 0
--   mine         32×12×32 blocks, hole x -64..64, z 8..136 (centre 0, 72); pit walls 2 blocks thick
--   arrival      (0, 0, 166) facing north to the pit; the buyer's stall east of it at (34, 0, 168)
--   paths        end stone bricks, 20 wide: the ring round the pit (x ±92, z -20..188 outside the pit area), NORTH
--                x -12..12 from the ring to the grand stair, WEST z 30..46 to the west bridge, EAST z -36..-20 to the
--                east bridge
--   grand stair  x -12..12, z -76 → -104, y 0 → 16, over the gap between the main and the arena island
--   arena island centre (0, -170), r ≈ 78, ground y 16; the arena (obsidian) r 52 at the centre; the GATE arch
--                behind it at x -28..28, z -240..-226 (hero, ~ 25 blocks tall); towers on the rim
--   west island  centre (-228, 40), r ≈ 56, y 0 (the chorus plantation); bridge x -180..-124, z 30..46
--   east island  centre (210, -28), r ≈ 56, y 0 (the dragon head, crystal spires); bridge x 84..170, z -36..-20
--   zones        GATE part: the arena island and the grand stair (z < -72); MAIN part: the main island (the pit
--                surroundings, huts, spires, the paths) and both bridges; ISLES part: the west and east islands, the
--                floating islets and the stalactites under every island
local LOC = "edge_gate"
local ROOT_NAME = "EdgeGate"
local BX, BY, BZ = 17400, 24000, 0 -- floor 8 [docs/research/floor-brief.md]
local SEED = 2026102635
