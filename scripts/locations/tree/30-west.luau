--!nocheck
-- ================================================================ tree: the west island (zoneOf == "west")
-- The mine island and the western part of the neck to the central island:
--   pit fence    oak log posts and spruce rails on the boardwalk's inner edge (74 from the pit centre), open at the
--                four ladder shafts (x -162..-138 on the north / south, z 18..42 on the west) and wide open on the
--                east toward the arrival (z 2..58); lanterns on log stumps at the four corners and beside each opening
--   lamp posts   log posts with an arm, a lantern on a chain and a green clover banner, 4 blocks out from the
--                boardwalk (92 from the pit centre) every ~38 studs; on MAIN STREET at (-18, 16) and (-6, 45)
--   landmarks    a mossy stone arch with vines over the south garden walk (x -162..-138, z 126..130); a mossy
--                totem with a carved face at (-252, 30) looking east over the west opening; a well with a winch and a
--                basket of white concrete at (-34, 2)
--   miners' yard a plank tool shed x -52..-40, z -40..-24 (pickaxes on the walls, a lantern inside), a cart of white
--                concrete, a fenced vegetable patch x -58..-50, z -16..4, hay, crates, barrels
--   gardens      9 small oak / azalea / flowering azalea trees, bushes, mossy boulders, flower beds, hay bales, tall
--                grass and flowers on the free ground round the boardwalk
--   south edge   a coarse walk under the arch to the island edge, a plank stair down 2 blocks to a fenced lookout
--                ledge hanging off the rim on log brackets
--   rim          short vines and hanging roots on the west island's rim face (1–4 blocks)
local westF = folder("WestIsland")
local startCount = count
local C = {
	vine = Color3.fromRGB(190, 230, 150),
	root = Color3.fromRGB(170, 140, 110),
	banner = Color3.fromRGB(70, 140, 55),
	bannerDark = Color3.fromRGB(45, 100, 40),
	clover = Color3.fromRGB(245, 245, 238),
	iron = Color3.fromRGB(165, 165, 170),
	handle = Color3.fromRGB(150, 110, 75),
	carve = Color3.fromRGB(34, 38, 32),
	soil = Color3.fromRGB(120, 86, 60),
	water = Color3.fromRGB(70, 100, 130),
	rope = Color3.fromRGB(150, 120, 80),
	wheel = Color3.fromRGB(60, 50, 44),
	stem = Color3.fromRGB(70, 130, 50),
	carrot = Color3.fromRGB(235, 130, 40),
	flowers = {
		Color3.fromRGB(210, 45, 45),
		Color3.fromRGB(245, 210, 60),
		Color3.fromRGB(245, 245, 238),
		Color3.fromRGB(90, 120, 225),
		Color3.fromRGB(235, 140, 200),
		Color3.fromRGB(245, 150, 50),
	},
}
local lights = 0
local LIGHT_CAP = 24

-- the spots big props took: circles { x, z, r } and rectangles { x0, z0, x1, z1, true }
local taken = {}
local function claim(x, z, r)
	table.insert(taken, { x, z, r })
end
local function claimRect(x0, z0, x1, z1)
	table.insert(taken, { x0, z0, x1, z1, true })
end
local function isTaken(x, z, pad)
	pad = pad or 0
	for _, t in ipairs(taken) do
		if t[5] then
			if x >= t[1] - pad and x <= t[3] + pad and z >= t[2] - pad and z <= t[4] + pad then
				return true
			end
		elseif (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (t[3] + pad) ^ 2 then
			return true
		end
	end
	return false
end
-- the point and the corners of its pad square all belong to this part
local function inZone(x, z, pad)
	pad = pad or 0
	for _, c in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		if zoneOf(x + c[1] * pad, z + c[2] * pad) ~= "west" then
			return false
		end
	end
	return true
end
-- free ground for a solid prop of half-size pad
local function spot(x, z, pad)
	return freeGround(x, z, pad) and inZone(x, z, pad + 2) and not isTaken(x, z, pad)
end
-- a softened tint: our pixel textures are already coloured, a full palette tint would darken them too much
local function soft(c, t)
	return Color3.new(1, 1, 1):Lerp(c, t or 0.45)
end
-- a kit lantern in its own folder; only `lit` ones keep their PointLight (≤ LIGHT_CAP for this part)
local function lamp(pos, parent, hangTop, lit)
	local f = folder("Lantern", parent)
	lantern(pos, f, false, hangTop)
	if lit and lights < LIGHT_CAP then
		lights += 1
	else
		local l = f:FindFirstChildWhichIsA("PointLight", true)
		if l then
			l:Destroy()
		end
	end
	return f
end
-- a frame at local (x, z) turned by yaw (its front, -Z, faces north at yaw 0, south at pi, west at pi/2)
local function fr(x, z, yaw, y)
	return at(x, y or 0, z) * CFrame.Angles(0, yaw or 0, 0)
end
-- a textured box in a frame cf by two local corners
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(
		name,
		size,
		cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		tint,
		nil,
		parent
	)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a flower: a stem and a bloom block (tall = a two-high lilac / peony)
local function flower(x, z, y, parent, tall)
	local sh = if tall then 2.4 else 1.2
	decor(
		part("FlowerStem", Vector3.new(0.25, sh, 0.25), at(x, y + sh / 2, z), C.stem, nil, parent)
	)
	local s = if tall then 1.1 else 0.8
	local bloom = decor(
		part("Flower", Vector3.new(s, s, s), at(x, y + sh + s / 2 - 0.1, z), nil, nil, parent)
	)
	textured(bloom, "px_white_wool", pick(C.flowers))
end
-- a tuft of tall grass: two crossed blades
local function tuft(x, z, y, parent)
	local h = 1 + rng:NextNumber() * 1.2
	local a = rng:NextNumber() * math.pi
	local tint = if rng:NextNumber() < 0.5 then GRASS else GRASS_DEEP
	for k = 0, 1 do
		local p = part(
			"TallGrass",
			Vector3.new(1.4, h, 0.2),
			at(x, y + h / 2, z) * CFrame.Angles(0, a + k * math.pi / 2, 0),
			nil,
			nil,
			parent
		)
		textured(decor(p), "px_grass_top", tint)
		p.CastShadow = false
	end
end

-- the fixed things of the core this part keeps off
claim(-44, 14, 5) -- the zone sign
claim(BUYER.x - 10, BUYER.z - 6, 3) -- the core lamp post
claimRect(-62, 38, -38, 64) -- the buyer stall with its crate and barrel

-- ================================================================ the fence round the pit
do
	local f = folder("PitFence", westF)
	local R = RING.inner + 2 -- 74: one block outside the pit rim
	local function world(side, u)
		if side == "N" then
			return PIT.x + u, PIT.z - R
		elseif side == "S" then
			return PIT.x + u, PIT.z + R
		elseif side == "W" then
			return PIT.x - R, PIT.z + u
		end
		return PIT.x + R, PIT.z + u
	end
	local function rails(ax, az, bx, bz)
		local a, b = V(ax, 0, az), V(bx, 0, bz)
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 8 + 0.5))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			textured(
				part(
					"FencePost",
					Vector3.new(1.6, 4.4, 1.6),
					CFrame.new(p + Vector3.new(0, 2.2, 0)),
					nil,
					nil,
					f
				),
				"px_oak_log"
			)
		end
		for _, h in ipairs({ 1.6, 3.4 }) do
			local mid = (a + b) / 2 + Vector3.new(0, h, 0)
			local rail = part(
				"FenceRail",
				Vector3.new(0.5, 0.7, len),
				CFrame.lookAt(mid, b + Vector3.new(0, h, 0)),
				nil,
				nil,
				f
			)
			textured(rail, "px_spruce_planks")
		end
	end
	local function stump(x, z)
		cube("LanternStump", x, 2, z, B, B, B, "px_oak_log", nil, f)
		lamp(V(x, 4.75, z), f, nil, true)
	end
	-- the four corners
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		stump(PIT.x + c[1] * R, PIT.z + c[2] * R)
	end
	-- each side: the opening (the ladder shaft ± 1 block; the east wide toward the arrival), its stumps, two runs
	for _, s in ipairs({ { "N", 12 }, { "S", 12 }, { "W", 12 }, { "E", 28 } }) do
		local side, o = s[1], s[2]
		local ax, az = world(side, -o - 2)
		local bx, bz = world(side, o + 2)
		stump(ax, az)
		stump(bx, bz)
		local p0x, p0z = world(side, -R + 3)
		local p1x, p1z = world(side, -o - 5)
		rails(p0x, p0z, p1x, p1z)
		local q0x, q0z = world(side, o + 5)
		local q1x, q1z = world(side, R - 3)
		rails(q0x, q0z, q1x, q1z)
	end
