--!strict
-- Mines: server-side block grid per location, Parts only for blocks with an exposed face,
-- timed reset with warning and chunked rebuild. Anchor: a BasePart tagged "MineAnchor" with
-- attribute LocationId; the grid grows down and sideways from the anchor's top-centre.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local TextureService = require(script.Parent.TextureService)

local BLOCK = 4 -- studs per block
local ANCHOR_TAG = "MineAnchor"
local BLOCK_TAG = "MineBlock"
local CHUNK = 512 -- parts created per frame during rebuild

export type Mine = {
	shares: { [string]: number },
	id: string,
	location: Config.Location,
	anchor: BasePart,
	folder: Folder,
	size: { number },
	origin: Vector3, -- world position of cell (1,1,1) centre
	cells: { [number]: string? }, -- index -> block id (nil = air)
	parts: { [number]: BasePart },
	generation: number,
	resetAt: number,
	rebuilding: boolean,
}

local MineService = {}
local mines: { [string]: Mine } = {}
local blockLookup: { [BasePart]: { mine: Mine, index: number } } = {}

local function index(mine: Mine, x: number, y: number, z: number): number
	local sx, sy = mine.size[1], mine.size[2]
	return ((z - 1) * sy + (y - 1)) * sx + x
end

local function coords(mine: Mine, i: number): (number, number, number)
	local sx, sy = mine.size[1], mine.size[2]
	local x = (i - 1) % sx + 1
	local y = math.floor((i - 1) / sx) % sy + 1
	local z = math.floor((i - 1) / (sx * sy)) + 1
	return x, y, z
end

local function cellAt(mine: Mine, x: number, y: number, z: number): string?
	if y < 1 then
		return nil -- above the mine is air: the top layer is always exposed
	end
	if x < 1 or z < 1 or x > mine.size[1] or y > mine.size[2] or z > mine.size[3] then
		return "wall" -- sides and floor count as solid (unbreakable surroundings)
	end
	return mine.cells[index(mine, x, y, z)]
end

local function exposed(mine: Mine, x: number, y: number, z: number): boolean
	return cellAt(mine, x + 1, y, z) == nil
		or cellAt(mine, x - 1, y, z) == nil
		or cellAt(mine, x, y + 1, z) == nil
		or cellAt(mine, x, y - 1, z) == nil
		or cellAt(mine, x, y, z + 1) == nil
		or cellAt(mine, x, y, z - 1) == nil
end

local COLORS: { [string]: Color3 } = {
	dirt = Color3.fromRGB(121, 85, 58),
	sand = Color3.fromRGB(219, 207, 163),
	gravel = Color3.fromRGB(131, 127, 126),
	stone = Color3.fromRGB(125, 125, 125),
	coal_ore = Color3.fromRGB(70, 70, 70),
	iron_ore = Color3.fromRGB(180, 150, 130),
	coal_block = Color3.fromRGB(30, 30, 30),
	red_sand = Color3.fromRGB(190, 100, 40),
	gold_ore = Color3.fromRGB(210, 180, 80),
	netherite = Color3.fromRGB(100, 40, 40),
	soul_sand = Color3.fromRGB(80, 60, 50),
	quartz_ore = Color3.fromRGB(170, 120, 110),
	sandstone = Color3.fromRGB(220, 205, 150),
	red_sandstone = Color3.fromRGB(190, 100, 50),
}

local function makePart(mine: Mine, i: number)
	if mine.parts[i] then
		return
	end
	local id = mine.cells[i]
	if not id then
		return
	end
	local x, y, z = coords(mine, i)
	local part = Instance.new("Part")
	part.Name = id
	part.Size = Vector3.new(BLOCK, BLOCK, BLOCK)
	part.Position = mine.origin + Vector3.new((x - 1) * BLOCK, -(y - 1) * BLOCK, (z - 1) * BLOCK)
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = COLORS[id] or Color3.fromRGB(200, 200, 200)
	TextureService.apply(part, id)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Block", id)
	part:SetAttribute("Index", i)
	part:SetAttribute("MineId", mine.id)
	part:SetAttribute("Generation", mine.generation)
	CollectionService:AddTag(part, BLOCK_TAG)
	part.Parent = mine.folder
	mine.parts[i] = part
	blockLookup[part] = { mine = mine, index = i }
end

local function pickBlock(shares: { [string]: number }, rng: Random): string?
	local r = rng:NextNumber()
	local acc = 0
	for id, share in pairs(shares) do
		acc += share
		if r <= acc then
			return if id == "air" then nil else id
		end
	end
	return nil
end

local function rebuild(mine: Mine)
	mine.rebuilding = true
	mine.generation += 1
	local n = 0
	for _, part in pairs(mine.parts) do
		blockLookup[part] = nil
		part:Destroy()
		n += 1
		if n % CHUNK == 0 then
			task.wait()
		end
	end
	mine.folder:ClearAllChildren()
	table.clear(mine.parts)
	table.clear(mine.cells)
	local rng = Random.new()
	local total = mine.size[1] * mine.size[2] * mine.size[3]
	for i = 1, total do
		mine.cells[i] = pickBlock(mine.shares, rng)
		if i % 4096 == 0 then
			task.wait()
		end
	end
	local created = 0
	for i = 1, total do
		local x, y, z = coords(mine, i)
		if mine.cells[i] and exposed(mine, x, y, z) then
			makePart(mine, i)
			created += 1
			if created % CHUNK == 0 then
				task.wait()
			end
		end
	end
	mine.resetAt = os.clock() + mine.location.mine.resetSeconds
	mine.rebuilding = false
	Remotes.event("MineReset"):FireAllClients(mine.id, mine.generation)
