--!nocheck
-- Builds the Ферма, level 31, PvP [меню]. «Ухоженная часть фермы сияет рядами аккуратных грядок, а зрелый урожай
-- манит собрать его руками» [меню, вики 26.10]. Mine: арбуз 46 %, тыква 46 %, зелёная шерсть 9 % [меню].
-- Boss: Грут (ent) — the Ent King pack: punches, stomp, shout, branches erupting from the ground, branch waves, leaf
-- storms, tree minions [клиент: RESOURCEPACK-BOSSES.md]; the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/farm/concept-v2.webp — a floating island of farmland seen from a hill: the mine full of
-- melons and pumpkins in the middle of a patchwork of crop beds (wheat, carrots, cabbages, melons) between dirt paths
-- with fences, a yellow-white produce stall, a stone well, a scarecrow with a pumpkin head, a pumpkin cart, a chicken
-- coop, a sheep pen, a beehive tree; a red barn in the east; on the hill in the north a windmill with white sails and a
-- red-brick silo with a grey dome (hero); in the north-west a forest round a dirt clearing (boss arena) in front of a
-- huge ancient tree with a face and root arches (the sleeping Ent), old trees standing round it. Ideas:
-- docs/research/location-ideas.md.
-- Generated: node scripts/bundle-location.mjs farm → scripts/build-farm.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Farm.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the farmland; the arrival is in the south):
--   island      a rounded square |x|, |z| <= 224 (corner r 48) with a ragged edge; the HILL L1 y 16 is the north
--               (z < -80); a windmill MOUND y 28 on it, centre (96, -168), r 36; grass cliffs between the levels
--   mine        32×12×32 blocks, hole x -64..64, z -40..88 (centre 0, 24); pit walls 2 blocks thick
--   ring path   dirt, 20 wide, round the pit: the band between x ±72, z -48..96 and x ±92, z -68..116
--   arrival     (0, 0, 108) on the ring path's south band, facing north to the pit; the buyer's yellow-white stall
--               east of it at (32, 0, 110)
--   paths       dirt, 16–20 wide: SOUTH x -10..10, z 116..224; WEST z 16..32, x -224..-92; EAST z 16..32,
--               x 92..132 (→ the barn yard)
--   stairs      MAIN x -10..10, z -64 → -80 (y 0 → 16); EAST x 80..96, z -64 → -80; WEST x -180..-164, z -64 → -80;
--               MOUND x 88..104, z -124 → -132 (y 16 → 28)
--   fields      crop beds FIELDS (05-plan) on L0 between the paths (the fields part plants them)
--   barn        the red barn yard x 132..208, z -48..40 on L0 (the farmstead part); the farmhouse x 120..196,
--               z 64..132; the silo at (156, -150) on L1; the windmill on the mound
--   arena       the dirt clearing on L1, centre (-92, -136), r 52; the Ent tree behind it at (-92, -200)
--   zones       FIELDS part: L0 west of x 116; FARMSTEAD part: L0 x ≥ 116 and L1/the mound east of x -24;
--               GROVE part: L1 west of x -24 (the arena, the Ent, the forest) plus the three L0→L1 stairs
local LOC = "farm"
local ROOT_NAME = "Farm"
local BX, BY, BZ = 15400, 21000, 0 -- floor 6 [docs/research/floor-brief.md]
local SEED = 2026102631
