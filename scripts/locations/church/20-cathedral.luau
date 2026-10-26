--!nocheck
-- ================================================================ church: the cathedral, the steps, the bell tower
-- The PLINTH x -40..40, z -190..-70, y 0..8 (white stone bricks, a grey course y 6..8 = the nave floor level). The
-- STEPS x -24..24 from the portal (z -70, y 8) down to the square (z -48, y 0): kit stairs on a fill, cheek walls
-- x ±24..28 with candles, two lantern pillars at x ±32, z -50.
-- The NAVE x -20..20 (10 blocks) inside, z -166..-78, floor y 8 (a blue-and-white mosaic, lattice down the aisle
-- x -8..8 and over the crossing z -166..-138); PIERS 2×2 blocks at x ±20..28 every 5 blocks (centres z -82, -102,
-- -122, -142, -162) to y 68 with pinnacles to 84; between them the stained-glass LANCETS (glass plane x ±24, z 12 wide,
-- y 12..55 with a stepped pointed head, two lights, diamond medallions, a little gold); FLYING BUTTRESSES (two stepped
-- flyers each) to outer piers x ±36..40 with slate pinnacles and gargoyles. The ROOF: px_roof_tiles slate, six steps
-- from y 60 (half-width 24) to the ridge at y 84, a flèche over the crossing (z -146) to y 134.
-- The FACADE z -78..-70 (three layers): the PORTAL x -12..12 (stepped archivolts ±16 / ±14 / ±12, springing y 18,
-- apex ≈ 33..37), the ROSE WINDOW centre (0, 56) r 16 (2-stud panes, 8 white spokes, a ring, gold centre and foils),
-- niches with statues at x ±21, blue banners, the stepped gable to y 84 with a gold cross; TURRETS x ±28..40,
-- z -82..-70 to y 76, slate spires to y 112.
-- The APSE z -190..-166: a stepped half-octagon of glass columns and pinnacled corner piers; the altar on a dais.
-- Inside: spruce pews x ±9..17 (aisle x -8..8 clear), shafts and stepped ribs at the piers, blue banners with a white
-- cross, candle stands (4 lit), two iron chandeliers, the pulpit (west, z -150), the lectern and the organ (east).
-- The BELL TOWER x 48..76, z -98..-70: walls 1 block, the door on the south (x 52..58, y 0..14); inside a square
-- spiral of 13 flights (6 wide, rise 8 over 8 — 4 steps of 2) round a central pier x 58..66, z -88..-80, landings in
-- the corners, 32 studs per turn (headroom ≥ 24); the BELFRY floor y 104 (the SUMMIT) with a railed stairwell, open
-- pointed arches with parapets on all four sides, the bronze bell (12 wide, y 112..127) under an oak headstock; the
-- cornice y 136..140, the slate spire to y 180 and a gold cross to y 192.
local cath = folder("Cathedral")
local partsBefore = count
local nLights = 0
local STONE, SMOOTH, GREYB, ROOF =
	"px_white_stone_bricks", "px_smooth_stone", "px_stone_bricks", "px_roof_tiles"
local OAK_DARK, GOLDB = "px_dark_oak_planks", "px_gold_block"
local BRONZE = Color3.fromRGB(214, 152, 92)
local IRON = Color3.fromRGB(62, 62, 70)
local WAX = Color3.fromRGB(242, 234, 212)
local FLAME = Color3.fromRGB(255, 196, 110)
local GARGOYLE = Color3.fromRGB(150, 150, 160)
local PZ = { -82, -102, -122, -142, -162 } -- the pier centres (z)

-- a pane of stained glass (Glass, light passes: no shadow)
local function glass(name, x0, y0, z0, x1, y1, z1, color, parent)
	local p = box(name, x0, y0, z0, x1, y1, z1, nil, color, parent)
	p.Material = Enum.Material.Glass
	p.Transparency = 0.28
	p.CastShadow = false
	return p
end
-- a dark iron bar (decor)
local function iron(name, x0, y0, z0, x1, y1, z1, parent)
	local p = decor(box(name, x0, y0, z0, x1, y1, z1, nil, IRON, parent))
	p.Material = Enum.Material.Metal
	return p
end
-- inside a pointed (two-centre) arch: half-span h, arc radius r, springing at y `spring`
local function pointed(u, y, h, r, spring)
	u = math.abs(u)
	if u > h then
		return false
	end
	if y <= spring then
		return true
	end
	return (u + r - h) ^ 2 + (y - spring) ^ 2 <= r * r
end
-- greedy rectangles over a grid of cells (res studs): cellFn(u, v) -> kind (string) or nil; equal runs of a row are
-- merged, then equal runs of consecutive rows; emit(kind, u0, u1, v0, v1) builds one rectangle
local function greedy(u0, u1, v0, v1, res, cellFn, emit)
	local nu = math.floor((u1 - u0) / res + 0.5)
	local nv = math.floor((v1 - v0) / res + 0.5)
	local open = {}
	for j = 0, nv do
		local runs = {}
		if j < nv then
			local v = v0 + (j + 0.5) * res
			local prev, start = nil, 0
			for i = 0, nu do
				local k = if i < nu then cellFn(u0 + (i + 0.5) * res, v) else nil
				if k ~= prev then
					if prev ~= nil then
						runs[start .. ":" .. i .. ":" .. prev] = { start, i, prev }
					end
					prev, start = k, i
				end
			end
		end
		for key, r in pairs(open) do
			if not runs[key] then
				emit(r[3], u0 + r[1] * res, u0 + r[2] * res, v0 + r[4] * res, v0 + j * res)
				open[key] = nil
			end
		end
		for key, r in pairs(runs) do
			if not open[key] then
				open[key] = { r[1], r[2], r[3], j }
			end
		end
	end
