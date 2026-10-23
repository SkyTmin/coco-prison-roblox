--!nocheck
-- Builds the Паучье логово, level 17, PvP [меню]. «Паучье логово окутано мраком, стены густо покрыты паутиной, а
-- тени, скользящие по углам, вызывают дрожь» [клиент]. Blocks: белая шерсть 90 %, паутина 10 % [меню]. Boss: Паучья
-- матка — «королева, скрывающаяся в тени своей армии» [клиент].
-- v2 [владелец 23.10: «всё плоское, небо плоское, стены плоские, пустые, ненасыщенные; паутина как блок, а должна
-- быть как в майнкрафте, и персонаж должен в ней застревать»]:
--  * the cave is a 3D voxel field (one block = 4 studs): domed vaults that curve down into the walls, overhangs,
--    ledges and terraced rubble at the foot of the walls, chimneys in the vaults with shafts of moonlight; only the
--    shell next to the air is built (greedy runs along X, then up);
--  * the rock is layered and mixed like a Minecraft cave: moss and mossy cobble at the foot, stone tinted violet,
--    deep dark "deepslate" veins, greenish tuff, coal / iron / gold ores, silk-covered patches in the spiders'
--    halls, glow lichen on the walls and vaults, cave vines with glowing berries, tapered dripstone;
--  * webs are Minecraft cobwebs: cross sprites (Config.textures.sprites.cobweb, VoxeLibre web, CC BY-SA 4.0) in
--    the corners of walls and vaults, under the mineshaft caps, round the spawners, giant webs built of them in the
--    Queen's nest; reachable ones are tagged Cobweb (Shared/Cobweb: the player is stuck as in Minecraft);
--  * it moves: spiders drop and climb on threads, crawl in circles, spawner cages spin their spider, cocoons sway,
--    egg sacs pulse (tags Ambient*, src/client/AmbientMotion.luau).
-- Plan (kept from v1): the abandoned adit (arrival, the mine 32×12×32 [решение], the buyer), the Clutch (west), the
-- Cocoon graveyard (east), the Queen's nest (north, the arena), wide passages with mineshaft frames (PvP crowds).
-- X 8400, height Y 10500. Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures
local WEB_TEX = textures.sprites and textures.sprites.cobweb

local old = workspace:FindFirstChild("SpiderLair")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "SpiderLair"
root:SetAttribute("LocationId", "spider_lair")
root.Parent = workspace

local BX, BZ = 8400, 0
local BY = 10500 -- the location's own height [владелец 23.10]
local B = 4
local rng = Random.new(20261723)
local THREAD = Color3.fromRGB(236, 236, 242)
local STONE = Color3.fromRGB(222, 196, 240) -- stone with a violet cast
local DEEP = Color3.fromRGB(150, 124, 204) -- the deep dark veins ("deepslate")
local TUFF = Color3.fromRGB(190, 214, 170)
local VAULT = Color3.fromRGB(176, 148, 220)
local IRON = Color3.fromRGB(56, 54, 62)
local RUST = Color3.fromRGB(140, 80, 46)
local SPIDER = Color3.fromRGB(54, 44, 40) -- a Minecraft spider: dark brown-grey
local CAVE_SPIDER = Color3.fromRGB(24, 70, 86) -- a cave spider: dark teal
local EYE = Color3.fromRGB(255, 30, 40)
local EGG = Color3.fromRGB(226, 232, 200)
local GLOW = Color3.fromRGB(120, 255, 110)
local LICHEN = Color3.fromRGB(150, 230, 170)
local SILK = Color3.fromRGB(230, 226, 214)
local WALL_SILK = Color3.fromRGB(176, 170, 190) -- silk over the walls: dimmer, it lit up as white slabs
local BONE = Color3.fromRGB(230, 224, 204)
local MOON = Color3.fromRGB(176, 206, 255)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or THREAD
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end
local function textured(p, variant, tint)
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = tint or Color3.new(1, 1, 1)
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function at(x, y, z)
	return CFrame.new(BX + x, y, BZ + z)
end
local function V(x, y, z)
	return Vector3.new(BX + x, y, BZ + z)