end
task.wait()

-- ================================================================ lamp posts with clover banners
do
	local f = folder("LampPosts", westF)
	local function bannerLamp(x, z, yaw, lit)
		if
			not (
				isleOf(x, z, 6)
				and inZone(x, z, 4)
				and not onPath(x, z, 1)
				and not isTaken(x, z, 2)
			)
		then
			warn(("[build-tree] west: lamp post at (%d, %d) skipped"):format(x, z))
			return
		end
		local lf = folder("BannerLamp", f)
		local cf = fr(x, z, yaw)
		lb(cf, "LampLog", -2, 0, -2, 2, 20, 2, "px_oak_log", nil, lf)
		lb(cf, "LampArm", -1.5, 16.5, -11, 1.5, 19.5, -2, "px_oak_log", nil, lf)
		lb(cf, "LampKnee", -1, 14.5, -3.4, 1, 16.5, -2, "px_oak_log", nil, lf)
		local lp = (cf * CFrame.new(0, 12.8, -9.3)).Position
		lamp(lp, lf, (cf * CFrame.new(0, 16.5, 0)).Position.Y, lit)
		-- the banner hangs from the arm beside the post, its cloth along the arm: green with a white clover
		local bc = cf * CFrame.new(0, 12.6, -5.4) * CFrame.Angles(0, math.pi / 2, 0)
		decor(
			part(
				"BannerBar",
				Vector3.new(4, 0.4, 0.4),
				bc * CFrame.new(0, 3.7, 0),
				C.handle,
				Enum.Material.Wood,
				lf
			)
		)
		textured(
			decor(part("Banner", Vector3.new(3.4, 7, 0.2), bc, nil, nil, lf)),
			"px_white_wool",
			C.banner
		)
		decor(
			part(
				"BannerHem",
				Vector3.new(3.4, 0.6, 0.26),
				bc * CFrame.new(0, -3.2, 0),
				C.bannerDark,
				Enum.Material.Fabric,
				lf
			)
		)
		for _, q in ipairs({
			{ 0, 1.5, 1.1 },
			{ -0.75, 0.75, 1.1 },
			{ 0.75, 0.75, 1.1 },
			{ 0, 0.95, 0.6 },
		}) do
			decor(
				part(
					"Clover",
					Vector3.new(q[3], q[3], 0.3),
					bc * CFrame.new(q[1], q[2], 0),
					C.clover,
					nil,
					lf
				)
			)
		end
		decor(
			part(
				"CloverStem",
				Vector3.new(0.3, 1.4, 0.3),
				bc * CFrame.new(0.2, -0.1, 0) * CFrame.Angles(0, 0, 0.3),
				C.clover,
				nil,
				lf
			)
		)
		claim(x, z, 3)
	end
	-- the boardwalk's outer edge, the arm over the boards toward the pit
	local c = RING.outer + 4 -- 92
	local i = 0
	for _, side in ipairs({
		{ "N", { -58, -20, 20, 58 } },
		{ "W", { -58, -20, 20, 58 } },
		{ "S", { -58, -20, 20, 58 } },
		{ "E", { -58, 58 } }, -- the middle of the east side is the arrival and the buyer
	}) do
		for _, d in ipairs(side[2]) do
			i += 1
			local lit = i % 2 == 1
			if side[1] == "N" then
				bannerLamp(PIT.x + d, PIT.z - c, math.pi, lit)
			elseif side[1] == "S" then
				bannerLamp(PIT.x + d, PIT.z + c, 0, lit)
			elseif side[1] == "W" then
				bannerLamp(PIT.x - c, PIT.z + d, -math.pi / 2, lit)
			else
				bannerLamp(PIT.x + c, PIT.z + d, math.pi / 2, lit)
			end
		end
	end
	-- MAIN STREET (x -62..0, z 20..40): beside the street, the arms over it
	bannerLamp(-18, 16, math.pi, true)
	bannerLamp(-6, 45, 0, true)