end
-- one candle (a lit one gets a flame); returns the flame
local function candle(x, y, z, h, lit, parent)
	decor(
		part(
			"Candle",
			Vector3.new(0.6, h, 0.6),
			at(x, y + h / 2, z),
			WAX,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	if lit then
		local f = decor(
			part(
				"CandleFlame",
				Vector3.new(0.3, 0.5, 0.3),
				at(x, y + h + 0.3, z),
				FLAME,
				Enum.Material.Neon,
				parent
			)
		)
		f.CastShadow = false
		return f
	end
	return nil
end
-- a cluster of three candles on a top at y; a lit cluster carries one warm PointLight
local function candles(x, y, z, lit, parent)
	local flame
	for _, c in ipairs({ { -0.7, -0.5, 1.6 }, { 0.7, -0.3, 1.1 }, { 0, 0.6, 2.2 } }) do
		flame = candle(x + c[1], y, z + c[2], c[3], lit, parent) or flame
	end
	if flame then
		light(flame, 26, 1.3, FLAME)
		nLights += 1
	end
end
-- a blue banner with a white cross (cf on the cloth plane, +Z out)
local function crossBanner(cf, w, h, parent)
	banner(cf, BANNER_BLUE, parent, nil, w, h)
	local white = Color3.fromRGB(240, 240, 236)
	decor(
		part(
			"BannerCross",
			Vector3.new(w * 0.2, h * 0.62, 0.28),
			cf * CFrame.new(0, h * 0.04, 0),
			white,
			Enum.Material.Fabric,
			parent
		)
	)
	decor(
		part(
			"BannerCross",
			Vector3.new(w * 0.66, h * 0.1, 0.28),
			cf * CFrame.new(0, h * 0.18, 0),
			white,
			Enum.Material.Fabric,
			parent
		)
	)
end
-- a grey stepped gargoyle; cf at the attachment point, LookVector outward
local function gargoyle(cf, parent)
	local function g(name, sx, sy, sz, ox, oy, oz, tint)
		textured(
			part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), nil, nil, parent),
			SMOOTH,
			tint or GARGOYLE
		)
	end
	g("GargoyleBody", 2.4, 2.2, 4, 0, 0, -2)
	g("GargoyleHead", 3, 2.6, 2.6, 0, 0.6, -4.8)
	g("GargoyleJaw", 2.2, 0.8, 1.8, 0, -0.9, -5.6, Color3.fromRGB(112, 112, 122))
	g("GargoyleSnout", 1.8, 1.2, 1, 0, 0.6, -6.5)
	for _, s in ipairs({ -1, 1 }) do
		g("GargoyleWing", 0.8, 2.6, 2.6, s * 1.6, 1.4, -1.6)
		g("GargoyleHorn", 0.6, 1.2, 0.6, s, 2.4, -4.2)
	end
end
-- the apse: a half-octagon "radius" of a 4-stud cell centre (cx, t = depth north of z -166)
local function apseR(cx, t)
	return math.max(math.abs(cx), t, (math.abs(cx) + t) * 0.75)
end
local function apseIn(cx, t)
	if t < 0 then
		return math.abs(cx) < 20
	end
	return apseR(cx, t) < 20
end

-- ================================================================ the plinth, the steps, the lantern pillars
do
	local f = folder("PlinthSteps", cath)
	box("Plinth", -40, 0, -190, 40, 6, -70, STONE, WHITE_STONE, f)
	box("PlinthCourse", -40, 6, -190, 40, 8, -70, GREYB, GREY_STONE, f)
	stairs("Steps", 0, -48, -70, 0, 8, 48, STONE, f)
	box("StepsFill", -24, 0, -70, 24, 4, -58, STONE, WHITE_STONE, f)
	for _, sx in ipairs({ -1, 1 }) do
		-- the cheek walls follow the stair a block above it, candles on every other cap (the lowest ones lit)
		for s = 0, 5 do
			local za = -70 + 4 * s
			local zb = math.min(za + 4, -48)
			local top = math.ceil(8 * (-48 - za) / 22) + 3
			box("StepWall", sx * 24, 0, za, sx * 28, top - 1, zb, STONE, WHITE_STONE, f)
			box("StepWallCap", sx * 24, top - 1, za, sx * 28, top, zb, SMOOTH, GREY_STONE, f)
			if s % 2 == 0 then
				candles(sx * 26, top, za + 2, s == 4, f)
			end
		end
		-- a lantern pillar with a blue banner at the foot of the stair
		local px = sx * 32
		box("PillarBase", px - 3, 0, -53, px + 3, 2, -47, GREYB, GREY_STONE, f)
		box("Pillar", px - 2, 2, -52, px + 2, 12, -48, STONE, WHITE_STONE, f)
		box("PillarCap", px - 2.5, 12, -52.5, px + 2.5, 13, -47.5, SMOOTH, GREY_STONE, f)
		lantern(V(px, 13.85, -50), f)
		nLights += 1
		crossBanner(at(px, 7, -47.7), 4, 8, f)
	end
end
task.wait()

