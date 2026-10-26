--!nocheck
-- Builds the Эдем, level 43, PvP, the fourth sky mine [меню]. «Цветущий сад Эдема, где земля богата на ценные блоки»
-- [меню]. Mine: гриб (коричневый) 100 % [меню: mine-shares]. No boss: a summit (the flowery hill under the Tree of
-- Life) instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/eden/concept-v2.webp — a square garden island over the clouds, the first truly colourful
-- level: a ring river round the central hill, three rivers from it to the edges falling off as waterfalls, so the
-- garden is split into parts; on the hill the pink-blossoming Tree of Life (cherry leaves, flowering azalea, pink wool,
-- hanging vines and wisteria) with a green serpent coiled round its trunk, a fountain and a plaza with lanterns at its
-- foot; arches of leaves and flowers, apple trees with red apples, pink cherry trees, gazebos with green roofs, pink
-- cherry-plank bridges, a pond with lily pads, flower beds in single-colour rows, trellises, beehives with bees, deer,
-- bamboo; the mine of brown mushroom blocks behind a fence with a green-roofed buyer pavilion, giant umbrella
-- mushrooms; mossy stone ruins of arches; vines hanging over the edges. Radiant spring noon.
-- Ideas: docs/research/location-ideas.md («Эдем (43)»).
-- Generated: node scripts/bundle-location.mjs eden → scripts/build-eden.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Eden.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the garden):
--   island        a rounded square |x|, |z| ≤ 220 (superellipse), ragged
--   the HILL      centre (0, -60): the bank y 0 out to r 82, the ring RIVER r 82..98 (bed y -4, water to y -0.8),
--                 L1 y 8 inside r 72, the SUMMIT L2 y 16 inside r 40 with the Tree of Life (trunk r 12) at the centre
--   rivers        WEST x ≤ -90, EAST x ≥ 90 at z -68..-52, NORTH x -8..8, z ≤ -150: from the ring to the edges
--   mine          32×12×32 blocks, hole x -104..24, z 64..192 (centre -40, 128), south-west of the hill
--   arrival       (56, 0, 128) east of the pit, facing west to it; the buyer's pavilion at (66, 150)
--   paths         EAST x 36..56, z 40..128 from the arrival north; CROSS x -10..56, z 40..56 under the ring; the south
--                 BRIDGE over the ring x -10..10, z 18..44; the hill stairs S1 (z 12, y 0→8) and S2 (z -20, y 8→16)
--   zones         HILL part: d < 100 from the hill centre (the ring river, the bank, the hill, the tree, the ring
--                 bridges); SOUTH part: z > -52 outside the hill (the mine, the arrival, gardens, mushrooms); NORTH
--                 part: z ≤ -52 outside the hill (the north-west and north-east gardens, the three rivers and their
--                 bridges and waterfalls), under the island, the sky
local LOC = "eden"
local ROOT_NAME = "Eden"
local BX, BY, BZ = 21400, 30000, 0 -- floor 12 [docs/research/floor-brief.md]
local SEED = 2026102643