end
-- an ellipsoid (a round part with no texture: textures on round parts look broken)
local function blob(name, size, cf, color, parent, material)
	local p = part(name, size, cf, color, material or Enum.Material.SmoothPlastic, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
-- a straight piece between two world points
local function beam(name, a, b, thick, color, parent, material)
	local len = (b - a).Magnitude
	return part(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material, parent)
end
local LIGHT_POWER, LIGHT_RANGE = 0.45, 0.7
local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range * LIGHT_RANGE
	l.Brightness = brightness * LIGHT_POWER
	l.Color = color
	l.Shadows = false
	l.Parent = p
	return l
end
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
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
local function boardText(target, text, color, faces)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 90
		gui.LightInfluence = 0.5
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(235, 225, 200)
		label.TextStrokeTransparency = 0.4
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Text = text
		label.Parent = gui
	end
end
local function n2(x, z, seed, scale)
	return math.noise(x * scale, z * scale, seed)
end
local function n3(x, y, z, scale, seed)
	return math.noise(x * scale + (seed or 0), y * scale, z * scale - (seed or 0))
end
local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((px - ax - dx * t) ^ 2 + (pz - az - dz * t) ^ 2)
end
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end
local function hash(a, b, c)
	local h = bit32.bxor(a * 73856093, b * 19349663, c * 83492791)
	return (h % 10007) / 10007
end

-- ================================================================ the plan
local PIT = { x = 0, z = 136, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json spider_lair.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B -- the hole edges (x ±72, z 64 / 208) lie on the block grid
local SPAWN_Z = PIT.z + PIT.hole + 14
-- the chambers: round, domed; h = the height of the dome's crown
local ENTRY = { x = 0, z = 150, r = 138, h = 64, name = "entry" }
local ARENA = { x = 0, z = -196, r = 86, h = 84, name = "arena" }
local CLUTCH = { x = -186, z = -22, r = 64, h = 50, name = "clutch" }
local COCOONS = { x = 186, z = -22, r = 64, h = 52, name = "cocoons" }
local CHAMBERS = { ENTRY, ARENA, CLUTCH, COCOONS }
-- the passages: wide (PvP crowds), an abandoned mineshaft in each; { ax, az, bx, bz, half-width }
local TUNNELS = {
	{ 0, 30, 0, -118, 17, main = true },
	{ -100, 92, -168, 16, 13 },
	{ -158, -70, -68, -168, 12 },
	{ 100, 92, 168, 16, 13 },
	{ 158, -70, 68, -168, 12 },
	{ -104, 222, -204, 254, 11, deadEnd = true }, -- the collapsed old drift
}
local TUNNEL_H = 32
-- chimneys in the vaults: moonlight falls through them (2 × 2 blocks)
local CHIMNEYS = { { -40, 230 }, { 76, 96 }, { -186, -30 }, { 186, -8 }, { 0, -60 }, { -36, -214 } }

-- ================================================================ the voxel field
local X0, Z0 = -288, -304
local NX, NZ, NL = 144, 152, 28 -- level 0 = the floor slab (y −4..0), level L = y 4(L−1)..4L
local field = buffer.create(NX * NZ * (NL + 1)) -- 0 rock, 1 air, 2 the mine pit (neither)
local function idx(ix, iz, L)
	return ix + iz * NX + L * NX * NZ
end
local function state(ix, iz, L)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ or L < 0 or L > NL then
		return 0
	end
	return buffer.readu8(field, idx(ix, iz, L))
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local chimneyCol = {}
for _, c in ipairs(CHIMNEYS) do
	for dx = 0, 1 do
		for dz = 0, 1 do
			chimneyCol[(math.floor((c[1] - X0) / B) + dx) + (math.floor((c[2] - Z0) / B) + dz) * NX] = true
		end
	end
end

local columns = {} -- [ix + iz·NX] = { x, z, d, owner, floor (levels), ceil (y of the vault), open }
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * B + B / 2, Z0 + iz * B + B / 2
		local feats = {}
		local best, owner = math.huge, nil
		for _, s in ipairs(CHAMBERS) do
			local d = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r * (1 + n2(x, z, 1.3 + s.r * 0.01, 0.025) * 0.1)
			if d < 1.25 then
				table.insert(feats, { d = d, H = s.h * (1 + n2(x, z, 3.1, 0.04) * 0.1), knee = 0.28 })
			end
			if d < best then
				best, owner = d, s
			end
		end
		for _, t in ipairs(TUNNELS) do
			local d = segDist(x, z, t[1], t[2], t[3], t[4]) / t[5] * (1 + n2(x, z, 4.7, 0.06) * 0.14)
			if d < 1.25 then
				table.insert(feats, { d = d, H = TUNNEL_H * (1 + n2(x, z, 5.3, 0.05) * 0.12), knee = 0.4 })
			end
			if d < best then
				best, owner = d, t
			end
		end
		local fl = 0
		if best > 0.8 and owner ~= ARENA then
			fl = math.clamp(math.floor((best - 0.8) * 14 + n2(x, z, 8.8, 0.09) * 1.4), 0, 3)
		elseif owner == ARENA and best > 0.9 then
			fl = math.clamp(math.floor((best - 0.9) * 14), 0, 2)
		end
		local hole = inHole(x, z)
		if hole then
			fl = 0
		end
		local col = { x = x, z = z, d = best, owner = owner, floor = fl, hole = hole }
		columns[ix + iz * NX] = col
		buffer.writeu8(field, idx(ix, iz, 0), if hole then 2 else 0)
		local chimney = chimneyCol[ix + iz * NX]
		local roofed = false
		for L = 1, NL do
			local yc = (L - 1) * B + B / 2
			local open = false
			if L - 1 >= fl then
				local wobble = n3(x, yc, z, 0.05, 17) * 0.09 + n3(x, yc, z, 0.13, 41) * 0.04
				for _, f in ipairs(feats) do
					local up = math.max(0, yc / f.H - f.knee) / (1 - f.knee)
					if math.sqrt(f.d * f.d + up * up) + wobble < 1 then
						open = true
						break
					end
				end
			end
			if L == NL then
				open = false -- the top level is always rock (the chimneys end in the moon glow)
			elseif chimney and not open and L - 1 >= fl and col.ceil then
				open = true -- the chimney goes on up to the top
			end
			if open and not roofed then
				buffer.writeu8(field, idx(ix, iz, L), 1)
			elseif L - 1 >= fl and not col.ceil then
				col.ceil = (L - 1) * B
				roofed = not chimney
				if chimney then
					buffer.writeu8(field, idx(ix, iz, L), 1)
				end
			end
		end
		col.open = state(ix, iz, fl + 1) == 1
		col.chimney = chimney
	end
	if iz % 8 == 0 then
		task.wait()
	end
end
local function colAt(x, z)
	local ix, iz = math.floor((x - X0) / B), math.floor((z - Z0) / B)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then
		return nil
	end
	return columns[ix + iz * NX]
end
local function floorAt(x, z)
	local c = colAt(x, z)
	return if c then c.floor * B else 0
end
local function ceilAt(x, z)
	local c = colAt(x, z)
	return if c and c.ceil then c.ceil else 24
end
-- open walking floor at y 0 (not a terrace, not the pit)
local function isOpen(x, z)
	local c = colAt(x, z)
	return c ~= nil and c.open and not c.hole and c.floor == 0
end
local function flatAround(x, z, r)
	for _, o in ipairs({ { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } }) do
		if not isOpen(x + o[1], z + o[2]) then
			return false
		end
	end
	return true
end

-- ================================================================ the rock: materials
local ORES = { { "px_coal_ore", 0.03 }, { "px_iron_ore", 0.045 }, { "px_gold_ore", 0.051 } }
local function zoneOf(col)
	local o = col.owner
	return if o == CLUTCH then "clutch" elseif o == COCOONS then "cocoons" elseif o == ARENA then "arena" elseif o and o[1] then "tunnel" else "entry"
end
local function floorLook(col, x, z)
	local v = n2(x, z, 7.7, 0.05) + n2(x, z, 2.9, 0.13) * 0.5
	local zone = zoneOf(col)
	if zone == "clutch" then
		if v > 0.05 then
			return "px_forest_floor", Color3.new(1, 1, 1)
		end
		return if v > -0.4 then "px_dirt" else "px_mossy_cobblestone", if v > -0.4 then Color3.fromRGB(150, 120, 110) else STONE
	elseif zone == "cocoons" then
		if v > 0.5 then
			return "px_white_wool", SILK
		end
		return if v > 0 then "px_gravel" else "px_stone", Color3.fromRGB(170, 160, 175)
	elseif zone == "arena" then
		if v > 0.45 then
			return "px_white_wool", SILK
		end
		return if v > -0.1 then "px_mossy_cobblestone" else "px_cobblestone", STONE
	elseif zone == "tunnel" then
		return if v > 0.1 then "px_gravel" else "px_cobblestone", Color3.fromRGB(170, 160, 170)
	end
	if v > 0.5 then
		return "px_forest_floor", Color3.new(1, 1, 1)
	elseif v > 0.2 then
		return "px_mossy_cobblestone", STONE
	elseif v < -0.45 then
		return "px_gravel", Color3.fromRGB(170, 160, 170)
	end
	return "px_cobblestone", STONE
end
local function rockLook(col, x, y, z, ix, iz, L, vault)
	local zone = zoneOf(col)
	local r = hash(ix, iz, L)
	local n = n3(x, y, z, 0.045, 3)
	local v = n3(x, y, z, 0.11, 9)
	local silk = n3(x, y, z, 0.07, 23)
	if (zone == "arena" or zone == "cocoons" or zone == "clutch") and silk > (if zone == "arena" then 0.4 else 0.48) and y > 10 then
		return "px_white_wool", WALL_SILK -- silk spun over the rock
	end
	if not vault and y < 9 then
		if v > (if zone == "clutch" then -0.2 else 0.15) then
			return "px_forest_floor", Color3.new(1, 1, 1)
		end
		return "px_mossy_cobblestone", STONE
	end
	for _, o in ipairs(ORES) do
		if r < o[2] and (o[1] ~= "px_gold_ore" or y < 30) then
			return o[1], Color3.fromRGB(215, 205, 225)
		end
	end
	if n > 0.22 or (vault and n > -0.05) then
		return if v > 0.3 then "px_cobblestone" else "px_stone", DEEP
	elseif n < -0.32 then
		return "px_cobblestone", TUFF
	elseif v > 0.33 then
		return if zone == "clutch" then "px_forest_floor" else "px_mossy_cobblestone", if zone == "clutch" then Color3.new(1, 1, 1) else STONE
	end
	return "px_stone", if vault then VAULT else STONE
end

-- ================================================================ build the shell (rock next to the air)
local cave = folder("Cave")
local count = 0
local lichenSpots = {} -- faces for glow lichen: { position, normal }
local cornerSpots = {} -- air cells in the corner of a wall and the vault (cobwebs)
local floorCorners = {} -- air cells at the floor with rock on two sides (cobwebs)
do
	local open = {} -- [iz .. ix0 .. ix1 .. key] = run, continued upwards
	local function flush(r)
		local x0, x1 = X0 + r.ix0 * B, X0 + (r.ix1 + 1) * B
		local z0, z1 = Z0 + r.iz * B, Z0 + (r.iz + 1) * B
		local y0, y1 = (r.L0 - 1) * B, r.L1 * B
		local p = part(r.name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), nil, nil, cave)
		textured(p, r.variant, r.tint)
		count += 1
	end
	for L = 0, NL do
		local nextOpen = {}
		for iz = 0, NZ - 1 do
			local run = nil
			local function close()
				if not run then
					return
				end
				local k = run.iz .. ":" .. run.ix0 .. ":" .. run.ix1 .. ":" .. run.variant .. ":" .. tostring(run.tint)
				local prev = open[k]
				if prev and prev.L1 == L - 1 then
					prev.L1 = L
					nextOpen[k] = prev
					open[k] = nil
				else
					run.L0, run.L1 = L, L
					nextOpen[k] = run
				end
				run = nil
			end
			for ix = 0, NX - 1 do
				local s = buffer.readu8(field, idx(ix, iz, L))
				local variant, tint, name
				if s == 0 then
					local up, down = state(ix, iz, L + 1) == 1, state(ix, iz, L - 1) == 1
					local side = state(ix + 1, iz, L) == 1 or state(ix - 1, iz, L) == 1 or state(ix, iz + 1, L) == 1 or state(ix, iz - 1, L) == 1
					if up or down or side then
						local col = columns[ix + iz * NX]
						local x, y, z = X0 + ix * B + B / 2, (L - 1) * B + B / 2, Z0 + iz * B + B / 2
						if up then
							variant, tint = floorLook(col, x, z)
							name = "Floor"
						else
							variant, tint = rockLook(col, x, y, z, ix, iz, L, down)
							name = if down then "Vault" else "CaveWall"
						end
						if L == NL and col.chimney then
							variant, tint, name = nil, MOON, "MoonSky"
						end
						-- glow lichen on some faces
						if (side or down) and not up and hash(iz, L, ix) < 0.05 and y > 6 then
							local nrm = if down then Vector3.new(0, -1, 0)
								elseif state(ix + 1, iz, L) == 1 then Vector3.xAxis
								elseif state(ix - 1, iz, L) == 1 then -Vector3.xAxis
								elseif state(ix, iz + 1, L) == 1 then Vector3.zAxis
								else -Vector3.zAxis
							table.insert(lichenSpots, { V(x, y, z) + nrm * (B / 2 + 0.06), nrm })
						end
					end
				elseif s == 1 and L >= 1 then
					local col = columns[ix + iz * NX]
					local above = state(ix, iz, L + 1) == 0
					local walls = 0
					for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
						if state(ix + d[1], iz + d[2], L) == 0 then
							walls += 1
						end
					end
					local x, y, z = X0 + ix * B + B / 2, (L - 1) * B + B / 2, Z0 + iz * B + B / 2
					if above and walls >= 1 and not col.chimney then
						table.insert(cornerSpots, { x, y, z })
					elseif L - 1 == col.floor and walls >= 2 and not col.hole then
						table.insert(floorCorners, { x, y, z })
					end
				end
				if variant or name == "MoonSky" then
					local v = variant or "MoonSky"
					if run and run.ix1 == ix - 1 and run.variant == v and run.tint == tint then
						run.ix1 = ix
					else
						close()
						run = { ix0 = ix, ix1 = ix, iz = iz, variant = v, tint = tint, name = name }
					end
				else
					close()
				end
			end
			close()
		end
		for _, r in pairs(open) do
			flush(r)
		end
		open = nextOpen
		task.wait()
	end
	for _, r in pairs(open) do
		flush(r)
	end
	-- the moon glow at the tops of the chimneys: neon, no texture
	for _, p in ipairs(cave:GetChildren()) do
		if p.MaterialVariant == "MoonSky" then
			p.MaterialVariant = ""
			p.Material = Enum.Material.Neon
			p.Color = MOON
		end
	end
end
task.wait()

-- ================================================================ cobwebs (Minecraft cross sprites)
local webs = folder("Webs")
local webCells = {} -- one web per block cell
-- a cobweb filling one block cell at a position (snapped to the block grid unless free); reachable ones are
-- tagged Cobweb: the player is stuck in them as in Minecraft
local function cobweb(x, y, z, parent, free)
	local cx, cy, cz = x, y, z
	if not free then
		cx = X0 + math.floor((x - X0) / B) * B + B / 2
		cz = Z0 + math.floor((z - Z0) / B) * B + B / 2
		cy = math.floor(y / B) * B + B / 2
	end
	local k = math.floor(cx) .. ":" .. math.floor(cy) .. ":" .. math.floor(cz)
	if webCells[k] then
		return nil
	end
	webCells[k] = true
	local box = part("Cobweb", Vector3.new(B, B, B), at(cx, cy, cz), nil, nil, parent or webs)
	box.Transparency = 1
	decor(box).CastShadow = false
	if cy < 14 then
		box:AddTag("Cobweb")
	end
	for _, yaw in ipairs({ math.pi / 4, -math.pi / 4 }) do
		local plane = decor(part("CobwebSprite", Vector3.new(B * math.sqrt(2), B, 0.05), box.CFrame * CFrame.Angles(0, yaw, 0), nil, nil, box))
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
	return box
end
-- a giant web built of cobweb cells: an orb pattern rasterised on a plane (cf: X, Y in the plane)
local function giantWeb(cf, R, spokes, rings, parent)
	rings = math.min(rings, 2)
	local cells = {}
	local function mark(lx, ly)
		local gx, gy = math.floor(lx / B + 0.5), math.floor(ly / B + 0.5)
		cells[gx .. ":" .. gy] = { gx * B, gy * B }
	end
	for k = 0, spokes - 1 do
		local a = k / spokes * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		for r = 0, R, B do
			mark(math.cos(a) * r, math.sin(a) * r)
		end
	end
	for k = 1, rings do
		local r = R * k / (rings + 0.3)
		for a = 0, math.pi * 2, B * 1.1 / r do
			mark(math.cos(a) * r, math.sin(a) * r)
		end
	end
	for _, c in pairs(cells) do
		local p = (cf * CFrame.new(c[1], c[2], 0)).Position
		cobweb(p.X - BX, p.Y, p.Z - BZ, parent or webs, true)
	end
end

-- ================================================================ small builders
local props = folder("Props")
local function tagMotion(m, tag, attrs)
	for k, v in pairs(attrs or {}) do
		m:SetAttribute(k, v)
	end
	CollectionService:AddTag(m, tag)
end
-- a blocky spider (a Model): abdomen with a mark, thorax, head, eight red eyes, eight jointed legs
local function spiderModel(cf, s, parent, opts)
	opts = opts or {}
	local m = model(if opts.cave then "CaveSpider" else "Spider", parent or props)
	local col = if opts.cave then CAVE_SPIDER else SPIDER
	local body = part("SpiderAbdomen", Vector3.new(3.2, 2.4, 3.8) * s, cf * CFrame.new(0, 1.9 * s, 2.4 * s), col, nil, m)
	part("SpiderMark", Vector3.new(1.2, 0.2, 1.8) * s, body.CFrame * CFrame.new(0, 1.22 * s, 0), if opts.cave then Color3.fromRGB(40, 150, 130) else Color3.fromRGB(160, 24, 30), nil, m)
	part("SpiderThorax", Vector3.new(2.2, 1.6, 2.2) * s, cf * CFrame.new(0, 1.6 * s, 0), col:Lerp(Color3.new(1, 1, 1), 0.06), nil, m)
	local head = part("SpiderHead", Vector3.new(1.6, 1.3, 1.3) * s, cf * CFrame.new(0, 1.6 * s, -1.7 * s), col, nil, m)
	for i = 0, 3 do
		for _, side in ipairs({ -1, 1 }) do
			decor(part("SpiderEye", Vector3.new(0.26, 0.26, 0.1) * s, head.CFrame * CFrame.new(side * (0.22 + i % 2 * 0.36) * s, (0.32 - math.floor(i / 2) * 0.32) * s, -0.66 * s), EYE, Enum.Material.Neon, m))
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		decor(part("SpiderFang", Vector3.new(0.3, 0.8, 0.3) * s, head.CFrame * CFrame.new(side * 0.35 * s, -0.8 * s, -0.5 * s), BONE, nil, m))
	end
	for k = 0, 3 do
		local yaw = math.rad(-55 + k * 36)
		for _, side in ipairs({ -1, 1 }) do
			local out = Vector3.new(side * math.cos(yaw), 0, math.sin(yaw))
			local rootP = (cf * CFrame.new(side * 1.0 * s, 1.6 * s, 0)).Position
			local knee = rootP + cf:VectorToWorldSpace(out * 2.2 * s + Vector3.new(0, 1.4 * s, 0))
			local foot = rootP + cf:VectorToWorldSpace(out * 4.2 * s + Vector3.new(0, (if opts.hanging then -0.4 else -1.6) * s, 0))
			decor(beam("SpiderLeg", rootP, knee, 0.42 * s, col, m))
			decor(beam("SpiderLeg", knee, foot, 0.34 * s, col, m))
		end
	end
	m.PrimaryPart = body
	if s < 1.5 then
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				decor(p).CastShadow = false
			end
		end
	end
	return m
end
-- a spider on a thread from the vault: it drops and climbs back (AmbientDangle)
local function danglingSpider(x, z, len, parent)
	local c = colAt(x, z)
	if not c or not c.ceil or c.chimney or not c.open then
		return
	end
	local top = c.ceil
	local m = model("DanglingSpider", parent or props)
	local thread = decor(beam("Thread", V(x, top, z), V(x, top - len, z), 0.1, THREAD, m))
	thread.Transparency = 0.2
	thread.CastShadow = false
	local sp = spiderModel(at(x, top - len - 0.6, z) * CFrame.Angles(math.pi / 2, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.3, 0.45), m, { hanging = true, cave = rng:NextNumber() < 0.4 })
	for _, p in ipairs(sp:GetChildren()) do
		p.Parent = m
	end
	sp:Destroy()
	tagMotion(m, "AmbientDangle", { Amplitude = math.max(1, math.min(len - 2, rng:NextNumber(3, 9))), Period = rng:NextNumber(5, 11) })
end
-- a spider crawling round a small circle on the floor (AmbientCrawl)
local function crawlingSpider(x, z, s, radius, parent, cave)
	if not flatAround(x, z, radius + 3) then
		return nil
	end
	local m = spiderModel(at(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s, parent, { cave = cave })
	tagMotion(m, "AmbientCrawl", { Radius = radius, Speed = rng:NextNumber(0.25, 0.5) * (if rng:NextNumber() < 0.5 then -1 else 1) })
	return m
end
-- a cocoon: a wrapped prisoner, the silk bound with darker strands; sometimes a hand or a pickaxe sticks out
local function cocoon(cf, len, parent)
	local f = parent or props
	local c = blob("Cocoon", Vector3.new(len * 0.42, len, len * 0.42), cf, SILK, f)
	for k = -1, 1 do
		decor(blob("CocoonBand", Vector3.new(len * 0.45, 0.35, len * 0.45), cf * CFrame.new(0, k * len * 0.24, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), SILK:Lerp(Color3.new(0.5, 0.48, 0.42), 0.35), f))
	end
	local roll = rng:NextNumber()
	if roll < 0.22 then
		decor(part("CocoonHand", Vector3.new(0.5, 1.2, 0.5), cf * CFrame.new(len * 0.2, -len * 0.05, -len * 0.06) * CFrame.Angles(0, 0, -0.9), Color3.fromRGB(196, 150, 120), nil, f))
	elseif roll < 0.34 then
		decor(part("CocoonPick", Vector3.new(0.3, 2.6, 0.3), cf * CFrame.new(0, len * 0.25, -len * 0.2) * CFrame.Angles(0.8, 0, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, f))
		decor(part("CocoonPickHead", Vector3.new(2, 0.35, 0.35), cf * CFrame.new(0, len * 0.25 + 1, -len * 0.2 - 0.9), Color3.fromRGB(80, 210, 220), nil, f))
	end
	return c
end
-- a cocoon hanging on a strand from the vault, swaying round the strand's top (AmbientSway)
local function hangingCocoon(x, z, len, size, parent)
	local c = colAt(x, z)
	if not c or not c.ceil or c.chimney or not c.open then
		return
	end
	local top = c.ceil
	local m = model("HangingCocoon", parent or props)
	decor(beam("Strand", V(x, top, z), V(x, top - len, z), 0.16, THREAD, m)).Transparency = 0.2
	cocoon(at(x, top - len - size / 2, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12)), size, m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			decor(p)
		end
	end
	m.PrimaryPart = m:FindFirstChild("Strand")
	-- the pivot is the strand's centre: the top is len/2 above it
	tagMotion(m, "AmbientSway", { TopOffset = len / 2, Amplitude = rng:NextNumber(0.04, 0.09), Period = rng:NextNumber(4, 8) })
end
-- a cluster of egg sacs; some glow green from inside (pulsing), some are hatched
local glowLights = 0
local function eggs(x, y, z, n, parent, glowing)
	local m = model("EggSacs", parent or props)
	local any = false
	for _ = 1, n do
		local s = rng:NextNumber(1.4, 3)
		local p = V(x + rng:NextNumber(-2.4, 2.4), y + s / 2 + rng:NextNumber(0, 1.2), z + rng:NextNumber(-2.4, 2.4))
		if rng:NextNumber() < 0.15 then
			decor(blob("EggShell", Vector3.new(s, s * 0.5, s), CFrame.new(p.X, y + s * 0.25, p.Z), EGG, m)).Transparency = 0.1
			decor(blob("EggShell", Vector3.new(s * 0.9, s * 0.45, s * 0.9), CFrame.new(p.X + s * 0.6, y + s * 0.2, p.Z + 0.4) * CFrame.Angles(2.6, 0, 0.4), EGG, m)).Transparency = 0.1
		else
			decor(blob("EggSac", Vector3.new(s, s * 1.15, s), CFrame.new(p), EGG, m)).Transparency = 0.15
			if glowing and rng:NextNumber() < 0.5 then
				any = true
				local core = decor(blob("Glow", Vector3.new(s * 0.55, s * 0.6, s * 0.55), CFrame.new(p), GLOW, m, Enum.Material.Neon))
				core.Transparency = 0.3
				if glowLights < 26 and rng:NextNumber() < 0.3 then
					glowLights += 1
					light(core, 18, 1, GLOW)
				end
			end
		end
	end
	if any then
		tagMotion(m, "AmbientPulse", { Period = rng:NextNumber(2, 4) })
	end
	return m
end
local function lantern(cfTop, lit, parent, chain)
	local f = parent or props
	chain = chain or 1.4
	decor(part("LanternChain", Vector3.new(0.2, chain, 0.2), cfTop * CFrame.new(0, -chain / 2, 0), IRON, Enum.Material.Metal, f))
	local c = cfTop * CFrame.new(0, -chain, 0)
	part("LanternCap", Vector3.new(1.3, 0.3, 1.3), c * CFrame.new(0, -0.15, 0), IRON, Enum.Material.Metal, f)
	local glass = part("Lantern", Vector3.new(1, 1.2, 1), c * CFrame.new(0, -0.9, 0), Color3.fromRGB(255, 176, 80), Enum.Material.Neon, f)
	glass.Transparency = 0.1
	part("LanternBase", Vector3.new(1.3, 0.3, 1.3), c * CFrame.new(0, -1.65, 0), IRON, Enum.Material.Metal, f)
	if lit then
		light(glass, 30, 1.4, Color3.fromRGB(255, 170, 90))
	end
	return glass
end
-- a Minecraft wall torch: a stick leaning out of the wall, a flame on top
local function torch(cf, parent, lit)
	local f = parent or props
	local stick = decor(part("TorchStick", Vector3.new(0.4, 2, 0.4), cf * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, 1, 0), Color3.fromRGB(120, 86, 50), Enum.Material.Wood, f))
	local flame = decor(part("TorchFlame", Vector3.new(0.5, 0.6, 0.5), stick.CFrame * CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 200, 70), Enum.Material.Neon, f))
	emitter(flame, {
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2),
		Rate = 6,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
	})
	if lit then
		light(flame, 22, 1.2, Color3.fromRGB(255, 180, 90))
	end
	return flame