-- ================================================================ the facade: portal, rose window, gable, turrets
do
	local f = folder("Facade", cath)
	local LAYERS = { { -72, -70 }, { -76, -72 }, { -78, -76 } } -- front, middle (the glass), back
	local GLASS = { gB = GLASS_BLUE, gC = GLASS_CYAN, gW = GLASS_WHITE }
	local Q = math.pi / 4
	-- the rose: gold centre, a white hub, 8 spokes, a ring at r 10, white-cored petals inside, cyan foils outside
	local function roseKind(u, yy, d)
		if d < 2.5 then
			return "gold"
		end
		if d < 4.2 then
			return "mull"
		end
		local a = math.atan2(yy, u) % Q
		if d * math.sin(math.min(a, Q - a)) < 1.1 or math.abs(d - 10) < 1.1 then
			return "mull"
		end
		local mid = d * math.sin(math.abs(a - Q / 2))
		if d < 10 then
			if mid < 1.2 then
				return "gW"
			end
			return if d < 6.6 then "gC" else "gB"
		end
		local fd = math.sqrt((d - 13.5) ^ 2 + mid * mid)
		if fd < 1.2 then
			return "gold"
		end
		return if fd < 2.6 then "gC" else "gB"
	end
	local function kind(layer, u, y)
		local hw = if y < 60 then 28 else 24 - 4 * math.floor((y - 60) / 4) -- the gable steps with the roof
		if math.abs(u) >= hw then
			return nil
		end
		local d = math.sqrt(u * u + (y - 56) ^ 2)
		if layer == 1 then
			if pointed(u, y, 16, 19, 18) or d < 17.5 then
				return nil
			end
			if y > 20 and pointed(math.abs(u) - 21, y, 3, 4, 30) then
				return nil -- the statue niches
			end
			if (y > 36 and y < 38) or (y > 58 and y < 60) then
				return "trim"
			end
			return "stone"
		elseif layer == 2 then
			if pointed(u, y, 14, 17, 18) then
				return nil
			end
			if d < 16 then
				return roseKind(u, y - 56, d)
			end
			return if d < 17.5 then "ring" else "stone"
		end
		if pointed(u, y, 12, 15, 18) or d < 16 then
			return nil
		end
		return "stone"
	end
	for li, zr in ipairs(LAYERS) do
		greedy(-28, 28, 8, 84, 2, function(u, y)
			return kind(li, u, y)
		end, function(k, ua, ub, ya, yb)
			if k == "stone" then
				box("FacadeWall", ua, ya, zr[1], ub, yb, zr[2], STONE, WHITE_STONE, f)
			elseif k == "trim" then
				box("FacadeCourse", ua, ya, zr[1], ub, yb, zr[2], GREYB, GREY_STONE, f)
			elseif k == "ring" then
				box("RoseFrame", ua, ya, zr[1], ub, yb, zr[2], SMOOTH, WHITE_STONE, f)
			elseif k == "mull" then
				box("RoseMullion", ua, ya, -76, ub, yb, -72, SMOOTH, WHITE_STONE, f)
			elseif k == "gold" then
				box("RoseGold", ua, ya, -75.4, ub, yb, -72.6, GOLDB, nil, f)
			else
				glass("RoseGlass", ua, ya, -74.5, ub, yb, -73.5, GLASS[k], f)
			end
		end)
	end
	-- crockets on the gable steps, the gold cross on top
	for _, hw in ipairs({ 24, 20, 16, 12, 8 }) do
		local y = 60 + (24 - hw) + 4
		for _, sx in ipairs({ -1, 1 }) do
			box("Crocket", sx * (hw - 2), y, -73, sx * hw, y + 2, -70, SMOOTH, GREY_STONE, f)
		end
	end
	box("GableTop", -2, 84, -76, 2, 86, -72, SMOOTH, WHITE_STONE, f)
	box("GableCross", -1, 86, -75, 1, 98, -73, GOLDB, nil, f)
	box("GableCross", -4, 92, -75, 4, 94, -73, GOLDB, nil, f)
	for _, sx in ipairs({ -1, 1 }) do
		-- statues in the niches, banners above them, a lantern on a bracket by the portal
		textured(
			part("Statue", Vector3.new(2.4, 6, 1.6), at(sx * 21, 23, -71), nil, nil, f),
			SMOOTH,
			WHITE_STONE
		)
		textured(
			part("StatueHead", Vector3.new(1.6, 1.6, 1.4), at(sx * 21, 26.8, -71), nil, nil, f),
			SMOOTH,
			WHITE_STONE
		)
		crossBanner(at(sx * 21, 46, -69.6), 4, 10, f)
		iron("LanternBracket", sx * 14.5, 28, -70, sx * 15.5, 28.6, -68.4, f)
		lantern(V(sx * 15, 26, -68.8), f, false, BY + 28)
		nLights += 1
		-- the open door leaves inside the portal
		decor(box("DoorLeaf", sx * 11, 8, -90, sx * 12, 28, -78, OAK_DARK, nil, f))
		for _, y in ipairs({ 12, 22 }) do
			iron("DoorBand", sx * 10.8, y, -89.5, sx * 11, y + 0.8, -78.5, f)
		end
		-- the turret: body, courses, an open stage with corner pinnacles, a slate spire with a gold cross
		local tx = sx * 34
		box("Turret", sx * 28, 8, -82, sx * 40, 64, -70, STONE, WHITE_STONE, f)
		for _, y in ipairs({ 36, 62 }) do
			box("TurretCourse", sx * 27, y, -83, sx * 41, y + 2, -69, GREYB, GREY_STONE, f)
		end
		for _, w in ipairs({ { 18, 30 }, { 42, 56 } }) do
			glass("TurretLancet", tx - 1, w[1], -70, tx + 1, w[2], -69.6, GLASS_BLUE, f)
			glass("TurretLancet", tx - 0.5, w[2], -70, tx + 0.5, w[2] + 1.5, -69.6, GLASS_CYAN, f)
			box("TurretSill", tx - 1.5, w[1] - 1, -70, tx + 1.5, w[1], -69.4, SMOOTH, GREY_STONE, f)
			glass("TurretLancet", sx * 40, w[1], -77, sx * 40.4, w[2], -75, GLASS_BLUE, f)
			glass("TurretLancet", sx * 40, w[2], -76.5, sx * 40.4, w[2] + 1.5, -75.5, GLASS_CYAN, f)
			box(
				"TurretSill",
				sx * 40,
				w[1] - 1,
				-77.5,
				sx * 40.6,
				w[1],
				-74.5,
				SMOOTH,
				GREY_STONE,
				f
			)
		end
		box("TurretStage", sx * 30, 64, -80, sx * 38, 76, -72, STONE, WHITE_STONE, f)
		glass("TurretStageGlass", tx - 1, 66, -72, tx + 1, 74, -71.6, GLASS_CYAN, f)
		glass("TurretStageGlass", sx * 38, 66, -77, sx * 38.4, 74, -75, GLASS_CYAN, f)
		for _, cx in ipairs({ 28, 37 }) do
			for _, cz in ipairs({ -82, -73 }) do
				box(
					"TurretPinnacle",
					sx * cx,
					64,
					cz,
					sx * (cx + 3),
					70,
					cz + 3,
					STONE,
					WHITE_STONE,
					f
				)
				box(
					"TurretPinnacleTip",
					sx * (cx + 0.5),
					70,
					cz + 0.5,
					sx * (cx + 2.5),
					74,
					cz + 2.5,
					ROOF,
					SLATE,
					f
				)
			end
		end
		for i, hw in ipairs({ 4, 3, 2, 1 }) do
			local y0 = 76 + (i - 1) * 8
			box(
				"TurretSpire",
				tx - hw,
				y0,
				-76 - hw,
				tx + hw,
				y0 + (if hw == 1 then 6 else 8),
				-76 + hw,
				ROOF,
				SLATE,
				f
			)
		end
		box("TurretCross", tx - 0.5, 106, -76.5, tx + 0.5, 112, -75.5, GOLDB, nil, f)
		box("TurretCross", tx - 1.5, 109, -76.5, tx + 1.5, 110, -75.5, GOLDB, nil, f)
		gargoyle(CFrame.lookAt(V(sx * 40, 60, -70), V(sx * 50, 60, -60)), f)
	end
end
task.wait()