end

-- Pushes players standing inside the grid up to the anchor top before a rebuild.
local function evacuate(mine: Mine)
	local top = mine.origin.Y + BLOCK
	local half = Vector3.new(
		mine.size[1] * BLOCK / 2,
		mine.size[2] * BLOCK / 2 + BLOCK,
		mine.size[3] * BLOCK / 2
	)
	local centre = mine.origin
		+ Vector3.new(
			(mine.size[1] - 1) * BLOCK / 2,
			-(mine.size[2] - 1) * BLOCK / 2,
			(mine.size[3] - 1) * BLOCK / 2
		)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local d = root.Position - centre
			if math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z then
				root.CFrame = CFrame.new(root.Position.X, top + 4, root.Position.Z)
			end
		end
	end
end

function MineService.lookup(part: Instance): (Mine?, number?)
	local hit = blockLookup[part :: BasePart]
	if hit then
		return hit.mine, hit.index
	end
	return nil, nil
end

-- Removes a block after a validated dig; exposes neighbours. Returns the block id.
function MineService.breakBlock(mine: Mine, i: number): string?
	local id = mine.cells[i]
	if not id then
		return nil
	end
	mine.cells[i] = nil
	local part = mine.parts[i]
	if part then
		blockLookup[part] = nil
		mine.parts[i] = nil
		part:Destroy()
	end
	local x, y, z = coords(mine, i)
	for _, d in ipairs({
		{ 1, 0, 0 },
		{ -1, 0, 0 },
		{ 0, 1, 0 },
		{ 0, -1, 0 },
		{ 0, 0, 1 },
		{ 0, 0, -1 },
	}) do
		local nx, ny, nz = x + d[1], y + d[2], z + d[3]
		if
			nx >= 1
			and ny >= 1
			and nz >= 1
			and nx <= mine.size[1]
			and ny <= mine.size[2]
			and nz <= mine.size[3]
		then
			local ni = index(mine, nx, ny, nz)
			if mine.cells[ni] then
				makePart(mine, ni)
			end
		end
	end
	return id
end

function MineService.get(id: string): Mine?
	return mines[id]
end

local function register(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local locationId = anchor:GetAttribute("LocationId")
	local location = if typeof(locationId) == "string" then Config.location(locationId) else nil
	if not location or location.kind ~= "mine" then
		warn("[MineService] anchor without valid LocationId:", anchor:GetFullName())
		return
	end
	local mineId = (anchor:GetAttribute("MineId") :: string?) or location.id
	local folder = Instance.new("Folder")
	folder.Name = "Mine_" .. mineId
	folder.Parent = workspace
	local sizeOverride = anchor:GetAttribute("Size")
	local size = if typeof(sizeOverride) == "Vector3"
		then { sizeOverride.X, sizeOverride.Y, sizeOverride.Z }
		else location.mine.size
	local top = anchor.Position + Vector3.new(0, anchor.Size.Y / 2, 0)
	local origin = top
		+ Vector3.new(-(size[1] - 1) * BLOCK / 2, -BLOCK / 2, -(size[3] - 1) * BLOCK / 2)
	-- per-mine composition override from locations.json (e.g. prison_small: only melon + oak)
	local override = (location :: any).mines and (location :: any).mines[mineId]
	local mine: Mine = {
		id = mineId,
		location = location,
		shares = if override and override.shares then override.shares else location.mine.shares,
		anchor = anchor,
		folder = folder,
		size = size,
		origin = origin,
		cells = {},
		parts = {},
		generation = 0,
		resetAt = 0,
		rebuilding = false,
	}
	mines[mineId] = mine
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	task.spawn(rebuild, mine)
end

function MineService.Start()
	for _, anchor in ipairs(CollectionService:GetTagged(ANCHOR_TAG)) do
		register(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(register)

	task.spawn(function()
		local warned: { [string]: boolean } = {}
		while true do
			task.wait(1)
			local now = os.clock()
			for id, mine in pairs(mines) do
				if mine.rebuilding or mine.resetAt == 0 then
					continue
				end
				local left = mine.resetAt - now
				if left <= mine.location.mine.warnSeconds and not warned[id] then
					warned[id] = true
					for _, player in ipairs(Players:GetPlayers()) do
						Remotes.event("Toast"):FireClient(
							player,
							Strings.t("mine_reset_warn", Strings.localeOf(player), math.ceil(left))
						)
					end
				end
				if left <= 0 then
					warned[id] = nil
					evacuate(mine)
					rebuild(mine)
				end
			end
		end
	end)
end

MineService.BLOCK = BLOCK
MineService.BLOCK_TAG = BLOCK_TAG
return MineService