end
local function crate(cf, s, parent)
	return textured(part("Crate", Vector3.new(s, s, s), cf, nil, nil, parent or props), "px_dark_oak_planks", Color3.fromRGB(200, 180, 160))
end
local function barrel(x, z, parent)
	local f = parent or props
	local y = floorAt(x, z)
	textured(part("Barrel", Vector3.new(2.6, 3.2, 2.6), at(x, y + 1.6, z), nil, nil, f), "px_spruce_planks", Color3.fromRGB(200, 170, 140))
	for _, hy in ipairs({ 0.6, 2.6 }) do
		decor(part("BarrelHoop", Vector3.new(2.7, 0.25, 2.7), at(x, y + hy, z), IRON, Enum.Material.Metal, f))
	end
end
local function bones(x, z, parent)
	local f = parent or props
	local y0 = floorAt(x, z) + 0.2
	decor(part("Skull", Vector3.new(1.2, 1.1, 1.3), at(x, y0 + 0.55, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), BONE, nil, f))
	for _ = 1, rng:NextInteger(2, 4) do
		decor(part("Bone", Vector3.new(0.35, 0.35, rng:NextNumber(1.6, 2.8)), at(x + rng:NextNumber(-1.8, 1.8), y0 + 0.2, z + rng:NextNumber(-1.8, 1.8)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), BONE, nil, f))
	end
	if rng:NextNumber() < 0.3 then
		decor(part("RustyHelmet", Vector3.new(1.5, 1, 1.6), at(x + 1.4, y0 + 0.5, z - 0.6) * CFrame.Angles(0.3, 0.5, 0.2), RUST, Enum.Material.Metal, f))
	end