-- ================================================================ the nave walls: piers, lancets, flying buttresses
do
	local f = folder("NaveWalls", cath)
	local GLASS = { gB = GLASS_BLUE, gC = GLASS_CYAN, gW = GLASS_WHITE }
	-- a lancet 12 wide (uu -6..6): stone sill, two lights of diamond medallions, a pointed head with a small rose
	local function winKind(uu, y)
		if y < 12 then
			return "sill"
		end
		if y > 56 or not pointed(uu, y, 6, 10, 46) then
			return "stone"
		end
		if y > 46 then
			local dc = math.sqrt(uu * uu + (y - 50) ^ 2)
			return if dc < 1.5 then "gold" elseif dc < 3.2 then "gC" else "gB"
		end
		local p = math.clamp(math.floor((y - 12) / 12), 0, 2)
		local md = math.abs(uu - (if uu < 0 then -3 else 3)) + math.abs(y - (18 + 12 * p))
		if md <= 1 then
			return if p == 1 then "gold" else "gW"
		end
		return if md <= 3 then "gC" else "gB"
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, pc in ipairs(PZ) do
			box("Pier", sx * 20, 8, pc - 4, sx * 28, 68, pc + 4, STONE, WHITE_STONE, f)
			box("PierBase", sx * 19, 8, pc - 5, sx * 29, 11, pc + 5, GREYB, GREY_STONE, f)
			box("PierCap", sx * 20, 60, pc - 5, sx * 29, 62, pc + 5, GREYB, GREY_STONE, f)
			box("Pinnacle", sx * 22, 68, pc - 2, sx * 26, 76, pc + 2, STONE, WHITE_STONE, f)
			box("PinnacleTip", sx * 23, 76, pc - 1, sx * 25, 82, pc + 1, ROOF, SLATE, f)
			box("PinnacleGold", sx * 23.5, 82, pc - 0.5, sx * 24.5, 84, pc + 0.5, GOLDB, nil, f)
			-- inside: a white shaft with a capital and a stepped rib arch over the nave
			box("Shaft", sx * 18, 8, pc - 2, sx * 20, 50, pc + 2, SMOOTH, WHITE_STONE, f)
			box("Capital", sx * 17, 50, pc - 3, sx * 20, 53, pc + 3, SMOOTH, WHITE_STONE, f)
			decor(
				box("CapitalGold", sx * 17.9, 49.6, pc - 2.1, sx * 20, 50, pc + 2.1, GOLDB, nil, f)
			)
			box("Rib", sx * 16, 53, pc - 2, sx * 20, 60, pc + 2, SMOOTH, WHITE_STONE, f)
			box("Rib", sx * 12, 56, pc - 2, sx * 16, 60, pc + 2, SMOOTH, WHITE_STONE, f)
			if pc ~= -82 then
				-- the outer pier with its pinnacle, two stepped flyers, a gargoyle
				box("Buttress", sx * 34, 8, pc - 4, sx * 40, 20, pc + 4, STONE, WHITE_STONE, f)
				box("Buttress", sx * 36, 20, pc - 3, sx * 40, 56, pc + 3, STONE, WHITE_STONE, f)
				box("ButtressCap", sx * 35, 56, pc - 4, sx * 40, 58, pc + 4, GREYB, GREY_STONE, f)
				box(
					"ButtressPinnacle",
					sx * 36,
					58,
					pc - 2,
					sx * 40,
					66,
					pc + 2,
					STONE,
					WHITE_STONE,
					f
				)
				box("ButtressTip", sx * 37, 66, pc - 1, sx * 39, 74, pc + 1, ROOF, SLATE, f)
				box("ButtressGold", sx * 37.5, 74, pc - 0.5, sx * 38.5, 76, pc + 0.5, GOLDB, nil, f)
				box("Flyer", sx * 28, 54, pc - 2, sx * 32, 58, pc + 2, STONE, WHITE_STONE, f)
				box("Flyer", sx * 32, 50, pc - 2, sx * 36, 54, pc + 2, STONE, WHITE_STONE, f)
				box("Flyer", sx * 28, 38, pc - 2, sx * 32, 42, pc + 2, STONE, WHITE_STONE, f)
				box("Flyer", sx * 32, 34, pc - 2, sx * 36, 38, pc + 2, STONE, WHITE_STONE, f)
				gargoyle(CFrame.lookAt(V(sx * 40, 54, pc), V(sx * 60, 54, pc)), f)
			end
		end
		box("Parapet", sx * 24, 60, -166, sx * 27, 62, -78, STONE, WHITE_STONE, f)
		-- the four lancets of this side (between the piers)
		for b = 1, 4 do
			local zc = -92 - 20 * (b - 1)
			greedy(zc - 6, zc + 6, 8, 60, 2, function(u, y)
				return winKind(u - zc, y)
			end, function(k, ua, ub, ya, yb)
				if k == "sill" then
					box("WindowSill", sx * 22, ya, ua, sx * 26, yb, ub, SMOOTH, GREY_STONE, f)
				elseif k == "stone" then
					box("WindowStone", sx * 22, ya, ua, sx * 26, yb, ub, STONE, WHITE_STONE, f)
				elseif k == "gold" then
					box("WindowGold", sx * 23.4, ya, ua, sx * 24.6, yb, ub, GOLDB, nil, f)
				else
					glass("WindowGlass", sx * 23.5, ya, ua, sx * 24.5, yb, ub, GLASS[k], f)
				end
			end)
			decor(
				box("Mullion", sx * 23, 12, zc - 0.6, sx * 25, 52, zc + 0.6, SMOOTH, WHITE_STONE, f)
			)
			for _, y in ipairs({ 24, 36 }) do
				decor(
					box(
						"Transom",
						sx * 23,
						y - 0.6,
						zc - 6,
						sx * 25,
						y + 0.6,
						zc + 6,
						SMOOTH,
						WHITE_STONE,
						f
					)
				)
			end
		end
	end
end
task.wait()

-- ================================================================ the apse: glass columns and pinnacled corner piers
do
	local f = folder("Apse", cath)
	local GC = { B = GLASS_BLUE, C = GLASS_CYAN, W = GLASS_WHITE }
	local BANDS =
		{ { 12, 24, "B" }, { 24, 28, "C" }, { 28, 40, "B" }, { 40, 44, "W" }, { 44, 48, "B" } }
	for cx = -22, 22, 4 do
		for t = 2, 22, 4 do
			if not apseIn(cx, t) then
				local near, side = false, false
				for dx = -1, 1 do
					for dt = -1, 1 do
						if apseIn(cx + dx * 4, t + dt * 4) then
							near = true
							side = side or dx == 0 or dt == 0
						end
					end
				end
				local cz = -166 - t
				if near and side then
					-- a face cell: a lancet of glass bands, thin across the wall's normal
					local nx = apseIn(cx - 4, t) or apseIn(cx + 4, t)
					local nz = apseIn(cx, t - 4) or apseIn(cx, t + 4)
					local hx = if nx and not nz then 1 else 2
					local hz = if nz and not nx then 1 else 2
					box("ApseSill", cx - 2, 8, cz - 2, cx + 2, 12, cz + 2, SMOOTH, GREY_STONE, f)
					box("ApseLintel", cx - 2, 50, cz - 2, cx + 2, 60, cz + 2, STONE, WHITE_STONE, f)
					for bi, b in ipairs(BANDS) do
						local col = if bi == 3 and (cx + t) % 8 == 0 then "C" else b[3]
						glass(
							"ApseGlass",
							cx - hx,
							b[1],
							cz - hz,
							cx + hx,
							b[2],
							cz + hz,
							GC[col],
							f
						)
					end
					box("ApseGold", cx - hx, 48, cz - hz, cx + hx, 50, cz + hz, GOLDB, nil, f)
				elseif near then
					-- a corner of the stepped wall: a pier with a slate pinnacle
					box("ApsePier", cx - 2, 8, cz - 2, cx + 2, 64, cz + 2, STONE, WHITE_STONE, f)
					box("ApsePinnacle", cx - 1, 64, cz - 1, cx + 1, 72, cz + 1, ROOF, SLATE, f)
					box(
						"ApseGoldTip",
						cx - 0.5,
						72,
						cz - 0.5,
						cx + 0.5,
						74,
						cz + 0.5,
						GOLDB,
						nil,
						f
					)
				end
			end
		end
	end
