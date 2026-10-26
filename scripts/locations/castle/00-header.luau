--!nocheck
-- Builds the Замок, level 25, PvP [меню]. «Старый замок с высокими стенами и тёмными коридорами. Его камни стерегут
-- стаи воронов и их проклятый рыцарь» [меню]; «Дворцовая площадь стала твоим новым забоем. Шот-шахта» [вики 26.10].
-- Mine: кварцевый блок 100 % [меню] (the справочник adds резной кварцевый блок). Boss: Вороний рыцарь (raven_knight)
-- — «проклятый рыцарь Замка, чья душа отдана воронам» [клиент]; resource pack: crow swarms, black fog, spikes from the
-- ground, a summoned flying axe, a crow-reaper second form. The fight is a placeholder for now [владелец 26.10].
-- Concept (the owner: «шедевр»): assets/concepts/castle/concept-v2.webp — a white gothic castle of quartz spoiled by
-- raven nests and soot (white/black contrast): a curtain wall with towers and black banners with a white wing, the mine
-- in the outer bailey by the gate with a black-and-white awning buyer, a round courtyard with a ring pattern in front
-- of the keep (the arena: 4 square quartz pillars with banners, knight statues, black feathers), the keep — a tall
-- White Tower with a raven nest on its spire, dark trees, a graveyard of the cursed knight. Overcast grey evening.
-- Ideas: docs/research/location-ideas.md (the Tower ravens, quartz gothic, deepslate → quartz gradient walls).
-- Generated: node scripts/bundle-location.mjs castle → scripts/build-castle.luau. Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Castle.
--
-- THE PLAN (local studs; +X east, +Z south; y 0 = the bailey floor; the gate and the arrival are in the south):
--   island      a square ±216 with rounded corners (ragged outside the wall)
--   curtain     the wall ring at |x| or |z| = 184..192, 9 blocks high, towers at the corners and mid-sides;
--               the gatehouse at the south (x -12..12) with a stone bridge out to a terrace over the clouds
--   avenue      from the gate north to the courtyard: x -12..12, z 4..184 (5 blocks + edges)
--   mine        32×12×32 blocks, hole x -160..-32, z 0..128 (centre -96, 64) in the outer bailey west of the avenue
--   arrival     (-96, 0, 156) facing north to the pit; the buyer's stall at (-64, 0, 160)
--   courtyard   the arena: a round paved court, centre (56, -48), r 52 (x 4..108, z -100..4), a low balustrade ring
--               with 6 openings; 4 quartz pillars at r ≈ 30
--   keep        north of the courtyard: footprint x 0..112, z -184..-112, the White Tower at (56, -150) rising to
--               ≈ 140 with a raven nest on its spire
--   districts   chapel (x 120..176, z 20..110), stables & barracks (x 30..176, z 116..176), the knights' hall
--               (x -176..-120, z -96..-20), the cursed knight's graveyard (x -176..-100, z -176..-110),
--               gardens with dark trees in between
local LOC = "castle"
local ROOT_NAME = "Castle"
local BX, BY, BZ = 12400, 16500, 0 -- floor 3 [docs/research/floor-brief.md]
local SEED = 2026102525
