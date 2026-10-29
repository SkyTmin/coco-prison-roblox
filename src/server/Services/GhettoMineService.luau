--!strict
-- Ghetto: mason, pass dealer and leased gang mines. All exchanges are atomic profile mutations.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boosters = require(Shared.Boosters)
local Strings = require(Shared.Strings)
local Remotes = require(Shared.Remotes)
local Profile = require(script.Parent.ProfileService)
local Inventory = require(script.Parent.InventoryService)
local Gangs = require(script.Parent.GangService)
local Locations = require(script.Parent.LocationService)
local Mines = require(script.Parent.MineService)
local Combat = require(script.Parent.CombatService)
local Service = {}
local cfg = Config.ghetto
local last: { [Player]: number } = {}
local started = false

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function rooms(): { Instance }
	local ghetto = workspace:FindFirstChild("Ghetto")
	local folder = ghetto and ghetto:FindFirstChild("GangMineRooms")
	return if folder then folder:GetChildren() else {}
end

local function enter(player: Player, gang: any)
	if Combat.inCombat(player) then
		toast(player, "teleport_in_combat", math.ceil(Combat.remainingSeconds(player)))
		return
	end
	local free: Instance? = nil
	for _, room in ipairs(rooms()) do
		local anchor = room:FindFirstChild("Anchor")
		local arrival = room:FindFirstChild("Arrival")
		if anchor and arrival and arrival:IsA("BasePart") then
			local untilAt = tonumber(anchor:GetAttribute("GangMineUntil")) or 0
			if untilAt > os.time() and anchor:GetAttribute("GangMineOwner") == gang.id then
				Locations.Request(player, "ghetto", arrival)
				return
			elseif untilAt <= os.time() then
				free = room
			end
		end
	end
	if not free then
		toast(player, "ghetto_mine_busy")
		return
	end
	local online = 0
	for _, member in ipairs(Players:GetPlayers()) do
		local doc = Gangs.gangOf(Profile.Get(member))
		if doc and doc.id == gang.id then
			online += 1
		end
	end
	if online < cfg.gangMine.minMembers then
		toast(player, "ghetto_mine_members", cfg.gangMine.minMembers)
		return
	end
	local room = free :: Instance
	local anchor = room:FindFirstChild("Anchor") :: BasePart
	local arrival = room:FindFirstChild("Arrival") :: BasePart
	local mine = Mines.get(anchor:GetAttribute("MineId") :: string)
	if not mine or mine.rebuilding then
		toast(player, "ghetto_mine_busy")
		return
	end
	local used = false
	Profile.Mutate(player, function(p)
		used = Inventory.remove(p, "gang_mine_pass", 1) == 1
	end)
	if not used then
		toast(player, "ghetto_mine_pass_needed")
		return
	end
	anchor:SetAttribute("GangMineOwner", gang.id)
	anchor:SetAttribute("GangMineUntil", os.time() + cfg.gangMine.seconds)
	mine.dug = math.max(1, mine.dug)
	mine.resetAt = os.clock()
	toast(player, "ghetto_mine_open", cfg.gangMine.seconds / 60)
	Locations.Request(player, "ghetto", arrival)
end

local function act(player: Player, tag: string)
	local p = Profile.Get(player)
	local gang = Gangs.gangOf(p)
	if not p or not gang or Gangs.level(p, "ghetto") < 1 then
		toast(player, "gang_location_need_gang")
		return
	end
	if tag == "GhettoMineGate" then
		enter(player, gang)
	elseif tag == "GhettoMineExit" then
		Locations.Request(player, "ghetto")
	elseif tag == "GhettoMason" then
		local rewarded, full, progress = false, false, 0
		Profile.Mutate(player, function(profile)
			progress = math.clamp(profile.stats.ghettoMasonStones or 0, 0, cfg.mason.count)
			local need = cfg.mason.count - progress
			local stone = Inventory.remove(profile, "stone", need)
			local cobble = Inventory.remove(profile, "cobblestone", need - stone)
			progress += stone + cobble
			if progress == cfg.mason.count then
				full = Boosters.storedCount(profile) >= Config.boosters.maxStored
				if not full then
					Boosters.store(profile, "blocks", "local", cfg.mason.mult, cfg.mason.minutes)
					progress, rewarded = 0, true
				end
			end
			profile.stats.ghettoMasonStones = progress
		end)
		if rewarded then
			toast(player, "ghetto_mason_reward")
		elseif full then
			toast(player, "ghetto_mason_full")
		else
			toast(player, "ghetto_mason_progress", progress, cfg.mason.count)
		end
	elseif tag == "GhettoPassDealer" then
		local result = "ghetto_pass_ore"
		Profile.Mutate(player, function(profile)
			if Inventory.count(profile, "iron_ore") < cfg.gangMine.passOre then
				return
			end
			if not Inventory.canAdd(profile, "gang_mine_pass", 1) then
				result = "bag_full"
				return
			end
			Inventory.remove(profile, "iron_ore", cfg.gangMine.passOre)
			Inventory.add(profile, "gang_mine_pass", 1)
			result = "ghetto_pass_received"
		end)
		toast(player, result, cfg.gangMine.passOre)
	end
end

local function bind(part: Instance, tag: string)
	if not part:IsA("BasePart") or part:FindFirstChild("GhettoMinePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GhettoMinePrompt"
	prompt.ActionText = Strings.t("prompt_" .. tag)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.5
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character.PrimaryPart
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if
			not root
			or not humanoid
			or humanoid.Health <= 0
			or not part:IsDescendantOf(workspace)
			or (root.Position - part.Position).Magnitude > 16
		then
			return
		end
		if os.clock() - (last[player] or 0) < 0.5 then
			return
		end
		last[player] = os.clock()
		act(player, tag)
	end)
end

function Service.Start()
	if started then
		return
	end
	started = true
	for _, tag in ipairs({ "GhettoMason", "GhettoPassDealer", "GhettoMineGate", "GhettoMineExit" }) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bind(part, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			bind(part, tag)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	-- Enforce the lease after reconnects, expiry, disbanding and attempts to enter another gang's room.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ghetto = workspace:FindFirstChild("Ghetto")
			local home = ghetto and ghetto:FindFirstChild("LocationSpawn_ghetto", true)
			if not home or not home:IsA("BasePart") then
				continue
			end
			for _, room in ipairs(rooms()) do
				local bounds = room:FindFirstChild("Bounds") :: BasePart?
				local anchor = room:FindFirstChild("Anchor")
				if not bounds or not anchor then
					continue
				end
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local root = character and character.PrimaryPart
					if not root or not character then
						continue
					end
					local offset = bounds.CFrame:PointToObjectSpace(root.Position)
					local half = bounds.Size / 2
					if
						math.abs(offset.X) > half.X
						or math.abs(offset.Y) > half.Y
						or math.abs(offset.Z) > half.Z
					then
						continue
					end
					local gang = Gangs.gangOf(Profile.Get(player))
					if
						not gang
						or gang.id ~= anchor:GetAttribute("GangMineOwner")
						or (tonumber(anchor:GetAttribute("GangMineUntil")) or 0) <= os.time()
					then
						root.AssemblyLinearVelocity = Vector3.zero
						character:PivotTo(home.CFrame + Vector3.new(0, 4, 0))
					end
				end
			end
		end
	end)
end

return Service
