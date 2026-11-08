--!nocheck
-- Каменоломня, level 3 [wiki]. Owner-approved OPEN-AIR concept 03.11.2026:
-- assets/concepts/quarry/accepted-open-air-2026-11-03.png. Exact original mine 40x16x40.
-- Wide mining court, western winding-wheel depot, northern terraced working faces,
-- eastern shared Basalt Guardian arena, buyer at arrival. New footprint/heights [decision].
-- Build in Studio Edit after build-textures. Atomic replacement, inert original backup.
-- Geometry at X=700 is lifted to its own open-sky altitude at the end; teleport tags follow it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before rebuilding Quarry")
local old = workspace:FindFirstChild("Quarry")
local originalBuyer = old and old:FindFirstChild("QuarryBuyer", true)
local buyer = originalBuyer and originalBuyer:Clone()
assert(not workspace:FindFirstChild("QuarryRebuild"), "Inspect unfinished QuarryRebuild first")
local root = Instance.new("Folder")
root.Name = "QuarryRebuild"
root:SetAttribute("DesignVersion", "2026-11-03-open-air-accepted")
root.Parent = workspace

local QX, QZ = 700, 0 -- zone centre
local B = 4 -- block size
local STONE = Color3.fromRGB(110, 110, 114)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local IRON = Color3.fromRGB(70, 70, 75)
local LEAVES = Color3.fromRGB(70, 120, 50)
local LAMP = Color3.fromRGB(255, 205, 120)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or STONE
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end
local function textured(p, variant)
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = Color3.new(1, 1, 1)
	return p
end
local function at(x, y, z)
	return CFrame.new(QX + x, y, QZ + z)
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 190, 60)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end
local function spot(id, x, z, faceX, faceZ)
	local p = part(
		"LocationSpawn_quarry_" .. id,
		Vector3.new(4, 1, 4),
		CFrame.lookAt(Vector3.new(QX + x, 0.5, QZ + z), Vector3.new(QX + faceX, 0.5, QZ + faceZ)),
		STONE
	)
	textured(p, "px_cobblestone")
	p.Transparency = 0
	p.CanCollide = true
	p:SetAttribute("LocationId", "quarry")
	if id ~= "spawn" then
		p:SetAttribute("Spot", id)
	end
	CollectionService:AddTag(p, "LocationSpawn")
	return p
end