end
task.wait()

-- ================================================================ landmarks: the arch, the totem, the well
do
	local f = folder("Landmarks", westF)
	local stones = {
		"px_mossy_stone_bricks",
		"px_mossy_stone_bricks",
		"px_mossy_cobblestone",
		"px_stone_bricks",
	}
	local function vineStrip(x, y, z, len, alongX, parent)
		local size = if alongX then Vector3.new(1.2, len, 0.3) else Vector3.new(0.3, len, 1.2)
		textured(
			decor(part("Vine", size, at(x, y - len / 2, z), nil, nil, parent)),
			"px_hedge",
			C.vine
		)
	end

	-- the mossy arch astride the south garden walk (x -154..-146), one block deep (z 126..130)
	do
		local af = folder("MossyArch", f)
		local z0, z1 = 126, 130
		local layout = {
			{ 0, { -160, -140 } },
			{ 4, { -160, -140 } },
			{ 8, { -160, -140 } },
			{ 12, { -160, -140 } },
			{ 16, { -160, -156, -144, -140 } },
			{ 20, { -156, -152, -148, -144 } },
		}
		for _, l in ipairs(layout) do
			for _, x in ipairs(l[2]) do
				box("ArchStone", x - 2, l[1], z0, x + 2, l[1] + B, z1, pick(stones), nil, af)
			end
		end
		-- moss on top, flowering azalea tufts, vines down both faces
		decor(
			box(
				"ArchMoss",
				-158,
				24,
				z0 - 0.3,
				-142,
				24.6,
				z1 + 0.3,
				"px_hedge",
				soft(AZALEA, 0.3),
				af
			)
		)
		for _, x in ipairs({ -156, -147 }) do
			decor(
				cube(
					"ArchBlossom",
					x,
					25.6,
					128,
					3,
					2,
					3,
					"px_cherry_leaves",
					soft(BLOSSOM, 0.4),
					af
				)
			)
		end
		for _ = 1, 9 do
			local x = -161.5 + rng:NextNumber() * 23
			local front = rng:NextNumber() < 0.5
			local top = if x < -158 or x > -142 then 20 else 24
			-- over the opening the vines stay short so the walk stays clear
			local len = if x > -154 and x < -146
				then rng:NextInteger(2, 5)
				else rng:NextInteger(3, 12)
			vineStrip(x, top + 0.4, if front then z0 - 0.2 else z1 + 0.2, len, true, af)
		end
		for _, x in ipairs({ -164, -136 }) do
			cube("ArchBush", x, 2, 128, B, B, B, "px_hedge", soft(OAK_LEAF, 0.3), af)
		end
		claimRect(-166, 124, -134, 132)
	end

	-- the mossy totem with a carved face, 4 blocks tall, looking east across the west opening of the fence
	do
		local tf = folder("MossyTotem", f)
		local tx, tz = -252, 30
		box("TotemBase", tx - 4, 0, tz - 4, tx + 4, 4, tz + 4, "px_mossy_cobblestone", nil, tf)
		box("TotemBody", tx - 4, 4, tz - 4, tx + 4, 12, tz + 4, "px_mossy_stone_bricks", nil, tf)
		box("TotemHead", tx - 4, 12, tz - 4, tx + 4, 16, tz + 4, "px_mossy_cobblestone", nil, tf)
		box("TotemEar", tx - 2, 12, tz - 6, tx + 2, 16, tz - 4, "px_mossy_stone_bricks", nil, tf)
		box("TotemEar", tx - 2, 12, tz + 4, tx + 2, 16, tz + 6, "px_mossy_stone_bricks", nil, tf)
		local fx = tx + 4 -- the face
		for _, ez in ipairs({ tz - 2, tz + 2 }) do
			decor(
				part("TotemEye", Vector3.new(0.3, 1.6, 2), at(fx + 0.1, 9.4, ez), C.carve, nil, tf)
			)
		end
		box(
			"TotemBrow",
			fx,
			10.6,
			tz - 3.5,
			fx + 0.8,
			11.6,
			tz + 3.5,
			"px_mossy_cobblestone",
			nil,
			tf
		)
		box("TotemNose", fx, 6.4, tz - 0.8, fx + 1.2, 8.8, tz + 0.8, "px_stone_bricks", nil, tf)
		decor(part("TotemMouth", Vector3.new(0.3, 1.2, 4), at(fx + 0.1, 5.4, tz), C.carve, nil, tf))
		decor(
			box(
				"TotemMoss",
				tx - 4.3,
				16,
				tz - 4.3,
				tx + 4.3,
				16.6,
				tz + 4.3,
				"px_hedge",
				soft(AZALEA, 0.3),
				tf
			)
		)
		decor(
			cube(
				"TotemBlossom",
				tx - 1,
				17.4,
				tz + 1,
				3,
				2,
				3,
				"px_cherry_leaves",
				soft(BLOSSOM, 0.4),
				tf
			)
		)
		for _ = 1, 5 do
			local side = rng:NextInteger(1, 3)
			local u = rng:NextNumber() * 6 - 3
			if side == 1 then
				vineStrip(tx - 4.2, 16.4, tz + u, rng:NextInteger(4, 12), false, tf)
			elseif side == 2 then
				vineStrip(tx + u, 16.4, tz - 4.2, rng:NextInteger(4, 12), true, tf)
			else
				vineStrip(tx + u, 16.4, tz + 4.2, rng:NextInteger(4, 12), true, tf)
			end
		end
		-- a short coarse walk from the boardwalk to the totem
		box("TotemWalk", tx + 4, 0, tz - 4, PIT.x - RING.outer, 0.12, tz + 4, "px_dirt", COARSE, tf)
		claim(tx, tz, 8)
		claimRect(tx, tz - 5, PIT.x - RING.outer, tz + 5)
	end

	-- the well: a mossy stone shaft, two log posts with a winch, a little roof, a basket of white concrete
	do
		local wf = folder("Well", f)
		local wx, wz = -34, 2
		box("WellWall", wx - 6, 0, wz - 6, wx + 6, 4, wz - 2, "px_mossy_cobblestone", nil, wf)
		box("WellWall", wx - 6, 0, wz + 2, wx + 6, 4, wz + 6, "px_mossy_cobblestone", nil, wf)
		box("WellWall", wx - 6, 0, wz - 2, wx - 2, 4, wz + 2, "px_mossy_cobblestone", nil, wf)
		box("WellWall", wx + 2, 0, wz - 2, wx + 6, 4, wz + 2, "px_mossy_cobblestone", nil, wf)
		decor(box("WellWater", wx - 2, 0.4, wz - 2, wx + 2, 0.6, wz + 2, "px_water", C.water, wf))
		box("WellPost", wx - 6, 4, wz - 2, wx - 2, 16, wz + 2, "px_oak_log", nil, wf)
		box("WellPost", wx + 2, 4, wz - 2, wx + 6, 16, wz + 2, "px_oak_log", nil, wf)
		box("WellBeam", wx - 7, 16, wz - 2, wx + 7, 20, wz + 2, "px_oak_log", nil, wf)
		box("WellRoof", wx - 8, 20, wz - 5, wx + 8, 22, wz + 5, "px_spruce_planks", nil, wf)
		box("WellRoof", wx - 8, 22, wz - 3, wx + 8, 24, wz + 3, "px_dark_oak_planks", nil, wf)
		box("Winch", wx - 2, 13, wz - 1, wx + 2, 15, wz + 1, "px_dark_oak_planks", nil, wf)
		-- the crank on the east post
		decor(
			box(
				"Crank",
				wx + 6,
				13.5,
				wz - 0.4,
				wx + 7,
				14.5,
				wz + 0.4,
				"px_dark_oak_planks",
				nil,
				wf
			)
		)
		decor(
			box(
				"Crank",
				wx + 7,
				11.5,
				wz - 0.4,
				wx + 7.8,
				14.5,
				wz + 0.4,
				"px_dark_oak_planks",
				nil,
				wf
			)
		)
		decor(
			box(
				"CrankGrip",
				wx + 7.8,
				11.5,
				wz - 0.4,
				wx + 9.2,
				12.3,
				wz + 0.4,
				"px_spruce_planks",
				nil,
				wf
			)
		)
		-- the rope and the basket hanging over the shaft
		decor(
			part(
				"Rope",
				Vector3.new(0.3, 3, 0.3),
				at(wx, 11.5, wz),
				C.rope,
				Enum.Material.Fabric,
				wf
			)
		)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			decor(
				beam(
					"BasketRope",
					V(wx, 10.1, wz),
					V(wx + c[1] * 1.6, 8.4, wz + c[2] * 1.6),
					0.2,
					C.rope,
					wf,
					Enum.Material.Fabric
				)
			)
		end
		decor(
			box(
				"Basket",
				wx - 1.8,
				5.8,
				wz - 1.8,
				wx + 1.8,
				6.3,
				wz + 1.8,
				"px_spruce_planks",
				nil,
				wf
			)
		)
		for _, s in ipairs({
			{ -1.8, -1.8, 1.8, -1.5 },
			{ -1.8, 1.5, 1.8, 1.8 },
			{ -1.8, -1.5, -1.5, 1.5 },
			{ 1.5, -1.5, 1.8, 1.5 },
		}) do
			decor(
				box(
					"BasketSide",
					wx + s[1],
					6.3,
					wz + s[2],
					wx + s[3],
					8.4,
					wz + s[4],
					"px_spruce_planks",
					nil,
					wf
				)
			)
		end
		for _, c in ipairs({ { -0.75, -0.75 }, { 0.75, -0.75 }, { 0.75, 0.75 }, { -0.75, 0.75 } }) do
			decor(
				cube(
					"WhiteConcrete",
					wx + c[1],
					7.05,
					wz + c[2],
					1.4,
					1.4,
					1.4,
					"px_smooth_stone",
					SAP,
					wf
				)
			)
		end
		decor(
			cube(
				"WhiteConcrete",
				wx + 0.2,
				8.45,
				wz - 0.1,
				1.4,
				1.4,
				1.4,
				"px_smooth_stone",
				SAP,
				wf
			)
		)
		lamp(V(wx, 17.6, wz - 4), wf, BY + 20, true)
		claim(wx, wz, 9)
		-- a stack of white concrete blocks and a crate by the well
		if spot(wx + 10, wz + 2, 2) then
			cube("ConcreteStack", wx + 10, 2, wz, B, B, B, "px_smooth_stone", SAP, wf)
			cube("ConcreteStack", wx + 10, 2, wz + 4, B, B, B, "px_smooth_stone", SAP, wf)
			cube("ConcreteStack", wx + 10, 6, wz + 2, B, B, B, "px_smooth_stone", SAP, wf)
			claim(wx + 10, wz + 2, 5)
		end
		if spot(wx - 2, wz + 10, 2) then
			crate(wx - 2, 0, wz + 10, wf)
			claim(wx - 2, wz + 10, 3)
		end
	end
