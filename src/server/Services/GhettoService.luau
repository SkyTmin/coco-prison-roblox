--!strict
-- The Гетто [вики LOCATIONS-MENU, HANDBOOK-WIKI; клиент blackmarket.*, gang.ghetto.*; docs/research/remaining-features-
-- design.md этап 1в]. Rules shared with the client: Shared/Ghetto.
--   * Торговец (tag GhettoTrader): ordinary keys and ancient stars for $ — GhettoBuy("trader", id, count 1..64).
--   * Чёрный рынок (tag BlackMarket, on the base and in the Гетто; from level minLevel): 6 goods with a stock per server
--     (refilled at start and every restockMinutes, mirrored in ReplicatedStorage.BlackMarket) — GhettoBuy("black", id).
--   * Сундук с сокровищами: every everyMinutes a chest appears at one of the points tagged TreasurePoint (a chest not
--     taken moves to another point), everyone on the server is told [клиент gang.ghetto.spawned]. Capturing = holding
--     its prompt (Shift / the button) for holdSeconds [вики: «зажать Shift и стоять до конца»]; any damage to the
--     holder breaks the hold (the client lets the prompt go on TreasureReset). The opener gets one reward of the
--     table, everyone hears «Игрок %s открыл сундук!» [клиент]; p.stats.ghettoChests counts the openings.
-- Announcements go through the toast of every player on the server (a later stage moves them into the chat).
-- QA (Studio): ServerStorage.GhettoDebug:Invoke(op, …) — ("chest") spawn the chest now → point index;
-- ("restock") refill the black market; ("capture", userId) give the chest to the player without holding;
-- ("book", userId, effect, level, rarity?) a test ancient book; ("state") → JSON.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Ghetto = require(Shared.Ghetto)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local ChatService = require(script.Parent.ChatService) -- announcements in the chat (этап 3)
local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)

local GhettoService = {}
local cfg = Ghetto.cfg
local NPC_RANGE = 16
local CHEST_RANGE = 10
local ACTION_GAP = 0.25
local random = Random.new()
local lastAction: { [Player]: number } = {}
local stock: { [string]: number } = {}
local stockFolder: Folder? = nil
local nextRestock = 0
local started = false

type Hold = { startedAt: number, endedAt: number?, connection: RBXScriptConnection }
type Treasure =
	{ model: Model, prompt: ProximityPrompt, point: BasePart, holds: { [Player]: Hold } }
local treasure: Treasure? = nil
local nextChestAt = 0
local lastPoint: BasePart? = nil

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- a message for every player on this server, each in his own language
local function announce(key: string, ...: any)
	for _, player in ipairs(Players:GetPlayers()) do
		toast(player, key, ...)
	end
	ChatService.announce(key, ...) -- and in the chat (этап 3)
end

local function units(dollars: number): number
	return math.floor(dollars * Config.moneyScale + 0.5)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function nearTag(player: Player, tag: string): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do
		if
			npc:IsA("BasePart")
			and npc:IsDescendantOf(workspace)
			and (npc.Position - root.Position).Magnitude <= NPC_RANGE
		then
			return true
		end
	end
	return false
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < ACTION_GAP then
		return true
	end
	lastAction[player] = now
	return false
end

-- ── the trader and the black market ─────────────────────────────────────────────────────────────────────────────

local function mirrorStock()
	local folder = stockFolder
	if not folder then
		return
	end
	for _, item in ipairs(Ghetto.blackItems()) do
		folder:SetAttribute(item.id, stock[item.id] or 0)
	end
	folder:SetAttribute(
		"RestockAt",
		workspace:GetServerTimeNow() + math.max(0, nextRestock - os.clock())
	)
end

local function restock()
	for _, item in ipairs(Ghetto.blackItems()) do
		stock[item.id] = random:NextInteger(item.stock[1], item.stock[2])
	end
	nextRestock = os.clock() + cfg.blackMarket.restockMinutes * 60
	mirrorStock()
end