end
local function zoneSign(x, z, text, yaw)
	textured(part("SignPost", Vector3.new(0.8, 5, 0.8), at(x, 2.5, z), nil, nil, props), "px_dark_oak_log")
	local board = textured(part("ZoneSign", Vector3.new(8, 1.8, 0.4), at(x, 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_dark_oak_planks")
	boardText(board, text)
end
-- a Minecraft abandoned mineshaft support: two dark oak posts, a plank cap, knee braces; cobwebs under it
local function frame(cf, halfW, h, parent, lit)
	local f = parent or props
	for _, s in ipairs({ -1, 1 }) do
		textured(part("FramePost", Vector3.new(1.6, h, 1.6), cf * CFrame.new(s * halfW, h / 2, 0), nil, nil, f), "px_dark_oak_log")
		if rng:NextNumber() < 0.6 then
			local p = (cf * CFrame.new(s * (halfW - 2.4), h - 2, 0)).Position
			cobweb(p.X - BX, p.Y, p.Z - BZ, webs, true)
		end
		if rng:NextNumber() < 0.3 then
			torch(cf * CFrame.new(s * (halfW - 0.4), h * 0.55, -0.9), f, false)
		end
		local a = (cf * CFrame.new(s * halfW, h - 3, 0)).Position
		local b = (cf * CFrame.new(s * (halfW - 3), h, 0)).Position
		textured(beam("FrameBrace", a, b, 0.9, nil, f), "px_dark_oak_planks")
	end
	textured(part("FrameCap", Vector3.new(halfW * 2 + 2.4, 1.6, 2), cf * CFrame.new(0, h + 0.8, 0), nil, nil, f), "px_dark_oak_planks")
	if lit ~= nil then
		lantern(cf * CFrame.new(0, h, -1.4), lit, f, 2)
	end
end
local function rails(a, b, parent)
	local f = parent or props
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b)
	for _, s in ipairs({ -1.2, 1.2 }) do
		decor(part("Rail", Vector3.new(0.3, 0.3, len), cf * CFrame.new(s, 0.15, -len / 2), Color3.fromRGB(110, 106, 112), Enum.Material.Metal, f))
	end
	for t = 1, len - 1, 2.2 do
		decor(textured(part("Sleeper", Vector3.new(3.6, 0.2, 0.8), cf * CFrame.new(0, 0.05, -t), nil, nil, f), "px_dark_oak_planks"))
	end
end
local function minecart(cf, parent, tipped, chest)
	local f = parent or props
	local base = if tipped then cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(100)) else cf * CFrame.new(0, 1.3, 0)
	part("CartFloor", Vector3.new(3.2, 0.3, 4.2), base * CFrame.new(0, -0.8, 0), IRON, Enum.Material.Metal, f)
	for _, w in ipairs({ { 0, 0, -2, 3.2, 1.8, 0.3 }, { 0, 0, 2, 3.2, 1.8, 0.3 }, { -1.6, 0, 0, 0.3, 1.8, 4.2 }, { 1.6, 0, 0, 0.3, 1.8, 4.2 } }) do
		part("CartSide", Vector3.new(w[4], w[5], w[6]), base * CFrame.new(w[1], w[2], w[3]), Color3.fromRGB(96, 92, 100):Lerp(RUST, 0.25), Enum.Material.Metal, f)
	end
	for _, s in ipairs({ { -1.2, -1.4 }, { 1.2, -1.4 }, { -1.2, 1.4 }, { 1.2, 1.4 } }) do
		decor(part("CartWheel", Vector3.new(0.4, 1, 1), base * CFrame.new(s[1] * 1.45, -1, s[2]), Color3.fromRGB(40, 38, 42), Enum.Material.Metal, f))
	end
	if chest then
		textured(part("CartChest", Vector3.new(2.8, 2.4, 3.6), base * CFrame.new(0, 0.6, 0), nil, nil, f), "px_spruce_planks", Color3.fromRGB(230, 170, 100))
		decor(part("ChestLatch", Vector3.new(0.5, 0.7, 0.2), base * CFrame.new(0, 0.8, -1.85), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, f))
	elseif not tipped then
		for _ = 1, 3 do
			textured(part("CartLoad", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(rng:NextNumber(-0.7, 0.7), 0.4, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), nil, nil, f), "px_white_wool")
		end
	end
end
-- a Minecraft monster spawner: a dark iron cage, a little cave spider spinning inside, flames; mossy cobble and
-- cobwebs round it like a dungeon, a chest
local function spawner(x, z, parent, withChest)
	local f = parent or props
	local y = floorAt(x, z)
	local cage = folder("Spawner", f)
	local cf = at(x, y + 2, z)
	local bar = Color3.fromRGB(30, 34, 44)
	for _, e in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		part("CageBar", Vector3.new(0.4, 4, 0.4), cf * CFrame.new(e[1] * 1.8, 0, e[2] * 1.8), bar, Enum.Material.Metal, cage)
		part("CageBar", Vector3.new(4, 0.4, 0.4), cf * CFrame.new(0, e[1] * 1.8, e[2] * 1.8), bar, Enum.Material.Metal, cage)
		part("CageBar", Vector3.new(0.4, 0.4, 4), cf * CFrame.new(e[1] * 1.8, e[2] * 1.8, 0), bar, Enum.Material.Metal, cage)
	end
	for k = -1, 1, 2 do
		for _, off in ipairs({ CFrame.new(k * 0.6, 0, 1.8), CFrame.new(k * 0.6, 0, -1.8), CFrame.new(1.8, 0, k * 0.6), CFrame.new(-1.8, 0, k * 0.6) }) do
			part("CageBar", Vector3.new(0.25, 3.6, 0.25), cf * off, bar, Enum.Material.Metal, cage)
		end
	end
	local fire = decor(part("SpawnerFire", Vector3.new(3, 0.4, 3), cf * CFrame.new(0, -1.6, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, cage))
	fire.Transparency = 0.6
	emitter(fire, {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Rate = 14,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(30, 30),
	})
	light(fire, 22, 1.2, Color3.fromRGB(255, 140, 60))
	local inner = spiderModel(cf * CFrame.new(0, -1.2, 0.3), 0.32, cage, { cave = true })
	tagMotion(inner, "AmbientSpin", { Speed = 2.2 })
	for _ = 1, 8 do
		local px, pz = x + rng:NextInteger(-3, 3) * B, z + rng:NextInteger(-3, 3) * B
		if isOpen(px, pz) then
			textured(decor(part("DungeonFloor", Vector3.new(B, 0.2, B), at(px, 0.1, pz), nil, nil, f)), "px_mossy_cobblestone", STONE)
		end
	end
	for _ = 1, 8 do
		local px, pz = x + rng:NextInteger(-3, 3) * B, z + rng:NextInteger(-3, 3) * B
		if isOpen(px, pz) and (math.abs(px - x) > 4 or math.abs(pz - z) > 4) then
			cobweb(px, 2 + rng:NextInteger(0, 1) * B, pz, webs)
		end
	end
	if withChest then
		local chest = textured(part("DungeonChest", Vector3.new(3.4, 3, 3.4), at(x + 8, y + 1.5, z + 2) * CFrame.Angles(0, 0.2, 0), nil, nil, f), "px_spruce_planks", Color3.fromRGB(230, 170, 100))
		decor(part("ChestLatch", Vector3.new(0.6, 0.8, 0.2), chest.CFrame * CFrame.new(0, 0.4, -1.75), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, f))
	end
	return cage
end
-- cave vines with glow berries hanging from the vault
local function caveVine(x, z, len, parent)
	local c = colAt(x, z)
	if not c or not c.ceil or c.chimney or not c.open then
		return
	end
	local f = parent or props
	local y = c.ceil
	local seg = 0
	while seg < len do
		local l = math.min(2, len - seg)
		local p = decor(part("CaveVine", Vector3.new(0.5, l, 0.5), at(x + math.sin(seg) * 0.3, y - seg - l / 2, z + math.cos(seg * 1.3) * 0.3), Color3.fromRGB(70, 140, 50), Enum.Material.Grass, f))
		p.CastShadow = false
		if rng:NextNumber() < 0.45 then
			decor(part("GlowBerry", Vector3.new(0.6, 0.6, 0.6), p.CFrame * CFrame.new(0.4, 0, 0), Color3.fromRGB(255, 160, 40), Enum.Material.Neon, f)).CastShadow = false
		end
		seg += l
	end
end
-- tapered dripstone hanging from the vault; water drips from some tips
local function dripstone(x, z, parent, withDrip)
	local c = colAt(x, z)
	if not c or not c.ceil or c.chimney or c.hole or not c.open then
		return
	end
	local f = parent or props
	local y = c.ceil
	local w = rng:NextInteger(2, 3) * 1.5
	local tint = if rng:NextNumber() < 0.5 then DEEP else Color3.fromRGB(186, 156, 132)
	while w >= 0.8 do
		local len = rng:NextNumber(2, 4.5)
		textured(part("Dripstone", Vector3.new(w, len, w), at(x, y - len / 2, z), nil, nil, f), "px_stone", tint)
		y -= len
		w -= rng:NextNumber(0.7, 1.3)
	end
	if withDrip then
		local tip = decor(part("DripTip", Vector3.new(0.2, 0.2, 0.2), at(x, y, z), THREAD, nil, f))
		tip.Transparency = 1
		emitter(tip, {
			Color = ColorSequence.new(Color3.fromRGB(150, 190, 255)),
			LightEmission = 0.4,
			Size = NumberSequence.new(0.15),
			Rate = 0.6,
			Lifetime = NumberRange.new(2.5, 3),
			Speed = NumberRange.new(0, 0),
			Acceleration = Vector3.new(0, -20, 0),
		})
	end
end

-- ================================================================ the rock dressed: lichen, corner webs, vault life
local dress = folder("CaveDetail")
do
	local n = 0
	for _, s in ipairs(lichenSpots) do
		if rng:NextNumber() < 0.55 and n < 520 then
			n += 1
			local nrm = s[2]
			local sz = rng:NextNumber(1.6, 3.4)
			local size = if math.abs(nrm.Y) > 0.5 then Vector3.new(sz, 0.1, sz * rng:NextNumber(0.6, 1.2))
				elseif math.abs(nrm.X) > 0.5 then Vector3.new(0.1, sz, sz * rng:NextNumber(0.6, 1.2))
				else Vector3.new(sz * rng:NextNumber(0.6, 1.2), sz, 0.1)
			local jitter = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)) * (Vector3.one - Vector3.new(math.abs(nrm.X), math.abs(nrm.Y), math.abs(nrm.Z)))
			local p = decor(part("GlowLichen", size, CFrame.new(s[1] + jitter), LICHEN, Enum.Material.Neon, dress))
			p.Transparency = rng:NextNumber(0.25, 0.5)
			p.CastShadow = false
		end
	end
	-- cobwebs in the corners of the walls and the vaults, and at the foot of the walls (where they trap you)
	local c = 0
	for _, s in ipairs(cornerSpots) do
		if rng:NextNumber() < 0.16 and c < 330 then
			c += 1
			cobweb(s[1], s[2], s[3], webs)
			-- a second web hanging under it sometimes, as Minecraft webs clump
			if rng:NextNumber() < 0.3 then
				cobweb(s[1], s[2] - B, s[3], webs)
			end
		end
	end
	local f = 0
	for _, s in ipairs(floorCorners) do
		local col = colAt(s[1], s[3])
		local nearSpawn = math.abs(s[1] - PIT.x) < 40 and s[3] > PIT.z + PIT.hole
		if not nearSpawn and rng:NextNumber() < 0.22 and f < 110 and col and not col.hole then
			f += 1
			cobweb(s[1], s[2], s[3], webs)
		end
	end