end
task.wait()

-- ================================================================ the roof: slate steps, the ridge, the flèche
do
	local f = folder("Roof", cath)
	for k = 0, 5 do
		local hw, y = 24 - 4 * k, 60 + 4 * k
		box("Roof", -hw, y, -166, hw, y + 4, -78, ROOF, SLATE, f)
		-- the apse end: rows of cells inside the shrinking half-octagon
		for t = 2, 22, 4 do
			local m
			for cx = 2, 22, 4 do
				if apseR(cx, t) < 24 - 4 * k then
					m = cx
				end
			end
			if m then
				box("ApseRoof", -(m + 2), y, -168 - t, m + 2, y + 4, -164 - t, ROOF, SLATE, f)
			end
		end
	end
	box("Ridge", -2, 84, -168, 2, 86, -78, ROOF, Color3.fromRGB(52, 60, 92), f)
	for z = -86, -166, -16 do
		box("RidgeFinial", -0.5, 86, z - 0.5, 0.5, 89, z + 0.5, GOLDB, nil, f)
	end
	-- the flèche over the crossing
	box("Fleche", -4, 84, -150, 4, 96, -142, STONE, WHITE_STONE, f)
	glass("FlecheGlass", -1, 87, -142, 1, 94, -141.6, GLASS_CYAN, f)
	glass("FlecheGlass", -1, 87, -150.4, 1, 94, -150, GLASS_CYAN, f)
	box("FlecheCornice", -5, 96, -151, 5, 98, -141, GREYB, GREY_STONE, f)
	box("FlecheSpire", -3, 98, -149, 3, 106, -143, ROOF, SLATE, f)
	box("FlecheSpire", -2, 106, -148, 2, 116, -144, ROOF, SLATE, f)
	box("FlecheSpire", -1, 116, -147, 1, 126, -145, ROOF, SLATE, f)
	box("FlecheCross", -0.5, 126, -146.5, 0.5, 134, -145.5, GOLDB, nil, f)
	box("FlecheCross", -2.5, 130, -146.5, 2.5, 131, -145.5, GOLDB, nil, f)
end
task.wait()

