--!strict
-- Deaths drop backpack contents (blocks, keys, mob loot…) on the ground; armor, tools and personal
-- containers (ender chest) stay in the profile [владелец 21.10].
local CollectionService = game:GetService("CollectionService")
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

local KEPT_TOOLS =
	{ pickaxe = true, shovel = true, axe = true, sword = true, shears = true, bow = true }
local ARMOR = { helmet = true, chestplate = true, leggings = true, boots = true }
local rules = Config.rules.survival.death
local DeathService = {}
local started = false

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
	if
		typeof(userId) == "number"
		and typeof(hitAt) == "number"
		and os.clock() - hitAt >= 0
		and os.clock() - hitAt <= 10
	then
		local killer = Players:GetPlayerByUserId(userId)
		if killer and killer ~= player and ProfileService.Get(killer) then
			ProfileService.Mutate(killer, function(p)
				p.stats.kills = (p.stats.kills or 0) + 1
			end)
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
					Strings.t(
						"pvp_kill_reward",
						Strings.localeOf(killer),
						money,
						player.DisplayName
					)
				)
				Remotes.event("Toast"):FireClient(
					player,
					Strings.t("pvp_death_loss", Strings.localeOf(player), money, killer.DisplayName)
				)
			end
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
			if not ARMOR[stack.id] and not (KEPT_TOOLS[stack.id] and Config.tools[stack.id]) then
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
