--!nocheck
-- Builds the Амбар, level 33, PvP [меню]. «Старинная часть фермы с амбаром запущена: заросли и мусор вокруг
-- превращают каждое задание в изнурительную работу» [меню]; «Заброшенный амбар и сорняки вокруг утомляют. Шот-шахта»
-- [вики 26.10]. Mine: светильник Джека 100 % [меню]. Boss: Древесный хранитель (forest_guardian) — a giant of roots
-- and bark: «пока его создания живы, никакое оружие не способно ранить хранителя» [клиент: RESOURCEPACK-BOSSES.md];
-- the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/barn/concept-v2.webp — the same farm many years later, an autumn-dusk Halloween island:
-- the mine full of jack o'lanterns in the south behind a crooked fence, a red-white buyer stall, a wooden stair up
-- from the south edge; in the middle a huge sagging red barn with a caved-in roof and an autumn tree growing through
-- the hole, glowing pumpkins and candles inside (hero); in the north the overgrown barnyard (boss arena): a dirt and
-- podzol clearing with broken fences, root mounds, jack o'lanterns and candles on hay, old striped silos standing
-- round it and a gnarled dead tree with a face at the back; a broken wind pump without sails, a rusty tractor, a
-- scarecrow with a burning pumpkin head, junk heaps with chains, an abandoned cart, ravens on posts, autumn trees.
-- Ideas: docs/research/location-ideas.md.
-- Generated: node scripts/bundle-location.mjs barn → scripts/build-barn.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Barn.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the farmyard; the arrival is in the south):
--   island      roughly round, r ≈ 216, ragged (a hexagon-ish outline), flat with soft bumps of weeds
--   mine        32×12×32 blocks, hole x -64..64, z 32..160 (centre 0, 96); pit walls 2 blocks thick
--   arrival     (0, 0, 190) facing north to the pit; the buyer's red-white stall east of it at (36, 0, 192)
--   south stair a wooden stair and landing at the south rim, x -10..10, z 196..216 (decor: it leads off the edge)
--   paths       podzol/dirt 20 wide: the ring round the pit (x ±92, z 4..188 outside the pit area; its north band
--               z 4..24 runs along the barn front); ROUND the barn
--               x -96..-72 and 72..96, z -84..4; WEST z -24..-8, x -216..-92; EAST z -24..-8, x 92..216
--   barn        the hero: footprint x -52..52, z -72..4 (26×19 blocks), big doors south (z 4) and north (z -72)
--               — walk through it from the mine to the arena; the tree grows out of the roof at (16, -32)
--   arena       the overgrown barnyard, centre (0, -140), r 52; the guardian's gnarled tree at the back (0, -204)
--   zones       BARN part: x -84..84, z -80..4 (the barn and its sides); YARD part: z < -80 (the arena, the north);
--               OUTSKIRTS part: the rest (the pit surroundings, the south, the west and east)
local LOC = "barn"
local ROOT_NAME = "Barn"
local BX, BY, BZ = 16400, 22500, 0 -- floor 7 [docs/research/floor-brief.md]
local SEED = 2026102633