-- ================================================================ inside: mosaic, pews, altar, pulpit, organ, light
do
	local f = folder("Interior", cath)
	-- the mosaic: a blue lattice with lapis centres down the aisle and over the crossing and the apse, white elsewhere
	greedy(-20, 20, -190, -78, 4, function(x, z)
		if not apseIn(x, -166 - z) then
			return nil
		end
		if math.abs(x) < 8 or z < -138 then
			local i, j = math.floor((x + 20) / 4), math.floor((-78 - z) / 4)
			local a, b = (i + j) % 4, (i - j) % 4
			if (a == 0 and b == 0) or (a == 2 and b == 2) then
				return "l"
			end
			if a == 0 or b == 0 then
				return "b"
			end
		end
		return "w"
	end, function(k, xa, xb, za, zb)
		if k == "w" then
			box("Mosaic", xa, 8, za, xb, 8.1, zb, SMOOTH, WHITE_STONE, f)
		elseif k == "b" then
			box("Mosaic", xa, 8, za, xb, 8.1, zb, "px_terracotta_blue", nil, f)
		else
			box("Mosaic", xa, 8, za, xb, 8.1, zb, "px_lapis_block", nil, f)
		end
	end)
	-- pews (a seat, a back and an oak end) on both sides of the aisle
	for _, sx in ipairs({ -1, 1 }) do
		for zr = -92, -134, -6 do
			box("PewSeat", sx * 9, 8, zr - 2, sx * 17, 10, zr + 1, "px_spruce_planks", nil, f)
			box("PewBack", sx * 9, 10, zr + 1, sx * 17, 13, zr + 2, "px_spruce_planks", nil, f)
			box("PewEnd", sx * 8, 8, zr - 2, sx * 9, 12, zr + 2, OAK_DARK, nil, f)
		end
		-- blue banners with a white cross on the shafts
		for k = 2, 5 do
			crossBanner(at(sx * 17.6, 34, PZ[k]) * CFrame.Angles(0, math.pi / 2, 0), 4, 12, f)
		end
	end
	-- candles on dark stands: the entrance, the crossing (lit), by the pulpit and the organ, by the altar (lit)
	local function stand(x, y0, z, lit)
		box("CandleStand", x - 2, y0, z - 2, x + 2, y0 + 1, z + 2, "px_blackstone", nil, f)
		box("CandleStand", x - 1, y0 + 1, z - 1, x + 1, y0 + 6, z + 1, "px_blackstone", nil, f)
		box(
			"CandleStand",
			x - 1.6,
			y0 + 6,
			z - 1.6,
			x + 1.6,
			y0 + 7,
			z + 1.6,
			"px_blackstone",
			nil,
			f
		)
		candles(x, y0 + 7, z, lit, f)
	end
	for _, sx in ipairs({ -1, 1 }) do
		stand(sx * 14, 8, -84, false)
		stand(sx * 10, 8, -144, true)
		stand(sx * 10, 8, -164, false)
		stand(sx * 10, 9, -176, true)
	end
	-- the altar on a two-step dais in the apse: white stone, a gold front, a cloth, a retable with a gold cross
	box("Dais", -12, 8, -182, 12, 9, -170, SMOOTH, WHITE_STONE, f)
	box("Dais", -8, 8, -186, 8, 9, -182, SMOOTH, WHITE_STONE, f)
	box("Dais", -8, 9, -184, 8, 10, -172, "px_terracotta_blue", Color3.fromRGB(220, 226, 255), f)
	box("Altar", -6, 10, -180, 6, 14, -176, SMOOTH, WHITE_STONE, f)
	decor(box("AltarFront", -5, 10.6, -176.2, 5, 13.4, -175.8, GOLDB, nil, f))
	box("AltarCloth", -6.5, 14, -180.5, 6.5, 14.4, -175.5, "px_white_wool", nil, f)
	decor(box("AltarRunner", -1.5, 14, -180.6, 1.5, 14.5, -175.4, "px_white_wool", BANNER_BLUE, f))
	box("Retable", -6, 10, -184, 6, 24, -182, STONE, WHITE_STONE, f)
	box("RetableTop", -2, 24, -184, 2, 28, -182, STONE, WHITE_STONE, f)
	box("RetableTip", -0.5, 28, -183.5, 0.5, 30, -182.5, GOLDB, nil, f)
	decor(box("AltarCross", -0.8, 14, -181.9, 0.8, 23, -181.5, GOLDB, nil, f))
	decor(box("AltarCross", -3.5, 19, -181.9, 3.5, 20.6, -181.5, GOLDB, nil, f))
	for _, c in ipairs({
		{ -5, 2.4, true },
		{ -3, 1.8, false },
		{ 3, 1.8, false },
		{ 5, 2.4, true },
	}) do
		local flame = candle(c[1], 14.4, -178, c[2], true, f)
		if c[3] then
			light(flame, 24, 1.2, FLAME)
			nLights += 1
		end
	end
	-- the pulpit (west of the crossing): a stone stem, an oak tub, a sounding board, a stair from the north
	box("PulpitStem", -16, 8, -152, -12, 14, -148, STONE, WHITE_STONE, f)
	box("PulpitTub", -18, 14, -154, -10, 18, -146, OAK_DARK, nil, f)
	decor(box("PulpitGold", -18.2, 16.8, -154.2, -9.8, 17.4, -145.8, GOLDB, nil, f))
	box("PulpitPost", -18, 18, -151, -17, 28, -149, OAK_DARK, nil, f)
	box("PulpitCanopy", -19, 28, -155, -9, 29, -145, OAK_DARK, nil, f)
	box("PulpitFinial", -14.5, 29, -150.5, -13.5, 31, -149.5, GOLDB, nil, f)
	stairs("PulpitStep", -14, -160, -154, 8, 10, 4, OAK_DARK, f)
	-- the lectern (east of the crossing) with an open book
	box("LecternBase", 13.5, 8, -141.5, 16.5, 9, -138.5, OAK_DARK, nil, f)
	box("LecternPost", 14.5, 9, -140.5, 15.5, 13, -139.5, OAK_DARK, nil, f)
	local top = textured(
		part(
			"LecternTop",
			Vector3.new(3.4, 0.6, 3),
			at(15, 13.4, -140) * CFrame.Angles(math.rad(-22), 0, 0),
			nil,
			nil,
			f
		),
		"px_spruce_planks"
	)
	decor(
		part(
			"LecternBook",
			Vector3.new(2.8, 0.3, 2),
			top.CFrame * CFrame.new(0, 0.45, 0),
			BANNER_BLUE,
			Enum.Material.Fabric,
			f
		)
	)
	decor(
		part(
			"LecternPages",
			Vector3.new(2.5, 0.2, 1.8),
			top.CFrame * CFrame.new(0, 0.65, 0),
			WAX,
			Enum.Material.SmoothPlastic,
			f
		)
	)
	-- the organ (east, before the fourth lancet): an oak case, a console, two ranks of iron pipes
	box("OrganCase", 12, 8, -158, 20, 20, -146, OAK_DARK, nil, f)
	decor(box("OrganGold", 11.8, 19.4, -158.2, 20, 20, -145.8, GOLDB, nil, f))
	box("OrganConsole", 10, 8, -156, 12, 12, -148, OAK_DARK, nil, f)
	decor(box("OrganKeys", 10, 12, -155, 11.6, 12.5, -149, "px_white_wool", nil, f))
	decor(box("OrganKeysBlack", 10.6, 12.5, -155, 11.2, 12.8, -149, "px_blackstone", nil, f))
	decor(box("OrganMusicStand", 11.4, 12, -154, 12, 15, -150, "px_spruce_planks", nil, f))
	box("OrganBench", 8, 8, -155, 9.6, 10, -149, "px_spruce_planks", nil, f)
	for n, h in ipairs({ 8, 12, 16, 16, 12, 8 }) do
		local z0 = -158 + 2 * (n - 1)
		box("OrganPipe", 14, 20, z0, 16, 20 + h, z0 + 2, "px_iron_block", nil, f)
		decor(
			box("OrganPipeMouth", 13.8, 21.5, z0 + 0.5, 14, 22.5, z0 + 1.5, "px_blackstone", nil, f)
		)
	end
	for n, h in ipairs({ 14, 22, 14 }) do
		local z0 = -158 + 4 * (n - 1)
		box("OrganPipe", 16.5, 20, z0, 19.5, 20 + h, z0 + 4, "px_iron_block", nil, f)
	end
	-- two iron chandeliers hung from the vault, mid-bay
	for _, cz in ipairs({ -112, -132 }) do
		iron("ChandelierChain", -0.3, 46, cz - 0.3, 0.3, 60, cz + 0.3, f)
		local hub = iron("ChandelierHub", -1, 43, cz - 1, 1, 46, cz + 1, f)
		for _, s in ipairs({ -1, 1 }) do
			iron("ChandelierRing", -5.5, 44, cz + s * 5 - 0.5, 5.5, 45, cz + s * 5 + 0.5, f)
			iron("ChandelierRing", s * 5 - 0.5, 44, cz - 4.5, s * 5 + 0.5, 45, cz + 4.5, f)
		end
		iron("ChandelierSpoke", -5, 44.2, cz - 0.3, 5, 44.8, cz + 0.3, f)
		iron("ChandelierSpoke", -0.3, 44.2, cz - 5, 0.3, 44.8, cz + 5, f)
		for _, c in ipairs({
			{ -5, -5 },
			{ 5, -5 },
			{ 5, 5 },
			{ -5, 5 },
			{ 0, -5 },
			{ 0, 5 },
			{ -5, 0 },
			{ 5, 0 },
		}) do
			candle(c[1], 45, cz + c[2], 1.4, true, f)
		end
		light(hub, 44, 1.6, FLAME)
		nLights += 1
	end
end
task.wait()