local function buyTrader(player: Player, id: any, rawCount: any)
	local price = Ghetto.traderPrice(id)
	if not price or not nearTag(player, "GhettoTrader") then
		return
	end
	local count = if typeof(rawCount) == "number"
			and rawCount == rawCount
			and rawCount >= 1
			and rawCount <= 64
		then math.floor(rawCount)
		else 1
	local itemId = id :: string
	local result = ""
	ProfileService.Mutate(player, function(p)
		local cost = units(price) * count
		if p.coins < cost then
			result = "not_enough_money"
			return
		end
		if not InventoryService.canAdd(p, itemId, count) then
			result = "bag_full"
			return
		end
		p.coins -= cost
		InventoryService.add(p, itemId, count)
		result = "bought"
	end)
	if result == "bought" then
		toast(
			player,
			"bought",
			Strings.itemName(itemId, 1, Strings.localeOf(player)) .. " ×" .. count
		)
		Sfx.toPlayer(player, "xp", 0.4)
	elseif result ~= "" then
		toast(player, result)
	end
end

local function buyBlack(player: Player, id: any)
	local item = Ghetto.blackItem(id)
	local profile = ProfileService.Get(player)
	if not item or not profile or not nearTag(player, "BlackMarket") then
		return
	end
	if profile.level < cfg.blackMarket.minLevel then
		toast(player, "black_market_no_level", cfg.blackMarket.minLevel) -- [клиент blackmarket.error.no_level]
		return
	end
	if (stock[item.id] or 0) <= 0 then
		toast(player, "black_market_ended") -- [клиент blackmarket.item_ended]
		return
	end
	local result = ""
	ProfileService.Mutate(player, function(p)
		local cost = units(Ghetto.blackPrice(item, p.level))
		if p.coins < cost then
			result = "not_enough_money"
			return
		end
		if not InventoryService.canAdd(p, item.id, 1) then
			result = "bag_full"
			return
		end
		if (stock[item.id] or 0) <= 0 then -- no yields since the check, but keep the stock the last word
			result = "black_market_ended"
			return
		end
		stock[item.id] -= 1
		p.coins -= cost
		InventoryService.add(p, item.id, 1)
		result = "bought"
	end)
	if result == "bought" then
		mirrorStock()
		toast(player, "bought", Strings.itemName(item.id, 1, Strings.localeOf(player)))
		Sfx.toPlayer(player, "xp", 0.4)
	elseif result ~= "" then
		toast(player, result)
	end
end

local function onBuy(player: Player, kind: any, id: any, count: any)
	if throttled(player) or not ProfileService.Get(player) then
		return
	end
	if kind == "trader" then
		buyTrader(player, id, count)
	elseif kind == "black" then
		buyBlack(player, id)
	end
end

local PROMPTS: { [string]: { window: string, text: string } } = {
	GhettoTrader = { window = "ghettoTrader", text = "ghetto_trader_prompt" },
	BlackMarket = { window = "blackMarket", text = "black_market_prompt" },
}

local function bindPrompt(part: Instance, tag: string)
	if not part:IsA("BasePart") or part:FindFirstChild("GhettoPrompt") then
		return
	end
	local def = PROMPTS[tag]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GhettoPrompt"
	prompt.ActionText = Strings.t(def.text)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if not part:IsDescendantOf(workspace) or not nearTag(player, tag) then
			return
		end
		local profile = ProfileService.Get(player)
		if tag == "BlackMarket" and profile and profile.level < cfg.blackMarket.minLevel then
			toast(player, "black_market_no_level", cfg.blackMarket.minLevel)
			return
		end
		Remotes.event("OpenMenu"):FireClient(player, def.window)
	end)
end

-- ── the treasure chest ──────────────────────────────────────────────────────────────────────────────────────────

