--!strict
-- Digging: client sends DigStart(part) then DigFinish(part). The server computes the vanilla break
-- time from the held tool and accepts DigFinish only after that time has passed (small tolerance).
-- Rewards: inventory (dropsAs), blocksTotal (× block upgrade), upgrade counters, profession xp,
-- ordinary key roll, combo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local MineService = require(script.Parent.MineService)
local ProfessionService = require(script.Parent.ProfessionService)

local MAX_DISTANCE = 10 -- studs from root to block centre (block is 4 wide)
local TOLERANCE = 0.85 -- accept finish at 85 % of the server-side break time (latency)

type Dig = { part: BasePart, generation: number, startedAt: number, needed: number }
type Combo = { count: number, lastAt: number }

local DigService = {}
local digs: { [Player]: Dig } = {}
local combos: { [Player]: Combo } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function inRange(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil
		and root:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= MAX_DISTANCE + MineService.BLOCK
end

-- Validates and returns the server-side break time, or nil (with a toast) when digging is not allowed.
local function check(player: Player, part: any): (number?, MineService.Mine?, number?)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return nil, nil, nil
	end
	local mine, i = MineService.lookup(part)
	if not mine or not i or mine.rebuilding then
		return nil, nil, nil
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return nil, nil, nil
	end
	if profile.level < mine.location.unlockLevel then
		toast(player, "level_too_low", mine.location.unlockLevel)
		return nil, nil, nil
	end
	if not inRange(player, part) then
		toast(player, "too_far")
		return nil, nil, nil
	end
	local id = mine.cells[i]
	local block = if id then Config.block(id) else nil
	if not block then
		return nil, nil, nil
	end
	local toolId, toolLevel = InventoryService.heldTool(profile)
	local needed = Config.breakTime(block, toolId, toolLevel)
	if not needed then
		if block.tool ~= "any" and toolId ~= block.tool then
			toast(player, "wrong_tool")
		else
			toast(player, "tool_too_weak")
		end
		return nil, nil, nil
	end
	if profile.needs.sleep <= 0 then
		return nil, nil, nil -- insomnia: cannot dig [вики]
	end
	local slowdown = 0
	if profile.needs.hygiene <= 0 then
		slowdown += Config.needs.hygiene.digSlowdownAtZero
	end
	return needed * (1 + slowdown), mine, i
end

local function onDigStart(player: Player, part: any)
	local needed, mine = check(player, part)
	if not needed or not mine then
		digs[player] = nil
		return
	end
	digs[player] =
		{ part = part, generation = mine.generation, startedAt = os.clock(), needed = needed }
end

local function onDigFinish(player: Player, part: any)
	local dig = digs[player]
	digs[player] = nil
	if not dig or dig.part ~= part then
		return
	end
	if os.clock() - dig.startedAt < dig.needed * TOLERANCE then
		return
	end
	local needed, mine, i = check(player, part)
	if not needed or not mine or not i or mine.generation ~= dig.generation then
		return
	end
	local blockId = MineService.breakBlock(mine, i)
	if not blockId then
		return
	end
	local block = Config.block(blockId) :: Config.Block
	local dropId = block.dropsAs or blockId

	-- combo
	local now = os.clock()
	local combo = combos[player] or { count = 0, lastAt = now }
	if now - combo.lastAt > Config.rules.combo.breakAfterIdleSeconds then
		combo.count = 0
	end
	combo.count += 1
	combo.lastAt = now
	combos[player] = combo
	local comboMult = math.min(
		Config.rules.combo.maxMultiplier,
		1
			+ math.floor(combo.count / Config.rules.combo.blocksPerStep)
				* Config.rules.combo.stepBonus
	)

	local keyFound = false
	local overflow = 0
	ProfileService.Mutate(player, function(p)
		overflow = InventoryService.add(p, dropId, 1)
		local blockMult = 1 + p.professions.upgrades.blocks * Config.professions.upgrades.blocks
		p.blocksTotal += blockMult * comboMult
		if block.upgradeCounter then
			p.counters[block.upgradeCounter] = (p.counters[block.upgradeCounter] or 0) + 1
		end
		p.needs.hygiene =
			math.max(0, p.needs.hygiene - 100 / (Config.needs.hygiene.minutesToZero * 60) * needed)
		local toolId = InventoryService.heldTool(p)
		if toolId == "pickaxe" then
			ProfessionService.addXp(p, "mason", 1)
		elseif toolId == "shovel" then
			ProfessionService.addXp(p, "surveyor", 1)
		end
		local chance = Config.keys.ordinaryKeyChancePerBlock
		p.counters["_keyPity"] = (p.counters["_keyPity"] or 0) + 1
		if math.random() < chance or p.counters["_keyPity"] >= Config.keys.ordinaryKeyPity then
			p.counters["_keyPity"] = 0
			InventoryService.add(p, "ordinary_key", 1)
			keyFound = true
		end
	end)
	if overflow > 0 then
		toast(player, "bag_full")
	end
	if keyFound then
		toast(player, "key_found")
	end
	Remotes.event("Combo")
		:FireClient(player, comboMult, combo.count % Config.rules.combo.blocksPerStep)
end

function DigService.Start()
	Remotes.event("DigStart").OnServerEvent:Connect(onDigStart)
	Remotes.event("DigFinish").OnServerEvent:Connect(onDigFinish)
	Players.PlayerRemoving:Connect(function(player)
		digs[player] = nil
		combos[player] = nil
	end)
end

return DigService