-- ================================================================ the bell tower: walls, the stair, the belfry, the spire
do
	local tw = folder("BellTower", cath)
	-- a rectangle in a wall face: u along the face, d = depth from the outer face inward (0..4)
	local function frect(face, u0, u1, d0, d1)
		if face == "S" then
			return u0, -70 - d1, u1, -70 - d0
		elseif face == "N" then
			return u0, -98 + d0, u1, -98 + d1
		elseif face == "W" then
			return 48 + d0, u0, 48 + d1, u1
		end
		return 76 - d1, u0, 76 - d0, u1
	end
	-- the walls y 0..104 as columns; holes: glass windows (with a sill) or the door
	local WALLS = {
		{
			"S",
			{
				{ 48, 52 },
				{ 52, 58, { 0, 14, "door" } },
				{ 58, 60 },
				{ 60, 64, { 14, 26 }, { 44, 58 }, { 76, 90 } },
				{ 64, 76 },
			},
		},
		{ "N", { { 48, 60 }, { 60, 64, { 18, 30 }, { 52, 62 }, { 84, 98 } }, { 64, 76 } } },
		{ "W", { { -94, -86 }, { -86, -82, { 36, 50 }, { 68, 80 }, { 86, 100 } }, { -82, -74 } } },
		{ "E", { { -94, -86 }, { -86, -82, { 18, 30 }, { 48, 60 }, { 80, 94 } }, { -82, -74 } } },
	}
	for _, w in ipairs(WALLS) do
		local face = w[1]
		for _, c in ipairs(w[2]) do
			local y = 0
			for hi = 3, #c do
				local h = c[hi]
				local x0, z0, x1, z1 = frect(face, c[1], c[2], 0, 4)
				if h[1] > y then
					box("TowerWall", x0, y, z0, x1, h[1], z1, STONE, WHITE_STONE, tw)
				end
				if h[3] == "door" then
					-- a pointed door: full width to y 12, the middle 2 studs to 14
					local a0, b0, a1, b1 = frect(face, c[1], c[1] + 2, 0, 4)
					box("TowerDoorHead", a0, 12, b0, a1, 14, b1, STONE, WHITE_STONE, tw)
					a0, b0, a1, b1 = frect(face, c[2] - 2, c[2], 0, 4)
					box("TowerDoorHead", a0, 12, b0, a1, 14, b1, STONE, WHITE_STONE, tw)
					for _, j in ipairs({ { c[1] - 1, c[1] }, { c[2], c[2] + 1 } }) do
						a0, b0, a1, b1 = frect(face, j[1], j[2], -0.5, 0.5)
						box("TowerDoorFrame", a0, 0, b0, a1, 15, b1, GREYB, GREY_STONE, tw)
					end
					a0, b0, a1, b1 = frect(face, c[1] - 1, c[2] + 1, -0.5, 0.5)
					box("TowerDoorFrame", a0, 14, b0, a1, 15, b1, GREYB, GREY_STONE, tw)
				else
					local g0, g1, g2, g3 = frect(face, c[1], c[2], 1.5, 2.5)
					glass(
						"TowerWindow",
						g0,
						h[1],
						g1,
						g2,
						h[2],
						g3,
						if hi % 2 == 0 then GLASS_CYAN else GLASS_BLUE,
						tw
					)
					local s0, s1, s2, s3 = frect(face, c[1], c[2], -0.6, 3.5)
					box("TowerSill", s0, h[1] - 1, s1, s2, h[1], s3, SMOOTH, GREY_STONE, tw)
				end
				y = h[2]
			end
			local x0, z0, x1, z1 = frect(face, c[1], c[2], 0, 4)
			box("TowerWall", x0, y, z0, x1, 104, z1, STONE, WHITE_STONE, tw)
		end
	end
	-- corner buttresses (two per corner, stepped), string courses, gargoyles at the corners
	for _, c in ipairs({
		{ 48, -70, -1, 1 },
		{ 76, -70, 1, 1 },
		{ 48, -98, -1, -1 },
		{ 76, -98, 1, -1 },
	}) do
		local cx, cz, dx, dz = c[1], c[2], c[3], c[4]
		local xa, za = cx - dx * 4, cz - dz * 4
		box("TowerButtress", xa, 0, cz, cx, 56, cz + dz * 4, STONE, WHITE_STONE, tw)
		box("TowerButtress", xa, 56, cz, cx, 96, cz + dz * 2, STONE, WHITE_STONE, tw)
		box("TowerButtressCap", xa, 96, cz, cx, 98, cz + dz * 2.5, GREYB, GREY_STONE, tw)
		box("TowerButtress", cx, 0, za, cx + dx * 4, 56, cz, STONE, WHITE_STONE, tw)
		box("TowerButtress", cx, 56, za, cx + dx * 2, 96, cz, STONE, WHITE_STONE, tw)
		box("TowerButtressCap", cx, 96, za, cx + dx * 2.5, 98, cz, GREYB, GREY_STONE, tw)
		gargoyle(CFrame.lookAt(V(cx, 96, cz), V(cx + dx * 10, 96, cz + dz * 10)), tw)
	end
	for _, y in ipairs({ 32, 64, 102 }) do
		box("TowerCourse", 47, y, -99, 77, y + 2, -98, GREYB, GREY_STONE, tw)
		box("TowerCourse", 47, y, -70, 77, y + 2, -69, GREYB, GREY_STONE, tw)
		box("TowerCourse", 47, y, -98, 48, y + 2, -70, GREYB, GREY_STONE, tw)
		box("TowerCourse", 76, y, -98, 77, y + 2, -70, GREYB, GREY_STONE, tw)
	end
	crossBanner(at(68, 24, -69.6), 4, 10, tw)
	decor(box("TowerDoorLeaf", 52, 0, -80, 53, 12, -74, OAK_DARK, nil, tw))
	-- the stair: 13 flights round the pier (S strip east, E north, N west, W south), landings in the corners
	box("StairPier", 58, 0, -88, 66, 104, -80, STONE, WHITE_STONE, tw)
	local CORNERS =
		{ { 66, -80, 72, -74 }, { 66, -94, 72, -88 }, { 52, -94, 58, -88 }, { 52, -80, 58, -74 } }
	for i = 1, 13 do
		local s, y0 = (i - 1) % 4, 8 * (i - 1)
		if s == 0 then
			stairs("TowerStep", -77, 58, 66, y0, 8, 6, GREYB, tw, "x")
		elseif s == 1 then
			stairs("TowerStep", 69, -80, -88, y0, 8, 6, GREYB, tw)
		elseif s == 2 then
			stairs("TowerStep", -91, 66, 58, y0, 8, 6, GREYB, tw, "x")
		else
			stairs("TowerStep", 55, -88, -80, y0, 8, 6, GREYB, tw)
		end
		if i < 13 then
			local c = CORNERS[s + 1]
			box("TowerLanding", c[1], y0 + 4, c[2], c[3], y0 + 8, c[4], GREYB, GREY_STONE, tw)
		end
	end
	for _, l in ipairs({
		{ 57.2, 44, -84, -1, 0 },
		{ 66.8, 26, -84, 1, 0 },
		{ 62, 84, -79.2, 0, 1 },
	}) do
		iron(
			"LanternBracket",
			l[1] - math.abs(l[4]) * 0.8 - 0.3,
			l[2] + 1,
			l[3] - math.abs(l[5]) * 0.8 - 0.3,
			l[1] + math.abs(l[4]) * 0.8 + 0.3,
			l[2] + 1.5,
			l[3] + math.abs(l[5]) * 0.8 + 0.3,
			tw
		)
		lantern(V(l[1], l[2], l[3]), tw)
		nLights += 1
	end
	-- the belfry floor (y 104, the SUMMIT): the north and east bands and the pier top; the stairwell (W strip, SW
	-- corner, S strip) stays open under the sky, railed
	box("BelfryFloor", 52, 100, -94, 72, 104, -88, SMOOTH, WHITE_STONE, tw)
	box("BelfryFloor", 66, 100, -88, 72, 104, -74, SMOOTH, WHITE_STONE, tw)
	box("StairwellRail", 52, 104, -89, 58, 107.5, -88, SMOOTH, GREY_STONE, tw)
	box("StairwellRail", 58, 104, -88, 59, 107.5, -80, SMOOTH, GREY_STONE, tw)
	box("StairwellRail", 58, 104, -81, 66, 107.5, -80, SMOOTH, GREY_STONE, tw)
	-- corner piers and the four open pointed arches with a parapet and an iron rail
	for _, cx in ipairs({ 48, 72 }) do
		for _, cz in ipairs({ -98, -74 }) do
			box("BelfryPier", cx, 104, cz, cx + 4, 136, cz + 4, STONE, WHITE_STONE, tw)
		end
	end
	for _, face in ipairs({ "S", "N", "W", "E" }) do
		local ua = if face == "S" or face == "N" then 52 else -94
		local uc = ua + 10
		greedy(ua, ua + 20, 104, 136, 2, function(u, y)
			if math.abs(u - uc) > 6 then
				return "stone"
			end
			if y < 108 then
				return "rail"
			end
			return if pointed(u - uc, y, 6, 8, 122) then nil else "stone"
		end, function(k, u0, u1, y0, y1)
			if k == "rail" then
				local x0, z0, x1, z1 = frect(face, u0, u1, 0.5, 3.5)
				box("BelfryParapet", x0, y0, z0, x1, y1, z1, SMOOTH, GREY_STONE, tw)
			else
				local x0, z0, x1, z1 = frect(face, u0, u1, 0, 4)
				box("BelfryWall", x0, y0, z0, x1, y1, z1, STONE, WHITE_STONE, tw)
			end
		end)
		local x0, z0, x1, z1 = frect(face, uc - 6, uc + 6, 1.7, 2.3)
		local rail = box("BelfryRail", x0, 109, z0, x1, 109.6, z1, nil, IRON, tw)
		rail.Material = Enum.Material.Metal
		for _, u in ipairs({ uc - 5.8, uc, uc + 5.8 }) do
			x0, z0, x1, z1 = frect(face, u - 0.2, u + 0.2, 1.8, 2.2)
			iron("BelfryRailPost", x0, 108, z0, x1, 109, z1, tw)
		end
		x0, z0, x1, z1 = frect(face, uc - 1, uc + 1, -0.4, 0)
		box("BelfryKeystone", x0, 129, z0, x1, 132, z1, GOLDB, nil, tw)
	end
	box("BelfryCornice", 46, 136, -100, 78, 140, -68, GREYB, GREY_STONE, tw)
	-- the bronze bell under an oak headstock on a beam through the band above the arches; an iron clapper
	box("BellBeam", 48, 130, -85.5, 76, 133, -82.5, OAK_DARK, nil, tw)
	box("BellHeadstock", 58, 127, -86, 66, 130, -82, OAK_DARK, nil, tw)
	iron("BellStrap", 59.5, 125, -86.2, 60.5, 130, -81.8, tw)
	iron("BellStrap", 63.5, 125, -86.2, 64.5, 130, -81.8, tw)
	box("Bell", 56, 112, -90, 68, 114, -78, GOLDB, BRONZE, tw)
	box("Bell", 57, 114, -89, 67, 120, -79, GOLDB, BRONZE, tw)
	box("Bell", 58, 120, -88, 66, 124, -80, GOLDB, BRONZE, tw)
	box("Bell", 59, 124, -87, 65, 126, -81, GOLDB, BRONZE, tw)
	box("BellCrown", 60, 126, -85, 64, 127, -83, GOLDB, BRONZE, tw)
	decor(box("BellBand", 56.8, 117, -89.2, 67.2, 118, -78.8, GOLDB, nil, tw))
	decor(box("BellBand", 55.8, 113, -90.2, 68.2, 113.6, -77.8, GOLDB, nil, tw))
	iron("BellClapper", 61.6, 109, -84.4, 62.4, 114, -83.6, tw)
	iron("BellClapperBall", 60.8, 107, -85.2, 63.2, 109.4, -82.8, tw)
	lantern(V(60, 122, -92), tw, false, BY + 136)
	nLights += 1
	-- the slate spire: stepped to y 180, lucarnes on its faces, pinnacles on the cornice corners, a gold cross
	for i, hw in ipairs({ 12, 10, 8, 6, 4, 2 }) do
		local y0 = 140 + 6 * (i - 1)
		box(
			"Spire",
			62 - hw,
			y0,
			-84 - hw,
			62 + hw,
			if hw == 2 then 180 else y0 + 6,
			-84 + hw,
			ROOF,
			SLATE,
			tw
		)
	end
	for _, l in ipairs({
		{ 62, -73, 0, 1 },
		{ 62, -95, 0, -1 },
		{ 51, -84, -1, 0 },
		{ 73, -84, 1, 0 },
	}) do
		local lx, lz, dx, dz = l[1], l[2], l[3], l[4]
		local ax, az = if dx == 0 then 3 else 2, if dz == 0 then 3 else 2
		box("Lucarne", lx - ax, 146, lz - az, lx + ax, 153, lz + az, STONE, WHITE_STONE, tw)
		-- a dark opening plate on the outward face
		local ox0, ox1 =
			if dx == 0 then lx - 1.2 else lx + dx * ax,
			if dx == 0 then lx + 1.2 else lx + dx * (ax + 0.2)
		local oz0, oz1 =
			if dz == 0 then lz - 1.2 else lz + dz * az,
			if dz == 0 then lz + 1.2 else lz + dz * (az + 0.2)
		decor(box("LucarneOpening", ox0, 147, oz0, ox1, 151.5, oz1, "px_blackstone", nil, tw))
		box(
			"LucarneCap",
			lx - ax - 0.5,
			153,
			lz - az - 0.5,
			lx + ax + 0.5,
			155,
			lz + az + 0.5,
			ROOF,
			SLATE,
			tw
		)
	end
	for _, cx in ipairs({ 46, 74 }) do
		for _, cz in ipairs({ -100, -72 }) do
			box("SpirePinnacle", cx, 140, cz, cx + 4, 150, cz + 4, STONE, WHITE_STONE, tw)
			box("SpirePinnacleTip", cx + 1, 150, cz + 1, cx + 3, 158, cz + 3, ROOF, SLATE, tw)
			box(
				"SpirePinnacleGold",
				cx + 1.5,
				158,
				cz + 1.5,
				cx + 2.5,
				160,
				cz + 2.5,
				GOLDB,
				nil,
				tw
			)
		end
	end
	box("SpireBall", 61, 180, -85, 63, 182, -83, GOLDB, nil, tw)
	box("SpireCross", 61.5, 182, -84.5, 62.5, 192, -83.5, GOLDB, nil, tw)
	box("SpireCross", 59, 187, -84.5, 65, 188, -83.5, GOLDB, nil, tw)
end
print(("[build-church] cathedral: %d parts, %d point lights"):format(count - partsBefore, nLights))
