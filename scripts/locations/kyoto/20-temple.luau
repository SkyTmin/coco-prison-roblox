-- ================================================================ kyoto: the torii stair, the temple hall, the stage, the pond, the pagoda
-- The main stair x 24..44 (kit stairs): flight A z 12 → -8 (y 0 → 16), the stone landing on L1 z -8..-40, flight B
-- z -40 → -72 (y 16 → 32); stone kerbs 1 block high on both flights (x 20..24, 44..48), a tunnel of 15 red torii
-- (posts on the kerb line x 20..24 / 44..48, black feet, red nuki at +15, black kasagi with raised ends; every 5 studs
-- on the flights, every 8 on the landing, where the gaps between the posts open to L1), stone lanterns at the landing
-- ends, a pair of stone kitsune at the foot (z 8) and at the top (z -77).
-- The hall (TEMPLE x 64..176, z -124..-76) on a stone footing filled down to wherever L2 ends: a wooden floor 1 stud
-- above the court, dark post-and-beam walls with white plaster, shoji bays and an open middle bay (x 106..134) to the
-- altar, a row of red posts along the veranda (z -78), a stepped hip roof of dark tiles (y 53..75, eaves x 60..180,
-- z -128..-72) with up-turned corner tips and a south cross-gable with a white plaster face.
-- The stage deck x 72..176, z -72..-16 at y 32 on 13 × 7 dark log stilts (every 8 studs from x 76, z -20) with tie
-- beams at y 6, 14, 22 in both directions and a cap row at 28; a dark railing on the south, west and east sides.
-- Three waterfalls (x 108, 124, 140) out of mossy rock mouths under the south edge into the POND (the side ones by a
-- short stream); the pond gets stone and moss edges, lily pads, 10 koi, reeds, a red arched bridge (x 76..172 along
-- z 24, deck z 16..32, top y 6, invisible chord ramps over the steps), stone lanterns at its ends and a small shrine
-- with the white ghost of the samurai's beloved on the east bank. Under and beside the stage: bamboo, moss rocks,
-- a gravel path from the square. The five-storey pagoda at (PAGODA.x, PAGODA.z + 4) on a stone platform (to y ≈ 129),
-- a bell tower, stone paths and lanterns in the east bailey; cherry trees with petal carpets and bamboo in the rest.
local temple = folder("Temple")
local partsBefore = count
local lights = 0
local INK = Color3.fromRGB(34, 30, 32)
local BRONZE = Color3.fromRGB(150, 112, 64)
local BAMBOO_C = Color3.fromRGB(170, 214, 110)
local LEAF_C = Color3.fromRGB(96, 150, 70)
local FOX_STONE = Color3.fromRGB(214, 212, 206)
local ROOF_V = "px_roof_tiles"

-- the height of the island cell under a point (the core samples the ground at the 8-stud cell centres)
local function cellY(x, z)
	return groundY(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4)
end
-- 8-stud cells of a rect: key(cx, cz) -> value or nil; equal values along x merge into one run -> emit(x0, x1, z, value)
local function cellRuns(x0, z0, x1, z1, key, emit)
	for z = z0, z1 - 8, 8 do
		local runX, runKey = nil, nil
		for x = x0, x1, 8 do
			local k = if x < x1 then key(x + 4, z + 4) else nil
			if k ~= runKey then
				if runKey ~= nil then
					emit(runX, x, z, runKey)
				end
				runX, runKey = x, k
			end
		end
	end
end
-- a stone footing under a rect up to `top` wherever the ground is lower (the L2 edge wanders by ±8 studs)
local function fillTo(x0, z0, x1, z1, top, parent)
	cellRuns(x0, z0, x1, z1, function(cx, cz)
		local gy = groundY(cx, cz)
		return if gy < top - 0.5 then gy else nil
	end, function(xa, xb, z, gy)
		box("Footing", xa, gy - B, z, xb, top, z + 8, "px_stone_bricks", STONE, parent)
	end)
end
local function glow(p, range)
	if lights < 26 then
		lights += 1
		light(p, range or 24, 1.1, LANTERN_GLOW)
	end
end
-- a stone lantern (tōrō) about 2.5 blocks tall standing on (x, y, z)
local function stoneLantern(x, y, z, parent, lit)
	local f = folder("StoneLantern", parent)
	cube("LanternBase", x, y + 0.5, z, 4, 1, 4, "px_stone_bricks", STONE, f)
	cube("LanternShaft", x, y + 2.5, z, 2, 3, 2, "px_smooth_stone", STONE, f)
	cube("LanternTable", x, y + 4.4, z, 3.6, 0.8, 3.6, "px_stone_bricks", STONE, f)
	cube("LanternBox", x, y + 6, z, 2.8, 2.4, 2.8, "px_smooth_stone", STONE, f)
	local g = decor(cube("LanternLight", x, y + 6, z, 3.1, 1.2, 1.4, "px_glowstone", nil, f))
	decor(cube("LanternLight", x, y + 6, z, 1.4, 1.2, 3.1, "px_glowstone", nil, f))
	cube(
		"LanternRoof",
		x,
		y + 7.7,
		z,
		4.6,
		1,
		4.6,
		"px_stone_bricks",
		Color3.fromRGB(120, 118, 116),
		f
	)
	cube(
		"LanternRoof",
		x,
		y + 8.6,
		z,
		2.6,
		0.8,
		2.6,
		"px_stone_bricks",
		Color3.fromRGB(120, 118, 116),
		f
	)
	cube("LanternCap", x, y + 9.5, z, 1, 1, 1, "px_smooth_stone", STONE, f)
	if lit then
		glow(g, 26)
	end
	return f
end
-- a paper lantern (chōchin) hanging from (x, yTop, z)
local function paperLantern(x, yTop, z, tint, parent, lit)
	decor(cube("LanternCord", x, yTop - 0.5, z, 0.3, 1, 0.3, nil, INK, parent))
	decor(cube("PaperCap", x, yTop - 1.2, z, 1.4, 0.4, 1.4, "px_dark_oak_planks", INK, parent))
	local body =
		decor(cube("PaperLantern", x, yTop - 2.5, z, 1.8, 2.2, 1.8, "px_white_wool", tint, parent))
	decor(cube("PaperCap", x, yTop - 3.8, z, 1.4, 0.4, 1.4, "px_dark_oak_planks", INK, parent))
	if lit then
		glow(body, 18)
	end
	return body
end
-- up-turned corner tips on a roof layer x0..x1, z0..z1 whose top is y: a block raised half a step at each corner and
-- a smaller one on it reaching out past the corner (the tip ends one block above the layer)
local function roofTips(x0, z0, x1, z1, y, tint, parent, s)
	s = s or B
	for _, cx in ipairs({ x0, x1 }) do
		for _, cz in ipairs({ z0, z1 }) do
			local ix = if cx == x0 then 1 else -1
			local iz = if cz == z0 then 1 else -1
			box(
				"RoofTip",
				cx,
				y,
				cz,
				cx + ix * 2 * s,
				y + s / 2,
				cz + iz * 2 * s,
				ROOF_V,
				tint,
				parent
			)
			box(
				"RoofTip",
				cx - ix * s / 2,
				y + s / 2,
				cz - iz * s / 2,
				cx + ix * s,
				y + s,
				cz + iz * s,
				ROOF_V,
				tint,
				parent
			)
		end
	end
