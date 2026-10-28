--!strict
-- The База банды: a location of its own for every gang [владелец 28.10: «Ты создал банду. Появляется отдельная
-- локация для банды твоей. Туда другие банды не могут попасть. И есть общая локация для банд это Гетто»; «представь
-- 33 банды» → одинаковая, без лимита; docs/research/remaining-features-design.md §1.5]. No shared courtyard:
-- scripts/build-gang-base.luau builds ONE base, ServerStorage.GangHouseTemplate (a Model pivoted at the middle of its
-- floor), and the locations menu / «На базу банды» take a member into his gang's copy (LocationService.SetArrival). The template's parts keep their tags in the attribute HouseTags ("TagA,TagB"): the tags are
-- put on only after a copy is in the workspace, so the services that bind prompts by tag (CaseService GangChest,
-- GangBaseService, NeedsService Restore*) bind each copy and never the template.
-- A member going to the base (the locations menu, GangHome from the «Банда» window) gets his gang's copy on this server:
-- cloned into a free cell of a grid (CELL studs apart), banners (attribute HouseBanner)
-- recoloured, the «[TAG] name» sign (TextLabel GangTagLabel) filled, attribute GangId / HouseOf on the copy and its
-- parts; then the player is streamed in and put on the house arrival (a LocationSpawn of gang_base with HouseSpawn).
-- In the house: the gang chest, Библиотекарь, Кузнец — each only once its upgrade is bought (FEATURES: a new gang's
-- house is empty [владелец 28.10: «с 0 уровня ничего нет, ни сундуков, ни библиотекаря, ни кузницы»]; a purchase shows
-- it at once through GangService.OnChanged), the Restore* zones, the Шнырь (→ the common Гетто, GangBaseService) and
-- the exit door (GangHouseExit → the prison). A non-member found inside the base box (part HouseBounds) is sent to the
-- prison. PvP between members follows the gang's own setting (CombatService), as everywhere.
-- A copy with no member inside for EMPTY_SECONDS is destroyed and its cell reused [решение].
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local GangService = require(script.Parent.GangService)
local LocationService = require(script.Parent.LocationService)

local GangHouseService = {}
local LOCATION = "gang_base"
local TEMPLATE = "GangHouseTemplate"
-- Config.gangs.base.houses [решение]: the grid of the base copies (X 10400, height 13 200),
-- studs between cells, cells a row, seconds an empty house lives
local houseCfg = Config.gangs.base.houses
local EMPTY_SECONDS = houseCfg.emptySeconds
local CELL = houseCfg.cell
local COLUMNS = houseCfg.columns
local ORIGIN = Vector3.new(houseCfg.x, houseCfg.y, houseCfg.z)
local DOOR_RANGE = 10

-- the parts an upgrade brings into the house: model name in the template → upgrade id
local FEATURES: { [string]: string } =
	{ GangChestModel = "chests", GangLibrarian = "library", GangSmith = "forge" }

type House = {
	model: Model,
	features: { { root: Instance, parent: Instance, upgrade: string } },
	gang: string,
	cell: number,
	bounds: BasePart?,
	spawn: BasePart?,
	emptySince: number?,
}
local houses: { [string]: House } = {} -- gang id → its house on this server
local cells: { [number]: string } = {} -- cell → gang id
local warned: { [Player]: number } = {}
local started = false

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function cellCFrame(cell: number): CFrame
	local column = (cell - 1) % COLUMNS
	local row = (cell - 1) // COLUMNS
	return CFrame.new(ORIGIN + Vector3.new((column - COLUMNS / 2) * CELL, 0, row * CELL))
end

local function prisonSpawn(): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LocationSpawn")) do
		if
			part:IsA("BasePart")
			and part:IsDescendantOf(workspace)
			and part:GetAttribute("LocationId") == "prison"
			and (part:GetAttribute("Spot") == nil or part:GetAttribute("Spot") == "spawn")
		then
			return part
		end
	end
	return nil
end

