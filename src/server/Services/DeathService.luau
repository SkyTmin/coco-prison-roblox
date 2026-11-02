--!strict
-- Deaths drop backpack contents (blocks, keys, mob loot…) on the ground; armor, tools and personal
-- containers (ender chest) stay in the profile [владелец 21.10].
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local GangService = require(script.Parent.GangService)
local ItemDropService = require(script.Parent.ItemDropService)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Numbers = require(Shared.Numbers)
local Persistence = require(Shared.Persistence)

local KEPT_TOOLS =
	{ pickaxe = true, shovel = true, axe = true, sword = true, shears = true, bow = true }
local ARMOR = { helmet = true, chestplate = true, leggings = true, boots = true }
local rules = Config.rules.survival.death
local DeathService = {}
local started = false
local settling: { [Player]: boolean } = {}

local function kept(stack: Types.ItemStack): boolean
	return ARMOR[stack.id] == true
		or (KEPT_TOOLS[stack.id] == true and Config.tools[stack.id] ~= nil)
end

-- Called inside StorageTransferService's durable delivery transform. The reserved result of the
-- transfer in flight at death belongs to that death, not to the respawned character's new backpack.
function DeathService.HoldTransfer(profile: any, operationId: string, remaining: any)
	local state = profile.storageDeath
	for _, entry in if state then state.queue else {} do
		if entry.transferId == operationId and entry.dropItems then
			for key, stack in remaining do
				if not kept(stack) then
					table.insert(entry.drops, Persistence.copy(stack))
					remaining[key] = nil
				end
			end
			return
		end
	end
end

local function settle(player: Player)
	local profile = ProfileService.Get(player) :: any
	if not profile or not ProfileService.IsReal(player) or profile.storageTransfer then
		return
	end
	local state = profile.storageDeath
	local entry = state and state.queue[1]
	if not entry then
		return
	end
	local killer = entry.killerUserId and Players:GetPlayerByUserId(entry.killerUserId)
	local recipient = killer and ProfileService.Get(killer)
	local refund = entry.loss > 0
		and (
			not killer
			or not ProfileService.IsReal(killer)
			or not recipient
			or not Numbers.canCredit(recipient.coins, entry.loss)
		)
	if refund and not Numbers.canCredit(profile.coins, entry.loss) then
		return -- keep the money in escrow until it can fit; never truncate it
	end
	local snapshot = Persistence.copy(entry)
	local saved = ProfileService.MutateDurable(player, function(p: any)
		local current = p.storageDeath
		if not current then
			return
		end
		for index, queued in current.queue do
			if queued.id == snapshot.id then
				if refund then
					if not Numbers.canCredit(p.coins, queued.loss) then
						return -- incoming money may have filled the wallet while the write yielded
					end
					p.coins += queued.loss
				end
				table.remove(current.queue, index)
				break
			end
		end
		if #current.queue == 0 then
			p.storageDeath = nil
		end
	end)
	if not saved then
		return
	end
	local latestProfile = ProfileService.Get(player) :: any
	for _, queued in
		if latestProfile and latestProfile.storageDeath
			then latestProfile.storageDeath.queue
			else {}
	do
		if queued.id == snapshot.id then
			return -- the live transform retained an unfit refund; no output may escape yet
		end
	end
	-- Consumption is durable before any external grant. A crash after it can lose ephemeral loot,
	-- but neither a retry nor a rejoin can emit the same death twice.
	if snapshot.loss > 0 and not refund and killer and ProfileService.IsReal(killer) then
		local latest = ProfileService.Get(killer)
		if latest and Numbers.canCredit(latest.coins, snapshot.loss) then
			ProfileService.Mutate(killer, function(p)
				p.coins += snapshot.loss
			end)
			GangService.progress(killer, "pvpMoney", snapshot.loss / Config.moneyScale)
			Remotes.event("Toast"):FireClient(
				killer,
				Strings.t(
					"pvp_kill_reward",
					Strings.localeOf(killer),
					Strings.money(snapshot.loss),
					snapshot.victimName
				)
			)
			Remotes.event("Toast"):FireClient(
				player,
				Strings.t(
					"pvp_death_loss",
					Strings.localeOf(player),
					Strings.money(snapshot.loss),
					killer.DisplayName
				)
			)
		end
	end
	local pos = snapshot.position
	if pos then
		for _, stack in snapshot.drops do
			ItemDropService.SpawnLoot(stack, Vector3.new(pos[1], pos[2], pos[3]), false, player)
		end
	end
end

local function resolve(player: Player)
	if settling[player] then
		return
	end
	settling[player] = true
	local ok, err = pcall(settle, player)
	settling[player] = nil
	local profile = ProfileService.Get(player) :: any
	player:SetAttribute(
		"SharedStorageBusy",
		profile ~= nil and (profile.storageTransfer ~= nil or profile.storageDeath ~= nil)
	)
	if not ok then
		warn("[DeathService] deferred settlement: " .. tostring(err))
	end
end

