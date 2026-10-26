-- ================================================================ market: the prison wall, the towers, the gates, the dock, the cliff path
-- The wall ring |x| or |z| = 184..192, 7 blocks high, a cobblestone plinth; the cap (y 24..28) is the wall-walk, one
-- block of it overhangs inside on corbels (180..184) so the walk is 2 blocks wide behind the merlons. 9 watch towers
-- (6×6 blocks, centre on the ring at |v| = 192: 4 corners, 2 at the south gatehouse, one at the north gate, the west
-- gate and the east postern), each with a guard room on the wall-walk (doorways where the walk passes), a ladder up
-- through a hatch to the wooden top floor and a stepped plank roof. Gate gaps are widened to the 4-stud grid:
-- south / north x -52..-28, west z 4..28, east postern z 8..24. Stairs up to the wall-walk: STAIRS_AT below.
-- The dock leaves the south gate (z 204) to z 284; the cliff path leaves the postern (x 192, z 8..24) along the east
-- cliff (x 216..232) down to the cave mouth (208, -48, -110).
local walls = folder("Walls")
local partsBefore = count
local METAL = Color3.fromRGB(44, 44, 48)
local ROPE = Color3.fromRGB(125, 98, 66)
local BONE = Color3.fromRGB(228, 222, 200)
local STONE_DARK = Color3.fromRGB(122, 120, 116)
local PLINTH_T = Color3.fromRGB(150, 146, 140)
local FLAGS = { WOOL_RED, WOOL_YELLOW, WOOL_LIME, WOOL_WHITE }
-- yaw that turns a CFrame's +Z to face outward from a face (N = -Z, S = +Z, W = -X, E = +X)
local YAW = { N = math.pi, S = 0, W = -math.pi / 2, E = math.pi / 2 }
-- the four sides of the ring: N / S run along x, W / E along z; s = the outward sign; w = |z| (N/S) or |x| (W/E)
local SIDES = {
	N = { along = "x", s = -1 },
	S = { along = "x", s = 1 },
	W = { along = "z", s = -1 },
	E = { along = "z", s = 1 },
}
local SIDE_ORDER = { "N", "S", "W", "E" }
-- the stairs up to the wall-walk: along the inner face (w 176..184), from u low end (y 0) to u high end (y 28) next
-- to a tower doorway
local STAIRS_AT = { S = { 44, -4 }, N = { -124, -76 }, W = { -68, -20 }, E = { 96, 48 } }

local function stoneTint(lo, hi)
	local g = rng:NextInteger(lo or 140, hi or 168)
	local warm = rng:NextInteger(-5, 5)
	return Color3.fromRGB(g + warm, g, g - warm)
end
-- a box on a side of the ring: u along the side, w = distance from the centre line
local function sbox(side, name, u0, y0, w0, u1, y1, w1, variant, tint, parent)
	if side.along == "x" then
		return box(name, u0, y0, side.s * w0, u1, y1, side.s * w1, variant, tint, parent)
	end
	return box(name, side.s * w0, y0, u0, side.s * w1, y1, u1, variant, tint, parent)
end
local function sxz(side, u, w)
	if side.along == "x" then
		return u, side.s * w
	end
	return side.s * w, u
end
local function faceCF(dir, x, y, z)
	return at(x, y, z) * CFrame.Angles(0, YAW[dir], 0)
end
-- an iron-bar window on a wall face: a dark opening block with bars (cf on the face, +Z outward)
local function barWindow(cf, parent)
	local hole = part("WindowHole", Vector3.new(4, 8, 0.3), cf * CFrame.new(0, 0, 0.15), nil, nil, parent)
	textured(decor(hole), "px_coal_block", Color3.fromRGB(80, 80, 86))
	for _, x in ipairs({ -1, 1 }) do
		decor(part("WindowBar", Vector3.new(0.5, 8, 0.5), cf * CFrame.new(x, 0, 0.45), METAL, Enum.Material.Metal, parent))
	end
	decor(part("WindowBar", Vector3.new(4, 0.5, 0.5), cf * CFrame.new(0, 1, 0.45), METAL, Enum.Material.Metal, parent))
end
-- a lantern on a bracket out of a wall face at (x, y, z) local, (nx, nz) the outward normal
local function wallLantern(x, y, z, nx, nz, parent)
	local arm = part("LanternArm", Vector3.new(if nx ~= 0 then 2.6 else 0.8, 0.8, if nz ~= 0 then 2.6 else 0.8), at(x + nx * 1.3, y, z + nz * 1.3), nil, nil, parent)
	textured(decor(arm), WOOD_DARK)
	lantern(V(x + nx * 2.3, y - 1.6, z + nz * 2.3), parent, false, y - 0.4)
end
-- a long banner (2 × 5 blocks) on a face, red with a yellow motif or yellow with a red one, and a stripe at the foot
local function longBanner(dir, x, y, z, red, parent, h)
	h = h or 20
	local cf = faceCF(dir, x, y, z) * CFrame.new(0, 0, 0.4)
	local color = if red then BANNER_RED else BANNER_YELLOW
	local motif = if red then BANNER_YELLOW else BANNER_RED
	banner(cf, color, parent, motif, 8, h)
	decor(part("BannerStripe", Vector3.new(8, 1.2, 0.26), cf * CFrame.new(0, -h / 2 + 2.5, 0), motif, Enum.Material.Fabric, parent))
end

