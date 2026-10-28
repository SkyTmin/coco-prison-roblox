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
local BlockColors = require(Shared.BlockColors)
local Cobweb = require(Shared.Cobweb)
local TextureService = require(script.Parent.TextureService)

local BLOCK = 4 -- studs per block
local ANCHOR_TAG = "MineAnchor"
local BLOCK_TAG = "MineBlock"
-- a reset works at most this long per frame (60 FPS = 16.7 ms a frame) [docs/research/server-scaling.md]
local FRAME_BUDGET = 0.004
local LADDER_WIDTH = 4 -- [владелец] four ladders, 4 blocks wide, centred on every side, always free

-- Cells of the four ladder shafts (one block deep against each wall, 4 wide, full depth). They are
-- never filled, so the ladders stay reachable whatever the players dig and whenever the mine resets.
local function ladderShaft(size: { number }, x: number, z: number): boolean
	local sx, sz = size[1], size[3]
	local x0 = math.floor(sx / 2) - LADDER_WIDTH / 2 + 1
	local z0 = math.floor(sz / 2) - LADDER_WIDTH / 2 + 1
	local midX = x >= x0 and x < x0 + LADDER_WIDTH
	local midZ = z >= z0 and z < z0 + LADDER_WIDTH
	return (midX and (z == 1 or z == sz)) or (midZ and (x == 1 or x == sx))
end

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
	dug: number, -- blocks broken since the last reset: an untouched mine is not rebuilt
	resetSeconds: number, -- the location's timer, or the faction base mini-mine's
	noLadders: boolean, -- anchor attribute NoLadders: no free ladder shafts (the small pads of the Дворы)
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

-- (cells are all rendered now; exposure tests were removed with the exposed-only rendering)

local COLORS: { [string]: Color3 } = {
	black_glass = Color3.fromRGB(34, 28, 42),
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
	ice = Color3.fromRGB(170, 210, 245),
	packed_ice = Color3.fromRGB(125, 165, 225),
}

-- Blocks whose top face differs (log rings, the melon's veined top — like the original Малая шахта
-- [владелец 22.10, скриншот]):
-- a Texture on the Top face from Config.textures "<id>_top".
local TOP_FACES: { [string]: string } = {}
for _, id in ipairs({ "oak_log", "melon" }) do
	local top = (Config.textures :: any).textures[id .. "_top"]
	if typeof(top) == "string" then
		TOP_FACES[id] = top
	end
end

local function styleTop(part: BasePart, id: string)
	local want = TOP_FACES[id]
	local tex = part:FindFirstChild("TopFace") :: Texture?
	if not want then
		if tex then
			tex:Destroy()
		end
		return
	end
	if not tex then
		local t = Instance.new("Texture")
		t.Name = "TopFace"
		t.Face = Enum.NormalId.Top
		t.StudsPerTileU = BLOCK
		t.StudsPerTileV = BLOCK
		t.Parent = part
		tex = t
	end
	if (tex :: Texture).Texture ~= want then
		(tex :: Texture).Texture = want
	end
end

-- Block look and identity; used for new parts and for parts re-used by an in-place reset. Only what
-- differs is written: every property change is replicated to every client that has the part.
-- Blocks with no texture of ours that read well in a Roblox material (Снежная длань: ice, packed ice)
local MATERIALS: { [string]: Enum.Material } = {
	ice = Enum.Material.Ice,
	packed_ice = Enum.Material.Glacier,
	black_glass = Enum.Material.Glass, -- Врата края: чёрное стекло [меню] (no texture: dark glossy glass)
}

-- [владелец 23.10: «паутина как в майнкрафте, и персонаж застревает»] a cobweb cell is an invisible box with no
-- collision (the player sinks into it and Cobweb slows them) holding the Minecraft cross sprite; it still takes rays,
-- so it can be aimed at and dug
local function styleCobweb(part: BasePart, web: boolean)
	local transparency = if web then 1 else 0
	if part.Transparency ~= transparency then
		part.Transparency = transparency
	end
	if part.CanCollide == web then
		part.CanCollide = not web
	end
	local sprite = part:FindFirstChild("CobwebSprite")
	if web and not sprite then
		Cobweb.sprite(part.CFrame, BLOCK, part)
		part:AddTag(Cobweb.TAG)
	elseif not web and sprite then
		for _, child in ipairs(part:GetChildren()) do
			if child.Name == "CobwebSprite" then
				child:Destroy()
			end
		end
		part:RemoveTag(Cobweb.TAG)
	end
end

-- tinted look of blocks we have no texture of: shared/BlockColors.TINTED (the UI icons use it too)
local TINTED = BlockColors.TINTED