end
task.wait()
local vault = folder("VaultDetail")
do
	local function randomOpen(tries, test)
		for _ = 1, tries do
			local x, z = rng:NextNumber(-280, 280), rng:NextNumber(-296, 296)
			local col = colAt(x, z)
			if col and col.open and col.ceil and not col.chimney and (not test or test(col, x, z)) then
				return x, z, col
			end
		end
		return nil
	end
	for _ = 1, 190 do
		local x, z = randomOpen(20, function(col)
			return col.ceil > 20
		end)
		if x then
			dripstone(x, z, vault, rng:NextNumber() < 0.35)
		end
	end
	for _ = 1, 110 do
		local x, z, col = randomOpen(20, function(col)
			return col.d > 0.55 and col.ceil > 16
		end)
		if x then
			caveVine(x, z, rng:NextNumber(4, math.min(16, col.ceil - 8)), vault)
		end
	end
	for _ = 1, 64 do
		local x, z, col = randomOpen(20, function(col, x, z)
			return col.ceil > 22 and not inHole(x, z)
		end)
		if x then
			danglingSpider(x, z, rng:NextNumber(8, math.min(26, col.ceil - 10)), vault)
		end
	end
	-- stalagmites (tapered) at the foot of the walls
	for _ = 1, 120 do
		local x, z, col = randomOpen(20, function(col)
			return col.d > 0.82 and not col.hole
		end)
		if x then
			local y = col.floor * B
			local w = rng:NextInteger(2, 3) * 1.5
			while w >= 0.8 do
				local len = rng:NextNumber(1.5, 3.5)
				textured(part("Stalagmite", Vector3.new(w, len, w), at(x, y + len / 2, z), nil, nil, vault), "px_stone", if rng:NextNumber() < 0.5 then DEEP else STONE)
				y += len
				w -= rng:NextNumber(0.7, 1.3)
			end
		end
	end
end
task.wait()

