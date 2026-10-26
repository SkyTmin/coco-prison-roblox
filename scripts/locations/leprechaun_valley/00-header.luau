--!nocheck
-- Builds the Лепреконовая долина, level 23, PvP [меню]. «Зелёная долина, заросшая клевером. Говорят, здесь спрятано
-- золото лепреконов, а поляну стережёт лесной дух» [меню]; «Не верь краскам, здесь только пот и тяжёлый труд.
-- Шот-шахта» [вики 26.10]. Mine: жёлтый цемент 100 % [меню] (the справочник also names orange, lime, purple, red).
-- Boss: Лесной дух (forest_spirit) — «древний дух Лепреконовой долины; пока культисты хранят его тотем, лес не знает
-- покоя» [клиент]; resource pack: totem, roots, spikes, storm, lightning, flying skulls, cultists (shamans, lost
-- explorers with lanterns). The fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/leprechaun_valley/concept-v2.webp — a round green floating island: the mine in the south
-- with a clover mosaic plaza and the arrival; a rainbow from a north-west hill into a black cauldron of gold; streams
-- with stone arch bridges and waterfalls off the edge; hobbit burrows in the west hills, giant red mushrooms, a
-- windmill, a cultists' camp with green tents; in the north-east an Irish fairy fort — a moat ring and earth banks —
-- round the arena of mossy totem pillars with antlers and the great hawthorn tree with the spirit's totem.
-- Ideas: docs/research/location-ideas.md (fairy fort, hawthorn, rainbow of concrete, menhirs, fairy ring).
-- Generated: node scripts/bundle-location.mjs leprechaun_valley → scripts/build-leprechaun-valley.luau. Run in Studio
-- (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.LeprechaunValley.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the valley floor; the arrival is in the south):
--   island      round, radius ≈ 224 (ragged); hills terraced in 4-stud steps (groundY in 05-plan)
--   mine        32×12×32 blocks, hole x -64..64, z -4..124 (centre 0, 60); a clover plaza around it to 24 studs
--   arrival     (0, 0, 152) facing north to the pit; the buyer's stall at (30, 0, 156)
--   paths       flat (y 0), 5 blocks: the plaza ring; NORTH (0,-12)→(0,-64)→(30,-100) to the fort's west gate;
--               NE (72,-12)→(110,-6) to the fort's south gate; WEST (-76,60)→(-150,60)→(-130,-20)→(-112,-40) to the
--               cauldron hill; EAST (76,60)→(150,40)→(196,-30) the cultist camp and the fort's east side
--   river       from the fort moat (west side) to a waterfall off the west edge: (52,-100)→(10,-70)→(-40,-30)→
--               (-100,10)→(-160,24)→(-232,24); 16 studs wide, bed y -4, water to y -1; stone bridges where paths cross
--   fort        the fairy fort, centre (110, -100): arena disc r 52 (flat y 0), moat r 60..72, earth banks r 72..88;
--               gates through the banks + bridges over the moat: south (110, -12), west (22, -100), east (198, -100)
--   tree        the great hawthorn with the totem at (110, -150) (the arena's north edge)
--   rainbow     from (-196, -116) arching to the cauldron on the hill at (-112, -62) (hill top y 16)
--   districts   west hills: hobbit burrows (x -210..-110, z -20..150) and the windmill (-176, 120);
--               cultist camp (x 120..200, z 10..90); mushroom grove (x -100..-40, z 150..200); fairy ring (60, 170)
local LOC = "leprechaun_valley"
local ROOT_NAME = "LeprechaunValley"
local BX, BY, BZ = 11400, 15000, 0 -- floor 2 [docs/research/floor-brief.md]: X +1000, Y +1500 from the Рынок
local SEED = 2026102323