end
-- the surface of the main stair at z (flight A 10 steps of 1.6, the landing, flight B 16 steps of 1)
local function stairY(z)
	if z >= 12 then
		return 0
	elseif z > -8 then
		return 1.6 * (math.clamp(math.floor((12 - z) / 2), 0, 9) + 1)
	elseif z >= -40 then
		return L1_Y
	elseif z > -72 then
		return L1_Y + math.clamp(math.floor((-40 - z) / 2), 0, 15) + 1
	end
	return L2_Y
end
-- keep-out rects of this part (x0, z0, x1, z1) for trees and bamboo: buildings, paths, the bridge, the falls, the stair
local BLOCK = {
	{ 60, -132, 180, -68 }, -- the hall and its eaves
	{ 86, -180, 134, -130 }, -- the pagoda platform and its steps
	{ 138, -152, 162, -128 }, -- the bell tower
	{ 54, -166, 66, -70 }, -- the west path
	{ 64, -164, 92, -150 }, -- the path to the pagoda
	{ 100, -136, 120, -122 }, -- the path behind the hall
	{ 70, 10, 206, 40 }, -- the bridge, its paths, the shrine
	{ 96, -22, 152, -6 }, -- the waterfalls
	{ 70, -10, 100, 2 }, -- the gravel path
	{ 16, -84, 52, 18 }, -- the torii stair
}
local function blocked(x, z, pad)
	for _, r in ipairs(BLOCK) do
		if inRect(x, z, r, pad) then
			return true
		end
	end
	return false
end
local function flat(x, z, r)
	local y = cellY(x, z)
	return cellY(x - r, z - r) == y
		and cellY(x + r, z - r) == y
		and cellY(x - r, z + r) == y
		and cellY(x + r, z + r) == y