-- ================================================================ moonlight through the chimneys
local shafts = folder("LightShafts")
for _, ch in ipairs(CHIMNEYS) do
	local x, z = X0 + math.floor((ch[1] - X0) / B) * B + B, Z0 + math.floor((ch[2] - Z0) / B) * B + B
	local col = colAt(x - 1, z - 1)
	if col and col.ceil then
		local top = (NL - 1) * B
		local fy = col.floor * B
		local shaft = decor(part("MoonShaft", Vector3.new(7, top - fy, 7), at(x, (top + fy) / 2, z), MOON, Enum.Material.Neon, shafts))
		shaft.Transparency = 0.93
		shaft.CastShadow = false
		local src = decor(part("MoonSource", Vector3.new(1, 1, 1), at(x, col.ceil - 1, z), MOON, nil, shafts))
		src.Transparency = 1
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 50
		spot.Range = 60
		spot.Brightness = 1.6
		spot.Color = MOON
		spot.Shadows = false
		spot.Parent = src
		emitter(src, {
			Color = ColorSequence.new(Color3.fromRGB(220, 235, 255)),
			LightEmission = 0.6,
			Size = NumberSequence.new(0.18),
			Transparency = NumberSequence.new(0.3),
			Rate = 5,
			Lifetime = NumberRange.new(8, 12),
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(12, 12),
		})
		-- a patch of moss and pale flowers where the moon falls
		for _ = 1, 10 do
			local px, pz = x + rng:NextNumber(-6, 6), z + rng:NextNumber(-6, 6)
			if isOpen(px, pz) then
				local fl = decor(part("MoonFlower", Vector3.new(0.5, rng:NextNumber(0.8, 1.6), 0.5), at(px, 0.5, pz), Color3.fromRGB(80, 150, 70), Enum.Material.Grass, shafts))
				decor(part("MoonPetal", Vector3.new(0.9, 0.4, 0.9), fl.CFrame * CFrame.new(0, fl.Size.Y / 2, 0), if rng:NextNumber() < 0.5 then Color3.fromRGB(190, 210, 255) else Color3.fromRGB(240, 240, 255), Enum.Material.Neon, shafts))
			end
		end
	end
end

-- ================================================================ the mineshafts in the passages
local mineshafts = folder("Mineshafts")
for ti, t in ipairs(TUNNELS) do
	local a, b = V(t[1], 0, t[2]), V(t[3], 0, t[4])
	local d = b - a
	local len = d.Magnitude
	local dirv = d.Unit
	local n = 0
	for s = 10, len - 10, 16 do
		local p = a + dirv * s
		local half = t[5] * 0.7
		n += 1
		frame(CFrame.lookAt(p, p + dirv), half, 14, mineshafts, if n % 2 == 0 then (n % 4 == 0) else nil)
	end
	if t.main or ti == 2 or ti == 4 then
		rails(a + dirv * 4, b - dirv * 4, mineshafts)
		minecart(CFrame.lookAt(a + dirv * len * 0.4, b), mineshafts, false, ti == 1)
	end
	-- cobwebs strung across the top of each passage, the way Minecraft mineshafts get choked
	for s = 20, len - 20, 22 do
		local p = a + dirv * s
		for _ = 1, 3 do
			local side = dirv:Cross(Vector3.yAxis) * rng:NextNumber(-t[5] * 0.6, t[5] * 0.6)
			cobweb(p.X + side.X - BX, 16 + rng:NextInteger(0, 1) * B, p.Z + side.Z - BZ, webs)
		end
	end
	if t.deadEnd then
		for _ = 1, 22 do
			local s = rng:NextInteger(1, 3) * B
			local q = b - dirv * rng:NextNumber(0, 18) + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
			textured(part("Rubble", Vector3.new(s, s, s), CFrame.new(q + Vector3.new(0, s / 2 + rng:NextNumber(0, 6), 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, mineshafts), if rng:NextNumber() < 0.5 then "px_cobblestone" else "px_gravel", STONE)
		end
		for _ = 1, 4 do
			local q = b - dirv * rng:NextNumber(10, 24)
			textured(part("BrokenBeam", Vector3.new(1.6, 1.6, rng:NextNumber(8, 14)), CFrame.new(q + Vector3.new(rng:NextNumber(-6, 6), 2, rng:NextNumber(-6, 6))) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), nil, nil, mineshafts), "px_dark_oak_planks")
		end
		minecart(CFrame.lookAt(b - dirv * 30, b), mineshafts, true)
		local bp = b - dirv * 34
		bones(bp.X - BX + 4, bp.Z - BZ, mineshafts)
		for _ = 1, 10 do
			local q = b - dirv * rng:NextNumber(14, 40) + dirv:Cross(Vector3.yAxis) * rng:NextNumber(-8, 8)
			cobweb(q.X - BX, 2 + rng:NextInteger(0, 2) * B, q.Z - BZ, webs)
		end
	end
	task.wait()
end

-- ================================================================ the adit: the mine and the arrival by it
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	textured(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(mx, -h - B / 2, mz), nil, nil, mine), "px_stone", DEEP)
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(mx - w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(mx + w / 2 + B, -h / 2, mz) },
	}) do
		textured(part("PitWall", wall[1], wall[2], nil, nil, mine), "px_stone", DEEP)
	end
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_dark_oak_planks")
	end
	-- mineshaft posts at the corners and along the sides, lanterns, cobwebs under the caps
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local x, z = mx + s[1] * (edge + 3), mz + s[2] * (edge + 3)
		textured(part("PitPost", Vector3.new(2.4, 14, 2.4), at(x, 7, z), nil, nil, mine), "px_dark_oak_log")
		textured(part("PitPostCap", Vector3.new(3.4, 1.2, 3.4), at(x, 14.6, z), nil, nil, mine), "px_dark_oak_planks")
		lantern(at(x - s[1] * 2, 14, z - s[2] * 2), true, mine)
		cobweb(x - s[1] * 3, 12.5, z - s[2] * 3, webs, true)
		torch(at(x, 6, z - s[2] * 1.3) * CFrame.Angles(0, if s[2] > 0 then math.pi else 0, 0), mine, false)
	end
	for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		for k = -1, 1, 2 do
			local along = Vector3.new(side[2], 0, side[1])
			local p = V(mx, 0, mz) + Vector3.new(side[1], 0, side[2]) * (edge + 3) + along * k * 34
			if not (side[2] == 1) then
				local cf = CFrame.lookAt(p, p + Vector3.new(side[1], 0, side[2]))
				frame(cf, 5, 11, mine, nil)
			end
		end
	end
	local anchor = part("MineAnchor_spider_lair", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor.Transparency = 1
	anchor:SetAttribute("LocationId", "spider_lair")
	anchor:SetAttribute("MineId", "spider_lair")
	anchor:SetAttribute("Size", Vector3.new(PIT.size, PIT.depth, PIT.size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, "Шахта", 14)
	local LADDER_W = 4 * B
	for _, side in ipairs({
		{ mx, mz - w / 2, Vector3.new(0, 0, 1) },
		{ mx, mz + w / 2, Vector3.new(0, 0, -1) },
		{ mx - w / 2, mz, Vector3.new(1, 0, 0) },
		{ mx + w / 2, mz, Vector3.new(-1, 0, 0) },
	}) do
		local inward = side[3]
		local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
		local base = Vector3.new(BX + side[1], -h / 2, BZ + side[2])
		for k = 0, LADDER_W / 2 - 1 do
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = Vector3.new(2, h, 2)
			truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-LADDER_W / 2 + 1 + k * 2))
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = mine
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(LADDER_W * along.X + 0.2 * math.abs(inward.X), h, LADDER_W * along.Z + 0.2 * math.abs(inward.Z))
		plate.CFrame = CFrame.new(base + inward * 0.15)
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.Transparency = 1
		plate.Parent = mine
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = if inward.Z > 0 then Enum.NormalId.Back elseif inward.Z < 0 then Enum.NormalId.Front elseif inward.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
	-- the arrival, the buyer at a timber stall beside it
	local spawn = part("LocationSpawn_spider_lair", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + SPAWN_Z), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), nil, nil, mine)
	textured(spawn, "px_dark_oak_planks")
	spawn:SetAttribute("LocationId", "spider_lair")
	CollectionService:AddTag(spawn, "LocationSpawn")
	local sx, sz = PIT.x + 18, SPAWN_Z + 2
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(205, 160, 125)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(60, 90, 140), Color3.fromRGB(60, 50, 40), Color3.fromRGB(60, 50, 40)
	local buyer = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	buyer.Name = "LairBuyer"
	local animate = buyer:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = buyer:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, p in ipairs(buyer:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	buyer.Parent = mine
	buyer:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + PIT.x, 3, BZ + SPAWN_Z)))
	buyer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = buyer:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, "SellPoint")
	sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
	part("Helmet", Vector3.new(2.3, 0.9, 2.3), buyer.Head.CFrame * CFrame.new(0, 0.6, 0), Color3.fromRGB(230, 180, 30), Enum.Material.SmoothPlastic, buyer).CanCollide = false
	decor(part("HelmetLamp", Vector3.new(0.6, 0.5, 0.3), buyer.Head.CFrame * CFrame.new(0, 0.7, -1.2), Color3.fromRGB(255, 230, 160), Enum.Material.Neon, buyer))
	textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, mine), "px_dark_oak_planks")
	textured(part("CounterTop", Vector3.new(2.8, 0.4, 9.4), at(sx, 3.2, sz), nil, nil, mine), "px_spruce_planks")
	for _, dz in ipairs({ -4.4, 4.4 }) do
		for _, dxo in ipairs({ -1.2, 5 }) do
			textured(part("StallPost", Vector3.new(0.8, 9, 0.8), at(sx + dxo, 4.5, sz + dz), nil, nil, mine), "px_dark_oak_log")
		end
	end
	textured(part("StallRoof", Vector3.new(8, 0.8, 10), at(sx + 1.9, 9.4, sz), nil, nil, mine), "px_dark_oak_planks")
	lantern(at(sx + 1.9, 9, sz - 4), true, mine)
	cobweb(sx + 4, 7.5, sz + 3.4, webs, true)
	textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx - 0.3, 4.3, sz - 2.5), nil, nil, mine), "px_white_wool")
	crate(at(sx - 0.3, 4.3, sz + 2.5), 1.8, mine)
	zoneSign(PIT.x - 14, SPAWN_Z + 4, "Паучье логово", math.pi)
	-- rails from the main passage to the mine's rim
	rails(V(0, 0, 34), V(0, 0, PIT.z - PIT.hole - 2), mineshafts)