local function stylePart(part: BasePart, id: string)
	local variant = TextureService.variantName(id)
	local tint = Color3.new(1, 1, 1)
	local tinted = TINTED[id]
	if not variant and tinted and not tinted.iconOnly then
		variant = TextureService.variantName(tinted.base)
		tint = tinted.color
	end
	local material = if variant
		then Enum.Material.Plastic
		else MATERIALS[id] or Enum.Material.SmoothPlastic
	local color = if variant then tint else COLORS[id] or Color3.fromRGB(200, 200, 200)
	if part.Name ~= id then
		part.Name = id
	end
	if part.Material ~= material then
		part.Material = material
	end
	if part.MaterialVariant ~= (variant or "") then
		part.MaterialVariant = variant or ""
	end
	if part.Color ~= color then
		part.Color = color
	end
	if part:GetAttribute("Block") ~= id then
		part:SetAttribute("Block", id)
	end
	styleTop(part, id)
	styleCobweb(part, id == "cobweb")
end

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
	stylePart(part, id)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Index", i)
	part:SetAttribute("MineId", mine.id)
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
	-- fresh seed every reset so the layout is reshuffled [владелец]
	local rng = Random.new(os.time() + mine.generation * 7919 + math.floor(os.clock() * 1000))
	local total = mine.size[1] * mine.size[2] * mine.size[3]
	local layout: { [number]: string } = {}
	local frameStart = os.clock()
	local function yieldIfLong()
		if os.clock() - frameStart > FRAME_BUDGET then
			task.wait()
			frameStart = os.clock()
		end
	end
	for i = 1, total do
		local x, _, z = coords(mine, i)
		local id = if not mine.noLadders and ladderShaft(mine.size, x, z)
			then nil
			else pickBlock(mine.shares, rng)
		if id then
			layout[i] = id
		end
		yieldIfLong()
	end
	-- [владелец 21.10] reset IN PLACE: existing blocks change their type, dug cells get a block back,
	-- nothing is removed first. Before, the whole mine was destroyed column by column and then rebuilt,
	-- so players standing on it fell through. Every cell keeps a Part (no holes into the solid inside).
	for i = 1, total do
		local id = layout[i]
		local part = mine.parts[i]
		mine.cells[i] = id
		if id then
			if part then
				stylePart(part, id) -- writes only what changed
			else
				makePart(mine, i)
			end
		elseif part then
			blockLookup[part] = nil
			mine.parts[i] = nil
			part:Destroy()
		end
		yieldIfLong()
	end
	mine.dug = 0
	mine.resetAt = os.clock() + mine.resetSeconds
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

-- players close enough to care about this mine's reset warning
local function playersNear(mine: Mine): { Player }
	local centre = mine.origin
		+ Vector3.new(
			(mine.size[1] - 1) * BLOCK / 2,
			-(mine.size[2] - 1) * BLOCK / 2,
			(mine.size[3] - 1) * BLOCK / 2
		)
	local radius = math.max(mine.size[1], mine.size[2], mine.size[3]) * BLOCK + 64
	local near = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - centre).Magnitude <= radius then
			table.insert(near, player)
		end
	end
	return near
end

MineService.ladderShaft = ladderShaft

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
	mine.dug += 1
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

-- cell index ↔ grid coordinates (x right, y down from the top layer, z) — the books Молот / Пластолом
function MineService.coords(mine: Mine, i: number): (number, number, number)
	return coords(mine, i)
end

function MineService.index(mine: Mine, x: number, y: number, z: number): number
	return index(mine, x, y, z)
end

function MineService.get(id: string): Mine?
	return mines[id]
end

-- Lamps must not reach a mine's blocks. Below the top graphics level Roblox lights by a 4-stud voxel
-- grid that matches our blocks and rebuilds as the camera moves, so lamp light on a mine shows as
-- single blocks flashing between lit and unlit (Studio 27.10, every mine with lamps at its rim).
local function keepLampsOff(mine: Mine)
	local sx, sy, sz = mine.size[1], mine.size[2], mine.size[3]
	local top = mine.origin.Y + BLOCK / 2
	local low = Vector3.new(mine.origin.X - BLOCK / 2, top - sy * BLOCK, mine.origin.Z - BLOCK / 2)
	local high = Vector3.new(low.X + sx * BLOCK, top, low.Z + sz * BLOCK)
	for _, instance in ipairs(workspace:GetDescendants()) do
		if not instance:IsA("Light") or not instance.Enabled then
			continue
		end
		local holder = instance.Parent
		local at = if holder and holder:IsA("BasePart")
			then holder.Position
			elseif holder and holder:IsA("Attachment") then holder.WorldPosition
			else nil
		if not at then
			continue
		end
		-- Range lives on PointLight, SpotLight and SurfaceLight, not on Light
		local light = instance :: PointLight
		local gap = (at:Max(low):Min(high) - at).Magnitude
		if gap < light.Range then
			if gap - 1 < 4 then
				light.Enabled = false
			else
				light.Range = gap - 1
			end
		end
	end
end