local function inPvp(character: Model, profile: Types.Profile): boolean
	local location = Config.location(profile.location)
	if location and location.pvp == true then
		return true
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { character }
	overlap.MaxParts = 1
	for _, zone in ipairs(CollectionService:GetTagged("PvpZone")) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			if #workspace:GetPartsInPart(zone, overlap) > 0 then
				return true
			end
		end
	end
	return false
end

local function died(player: Player, character: Model)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	ProfileService.Mutate(player, function(p)
		p.stats.deaths = (p.stats.deaths or 0) + 1
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local userId = humanoid and humanoid:GetAttribute("LastHitBy")
	local hitAt = humanoid and humanoid:GetAttribute("LastHitAt")
	local killer: Player? = nil
	if
		typeof(userId) == "number"
		and typeof(hitAt) == "number"
		and os.clock() - hitAt >= 0
		and os.clock() - hitAt <= 10
	then
		killer = Players:GetPlayerByUserId(userId)
		if killer and killer ~= player and ProfileService.Get(killer) then
			ProfileService.Mutate(killer, function(p)
				p.stats.kills = (p.stats.kills or 0) + 1
			end)
		else
			killer = nil
		end
	end
	if (profile :: any).storageTransfer or (profile :: any).storageDeath then
		local dropItems = character:IsDescendantOf(workspace)
			and (not rules.dropInPvpOnly or inPvp(character, profile))
		local root = character:FindFirstChild("HumanoidRootPart")
		local position = if root and root:IsA("BasePart")
			then root.Position
			else character:GetPivot().Position
		ProfileService.Mutate(player, function(p: any)
			local state = p.storageDeath or { queue = {} }
			local transferId = p.storageTransfer and p.storageTransfer.id
			for _, queued in state.queue do
				if queued.transferId == transferId then
					transferId = nil -- only the first death may own this transfer's reserved inventory
				end
			end
			local entry = {
				id = HttpService:GenerateGUID(false),
				transferId = transferId,
				dropItems = dropItems,
				drops = {},
				position = { position.X, position.Y, position.Z },
				loss = if killer then math.min(p.coins, p.level * Config.moneyScale) else 0,
				killerUserId = killer and killer.UserId,
				victimName = player.DisplayName,
			}
			if dropItems then
				for slot, stack in p.inventory do
					if not kept(stack) then
						table.insert(entry.drops, Persistence.copy(stack))
						p.inventory[slot] = nil
					end
				end
			end
			p.coins -= entry.loss
			table.insert(state.queue, entry)
			p.storageDeath = state
		end)
		player:SetAttribute("SharedStorageBusy", true)
		task.spawn(function()
			if ProfileService.SaveNow(player) then
				resolve(player)
			end
		end)
		return
	end
	if killer then
		-- [владелец 22.10] the killer gets as many dollars as the victim's level, taken from the victim
		-- (no more than the victim has)
		local loss = math.min(profile.coins, profile.level * Config.moneyScale)
		if loss > 0 then
			-- gang quests «Заработать N $ на убийствах игроков»
			GangService.progress(killer, "pvpMoney", loss / Config.moneyScale)
			ProfileService.Mutate(player, function(p)
				p.coins -= loss
			end)
			ProfileService.Mutate(killer, function(p)
				p.coins += loss
			end)
			local money = Strings.money(loss)
			Remotes.event("Toast"):FireClient(
				killer,
				Strings.t("pvp_kill_reward", Strings.localeOf(killer), money, player.DisplayName)
			)
			Remotes.event("Toast"):FireClient(
				player,
				Strings.t("pvp_death_loss", Strings.localeOf(player), money, killer.DisplayName)
			)
		end
	end
	-- [владелец 21.10] every death loses the loot (only PvP deaths did before); dropInPvpOnly keeps the
	-- old rule switchable
	if
		not character:IsDescendantOf(workspace)
		or (rules.dropInPvpOnly and not inPvp(character, profile))
	then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart")
		then root.Position
		else character:GetPivot().Position
	local drops: { Types.ItemStack } = {}
	ProfileService.Mutate(player, function(p)
		for slot, stack in pairs(p.inventory) do
			if not kept(stack) then
				table.insert(drops, table.clone(stack))
				p.inventory[slot] = nil
			end
		end
	end)
	for _, stack in ipairs(drops) do
		ItemDropService.SpawnLoot(stack, position, false, player) -- on the База банды: his gang's only
	end
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.Died:Once(function()
		died(player, character)
		-- the respawn is at the prison spawn: the profile must say so, or the old PvP location stayed in force
		-- there [2-player test 27.10: two players respawned side by side, a sword swung at the pyramid boss hit
		-- the other at the spawn and «killed» him for $30]
		ProfileService.Mutate(player, function(p)
			p.location = "prison"
		end)
	end)
end

function DeathService.Start()
	if started then
		return
	end
	started = true
	ProfileService.OnLoaded(resolve)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local profile = ProfileService.Get(player) :: any
				if profile and profile.storageDeath then
					task.spawn(resolve, player)
				end
			end
			task.wait(3)
		end
	end)
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(bindCharacter, player, character)
		end)
		if player.Character then
			task.spawn(bindCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
end

return DeathService