-- the house's look: banners in the gang colour, the tag over the door
local function paint(house: House, doc: any)
	local color = Gangs.color(doc.color)
	house.model:SetAttribute("GangTag", doc.tag)
	house.model:SetAttribute("GangColor", doc.color)
	for _, d in ipairs(house.model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("HouseBanner") then
			d.Color = color
		elseif d:IsA("TextLabel") and d.Name == "GangTagLabel" then
			d.Text = "[" .. doc.tag .. "] " .. doc.name
			d.TextColor3 = color
		end
	end
end

-- the CollectionService tags of a copy (kept in the attribute HouseTags): added only in the workspace
local function tagAll(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		local list = d:GetAttribute("HouseTags")
		if typeof(list) == "string" then
			for tag in string.gmatch(list, "[^,%s]+") do
				CollectionService:AddTag(d, tag)
			end
		end
	end
end

-- shows the chests / Библиотекарь / Кузнец the gang has bought and takes away the rest (parented to nil, kept)
local function fit(house: House, doc: any)
	for _, f in ipairs(house.features) do
		local has = Gangs.level(doc, f.upgrade) >= 1
		if has and f.root.Parent == nil then
			f.root.Parent = f.parent
			tagAll(f.root)
		elseif not has and f.root.Parent ~= nil then
			f.root.Parent = nil
		end
	end
end

local function destroy(house: House)
	houses[house.gang] = nil
	cells[house.cell] = nil
	house.model:Destroy()
end

-- the gang's house on this server, built from the template when it has none (nil = no template in the place)
local function ensure(doc: any): House?
	local have = houses[doc.id]
	if have and have.model.Parent then
		return have
	end
	local template = ServerStorage:FindFirstChild(TEMPLATE)
	if not template or not template:IsA("Model") then
		warn(
			"[GangHouse] ServerStorage."
				.. TEMPLATE
				.. " is missing: run scripts/build-gang-base.luau"
		)
		return nil
	end
	local cell = 1
	while cells[cell] do
		cell += 1
	end
	local model = template:Clone()
	model.Name = "GangHouse_" .. doc.tag
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("GangId", doc.id)
	model:PivotTo(cellCFrame(cell))
	local house: House =
		{ model = model, features = {}, gang = doc.id, cell = cell, emptySince = os.clock() }
	for _, d in ipairs(model:GetDescendants()) do
		d:SetAttribute("HouseOf", doc.id)
		if d:IsA("BasePart") and d.Name == "HouseBounds" then
			house.bounds = d
		end
		local upgrade = FEATURES[d.Name]
		if upgrade and d.Parent then
			table.insert(house.features, { root = d, parent = d.Parent, upgrade = upgrade })
		end
	end
	paint(house, doc)
	fit(house, doc) -- what is not bought yet leaves before the copy enters the workspace
	model.Parent = workspace
	-- the tags only now: the prompt services bind this copy
	tagAll(model)
	for _, d in ipairs(model:GetDescendants()) do
		if
			d:IsA("BasePart")
			and d:GetAttribute("HouseSpawn")
			and CollectionService:HasTag(d, "LocationSpawn")
		then
			house.spawn = d
		end
	end
	houses[doc.id] = house
	cells[cell] = doc.id
	return house
end

local function inside(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- may this player use this NPC / chest / zone? (parts of a gang's base: only that gang; anything else: yes)
function GangHouseService.allowed(part: Instance, player: Player): boolean
	local owner = part:GetAttribute("HouseOf")
	if owner == nil then
		return true
	end
	local doc = GangService.gangOf(ProfileService.Get(player))
	return doc ~= nil and doc.id == owner
end

local function place(player: Player, target: BasePart)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, target.Position, 3)
	if player.Character ~= character then
		return
	end
	character:PivotTo(target.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- the arrival of this player's base: his gang's copy, built when it has none (nil: no gang / no template)
local function arrivalOf(player: Player): BasePart?
	local doc = GangService.gangOf(ProfileService.Get(player))
	local house = doc and ensure(doc)
	if not house then
		return nil
	end
	house.emptySince = os.clock() -- the trip takes a few seconds: the copy waits
	return house.spawn
end

-- «На базу банды» from the «Банда» window: the usual 5 s trip into the gang's own copy
local function goHome(player: Player)
	local profile = ProfileService.Get(player)
	if not profile or not GangService.gangOf(profile) then
		toast(player, "gang_location_need_gang")
		return
	end
	LocationService.Request(player, LOCATION)
end

-- a stranger in a gang's base: straight to the prison spawn
local function evict(player: Player)
	local spawn = prisonSpawn()
	if not spawn then
		return
	end
	place(player, spawn)
	ProfileService.Mutate(player, function(p)
		p.location = "prison"
	end)
end

local lastUse: { [Player]: number } = {}
local function bindPrompt(part: Instance)
	if
		not part:IsA("BasePart")
		or part:FindFirstChild("HousePrompt")
		or not part:IsDescendantOf(workspace)
	then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HousePrompt"
	prompt.ActionText = Strings.t("gang_house_exit")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = DOOR_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if
			not part:IsDescendantOf(workspace)
			or not root
			or not root:IsA("BasePart")
			or (root.Position - part.Position).Magnitude > DOOR_RANGE + 2
			or os.clock() - (lastUse[player] or -math.huge) < 1
		then
			return
		end
		lastUse[player] = os.clock()
		LocationService.Request(player, "prison") -- the exit door: the usual trip to the prison
	end)
end

-- strangers out, empty copies gone
local function tick()
	local now = os.clock()
	local occupied: { [string]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			continue
		end
		local doc = GangService.gangOf(ProfileService.Get(player))
		for gangId, house in pairs(houses) do
			local bounds = house.bounds
			if not bounds or not inside(bounds, root.Position) then
				continue
			end
			if doc and doc.id == gangId then
				occupied[gangId] = true
			else
				evict(player)
				if now - (warned[player] or -math.huge) > 3 then
					warned[player] = now
					toast(player, "gang_plot_foreign")
				end
			end
			break
		end
	end
	for gangId, house in pairs(houses) do
		if occupied[gangId] then
			house.emptySince = nil
		else
			house.emptySince = house.emptySince or now
			if now - house.emptySince >= EMPTY_SECONDS or not house.model.Parent then
				destroy(house)
			end
		end
	end
	-- a renamed / recoloured gang: keep the house up to date
	for _, player in ipairs(Players:GetPlayers()) do
		local doc = GangService.gangOf(ProfileService.Get(player))
		local house = doc and houses[doc.id]
		if
			house
			and (
				house.model:GetAttribute("GangTag") ~= doc.tag
				or house.model:GetAttribute("GangColor") ~= doc.color
			)
		then
			paint(house, doc)
		end
	end
end

-- a new copy of a gang on this server (a purchase here or on another server, a rename): the house follows at once
local function changed(id: string, doc: any)
	local house = houses[id]
	if house and doc and not doc.disbanded then
		paint(house, doc)
		fit(house, doc)
	end
end

-- QA: which gangs have a house here ({gangId = cell})
function GangHouseService.houses(): { [string]: number }
	local out = {}
	for id, house in pairs(houses) do
		out[id] = house.cell
	end
	return out
end

function GangHouseService.Start()
	if started then
		return
	end
	started = true
	GangService.OnChanged(changed)
	LocationService.SetArrival(LOCATION, arrivalOf)
	Remotes.event("GangHome").OnServerEvent:Connect(function(player)
		if os.clock() - (lastUse[player] or -math.huge) < 1 then
			return
		end
		lastUse[player] = os.clock()
		local ok, err = pcall(goHome, player)
		if not ok then
			warn("[GangHouse] home: " .. tostring(err))
		end
	end)
	for _, part in ipairs(CollectionService:GetTagged("GangHouseExit")) do
		bindPrompt(part)
	end
	CollectionService:GetInstanceAddedSignal("GangHouseExit"):Connect(bindPrompt)
	Players.PlayerRemoving:Connect(function(player)
		warned[player] = nil
		lastUse[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(tick)
			if not ok then
				warn("[GangHouse] " .. tostring(err))
			end
		end
	end)
end

return GangHouseService
