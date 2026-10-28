--!strict
-- The NPCs of the База банды [вики HANDBOOK-WIKI: «склад, библиотекарь и кузнец»; клиент npc.gang.*: Шнырь,
-- Библиотекарь, Кузнец; docs/research/remaining-features-design.md §1.5]. They stand there for everyone, they work
-- for members whose gang bought the upgrade (Gangs.level via GangService.level):
--   * Библиотекарь (tag GangLibrarian, upgrade «Библиотека»): an ancient book handed in (from any bag slot) adds
--     Config.gangs.base.library.rarityPoints[rarity] × the book's level to the gang's bar (gang.library, up to goal 4000
--     [владелец 28.10]); a full bar → «Забрать награду» (reward.points gang points). The book leaves the profile
--     first, then GangService.addLibrary writes the document; a refused write gives the book back.
--   * Кузнец (tag GangForge, upgrade «Кузница»): two identical books (one effect, one level) + starsPerLevel × the new
--     level ancient stars → the level + 1 with chances[level] (70 / 50 / 30 %) [решение; 2021: II+II=III за 30 звёзд];
--     a failure keeps one book, the other and the stars are gone. One Mutate: inputs and outputs change together.
--   * Шнырь (tag GangShnyr): the trip to the Гетто through LocationService (its checks: gang + the «Гетто» upgrade).
-- Client → server GangNpc(op, a, b): "library" slot | "libraryClaim" | "forge" slotA slotB. The windows: client GangNpcWindow.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemInfo = require(Shared.ItemInfo)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local GangService = require(script.Parent.GangService)
local InventoryService = require(script.Parent.InventoryService)
local LocationService = require(script.Parent.LocationService)
local GangHouse = require(script.Parent.GangHouseService)

local GangBaseService = {}
local base = Config.gangs.base
local NPC_RANGE = 16 -- the prompt shows at 10, a little slack while the window is open (as EconomyService)
local ACTION_GAP = 0.5
local random = Random.new()
local lastAction: { [Player]: number } = {}
local started = false