end
task.wait()

-- ================================================================ the miners' yard: the tool shed, the cart, the patch
do
	local f = folder("MinersYard", westF)
	local function pickaxe(cf, parent, shovel)
		decor(
			part(
				"ToolHandle",
				Vector3.new(0.35, 3.6, 0.35),
				cf,
				C.handle,
				Enum.Material.Wood,
				parent
			)
		)
		if shovel then
			decor(
				part(
					"ShovelBlade",
					Vector3.new(1.2, 1.4, 0.3),
					cf * CFrame.new(0, 2.3, 0),
					C.iron,
					Enum.Material.Metal,
					parent
				)
			)
			return
		end
		decor(
			part(
				"PickHead",
				Vector3.new(2.4, 0.5, 0.4),
				cf * CFrame.new(0, 1.7, 0),
				C.iron,
				Enum.Material.Metal,
				parent
			)
		)
		decor(
			part(
				"PickTip",
				Vector3.new(0.6, 0.5, 0.4),
				cf * CFrame.new(-1.3, 1.35, 0),
				C.iron,
				Enum.Material.Metal,
				parent
			)
		)
		decor(
			part(
				"PickTip",
				Vector3.new(0.6, 0.5, 0.4),
				cf * CFrame.new(1.3, 1.35, 0),
				C.iron,
				Enum.Material.Metal,
				parent
			)
		)
	end

	-- the tool shed x -52..-40, z -40..-24: log corners, plank walls, a door on the south, a stepped roof
	do
		local sf = folder("ToolShed", f)
		local x0, x1, z0, z1 = -52, -40, -40, -24
		box("ShedFloor", x0, 0, z0, x1, 0.4, z1, "px_spruce_planks", nil, sf)
		for _, cx in ipairs({ x0, x1 - B }) do
			for _, cz in ipairs({ z0, z1 - B }) do
				box("ShedPost", cx, 0, cz, cx + B, 12, cz + B, "px_oak_log", nil, sf)
			end
		end
		box("ShedWall", x0 + B, 0, z0, x1 - B, 12, z0 + 1, "px_spruce_planks", nil, sf)
		box("ShedWall", x0, 0, z0 + B, x0 + 1, 12, z1 - B, "px_spruce_planks", nil, sf)
		-- the east wall with a window
		box("ShedWall", x1 - 1, 0, z0 + B, x1, 5, z1 - B, "px_spruce_planks", nil, sf)
		box("ShedWall", x1 - 1, 9, z0 + B, x1, 12, z1 - B, "px_spruce_planks", nil, sf)
		box("ShedWall", x1 - 1, 5, z0 + B, x1, 9, z0 + 6, "px_spruce_planks", nil, sf)
		box("ShedWall", x1 - 1, 5, z1 - 6, x1, 9, z1 - B, "px_spruce_planks", nil, sf)
		box("ShedLintel", x0 + B, 8, z1 - 1, x1 - B, 12, z1, "px_dark_oak_planks", nil, sf)
		box("ShedRoof", x0 - 2, 12, z0 - 2, x1 + 2, 15, z1 + 2, "px_dark_oak_planks", nil, sf)
		box("ShedRoof", x0 + 2, 15, z0 - 2, x1 - 2, 18, z1 + 2, "px_dark_oak_planks", nil, sf)
		box("ShedRidge", x0 + 5, 18, z0 - 2, x1 - 5, 19.5, z1 + 2, "px_oak_log", nil, sf)
		-- pickaxes and a shovel on the west wall, inside and out (the outside faces the boardwalk)
		for _, t in ipairs({ { -34.5, false }, { -32, false }, { -29.5, true } }) do
			pickaxe(
				at(x0 - 0.25, 5.5, t[1])
					* CFrame.Angles(0, math.pi / 2, 0)
					* CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)),
				sf,
				t[2]
			)
			pickaxe(at(x0 + 1.25, 5.5, t[1] + 0.8) * CFrame.Angles(0, math.pi / 2, 0), sf, not t[2])
		end
		-- inside: a workbench in the back, a barrel, a hanging lantern
		cube("Workbench", -46, 2, -37, B, B, B, "px_spruce_planks", nil, sf)
		decor(
			cube(
				"WorkbenchTop",
				-46,
				4.15,
				-37,
				B + 0.2,
				0.3,
				B + 0.2,
				"px_dark_oak_planks",
				nil,
				sf
			)
		)
		decor(cube("WhiteConcrete", -46.6, 4.9, -37.4, 1.2, 1.2, 1.2, "px_smooth_stone", SAP, sf))
		barrel(-43, 0.4, -30, sf)
		lamp(V(-46, 9.2, -32), sf, BY + 12, true)
		claimRect(x0 - 2, z0 - 2, x1 + 2, z1 + 2)
	end

	-- a coarse walk from the shed door toward MAIN STREET
	box("YardWalk", -48, 0, -24, -44, 0.12, 8, "px_dirt", COARSE, f)
	claimRect(-49, -24, -43, 8)

	-- the cart of white concrete by the walk
	do
		local cf = fr(-38, -14, 0.08)
		local cart = folder("ConcreteCart", f)
		lb(cf, "CartBody", -3, 1.2, -2, 3, 4, 2, "px_spruce_planks", nil, cart)
		decor(lb(cf, "CartRim", -3.2, 4, -2.2, 3.2, 4.4, 2.2, "px_dark_oak_planks", nil, cart))
		for _, w in ipairs({ { -1.8, -2.2 }, { 1.8, -2.2 }, { -1.8, 2.2 }, { 1.8, 2.2 } }) do
			decor(
				lb(
					cf,
					"CartWheel",
					w[1] - 0.9,
					0,
					w[2] - 0.2,
					w[1] + 0.9,
					1.8,
					w[2] + 0.2,
					"px_dark_oak_log",
					C.wheel,
					cart
				)
			)
		end
		for _, b in ipairs({ { -1.5, -0.9 }, { 0.6, -0.9 }, { -0.5, 0.9 }, { 1.6, 0.9 } }) do
			decor(
				lb(
					cf,
					"WhiteConcrete",
					b[1] - 1,
					4.4,
					b[2] - 1,
					b[1] + 1,
					6.4,
					b[2] + 1,
					"px_smooth_stone",
					SAP,
					cart
				)
			)
		end
		decor(lb(cf, "WhiteConcrete", -0.6, 6.4, -1, 1.4, 8.4, 1, "px_smooth_stone", SAP, cart))
		for _, hz in ipairs({ -1.4, 1.4 }) do
			decor(
				lb(
					cf,
					"CartHandle",
					3,
					2.8,
					hz - 0.2,
					6,
					3.2,
					hz + 0.2,
					"px_dark_oak_planks",
					nil,
					cart
				)
			)
		end
		claim(-38, -14, 5)
	end

	-- hay, barrels and crates round the shed
	if spot(-37, -22, 2) then
		cube("Hay", -37, 2, -22, B, B, B, "px_hay", nil, f)
		cube("Hay", -37, 6, -22, B, B, B, "px_hay", nil, f)
		claim(-37, -22, 3)
	end
	for _, b in ipairs({ { -56, -36, "barrel" }, { -56, -42, "crate" }, { -55, -21, "barrel" } }) do
		if spot(b[1], b[2], 2) then
			if b[3] == "barrel" then
				barrel(b[1], 0, b[2], f, "px_smooth_stone")
			else
				crate(b[1], 0, b[2], f)
			end
			claim(b[1], b[2], 3)
		end
	end

	-- the vegetable patch x -58..-50, z -16..4 with a fence and a gate toward the walk
	do
		local vf = folder("VegetablePatch", f)
		box("Farmland", -58, 0, -16, -50, 0.3, 4, "px_dirt", C.soil, vf)
		for zc = -14, 2, 4 do
			-- a row of cabbages and a row of carrots
			decor(cube("Cabbage", -56, 1.5, zc, 2.4, 2.4, 2.4, "px_hedge", soft(AZALEA, 0.25), vf))
			decor(
				cube("CarrotTop", -52, 1.2, zc, 1.2, 1.8, 1.2, "px_hedge", soft(OAK_LEAF, 0.2), vf)
			)
			decor(part("Carrot", Vector3.new(0.9, 0.5, 0.9), at(-52, 0.45, zc), C.carrot, nil, vf))
		end
		fence(-59, -17, -59, 5, vf, 0, "px_spruce_planks")
		fence(-59, -17, -49, -17, vf, 0, "px_spruce_planks")
		fence(-59, 5, -49, 5, vf, 0, "px_spruce_planks")
		fence(-49, -17, -49, -9, vf, 0, "px_spruce_planks")
		fence(-49, -3, -49, 5, vf, 0, "px_spruce_planks")
		claimRect(-60, -18, -48, 6)
	end