end
task.wait()

-- ================================================================ the prospectors' camp lost to the spiders (east of the mine)
local camp = folder("Camp")
do
	local tx, tz = 108, 170
	for _, s in ipairs({ -1, 1 }) do
		part("TentCloth", Vector3.new(0.4, 11, 13), at(tx + s * 3.6, 4.2, tz) * CFrame.Angles(0, 0, s * 0.58), Color3.fromRGB(176, 120, 70), Enum.Material.Fabric, camp)
	end
	textured(part("TentPole", Vector3.new(0.6, 0.6, 14), at(tx, 8.8, tz), nil, nil, camp), "px_dark_oak_log")
	cobweb(tx, 6, tz - 6, webs, true)
	cobweb(tx + 2, 2, tz + 6.5, webs, true)
	cocoon(at(tx + 1, 1.2, tz + 2) * CFrame.Angles(0, 0, math.pi / 2), 5, camp)
	local fx, fz = 98, 198
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		textured(part("FireStone", Vector3.new(1.4, 0.9, 1.4), at(fx + math.sin(a) * 2.6, 0.45, fz + math.cos(a) * 2.6), nil, nil, camp), "px_cobblestone", STONE)
	end
	for k = 0, 2 do
		textured(part("Ash", Vector3.new(0.6, 0.6, 3), at(fx, 0.4, fz) * CFrame.Angles(0, k, 0), nil, nil, camp), "px_dark_oak_log", Color3.fromRGB(90, 80, 74))
	end
	local ember = decor(part("Embers", Vector3.new(2, 0.3, 2), at(fx, 0.5, fz), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, camp))
	ember.Transparency = 0.3
	emitter(ember, {
		Color = ColorSequence.new(Color3.fromRGB(255, 150, 60)),
		LightEmission = 1,
		Size = NumberSequence.new(0.12),
		Rate = 4,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(25, 25),
	})
	light(ember, 18, 0.9, Color3.fromRGB(255, 120, 50))
	barrel(116, 186, camp)
	barrel(118, 190, camp)
	crate(at(94, 1.25, 160), 2.5, camp)
	crate(at(94, 3.75, 160) * CFrame.Angles(0, 0.4, 0), 2.5, camp)
	crate(at(96.5, 1.25, 163) * CFrame.Angles(0, 0.2, 0), 2.5, camp)
	cobweb(95, 6, 161, webs, true)
	bones(104, 206, camp)
	bones(122, 160, camp)
	rails(V(88, 0, 148), V(88, 0, 214), camp)
	minecart(at(88, 0, 180), camp, false, true)
	frame(at(88, 0, 210), 4, 10, camp, true)
	eggs(-118, 0, 236, 6, camp, true)
	eggs(-60, 0, 248, 5, camp, false)
end
spawner(-98, 176, props, true)
task.wait()

-- ================================================================ the Clutch (west): egg sacs, hatchlings, moss
local clutch = folder("Clutch")
do
	local cx, cz = CLUTCH.x, CLUTCH.z
	spawner(cx + 6, cz + 4, clutch, false)
	for _ = 1, 30 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(12, CLUTCH.r - 8)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.open then
			eggs(x, col.floor * B, z, rng:NextInteger(3, 7), clutch, true)
		end
	end
	for _ = 1, 16 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(6, CLUTCH.r - 14)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.open and col.ceil and not col.chimney then
			local len = rng:NextNumber(8, 18)
			decor(beam("Strand", V(x, col.ceil, z), V(x, col.ceil - len, z), 0.12, THREAD, clutch)).Transparency = 0.25
			eggs(x, col.ceil - len - 3.5, z, 3, clutch, true)
		end
	end
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, CLUTCH.r - 14)
		crawlingSpider(cx + math.sin(a) * r, cz + math.cos(a) * r, rng:NextNumber(0.35, 0.55), rng:NextNumber(4, 7), clutch, rng:NextNumber() < 0.5)
	end
	minecart(at(cx + 30, 0, cz + 28) * CFrame.Angles(0, 0.6, 0), clutch, true)
	for _ = 1, 5 do
		textured(part("SpilledWool", Vector3.new(2, 2, 2), at(cx + 30 + rng:NextNumber(-5, 5), 1, cz + 33 + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, clutch), "px_white_wool")
	end
	-- mushrooms: Minecraft red and brown ones, and glowing teal cave caps
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(CLUTCH.r * 0.5, CLUTCH.r - 3)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.open then
			local y = col.floor * B
			local kind = rng:NextInteger(1, 3)
			local h = if kind == 3 then rng:NextNumber(1.6, 3.2) else rng:NextNumber(0.8, 1.4)
			decor(part("MushroomStem", Vector3.new(0.6, h, 0.6), at(x, y + h / 2, z), Color3.fromRGB(230, 226, 210), nil, clutch))
			if kind == 1 then
				local cap = decor(part("MushroomCap", Vector3.new(1.8, 0.8, 1.8), at(x, y + h + 0.3, z), Color3.fromRGB(210, 30, 30), nil, clutch))
				for _ = 1, 3 do
					decor(part("CapSpot", Vector3.new(0.35, 0.1, 0.35), cap.CFrame * CFrame.new(rng:NextNumber(-0.6, 0.6), 0.42, rng:NextNumber(-0.6, 0.6)), Color3.new(1, 1, 1), nil, clutch))
				end
			elseif kind == 2 then
				decor(part("MushroomCap", Vector3.new(2, 0.5, 2), at(x, y + h + 0.2, z), Color3.fromRGB(150, 104, 70), nil, clutch))
			else
				local cap = decor(part("MushroomCap", Vector3.new(2.6, 0.7, 2.6), at(x, y + h + 0.3, z), Color3.fromRGB(70, 240, 210), Enum.Material.Neon, clutch))
				cap.Transparency = 0.15
			end
		end
	end
	-- a giant web on the back wall
	giantWeb(CFrame.lookAt(V(cx - 34, 24, cz), V(cx + 10, 24, cz)), 16, 8, 3, webs)
	zoneSign(-112, 76, "Кладка", math.rad(-50))
end
task.wait()

-- ================================================================ the Cocoon graveyard (east): wrapped prisoners, bones, rusty gear
local graveyard = folder("CocoonGraveyard")
do
	local cx, cz = COCOONS.x, COCOONS.z
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, COCOONS.r - 12)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.ceil and col.ceil > 20 then
			hangingCocoon(x, z, rng:NextNumber(4, math.min(18, col.ceil - 14)), rng:NextNumber(5, 6.5), graveyard)
		end
	end
	for _ = 1, 12 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(6, COCOONS.r - 8)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.open then
			cocoon(at(x, col.floor * B + 1.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.pi / 2), rng:NextNumber(4.5, 6), graveyard)
		end
	end
	for _ = 1, 20 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, COCOONS.r - 6)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local col = colAt(x, z)
		if col and col.open then
			bones(x, z, graveyard)
		end
	end
	minecart(at(cx - 26, 0, cz - 22) * CFrame.Angles(0, -0.5, 0), graveyard, false, true)
	for _ = 1, 8 do
		local x, z = cx + rng:NextNumber(-34, 34), cz + rng:NextNumber(-34, 34)
		if isOpen(x, z) then
			local tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
			decor(part("StuckPickHandle", Vector3.new(0.35, 3.2, 0.35), at(x, 1.4, z) * tilt, Color3.fromRGB(110, 80, 50), Enum.Material.Wood, graveyard))
			decor(part("StuckPickHead", Vector3.new(2.4, 0.4, 0.4), at(x, 1.4, z) * tilt * CFrame.new(0, 1.5, 0), if rng:NextNumber() < 0.5 then RUST else Color3.fromRGB(80, 210, 220), Enum.Material.Metal, graveyard))
		end
	end
	spawner(cx + 18, cz - 28, graveyard, true)
	for _ = 1, 6 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, COCOONS.r - 14)
		crawlingSpider(cx + math.sin(a) * r, cz + math.cos(a) * r, rng:NextNumber(0.4, 0.6), rng:NextNumber(4, 7), graveyard, false)
	end
	giantWeb(CFrame.lookAt(V(cx + 36, 24, cz), V(cx - 10, 24, cz)), 16, 8, 3, webs)
	zoneSign(112, 76, "Кладбище коконов", math.rad(50))
end
task.wait()