local function register(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local locationId = anchor:GetAttribute("LocationId")
	local location = if typeof(locationId) == "string" then Config.location(locationId) else nil
	-- the faction base is not a mine location, but its districts have mini-mines (anchor attribute MiniMine)
	local mini = anchor:GetAttribute("MiniMine") == true
		and location ~= nil
		and location.miniMine ~= nil
	if not location or (location.kind ~= "mine" and not mini) then
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
		dug = 0,
		resetSeconds = if mini and location.miniMine
			then location.miniMine.resetSeconds
			elseif override and override.resetSeconds then override.resetSeconds
			else location.mine.resetSeconds,
		noLadders = anchor:GetAttribute("NoLadders") == true,
	}
	mines[mineId] = mine
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	keepLampsOff(mine)
	task.spawn(rebuild, mine)
end

-- A player whose root is inside a solid cell (rendered or not) is lifted onto the mine top. Solid
-- cells deeper than the exposed layer have no Parts, so anything that slips past the surface would
-- otherwise fall to the pit floor "through" the blocks.
local function solidCell(id: string?): boolean
	return id ~= nil and id ~= "cobweb"
end

local function rescue(mine: Mine)
	if mine.rebuilding then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local local_ = root.Position - mine.origin
			local x = math.floor(local_.X / BLOCK + 0.5) + 1
			local y = math.floor(-local_.Y / BLOCK + 0.5) + 1
			local z = math.floor(local_.Z / BLOCK + 0.5) + 1
			-- below the grid (between the lowest layer and the pit floor) counts as stuck too
			local below = y > mine.size[2] and local_.Y > -(mine.size[2] + 1) * BLOCK - 2
			local inside = x >= 1 and x <= mine.size[1] and z >= 1 and z <= mine.size[3]
			if
				inside
				and (
					below
					-- a cobweb cell has no collision: being in it is being stuck in a web, not in a block
					or (
						y >= 1
						and y <= mine.size[2]
						and solidCell(mine.cells[index(mine, x, y, z)])
					)
				)
			then
				-- still fine while standing on a rendered block: only the root centre deep inside counts
				local depthInCell = (y - 1) * BLOCK + local_.Y + BLOCK / 2 -- 0 at the cell top, BLOCK at its bottom
				if below or depthInCell > 1.5 then
					root.CFrame =
						CFrame.new(root.Position.X, mine.origin.Y + BLOCK * 1.5, root.Position.Z)
				end
			end
		end
	end
end

function MineService.Start()
	for _, anchor in ipairs(CollectionService:GetTagged(ANCHOR_TAG)) do
		register(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(register)

	-- Studio-only QA hook (ServerStorage.MineDebug): ("reset", mineId) makes that mine reset in 1 s
	if game:GetService("RunService"):IsStudio() then
		local debugApi = Instance.new("BindableFunction")
		debugApi.Name = "MineDebug"
		debugApi.OnInvoke = function(op: string, id: string): any
			local mine = mines[id]
			if op == "reset" and mine then
				mine.dug = math.max(mine.dug, 1) -- an untouched mine would skip the reset
				mine.resetAt = os.clock() + 1
				return true
			elseif op == "state" and mine then
				return string.format(
					"rebuilding=%s generation=%d dug=%d resetIn=%.1f parts=%d",
					tostring(mine.rebuilding),
					mine.generation,
					mine.dug,
					mine.resetAt - os.clock(),
					#mine.folder:GetChildren()
				)
			end
			return false
		end
		debugApi.Parent = game:GetService("ServerStorage")
	end

	task.spawn(function()
		local warned: { [string]: boolean } = {}
		while true do
			task.wait(1)
			for _, mine in pairs(mines) do
				rescue(mine)
			end
			local now = os.clock()
			for id, mine in pairs(mines) do
				if mine.rebuilding or mine.resetAt == 0 then
					continue
				end
				local left = mine.resetAt - now
				if mine.dug == 0 then
					-- nobody dug since the last reset: nothing to restore, no work, no traffic
					if left <= 0 then
						mine.resetAt = now + mine.resetSeconds
					end
					continue
				end
				-- warnSeconds 0: no warning (the Дворы pads reset every minute, a toast each time would be noise)
				local warnSeconds = mine.location.mine.warnSeconds
				if warnSeconds > 0 and left <= warnSeconds and not warned[id] then
					warned[id] = true
					for _, player in ipairs(playersNear(mine)) do
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

-- the mine timers of this server for the PRIS+ «Респавн шахт» board (PrisService): mine id, its location, seconds to
-- the next reset (an untouched mine runs its cycle too) and the cycle length
function MineService.timers(): { { id: string, location: string, left: number, cycle: number } }
	local now = os.clock()
	local out = {}
	for id, mine in pairs(mines) do
		table.insert(out, {
			id = id,
			location = mine.location.id,
			left = if mine.rebuilding or mine.resetAt == 0
				then 0
				else math.max(0, mine.resetAt - now),
			cycle = mine.resetSeconds,
		})
	end
	return out
end

MineService.BLOCK = BLOCK
MineService.BLOCK_TAG = BLOCK_TAG
return MineService
