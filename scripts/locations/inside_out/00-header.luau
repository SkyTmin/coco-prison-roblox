--!nocheck
-- Builds the Изнанка, level 27, PvP [меню]. «Мрачный перевёрнутый мир, где всё не так, как кажется. В его тенях
-- прячется Векна» [меню]; «Реальность трещит по швам, а блоки парят в пустоте. Шот-шахта» [вики 26.10].
-- Mine: листья мрачного дуба 100 % [меню], shears [вики]. Boss: Векна (vecna) — Stranger Things pack: demogorgon,
-- demodog and demobat minions, the clock of Vecna (a curse countdown), portals [клиент: RESOURCEPACK-BOSSES.md];
-- the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/inside_out/concept-v2.webp (владелец: «шедевр») — a dead copy of a small American suburb
-- on a floating island in a red void: grey cobbled square round the mine (oak fence, stone posts, lamp posts, a
-- red-white striped buyer stall), black asphalt streets with yellow markings, clapboard houses and a white church
-- choked by crimson vines, dead telephone poles, a yellow school bus, an overturned car, a bicycle by a fence, a wall
-- with Christmas lights over a painted alphabet, glowing rift doors; a Victorian mansion with a clock on its own
-- island high in the north (hero); the boss arena on an island below in the south: a dark cracked disc with red
-- glowing seams, broken lamp-post pillars, a ring rift of vines; dozens of upside-down dirt cones with hanging vines
-- float all around. Ideas: docs/research/location-ideas.md.
-- Generated: node scripts/bundle-location.mjs inside_out → scripts/build-inside-out.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.InsideOut.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the street level of the main island; the arrival is in the south):
--   main island  a rounded square |x/220|^4 + |z/200|^4 <= 1 with a ragged edge; an upside-down rock cone below
--   mine         32×12×32 blocks, hole x -64..64, z -72..56 (centre 0, -8); pit walls 2 blocks thick
--   square       grey cobbles x -96..96, z -104..100 round the pit (fence, posts, lamps — the town part)
--   arrival      (0, 0, 84) facing north to the pit; the buyer's red-white stall east of it at (32, 0, 84)
--   ring road    asphalt, 5 blocks wide, between the square and x ±116, z -124..120
--   streets      5 blocks wide (20 studs): WEST z -18..2, x -220..-116; EAST z -18..2, x 116..220;
--                NORTH x -10..10, z -200..-124 (→ the floating road up to the mansion);
--                SOUTH x -10..10, z 120..200 (→ the bridge down to the arena);
--                SW (-116, 120) → (-120, 190) and SE (116, 120) → (120, 190) (→ the islet bridges)
--   districts    houses in DISTRICTS (05-plan), each lot fronting a street; the church in the NE district
--   mansion      its own island, centre (0, -330), r 68, ground y 48 (hero; the clock over the porch)
--   sky road     torn-off asphalt chunks with stairs from the north street end (0, 0, -196) up to (0, 48, -264)
--   arena        island centre (0, 320), r 76, floor y -16; arena disc r 56; bridge from (0, 0, 198) down the
--                south street to (0, -16, 246); islets W (-120, 262) and E (120, 262), r 24, ground y -8, joined
--                to the main island (from (∓120, 0, 192)) and to the arena by arches: three ways in
--   sky          upside-down dirt cones with vines all round (x ±420, z ±520), none inside the paths
local LOC = "inside_out"
local ROOT_NAME = "InsideOut"
local BX, BY, BZ = 13400, 18000, 0 -- floor 4 [docs/research/floor-brief.md]
local SEED = 2026102627
