--!strict
-- 3D "extruded sprite" item models, the way Minecraft renders held items: every item icon was
-- reduced to a 16×16 pixel grid (scripts/sprite-to-voxels.ps1 → assets/icons/voxels.json →
-- Config/itemvoxels.json) and each same-colour rectangle becomes a thin Part. Models are built once
-- per item id and cloned for every character that holds the item.
--
-- Model frame: the sprite lies in the Y–Z plane of the root part (thickness along X, like the old
-- decal plane): image up = +Y, image right = +Z. Root part = sprite bounds, invisible.
-- Blender voxel models (Config.itemModels: the bow and its pull stages, the arrow — assets/models/*/<item>.py
-- -- export) come first and use the same frame; their boxes are real 3D voxels (the bow's grip is three deep).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ItemModels = {}
local cache: { [string]: Model } = {}
local store = Instance.new("Folder")
store.Name = "ItemModelCache"
store.Parent = ReplicatedStorage

export type Voxels = { w: number, h: number, p: { string }, r: { number }, mirror: boolean? }
-- size = {x, y, z} voxels (x = image right, z = image up, y = depth); b = flat {x, y, z, w, d, h, paletteIndex, …}
export type Model3d = { size: { number }, p: { string }, b: { number } }

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

function ItemModels.modelFor(id: string): Model3d?
	local models = Config.itemModels and Config.itemModels.items
	return if models then models[id] else nil
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

local function build3d(key: string, m: Model3d, pixel: number): Model
	local model = Instance.new("Model")
	model.Name = "Item_" .. key
	local sx, sy, sz = m.size[1], m.size[2], m.size[3]
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(sy * pixel, sz * pixel, sx * pixel)
	root.Transparency = 1
	root.Massless = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Anchored = false
	root.Parent = model
	model.PrimaryPart = root
	local b = m.b
	for i = 1, #b, 7 do
		local x, y, z, w, d, h, pi =
			b[i], b[i + 1], b[i + 2], b[i + 3], b[i + 4], b[i + 5], b[i + 6]
		local offset = CFrame.new(
			(y + d / 2 - sy / 2) * pixel,
			(z + h / 2 - sz / 2) * pixel,
			(x + w / 2 - sx / 2) * pixel
		)
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
		local p = Instance.new("Part")
		p.Name = "Px"
		p.Size = Vector3.new(depth, h * pixel, w * pixel)
		-- centre of the rect in sprite space, origin at the sprite centre
		local cx = (x + w / 2 - voxels.w / 2) * pixel * (if voxels.mirror then -1 else 1)
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
	local m = ItemModels.modelFor(id)
	if m then
		local key = string.format("3d:%s:%.2f", id, size)
		local cached = cache[key]
		if not cached then
			cached = build3d(key, m, size / m.size[3])
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
