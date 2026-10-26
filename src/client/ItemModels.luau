--!strict
-- 3D "extruded sprite" item models, the way Minecraft renders held items: every item icon was
-- reduced to a 16×16 pixel grid (scripts/sprite-to-voxels.ps1 → assets/icons/voxels.json →
-- Config/itemvoxels.json) and each same-colour rectangle becomes a thin Part. Models are built once
-- per item id and cloned for every character that holds the item.
--
-- Model frame: the sprite lies in the Y–Z plane of the root part (thickness along X, like the old
-- decal plane): image up = +Y, image right = +Z. Root part = sprite bounds, invisible.
-- Blender voxel models (Config.itemModels: the bow and its pull stages, the arrow, the shears, and our pickaxes, axes,
-- shovels and swords per material as <id>_<material> — assets/models/*/<item>.py -- export) come first and use the
-- same frame; their boxes are real 3D voxels (the bow's grip is three deep). The tools are modelled upright and carry
-- a `tilt`: turned by it in the item plane they lie across the item square like a Minecraft sprite, the handle end at
-- the lower left where the hand holds a sprite (HeldItem); the square is the tilted model's bounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ItemModels = {}
local cache: { [string]: Model } = {}
local store = Instance.new("Folder")
store.Name = "ItemModelCache"
store.Parent = ReplicatedStorage

export type Voxels = { w: number, h: number, p: { string }, r: { number }, mirror: boolean? }
-- size = {x, y, z} voxels (x = image right, z = image up, y = depth); b = flat {x, y, z, w, d, h, paletteIndex, …}
export type Model3d = { size: { number }, p: { string }, b: { number }, tilt: number? }

local function hexColor(hex: string): Color3
	local r = tonumber(string.sub(hex, 1, 2), 16) or 0
	local g = tonumber(string.sub(hex, 3, 4), 16) or 0
	local b = tonumber(string.sub(hex, 5, 6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

-- Voxel data for an item: exact id first, then "<id>_<material>" for tools/armor by level.
function ItemModels.voxelsFor(id: string, level: number?): Voxels?
	local items = Config.itemVoxels and Config.itemVoxels.items
	if not items then
		return nil
	end
	if level and Config.tools[id] then
		local keyed = items[id .. "_" .. Config.materialForLevel(level)]
		if keyed then
			return keyed
		end
	end
	return items[id]
end

-- the Blender model of an item: "<id>_<material>" for tools by level first, then the exact id
function ItemModels.modelFor(id: string, level: number?): Model3d?
	local models = Config.itemModels and Config.itemModels.items
	if not models then
		return nil
	end
	if level and Config.tools[id] then
		local keyed = models[id .. "_" .. Config.materialForLevel(level)]
		if keyed then
			return keyed
		end
	end
	return models[id]
end

local function part(root: BasePart, size: Vector3, offset: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "Px"
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Massless = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	-- explicit Weld with C0: the relative offset survives cloning and re-parenting
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = root, p
	weld.C0 = offset
	weld.Parent = p
	return p
end

-- `size` = the item square's side in studs
local function build3d(key: string, m: Model3d, size: number): Model
	local model = Instance.new("Model")
	model.Name = "Item_" .. key
	local sx, sy, sz = m.size[1], m.size[2], m.size[3]
	local b = m.b
	local turn = CFrame.Angles(math.rad(m.tilt or 0), 0, 0)
	-- the voxel frame's centre, then (tilted) the item square round the boxes' turned corners, in voxels
	local mid = Vector3.new(sy / 2, sz / 2, sx / 2)
	local pixel = size / sz
	local centre = Vector3.zero
	local side = Vector3.new(sy, sz, sx)
	if m.tilt then
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		for i = 1, #b, 7 do
			for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
				local at = turn
					* (
						Vector3.new(0, b[i + 2] + corner[2] * b[i + 5], b[i] + corner[1] * b[i + 3])
						- Vector3.new(0, mid.Y, mid.Z)
					)
				low, high = low:Min(at), high:Max(at)
			end
		end
		local span = math.max(high.Y - low.Y, high.Z - low.Z)
		centre = Vector3.new(0, (low.Y + high.Y) / 2, (low.Z + high.Z) / 2)
		pixel = size / span
		side = Vector3.new(sy, span, span)
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = side * pixel
	root.Transparency = 1
	root.Massless = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Anchored = false
	root.Parent = model
	model.PrimaryPart = root
	for i = 1, #b, 7 do
		local x, y, z, w, d, h, pi =
			b[i], b[i + 1], b[i + 2], b[i + 3], b[i + 4], b[i + 5], b[i + 6]
		local offset = CFrame.new(-centre * pixel)
			* turn
			* CFrame.new((Vector3.new(y + d / 2, z + h / 2, x + w / 2) - mid) * pixel)
		part(root, Vector3.new(d * pixel, h * pixel, w * pixel), offset, hexColor(m.p[pi + 1])).Parent =
			model
	end
	return model
end

local function build(key: string, voxels: Voxels, pixel: number, depth: number): Model
	local model = Instance.new("Model")
	model.Name = "Item_" .. key
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(depth, voxels.h * pixel, voxels.w * pixel)
	root.Transparency = 1
	root.Massless = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Anchored = false
	root.Parent = model
	model.PrimaryPart = root
	local r = voxels.r
	for i = 1, #r, 5 do
		local x, y, w, h, pi = r[i], r[i + 1], r[i + 2], r[i + 3], r[i + 4]
		if voxels.mirror then
			-- the axe's blade forward: mirror across the handle's diagonal (bottom-left → top-right), so the blade
			-- changes sides and the handle stays where the grip expects it (a left-right mirror moved the handle out of
			-- the fist: the axe was held by its head)
			x, y, w, h = voxels.w - y - h, voxels.h - x - w, h, w
		end
		local p = Instance.new("Part")
		p.Name = "Px"
		p.Size = Vector3.new(depth, h * pixel, w * pixel)
		-- centre of the rect in sprite space, origin at the sprite centre
		local cx = (x + w / 2 - voxels.w / 2) * pixel
		local cy = (voxels.h / 2 - (y + h / 2)) * pixel
		local offset = CFrame.new(0, cy, cx) -- image right = +Z (checked on the live character)
		p.CFrame = root.CFrame * offset
		p.Color = hexColor(voxels.p[pi + 1])
		p.Material = Enum.Material.SmoothPlastic
		p.Massless = true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CastShadow = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		-- explicit Weld with C0: the relative offset survives cloning and re-parenting
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = root, p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = model
	end
	return model
end

-- Returns a fresh clone (or nil when the item has no sprite). `size` = sprite height in studs.
function ItemModels.get(id: string, level: number?, size: number): Model?
	local m = ItemModels.modelFor(id, level)
	if m then
		local key = string.format(
			"3d:%s:%s:%.2f",
			id,
			tostring(if level and Config.tools[id] then Config.materialForLevel(level) else "-"),
			size
		)
		local cached = cache[key]
		if not cached then
			cached = build3d(key, m, size)
			cached.Parent = store
			cache[key] = cached
		end
		return cached:Clone()
	end
	local voxels = ItemModels.voxelsFor(id, level)
	if not voxels then
		return nil
	end
	local pixel = size / voxels.h
	local key = string.format(
		"%s:%s:%.2f",
		id,
		tostring(if level and Config.tools[id] then Config.materialForLevel(level) else "-"),
		size
	)
	local cached = cache[key]
	if not cached then
		cached = build(key, voxels, pixel, pixel * 1.2)
		cached.Parent = store
		cache[key] = cached
	end
	return cached:Clone()
end

return ItemModels
