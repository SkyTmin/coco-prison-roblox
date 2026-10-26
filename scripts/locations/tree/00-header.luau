--!nocheck
-- Builds the Древо, level 37, PvP, the first sky mine [меню]. «Исполинское древо, чьи корни уходят сквозь облака. С
-- него начинается путь в небесные шахты» [меню]. Mine: белый цемент 100 % [меню: mine-shares]. No boss: a summit in
-- the crown instead of an arena [docs/research/floor-brief.md].
-- Concept: assets/concepts/tree/concept-v2.webp — three earth islands wrapped in roots over the clouds, joined by
-- wooden paths and rope bridges: on the west island the mine of white concrete («застывший небесный сок») in a
-- stone-brick bowl behind a plank boardwalk and a fence, a buyer under a green-and-white awning, lamp posts with
-- clover banners, a mossy stone arch and a mossy totem with a face, a well with a basket of white concrete; in the
-- middle the colossal trunk (12 blocks wide, bark of dark oak, oak and stripped wood) with a hollow arched entrance
-- and a spiral stair inside up to the SUMMIT: a wooden deck in the crown above the clouds with a ring of mossy stone
-- ruins and planters; branches with rope bridges, hanging lanterns, birdhouses, red bracket mushrooms, a basket
-- lift; the crown in patches of oak, azalea and flowering azalea leaves; on the east island a pond with a waterfall
-- off the edge; roots hang 30–40 blocks under the islands into white wool clouds. Early morning, airy height.
-- Ideas: docs/research/location-ideas.md («Древо (37)»).
-- Generated: node scripts/bundle-location.mjs tree → scripts/build-tree.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Tree.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the ground of every island):
--   west island    a disc centre (-150, 30), r ≈ 128, ragged; the mine and the arrival
--   mine           32×12×32 blocks, hole x -214..-86, z -34..94 (centre -150, 30); a plank boardwalk ring round
--                  the pit (4 blocks wide, corners cut round)
--   arrival        (-56, 0, 30) east of the pit, facing west to it; the buyer's stall at (-50, 50)
--   central island a disc centre (30, -30), r ≈ 100, merges with the west island through a wide neck
--   the TREE       trunk centre (36, -48), r 24 (12 blocks), the door on its south face (z -24) at x 28..44; a
--                  spiral stair inside up to the SUMMIT deck at y 140 (r 44 round the trunk); the crown y 120..200
--   east island    a disc centre (230, 24), r ≈ 80, separate: a rope bridge x 116..164, z -2..10 at y 0
--   paths          the boardwalk ring; MAIN STREET x -62..56, z 20..40 (5 blocks) from the ring to the tree; the DOOR
--                  path x 26..46, z -24..20; the EAST path x 46..120, z -6..14 to the bridge
--   zones          TREE part: the circle r 72 round the trunk, the trunk, the crown, the summit, the roots of the
--                  tree under the central island; WEST part: x < 0 outside the tree circle; EAST part: x ≥ 0 outside
--                  the tree circle, the bridge, the east island, the islets, the roots under the islands, the clouds
local LOC = "tree"
local ROOT_NAME = "Tree"
local BX, BY, BZ = 18400, 25500, 0 -- floor 9 [docs/research/floor-brief.md]
local SEED = 2026102637