end
task.wait()

-- ================================================================ the south edge: the walk, the stair, the lookout
do
	local f = folder("SouthLookout", westF)
	-- the island face under a column of 8-stud cells (the island is built in cells centred on x, z ≡ 4 mod 8)
	local function faceSouth(xc)
		for zc = 172, 36, -8 do
			if isleOf(xc, zc) then
				return zc + 4
			end
		end
		return nil
	end
	local zA, zB = faceSouth(-156), faceSouth(-148)
	if zA and zB and math.min(zA, zB) > 132 and math.max(zA, zB) + 24 < 186 then
		local zMin, zMax = math.min(zA, zB), math.max(zA, zB)
		local walkZ0 = PIT.z + RING.outer -- 118: off the boardwalk
		box("GardenWalk", -154, 0, walkZ0, -146, 0.12, zMin, "px_dirt", COARSE, f)
		if zMax > zMin then
			box("StairLanding", -154, -4, zMin, -146, 0.12, zMax, "px_spruce_planks", nil, f)
		end
		claimRect(-156, walkZ0, -144, zMax)
		-- the stair: two blocks down over three blocks, then the ledge 4 × 3 blocks
		stairs("SouthStair", -150, zMax, zMax + 12, 0, -8, 8, "px_spruce_planks", f)
		box("Ledge", -158, -12, zMax + 12, -142, -8, zMax + 24, "px_spruce_planks", nil, f)
		decor(
			box(
				"LedgeTrim",
				-158.3,
				-12.4,
				zMax + 23.7,
				-141.7,
				-11.6,
				zMax + 24.3,
				"px_dark_oak_log",
				nil,
				f
			)
		)
		-- log brackets from under the ledge back into the rock of the rim
		for _, b in ipairs({ { -155, zA }, { -145, zB } }) do
			local strut =
				beam("LedgeBracket", V(b[1], -12, zMax + 22), V(b[1], -18, b[2] - 3), 2, nil, f)
			textured(strut, "px_dark_oak_log")
		end
		-- hand rails down the stair
		for _, rx in ipairs({ -153.6, -146.4 }) do
			local tops = {}
			for j = 0, 2 do
				local z = zMax + 1 + 4 * j
				local top = -(2 * j + 1) * 8 / 6
				textured(
					part("StairPost", Vector3.new(0.8, 3.6, 0.8), at(rx, top + 1.8, z), nil, nil, f),
					"px_oak_log"
				)
				table.insert(tops, V(rx, top + 3.3, z))
			end
			textured(beam("StairRail", tops[1], tops[3], 0.5, nil, f), "px_spruce_planks")
		end
		-- the ledge fence (open where the stair arrives), a lantern on a post, a barrel
		fence(-157.5, zMax + 12.5, -157.5, zMax + 23.5, f, -8, "px_oak_log")
		fence(-157.5, zMax + 23.5, -142.5, zMax + 23.5, f, -8, "px_oak_log")
		fence(-142.5, zMax + 23.5, -142.5, zMax + 12.5, f, -8, "px_oak_log")
		fence(-157.5, zMax + 12.5, -154.5, zMax + 12.5, f, -8, "px_oak_log")
		fence(-145.5, zMax + 12.5, -142.5, zMax + 12.5, f, -8, "px_oak_log")
		textured(
			part("LookoutPost", Vector3.new(1.6, 5, 1.6), at(-156, -5.5, zMax + 22), nil, nil, f),
			"px_oak_log"
		)
		lamp(V(-156, -2.25, zMax + 22), f, nil, true)
		barrel(-145, -8, zMax + 20, f)
	else
		warn(
			("[build-tree] west: south lookout skipped (island face %s / %s)"):format(
				tostring(zA),
				tostring(zB)
			)
		)
	end