-- ================================================================ the wall ring
do
	local ring = folder("Ring", walls)
	-- spans of each side taken by towers and gate gaps (the corner towers cover |u| > 180)
	local BLOCKED = {
		N = { { -76, -28 } },
		S = { { -76, -4 } },
		W = { { -20, 28 } },
		E = { { 8, 48 } },
	}
	for _, dir in ipairs(SIDE_ORDER) do
		local side = SIDES[dir]
		local spans, cur = {}, -180
		for _, b in ipairs(BLOCKED[dir]) do
			if b[1] > cur then
				table.insert(spans, { cur, b[1] })
			end
			cur = math.max(cur, b[2])
		end
		if cur < 180 then
			table.insert(spans, { cur, 180 })
		end
		local st = STAIRS_AT[dir]
		local s0, s1 = math.min(st[1], st[2]), math.max(st[1], st[2])
		for _, sp in ipairs(spans) do
			local u0, u1 = sp[1], sp[2]
			-- the plinth: one block of cobblestone, a block wider outside
			sbox(side, "WallPlinth", u0, 0, 184, u1, 4, 196, "px_cobblestone", PLINTH_T, ring)
			-- the cap = the wall-walk; it overhangs one block inside, except over the stairs (they climb along the face)
			local cuts = { u0 }
			if s0 > u0 and s0 < u1 then
				table.insert(cuts, s0)
			end
			if s1 > u0 and s1 < u1 then
				table.insert(cuts, s1)
			end
			table.insert(cuts, u1)
			for i = 1, #cuts - 1 do
				local a, b = cuts[i], cuts[i + 1]
				local overStair = a >= s0 and b <= s1
				sbox(side, "WallWalk", a, 24, if overStair then 184 else 180, b, 28, 192, "px_stone_bricks", Color3.fromRGB(168, 165, 158), ring)
			end
			-- the body in segments of 2..5 blocks: a slightly different grey each, moss and cobble patches at the foot
			local u = u0
			while u < u1 - 0.01 do
				local len = math.min(u1 - u, rng:NextInteger(2, 5) * B)
				local tint = stoneTint()
				local r = rng:NextNumber()
				local low = if r < 0.55 then "px_stone_bricks" elseif r < 0.85 then "px_mossy_stone_bricks" else "px_cobblestone"
				sbox(side, "WallFoot", u, 4, 184, u + len, 12, 192, low, tint, ring)
				local high = if rng:NextNumber() < 0.12 then "px_mossy_stone_bricks" else "px_stone_bricks"
				sbox(side, "Wall", u, 12, 184, u + len, 24, 192, high, tint, ring)
				u += len
			end
			-- merlons on the outer edge every other block; a lantern on every third merlon (every 6 blocks)
			for gu = math.ceil(u0 / 8) * 8, u1 - 4, 8 do
				sbox(side, "Merlon", gu, 28, 188, gu + 4, 32, 192, "px_stone_bricks", stoneTint(146, 170), ring)
				if gu % 24 == 0 then
					local x, z = sxz(side, gu + 2, 190)
					lantern(V(x, 32.75, z), ring)
				end
			end
			-- corbels under the overhanging walk
			for gu = math.ceil((u0 + 4) / 12) * 12, u1 - 8, 12 do
				if gu + 4 <= s0 or gu >= s1 then
					sbox(side, "WallCorbel", gu, 20, 180, gu + 4, 24, 184, "px_stone_bricks", STONE_DARK, ring)
				end
			end
			-- iron-bar windows on the outer face
			for gu = math.ceil(u0 / 48) * 48 + 24, u1 - 8, 48 do
				if gu - 6 >= u0 then
					local x, z = sxz(side, gu, 192)
					barWindow(faceCF(dir, x, 16, z), ring)
				end
			end
		end
	end
	-- the stairs up to the wall-walk: kit stairs (visible steps + invisible ramp) on a stepped stone fill
	for _, dir in ipairs(SIDE_ORDER) do
		local side = SIDES[dir]
		local uLow, uHigh = STAIRS_AT[dir][1], STAIRS_AT[dir][2]
		stairs("WallStairs", side.s * 180, uLow, uHigh, 0, 28, 8, "px_stone_bricks", ring, if side.along == "x" then "x" else nil)
		local run = math.abs(uHigh - uLow)
		local steps = math.max(1, math.floor(run / 2))
		local udir = if uHigh > uLow then 1 else -1
		for j = 0, 5 do
			-- under every step whose top is above this layer
			local k = math.floor(steps * (4 * j + 4) / 28)
			sbox(side, "StairFill", uLow + udir * k * run / steps, 4 * j, 176.05, uHigh, 4 * j + 4, 183.95, "px_stone_bricks", STONE_DARK, ring)
		end
	end
end
task.wait()

