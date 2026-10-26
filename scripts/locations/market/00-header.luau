--!nocheck
-- Builds the Рынок, level 21, PvP [меню]. «Шумный тюремный рынок, где торгуют всем подряд. Под прилавками копают
-- ресурсы, а из-под земли поднялся Король нежити» [меню]; «Твоя новая смена среди торговых лавок и ящиков.
-- Шот-шахта» [вики 26.10]. Mine: красная шерсть 100 % [меню] (the справочник also names yellow and lime wool).
-- Boss: Король нежити (un_king) — «мечет тёмные снаряды, призывает взрывающиеся черепа и призрачный меч, а под
-- защитой своих гулей обрушивает на врагов метеоры» [клиент]; the fight is a placeholder for now [владелец 26.10].
-- Concept: assets/concepts/market/concept-v2.webp (approved style) — a walled prison bazaar on a floating island:
-- stone-brick wall with wooden-roofed watch towers and red/yellow banners, rows of striped-awning stalls around the
-- mine in the square, a collapsed fountain sinking into a hole (hero) with a broken staircase down to a crypt (boss
-- arena: dark pillars, a bone throne, soul lanterns), a wooden dock off the south gate. Ideas: docs/research/
-- location-ideas.md (Grand Bazaar, market towns, tomb cathedrals).
-- Generated: node scripts/bundle-location.mjs market → scripts/build-market.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Market.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the market floor; the arrival is in the south):
--   island      x, z in [-208, 208], rounded; the wall ring at |x|, |z| = 184..192; invisible edge walls further out
--   mine        32×12×32 blocks, hole x -104..24, z -48..80 (centre -40, 16); pit walls 2 blocks thick
--   plaza       cobbled ring around the pit to x -136..56, z -80..112
--   arrival     (-40, 0, 108) facing north to the pit; the buyer's stall east of it at (-12, 0, 110)
--   streets     5 blocks wide (20 studs): SOUTH avenue x -50..-30, z 112..184 (south gate, dock beyond);
--               NORTH street x -50..-30, z -184..-80; WEST street z 6..26, x -184..-136;
--               EAST street z 6..26, x 56..184 (east postern → cliff stairs down to the crypt cave);
--               CROSS street z -120..-100, x -184..54 (west quarter ↔ the hero plaza)
--   hero plaza  the collapsed fountain square, circle centre (110, -110), r 56 (x 54..166, z -166..-54)
--   crypt       the boss arena UNDER the hero plaza: floor y -48, vault y -8, centre (110, -110), r 56
--   entrances   (1) the sinkhole stairs from the hero plaza (NW part of the circle) down to the crypt floor;
--               (2) the cliff cave: mouth on the east cliff at (208, -48, -110), tunnel west to the arena;
--               (3) the smugglers' tunnel from a hatch at (40, 0, -66) by the plaza down to the arena's west side
--   districts   stall blocks are everything inside the wall that is not a street, the plaza or the hero plaza
local LOC = "market"
local ROOT_NAME = "Market"
local BX, BY, BZ = 10400, 13500, 0 -- the next free floor [CLAUDE.md: «Next location: X 10400, Y 13500»]
local SEED = 2026102121