end
task.wait()

-- ================================================================ small trees round the island
do
	local f = folder("Trees", westF)
	-- one crown layer w blocks wide (odd) with its corners cut, as three boxes that never overlap
	local function crownLayer(x, z, y, w, variant, tint, parent)
		local h = w * B / 2
		decor(box("Leaves", x - h, y, z - h + B, x + h, y + B, z + h - B, variant, tint, parent))
		decor(
			box("Leaves", x - h + B, y, z - h, x + h - B, y + B, z - h + B, variant, tint, parent)
		)
		decor(
			box("Leaves", x - h + B, y, z + h - B, x + h - B, y + B, z + h, variant, tint, parent)
		)
	end
	local function smallTree(x, z, hBlocks, kind, r, big)
		local tw = if big then 2 * B else B
		if not (spot(x, z, tw / 2) and inZone(x, z, r * B + 2)) then
			warn(("[build-tree] west: tree at (%d, %d) skipped"):format(x, z))
			return
		end
		local tf = folder("Tree", f)
		local H = hBlocks * B
		box("Trunk", x - tw / 2, 0, z - tw / 2, x + tw / 2, H, z + tw / 2, "px_oak_log", nil, tf)
		local main, mainTint, alt, altTint
		if kind == "oak" then
			main, mainTint, alt, altTint =
				"px_hedge", soft(OAK_LEAF, 0.3), "px_hedge", soft(AZALEA, 0.15)
		elseif kind == "azalea" then
			main, mainTint, alt, altTint =
				"px_hedge", soft(AZALEA, 0.25), "px_cherry_leaves", soft(BLOSSOM, 0.45)
		else
			main, mainTint, alt, altTint =
				"px_cherry_leaves", soft(BLOSSOM, 0.4), "px_hedge", soft(AZALEA, 0.25)
		end
		local widths = if r >= 3 then { 5, 7, 7, 5, 3 } else { 5, 5, 3 }
		local y0 = H - B
		for i, w in ipairs(widths) do
			crownLayer(x, z, y0 + (i - 1) * B, w, main, mainTint, tf)
		end
		-- patches of the other leaves on the crown's sides
		for _ = 1, (if r >= 3 then 12 else 7) do
			local li = rng:NextInteger(1, #widths)
			local half = (widths[li] - 1) / 2
			local bx, bz = rng:NextInteger(-half, half), rng:NextInteger(-half, half)
			if rng:NextNumber() < 0.5 then
				bx = if rng:NextNumber() < 0.5 then -half else half
			else
				bz = if rng:NextNumber() < 0.5 then -half else half
			end
			if not (math.abs(bx) == half and math.abs(bz) == half) then
				decor(
					cube(
						"LeafPatch",
						x + bx * B,
						y0 + (li - 0.5) * B,
						z + bz * B,
						4.2,
						4.2,
						4.2,
						alt,
						altTint,
						tf
					)
				)
			end
		end
		-- a branch stub on the big trees, hanging leaves on the azaleas
		if big then
			box(
				"Branch",
				x + tw / 2,
				H - 9,
				z - 1.5,
				x + tw / 2 + 6,
				H - 6,
				z + 1.5,
				"px_oak_log",
				nil,
				tf
			)
			decor(cube("BranchLeaves", x + tw / 2 + 7, H - 6, z, 6, 4, 6, main, mainTint, tf))
		end
		if kind ~= "oak" then
			local edge = widths[1] * B / 2 + 0.2
			for _ = 1, 3 do
				local u = rng:NextInteger(-1, 1) * B
				local len = rng:NextInteger(2, 6)
				local p
				if rng:NextNumber() < 0.5 then
					local sx = if rng:NextNumber() < 0.5 then -edge else edge
					p = part(
						"HangingLeaves",
						Vector3.new(0.4, len, 1.6),
						at(x + sx, y0 - len / 2 + 1, z + u),
						nil,
						nil,
						tf
					)
				else
					local sz = if rng:NextNumber() < 0.5 then -edge else edge
					p = part(
						"HangingLeaves",
						Vector3.new(1.6, len, 0.4),
						at(x + u, y0 - len / 2 + 1, z + sz),
						nil,
						nil,
						tf
					)
				end
				textured(decor(p), "px_hedge", C.vine)
			end
		end
		claim(x, z, tw / 2 + 2)
	end
	for _, t in ipairs({
		{ -188, -72, 6, "oak", 2 },
		{ -150, -78, 5, "blossom", 2 },
		{ -112, -72, 6, "azalea", 2 },
		{ -188, 132, 6, "azalea", 2 },
		{ -116, 132, 5, "oak", 2 },
		{ -252, -8, 6, "blossom", 2 },
		{ -252, 62, 7, "oak", 3, true },
		{ -47, -58, 5, "azalea", 2 },
		{ -52, 74, 5, "blossom", 2 },
	}) do
		smallTree(t[1], t[2], t[3], t[4], t[5], t[6])
	end
end
task.wait()

-- ================================================================ gardens: bushes, boulders, beds, hay, crates
do
	local f = folder("Gardens", westF)
	local function bush(x, z)
		local tint = if rng:NextNumber() < 0.5 then soft(OAK_LEAF, 0.3) else soft(AZALEA, 0.25)
		cube("Bush", x, 2, z, B, B, B, "px_hedge", tint, f)
		if rng:NextNumber() < 0.4 then
			local dx, dz = if rng:NextNumber() < 0.5 then B else 0, 0
			if dx == 0 then
				dz = B
			end
			if spot(x + dx, z + dz, 2) then
				cube("Bush", x + dx, 2, z + dz, B, B, B, "px_hedge", tint, f)
			end
		end
		if rng:NextNumber() < 0.35 then
			decor(
				cube(
					"BushBlossom",
					x,
					4.4,
					z,
					3.2,
					0.8,
					3.2,
					"px_cherry_leaves",
					soft(BLOSSOM, 0.45),
					f
				)
			)
		end
		claim(x, z, 5)
	end
	local function boulder(x, z)
		local alongX = rng:NextNumber() < 0.5
		local sx, sz = if alongX then 2 * B else B, if alongX then B else 2 * B
		cube(
			"Boulder",
			x,
			2,
			z,
			sx,
			B,
			sz,
			pick({ "px_mossy_cobblestone", "px_mossy_cobblestone", "px_cobblestone" }),
			nil,
			f
		)
		local tx = if alongX then x - 2 else x
		local tz = if alongX then z else z - 2
		cube(
			"Boulder",
			tx,
			6,
			tz,
			B,
			B,
			B,
			pick({ "px_mossy_cobblestone", "px_mossy_stone_bricks" }),
			nil,
			f
		)
		decor(
			cube(
				"BoulderMoss",
				tx,
				8.2,
				tz,
				B + 0.2,
				0.4,
				B + 0.2,
				"px_hedge",
				soft(AZALEA, 0.3),
				f
			)
		)
		claim(x, z, 6)
	end
	local function bed(x, z)
		local alongX = rng:NextNumber() < 0.5
		local hx, hz = if alongX then 4 else 2, if alongX then 2 else 4
		box("FlowerBed", x - hx, 0, z - hz, x + hx, 1, z + hz, "px_dirt", C.soil, f)
		for k = -1, 1 do
			local fx = if alongX then x + k * 2.6 else x + rng:NextNumber(-0.8, 0.8)
			local fz = if alongX then z + rng:NextNumber(-0.8, 0.8) else z + k * 2.6
			flower(fx, fz, 1, f, rng:NextNumber() < 0.2)
		end
		claim(x, z, 5)
	end
	local function hay(x, z)
		cube("Hay", x, 2, z, B, B, B, "px_hay", nil, f)
		if rng:NextNumber() < 0.5 and spot(x + B, z, 2) then
			cube("Hay", x + B, 2, z, B, B, B, "px_hay", nil, f)
			if rng:NextNumber() < 0.5 then
				cube("Hay", x + 2, 6, z, B, B, B, "px_hay", nil, f)
			end
		end
		claim(x, z, 6)
	end
	for gx = -268, -4, 8 do
		for gz = -108, 164, 8 do
			local x, z = gx + rng:NextInteger(-1, 1) * 2, gz + rng:NextInteger(-1, 1) * 2
			local r = rng:NextNumber()
			if r < 0.3 and spot(x, z, 3) then
				if r < 0.11 then
					bush(x, z)
				elseif r < 0.16 then
					boulder(x, z)
				elseif r < 0.22 then
					bed(x, z)
				elseif r < 0.25 then
					hay(x, z)
				elseif r < 0.275 then
					crate(x, 0, z, f, nil, rng:NextInteger(0, 1) * 0.3)
					claim(x, z, 4)
				else
					barrel(x, 0, z, f)
					claim(x, z, 4)
				end
			end
		end
		if gx % 64 == 0 then
			task.wait()
		end
	end
	-- tall grass and flowers on the free ground
	local function decorOk(x, z)
		return isleOf(x, z, 5) ~= nil
			and inZone(x, z, 1)
			and not onPath(x, z, 1)
			and not inPitArea(x, z, 1)
			and (x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2 > 100
			and not isTaken(x, z, 0.5)
	end
	local tufts = folder("TallGrass", f)
	for gx = -270, -2, 4 do
		for gz = -112, 168, 4 do
			if rng:NextNumber() < 0.42 then
				local x, z = gx + rng:NextNumber(-1.5, 1.5), gz + rng:NextNumber(-1.5, 1.5)
				if decorOk(x, z) then
					if rng:NextNumber() < 0.68 then
						tuft(x, z, 0, tufts)
					else
						flower(x, z, 0, tufts, rng:NextNumber() < 0.12)
					end
				end
			end
		end
		if gx % 32 == 0 then
			task.wait()
		end
	end
end
task.wait()

-- ================================================================ the rim: short vines and hanging roots on the face
do
	local f = folder("RimVines", westF)
	local function strip(x, z, nx, nz)
		local isRoot = rng:NextNumber() < 0.3
		local len = rng:NextInteger(1, 4) * B - rng:NextInteger(0, 2)
		local w = pick({ 1.2, 1.6, 2 })
		local th = if isRoot then 0.8 else 0.35
		local size = if nx ~= 0 then Vector3.new(th, len, w) else Vector3.new(w, len, th)
		local px, pz = x + nx * (th / 2 + 0.05), z + nz * (th / 2 + 0.05)
		local p = decor(
			part(
				if isRoot then "HangingRoot" else "RimVine",
				size,
				at(px, 0.1 - len / 2, pz),
				nil,
				nil,
				f
			)
		)
		textured(p, if isRoot then "px_oak_log" else "px_hedge", if isRoot then C.root else C.vine)
		p.CastShadow = false
		-- the bit that creeps over the edge
		local lip = if nx ~= 0 then Vector3.new(1.4, 0.15, w) else Vector3.new(w, 0.15, 1.4)
		local l = decor(part("RimLip", lip, at(x - nx * 0.6, 0.075, z - nz * 0.6), nil, nil, f))
		textured(l, if isRoot then "px_oak_log" else "px_hedge", if isRoot then C.root else C.vine)
		if not isRoot and len > 6 and rng:NextNumber() < 0.6 then
			decor(
				cube(
					"RimLeaves",
					px + nx * 0.5,
					0.1 - rng:NextNumber(2, len - 1),
					pz + nz * 0.5,
					1.6,
					1.6,
					1.6,
					"px_hedge",
					C.vine,
					f
				)
			)
		end
	end
	local function hang(x, z, nx, nz)
		-- only the west island's own rim (the cell behind the face), not the central island's
		if
			zoneOf(x, z) ~= "west"
			or isleOf(x - nx * 4, z - nz * 4) ~= "west"
			or rng:NextNumber() > 0.5
		then
			return
		end
		for _ = 1, rng:NextInteger(1, 2) do
			local u = rng:NextNumber(-3, 3)
			if nx ~= 0 then
				strip(x, z + u, nx, nz)
			else
				strip(x + u, z, nx, nz)
			end
		end
	end
	-- the north and south faces column by column, the west face row by row (cell centres ≡ 4 mod 8)
	for xc = -292, -4, 8 do
		for zc = -148, 36, 8 do
			if isleOf(xc, zc) then
				hang(xc, zc - 4, 0, -1)
				break
			end
		end
		if xc < -164 or xc > -136 then -- the stair goes down there
			for zc = 172, 36, -8 do
				if isleOf(xc, zc) then
					hang(xc, zc + 4, 0, 1)
					break
				end
			end
		end
	end
	for zc = -148, 172, 8 do
		for xc = -292, -156, 8 do
			if isleOf(xc, zc) then
				hang(xc - 4, zc, -1, 0)
				break
			end
		end
	end
end

print(("[build-tree] west: %d parts, %d lights"):format(count - startCount, lights))