-- ================================================================ the watch towers
do
	local towers = folder("Towers", walls)
	-- doors: { face, a0, a1 } — a doorway on that face over [a0, a1] (x for N/S faces, z for W/E faces), y 28..40;
	-- ladder: the face the ladder climbs (an outer one); flags: faces with a long banner and two barred windows
	local function tower(name, cx, cz, doors, ladder, flags, red)
		local f = folder(name, towers)
		local x0, x1, z0, z1 = cx - 12, cx + 12, cz - 12, cz + 12
		local tint = stoneTint(145, 165)
		-- the footing steps down under the island edge (hidden in the rock where the island is wide enough)
		box("TowerFooting", x0 + 8, -44, z0 + 8, x1 - 8, -36, z1 - 8, "px_cobblestone", STONE_DARK, f)
		box("TowerFooting", x0 + 4, -36, z0 + 4, x1 - 4, -24, z1 - 4, "px_cobblestone", STONE_DARK, f)
		box("TowerBase", x0, -24, z0, x1, 4, z1, "px_cobblestone", PLINTH_T, f)
		box("TowerShaft", x0, 4, z0, x1, 12, z1, "px_mossy_stone_bricks", tint, f)
		box("TowerShaft", x0, 12, z0, x1, 28, z1, "px_stone_bricks", tint, f)
		local function doorOn(face)
			for _, d in ipairs(doors) do
				if d[1] == face then
					return d
				end
			end
			return nil
		end
		local function opens(face, a0, a1)
			local d = doorOn(face)
			return d ~= nil and math.min(a1, d[3]) - math.max(a0, d[2]) > 0.01
		end
		-- the guard room on the wall-walk (y 28..44): corner columns and the walls between them
		for _, c in ipairs({ { x0, z0, "N", "W" }, { x1 - 4, z0, "N", "E" }, { x0, z1 - 4, "S", "W" }, { x1 - 4, z1 - 4, "S", "E" } }) do
			local open = opens(c[3], c[1], c[1] + 4) or opens(c[4], c[2], c[2] + 4)
			box("TowerCorner", c[1], if open then 40 else 28, c[2], c[1] + 4, 44, c[2] + 4, "px_stone_bricks", tint, f)
		end
		for _, face in ipairs({ "N", "S", "W", "E" }) do
			local lo, hi = z0 + 4, z1 - 4
			if face == "N" or face == "S" then
				lo, hi = x0 + 4, x1 - 4
			end
			local function piece(a, b, ya, yb)
				if b - a < 0.01 then
					return
				end
				if face == "N" then
					box("TowerWall", a, ya, z0, b, yb, z0 + 4, "px_stone_bricks", tint, f)
				elseif face == "S" then
					box("TowerWall", a, ya, z1 - 4, b, yb, z1, "px_stone_bricks", tint, f)
				elseif face == "W" then
					box("TowerWall", x0, ya, a, x0 + 4, yb, b, "px_stone_bricks", tint, f)
				else
					box("TowerWall", x1 - 4, ya, a, x1, yb, b, "px_stone_bricks", tint, f)
				end
			end
			local d = doorOn(face)
			local a0, a1 = lo, lo
			if d then
				a0, a1 = math.max(lo, d[2]), math.min(hi, d[3])
			end
			if a1 - a0 > 0.01 then
				piece(lo, a0, 28, 44)
				piece(a1, hi, 28, 44)
				piece(a0, a1, 40, 44)
			else
				piece(lo, hi, 28, 44)
			end
		end
		-- the cornice ring and corbels that carry the overhanging wooden floor
		box("TowerCornice", x0 - 4, 40, z0 - 4, x1 + 4, 44, z0, "px_stone_bricks", STONE_DARK, f)
		box("TowerCornice", x0 - 4, 40, z1, x1 + 4, 44, z1 + 4, "px_stone_bricks", STONE_DARK, f)
		box("TowerCornice", x0 - 4, 40, z0, x0, 44, z1, "px_stone_bricks", STONE_DARK, f)
		box("TowerCornice", x1, 40, z0, x1 + 4, 44, z1, "px_stone_bricks", STONE_DARK, f)
		for _, o in ipairs({ -12, 8 }) do
			box("TowerCorbel", cx + o, 36, z0 - 4, cx + o + 4, 40, z0, "px_stone_bricks", STONE_DARK, f)
			box("TowerCorbel", cx + o, 36, z1, cx + o + 4, 40, z1 + 4, "px_stone_bricks", STONE_DARK, f)
			box("TowerCorbel", x0 - 4, 36, cz + o, x0, 40, cz + o + 4, "px_stone_bricks", STONE_DARK, f)
			box("TowerCorbel", x1, 36, cz + o, x1 + 4, 40, cz + o + 4, "px_stone_bricks", STONE_DARK, f)
		end
		-- the wooden top floor (8×8 blocks) with a hatch over the ladder
		local inward, hx0, hx1, hz0, hz1
		if ladder == "N" then
			inward, hx0, hx1, hz0, hz1 = Vector3.new(0, 0, 1), cx - 2, cx + 2, z0 + 4, z0 + 8
		elseif ladder == "S" then
			inward, hx0, hx1, hz0, hz1 = Vector3.new(0, 0, -1), cx - 2, cx + 2, z1 - 8, z1 - 4
		elseif ladder == "W" then
			inward, hx0, hx1, hz0, hz1 = Vector3.new(1, 0, 0), x0 + 4, x0 + 8, cz - 2, cz + 2
		else
			inward, hx0, hx1, hz0, hz1 = Vector3.new(-1, 0, 0), x1 - 8, x1 - 4, cz - 2, cz + 2
		end
		local X0, X1, Z0, Z1 = cx - 16, cx + 16, cz - 16, cz + 16
		box("TowerFloor", X0, 44, Z0, hx0, 48, Z1, WOOD, nil, f)
		box("TowerFloor", hx1, 44, Z0, X1, 48, Z1, WOOD, nil, f)
		box("TowerFloor", hx0, 44, Z0, hx1, 48, hz0, WOOD, nil, f)
		box("TowerFloor", hx0, 44, hz1, hx1, 48, Z1, WOOD, nil, f)
		-- the ladder: invisible trusses + the ladder picture on the wall (like the mine shafts)
		local wallPt = V((hx0 + hx1) / 2, 38, (hz0 + hz1) / 2) - inward * 2
		local side = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
		for _, k in ipairs({ -1, 1 }) do
			local truss = Instance.new("TrussPart")
			truss.Name = "TowerLadder"
			truss.Size = Vector3.new(2, 22, 2)
			truss.CFrame = CFrame.new(wallPt + inward + side * k + Vector3.new(0, 1, 0))
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = f
		end
		local plate = decor(part("LadderFace", Vector3.new(4 * side.X + 0.2 * math.abs(inward.X), 20, 4 * side.Z + 0.2 * math.abs(inward.Z)), CFrame.new(wallPt + inward * 0.15), nil, nil, f))
		plate.Transparency = 1
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = if inward.Z > 0 then Enum.NormalId.Back elseif inward.Z < 0 then Enum.NormalId.Front elseif inward.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
		-- the top room: corner posts, a plank parapet, a stepped pyramid roof, a flag
		for _, p in ipairs({ { X0, Z0 }, { X1 - 4, Z0 }, { X0, Z1 - 4 }, { X1 - 4, Z1 - 4 } }) do
			box("TowerPost", p[1], 48, p[2], p[1] + 4, 60, p[2] + 4, "px_dark_oak_log", nil, f)
		end
		local railT = Color3.fromRGB(225, 205, 180)
		box("TowerParapet", X0 + 4, 48, Z0, X1 - 4, 52, Z0 + 4, WOOD, railT, f)
		box("TowerParapet", X0 + 4, 48, Z1 - 4, X1 - 4, 52, Z1, WOOD, railT, f)
		box("TowerParapet", X0, 48, Z0 + 4, X0 + 4, 52, Z1 - 4, WOOD, railT, f)
		box("TowerParapet", X1 - 4, 48, Z0 + 4, X1, 52, Z1 - 4, WOOD, railT, f)
		for i, r in ipairs({ 20, 16, 12, 8, 4 }) do
			local y = 56 + i * 4
			box("TowerRoof", cx - r, y, cz - r, cx + r, y + 4, cz + r, WOOD_DARK, if i % 2 == 0 then Color3.fromRGB(215, 200, 185) else nil, f)
		end
		decor(part("FlagPole", Vector3.new(0.8, 12, 0.8), at(cx, 86, cz), METAL, Enum.Material.Metal, f))
		decor(part("TowerFlag", Vector3.new(0.3, 3, 5), at(cx, 90.4, cz + 2.9), if red then BANNER_RED else BANNER_YELLOW, Enum.Material.Fabric, f))
		lantern(V(cx, 38, cz), f, false, 44)
		lantern(V(cx, 55, cz), f, false, 60)
		-- long banners and barred windows on the outer / inner faces
		for _, face in ipairs(flags) do
			local fx, fz = cx, z0
			if face == "S" then
				fz = z1
			elseif face == "W" then
				fx, fz = x0, cz
			elseif face == "E" then
				fx, fz = x1, cz
			end
			longBanner(face, fx, 28, fz, red, f)
			for _, o in ipairs({ -6, 6 }) do
				barWindow(faceCF(face, fx, 34, fz) * CFrame.new(o, 0, 0), f)
			end
		end
		return f
	end
	tower("TowerNW", -192, -192, { { "E", -192, -180 }, { "S", -192, -180 } }, "N", { "N", "W" }, true)
	tower("TowerNE", 192, -192, { { "W", -192, -180 }, { "S", 180, 192 } }, "N", { "N", "E" }, false)
	tower("TowerSW", -192, 192, { { "E", 180, 192 }, { "N", -192, -180 } }, "S", { "S", "W" }, false)
	tower("TowerSE", 192, 192, { { "W", 180, 192 }, { "N", 180, 192 } }, "S", { "S", "E" }, true)
	tower("GateTowerW", -64, 192, { { "W", 180, 192 }, { "E", 180, 192 } }, "S", { "S", "N" }, true)
	tower("GateTowerE", -16, 192, { { "W", 180, 192 }, { "E", 180, 192 } }, "S", { "S", "N" }, false)
	tower("NorthGateTower", -64, -192, { { "W", -192, -180 }, { "E", -192, -180 } }, "N", { "N", "S" }, false)
	tower("WestGateTower", -192, -8, { { "N", -192, -180 }, { "S", -192, -180 } }, "W", { "W", "E" }, true)
	tower("PosternTower", 192, 36, { { "N", 180, 192 }, { "S", 180, 192 } }, "E", { "E", "W" }, false)