end
-- a blooming cherry: a log trunk with two branches, a crown of cherry leaves round a pink wool core (`size` blocks
-- wide), loose blocks on its edge and a carpet of fallen petals
local function cherry(x, z, size, parent)
	local y0 = cellY(x, z)
	local f = folder("CherryTree", parent)
	local h = if size >= 7 then 16 elseif size == 6 then 14 else 12
	local log = if rng:NextNumber() < 0.5 then "px_cherry_log" else "px_dark_oak_log"
	local core = if rng:NextNumber() < 0.35 then SAKURA_DEEP else SAKURA
	local W = size * B
	local hw = W / 2
	box("Trunk", x - 2, y0, z - 2, x + 2, y0 + h, z + 2, log, nil, f)
	local sx = if rng:NextNumber() < 0.5 then 1 else -1
	box("Branch", x + sx * 2, y0 + h - 6, z - 2, x + sx * 6, y0 + h - 2, z + 2, log, nil, f)
	box("Branch", x - 2, y0 + h - 4, z - sx * 2, x + 2, y0 + h, z - sx * 6, log, nil, f)
	box(
		"Leaves",
		x - hw,
		y0 + h - 2,
		z - hw + 4,
		x + hw,
		y0 + h + 2,
		z + hw - 4,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Leaves",
		x - hw + 4,
		y0 + h - 2,
		z - hw,
		x + hw - 4,
		y0 + h + 2,
		z + hw,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Blossom",
		x - hw + 2,
		y0 + h + 2,
		z - hw + 2,
		x + hw - 2,
		y0 + h + 8,
		z + hw - 2,
		"px_white_wool",
		core,
		f
	)
	box(
		"Leaves",
		x - hw + 4,
		y0 + h + 8,
		z - hw + 4,
		x + hw - 4,
		y0 + h + 10,
		z + hw - 4,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Leaves",
		x - hw,
		y0 + h + 2,
		z - hw + 4,
		x - hw + 2,
		y0 + h + 6,
		z + hw - 4,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Leaves",
		x + hw - 2,
		y0 + h + 2,
		z - hw + 4,
		x + hw,
		y0 + h + 6,
		z + hw - 4,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Leaves",
		x - hw + 4,
		y0 + h + 2,
		z - hw,
		x + hw - 4,
		y0 + h + 6,
		z - hw + 2,
		"px_cherry_leaves",
		nil,
		f
	)
	box(
		"Leaves",
		x - hw + 4,
		y0 + h + 2,
		z + hw - 2,
		x + hw - 4,
		y0 + h + 6,
		z + hw,
		"px_cherry_leaves",
		nil,
		f
	)
	for i = 1, 3 do
		local lx = x + rng:NextInteger(-(size // 2), size // 2) * B
		local lz = z + (if i % 2 == 0 then 1 else -1) * (hw - 2)
		local ly = y0 + h + rng:NextInteger(-1, 1) * B
		cube(
			if i == 2 then "Blossom" else "Leaves",
			lx,
			ly,
			lz,
			B,
			B,
			B,
			if i == 2 then "px_white_wool" else "px_cherry_leaves",
			if i == 2 then core else nil,
			f
		)
	end
	if flat(x, z, hw) then
		decor(
			box(
				"Petals",
				x - hw,
				y0 + 0.05,
				z - hw,
				x + hw,
				y0 + 0.35,
				z + hw,
				"px_white_wool",
				SAKURA,
				f
			)
		)
	end
	return f
end
-- a clump of bamboo: 1×1-block green stalks 4–8 blocks tall on a 4-stud grid round (cx, cz); every stalk is checked
local function bambooClump(cx, cz, parent)
	local f = folder("Bamboo", parent)
	local n = 0
	for gx = -2, 2 do
		for gz = -2, 2 do
			local x, z = snap(cx) + gx * B, snap(cz) + gz * B
			if
				math.abs(gx) + math.abs(gz) <= 3
				and rng:NextNumber() < 0.5
				and zoneOf(x, z) == "temple"
				and onIsland(x, z, 10)
				and not inStairCorridor(x, z)
				and not inRect(x, z, { STAGE.x0, STAGE.z0, STAGE.x1, STAGE.z1 }, 3)
				and not inPond(x, z, 5)
				and not (x < 74 and z > -10)
				and not blocked(x, z, 2)
				and flat(x, z, 2)
			then
				local y0 = cellY(x, z)
				local h = rng:NextInteger(4, 8) * B
				box("BambooStalk", x - 2, y0, z - 2, x + 2, y0 + h, z + 2, "px_hedge", BAMBOO_C, f)
				decor(
					box(
						"BambooNode",
						x - 2.2,
						y0 + h * 0.5,
						z - 2.2,
						x + 2.2,
						y0 + h * 0.5 + 0.5,
						z + 2.2,
						"px_hedge",
						LEAF_C,
						f
					)
				)
				decor(
					box(
						"BambooLeaves",
						x - 3,
						y0 + h - 1,
						z - 3,
						x + 3,
						y0 + h + 2,
						z + 3,
						"px_hedge",
						LEAF_C,
						f
					)
				)
				n += 1
			end
		end
	end
	return n
end
-- a stone kitsune (fox) on a plinth at (x, y, z) looking south (+Z), a red bib round its neck
local function fox(x, y, z, parent)
	local f = folder("Kitsune", parent)
	local function fb(name, x0, y0, z0, x1, y1, z1, variant, tint, deco)
		local p = box(name, x + x0, y + y0, z + z0, x + x1, y + y1, z + z1, variant, tint, f)
		if deco then
			decor(p)
		end
	end
	fb("FoxPlinth", -2.4, -1, -4.4, 2.4, 3, 4.4, "px_stone_bricks", STONE)
	fb("FoxBody", -2, 3, -3.6, 2, 8, 1, "px_smooth_stone", FOX_STONE)
	fb("FoxChest", -1.6, 3, 0.6, 1.6, 10.4, 3, "px_smooth_stone", FOX_STONE)
	fb("FoxHead", -1.8, 10.4, 0.4, 1.8, 13.6, 3.8, "px_smooth_stone", FOX_STONE)
	fb("FoxSnout", -0.8, 10.8, 3.8, 0.8, 12, 5.4, "px_smooth_stone", FOX_STONE)
	fb("FoxEar", -1.7, 13.6, 1.2, -0.5, 15.4, 2.4, "px_smooth_stone", FOX_STONE)
	fb("FoxEar", 0.5, 13.6, 1.2, 1.7, 15.4, 2.4, "px_smooth_stone", FOX_STONE)
	fb("FoxTail", -1, 5, -4.4, 1, 12, -2.8, "px_smooth_stone", FOX_STONE)
	fb("FoxTailTip", -1.1, 12, -4.5, 1.1, 13.6, -2.7, "px_white_wool", PAPER)
	fb("FoxBib", -1.9, 8.6, 2.6, 1.9, 10.2, 3.3, "px_white_wool", TORII_RED, true)
	fb("FoxBib", -1, 7.6, 2.9, 1, 8.6, 3.4, "px_white_wool", TORII_RED, true)
	fb("FoxEye", -1.4, 12.2, 3.8, -0.6, 12.6, 3.9, nil, TORII_RED, true)
	fb("FoxEye", 0.6, 12.2, 3.8, 1.4, 12.6, 3.9, nil, TORII_RED, true)
end

-- ================================================================ the main stair and the torii tunnel
do
	local st = folder("MainStair", temple)
	local S = MAIN_STAIR
	local cx, w = (S.x0 + S.x1) / 2, S.x1 - S.x0
	stairs("FlightA", cx, S.zA0, S.zA1, 0, L1_Y, w, "px_stone_bricks", st)
	stairs("FlightB", cx, S.zB0, S.zB1, L1_Y, L2_Y - L1_Y, w, "px_stone_bricks", st)
	for _, p in ipairs(st:GetChildren()) do
		if p:IsA("Part") then
			p.Color = STONE
		end
	end
	-- the kerbs: one block above every step on both sides
	for k = 0, 9 do
		local top = 1.6 * (k + 1)
		for _, wx in ipairs({ S.x0 - B, S.x1 }) do
			box(
				"StairKerb",
				wx,
				-1,
				S.zA0 - 2 * k - 2,
				wx + B,
				top + B,
				S.zA0 - 2 * k,
				"px_stone_bricks",
				STONE,
				st
			)
		end
	end
	for k = 0, 15 do
		local top = L1_Y + k + 1
		for _, wx in ipairs({ S.x0 - B, S.x1 }) do
			box(
				"StairKerb",
				wx,
				L1_Y - 1,
				S.zB0 - 2 * k - 2,
				wx + B,
				top + B,
				S.zB0 - 2 * k,
				"px_stone_bricks",
				STONE,
				st
			)
		end
	end
	-- the stone landing on L1 and the paving at the top
	box("Landing", S.x0, L1_Y - 0.5, S.zB0, S.x1, L1_Y + 0.1, S.zA1, "px_stone_bricks", STONE, st)
	box(
		"TopPaving",
		S.x0 - B,
		L2_Y - 0.5,
		-80,
		S.x1 + B,
		L2_Y + 0.1,
		S.zB1,
		"px_stone_bricks",
		STONE,
		st
	)
	for _, z in ipairs({ -11, -37 }) do
		stoneLantern(S.x0 - 2, L1_Y, z, st, true)
		stoneLantern(S.x1 + 2, L1_Y, z, st, true)
	end
	-- the torii: posts on the kerb line, black feet, red nuki and shimaki, a black kasagi with raised ends
	local zs = { 14, 9, 4, -1, -6, -16, -24, -32, -43, -48, -53, -58, -63, -68, -73 }
	for _, zc in ipairs(zs) do
		local f = folder("Torii", st)
		local lo, hi = stairY(zc + 2), stairY(zc - 2.5)
		box(
			"ToriiFoot",
			S.x0 - 4.8,
			lo - 1,
			zc - 2.4,
			S.x0,
			lo + B,
			zc + 2.4,
			"px_white_wool",
			INK,
			f
		)
		box(
			"ToriiFoot",
			S.x1,
			lo - 1,
			zc - 2.4,
			S.x1 + 4.8,
			lo + B,
			zc + 2.4,
			"px_white_wool",
			INK,
			f
		)
		box(
			"ToriiPost",
			S.x0 - B,
			lo + B,
			zc - 2,
			S.x0,
			hi + 21,
			zc + 2,
			"px_smooth_stone",
			TORII_RED,
			f
		)
		box(
			"ToriiPost",
			S.x1,
			lo + B,
			zc - 2,
			S.x1 + B,
			hi + 21,
			zc + 2,
			"px_smooth_stone",
			TORII_RED,
			f
		)
		box(
			"ToriiNuki",
			S.x0 - 7,
			hi + 15,
			zc - 1,
			S.x1 + 7,
			hi + 17,
			zc + 1,
			"px_smooth_stone",
			TORII_RED,
			f
		)
		box(
			"ToriiTablet",
			cx - 2,
			hi + 17,
			zc - 0.8,
			cx + 2,
			hi + 19,
			zc + 0.8,
			"px_white_wool",
			INK,
			f
		)
		box(
			"ToriiShimaki",
			S.x0 - 8,
			hi + 19,
			zc - 1.5,
			S.x1 + 8,
			hi + 21,
			zc + 1.5,
			"px_smooth_stone",
			TORII_RED,
			f
		)
		box(
			"ToriiKasagi",
			S.x0 - 10,
			hi + 21,
			zc - 2,
			S.x1 + 10,
			hi + 23,
			zc + 2,
			"px_white_wool",
			INK,
			f
		)
		box(
			"ToriiKasagiEnd",
			S.x0 - 12,
			hi + 22,
			zc - 2,
			S.x0 - 8,
			hi + 25,
			zc + 2,
			"px_white_wool",
			INK,
			f
		)
		box(
			"ToriiKasagiEnd",
			S.x1 + 8,
			hi + 22,
			zc - 2,
			S.x1 + 12,
			hi + 25,
			zc + 2,
			"px_white_wool",
			INK,
			f
		)
	end
	-- the kitsune guarding the foot and the top
	fox(S.x0 - 7.2, 0, 8, st)
	fox(S.x1 + 7.2, 0, 8, st)
	fox(S.x0 - 7.2, L2_Y, -77, st)
	fox(S.x1 + 7.2, L2_Y, -77, st)
end
task.wait()

-- ================================================================ the temple hall on L2
do
	local hall = folder("Hall", temple)
	local T = TEMPLE
	local FY = L2_Y + 1 -- the hall floor, one stud above the court
	local WT = 53 -- the top of the walls, where the roof starts
	fillTo(56, -128, 176, -72, L2_Y, hall)
	box("HallFloor", T.x0, L2_Y - 1, T.z0, T.x1, FY, T.z1, "px_spruce_planks", nil, hall)
	-- the walls: back, sides, the front with shoji bays and the open middle bay
	box("WallFoot", 72, FY, -120, 168, FY + 4, -116, "px_dark_oak_planks", nil, hall)
	box("Plaster", 72, FY + 4, -120, 168, WT, -116, "px_white_wool", PAPER, hall)
	for _, sx in ipairs({ 72, 164 }) do
		box("WallFoot", sx, FY, -116, sx + 4, FY + 4, -92, "px_dark_oak_planks", nil, hall)
		box("Plaster", sx, FY + 4, -116, sx + 4, WT, -92, "px_white_wool", PAPER, hall)
		box("Nageshi", sx - 0.5, 45, -120.5, sx + 4.5, 47, -91.5, "px_dark_oak_planks", nil, hall)
	end
	box("Nageshi", 71.5, 45, -120.5, 168.5, 47, -115.5, "px_dark_oak_planks", nil, hall)
	box("Plaster", 72, 47, -92, 168, WT, -88, "px_white_wool", PAPER, hall)
	box("Nageshi", 71, 45, -93, 169, 47, -87, "px_dark_oak_planks", nil, hall)
	for _, bay in ipairs({ { 76, 86 }, { 90, 102 }, { 138, 150 }, { 154, 164 } }) do
		box("Shoji", bay[1], FY, -91, bay[2], 45, -89, "px_white_wool", PAPER, hall)
		decor(box("ShojiBar", bay[1], 38.6, -89, bay[2], 39.4, -88.6, nil, DARK_WOOD, hall))
		local mx = (bay[1] + bay[2]) / 2
		decor(box("ShojiBar", mx - 0.4, FY, -89, mx + 0.4, 45, -88.6, nil, DARK_WOOD, hall))
	end
	for _, x in ipairs({ 74, 88, 104, 136, 152, 166 }) do
		box("HallPost", x - 2, FY, -93, x + 2, WT, -87, "px_dark_oak_planks", nil, hall)
	end
	for _, x in ipairs({ 74, 104, 136, 166 }) do
		box("HallPost", x - 2, FY, -121, x + 2, WT, -115, "px_dark_oak_planks", nil, hall)
	end
	for _, x in ipairs({ 71, 165 }) do
		box("HallPost", x, FY, -106, x + 4, WT, -102, "px_dark_oak_planks", nil, hall)
	end
	-- the red posts along the veranda
	for k = 0, 9 do
		local x = 66 + 12 * k
		box("VerandaPost", x - 2, FY, -80, x + 2, WT, -76, "px_smooth_stone", TORII_RED, hall)
	end
	box("VerandaBeam", T.x0, WT - 3, -80, T.x1, WT, -76, "px_smooth_stone", TORII_RED, hall)
	-- inside: the altar with offerings, a bell rope at the entrance, two hanging lanterns
	box("Altar", 108, FY, -116, 132, FY + 4, -110, "px_dark_oak_planks", nil, hall)
	box("AltarTop", 107, FY + 4, -116, 133, FY + 5, -109, "px_spruce_planks", DARK_WOOD, hall)
	cube("OfferingBox", 120, FY + 6.5, -111.5, 4, 3, 3, "px_gold_block", nil, hall)
	decor(cube("Mirror", 120, FY + 9.5, -114, 3, 3, 0.6, "px_gold_block", nil, hall))
	decor(cube("MirrorStand", 120, FY + 6.5, -114, 1, 3, 1, "px_dark_oak_planks", nil, hall))
	for _, x in ipairs({ 110, 130 }) do
		paperLantern(x, FY + 11, -113, PAPER, hall, false)
		decor(cube("LanternStand", x, FY + 7, -113, 0.6, 4, 0.6, "px_dark_oak_planks", nil, hall))
	end
	banner(at(120, FY + 13, -115.8), TORII_RED, hall, PAPER, 2 * B, 3 * B)
	decor(cube("BellSuzu", 120, 43, -89, 2.4, 2.4, 2.4, "px_gold_block", nil, hall))
	decor(cube("BellRope", 120, 38, -89, 0.6, 8, 0.6, "px_white_wool", TORII_RED, hall))
	decor(cube("BellRope", 120.7, 38, -89, 0.6, 8, 0.6, "px_white_wool", PAPER, hall))
	for _, x in ipairs({ 92, 148 }) do
		lantern(V(x, 44, -104), hall, false, BY + WT)
		lights += 1
	end
	-- the roof: a stepped hip of dark tiles (thin flared eaves, steeper above), the ridge, the corner tips
	local LAYERS = { { 0, 2 }, { 4, 2 }, { 8, 3 }, { 12, 3 }, { 16, 4 }, { 20, 4 }, { 24, 4 } }
	local y = WT
	local ys = {}
	for i, l in ipairs(LAYERS) do
		local d = l[1]
		ys[i] = y
		box("HallRoof", 60 + d, y, -128 + d, 180 - d, y + l[2], -72 - d, ROOF_V, ROOF_DARK, hall)
		y += l[2]
	end
	box("Ridge", 82, y, -102, 158, y + 3, -98, "px_white_wool", INK, hall)
	box("RidgeEnd", 78, y + 1, -103, 84, y + 6, -97, "px_white_wool", INK, hall)
	box("RidgeEnd", 156, y + 1, -103, 162, y + 6, -97, "px_white_wool", INK, hall)
	roofTips(60, -128, 180, -72, WT + 2, ROOF_DARK, hall)
	-- the south cross-gable: a north-south stepped roof over the middle bays with a white plaster face
	for k = 0, 5 do
		local l = LAYERS[k + 1]
		box(
			"GableRoof",
			96 + 4 * k,
			ys[k + 1],
			-100,
			144 - 4 * k,
			ys[k + 1] + l[2],
			-70,
			ROOF_V,
			ROOF_DARK,
			hall
		)
		if k >= 1 then
			box(
				"GableFace",
				96 + 4 * k,
				WT,
				-75,
				144 - 4 * k,
				ys[k + 1],
				-73,
				"px_white_wool",
				PAPER,
				hall
			)
		end
	end
	box("GableTip", 92, WT + 2, -72, 98, WT + 5, -68, ROOF_V, ROOF_DARK, hall)
	box("GableTip", 142, WT + 2, -72, 148, WT + 5, -68, ROOF_V, ROOF_DARK, hall)
	box("GableTrim", 99, WT, -73.5, 141, WT + 1.5, -72.5, "px_dark_oak_planks", nil, hall)
	decor(box("GableCrest", 118, ys[6] - 5, -73, 122, ys[6] - 1, -72.4, "px_gold_block", nil, hall))
	-- stone lanterns by the east side of the hall
	for _, z in ipairs({ -84, -116 }) do
		if onIsland(182, z, 10) and cellY(182, z) == L2_Y then
			stoneLantern(182, L2_Y, z, hall, true)
		end
	end
end
task.wait()

-- ================================================================ the stage on its log stilts
do
	local stage = folder("Stage", temple)
	local S = STAGE
	local DY = S.y + 0.1 -- the deck top (a hair over the L2 court so the faces never fight)
	for z = S.z0, S.z1 - 8, 8 do
		local tint = if (z // 8) % 2 == 0 then nil else Color3.fromRGB(232, 222, 210)
		box("Deck", S.x0, S.y - 2, z, S.x1, DY, z + 8, "px_spruce_planks", tint, stage)
	end
	-- the stilts: 1×1-block logs every 2 blocks from the ground (L0) up to the deck, stone feet
	local nStilts = 0
	for i = 0, 12 do
		local x = 76 + 8 * i
		for k = 0, 6 do
			local z = -20 - 8 * k
			local gy = cellY(x, z)
			if gy < S.y - 4 then
				box(
					"Stilt",
					x - 2,
					gy - 1,
					z - 2,
					x + 2,
					S.y - 2,
					z + 2,
					"px_dark_oak_log",
					nil,
					stage
				)
				box(
					"StiltFoot",
					x - 2.6,
					gy - 0.5,
					z - 2.6,
					x + 2.6,
					gy + 1.5,
					z + 2.6,
					"px_stone_bricks",
					STONE,
					stage
				)
				nStilts += 1
			end
		end
	end
	-- the tie beams: one long box per row and level (y 6, 14, 22), a cap row under the deck along x
	for k = 0, 6 do
		local z = -20 - 8 * k
		for _, h in ipairs({ 6, 14, 22, 28 }) do
			box("TieBeam", S.x0, h, z - 1, S.x1, h + 2, z + 1, "px_dark_oak_planks", nil, stage)
		end
	end
	for i = 0, 12 do
		local x = 76 + 8 * i
		for _, h in ipairs({ 6, 14, 22 }) do
			box("TieBeam", x - 1, h, S.z0, x + 1, h + 2, S.z1, "px_dark_oak_planks", nil, stage)
		end
	end
	-- the railing on the open sides (south, west, east); the north side stays open to the hall
	local RAIL = "px_dark_oak_planks"
	for x = S.x0 + 1, S.x1 - 1, 8 do
		box("RailPost", x - 1, DY, S.z1 - 2, x + 1, DY + 4.4, S.z1, RAIL, nil, stage)
	end
	box("RailPost", S.x1 - 2, DY, S.z1 - 2, S.x1, DY + 4.4, S.z1, RAIL, nil, stage)
	for z = S.z1 - 9, S.z0, -8 do
		box("RailPost", S.x0, DY, z - 1, S.x0 + 2, DY + 4.4, z + 1, RAIL, nil, stage)
		box("RailPost", S.x1 - 2, DY, z - 1, S.x1, DY + 4.4, z + 1, RAIL, nil, stage)
	end
	box("RailTop", S.x0, DY + 3.4, S.z1 - 2.3, S.x1, DY + 4.6, S.z1 + 0.3, RAIL, nil, stage)
	box("RailMid", S.x0, DY + 1.6, S.z1 - 1.6, S.x1, DY + 2.4, S.z1 - 0.4, RAIL, nil, stage)
	for _, x0 in ipairs({ S.x0, S.x1 - 2 }) do
		box("RailTop", x0 - 0.3, DY + 3.4, S.z0, x0 + 2.3, DY + 4.6, S.z1, RAIL, nil, stage)
		box("RailMid", x0 + 0.4, DY + 1.6, S.z0, x0 + 1.6, DY + 2.4, S.z1, RAIL, nil, stage)
	end
	-- paper lanterns hung out over the south edge on short brackets
	for i, x in ipairs({ 88, 112, 136, 160 }) do
		decor(
			box(
				"LanternArm",
				x - 0.4,
				DY + 3.4,
				S.z1,
				x + 0.4,
				DY + 4.2,
				S.z1 + 2.4,
				RAIL,
				nil,
				stage
			)
		)
		paperLantern(
			x,
			DY + 3.4,
			S.z1 + 2,
			if i % 2 == 0 then PAPER else TORII_RED,
			stage,
			i == 2 or i == 3
		)
	end
	print(("[build-kyoto] temple: stage stilts %d"):format(nStilts))
end
task.wait()

-- ================================================================ three waterfalls from under the stage into the pond
do
	local falls = folder("Waterfalls", temple)
	local function water(p)
		p.Transparency = 0.3
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	for _, c in ipairs({ 108, 124, 140 }) do
		local inWater = cellY(c, -11) == POND.bed
		local foot = if inWater then -1 else 0.2
		-- the rock mouth under the deck edge, moss over it
		box("SpoutRock", c - 6, 26, -18, c + 6, 30, -12, "px_mossy_stone_bricks", nil, falls)
		box("SpoutRock", c - 8, 22, -17, c - 3, 26, -13, "px_mossy_cobblestone", nil, falls)
		box("SpoutRock", c + 3, 23, -17, c + 8, 26, -14, "px_mossy_cobblestone", nil, falls)
		decor(box("Moss", c - 6.3, 28, -12.3, c + 6.3, 30.2, -11.8, "px_hedge", LEAF_C, falls))
		water(box("FallLip", c - 3, 25, -16, c + 3, 26.2, -11.4, "px_water", WATER_C, falls))
		water(box("Waterfall", c - 3, foot, -11.6, c + 3, 26, -10, "px_water", WATER_C, falls))
		-- the side falls land on the bank and run to the pond in a short stream
		if not inWater then
			local zEnd = -8
			for zc = -8, 8, 8 do
				if cellY(c, zc + 4) == POND.bed then
					zEnd = zc
					break
				end
			end
			water(box("Stream", c - 3, 0, -10, c + 3, 0.35, zEnd, "px_water", WATER_C, falls))
			box("StreamBank", c - 5, -0.5, -12, c - 3, 1, zEnd, "px_mossy_cobblestone", nil, falls)
			box("StreamBank", c + 3, -0.5, -12, c + 5, 1, zEnd, "px_mossy_cobblestone", nil, falls)
		end
		local foam =
			decor(box("Foam", c - 4, foot, -13, c + 4, foot + 0.4, -7, "px_white_wool", nil, falls))
		foam.Transparency = 0.35
		foam.CastShadow = false
		local spray =
			decor(part("Splash", Vector3.new(6, 1, 3), at(c, foot + 0.5, -10.8), nil, nil, falls))
		spray.Transparency = 1
		emitter(spray, {
			Rate = 10,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(50, 50),
			Acceleration = Vector3.new(0, -14, 0),
			Size = NumberSequence.new(0.8, 1.6),
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new(0.3, 1),
		})
		emitter(spray, {
			Rate = 3,
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(70, 70),
			Size = NumberSequence.new(4, 9),
			Color = ColorSequence.new(Color3.fromRGB(235, 245, 250)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end
end
task.wait()

-- ================================================================ the koi pond: edges, lilies, koi, reeds, the bridge, the shrine
do
	local pond = folder("Pond", temple)
	local NO_RIM = { { 72, 14, 176, 34 }, { 104, -16, 112, -8 }, { 136, -16, 144, -8 } }
	local function isPond(cx, cz)
		return groundY(cx, cz) == POND.bed
	end
	-- the stone and moss edge on every bank cell next to the water
	local EDGE =
		{ "px_stone_bricks", "px_mossy_stone_bricks", "px_cobblestone", "px_mossy_stone_bricks" }
	local nRim = 0
	for z = -16, 64, 8 do
		for x = 80, 168, 8 do
			local cx, cz = x + 4, z + 4
			local skip = cz > 64 or isPond(cx, cz) or cellY(cx, cz) ~= 0
			for _, r in ipairs(NO_RIM) do
				skip = skip or inRect(cx, cz, r)
			end
			if
				not skip
				and (
					isPond(cx + 8, cz)
					or isPond(cx - 8, cz)
					or isPond(cx, cz + 8)
					or isPond(cx, cz - 8)
				)
			then
				local v = pick(EDGE)
				box(
					"PondEdge",
					x,
					-0.4,
					z,
					x + 8,
					0.5,
					z + 8,
					v,
					if v == "px_stone_bricks" then STONE else nil,
					pond
				)
				if rng:NextNumber() < 0.5 then
					local qx, qz = x + rng:NextInteger(0, 1) * 4, z + rng:NextInteger(0, 1) * 4
					box(
						"PondRock",
						qx,
						0,
						qz,
						qx + 4,
						rng:NextInteger(2, 4),
						qz + 4,
						pick({ "px_mossy_cobblestone", "px_stone" }),
						nil,
						pond
					)
				elseif rng:NextNumber() < 0.6 then
					-- reeds and irises
					for _ = 1, 3 do
						local rx, rz = x + 1 + rng:NextNumber() * 6, z + 1 + rng:NextNumber() * 6
						local h = 2 + rng:NextNumber() * 2
						decor(
							cube("Reed", rx, 0.5 + h / 2, rz, 0.6, h, 0.6, "px_hedge", LEAF_C, pond)
						)
						if rng:NextNumber() < 0.5 then
							decor(
								cube(
									"Iris",
									rx,
									0.5 + h + 0.4,
									rz,
									0.9,
									0.8,
									0.9,
									"px_white_wool",
									Color3.fromRGB(130, 90, 200),
									pond
								)
							)
						end
					end
				end
				nRim += 1
			end
		end
	end
	-- flat stepping stones along the south-west shore
	for i = 0, 4 do
		local a = math.rad(110 + i * 14)
		local sx, sz = POND.x + math.cos(a) * (POND.r - 8), POND.z + math.sin(a) * (POND.r - 8)
		if cellY(sx, sz) == POND.bed then
			box(
				"SteppingStone",
				sx - 2,
				-1.6,
				sz - 2,
				sx + 2,
				-0.4,
				sz + 2,
				"px_smooth_stone",
				STONE,
				pond
			)
		end
	end
	-- lily pads (some in bloom) and koi under the surface
	local function inWater(x, z, pad)
		return inPond(x, z, -pad) and cellY(x, z) == POND.bed and not (z > 12 and z < 36)
	end
	local nLily = 0
	for _ = 1, 60 do
		if nLily >= 16 then
			break
		end
		local x, z = POND.x + rng:NextInteger(-30, 30), POND.z + rng:NextInteger(-30, 30)
		if inWater(x, z, 5) then
			decor(
				cube(
					"LilyPad",
					x,
					-0.9,
					z,
					2.6,
					0.2,
					2.6,
					"px_hedge",
					Color3.fromRGB(80, 140, 60),
					pond
				)
			)
			if rng:NextNumber() < 0.35 then
				decor(
					cube(
						"LilyFlower",
						x + 0.4,
						-0.5,
						z - 0.3,
						0.8,
						0.6,
						0.8,
						"px_white_wool",
						SAKURA,
						pond
					)
				)
			end
			nLily += 1
		end
	end
	local KOI = {
		{ Color3.fromRGB(240, 120, 40), Color3.fromRGB(250, 250, 245) },
		{ Color3.fromRGB(250, 250, 245), Color3.fromRGB(235, 100, 30) },
		{ Color3.fromRGB(250, 250, 245), Color3.fromRGB(30, 30, 34) },
		{ Color3.fromRGB(235, 110, 35), Color3.fromRGB(30, 30, 34) },
	}
	local nKoi = 0
	for _ = 1, 80 do
		if nKoi >= 10 then
			break
		end
		local x, z = POND.x + rng:NextInteger(-28, 28), POND.z + rng:NextInteger(-28, 28)
		if inWater(x, z, 6) then
			local c = KOI[nKoi % #KOI + 1]
			local cf = at(x, -1.7, z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
			textured(
				decor(part("Koi", Vector3.new(2.4, 0.7, 1), cf, nil, nil, pond)),
				"px_white_wool",
				c[1]
			)
			textured(
				decor(
					part(
						"KoiPatch",
						Vector3.new(0.9, 0.75, 1.05),
						cf * CFrame.new(0.5, 0, 0),
						nil,
						nil,
						pond
					)
				),
				"px_white_wool",
				c[2]
			)
			textured(
				decor(
					part(
						"KoiTail",
						Vector3.new(0.6, 0.5, 0.9),
						cf * CFrame.new(-1.5, 0, 0),
						nil,
						nil,
						pond
					)
				),
				"px_white_wool",
				c[1]
			)
			nKoi += 1
		end
	end
	task.wait()

	-- the red arched bridge: stepped deck segments (≤ 1.1 stud apart) with a plank walkway, red rails, invisible
	-- chord ramps over the step noses so it walks like a slope
	local br = folder("Bridge", pond)
	local X0, X1, ZC = 76, 172, POND.z
	local N = (X1 - X0) // 4
	local tops = {}
	for i = 0, N - 1 do
		local xc = X0 + 4 * i + 2
		local t = 6 * (1 - ((xc - 124) / 48) ^ 2)
		t = math.max(0.4, math.floor(t * 5 + 0.5) / 5)
		tops[i] = t
		local xa = X0 + 4 * i
		box("BridgeDeck", xa, t - 2.5, ZC - 8, xa + 4, t, ZC + 8, "px_planks", TORII_RED, br)
		box(
			"BridgeWalk",
			xa,
			t - 0.4,
			ZC - 6,
			xa + 4,
			t + 0.05,
			ZC + 6,
			"px_spruce_planks",
			nil,
			br
		)
		for _, s in ipairs({ -1, 1 }) do
			box(
				"BridgeRail",
				xa,
				t + 3.4,
				ZC + s * 7 - 0.6,
				xa + 4,
				t + 4.2,
				ZC + s * 7 + 0.6,
				"px_planks",
				TORII_RED,
				br
			)
		end
	end
	for k = 0, N // 2 do
		local x = X0 + 8 * k
		local i0, i1 = math.clamp(2 * k - 1, 0, N - 1), math.clamp(2 * k, 0, N - 1)
		local t = math.max(tops[i0], tops[i1])
		for _, s in ipairs({ -1, 1 }) do
			local px = math.clamp(x, X0 + 1, X1 - 1)
			box(
				"BridgePost",
				px - 1,
				t - 0.5,
				ZC + s * 7 - 1,
				px + 1,
				t + 4.6,
				ZC + s * 7 + 1,
				"px_planks",
				TORII_RED,
				br
			)
			if k == 0 or k == N // 2 then
				cube("BridgeCap", px, t + 5.2, ZC + s * 7, 1.6, 1.2, 1.6, "px_gold_block", nil, br)
			end
		end
	end
	local pts = { { X0 - 4, 0 } }
	for i = 0, N - 1 do
		local xc = X0 + 4 * i + 2
		table.insert(pts, { if xc < 124 then X0 + 4 * i else X0 + 4 * i + 4, tops[i] })
	end
	table.insert(pts, { X1 + 4, 0 })
	for i = 1, #pts - 1 do
		local a, b = V(pts[i][1], pts[i][2], ZC), V(pts[i + 1][1], pts[i + 1][2], ZC)
		local ramp = part(
			"BridgeRamp",
			Vector3.new(12, 1, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.5, 0),
			nil,
			nil,
			br
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
	end
	-- gravel paths: from the square to the bridge, from the square along the north bank, east to the shrine
	box("GravelPath", 72, -0.2, ZC - 6, X0, 0.15, ZC + 6, "px_gravel", nil, pond)
	box("GravelPath", X1, -0.2, ZC - 6, 186, 0.15, ZC + 6, "px_gravel", nil, pond)
	box("GravelPath", 72, -0.2, -8, 96, 0.15, 0, "px_gravel", nil, pond)
	for _, p in ipairs({ { 74, ZC - 12 }, { 74, ZC + 12 }, { 174, ZC - 12 }, { 174, ZC + 12 } }) do
		stoneLantern(p[1], 0, p[2], br, true)
	end
	task.wait()

	-- the little shrine on the east bank (facing the bridge) and the ghost of the samurai's beloved
	local sh = folder("Shrine", pond)
	local SX, SZ = 194, ZC
	box("ShrineBase", SX - 6, -0.5, SZ - 6, SX + 6, 1, SZ + 6, "px_stone_bricks", STONE, sh)
	box("ShrineBody", SX - 2, 1, SZ - 4, SX + 4, 8, SZ + 4, "px_dark_oak_planks", nil, sh)
	decor(box("ShrineDoor", SX - 2.2, 2, SZ - 3, SX - 2, 7, SZ + 3, "px_white_wool", PAPER, sh))
	decor(box("ShrineDoorBar", SX - 2.4, 2, SZ - 0.3, SX - 2.1, 7, SZ + 0.3, nil, DARK_WOOD, sh))
	for _, s in ipairs({ -1, 1 }) do
		box(
			"ShrinePost",
			SX - 5,
			1,
			SZ + s * 4 - 1,
			SX - 3,
			9,
			SZ + s * 4 + 1,
			"px_smooth_stone",
			TORII_RED,
			sh
		)
		paperLantern(SX - 4, 9, SZ + s * 2.2, PAPER, sh, true)
	end
	box("ShrineRoof", SX - 7, 9, SZ - 7, SX + 7, 10, SZ + 7, ROOF_V, ROOF_DARK, sh)
	box("ShrineRoof", SX - 5, 10, SZ - 5, SX + 5, 11.5, SZ + 5, ROOF_V, ROOF_DARK, sh)
	box("ShrineRidge", SX - 1, 11.5, SZ - 5, SX + 1, 13, SZ + 5, "px_white_wool", INK, sh)
	roofTips(SX - 7, SZ - 7, SX + 7, SZ + 7, 10, ROOF_DARK, sh, 2)
	box("OfferingTable", SX - 5, 1, SZ - 1.5, SX - 3, 2.6, SZ + 1.5, "px_dark_oak_planks", nil, sh)
	decor(cube("Offering", SX - 4, 3.2, SZ, 1.2, 1.2, 1.2, "px_gold_block", nil, sh))
	local gx, gz = 184, ZC + 12
	local ghost = {
		{ "GhostRobe", Vector3.new(1.8, 4.2, 1.4), Vector3.new(0, 2.6, 0), PAPER },
		{ "GhostBody", Vector3.new(1.4, 1.8, 1), Vector3.new(0, 5.6, 0), PAPER },
		{
			"GhostHead",
			Vector3.new(1.3, 1.3, 1.3),
			Vector3.new(0, 7.2, 0),
			Color3.fromRGB(250, 250, 255),
		},
		{ "GhostHair", Vector3.new(1.4, 3, 0.4), Vector3.new(0, 6.4, 0.75), INK },
		{ "GhostSleeve", Vector3.new(2.6, 0.8, 0.9), Vector3.new(0, 5.4, -0.4), PAPER },
	}
	local gcf = CFrame.lookAt(V(gx, 0, gz), V(POND.x, 0, POND.z)) -- -Z (her face) toward the water
	for _, g in ipairs(ghost) do
		local p = textured(
			decor(part(g[1], g[2], gcf * CFrame.new(g[3]), nil, nil, sh)),
			"px_white_wool",
			g[4]
		)
		p.Transparency = if g[1] == "GhostHair" then 0.4 else 0.5
		p.CastShadow = false
	end
	print(("[build-kyoto] temple: pond edge cells %d, lilies %d, koi %d"):format(nRim, nLily, nKoi))
end
task.wait()

-- ================================================================ under the stage: moss rocks and bamboo beside it
do
	local under = folder("UnderStage", temple)
	for i = 0, 11 do
		for k = 0, 5 do
			local x, z = 80 + 8 * i, -24 - 8 * k
			if rng:NextNumber() < 0.16 and cellY(x, z) == 0 then
				box(
					"MossRock",
					x - 2,
					-0.5,
					z - 2,
					x + 2,
					rng:NextInteger(2, 4),
					z + 2,
					pick({ "px_mossy_cobblestone", "px_mossy_stone_bricks" }),
					nil,
					under
				)
				if rng:NextNumber() < 0.5 then
					decor(
						box(
							"Fern",
							x - 1.5,
							0,
							z + 2,
							x + 1.5,
							1.6,
							z + 3.2,
							"px_hedge",
							LEAF_C,
							under
						)
					)
				end
			end
		end
	end
	local nb = 0
	for _, c in ipairs({
		{ 62, -62 },
		{ 62, -44 },
		{ 62, -26 },
		{ 186, -62 },
		{ 194, -44 },
		{ 186, -26 },
		{ 204, -58 },
		{ 204, -30 },
	}) do
		nb += bambooClump(c[1], c[2], under)
	end
	print(("[build-kyoto] temple: bamboo stalks by the stage %d"):format(nb))
end
task.wait()

-- ================================================================ the five-storey pagoda (hero) on L2
do
	local pg = folder("Pagoda", temple)
	local px, pz = PAGODA.x, PAGODA.z + 4 -- nudged 4 studs in, away from the island rim
	box(
		"PagodaPlatform",
		px - 18,
		L2_Y - 4,
		pz - 18,
		px + 18,
		L2_Y + 2,
		pz + 18,
		"px_stone_bricks",
		STONE,
		pg
	)
	box(
		"PagodaKerb",
		px - 18.5,
		L2_Y + 1.6,
		pz - 18.5,
		px + 18.5,
		L2_Y + 2.2,
		pz + 18.5,
		"px_smooth_stone",
		STONE,
		pg
	)
	box(
		"PagodaStep",
		px - 8,
		L2_Y - 1,
		pz + 18,
		px + 8,
		L2_Y + 1,
		pz + 22,
		"px_stone_bricks",
		STONE,
		pg
	)
	local y = L2_Y + 2
	for i, h in ipairs({ 14, 12, 10, 8, 6 }) do
		local wallH = if i == 1 then 12 else 8
		box("PagodaWall", px - h, y, pz - h, px + h, y + wallH, pz + h, "px_white_wool", PAPER, pg)
		box(
			"PagodaSill",
			px - h - 0.5,
			y,
			pz - h - 0.5,
			px + h + 0.5,
			y + 1.5,
			pz + h + 0.5,
			"px_dark_oak_planks",
			nil,
			pg
		)
		box(
			"PagodaBand",
			px - h - 0.5,
			y + wallH - 2,
			pz - h - 0.5,
			px + h + 0.5,
			y + wallH,
			pz + h + 0.5,
			"px_smooth_stone",
			TORII_RED,
			pg
		)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				box(
					"PagodaPost",
					px + sx * (h + 1),
					y,
					pz + sz * (h + 1),
					px + sx * (h - 3),
					y + wallH,
					pz + sz * (h - 3),
					"px_smooth_stone",
					TORII_RED,
					pg
				)
			end
		end
		-- a door on the south of the ground floor, red lattice windows elsewhere
		local dh = if i == 1 then 8 else 4
		local dw = if i == 1 then 3 else 2
		decor(
			box(
				"PagodaDoor",
				px - dw,
				y + 1.5,
				pz + h,
				px + dw,
				y + 1.5 + dh,
				pz + h + 0.3,
				"px_dark_oak_planks",
				nil,
				pg
			)
		)
		decor(
			box(
				"PagodaWindow",
				px - dw,
				y + 2,
				pz - h - 0.3,
				px + dw,
				y + 2 + dh * 0.75,
				pz - h,
				"px_smooth_stone",
				TORII_RED,
				pg
			)
		)
		decor(
			box(
				"PagodaWindow",
				px - h - 0.3,
				y + 2,
				pz - dw,
				px - h,
				y + 2 + dh * 0.75,
				pz + dw,
				"px_smooth_stone",
				TORII_RED,
				pg
			)
		)
		decor(
			box(
				"PagodaWindow",
				px + h,
				y + 2,
				pz - dw,
				px + h + 0.3,
				y + 2 + dh * 0.75,
				pz + dw,
				"px_smooth_stone",
				TORII_RED,
				pg
			)
		)
		-- the roof: two wide dark layers, the up-turned tips, paper lanterns at the eave corners
		local r = y + wallH
		box(
			"PagodaRoof",
			px - h - 8,
			r,
			pz - h - 8,
			px + h + 8,
			r + 2,
			pz + h + 8,
			ROOF_V,
			ROOF_DARK,
			pg
		)
		box(
			"PagodaRoof",
			px - h - 4,
			r + 2,
			pz - h - 4,
			px + h + 4,
			r + 4,
			pz + h + 4,
			ROOF_V,
			ROOF_DARK,
			pg
		)
		roofTips(px - h - 8, pz - h - 8, px + h + 8, pz + h + 8, r + 2, ROOF_DARK, pg)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				paperLantern(
					px + sx * (h + 5),
					r,
					pz + sz * (h + 5),
					if i % 2 == 0 then TORII_RED else PAPER,
					pg,
					false
				)
			end
		end
		y = r + 4
	end
	-- the top: a stepped cap and the gold spire (sorin) with its rings
	box("PagodaCap", px - 6, y, pz - 6, px + 6, y + 2, pz + 6, ROOF_V, ROOF_DARK, pg)
	box("PagodaCap", px - 4, y + 2, pz - 4, px + 4, y + 4, pz + 4, ROOF_V, ROOF_DARK, pg)
	box("PagodaCap", px - 2, y + 4, pz - 2, px + 2, y + 6, pz + 2, "px_iron_block", nil, pg)
	box("Sorin", px - 0.7, y + 6, pz - 0.7, px + 0.7, y + 30, pz + 0.7, "px_iron_block", nil, pg)
	for k = 0, 6 do
		cube(
			"SorinRing",
			px,
			y + 10 + 2 * k,
			pz,
			3 - k * 0.2,
			0.6,
			3 - k * 0.2,
			"px_gold_block",
			nil,
			pg
		)
	end
	cube("SorinFlame", px, y + 26, pz, 2, 2.6, 2, "px_gold_block", nil, pg)
	cube("SorinJewel", px, y + 30.7, pz, 1.4, 1.4, 1.4, "px_gold_block", nil, pg)
	-- stone lanterns by the steps and at the back corners
	for _, p in ipairs({
		{ px - 12, pz + 22 },
		{ px + 12, pz + 22 },
		{ px - 22, pz - 16 },
		{ px + 22, pz - 16 },
	}) do
		if onIsland(p[1], p[2], 10) and cellY(p[1], p[2]) == L2_Y then
			stoneLantern(p[1], L2_Y, p[2], pg, true)
		end
	end
	print(("[build-kyoto] temple: pagoda top y %.1f"):format(y + 31.4))
end
task.wait()

-- ================================================================ the east bailey: paths, the bell tower, lanterns
do
	local bailey = folder("Bailey", temple)
	local function path(x0, z0, x1, z1)
		box("StonePath", x0, L2_Y - 0.2, z0, x1, L2_Y + 0.15, z1, "px_stone_bricks", STONE, bailey)
	end
	path(56, -164, 64, -72) -- from the arena side along the hall to the pagoda yard
	path(64, -160, 92, -152)
	path(104, -134, 116, -124) -- behind the hall to the pagoda steps
	stoneLantern(100, L2_Y, -130, bailey, true)
	stoneLantern(120, L2_Y, -130, bailey, true)
	-- the bell tower (shōrō): stone base, four red posts, the bronze bell, a stepped roof
	local bx, bz = 150, -140
	box(
		"BellBase",
		bx - 8,
		L2_Y - 1,
		bz - 8,
		bx + 8,
		L2_Y + 1.5,
		bz + 8,
		"px_stone_bricks",
		STONE,
		bailey
	)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			box(
				"BellPost",
				bx + sx * 5,
				L2_Y + 1.5,
				bz + sz * 5,
				bx + sx * 7,
				L2_Y + 14,
				bz + sz * 7,
				"px_smooth_stone",
				TORII_RED,
				bailey
			)
		end
	end
	box(
		"BellBeam",
		bx - 7,
		L2_Y + 12,
		bz - 1,
		bx + 7,
		L2_Y + 14,
		bz + 1,
		"px_dark_oak_planks",
		nil,
		bailey
	)
	box(
		"Bell",
		bx - 2.5,
		L2_Y + 5,
		bz - 2.5,
		bx + 2.5,
		L2_Y + 11,
		bz + 2.5,
		"px_iron_block",
		BRONZE,
		bailey
	)
	box(
		"BellLip",
		bx - 3,
		L2_Y + 4.4,
		bz - 3,
		bx + 3,
		L2_Y + 5.4,
		bz + 3,
		"px_iron_block",
		BRONZE,
		bailey
	)
	decor(
		box(
			"BellHanger",
			bx - 0.5,
			L2_Y + 11,
			bz - 0.5,
			bx + 0.5,
			L2_Y + 12,
			bz + 0.5,
			nil,
			INK,
			bailey
		)
	)
	decor(
		box(
			"BellStriker",
			bx - 7,
			L2_Y + 8,
			bz - 0.5,
			bx - 3.4,
			L2_Y + 9,
			bz + 0.5,
			"px_dark_oak_log",
			nil,
			bailey
		)
	)
	local ry = L2_Y + 14
	for k, half in ipairs({ 12, 9, 6, 3 }) do
		box(
			"BellRoof",
			bx - half,
			ry,
			bz - half,
			bx + half,
			ry + 2,
			bz + half,
			ROOF_V,
			ROOF_DARK,
			bailey
		)
		if k == 1 then
			roofTips(bx - half, bz - half, bx + half, bz + half, ry + 2, ROOF_DARK, bailey, 3)
		end
		ry += 2
	end
	cube("BellFinial", bx, ry + 1, bz, 1.6, 2, 1.6, "px_gold_block", nil, bailey)
end
task.wait()

-- ================================================================ cherry trees and bamboo over the rest of the zone
do
	local grove = folder("Grove", temple)
	local nTrees, nClumps = 0, 0
	local placed = {}
	local function roomy(x, z, hw)
		for _, t in ipairs(placed) do
			if math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2) < (hw + t[3]) * 0.8 then
				return false
			end
		end
		return true
	end
	for x = 60, 228, 20 do
		for z = -228, 60, 20 do
			local tx, tz = snap(x + rng:NextInteger(-6, 6)), snap(z + rng:NextInteger(-6, 6))
			local size = rng:NextInteger(5, 7)
			local hw = size * B / 2
			local ok = zoneOf(tx, tz) == "temple"
				and freeGround(tx, tz, 4)
				and not (tx < 76 + hw and tz > -12 - hw) -- the square
				and not (tx < 76 and tz > -80 and tz < -8) -- the bamboo strip under the L1 cliff
				and not inRect(tx, tz, { STAGE.x0, STAGE.z0, STAGE.x1, STAGE.z1 }, hw + 2)
				and not blocked(tx, tz, hw)
				and onIsland(tx, tz, 10 + hw / 2)
				and tx - hw >= 56
				and tz + hw <= 64
				and roomy(tx, tz, hw)
			if ok then
				if rng:NextNumber() < 0.2 then
					if flat(tx, tz, 6) and bambooClump(tx, tz, grove) > 0 then
						nClumps += 1
						table.insert(placed, { tx, tz, 8 })
					end
				elseif nTrees < 44 and flat(tx, tz, hw) then
					cherry(tx, tz, size, grove)
					nTrees += 1
					table.insert(placed, { tx, tz, hw })
				end
			end
		end
		task.wait()
	end
	print(
		("[build-kyoto] temple: %d cherry trees, %d bamboo clumps, %d lights, %d parts"):format(
			nTrees,
			nClumps,
			lights,
			count - partsBefore
		)
	)
end