local ok, result = xpcall(function()
	-- ---------------------------------------------------------------- the pit (mine 40 × 16 × 40)
	local MX, MZ = 0, -20 -- pit centre
	local SX, SY, SZ = 40, 16, 40
	local w, h, d = SX * B, SY * B, SZ * B
	local hole = {
		x0 = MX - w / 2 - 2 * B,
		x1 = MX + w / 2 + 2 * B,
		z0 = MZ - d / 2 - 2 * B,
		z1 = MZ + d / 2 + 2 * B,
	}

	-- ground: four grass slabs around the pit hole, 4 studs thick, top at y = 0
	local HALF = 156
	local function slab(name, x0, x1, z0, z1)
		if x1 - x0 < 0.5 or z1 - z0 < 0.5 then
			return
		end
		local p = part(
			name,
			Vector3.new(x1 - x0, 4, z1 - z0),
			at((x0 + x1) / 2, -2, (z0 + z1) / 2),
			LEAVES
		)
		textured(p, "px_stone")
	end
	slab("Ground", -HALF, HALF, -HALF, hole.z0)
	slab("Ground", -HALF, HALF, hole.z1, HALF)
	slab("Ground", -HALF, hole.x0, hole.z0, hole.z1)
	slab("Ground", hole.x1, HALF, hole.z0, hole.z1)

	-- [владелец 22.10: «границы шахты из камня, а копаем камень — границы не видно»] the pit walls, floor and
	-- rim are dark like Minecraft's bedrock (cobblestone texture tinted almost black), so the edge of the
	-- mine never looks like one more block to dig
	local BEDROCK = Color3.fromRGB(62, 58, 66)
	local function bedrock(p)
		textured(p, "px_cobblestone")
		p.Color = BEDROCK
		return p
	end
	bedrock(part("PitFloor", Vector3.new(w + 4 * B, B, d + 4 * B), at(MX, -h - B / 2, MZ), DARK))
	for _, wall in ipairs({
		{ "PitWallN", Vector3.new(w + 4 * B, h, 2 * B), at(MX, -h / 2, MZ - d / 2 - B) },
		{ "PitWallS", Vector3.new(w + 4 * B, h, 2 * B), at(MX, -h / 2, MZ + d / 2 + B) },
		{ "PitWallW", Vector3.new(2 * B, h, d), at(MX - w / 2 - B, -h / 2, MZ) },
		{ "PitWallE", Vector3.new(2 * B, h, d), at(MX + w / 2 + B, -h / 2, MZ) },
	}) do
		bedrock(part(wall[1], wall[2], wall[3], STONE))
	end
	-- cobblestone rim around the opening; a gate in the south rail towards the plaza
	local rimY = 1
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(MX, rimY - 0.5, MZ - d / 2 - B) },
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(MX, rimY - 0.5, MZ + d / 2 + B) },
		{ Vector3.new(2 * B, 1, d), at(MX - w / 2 - B, rimY - 0.5, MZ) },
		{ Vector3.new(2 * B, 1, d), at(MX + w / 2 + B, rimY - 0.5, MZ) },
	}) do
		bedrock(part("PitRim", r[1], r[2], STONE))
	end
	local function rail(size, cf)
		textured(part("PitRail", size, cf, WOOD), "px_planks")
	end
	local railLen = (w + 4 * B) / 2 - 8
	for _, half in ipairs({ -1, 1 }) do
		rail(
			Vector3.new(railLen, 3, 0.6),
			at(MX + half * (8 + railLen / 2), 1.5, MZ + d / 2 + 2 * B)
		)
	end
	rail(Vector3.new(w + 4 * B, 3, 0.6), at(MX, 1.5, MZ - d / 2 - 2 * B))
	rail(Vector3.new(0.6, 3, d + 4 * B), at(MX - w / 2 - 2 * B, 1.5, MZ))
	rail(Vector3.new(0.6, 3, d + 4 * B), at(MX + w / 2 + 2 * B, 1.5, MZ))

	local anchor = part("MineAnchor_quarry", Vector3.new(w, 0.2, d), at(MX, -0.1, MZ), DARK)
	anchor:SetAttribute("LocationId", "quarry")
	anchor:SetAttribute("MineId", "quarry")
	anchor:SetAttribute("Size", Vector3.new(SX, SY, SZ))
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")

	-- four ladders like the prison mines (eight invisible 2×2 trusses + a textured plate each)
	local LADDER_W = 4 * B
	local ladderTexture = textures and textures.textures and textures.textures.ladder
	for _, side in ipairs({
		{ MX, MZ - d / 2, Vector3.new(0, 0, 1) },
		{ MX, MZ + d / 2, Vector3.new(0, 0, -1) },
		{ MX - w / 2, MZ, Vector3.new(1, 0, 0) },
		{ MX + w / 2, MZ, Vector3.new(-1, 0, 0) },
	}) do
		local inward = side[3]
		local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
		local base = Vector3.new(QX + side[1], -h / 2, QZ + side[2])
		for k = 0, LADDER_W / 2 - 1 do
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = Vector3.new(2, h, 2)
			truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-LADDER_W / 2 + 1 + k * 2))
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = root
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(
			LADDER_W * along.X + 0.2 * math.abs(inward.X),
			h,
			LADDER_W * along.Z + 0.2 * math.abs(inward.Z)
		)
		plate.CFrame = CFrame.new(base + inward * 0.15)
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.Transparency = 1
		plate.Parent = root
		if ladderTexture then
			local tex = Instance.new("Texture")
			tex.Texture = ladderTexture
			tex.Face = if inward.Z > 0
				then Enum.NormalId.Back
				elseif inward.Z < 0 then Enum.NormalId.Front
				elseif inward.X > 0 then Enum.NormalId.Right
				else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end

	-- Accepted owner concept 03.11: assets/concepts/quarry/accepted-open-air-2026-11-03.png.
	-- Spacious OPEN-AIR quarry. Existing excavation stays exactly 40x16x40 blocks.
	local terrain, props, arena =
		Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	terrain.Name, props.Name, arena.Name = "Terraces", "Props", "BossArena"
	terrain.Parent, props.Parent, arena.Parent = root, root, root
	local ROCK = Color3.fromRGB(228, 226, 219)
	local TIMBER = Color3.fromRGB(241, 225, 196)
	local BASALT = Color3.fromRGB(184, 190, 197)
	local MOSS = Color3.fromRGB(119, 148, 87)
	local count = 0
	local function block(name, x, y, z, w, h, d, variant, tint, parent, collide)
		local p = part(name, Vector3.new(w, h, d), at(x, y, z), tint or STONE, nil, parent or props)
		if variant then
			textured(p, variant)
		end
		p.Color = tint or ROCK
		p.CanTouch, p.CanCollide = false, collide ~= false
		if collide == false then
			p.CanQuery = false
		end
		count += 1
		if count % 100 == 0 then
			task.wait()
		end
		return p
	end
	local function beam(name, a, b, width, variant, color)
		local p = block(name, 0, 0, 0, width, width, (b - a).Magnitude, variant, color)
		p.CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(QX, 0, QZ), b + Vector3.new(QX, 0, QZ))
		return p
	end
	local function lantern(x, y, z, lit)
		block("LampCap", x, y + 1.6, z, 3, 0.6, 3, nil, IRON)
		block("LampBase", x, y - 1.6, z, 3, 0.6, 3, nil, IRON)
		local bulb = block("LampGlass", x, y, z, 2, 2.6, 2, nil, LAMP, props, false)
		for _, dx in { -1.2, 1.2 } do
			for _, dz in { -1.2, 1.2 } do
				block("LampFrame", x + dx, y, z + dz, 0.3, 3, 0.3, nil, IRON, props, false)
			end
		end
		if lit then
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = 46, 0.65, LAMP, false
			light.Parent = bulb
		end
	end
	local function crate(x, y, z, scale)
		local s = scale or 8
		block("Crate", x, y + s / 2, z, s, s, s, "px_planks", TIMBER)
		for _, dx in { -s / 2 - 0.15, s / 2 + 0.15 } do
			block("CrateBand", x + dx, y + s / 2, z, 0.6, s + 0.2, s + 0.2, "px_oak_log", TIMBER)
		end
		for _, dy in { 1, s - 1 } do
			block("CrateRail", x, y + dy, z, s - 0.4, 1.2, s + 0.3, "px_oak_log", TIMBER)
		end
	end
	local function barrel(x, y, z)
		block("Barrel", x, y + 4, z, 6, 8, 6, "px_planks", TIMBER)
		for _, dy in { 1.5, 6.5 } do
			block("BarrelHoop", x, y + dy, z, 6.3, 1, 6.3, nil, IRON)
		end
		block("BarrelLid", x, y + 8.1, z, 5.5, 0.2, 5.5, "px_oak_log", TIMBER)
	end

	local function fence(x0, z0, x1, z1, y, low)
		local a, b = Vector3.new(x0, y, z0), Vector3.new(x1, y, z1)
		local n = math.max(1, math.ceil((b - a).Magnitude / 12))
		for i = 0, n do
			local v = a:Lerp(b, i / n)
			block(
				"FencePost",
				v.X,
				y + (if low then 1.5 else 2.5),
				v.Z,
				1.5,
				(if low then 3 else 5),
				1.5,
				"px_oak_log",
				TIMBER
			)
		end
		for _, h in (if low then { 0.8, 2.3 } else { 1.5, 3.5 }) do
			beam("FenceRail", a + Vector3.yAxis * h, b + Vector3.yAxis * h, 1, "px_oak_log", TIMBER)
		end
	end
	local function footprint(x, z)
		local n = math.noise(x / 48, z / 48, 9) * 0.035
		return (x / 240) ^ 2 + ((z + 16) / 248) ^ 2 < 1 + n
			or ((x - 216) / 96) ^ 2 + ((z + 24) / 116) ^ 2 < 1 + n
			or (x / 176) ^ 2 + ((z - 136) / 88) ^ 2 < 1 + n
	end
	local function groundY(x, z)
		local h = 0
		-- Broad usable terrace shelves; curved risers follow the quarry face.
		local north = z + math.floor(math.sin(x / 44) * 2) * 4
		if north < -128 then
			h = 8
		end
		if north < -160 then
			h = 20
		end
		if north < -192 then
			h = 32
		end
		if north < -224 then
			h = 44
		end
		if x < -208 and (x < -224 or z < -108 or z > 44) then
			h = math.max(h, 8)
		end
		if x > 280 then
			h = math.max(h, 16)
		end
		-- Switchback stair routes are carved into the heightfield, no buried/blocked treads.
		if math.abs(x) < 12 and z >= -148 and z <= -116 then
			h = math.clamp(math.floor((-z - 116) / 4) * 2, 0, 8)
		elseif x >= -56 and x <= 12 and z >= -148 and z <= -132 then
			h = 8
		elseif x >= -56 and x <= -32 and z >= -184 and z < -148 then
			h = 8 + math.clamp(math.floor((-z - 148) / 4) * 2, 0, 12)
		elseif x >= -56 and x <= 52 and z >= -184 and z <= -172 then
			h = 20
		elseif x >= 28 and x <= 52 and z >= -216 and z < -184 then
			h = 20 + math.clamp(math.floor((-z - 184) / 4) * 2, 0, 12)
		end
		return h
	end
	for _, p in root:GetChildren() do
		if p.Name == "Ground" or p.Name == "PitRail" then
			p:Destroy()
		end
	end
	-- Solid columns, merged by equal height/material. No thin cave skin or missing corner cells.
	local cells = {}
	local function cellKey(x, z)
		return x .. ":" .. z
	end
	for z = -280, 232, 4 do
		for x = -252, 324, 4 do
			if footprint(x + 2, z + 2) and not (x >= -88 and x < 88 and z >= -108 and z < 68) then
				local h = groundY(x + 2, z + 2)
				local style = if h > 0
					then 1
					elseif math.noise(x / 36, z / 36, 3) > 0.08 then 2
					else 3
				cells[cellKey(x, z)] = { h = h, style = style }
			end
		end
	end
	for z = -280, 232, 4 do
		for x = -252, 324, 4 do
			local c = cells[cellKey(x, z)]
			if not c then
				continue
			end
			local function same(xx, zz)
				local v = cells[cellKey(xx, zz)]
				return v and v.h == c.h and v.style == c.style
			end
			local nx = 1
			while same(x + nx * 4, z) do
				nx += 1
			end
			local nz = 1
			while true do
				local full = true
				for i = 0, nx - 1 do
					if not same(x + i * 4, z + nz * 4) then
						full = false
						break
					end
				end
				if not full then
					break
				end
				nz += 1
			end
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					cells[cellKey(x + i * 4, z + j * 4)] = nil
				end
			end
			block(
				"TerraceGround",
				x + nx * 2,
				(c.h - 12) / 2,
				z + nz * 2,
				nx * 4,
				c.h + 12,
				nz * 4,
				if c.style == 1
					then "px_stone"
					elseif c.style == 2 then "px_gravel"
					else "px_cobblestone",
				ROCK,
				terrain
			)
		end
	end

	-- Readable rock faces, ore seams and moss ledges, each on the actual terrace riser.
	-- A shallow facing sits outside the solid core: no coplanar flickering and no holes behind it.
	for z = -252, -120, 4 do
		for x = -224, 260, 4 do
			if not footprint(x + 2, z + 2) or not footprint(x + 2, z + 6) then
				continue
			end
			local hi, lo = groundY(x + 2, z + 2), groundY(x + 2, z + 6)
			if hi - lo < 4 then
				continue
			end
			local h = math.floor(x / 4 + z / 4) % 13
			local material = if h == 0 or h == 1
				then "px_coal_ore"
				elseif h == 4 or h == 5 then "px_iron_ore"
				elseif h == 8 then "px_mossy_cobblestone"
				else "px_cobblestone"
			block(
				"TerraceRiserFace",
				x + 2,
				(hi + lo) / 2,
				z + 4.15,
				4,
				hi - lo,
				0.3,
				material,
				ROCK,
				terrain,
				false
			)
			if h == 2 or h == 9 then
				block(
					"RoughRockRib",
					x + 2,
					(hi + lo) / 2,
					z + 5,
					4,
					hi - lo,
					2,
					"px_stone",
					ROCK,
					terrain,
					false
				)
			end
		end
	end
	-- Moss/grass borders and shrubs belong to the periphery and upper benches, keeping
	-- stairs and every principal working court clear. Full blocks/slabs, no particle grass.
	for z = -252, 212, 4 do
		for x = -236, 308, 4 do
			if not footprint(x + 2, z + 2) then
				continue
			end
			local border = not footprint(x + 14, z + 2)
				or not footprint(x - 10, z + 2)
				or not footprint(x + 2, z + 14)
				or not footprint(x + 2, z - 10)
			local upper = z < -132 and math.noise(x / 20, z / 20, 12) > 0.12
			local stair = (x > -64 and x < 60 and z < -112 and z > -220)
			if not (border or upper) or stair then
				continue
			end
			local y = groundY(x + 2, z + 2)
			block(
				"GrassLedge",
				x + 2,
				y + 0.12,
				z + 2,
				4,
				0.24,
				4,
				"px_grass_top",
				Color3.fromRGB(230, 235, 219),
				terrain,
				false
			)
			if (math.floor(x / 4) * 7 + math.floor(z / 4) * 13) % 43 == 0 then
				block(
					"QuarryShrub",
					x + 2,
					y + 2,
					z + 2,
					4,
					4,
					4,
					"px_dark_oak_leaves",
					Color3.fromRGB(174, 204, 143),
					terrain,
					false
				)
				block(
					"QuarryShrub",
					x + 5,
					y + 1.5,
					z + 2,
					2,
					3,
					4,
					"px_dark_oak_leaves",
					Color3.fromRGB(182, 214, 151),
					terrain,
					false
				)
			end
		end
	end
	-- Perimeter follows the actual footprint. The invisible collision wall is behind the
	-- visible low retaining wall/fence; it cannot cover the mine or any interior route.
	local edgeModel = Instance.new("Model")
	edgeModel.Name, edgeModel.ModelStreamingMode, edgeModel.Parent =
		"ContourSafety", Enum.ModelStreamingMode.Persistent, root
	for z = -280, 232, 8 do
		for x = -252, 324, 8 do
			if not footprint(x + 4, z + 4) then
				continue
			end
			for _, v in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
				if footprint(x + 4 + v[1] * 8, z + 4 + v[2] * 8) then
					continue
				end
				local xx, zz = x + 4 + v[1] * 4, z + 4 + v[2] * 4
				local y = groundY(x + 4, z + 4)
				local w, d = if v[1] == 0 then 8 else 2, if v[2] == 0 then 8 else 2
				local guard = block("ContourWall", xx, 56, zz, w, 136, d, nil, STONE, edgeModel)
				guard.Transparency, guard.CanQuery, guard.CastShadow = 1, false, false
				block("OuterRetaining", xx, y + 1, zz, w, 2, d, "px_stone_bricks", BASALT, terrain)
				block(
					"OuterFence",
					xx,
					y + 3.5,
					zz,
					if v[1] == 0 then 8 else 1,
					1,
					if v[2] == 0 then 8 else 1,
					"px_oak_log",
					TIMBER
				)
				block("OuterPost", xx, y + 3, zz, 1.5, 4, 1.5, "px_oak_log", TIMBER)
			end
		end
	end
	-- Vegetation and exposed stone stay on shelves and yard edges, never on the digging grid.
	for _, p in
		{
			{ -220, 44 },
			{ -208, 112 },
			{ -156, 168 },
			{ -80, 188 },
			{ 72, 184 },
			{ 152, 144 },
			{ 288, 28 },
			{ 280, -88 },
			{ -164, -188 },
			{ -88, -224 },
			{ 12, -236 },
			{ 96, -204 },
			{ 176, -156 },
		}
	do
		local x, z = p[1], p[2]
		local y = groundY(x, z)
		for i = 0, 4 do
			local dx, dz = (i % 3) * 4, math.floor(i / 3) * 4
			block(
				"MossyRubble",
				x + dx,
				y + 2 + (i % 2) * 2,
				z + dz,
				4,
				4 + (i % 2) * 4,
				4,
				"px_cobblestone",
				if i % 2 == 0 then MOSS else ROCK,
				terrain
			)
		end
	end
	-- Ore faces and rough ribs establish the working quarry character of the north terraces.
	for _, q in
		{
			{ -140, -164, 8 },
			{ -100, -196, 20 },
			{ -12, -228, 32 },
			{ 84, -200, 20 },
			{ 144, -164, 8 },
		}
	do
		local x, z, y = q[1], q[2], q[3]
		for i = -3, 3 do
			block(
				"QuarryOreFace",
				x + i * 4,
				y + 6 + (i % 2) * 4,
				z,
				4,
				4,
				4,
				if i % 3 == 0 then "px_coal_ore" else "px_iron_ore",
				ROCK,
				terrain
			)
		end
	end
	-- The mine retains the dark unbreakable walls and exact ladder shafts of the original.
	for _, z in { -108, 68 } do
		for _, x in { -48, 48 } do
			block("PitCurb", x, 1, z, 72, 2, 4, "px_stone_bricks", BASALT)
			fence(x - 36, z, x + 36, z, 2, true)
		end
	end
	for _, x in { -88, 88 } do
		for _, z in { -68, 28 } do
			block("PitCurb", x, 1, z, 4, 2, 72, "px_stone_bricks", BASALT)
			fence(x, z - 36, x, z + 36, 2, true)
		end
	end
	for _, p in { { -88, 68 }, { 88, 68 }, { -88, -108 }, { 88, -108 } } do
		block("RimLanternFoot", p[1], 2, p[2], 5, 4, 5, "px_stone_bricks", BASALT)
		lantern(p[1], 6, p[2], false)
	end
	-- [владелец 08.11: «тп рядом с шахтой в каменоломне, игрок должен смотреть на шахту»] at the pit's south rim
	spot("spawn", 0, 84, 0, -20)
	spot("mine", 0, 76, 0, -20)
	for _, x in { -18, 18 } do
		block("ArrivalBorder", x, 1, 152, 3, 2, 56, "px_stone_bricks", BASALT)
		block("ArrivalPost", x, 4, 176, 5, 6, 5, "px_stone_bricks", BASALT)
		lantern(x, 9, 176, false)
	end
	-- Buyer: stepped-gable shop from the accepted sheet, near the arrival on the right.
	local SX, SZ = 56, 124
	block("BuyerCounter", SX, 2, SZ + 8, 20, 4, 4, "px_planks", TIMBER)
	block("CounterTrim", SX, 4.25, SZ + 8, 22.4, 0.5, 5, "px_oak_log", TIMBER)
	for _, x in { SX - 10, SX + 10 } do
		for _, z in { SZ - 8, SZ + 8 } do
			block("StallPost", x, 6, z, 2, 12, 2, "px_oak_log", TIMBER)
		end
	end
	block("StallBack", SX, 4, SZ - 8, 18, 8, 2, "px_planks", TIMBER)
	for tier = 0, 3 do
		for _, side in { -1, 1 } do
			block(
				"StallRoofStep",
				SX + side * (12 - tier * 3),
				12 + tier * 1.5,
				SZ,
				3,
				1.5,
				24,
				"px_planks",
				TIMBER
			)
		end
	end
	block("StallRidge", SX, 18, SZ, 3, 1.5, 24, "px_oak_log", TIMBER)
	block("CounterSample", SX - 6, 6.5, SZ + 8, 4, 4, 4, "px_coal_ore", ROCK)
	block("CounterSample", SX + 6, 5.5, SZ + 8, 4, 2, 4, "px_iron_ore", ROCK)
	lantern(SX + 7, 10, SZ + 7, true)
	barrel(SX + 16, 0, SZ + 4)
	crate(SX + 16, 0, SZ - 8, 8)
	if not buyer then
		local d = Instance.new("HumanoidDescription")
		d.HeadColor, d.LeftArmColor, d.RightArmColor =
			Color3.fromRGB(198, 140, 100),
			Color3.fromRGB(198, 140, 100),
			Color3.fromRGB(198, 140, 100)
		d.TorsoColor, d.LeftLegColor, d.RightLegColor = Color3.fromRGB(65, 78, 85), IRON, IRON
		buyer = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		d:Destroy()
	end
	local npcs = Instance.new("Folder")
	npcs.Name, npcs.Parent = "Npcs", root
	buyer.Name, buyer.Parent = "QuarryBuyer", npcs
	buyer:PivotTo(CFrame.lookAt(Vector3.new(QX + SX, 4, SZ + 2), Vector3.new(QX + SX, 4, SZ + 20)))
	for _, v in buyer:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = true
		end
		if v:IsA("LuaSourceContainer") or v:IsA("BillboardGui") then
			v:Destroy()
		end
	end
	local hrp = assert(buyer:FindFirstChild("HumanoidRootPart"))
	CollectionService:AddTag(hrp, "SellPoint")
	sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 80, 65))
	local hum = buyer:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	buyer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- WEST: masonry loading deck, working rail siding and warehouse behind the winding tower.
	local WX = -180
	block("LoadingDeck", WX, 14, -32, 80, 4, 144, "px_stone_bricks", BASALT)
	for z = -96, 32, 32 do
		for _, x in { WX - 32, WX + 32 } do
			block("LoadingFoot", x, 2, z, 8, 4, 8, "px_stone_bricks", BASALT)
			block("LoadingPillar", x, 9, z, 6, 10, 6, "px_stone_bricks", BASALT)
		end
	end
	for i = 1, 8 do
		block("LoadingStair", WX, i, 74 - i * 4, 24, i * 2, 4, "px_stone_bricks", BASALT)
	end
	for _, x in { WX - 13, WX + 13 } do
		beam(
			"LoadingHandrail",
			Vector3.new(x, 6, 70),
			Vector3.new(x, 20, 42),
			1.5,
			"px_oak_log",
			TIMBER
		)
	end
	fence(WX - 40, -104, WX + 40, -104, 16)
	fence(WX + 40, -104, WX + 40, 40, 16)
	fence(WX - 40, -104, WX - 40, 40, 16)
	-- Warehouse open at the front; full block columns and stepped pitched roof.
	for _, x in { WX - 28, WX + 28 } do
		for _, z in { -100, -56 } do
			block("WarehousePost", x, 28, z, 4, 24, 4, "px_oak_log", TIMBER)
			block("WarehouseFoot", x, 18, z, 6, 4, 6, "px_stone_bricks", BASALT)
		end
	end
	block("WarehouseBack", WX, 26, -100, 56, 20, 2, "px_planks", TIMBER)
	for _, x in { WX - 28, WX + 28 } do
		block("WarehouseSide", x, 22, -78, 2, 12, 44, "px_planks", TIMBER)
	end
	block("WarehouseHeader", WX, 38, -56, 52, 4, 4, "px_oak_log", TIMBER)
	for i = 0, 6 do
		for _, side in { -1, 1 } do
			block(
				"WarehouseRoof",
				WX,
				39 + i * 2,
				-78 + side * (26 - i * 4),
				64,
				2,
				4,
				"px_planks",
				TIMBER
			)
		end
	end
	crate(WX - 18, 16, -86, 8)
	crate(WX - 8, 16, -86, 8)
	crate(WX - 18, 24, -86, 6)
	barrel(WX + 18, 16, -86)
	lantern(WX + 24, 33, -58, true)
	-- Large stepped wooden wheel and an intelligible load-bearing hoist structure.
	for _, x in { WX - 20, WX + 20 } do
		block("HoistFoot", x, 18, -12, 10, 4, 10, "px_stone_bricks", BASALT)
		block("HoistTower", x, 46, -12, 4, 52, 6, "px_oak_log", TIMBER)
	end
	block("HoistCrown", WX, 74, -12, 52, 4, 8, "px_oak_log", TIMBER)
	block("HoistCrossbar", WX, 40, -12, 36, 4, 8, "px_oak_log", TIMBER)
	beam(
		"HoistBrace",
		Vector3.new(WX - 20, 22, -12),
		Vector3.new(WX + 20, 62, -12),
		3,
		"px_oak_log",
		TIMBER
	)
	for dx = -24, 24, 4 do
		for dy = -24, 24, 4 do
			local r = math.sqrt(dx * dx + dy * dy)
			if r >= 19 and r <= 24 then
				block("WheelRim", WX + dx, 52 + dy, -6, 4, 4, 4, "px_planks", TIMBER)
			end
		end
	end
	block("WheelHub", WX, 52, -6, 8, 8, 8, "px_oak_log", TIMBER)
	block("WheelSpoke", WX, 52, -6, 40, 3, 3, "px_oak_log", TIMBER)
	block("WheelSpoke", WX, 52, -6, 3, 40, 3, "px_oak_log", TIMBER)
	for _, side in { -1, 1 } do
		beam(
			"WheelSpoke",
			Vector3.new(WX - 14, 52 + side * 14, -6),
			Vector3.new(WX + 14, 52 - side * 14, -6),
			3,
			"px_oak_log",
			TIMBER
		)
	end
	block("HoistAxle", WX, 52, -12, 5, 5, 24, nil, IRON)
	block("HoistBoom", WX + 24, 62, -12, 56, 4, 7, "px_oak_log", TIMBER)
	beam(
		"HoistBoomBrace",
		Vector3.new(WX, 42, -12),
		Vector3.new(WX + 44, 60, -12),
		3,
		"px_oak_log",
		TIMBER
	)
	block("HoistChain", WX + 44, 43, -12, 0.6, 34, 0.6, nil, IRON, props, false)
	crate(WX + 44, 21, -12, 8)
	lantern(WX - 24, 62, -8, false)
	for x = WX - 28, WX + 28, 8 do
		block("RailSleeper", x, 16.3, 22, 2, 0.6, 12, "px_oak_log", TIMBER)
	end
	for _, z in { 19, 25 } do
		block("Rail", WX, 17, z, 64, 0.5, 0.5, nil, IRON)
	end
	for _, x in { WX - 16, WX + 4 } do
		block("CartFloor", x, 19, 22, 11, 1, 7, nil, IRON)
		for _, z in { 18, 26 } do
			block("CartSide", x, 21, z, 11, 4, 1, nil, Color3.fromRGB(147, 151, 154))
			for _, dx in { -4, 4 } do
				block("CartWheel", x + dx, 18, z, 2, 2, 1.5, nil, IRON)
			end
		end
		for _, dx in { -6, 6 } do
			block("CartEnd", x + dx, 21, 22 + 0, 1, 4, 8, nil, Color3.fromRGB(147, 151, 154))
		end
		block("CartOre", x, 21, 22, 10, 2, 6, "px_coal_ore", ROCK)
	end
	-- Three sorting bays with different ore piles, lumber and a tool rack at the yard edge.
	for i = 0, 2 do
		local x, z = WX - 20 + i * 20, 116
		block("SortingBase", x, 1, z, 20, 2, 24, "px_stone_bricks", BASALT)
		block("SortingBack", x, 5, z + 10, 20, 6, 4, "px_stone_bricks", BASALT)
		block("SortingDivider", x - 9, 5, z - 2, 2, 6, 20, "px_stone_bricks", BASALT)
		for j = 0, 3 do
			block(
				"SortingLoad",
				x - 4 + j % 2 * 4,
				4 + math.floor(j / 2) * 2,
				z - 4 + math.floor(j / 2) * 4,
				4,
				4,
				4,
				({ "px_coal_ore", "px_iron_ore", "px_stone" })[i + 1],
				ROCK
			)
		end
	end
	for row = 0, 1 do
		for i = 0, 2 - row do
			block(
				"TimberStack",
				-92 + i * 4 + row * 2,
				2 + row * 4,
				152,
				4,
				4,
				20,
				"px_oak_log",
				TIMBER
			)
		end
	end
	for _, x in { -122, -102 } do
		block("ToolRackPost", x, 6, 104, 2, 12, 2, "px_oak_log", TIMBER)
	end
	block("ToolRackBeam", -112, 13, 104, 24, 2, 2, "px_oak_log", TIMBER)
	for i = 0, 2 do
		block("ToolHandle", -118 + i * 6, 7, 104, 1, 7, 1, "px_oak_log", TIMBER)
		block("ToolHead", -118 + i * 6, 9, 104, 5, 1.5, 2, nil, IRON)
	end
	crate(-116, 0, 148, 8)
	crate(-126, 0, 148, 8)
	crate(-126, 8, 148, 6)

	-- NORTH: two work shelters on distinct terraces, a connected upper gallery, stairs in terrain.
	local function shelter(x, z, y)
		for _, dx in { -20, 20 } do
			block("ShelterPost", x + dx, y + 7, z + 6, 4, 14, 4, "px_oak_log", TIMBER)
			block("ShelterBase", x + dx, y + 1, z + 6, 6, 2, 6, "px_stone_bricks", BASALT)
		end
		block("ShelterRoof", x, y + 15, z, 48, 2, 24, "px_planks", TIMBER)
		block("ShelterBeam", x, y + 13, z + 8, 48, 2, 4, "px_oak_log", TIMBER)
		crate(x - 12, y, z, 8)
		barrel(x + 12, y, z)
		lantern(x, y + 10, z + 8, true)
	end
	shelter(-112, -180, 20)
	shelter(92, -212, 32)
	for _, q in { { -112, -140, 8, 88 }, { 92, -172, 20, 96 } } do
		local x, z, y, w = q[1], q[2], q[3], q[4]
		block("TerraceGallery", x, y + 1, z, w, 2, 12, "px_planks", TIMBER)
		fence(x - w / 2, z + 6, x + w / 2, z + 6, y + 2)
		for dx = -w / 2, w / 2, 16 do
			block("GalleryBrace", x + dx, y - 2, z, 4, 8, 4, "px_oak_log", TIMBER)
		end
	end
	for _, p in { { -64, -152, 8 }, { 64, -184, 20 }, { -76, -216, 32 } } do
		block("TerraceLampFoot", p[1], p[3] + 2, p[2], 4, 4, 4, "px_stone_bricks", BASALT)
		lantern(p[1], p[3] + 6, p[2], false)
	end

	-- Stone cutting benches and stored quarry blocks sit beside the terrace work shelters.
	for _, v in { { -120, -172, 20 }, { 100, -204, 32 } } do
		local x, z, y = v[1], v[2], v[3]
		block("CuttingBench", x, y + 3, z + 14, 16, 2, 6, "px_planks", TIMBER)
		for _, dx in { -6, 6 } do
			block("BenchLeg", x + dx, y + 1, z + 14, 2, 2, 4, "px_oak_log", TIMBER)
		end
		block("CuttingStone", x, y + 5, z + 14, 8, 2, 4, "px_smooth_stone", ROCK)
		for i = 0, 2 do
			block(
				"StoredQuarryStone",
				x + 28 + i % 2 * 4,
				y + 2 + math.floor(i / 2) * 4,
				z + 12,
				4,
				4,
				4,
				"px_stone",
				ROCK
			)
		end
	end
	-- EAST: open-sky basalt sanctuary with a free combat circle and arch behind the arena.
	local AX, AZ = 220, -32
	block("ArenaPlinth", AX, 6, AZ, 104, 12, 104, "px_stone_bricks", BASALT, arena)
	block(
		"ArenaInlay",
		AX,
		12.15,
		AZ,
		80,
		0.3,
		80,
		"px_stone_bricks",
		Color3.fromRGB(208, 211, 216),
		arena
	)
	for _, d in { -32, 32 } do
		block("ArenaFloorMark", AX + d, 12.33, AZ, 2, 0.06, 64, "px_stone", ROCK, arena, false)
		block("ArenaFloorMark", AX, 12.33, AZ + d, 64, 0.06, 2, "px_stone", ROCK, arena, false)
	end
	for i = 1, 6 do
		block("ArenaStair", AX, i, 46 - i * 4, 64, i * 2, 4, "px_stone_bricks", BASALT, arena)
	end
	for _, dx in { -46, 46 } do
		for _, dz in { -46, 46 } do
			local x, z = AX + dx, AZ + dz
			block("SentryFoot", x, 13, z, 12, 2, 12, "px_stone_bricks", BASALT, arena)
			block("SentryBase", x, 16, z, 10, 4, 10, "px_stone_bricks", BASALT, arena)
			block("SentryBody", x, 26, z, 8, 16, 8, "px_stone_bricks", BASALT, arena)
			block("SentryBrow", x, 36, z, 12, 4, 12, "px_stone_bricks", BASALT, arena)
			block("SentryCrown", x, 40, z, 8, 4, 8, "px_stone_bricks", BASALT, arena)
			block("SentryFace", x, 29, z + 4.1, 6, 6, 0.3, "px_stone", ROCK, arena, false)
			for _, ex in { -1.5, 1.5 } do
				block("SentryEye", x + ex, 30, z + 4.3, 1.2, 1, 0.3, nil, IRON, arena, false)
			end
			block("SentryMouth", x, 27.8, z + 4.3, 3, 1, 0.3, nil, IRON, arena, false)
			block("SentryRecess", x, 21, z + 4.1, 3, 6, 0.3, nil, IRON, arena, false)
			lantern(x, 21, z + 6, dz > 0)
		end
	end
	block("ArchLanding", AX, 6, AZ - 58, 72, 12, 12, "px_stone_bricks", BASALT, arena)
	for tier = 0, 5 do
		local inset = if tier < 3 then 0 else (tier - 2) * 6
		for _, side in { -1, 1 } do
			block(
				"SanctuaryArch",
				AX + side * (28 - inset),
				16 + tier * 8,
				AZ - 56,
				8,
				8,
				8,
				"px_stone_bricks",
				BASALT,
				arena
			)
		end
	end
	block("SanctuaryKeystone", AX, 60, AZ - 56, 24, 8, 8, "px_stone_bricks", BASALT, arena)
	local bossSpawn = block("BossSpawn", AX, 12.3, AZ, 4, 0.2, 4, nil, STONE, arena, false)
	bossSpawn.Transparency = 1
	bossSpawn:SetAttribute("BossId", "basalt_guardian")
	bossSpawn:SetAttribute("ArenaRadius", 40)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
	spot("boss", AX, 52, AX, AZ)
	-- Deliberate trim clearances: avoid equal visible planes where different textures meet.
	-- Never alter the mining grid, terrain collision or ladder widths.
	for _, v in arena:GetDescendants() do
		if v:IsA("BasePart") and v.Name == "ArenaFloorMark" and v.Size.X > v.Size.Z then
			v.Size = Vector3.new(62, v.Size.Y, v.Size.Z)
		end
	end
	for _, v in terrain:GetDescendants() do
		if not v:IsA("BasePart") then
			continue
		end
		if v.Name == "GrassLedge" then
			v.Size = Vector3.new(v.Size.X - 0.12, v.Size.Y, v.Size.Z - 0.12)
		elseif v.Name == "TerraceRiserFace" then
			v.Size = Vector3.new(v.Size.X - 0.12, math.max(0.1, v.Size.Y - 0.08), v.Size.Z)
		elseif v.Name == "QuarryShrub" then
			v.Size -= Vector3.new(0.24, 0.08, 0.24)
		end
	end
	-- Local daylight preset is for consistent gameplay, not a cave. Deep mine fill remains.
	local lighting = Instance.new("Model")
	lighting.Name, lighting.ModelStreamingMode, lighting.Parent =
		"QuarryDaylight", Enum.ModelStreamingMode.Persistent, root
	local volume = block("DaylightVolume", 40, 36, -20, 608, 240, 544, nil, STONE, lighting, false)
	volume.Transparency = 1
	volume:SetAttribute("Ambient", Color3.fromRGB(140, 140, 146))
	volume:SetAttribute("Exposure", -0.1)
	volume:SetAttribute("Haze", 0.035)
	volume:SetAttribute("ClockTime", 13.5)
	volume:SetAttribute("Brightness", 1.5)
	CollectionService:AddTag(volume, "IndoorLighting")
	require(Shared.MineLighting).Apply(anchor, { 40, 16, 40 })
	-- Separate altitude prevents the newly open quarry from overlooking the prison/basement.
	local BY = 37500 -- [decision] unused altitude above the existing 34500 highest location.
	root:SetAttribute("WorldBaseY", BY)
	for _, v in root:GetDescendants() do
		if v:IsA("BasePart") then
			v.CFrame += Vector3.new(0, BY, 0)
		end
	end
	require(Shared.LocationBounds).Apply(root, "quarry")
	assert(count < 6000, "Open quarry scenery budget exceeded")
	-- Preserve an inert snapshot: stripping every tag prevents backup NPCs/anchors joining live registries.
	local backupName = "QuarryBeforeRedesign_20261103"
	if old and not game.ServerStorage:FindFirstChild(backupName) then
		local backup = old:Clone()
		backup.Name = backupName
		for _, v in backup:GetDescendants() do
			local tags = CollectionService:GetTags(v)
			if #tags > 0 then
				v:SetAttribute("BackupTags", table.concat(tags, "|"))
			end
			for _, tag in tags do
				CollectionService:RemoveTag(v, tag)
			end
			if v:IsA("BaseScript") then
				v.Enabled = false
			end
		end
		backup.Parent = game.ServerStorage
	end
	-- Clear only the old quarry's tiny Terrain pool, now replaced by dry mining infrastructure.
	workspace.Terrain:FillBlock(at(-80, 1.1, 128), Vector3.new(36, 4, 28), Enum.Material.Air)
	if old then
		old:Destroy()
	end
	root.Name = "Quarry"
	return "[build-quarry] accepted open-air quarry, extra parts="
		.. count
		.. ", original mining volume/economy/boss retained"
end, debug.traceback)
if not ok then
	root:Destroy()
	if buyer and not buyer.Parent then
		buyer:Destroy()
	end
	error(result)
end
return result