end
task.wait()

-- ================================================================ the gates: arches, the south gatehouse, guard details
do
	local gates = folder("Gates", walls)
	-- a gate arch: the lintel carries the wall-walk over the gap; stepped corners make the arch
	local function arch(side, u0, u1, yb, w0, w1, merlonW)
		local tint = stoneTint(150, 170)
		sbox(side, "GateLintel", u0, yb, w0, u1, 28, w1, "px_stone_bricks", tint, gates)
		sbox(side, "GateArch", u0, yb - 4, w0, u0 + 4, yb, w1, "px_stone_bricks", tint, gates)
		sbox(side, "GateArch", u1 - 4, yb - 4, w0, u1, yb, w1, "px_stone_bricks", tint, gates)
		for gu = u0, u1 - 4, 8 do
			sbox(side, "Merlon", gu, 28, merlonW, gu + 4, 32, merlonW + 4, "px_stone_bricks", stoneTint(146, 170), gates)
		end
	end
	arch(SIDES.S, -52, -28, 20, 180, 204, 200) -- the gatehouse: a passage 6 blocks deep between the gate towers
	arch(SIDES.N, -52, -28, 20, 180, 192, 188)
	arch(SIDES.W, 4, 28, 20, 180, 192, 188)
	arch(SIDES.E, 8, 24, 16, 180, 192, 188) -- the postern: 4 blocks wide, 4 high

	-- the raised portcullis of the south gate: dark iron bars under the lintel
	for _, x in ipairs({ -46, -42, -38, -34 }) do
		decor(part("Portcullis", Vector3.new(0.8, 7.5, 0.8), at(x, 16.25, 190), METAL, Enum.Material.Metal, gates))
	end
	for _, y in ipairs({ 14.5, 18 }) do
		decor(part("Portcullis", Vector3.new(16, 0.8, 0.8), at(-40, y, 190), METAL, Enum.Material.Metal, gates))
	end
	-- the gate leaves stand open against the passage walls
	for _, x in ipairs({ -51.5, -28.5 }) do
		textured(decor(part("GateDoor", Vector3.new(1, 16, 12), at(x, 8, 188), nil, nil, gates)), WOOD_DARK)
		for _, y in ipairs({ 3, 13 }) do
			decor(part("DoorBand", Vector3.new(1.3, 0.8, 12), at(x, y, 188), METAL, Enum.Material.Metal, gates))
		end
	end
	-- banners over the arch, portcullis chains with counterweights on the gate towers
	longBanner("S", -40, 22, 204, true, gates, 12)
	longBanner("N", -40, 22, 180, false, gates, 12)
	for _, x in ipairs({ -56, -24 }) do
		decor(part("Chain", Vector3.new(0.4, 12, 0.4), at(x, 20, 179.6), METAL, Enum.Material.Metal, gates))
		textured(decor(part("Counterweight", Vector3.new(2, 2, 2), at(x, 13, 179.2), nil, nil, gates)), "px_iron_block", Color3.fromRGB(150, 150, 155))
	end
	-- lanterns on brackets by every gate, inside and out
	wallLantern(-58, 12, 180, 0, -1, gates)
	wallLantern(-22, 12, 180, 0, -1, gates)
	wallLantern(-58, 12, 204, 0, 1, gates)
	wallLantern(-22, 12, 204, 0, 1, gates)
	wallLantern(-58, 12, -180, 0, 1, gates)
	wallLantern(-22, 12, -184, 0, 1, gates)
	wallLantern(-180, 12, -2, 1, 0, gates)
	wallLantern(-184, 12, 32, 1, 0, gates)
	wallLantern(180, 12, 30, -1, 0, gates)
	wallLantern(184, 12, 4, -1, 0, gates)
	wallLantern(192, 10, 4, 1, 0, gates)
	wallLantern(204, 10, 28, 1, 0, gates)
	-- flag bunting from the gate towers: across the south gate inside and out, down to the welcome arch, and at the
	-- north and west gates
	bunting(V(-48, 56, 178), V(-32, 56, 178), FLAGS, gates)
	bunting(V(-48, 56, 206), V(-32, 56, 206), FLAGS, gates)
	bunting(V(-50, 54, 177), V(-52, 20, 126), FLAGS, gates)
	bunting(V(-30, 54, 177), V(-28, 20, 126), FLAGS, gates)
	bunting(V(-50, 54, -178), V(-22, 32, -190), FLAGS, gates)
	bunting(V(-178, 54, 6), V(-190, 32, 34), FLAGS, gates)

	-- the guard booth inside the south gate, east of the avenue, its door to the avenue
	local guard = folder("Guard", gates)
	local bx0, bx1, bz0, bz1 = -24, -12, 164, 176
	for _, p in ipairs({ { bx0, bz0 }, { bx1 - 4, bz0 }, { bx0, bz1 - 4 }, { bx1 - 4, bz1 - 4 } }) do
		box("BoothPost", p[1], 0, p[2], p[1] + 4, 12, p[2] + 4, "px_dark_oak_log", nil, guard)
	end
	for _, zz in ipairs({ bz0, bz1 - 4 }) do
		box("BoothWall", bx0 + 4, 0, zz, bx1 - 4, 4, zz + 4, "px_stone_bricks", STONE_T, guard)
		box("BoothWall", bx0 + 4, 8, zz, bx1 - 4, 12, zz + 4, WOOD, nil, guard)
		for _, x in ipairs({ bx0 + 5.3, bx0 + 6.7 }) do
			decor(part("WindowBar", Vector3.new(0.4, 4, 0.4), at(x, 6, zz + 2), METAL, Enum.Material.Metal, guard))
		end
	end
	box("BoothWall", bx1 - 4, 0, bz0 + 4, bx1, 4, bz1 - 4, "px_stone_bricks", STONE_T, guard)
	box("BoothWall", bx1 - 4, 4, bz0 + 4, bx1, 12, bz1 - 4, WOOD, nil, guard)
	box("BoothLintel", bx0, 8, bz0 + 4, bx0 + 4, 12, bz1 - 4, WOOD, nil, guard)
	box("BoothRoof", bx0 - 4, 12, bz0 - 4, bx1 + 4, 16, bz1 + 4, WOOD_DARK, nil, guard)
	box("BoothRoof", bx0, 16, bz0, bx1, 20, bz1, WOOD_DARK, Color3.fromRGB(215, 200, 185), guard)
	local board = textured(part("BoothSign", Vector3.new(8, 2, 0.4), at(bx0 - 0.25, 10, 170) * CFrame.Angles(0, math.pi / 2, 0), nil, nil, guard), WOOD_LIGHT)
	boardText(board, "Пост охраны")
	lantern(V(bx0 - 2.5, 8.5, bz0 + 1), guard, false, 12)
	-- weapon racks: swords and spears
	local function rack(x0, z)
		for _, x in ipairs({ x0, x0 + 12 }) do
			textured(part("RackPost", Vector3.new(1, 6, 1), at(x, 3, z), nil, nil, guard), WOOD_DARK)
		end
		for _, y in ipairs({ 1.5, 5 }) do
			textured(part("RackBar", Vector3.new(12, 0.6, 0.8), at(x0 + 6, y, z), nil, nil, guard), WOOD_DARK)
		end
		for i = 1, 4 do
			local x = x0 + i * 2.4
			if i % 2 == 1 then
				decor(part("SwordBlade", Vector3.new(0.5, 3.6, 0.25), at(x, 2.9, z - 0.6), Color3.fromRGB(200, 200, 206), Enum.Material.Metal, guard))
				decor(part("SwordGuard", Vector3.new(1.6, 0.4, 0.4), at(x, 4.9, z - 0.6), METAL, Enum.Material.Metal, guard))
				decor(part("SwordGrip", Vector3.new(0.4, 1.2, 0.4), at(x, 5.7, z - 0.6), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, guard))
			else
				decor(part("Spear", Vector3.new(0.4, 7, 0.4), at(x, 3.5, z - 0.6), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, guard))
				decor(part("SpearTip", Vector3.new(0.7, 1.2, 0.3), at(x, 7.6, z - 0.6), Color3.fromRGB(200, 200, 206), Enum.Material.Metal, guard))
			end
		end
	end
	rack(-72, 178.5)
	rack(-24, 178.5)
	barrel(-8, 0, 166, guard, "px_coal_block")
	barrel(-8, 0, 161, guard)
	crate(-72, 0, 170, guard)
	crate(-67.5, 0, 170, guard)
	crate(-70, B, 170, guard, B, 0.3)
	barrel(-74, 0, 164, guard, "px_hay")