-- tag → the window it opens (nil = an action right away)
local NPCS: { [string]: { window: string?, prompt: string, upgrade: string? } } = {
	GangLibrarian = {
		window = "gangLibrary",
		prompt = "gang_npc_librarian",
		upgrade = base.library.upgrade,
	},
	GangForge = { window = "gangForge", prompt = "gang_npc_forge", upgrade = base.forge.upgrade },
	GangShnyr = { prompt = "gang_npc_shnyr" },
}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- next to an NPC of this tag that serves the player (a house NPC only serves the house's gang, GangHouseService)
local function nearTag(player: Player, tag: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do
		if
			npc:IsA("BasePart")
			and npc:IsDescendantOf(workspace)
			and (npc.Position - root.Position).Magnitude <= NPC_RANGE
			and GangHouse.allowed(npc, player)
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

-- the refusal for an NPC that needs a gang upgrade (nil = it works for this player)
local function upgradeRefusal(player: Player, upgrade: string?): (string?, any)
	local profile = ProfileService.Get(player)
	if not profile or not GangService.gangOf(profile) then
		return "gang_location_need_gang", nil
	end
	if upgrade and GangService.level(profile, upgrade) < 1 then
		return "gang_npc_need_upgrade", Strings.t("gang_up_" .. upgrade, Strings.localeOf(player))
	end
	return nil, nil
end

-- an ancient book stack with its one effect, or nil
local function bookOf(stack: Types.ItemStack?): (string?, number?)
	if not stack or stack.id ~= "ancient_book" or not stack.books or not stack.books[1] then
		return nil, nil
	end
	local book = stack.books[1]
	if typeof(book.id) ~= "string" or typeof(book.level) ~= "number" then
		return nil, nil
	end
	return book.id, book.level
end

-- gang points for handing a book in: rarity points × level [решение]
function GangBaseService.libraryPoints(stack: Types.ItemStack?): number
	local effect, level = bookOf(stack)
	if not effect or not level or not stack then
		return 0
	end
	local entry = Config.books.catalog[effect]
	local rarity = stack.rarity or (entry and entry.rarity) or "common"
	local points = base.library.rarityPoints[rarity] or base.library.rarityPoints.common
	return math.max(0, math.floor(points * level))
end

-- the chance and the star price of forging a book of this level one level up (nil = already at the top)
function GangBaseService.forgeOffer(effect: string, level: number): (number?, number?)
	local values = Config.books.effects[effect]
	if not values or level >= #values then
		return nil, nil
	end
	local chances = base.forge.chances
	local chance = chances[math.min(level, #chances)]
	return chance, base.forge.starsPerLevel * (level + 1)
end

local function library(player: Player, slot: any)
	if not InventoryService.isSlot(slot) or not nearTag(player, "GangLibrarian") then
		return
	end
	local refusal, arg = upgradeRefusal(player, base.library.upgrade)
	if refusal then
		toast(player, refusal, arg)
		return
	end
	local taken: Types.ItemStack? = nil
	local points = 0
	ProfileService.Mutate(player, function(p)
		local stack = p.inventory[slot]
		points = GangBaseService.libraryPoints(stack)
		if points > 0 and stack then
			taken = stack
			p.inventory[slot] = nil
		end
	end)
	local book = taken
	if not book then
		toast(player, "gang_library_need_book")
		return
	end
	local err = GangService.addLibrary(player, points)
	if not err then
		toast(player, "gang_library_added", points, base.library.goal)
		Sfx.toPlayer(player, "xp", 0.5)
		return
	end
	toast(player, err)
	-- the gang document was not written: the book comes back (its old slot if still free, else the first free one)
	local back = false
	ProfileService.Mutate(player, function(p)
		local target: number? = if p.inventory[slot] then nil else slot
		for i = 1, InventoryService.SLOTS do
			if target then
				break
			end
			if not p.inventory[i] then
				target = i
			end
		end
		if target then
			p.inventory[target] = book
			back = true
		end
	end)
	if not back then
		warn("[GangBase] a handed-in book could not be returned to " .. player.Name)
	end
	toast(player, "gang_err_try_later")
end

local function forge(player: Player, slotA: any, slotB: any)
	if
		not InventoryService.isSlot(slotA)
		or not InventoryService.isSlot(slotB)
		or slotA == slotB
		or not nearTag(player, "GangForge")
	then
		return
	end
	local refusal, arg = upgradeRefusal(player, base.forge.upgrade)
	if refusal then
		toast(player, refusal, arg)
		return
	end
	local result, resultArg = "", nil :: any
	local locale = Strings.localeOf(player)
	ProfileService.Mutate(player, function(p)
		local a, b = p.inventory[slotA], p.inventory[slotB]
		local effectA, levelA = bookOf(a)
		local effectB, levelB = bookOf(b)
		if not effectA or not levelA or effectA ~= effectB or levelA ~= levelB or not a then
			result = "gang_forge_need_pair"
			return
		end
		local chance, stars = GangBaseService.forgeOffer(effectA, levelA)
		if not chance or not stars then
			result = "gang_forge_max"
			return
		end
		if InventoryService.count(p, "ancient_star") < stars then
			result, resultArg = "gang_forge_need_stars", stars
			return
		end
		-- no yields: the stars, both books and the result change in this one step
		InventoryService.remove(p, "ancient_star", stars)
		p.inventory[slotB] = nil
		if random:NextNumber() < chance then
			local forged = table.clone(a)
			forged.books = { { id = effectA, level = levelA + 1 } }
			forged.level = levelA + 1
			forged.applyChance = math.max(a.applyChance or 0, (b and b.applyChance) or 0)
			p.inventory[slotA] = forged
			result, resultArg = "gang_forge_success", ItemInfo.bookName(effectA, levelA + 1, locale)
		else
			result = "gang_forge_failed"
		end
	end)
	if result ~= "" then
		toast(player, result, resultArg)
		if result == "gang_forge_success" then
			Sfx.toPlayer(player, "enchant", 0.6)
		elseif result == "gang_forge_failed" then
			Sfx.toPlayer(player, "tool_break", 0.6)
		end
	end
end

local function onNpc(player: Player, op: any, a: any, b: any)
	if throttled(player) or not ProfileService.Get(player) then
		return
	end
	if op == "library" then
		library(player, a)
	elseif op == "forge" then
		forge(player, a, b)
	elseif op == "libraryClaim" and nearTag(player, "GangLibrarian") then
		local refusal, arg = upgradeRefusal(player, base.library.upgrade)
		if refusal then
			toast(player, refusal, arg)
		else
			GangService.claimLibrary(player)
		end
	end
end

local function bindPrompt(part: Instance, tag: string)
	local npc = NPCS[tag]
	if not part:IsA("BasePart") or part:FindFirstChild("GangNpcPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GangNpcPrompt"
	prompt.ActionText = Strings.t(npc.prompt)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false -- the tag sits inside the rig's torso
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if not part:IsDescendantOf(workspace) then
			return
		end
		if not GangHouse.allowed(part, player) then
			toast(player, "gang_plot_foreign")
			return
		end
		if not nearTag(player, tag) then
			return
		end
		if npc.window then
			local refusal, arg = upgradeRefusal(player, npc.upgrade)
			if refusal then
				toast(player, refusal, arg) -- visible to all, works after the upgrade [дизайн §1.5]
				return
			end
			Remotes.event("OpenMenu"):FireClient(player, npc.window)
		else
			LocationService.Request(player, "ghetto") -- refusals (no gang / no «Гетто») come from LocationService
		end
	end)
end

function GangBaseService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("GangNpc").OnServerEvent:Connect(function(player, op, a, b)
		local ok, err = pcall(onNpc, player, op, a, b)
		if not ok then
			warn("[GangBase] " .. tostring(op) .. ": " .. tostring(err))
		end
	end)
	for tag in pairs(NPCS) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bindPrompt(part, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			bindPrompt(part, tag)
		end)
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return GangBaseService