local function rollReward(): any
	local rewards = cfg.treasure.rewards
	local total = 0
	for _, r in ipairs(rewards) do
		total += r.weight
	end
	local value = random:NextNumber() * total
	for _, r in ipairs(rewards) do
		value -= r.weight
		if value < 0 then
			return r
		end
	end
	return rewards[#rewards]
end

-- a blocky wooden chest with gold bands and a beam of light over it (built at runtime: the point is any part)
local function buildChest(point: BasePart): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = point.CFrame * CFrame.new(0, point.Size.Y / 2, 0)
	local function block(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		variant: string?,
		neon: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = base * offset
		p.Anchored = true
		p.CanCollide = name == "ChestBody"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		if neon then
			p.Material = Enum.Material.Neon
		elseif variant then
			p.Material = Enum.Material.Plastic
			p.MaterialVariant = variant
		else
			p.Material = Enum.Material.Metal
		end
		p.Parent = model
		return p
	end
	local wood = Color3.fromRGB(150, 105, 60)
	local gold = Color3.fromRGB(240, 190, 60)
	local body =
		block("ChestBody", Vector3.new(4, 2.6, 3), CFrame.new(0, 1.3, 0), wood, "px_planks")
	block(
		"ChestLid",
		Vector3.new(4.1, 1, 3.1),
		CFrame.new(0, 3.1, 0),
		Color3.fromRGB(130, 90, 50),
		"px_spruce_planks"
	)
	for _, x in ipairs({ -1.4, 1.4 }) do
		block("Band", Vector3.new(0.35, 3.7, 3.2), CFrame.new(x, 1.85, 0), gold)
	end
	block("Lock", Vector3.new(0.7, 0.9, 0.3), CFrame.new(0, 2.5, -1.62), gold)
	local glow = block(
		"Glow",
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(0, 3.9, 0),
		Color3.fromRGB(255, 220, 120),
		nil,
		true
	)
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = glow
	-- the beacon: a tall thin beam the players see across the streets
	local beam = block(
		"Beacon",
		Vector3.new(0.8, 120, 0.8),
		CFrame.new(0, 64, 0),
		Color3.fromRGB(255, 210, 90),
		nil,
		true
	)
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Transparency = 0.55
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
	model.PrimaryPart = body
	model.Parent = workspace
	return model, body
end

local function clearTreasure()
	local t = treasure
	if not t then
		return
	end
	treasure = nil
	for _, hold in pairs(t.holds) do
		hold.connection:Disconnect()
	end
	t.model:Destroy()
end

local function giveReward(player: Player, at: Vector3)
	local reward = rollReward()
	local locale = Strings.localeOf(player)
	local text: string
	if reward.id == "money" then
		ProfileService.Mutate(player, function(p)
			p.coins += units(reward.dollars or 0)
			p.stats.ghettoChests = (p.stats.ghettoChests or 0) + 1
		end)
		text = Strings.money(units(reward.dollars or 0)) .. " $"
	else
		local count = reward.count or 1
		local left = 0
		ProfileService.Mutate(player, function(p)
			left = InventoryService.add(p, reward.id, count)
			p.stats.ghettoChests = (p.stats.ghettoChests or 0) + 1
		end)
		if left > 0 then -- a full bag: the rest falls next to the chest for him to pick up
			ItemDropService.SpawnLoot(
				{ id = reward.id, count = left } :: Types.ItemStack,
				at,
				false
			)
		end
		text = Strings.itemName(reward.id, 1, locale) .. (if count > 1 then " ×" .. count else "")
	end
	toast(player, "ghetto_chest_drop", text) -- [клиент gang.ghetto.chest.drop]
end

local function capture(player: Player)
	local t = treasure
	if not t then
		return
	end
	local at = t.point.Position
	clearTreasure()
	giveReward(player, at + Vector3.new(0, 3, 0))
	Sfx.toPlayer(player, "level_up", 0.6)
	announce("ghetto_chest_opened", player.DisplayName) -- [клиент gang.ghetto.chest.opened]
end

local function endHold(t: Treasure, player: Player)
	local hold = t.holds[player]
	if hold then
		hold.connection:Disconnect()
		t.holds[player] = nil
	end
end

local function spawnChest(): number?
	local points: { BasePart } = {}
	for _, part in ipairs(CollectionService:GetTagged("TreasurePoint")) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) and part ~= lastPoint then
			table.insert(points, part)
		end
	end
	if #points == 0 and lastPoint and lastPoint:IsDescendantOf(workspace) then
		table.insert(points, lastPoint)
	end
	nextChestAt = os.clock() + cfg.treasure.everyMinutes * 60
	if #points == 0 then
		return nil
	end
	clearTreasure()
	local point = points[random:NextInteger(1, #points)]
	lastPoint = point
	local model, body = buildChest(point)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TreasurePrompt"
	prompt.ActionText = Strings.t("ghetto_chest_capture")
	prompt.ObjectText = Strings.t("ghetto_chest_name")
	prompt.HoldDuration = cfg.treasure.holdSeconds
	prompt.KeyboardKeyCode = Enum.KeyCode.LeftShift -- [вики: «зажать Shift у сундука»]
	prompt.MaxActivationDistance = CHEST_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = body
	local t: Treasure = { model = model, prompt = prompt, point = point, holds = {} }
	treasure = t
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if treasure ~= t then
			return
		end
		endHold(t, player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local profile = ProfileService.Get(player)
		if not humanoid or not profile or profile.location ~= "ghetto" then
			return
		end
		local health = humanoid.Health
		t.holds[player] = {
			startedAt = os.clock(),
			-- damage breaks the capture [решение]
			connection = humanoid.HealthChanged:Connect(function(now: number)
				if now < health - 0.01 and t.holds[player] then
					endHold(t, player)
					Remotes.event("TreasureReset"):FireClient(player)
					toast(player, "ghetto_chest_interrupted")
				end
				health = now
			end),
		}
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		-- the order of HoldEnded and Triggered is not promised: the hold keeps its end time, Triggered measures it
		local hold = t.holds[player]
		if hold and not hold.endedAt then
			hold.endedAt = os.clock()
			hold.connection:Disconnect()
		end
	end)
	prompt.Triggered:Connect(function(player)
		local hold = t.holds[player]
		local root = rootOf(player)
		if
			treasure ~= t
			or not hold
			or (hold.endedAt or os.clock()) - hold.startedAt < cfg.treasure.holdSeconds - 0.35
			or not root
			or (root.Position - body.Position).Magnitude > CHEST_RANGE + 2
		then
			return
		end
		capture(player)
	end)
	announce("ghetto_chest_spawned") -- [клиент gang.ghetto.spawned]
	return table.find(CollectionService:GetTagged("TreasurePoint"), point)
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "GhettoDebug"
	hook.OnInvoke = function(op: string, a: any, b: any, c: any, d: any): any
		if op == "chest" then
			return spawnChest()
		elseif op == "restock" then
			restock()
			return HttpService:JSONEncode(stock)
		elseif op == "capture" then
			local player = Players:GetPlayerByUserId(a)
			if player and treasure then
				capture(player)
				return true
			end
			return false
		elseif op == "book" then
			local player = Players:GetPlayerByUserId(a)
			local entry = Config.books.catalog[b]
			if not player or not Config.books.effects[b] then
				return false
			end
			local level = math.clamp(tonumber(c) or 1, 1, #Config.books.effects[b])
			local given = false
			ProfileService.Mutate(player, function(p)
				for slot = 1, InventoryService.SLOTS do
					if not p.inventory[slot] then
						p.inventory[slot] = {
							id = "ancient_book",
							count = 1,
							level = level,
							books = { { id = b, level = level } },
							rarity = d or (entry and entry.rarity) or "common",
							applyChance = 50,
						}
						given = true
						return
					end
				end
			end)
			return given
		elseif op == "state" then
			local t = treasure
			return HttpService:JSONEncode({
				stock = stock,
				restockIn = math.floor(nextRestock - os.clock()),
				chest = if t then t.point:GetFullName() else nil,
				nextChestIn = math.floor(nextChestAt - os.clock()),
				points = #CollectionService:GetTagged("TreasurePoint"),
			})
		end
		return nil
	end
	hook.Parent = ServerStorage
end

function GhettoService.Start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = Ghetto.STOCK_FOLDER
	folder.Parent = ReplicatedStorage
	stockFolder = folder
	restock()
	Remotes.event("TreasureReset")
	Remotes.event("GhettoBuy").OnServerEvent:Connect(function(player, kind, id, count)
		local ok, err = pcall(onBuy, player, kind, id, count)
		if not ok then
			warn("[Ghetto] buy: " .. tostring(err))
		end
	end)
	for tag in pairs(PROMPTS) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bindPrompt(part, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			bindPrompt(part, tag)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		local t = treasure
		if t then
			endHold(t, player)
		end
	end)
	nextChestAt = os.clock() + cfg.treasure.firstAfterMinutes * 60
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				if os.clock() >= nextRestock then
					restock()
				end
				if os.clock() >= nextChestAt then
					spawnChest()
				end
			end)
			if not ok then
				warn("[Ghetto] tick: " .. tostring(err))
			end
		end
	end)
	debugHook()
end

return GhettoService