end
task.wait()

-- ================================================================ the dock off the south gate
do
	local dock = folder("Dock", walls)
	local Y = 0.2 -- the deck top (a hair over the ground so the two never z-fight where the pier starts on land)
	local plankT = { Color3.fromRGB(205, 175, 135), Color3.fromRGB(184, 152, 114), Color3.fromRGB(220, 190, 146) }
	-- crosswise planks: the pier x -56..-24 (8 blocks), the head x -80..0 at the far end
	for z = 204, 252, 4 do
		box("DockPlank", -56, Y - 4, z, -24, Y, z + 4, "px_spruce_planks", plankT[rng:NextInteger(1, 3)], dock)
	end
	for z = 256, 280, 4 do
		box("DockPlank", -80, Y - 4, z, 0, Y, z + 4, "px_spruce_planks", plankT[rng:NextInteger(1, 3)], dock)
	end
	-- beams under the deck and thick posts going down into the void, cross-braced
	for _, x in ipairs({ -56, -42, -28 }) do
		box("DockBeam", x, Y - 8, 208, x + 4, Y - 4, 284, "px_dark_oak_log", nil, dock)
	end
	box("DockBeam", -80, Y - 9, 256, 0, Y - 4, 260, "px_dark_oak_log", nil, dock)
	box("DockBeam", -80, Y - 9, 280, 0, Y - 4, 284, "px_dark_oak_log", nil, dock)
	box("DockBeam", -80, Y - 9, 260, -76, Y - 4, 280, "px_dark_oak_log", nil, dock)
	box("DockBeam", -4, Y - 9, 260, 0, Y - 4, 280, "px_dark_oak_log", nil, dock)
	for _, p in ipairs({ { -56, 216 }, { -28, 216 }, { -56, 236 }, { -28, 236 }, { -80, 256 }, { -4, 256 }, { -80, 280 }, { -4, 280 }, { -42, 280 } }) do
		box("DockPost", p[1], -36 - rng:NextInteger(0, 3) * 4, p[2], p[1] + 4, Y - 8, p[2] + 4, "px_dark_oak_log", nil, dock)
	end
	for _, z in ipairs({ 218, 238 }) do
		textured(beam("DockBrace", V(-54, -30, z), V(-26, -10, z), 1.6, nil, dock), WOOD_DARK)
		textured(beam("DockBrace", V(-26, -30, z), V(-54, -10, z), 1.6, nil, dock), WOOD_DARK)
	end
	for _, x in ipairs({ -78, -2 }) do
		textured(beam("DockBrace", V(x, -30, 258), V(x, -10, 282), 1.6, nil, dock), WOOD_DARK)
	end
	-- railings (an opening on the east side for the airship's gangplank)
	fence(-55.5, 206, -55.5, 256, dock, Y)
	fence(-24.5, 206, -24.5, 228, dock, Y)
	fence(-24.5, 240, -24.5, 256, dock, Y)
	fence(-79.5, 256.5, -55.5, 256.5, dock, Y)
	fence(-24.5, 256.5, -0.5, 256.5, dock, Y)
	fence(-79.5, 256.5, -79.5, 283.5, dock, Y)
	fence(-0.5, 256.5, -0.5, 283.5, dock, Y)
	fence(-79.5, 283.5, -0.5, 283.5, dock, Y)
	-- lamp posts, arms over the deck
	lampPost(-52, 220, dock, false, -math.pi / 2, Y)
	lampPost(-28, 220, dock, false, math.pi / 2, Y)
	lampPost(-52, 248, dock, false, -math.pi / 2, Y)
	lampPost(-28, 248, dock, false, math.pi / 2, Y)
	lampPost(-60, 280, dock, false, 0, Y)
	lampPost(-24, 280, dock, false, 0, Y)
	-- cargo along the railings (the middle stays free)
	barrel(-52, Y, 209, dock, "px_hay")
	barrel(-52, Y, 236, dock)
	crate(-28, Y, 210, dock)
	crate(-28, Y, 214.5, dock, B, 0.25)
	crate(-28, Y, 252, dock)
	barrel(-76, Y, 260, dock)
	barrel(-71.5, Y, 260, dock, "px_coal_block")
	textured(cube("RopeCoil", -64, Y + 1, 281, B, 2, B, nil, nil, dock), "px_brown_wool", ROPE)

	-- the crane on the head: a mast, a jib out over the void, a rope with a hanging crate, a winch
	do
		local cx, cz = -72, 272
		box("CraneBase", cx - 4, Y, cz - 4, cx + 4, Y + 4, cz + 4, "px_stone_bricks", STONE_T, dock)
		box("CraneMast", cx - 2, Y + 4, cz - 2, cx + 2, 32, cz + 2, "px_dark_oak_log", nil, dock)
		box("CraneJib", cx - 30, 28, cz - 2, cx + 6, 32, cz + 2, "px_dark_oak_log", nil, dock)
		box("CraneWeight", cx + 2, 22, cz - 2, cx + 6, 28, cz + 2, "px_cobblestone", STONE_DARK, dock)
		textured(beam("CraneBrace", V(cx - 2, 16, cz), V(cx - 16, 28, cz), 1.6, nil, dock), WOOD_DARK)
		decor(part("Pulley", Vector3.new(1.6, 1.6, 1.6), at(cx - 28, 27.2, cz), METAL, Enum.Material.Metal, dock))
		decor(beam("CraneRope", V(cx - 28, 26.4, cz), V(cx - 28, 8, cz), 0.35, ROPE, dock, Enum.Material.Fabric))
		decor(part("Hook", Vector3.new(1, 1.2, 1), at(cx - 28, 7.4, cz), METAL, Enum.Material.Metal, dock))
		decor(crate(cx - 28, 2.6, cz, dock, B, 0.2))
		box("Winch", cx + 4, Y, cz + 2, cx + 8, Y + 4, cz + 6, "px_oak_log", nil, dock)
		decor(part("WinchCrank", Vector3.new(0.5, 0.5, 2.4), at(cx + 6, Y + 2, cz + 7), METAL, Enum.Material.Metal, dock))
		decor(beam("CraneRope", V(cx + 6, Y + 3.6, cz + 4), V(cx + 2, 30, cz), 0.35, ROPE, dock, Enum.Material.Fabric))
	end

	-- the dockmaster's stall on the head, facing the pier (west)
	stall(at(-12, Y, 270) * CFrame.Angles(0, math.pi / 2, 0), { w = 3 * B, d = 2 * B, colA = WOOL_YELLOW, colB = WOOL_WHITE, goods = { "px_brown_wool", "px_hay", "px_oak_log" }, sign = "Пристань" }, dock)
	crate(-4, Y, 262, dock)
	crate(-4, Y, 266.5, dock)
	crate(-4, Y + B, 264, dock, B, 0.4)
	barrel(-4, Y, 274, dock, "px_hay")
	barrel(-4, Y, 278.5, dock)

	-- the moored airship: a block gondola on the east side of the pier under a red-and-white wool balloon
	do
		local ship = folder("Airship", dock)
		local HULL = "px_dark_oak_planks"
		box("Keel", -12, -12, 226, -8, -8, 246, HULL, nil, ship)
		box("Hull", -16, -8, 224, -4, -4, 248, "px_white_wool", WOOL_RED, ship)
		box("HullDeck", -20, -4, 222, 0, 0, 250, HULL, nil, ship)
		box("HullSide", -20, 0, 222, -16, 4, 230, WOOD, nil, ship) -- the boarding gap z 230..238
		box("HullSide", -20, 0, 238, -16, 4, 250, WOOD, nil, ship)
		box("HullSide", -4, 0, 222, 0, 4, 250, WOOD, nil, ship)
		box("HullSide", -16, 0, 222, -4, 4, 226, WOOD, nil, ship)
		box("HullSide", -16, 0, 246, -4, 4, 250, WOOD, nil, ship)
		box("Prow", -14, -4, 218, -6, 4, 222, HULL, nil, ship)
		box("Prow", -12, 4, 218, -8, 8, 222, HULL, nil, ship)
		box("Rudder", -11, -10, 250, -9, 6, 254, HULL, nil, ship)
		box("Gangplank", -24, Y - 1, 230, -20, Y, 238, WOOD, nil, ship)
		-- the balloon: layers of wool blocks, wider in the middle, stripes of red
		for _, l in ipairs({
			{ 20, 24, 6, 10, WOOL_WHITE },
			{ 24, 28, 10, 16, WOOL_RED },
			{ 28, 36, 12, 20, WOOL_WHITE },
			{ 36, 40, 10, 16, WOOL_RED },
			{ 40, 44, 6, 12, WOOL_WHITE },
		}) do
			box("Balloon", -10 - l[3], l[1], 236 - l[4], -10 + l[3], l[2], 236 + l[4], "px_white_wool", l[5], ship)
		end
		box("Balloon", -18, 28, 212, -2, 36, 216, "px_white_wool", WOOL_RED, ship)
		box("Balloon", -18, 28, 256, -2, 36, 260, "px_white_wool", WOOL_RED, ship)
		box("BalloonSpar", -11, 18, 226, -9, 20, 246, WOOD_DARK, nil, ship)
		for _, c in ipairs({ { -19, 223, -15, 228 }, { -1, 223, -5, 228 }, { -19, 249, -15, 244 }, { -1, 249, -5, 244 } }) do
			decor(beam("Rigging", V(c[1], 4, c[2]), V(c[3], 20, c[4]), 0.35, ROPE, ship, Enum.Material.Fabric))
		end
		-- a propeller at the stern, a lantern under the balloon, a pennant on the prow
		local hub = at(-10, 2, 254.8)
		decor(part("PropHub", Vector3.new(1.6, 1.6, 1.6), hub, METAL, Enum.Material.Metal, ship))
		for _, a in ipairs({ math.pi / 4, -math.pi / 4 }) do
			textured(decor(part("PropBlade", Vector3.new(1.4, 8, 0.6), hub * CFrame.new(0, 0, 0.5) * CFrame.Angles(0, 0, a), nil, nil, ship)), WOOD)
		end
		lantern(V(-10, 12, 236), ship, false, 18)
		decor(part("PennantPole", Vector3.new(0.5, 6, 0.5), at(-10, 11, 220), METAL, Enum.Material.Metal, ship))
		decor(part("Pennant", Vector3.new(0.2, 2.4, 4), at(-10, 12.8, 222.2), BANNER_YELLOW, Enum.Material.Fabric, ship))
		-- mooring: bollards on the pier, ropes to the hull
		for _, z in ipairs({ 224, 242 }) do
			box("Bollard", -28, Y, z, -26, Y + 3, z + 2, "px_dark_oak_log", nil, dock)
			decor(beam("MooringRope", V(-27, Y + 2.6, z + 1), V(-20, 3.5, z + 1), 0.35, ROPE, ship, Enum.Material.Fabric))
		end
	end
end
task.wait()

-- ================================================================ the east postern → the cliff path → the crypt cave
do
	local cp = folder("CliffPath", walls)
	-- the profile going north: { z north end, z south end, top at the north end, top at the south end }
	local SEG = {
		{ 4, 28, 0.2, 0.2 }, -- the landing outside the postern
		{ -24, 4, -12, 0.2 },
		{ -36, -24, -12, -12 },
		{ -64, -36, -28, -12 },
		{ -72, -64, -28, -28 },
		{ -98, -72, -48, -28 },
		{ -126, -98, -48, -48 }, -- the landing in front of the cave
	}
	local function topAt(z)
		for _, s in ipairs(SEG) do
			if z >= s[1] and z <= s[2] then
				return s[3] + (s[4] - s[3]) * (z - s[1]) / (s[2] - s[1])
			end
		end
		return if z > 28 then 0.2 else -48
	end
	local DECK, deckT = "px_stone_bricks", Color3.fromRGB(160, 156, 150)
	-- the walking deck: landings and kit stairs, 4 blocks wide (x 216..232)
	box("PathLanding", 192, -3.8, 4, 232, 0.2, 28, DECK, deckT, cp)
	stairs("PathStairs", 224, 4, -24, 0.2, -12.2, 16, DECK, cp)
	box("PathLanding", 216, -16, -36, 232, -12, -24, DECK, deckT, cp)
	stairs("PathStairs", 224, -36, -64, -12, -16, 16, DECK, cp)
	box("PathLanding", 216, -32, -72, 232, -28, -64, DECK, deckT, cp)
	stairs("PathStairs", 224, -72, -98, -28, -20, 16, DECK, cp)
	box("PathLanding", 208, -52, -126, 232, -48, -98, DECK, deckT, cp)
	box("PathRock", 208, -64, -126, 232, -52, -96, "px_stone", STONE_T, cp)
	box("PathRock", 212, -76, -122, 228, -64, -100, "px_stone", STONE_T, cp)
	box("PathRock", 216, -88, -118, 224, -76, -106, "px_cobblestone", STONE_DARK, cp)
	-- the support, one 1-block slice at a time: a masonry wall against the cliff (x 208..220) running into hanging
	-- rock, stepped corbels under the outer edge, a 1-block parapet on the cliff side
	for z = -96, 24, 4 do
		local yl = topAt(z)
		local r = rng:NextNumber()
		local var = if r < 0.6 then "px_stone_bricks" elseif r < 0.85 then "px_cobblestone" else "px_mossy_stone_bricks"
		local tint = stoneTint(135, 160)
		box("PathWall", 208, yl - 16, z, 220, yl - 0.5, z + 4, var, tint, cp)
		box("PathRock", 208, yl - 16 - rng:NextInteger(1, 5) * 4, z, 220, yl - 16, z + 4, "px_stone", STONE_T, cp)
		box("PathCorbel", 220, yl - 8, z, 232, yl - 3.5, z + 4, "px_stone_bricks", STONE_DARK, cp)
		box("PathCorbel", 220, yl - 12, z, 228, yl - 8, z + 4, "px_stone_bricks", STONE_DARK, cp)
		if z < 4 then
			box("PathParapet", 212, yl - 0.5, z, 216, topAt(z + 4) + 4, z + 4, var, tint, cp)
		end
	end
	for _, z in ipairs({ -12, -32, -56, -68, -88 }) do
		lantern(V(214, topAt(z + 4) + 4.75, z + 2), cp)
	end
	-- the low railing on the void side: posts every 2 blocks, rails following the slope
	local prevTop, prevZ = nil, nil
	for z = 28, -124, -8 do
		local t = topAt(z)
		box("PathRailPost", 230.5, t - 2, z - 0.5, 231.5, t + 3.4, z + 0.5, WOOD_DARK, nil, cp)
		if prevZ then
			for _, h in ipairs({ 1.4, 3 }) do
				textured(beam("PathRail", V(231, prevTop + h, prevZ), V(231, t + h, z), 0.5, nil, cp), WOOD_DARK)
			end
		end
		prevTop, prevZ = t, z
	end
	fence(204, 27.5, 231, 27.5, cp, 0.2)
	fence(208, -125.5, 231, -125.5, cp, -48)
	zoneSign(198, 20, "К пещере", math.pi / 2, cp)
	-- a block against the cliff north of the cave mouth (no gap where the ragged edge is further in)
	box("PathWall", 204, -52, -126, 208, -36, -122, "px_cobblestone", STONE_DARK, cp)

	-- the cave mouth: a rough stone arch around the opening (z -118..-102, y -48..-28), facing east
	local mouth = folder("CaveMouth", cp)
	local M = CAVE_MOUTH
	local zA, zB = M.z - M.w / 2, M.z + M.w / 2
	local yTop = M.y + M.h
	local ROUGH = { "px_cobblestone", "px_mossy_cobblestone", "px_stone", "px_cobblestone" }
	for _, pz in ipairs({ { zA - 8, zA, 220 }, { zB, zB + 8, 216 } }) do
		for _, yy in ipairs({ M.y - 4, M.y + 4, M.y + 12 }) do
			local xr = if pz[3] > 216 and rng:NextNumber() < 0.5 then 220 else 216
			box("MouthPillar", M.x, yy, pz[1], xr, yy + 8, pz[2], ROUGH[rng:NextInteger(1, #ROUGH)], stoneTint(120, 150), mouth)
		end
	end
	box("MouthLintel", M.x, yTop, zA - 8, M.x + 10, yTop + 8, M.z, ROUGH[rng:NextInteger(1, #ROUGH)], stoneTint(120, 150), mouth)
	box("MouthLintel", M.x, yTop, M.z, M.x + 10, yTop + 8, zB + 8, ROUGH[rng:NextInteger(1, #ROUGH)], stoneTint(120, 150), mouth)
	box("MouthArch", M.x, yTop - 4, zA, M.x + 8, yTop, zA + 4, "px_cobblestone", stoneTint(120, 150), mouth)
	box("MouthArch", M.x, yTop - 4, zB - 4, M.x + 8, yTop, zB, "px_cobblestone", stoneTint(120, 150), mouth)
	box("MouthKeystone", M.x, yTop + 4, M.z - 4, M.x + 12, yTop + 12, M.z + 4, "px_mossy_stone_bricks", Color3.fromRGB(140, 145, 135), mouth)
	box("Rubble", 216, M.y, -126, 220, M.y + 4, -122, "px_mossy_cobblestone", nil, mouth)
	-- cobwebs (Minecraft cross sprites) in the upper corners, out of reach
	local WEB_TEX = TEXCFG.sprites and TEXCFG.sprites.cobweb
	for _, w in ipairs({ { M.x + 2, yTop - 6, zA + 2 }, { M.x + 2, yTop - 6, zB - 2 }, { M.x + 8, yTop - 2, M.z } }) do
		local cell = part("Cobweb", Vector3.new(B, B, B), at(w[1], w[2], w[3]), nil, nil, mouth)
		cell.Transparency = 1
		decor(cell).CastShadow = false
		for _, yaw in ipairs({ math.pi / 4, -math.pi / 4 }) do
			local plane = decor(part("CobwebSprite", Vector3.new(B * math.sqrt(2), B, 0.05), cell.CFrame * CFrame.Angles(0, yaw, 0), nil, nil, cell))
			plane.Transparency = 1
			plane.CastShadow = false
			if WEB_TEX then
				for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
					local decal = Instance.new("Decal")
					decal.Texture = WEB_TEX
					decal.Face = face
					decal.Parent = plane
				end
			end
		end
	end
	-- soul lanterns: one hanging in the arch, one on a stone post by the railing
	lantern(V(M.x + 4, yTop - 6, M.z), mouth, true, yTop)
	box("LanternPost", 226, M.y, -124, 230, M.y + 4, -120, "px_cobblestone", STONE_DARK, mouth)
	lantern(V(228, M.y + 4.75, -122), mouth, true)
	-- bones and skulls along the edges of the landing
	for _, b in ipairs({ { 222, -124.5, 0.4 }, { 224, -118.5, 1.9 }, { 229.5, -104, 0.9 }, { 226.5, -117, 2.6 } }) do
		decor(part("Bone", Vector3.new(0.8, 0.8, 3.2), at(b[1], M.y + 0.4, b[2]) * CFrame.Angles(0, b[3], 0), BONE, Enum.Material.SmoothPlastic, mouth))
	end
	for _, s in ipairs({ { 221, -120.5 }, { 228.5, -106 } }) do
		local skull = decor(part("Skull", Vector3.new(2, 2, 2), at(s[1], M.y + 1, s[2]) * CFrame.Angles(0, -0.3, 0), BONE, Enum.Material.SmoothPlastic, mouth))
		for _, ez in ipairs({ -0.45, 0.45 }) do
			decor(part("SkullEye", Vector3.new(0.12, 0.5, 0.5), skull.CFrame * CFrame.new(-1.02, 0.2, ez), Color3.fromRGB(25, 22, 20), Enum.Material.SmoothPlastic, mouth))
		end
	end
	-- a warning board by the cave
	box("SignPost", 229.5, M.y, -112.5, 230.5, M.y + 5, -111.5, WOOD_DARK, nil, mouth)
	local board = textured(part("SignBoard", Vector3.new(7, 2, 0.4), at(229.7, M.y + 4.4, -112) * CFrame.Angles(0, math.pi / 2, 0), nil, nil, mouth), WOOD)
	boardText(board, "Склеп Короля нежити", Color3.fromRGB(150, 235, 240))
end
task.wait()

-- ================================================================ outside the wall: trees, bushes, rocks, a broken cart
do
	local out = folder("Outside", walls)
	for _, t in ipairs({ { -140, 198, 12 }, { 76, 198, 11 }, { 140, 199, 13 }, { 198, 124, 12 }, { 198, -60, 11 }, { -198, -104, 12 }, { -198, 124, 11 }, { 104, -198, 12 }, { -150, -198, 11 } }) do
		tree(t[1], t[2], t[3], out)
	end
	local HEDGE_T = Color3.fromRGB(150, 200, 120)
	for _, b in ipairs({ { "S", -120, 8 }, { "S", -100, 4 }, { "S", 30, 8 }, { "S", 110, 4 }, { "N", -120, 8 }, { "N", 20, 4 }, { "N", 130, 8 }, { "W", -140, 8 }, { "W", 70, 4 }, { "E", 130, 8 }, { "E", -160, 4 } }) do
		local side = SIDES[b[1]]
		sbox(side, "Bush", b[2], 0, 196, b[2] + b[3], 4, 200, "px_hedge", HEDGE_T, out)
		if b[3] > 4 then
			sbox(side, "Bush", b[2] + 4, 4, 196, b[2] + 8, 8, 200, "px_hedge", HEDGE_T, out)
		end
	end
	for _, r in ipairs({ { "N", 60 }, { "W", 150 }, { "E", 150 }, { "S", 160 }, { "N", 160 }, { "W", -60 } }) do
		local side = SIDES[r[1]]
		sbox(side, "Rock", r[2], 0, 196, r[2] + 8, 4, 200, "px_stone", STONE_T, out)
		sbox(side, "Rock", r[2] + 4, 4, 196, r[2] + 8, 8, 200, if rng:NextNumber() < 0.5 then "px_mossy_cobblestone" else "px_cobblestone", nil, out)
	end
	-- the broken cart outside the west gate: tipped onto its broken side, a wheel off, the load spilled
	local cf = at(-198, 2.4, 46) * CFrame.Angles(0.1, 0.35, 0.28)
	textured(part("CartBed", Vector3.new(8, 3, 12), cf, nil, nil, out), WOOD)
	textured(part("CartSide", Vector3.new(1, 2, 12), cf * CFrame.new(-3.5, 2.5, 0), nil, nil, out), WOOD_DARK)
	textured(part("CartWheel", Vector3.new(1, 4, 4), cf * CFrame.new(4.5, -0.8, 0), nil, nil, out), WOOD_DARK)
	textured(part("CartWheel", Vector3.new(4, 1, 4), at(-196, 0.5, 57) * CFrame.Angles(0, 0.5, 0), nil, nil, out), WOOD_DARK)
	for _, dx in ipairs({ -2.5, 2.5 }) do
		textured(beam("CartShaft", (cf * CFrame.new(dx, 0, -6)).Position, (cf * CFrame.new(dx, 0, -6)).Position + Vector3.new(1.5, -2, -8), 1, nil, out), WOOD_DARK)
	end
	textured(part("Hay", Vector3.new(B, B, B), at(-199, 2, 34) * CFrame.Angles(0, 0.4, 0), nil, nil, out), "px_hay")
	crate(-194.5, 0, 38, out, B, 0.7)
	barrel(-22, 0, -198, out)
end

print(("[build-market] walls: %d parts"):format(count - partsBefore))