-- ================================================================ the Queen's nest (the arena)
local arena = folder("QueensNest")
do
	local ax, az, R = ARENA.x, ARENA.z, ARENA.r
	-- six stone columns from floor to vault, wrapped in silk (the charge stuns on them: names Pillar*)
	local tops = {}
	for k = 0, 5 do
		local a = (k + 0.5) / 6 * math.pi * 2
		local px, pz = ax + math.sin(a) * 50, az + math.cos(a) * 50
		local top = ceilAt(px, pz) + B
		local cf = at(px, 0, pz) * CFrame.Angles(0, a, 0)
		textured(part("PillarBase", Vector3.new(11, 3, 11), cf * CFrame.new(0, 1.5, 0), nil, nil, arena), "px_mossy_cobblestone", STONE)
		textured(part("PillarPlinth", Vector3.new(9, 2, 9), cf * CFrame.new(0, 4, 0), nil, nil, arena), "px_cobblestone", DEEP)
		textured(part("Pillar", Vector3.new(7, top, 7), cf * CFrame.new(0, top / 2, 0), nil, nil, arena), "px_stone", STONE)
		for y = 14, top - 12, 16 do
			textured(part("PillarRing", Vector3.new(8, 1.6, 8), cf * CFrame.new(0, y, 0), nil, nil, arena), "px_cobblestone", DEEP)
		end
		textured(part("PillarFlare", Vector3.new(11, 6, 11), cf * CFrame.new(0, top - 6, 0), nil, nil, arena), "px_stone", VAULT)
		-- silk wrapping in loose bands, cobwebs clinging to the column
		for y = 8, top - 12, 7 do
			local band = decor(part("SilkWrap", Vector3.new(7.5, rng:NextNumber(1, 2.4), 7.5), cf * CFrame.new(0, y, 0) * CFrame.Angles(rng:NextNumber(-0.14, 0.14), rng:NextNumber(0, 1), rng:NextNumber(-0.14, 0.14)), SILK, Enum.Material.Fabric, arena))
			band.Transparency = 0.3
		end
		for y = 18, top - 14, 10 do
			local off = cf * CFrame.new(rng:NextInteger(-1, 1) * 5.5, y, if rng:NextNumber() < 0.5 then 5.5 else -5.5)
			cobweb(off.X - BX, off.Y, off.Z - BZ, webs, true)
		end
		eggs(px + math.sin(a) * 7, 0, pz + math.cos(a) * 7, 4, arena, true)
		torch(cf * CFrame.new(0, 7, -3.6) * CFrame.Angles(0, math.pi, 0), arena, k % 2 == 0)
		table.insert(tops, V(px, 34, pz))
	end
	-- giant webs of cobwebs strung high between neighbouring columns (every other gap: the ways stay clear)
	for k = 1, 6, 2 do
		local a, b = tops[k], tops[k % 6 + 1]
		local mid = (a + b) / 2
		giantWeb(CFrame.lookAt(mid, mid + (b - a):Cross(Vector3.yAxis)), 18, 8, 3, webs)
	end
	-- the funnel web in the vault: rings of cobwebs closing up into the crown
	local crown = ceilAt(ax, az)
	for k = 0, 3 do
		local r = 30 - k * 7
		local y = crown - 8 - (3 - k) * 5
		for a = 0, math.pi * 2, B * 0.9 / r do
			cobweb(ax + math.sin(a) * r, y, az + math.cos(a) * r, webs, true)
		end
	end
	-- the nest at the back (north): a mound of silk and eggs, wrapped victims, bones
	local nx, nz = ax, az - 60
	for k = 0, 3 do
		local s = 26 - k * 6
		textured(part("NestMound", Vector3.new(s, 2.4, s * 0.8), at(nx, 1.2 + k * 2.4, nz) * CFrame.Angles(0, k * 0.3, 0), nil, nil, arena), "px_white_wool", SILK)
	end
	eggs(nx, 9.6, nz, 9, arena, true)
	eggs(nx - 9, 0, nz + 4, 6, arena, true)
	eggs(nx + 10, 0, nz + 3, 6, arena, true)
	for _, d in ipairs({ { -14, -2, 0.4 }, { 14, -4, -0.3 }, { -6, -9, 1.2 }, { 7, -10, -1 } }) do
		cocoon(at(nx + d[1], 3.2, nz + d[2]) * CFrame.Angles(0.3, d[3], 0.2), 6, arena)
	end
	for _ = 1, 8 do
		bones(nx + rng:NextNumber(-20, 20), nz + rng:NextNumber(-6, 14), arena)
	end
	giantWeb(CFrame.lookAt(V(nx, 22, nz - 12), V(nx, 22, nz + 10)), 20, 10, 4, webs)
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(20, R - 12)
		hangingCocoon(ax + math.sin(a) * r, az + math.cos(a) * r, rng:NextNumber(6, 20), rng:NextNumber(5, 6.5), arena)
	end
	-- the gate from the main passage: two curved fangs over the way in, a sign, two great spider statues
	local gz = az + R - 2
	for _, s in ipairs({ -1, 1 }) do
		local prevP = V(ax + s * 15, 0, gz)
		for k = 1, 6 do
			local t = k / 6
			local p = V(ax + s * (15 - 11 * t ^ 1.6), 24 * math.sin(t * math.pi / 2) + 0.5, gz)
			beam("GateFang", prevP, p, 3.2 - t * 1.8, BONE, arena)
			prevP = p
		end
		local statue = spiderModel(at(ax + s * 24, 1, gz - 12) * CFrame.Angles(0, if s < 0 then 0.5 else -0.5, 0), 2.3, arena)
		for _, p in ipairs(statue:GetChildren()) do
			if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
				textured(p, "px_cobblestone", DEEP)
			end
		end
		textured(part("StatuePlinth", Vector3.new(14, 1, 14), at(ax + s * 24, 0.5, gz - 11), nil, nil, arena), "px_cobblestone", STONE)
	end
	local gateSign = textured(decor(part("ArenaSign", Vector3.new(14, 2, 0.3), at(ax, 27.5, gz), nil, nil, arena)), "px_dark_oak_planks")
	boardText(gateSign, "Гнездо матки", Color3.fromRGB(230, 60, 60), { Enum.NormalId.Back, Enum.NormalId.Front })
	local nestGlow = decor(part("NestGlow", Vector3.new(1, 1, 1), at(nx, 14, nz), GLOW, nil, arena))
	nestGlow.Transparency = 1
	light(nestGlow, 60, 1.3, Color3.fromRGB(170, 255, 150))
	local dust = decor(part("ArenaDust", Vector3.new(120, 1, 120), at(ax, crown - 6, az), THREAD, nil, arena))
	dust.Transparency = 1
	emitter(dust, {
		Color = ColorSequence.new(Color3.fromRGB(230, 230, 230)),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.18),
		Transparency = NumberSequence.new(0.4),
		Rate = 14,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(20, 20),
	})
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, 1.2, az), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "spider_queen")
	bossSpawn:SetAttribute("ArenaRadius", R - 8)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
	zoneSign(-12, -104, "Гнездо матки", 0)
end
task.wait()

-- ================================================================ spiders about the adit and the passages
for _, p in ipairs({ { -60, 200 }, { 104, 120 }, { -110, 130 }, { 30, -40 }, { -24, -90 }, { 120, 50 } }) do
	crawlingSpider(p[1], p[2], rng:NextNumber(0.5, 0.8), rng:NextNumber(5, 8), props, rng:NextNumber() < 0.4)
end
-- big sleeping spiders by the chamber walls (off the ways)
for _, p in ipairs({ { -70, 250, 1.6 }, { 118, 230, 1.3 }, { -214, 10, 1.2 }, { 214, -50, 1.4 } }) do
	if isOpen(p[1], p[2]) then
		spiderModel(at(p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), p[3], props)
	end
end

-- ================================================================ the murk: dark, violet, but the mine and the ways read
-- [клиент: окутано мраком] — a saturated dark: violet ambient, green glow of the eggs, orange lanterns, moonlight
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(part("LairAir", Vector3.new(580, 150, 620), at(0, 46, -10), nil, nil, air))
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(150, 122, 186))
volume:SetAttribute("Exposure", 0.55)
volume:SetAttribute("Haze", 0.14)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(70, 44, 100))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(36, 60, 54))
CollectionService:AddTag(volume, "IndoorLighting")
local motes = decor(part("Motes", Vector3.new(220, 1, 220), at(ENTRY.x, 44, ENTRY.z), THREAD, nil, air))
motes.Transparency = 1
emitter(motes, {
	Color = ColorSequence.new(Color3.fromRGB(220, 210, 240)),
	LightEmission = 0.3,
	Size = NumberSequence.new(0.15),
	Transparency = NumberSequence.new(0.5),
	Rate = 12,
	Lifetime = NumberRange.new(10, 16),
	Speed = NumberRange.new(0.5, 1.5),
	EmissionDirection = Enum.NormalId.Bottom,
	SpreadAngle = Vector2.new(40, 40),
})

-- lift the location to its own height
do
	local up = Vector3.new(0, BY, 0)
	for i, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame += up
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
end

local total = #root:GetDescendants()
local nwebs = #CollectionService:GetTagged("Cobweb")
print(("[build-spider-lair] built: %d instances, %d shell runs, %d webs (%d tagged)"):format(total, count, #webs:GetChildren(), nwebs))
return ("built %d instances, %d shell runs, %d webs"):format(total, count, #webs:GetChildren())
