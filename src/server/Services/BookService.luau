--!strict
-- Ancient books [владелец 28.10: «Добавь все книги. Логику у книг. Если взять книгу в руку, можно будет нажать
-- использовать. Выйдет меню, и можно выбрать предмет, куда наложится»; GAME-DESIGN §10; вики BOOKS-SYSTEM].
--   * BookUse(sourceSlot, where, key): the book / powder / dispeller in sourceSlot goes on an inventory slot
--     (where = "inv", key = slot) or a worn armor piece (where = "armor", key = "helmet" …). Shared/Books holds the
--     rules; a book takes with its apply chance, else it tears and the item stays [клиент].
--   * The effects of the 32 books, called from CombatService (blows given and taken), BowService (arrows), DigService
--     (mining), BossService (the boss bank and stars) and the init health loop (Танк), plus the loop here: the
--     statuses on whoever was hit (character / mob attributes <Status> + <Status>Until, the HUD icons of Effects),
--     poison / wither / burning ticks, Frost and slows, Hulk, Springs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Books = require(Shared.Books)
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Effects = require(Shared.Effects)
local Potions = require(Shared.Potions)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local HungerService = require(script.Parent.HungerService)
local HurtService = require(script.Parent.HurtService)
local InventoryService = require(script.Parent.InventoryService)
local MineService = require(script.Parent.MineService)
local NeedsService = require(script.Parent.NeedsService)
local ProfileService = require(script.Parent.ProfileService)
local GangService = require(script.Parent.GangService)

local BookService = {}

local BLOCK = 4 -- studs per block
local random = Random.new()
-- [решение 28.10] durations and strengths the wiki does not give
local POISON_SECONDS = 3 -- Токсичный (GAME-DESIGN §10)
local DOT_EVERY = 1 -- poison / wither / burning: 1 HP a second
local BURN_SECONDS = 3 -- Раскалённый
local WITHER_SECONDS = 3
local WEAKNESS_SECONDS = 3
local SLOW_SECONDS = 2 -- Бульдозер
local NAUSEA_SECONDS = 3 -- Замешательство
local BLIND_SECONDS = 3
local CURSE_SECONDS, CURSE_IMMUNE = 5, 5 -- Проклятие: 5 s no healing, then 5 s immunity [вики]
local SPEED_SECONDS = 3 -- Ниндзя [вики]
local FROST_SECONDS = 3
local HASTE_LEVEL, HASTE_SECONDS = 2, 5 -- Археолог: Спешка II на 5 с (GAME-DESIGN §10)
local LIGHTNING_DAMAGE = 3 -- Громовержец
local ENLIGHTENED_HEAL = 4 -- Просвещённый: +2 сердца (GAME-DESIGN §10)
local BERSERK_BELOW = 20 -- Берсерк: below 10 hearts
local RAGE_MAX, RAGE_RESET = 10, 5 -- Ярость: up to 10 blows, the streak ends after 5 s
local FIRE_RADIUS, FIRE_SECONDS = 2 * BLOCK, 5 -- Пожар: 2 blocks, 5 s [сеть, патч 20.08.2022]
local LAYER_STATS_CAP = 200 -- Пластолом: half the layer, not above 200 [клиент]
local USE_COOLDOWN = 0.3

local STATUSES = {
	"Poison",
	"Wither",
	"Burning",
	"Frost",
	"Weakness",
	"Blindness",
	"Cursed",
	"Glowing",
	"Dazed",
	"Slowed",
	"Hunger", -- a splash potion's (PotionService)
}
local DOTS = { "Poison", "Wither", "Burning" }

local tracked: { [Model]: boolean } = {}
local nextTick: { [Model]: { [string]: number } } = {}
local cursedHealth: { [Humanoid]: number } = {}
local rage: { [Player]: { target: Model, stacks: number, at: number } } = {}
local lastUse: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function roll(chance: number): boolean
	return chance > 0 and random:NextNumber() < chance
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- the level of a status on a model while it lasts (0 = none)
function BookService.active(model: Instance?, status: string): number
	if not model then
		return 0
	end
	local level = model:GetAttribute(status)
	local ends = model:GetAttribute(status .. Effects.UNTIL)
	if typeof(level) == "number" and level > 0 and typeof(ends) == "number" and ends > now() then
		return level
	end
	return 0
end

local function humanoidOf(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root else nil
end

-- healing is undone while Проклятие lasts (food, regeneration, vampirism alike)
local function watchCurse(humanoid: Humanoid)
	if cursedHealth[humanoid] then
		return
	end
	cursedHealth[humanoid] = humanoid.Health
	humanoid.HealthChanged:Connect(function(health: number)
		local last = cursedHealth[humanoid] or health
		local model = humanoid.Parent
		if health > last and health > 0 and BookService.active(model, "Cursed") > 0 then
			humanoid.Health = last
			return
		end
		cursedHealth[humanoid] = health
	end)
	humanoid.Destroying:Connect(function()
		cursedHealth[humanoid] = nil
	end)
end

-- a status on whoever was hit; a boss casting a skill takes none
local function setStatus(model: Model, status: string, level: number, seconds: number, by: Player?)
	if model:GetAttribute("Shielded") == true then
		return
	end
	-- Frost is given its new stack count; the others keep the stronger level
	local value = if status == "Frost"
		then level
		else math.max(level, BookService.active(model, status))
	model:SetAttribute(status, value)
	model:SetAttribute(status .. Effects.UNTIL, now() + seconds)
	if by then
		model:SetAttribute(status .. "By", by.UserId)
	end
	tracked[model] = true
	local root = rootOf(model)
	if status == "Burning" and root and not root:FindFirstChild("BookFire") then
		local fire = Instance.new("Fire")
		fire.Name = "BookFire"
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = root
	elseif status == "Glowing" and not model:FindFirstChild("BookGlow") then
		local glow = Instance.new("Highlight")
		glow.Name = "BookGlow"
		glow.FillTransparency = 1
		glow.OutlineColor = Color3.fromRGB(255, 255, 255)
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Parent = model
	elseif status == "Cursed" then
		local humanoid = humanoidOf(model)
		if humanoid then
			watchCurse(humanoid)
		end
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and status == "Frost" then
		NeedsService.Refresh(victim)
	end
end

-- Nausea / Slowness / Speed on a player go through the needs effects (one place sets them); a mob is dazed or
-- slowed instead
local function playerEffect(model: Model, effect: string, level: number, seconds: number)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		NeedsService.GiveEffect(victim, effect, level, seconds)
	elseif not CollectionService:HasTag(model, "Boss") then
		if effect == "slowness" then
			setStatus(model, "Slowed", level, seconds)
		elseif effect == "nausea" then
			setStatus(model, "Dazed", 1, seconds / 2)
		end
	end
end

local function heal(model: Model, amount: number)
	local humanoid = humanoidOf(model)
	if humanoid and humanoid.Health > 0 and amount > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- PvP rules of CombatService.HitModel for the side damage of a book (lightning, fire): the location allows it for
-- both and they are not one faction
local function mayHurt(attacker: Player, model: Model): boolean
	local victim = Players:GetPlayerFromCharacter(model)
	if not victim then
		return true
	end
	if victim == attacker then
		return false
	end
	local mine, theirs = ProfileService.Get(attacker), ProfileService.Get(victim)
	if not mine or not theirs then
		return false
	end
	local a, b = Config.location(mine.location), Config.location(theirs.location)
	local sameFaction = mine.faction ~= nil and theirs.faction == mine.faction
		or GangService.allies(attacker, victim) -- one gang with its PvP off
	return a ~= nil and a.pvp == true and b ~= nil and b.pvp == true and not sameFaction
end

local function sideDamage(attacker: Player, model: Model, amount: number)
	local humanoid = humanoidOf(model)
	if humanoid and humanoid.Health > 0 and mayHurt(attacker, model) then
		humanoid:SetAttribute("LastHitBy", attacker.UserId)
		humanoid:SetAttribute("LastHitAt", os.clock())
		HurtService.Damage(humanoid, amount)
	end
end

-- Громовержец: a bolt from the sky onto the target
local function lightning(attacker: Player, model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	local height = 60
	local bolt = Instance.new("Part")
	bolt.Name = "BookLightning"
	bolt.Anchored, bolt.CanCollide, bolt.CanQuery, bolt.CanTouch = true, false, false, false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(190, 220, 255)
	bolt.Size = Vector3.new(0.6, height, 0.6)
	bolt.CFrame = CFrame.new(root.Position + Vector3.new(0, height / 2 - 2, 0))
	bolt.Parent = workspace
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 24, 6, bolt.Color
	light.Parent = bolt
	task.delay(0.25, function()
		bolt:Destroy()
	end)
	sideDamage(attacker, model, LIGHTNING_DAMAGE)
end

-- every model a fire zone or a status can reach: players, mobs, bosses
local function livingModels(): { Model }
	local out: { Model } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(out, player.Character)
		end
	end
	for _, tag in ipairs({ "Mob", "Boss" }) do
		for _, model in ipairs(CollectionService:GetTagged(tag)) do
			if model:IsA("Model") then
				table.insert(out, model)
			end
		end
	end
	return out
end

-- Пожар: a ring of fire round the target for 5 s; anyone in it (not the shooter) burns
local function fireZone(attacker: Player, model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	local center = root.Position - Vector3.new(0, 2.5, 0)
	local floor = Instance.new("Part")
	floor.Name = "BookFireZone"
	floor.Shape = Enum.PartType.Cylinder
	floor.Anchored, floor.CanCollide, floor.CanQuery, floor.CanTouch = true, false, false, false
	floor.Material = Enum.Material.Neon
	floor.Color = Color3.fromRGB(255, 110, 20)
	floor.Transparency = 0.55
	floor.Size = Vector3.new(0.2, FIRE_RADIUS * 2, FIRE_RADIUS * 2)
	floor.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Parent = workspace
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local spot = Instance.new("Attachment")
		spot.Position =
			Vector3.new(0, math.cos(a) * FIRE_RADIUS * 0.7, math.sin(a) * FIRE_RADIUS * 0.7)
		spot.Parent = floor
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 5, 9
		fire.Parent = spot
	end
	task.spawn(function()
		local ends = os.clock() + FIRE_SECONDS
		while os.clock() < ends and floor.Parent do
			for _, other in ipairs(livingModels()) do
				local otherRoot = rootOf(other)
				if
					other ~= attacker.Character
					and otherRoot
					and ((otherRoot.Position - center) * Vector3.new(1, 0, 1)).Magnitude <= FIRE_RADIUS
					and math.abs(otherRoot.Position.Y - center.Y) < 8
					and mayHurt(attacker, other)
				then
					setStatus(other, "Burning", 1, 2, attacker)
				end
			end
			task.wait(0.5)
		end
		floor:Destroy()
	end)
end

-- A splash potion bursts at `center` [вики POTIONS.md, ванильный радиус]: its bad effects on everyone in the radius
-- that the thrower may hurt (players under the PvP rules, mobs; not the thrower); the closer, the longer [ваниль]
function BookService.Splash(
	attacker: Player,
	center: Vector3,
	radius: number,
	effects: { { id: string, seconds: number } }
)
	for _, model in ipairs(livingModels()) do
		local root = rootOf(model)
		local humanoid = humanoidOf(model)
		if
			model == attacker.Character
			or not root
			or not humanoid
			or humanoid.Health <= 0
			or not mayHurt(attacker, model)
		then
			continue
		end
		local distance = (root.Position - center).Magnitude
		if distance > radius * BLOCK then
			continue
		end
		local share = 1 - 0.75 * distance / (radius * BLOCK)
		local player = Players:GetPlayerFromCharacter(model)
		for _, effect in ipairs(effects) do
			local seconds = effect.seconds * share
			if effect.id == "slowness" then
				playerEffect(model, "slowness", 1, seconds)
			elseif effect.id == "hunger" then
				if player then
					setStatus(model, "Hunger", 1, seconds, attacker)
				end
			elseif effect.id == "blindness" then
				setStatus(model, "Blindness", 1, seconds, attacker)
			elseif effect.id == "weakness" then
				setStatus(model, "Weakness", 1, seconds, attacker)
			end
		end
	end
end

-- ---------------------------------------------------------------- combat: blows given
export type Hit = { boxer: boolean }

-- the damage of a blow after the weapon's books (before it lands): Берсерк, Боксёр, Ярость, and the attacker's
-- Слабость
function BookService.outgoing(
	attacker: Player,
	weapon: Types.ItemStack?,
	model: Model,
	damage: number
): (number, Hit)
	local hit: Hit = { boxer = false }
	local character = attacker.Character
	local humanoid = character and humanoidOf(character)
	-- Сила: +3 per level [ваниль] (a potion, the random event)
	damage += Potions.STRENGTH_DAMAGE * Effects.level(character, "Strength")
	if character and BookService.active(character, "Weakness") > 0 then
		damage *= 1 - Effects.WEAKNESS
	end
	if humanoid and humanoid.Health < BERSERK_BELOW and roll(Books.value(weapon, "berserk")) then
		damage *= 2
	end
	if roll(Books.value(weapon, "boxer")) then
		damage *= 1.5
		hit.boxer = true
	end
	local step = Books.value(weapon, "rage")
	if step > 0 then
		local streak = rage[attacker]
		local t = os.clock()
		if streak and streak.target == model and t - streak.at < RAGE_RESET then
			damage *= 1 + step * streak.stacks
			streak.stacks = math.min(RAGE_MAX, streak.stacks + 1)
			streak.at = t
		else
			rage[attacker] = { target = model, stacks = 1, at = t }
		end
	end
	return damage, hit
end

-- after a blow landed (dealt > 0): the weapon's effects on the target and the attacker's helmet (Обжора)
function BookService.afterHit(
	attacker: Player,
	profile: Types.Profile,
	weapon: Types.ItemStack?,
	model: Model,
	dealt: number,
	look: Vector3,
	ranged: boolean,
	hit: Hit?
)
	if dealt <= 0 then
		return
	end
	local target = humanoidOf(model)
	local alive = target ~= nil and target.Health > 0
	local isBoss = CollectionService:HasTag(model, "Boss")
	-- Вампиризм: «Лечит на %s от нанесённого урона» — every blow
	local vampirism = Books.value(weapon, "vampirism")
	if vampirism > 0 and attacker.Character then
		heal(attacker.Character, dealt * vampirism)
	end
	if roll(Books.value(profile.armor and profile.armor.helmet, "glutton")) then
		HungerService.Feed(attacker, 1, 0)
	end
	if not alive then
		return
	end
	if roll(Books.value(weapon, "toxic")) then
		setStatus(model, "Poison", 1, POISON_SECONDS, attacker)
	end
	if roll(Books.value(weapon, "thor")) then
		lightning(attacker, model)
	end
	if roll(Books.value(weapon, "confusion")) then
		playerEffect(model, "nausea", 1, NAUSEA_SECONDS)
	end
	if roll(Books.value(weapon, "blindness")) then
		if Players:GetPlayerFromCharacter(model) then
			setStatus(model, "Blindness", 1, BLIND_SECONDS, attacker)
		elseif not isBoss then
			setStatus(model, "Dazed", 1, BLIND_SECONDS / 2)
		end
	end
	if
		roll(Books.value(weapon, "curse"))
		and BookService.active(model, "CurseImmune") <= 0
		and BookService.active(model, "Cursed") <= 0
	then
		setStatus(model, "Cursed", 1, CURSE_SECONDS, attacker)
		model:SetAttribute("CurseImmune", 1)
		model:SetAttribute("CurseImmune" .. Effects.UNTIL, now() + CURSE_SECONDS + CURSE_IMMUNE)
	end
	if roll(Books.value(weapon, "vortex")) then
		HurtService.Knockback(model, look, 1.9, 1.2)
		playerEffect(model, "nausea", 1, 2)
	elseif hit and hit.boxer then
		HurtService.Knockback(model, look, 1, 2.4)
	end
	if ranged then
		local cap = Books.value(weapon, "frost")
		if cap > 0 and not isBoss then
			local stacks = math.floor(cap / Effects.FROST_PER_STACK + 0.5)
			setStatus(
				model,
				"Frost",
				math.min(stacks, BookService.active(model, "Frost") + 1),
				FROST_SECONDS,
				attacker
			)
		end
		if roll(Books.value(weapon, "fire")) then
			fireZone(attacker, model)
		end
	end
end

-- Экономия: the arrow is not used up
function BookService.saveArrow(profile: Types.Profile): boolean
	return roll(Books.value(Books.held(profile), "saving"))
end

-- ---------------------------------------------------------------- combat: blows taken
-- the damage a player takes after the armor's books: Шныр dodges a player's blow, Халк takes less; the
-- attacker's Слабость (a mob's or a boss's — a player's is counted in outgoing)
function BookService.incoming(
	victim: Player,
	profile: Types.Profile,
	amount: number,
	source: string,
	attackerModel: Model?
): number
	_ = victim
	if source == "player" and roll(Books.worn(profile, "shnyr")) then
		return 0
	end
	amount *= math.max(0, 1 - Books.worn(profile, "hulk"))
	if
		source ~= "player"
		and attackerModel
		and BookService.active(attackerModel, "Weakness") > 0
	then
		amount *= 1 - Effects.WEAKNESS
	end
	return amount
end

-- after a player took a blow: Просвещённый, Ниндзя, and the armor's answers to the attacker
function BookService.afterHurt(
	victim: Player,
	profile: Types.Profile,
	dealt: number,
	attackerModel: Model?
)
	local character = victim.Character
	if dealt <= 0 or not character then
		return
	end
	local humanoid = humanoidOf(character)
	if humanoid and humanoid.Health > 0 and roll(Books.worn(profile, "enlightened")) then
		heal(character, ENLIGHTENED_HEAL)
	end
	if roll(Books.worn(profile, "ninja")) then
		NeedsService.GiveEffect(victim, "speed", 1, SPEED_SECONDS)
	end
	if not attackerModel or attackerModel == character then
		return
	end
	local attackerHumanoid = humanoidOf(attackerModel)
	if not attackerHumanoid or attackerHumanoid.Health <= 0 then
		return
	end
	if roll(Books.worn(profile, "fired")) then
		setStatus(attackerModel, "Burning", 1, BURN_SECONDS, victim)
	end
	if roll(Books.worn(profile, "wither")) then
		setStatus(attackerModel, "Wither", 1, WITHER_SECONDS, victim)
	end
	if roll(Books.worn(profile, "fortification")) then
		setStatus(attackerModel, "Weakness", 1, WEAKNESS_SECONDS, victim)
	end
	if roll(Books.worn(profile, "bulldozer")) then
		playerEffect(attackerModel, "slowness", 1, SLOW_SECONDS)
	end
	local snitch = Books.worn(profile, "snitch")
	if snitch > 0 then
		setStatus(attackerModel, "Glowing", 1, snitch, victim)
	end
end

-- Танк: extra health from the worn armor (HP)
function BookService.bonusHealth(profile: Types.Profile): number
	return Books.worn(profile, "tank") * 2
end

-- Старатель / Общак: the boss multipliers of a player with at least 35 % of the damage
function BookService.bossBonus(profile: Types.Profile, share: number): (number, number)
	if share < Books.BOSS_SHARE then
		return 1, 1
	end
	return 1 + Books.inHand(profile, "obshak"), 1 + Books.inHand(profile, "prospector")
end

-- ---------------------------------------------------------------- mining
-- Шёлковое касание: the block drops itself
function BookService.silkTouch(profile: Types.Profile): boolean
	return Books.level(Books.held(profile), "silk_touch") > 0
end

local function blockMultiplier(p: Types.Profile): number
	return (1 + p.professions.upgrades.blocks * Config.professions.upgrades.blocks)
		* Boosters.multiplier(p, "blocks")
end

-- breaks the given cells the tool can harvest; returns their drops
local function breakCells(
	mine: MineService.Mine,
	cells: { number },
	toolId: string,
	toolLevel: number
): { string }
	local broken: { string } = {}
	for _, cell in ipairs(cells) do
		local id = mine.cells[cell]
		local block = if id then Config.block(id) else nil
		if block and Config.breakTime(block, toolId, toolLevel, 0) ~= nil then
			local gone = MineService.breakBlock(mine, cell)
			if gone then
				table.insert(broken, gone)
			end
		end
	end
	return broken
end

-- after a block broke with a tool: Барыга, Археолог, Молот, Пластолом. `face` is the hit point minus the block
-- centre (which side was dug), `dropId` / `dropCount` the drop of the block itself.
function BookService.onDug(
	player: Player,
	mine: MineService.Mine,
	index: number,
	face: Vector3,
	dropId: string,
	dropCount: number
)
	local profile = ProfileService.Get(player)
	local tool = profile and Books.held(profile)
	if
		not profile
		or not tool
		or not Config.tools[tool.id]
		or not tool.books
		or #tool.books == 0
	then
		return
	end
	local toolId, toolLevel = tool.id, tool.level or 1
	local extra: { string } = {}
	local layerStats = 0
	if roll(Books.value(tool, "plastolom")) then
		-- the whole layer the block was in (the player stands on it while digging down)
		local _, y = MineService.coords(mine, index)
		local cells: { number } = {}
		for z = 1, mine.size[3] do
			for x = 1, mine.size[1] do
				table.insert(cells, MineService.index(mine, x, y, z))
			end
		end
		local broken = breakCells(mine, cells, toolId, toolLevel)
		layerStats = math.min(LAYER_STATS_CAP, math.floor(#broken / 2))
	elseif roll(Books.value(tool, "hammer")) then
		-- 3×3 across the dug face
		local x, y, z = MineService.coords(mine, index)
		local ax = math.abs(face.X)
		local ay = math.abs(face.Y)
		local az = math.abs(face.Z)
		local cells: { number } = {}
		for a = -1, 1 do
			for b = -1, 1 do
				if a ~= 0 or b ~= 0 then
					local cx, cy, cz = x, y, z
					if ay >= ax and ay >= az then
						cx, cz = x + a, z + b
					elseif ax >= az then
						cy, cz = y + a, z + b
					else
						cx, cy = x + a, y + b
					end
					if
						cx >= 1
						and cy >= 1
						and cz >= 1
						and cx <= mine.size[1]
						and cy <= mine.size[2]
						and cz <= mine.size[3]
					then
						table.insert(cells, MineService.index(mine, cx, cy, cz))
					end
				end
			end
		end
		extra = breakCells(mine, cells, toolId, toolLevel)
	end
	local copy = roll(Books.value(tool, "trader"))
	if copy or #extra > 0 or layerStats > 0 then
		ProfileService.Mutate(player, function(p)
			local mult = blockMultiplier(p)
			if copy then
				InventoryService.add(p, dropId, dropCount)
			end
			for _, id in ipairs(extra) do
				local block = Config.block(id)
				InventoryService.add(p, if block and block.dropsAs then block.dropsAs else id, 1)
			end
			local counted = #extra + layerStats
			p.blocksTotal += mult * counted
			p.stats.blocksClean = (p.stats.blocksClean or 0) + counted
		end)
	end
	if roll(Books.value(tool, "archaeologist")) then
		NeedsService.GiveEffect(player, "haste", HASTE_LEVEL, HASTE_SECONDS)
	end
end

-- ---------------------------------------------------------------- applying
local function take(p: Types.Profile, slot: number)
	local stack = p.inventory[slot]
	if stack then
		stack.count -= 1
		if stack.count <= 0 then
			p.inventory[slot] = nil
		end
	end
end

local function onUse(player: Player, sourceSlot: any, where: any, key: any)
	local t = os.clock()
	if t - (lastUse[player] or 0) < USE_COOLDOWN then
		return
	end
	lastUse[player] = t
	if
		typeof(sourceSlot) ~= "number"
		or sourceSlot % 1 ~= 0
		or (where ~= "inv" and where ~= "armor")
		or (where == "inv" and (typeof(key) ~= "number" or key % 1 ~= 0 or key == sourceSlot))
		or (where == "armor" and (typeof(key) ~= "string" or not table.find(Books.ARMOR, key)))
	then
		return
	end
	local result: string? = nil
	local args: { any } = {}
	local locale = Strings.localeOf(player)
	ProfileService.Mutate(player, function(p)
		local source = p.inventory[sourceSlot]
		local target: Types.ItemStack? = if where == "inv"
			then p.inventory[key :: number]
			else p.armor and p.armor[key :: string]
		if not source or not target or not Books.isUsable(source.id) then
			return
		end
		local refusal = Books.refusalFor(source, target)
		if refusal then
			result = refusal
			return
		end
		if source.id == Books.BOOK then
			local book = (source.books :: { { id: string, level: number } })[1]
			local chance = source.applyChance or 100
			take(p, sourceSlot)
			if random:NextInteger(1, 100) <= chance then
				local books = table.clone(target.books or {})
				table.insert(books, { id = book.id, level = book.level })
				target.books = books
				result = "book_applied"
				args = {
					Strings.t("book_" .. book.id, locale),
					Strings.itemFullName(target.id, target.level, locale),
				}
			else
				result = "book_torn"
			end
		elseif source.id == Books.POWDER then
			local chance = math.min(100, (target.applyChance or 100) + Books.POWDER_STEP)
			take(p, sourceSlot)
			target.applyChance = chance
			result = "book_powdered"
			args = { chance }
		else
			take(p, sourceSlot)
			target.books = {}
			result = "book_dispelled"
			args = { Strings.itemFullName(target.id, target.level, locale) }
		end
	end)
	if result then
		toast(player, result, table.unpack(args))
		Remotes.event("BookResult"):FireClient(player, result)
	end
end

-- ---------------------------------------------------------------- the loop
local function tickModel(model: Model, t: number)
	local humanoid = humanoidOf(model)
	if not model.Parent or not humanoid then
		tracked[model], nextTick[model] = nil, nil
		return
	end
	local ticks = nextTick[model] or {}
	nextTick[model] = ticks
	local any = false
	for _, status in ipairs(STATUSES) do
		local level = model:GetAttribute(status)
		if level ~= nil then
			if BookService.active(model, status) > 0 then
				any = true
			else
				model:SetAttribute(status, nil)
				model:SetAttribute(status .. Effects.UNTIL, nil)
				model:SetAttribute(status .. "By", nil)
				ticks[status] = nil
				if status == "Burning" then
					local root = rootOf(model)
					local fire = root and root:FindFirstChild("BookFire")
					if fire then
						fire:Destroy()
					end
				elseif status == "Glowing" then
					local glow = model:FindFirstChild("BookGlow")
					if glow then
						glow:Destroy()
					end
				elseif status == "Frost" then
					local victim = Players:GetPlayerFromCharacter(model)
					if victim then
						NeedsService.Refresh(victim)
					end
				end
			end
		end
	end
	if humanoid.Health > 0 then
		for _, status in ipairs(DOTS) do
			-- Огнестойкость: no burning [ваниль]
			if
				BookService.active(model, status) > 0
				and not (status == "Burning" and Effects.level(model, "FireResistance") > 0)
			then
				local due = ticks[status] or (t + DOT_EVERY)
				ticks[status] = due
				if t >= due then
					ticks[status] = due + DOT_EVERY
					-- Poison never kills [ваниль]; Wither and fire do
					local amount = if status == "Poison"
						then math.min(1, humanoid.Health - 1)
						else 1
					local by = model:GetAttribute(status .. "By")
					if typeof(by) == "number" then
						humanoid:SetAttribute("LastHitBy", by)
						humanoid:SetAttribute("LastHitAt", os.clock())
					end
					if amount > 0 then
						HurtService.Damage(humanoid, amount)
					end
				end
			end
		end
	end
	-- a mob's walk speed: Frost stacks and Бульдозер's slow (players: NeedsService)
	if CollectionService:HasTag(model, "Mob") then
		local base = model:GetAttribute("BaseWalkSpeed")
		if typeof(base) ~= "number" then
			base = humanoid.WalkSpeed
			model:SetAttribute("BaseWalkSpeed", base)
		end
		local factor = math.max(
			0.1,
			1 - Effects.FROST_PER_STACK * BookService.active(model, "Frost")
		) * (if BookService.active(model, "Slowed") > 0 then 1 - Effects.SLOWNESS_PER_LEVEL else 1)
		humanoid.WalkSpeed = (base :: number) * factor
	end
	if not any then
		tracked[model], nextTick[model] = nil, nil
	end
end

-- The jump height of every player: one block [владелец 28.10: «обычный прыжок не выше 1 блока»], higher with the
-- boots book Пружины
local function springs(player: Player, profile: Types.Profile)
	local character = player.Character
	local humanoid = character and humanoidOf(character)
	if not humanoid then
		return
	end
	-- the ordinary jump is one block [владелец 28.10]; Пружины add theirs
	local height = (Config.rules.combat.jumpBlocks or 1.05) * BLOCK
		+ Books.worn(profile, "springs") * BLOCK
	if humanoid.UseJumpPower then
		local power = math.sqrt(2 * workspace.Gravity * height)
		if math.abs(humanoid.JumpPower - power) > 0.01 then
			humanoid.JumpPower = power
		end
	elseif math.abs(humanoid.JumpHeight - height) > 0.01 then
		humanoid.JumpHeight = height
	end
end

function BookService.Start()
	Remotes.event("BookUse").OnServerEvent:Connect(onUse)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player], rage[player] = nil, nil
	end)
	task.spawn(function()
		local hulkWorn: { [Player]: boolean } = {}
		while true do
			task.wait(0.25)
			local t = now()
			for model in pairs(tracked) do
				tickModel(model, t)
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = ProfileService.Get(player)
				if profile then
					springs(player, profile)
					local hulk = Books.worn(profile, "hulk") > 0
					if hulk ~= (hulkWorn[player] == true) then
						hulkWorn[player] = hulk
						NeedsService.Refresh(player)
					end
				end
			end
			for player in pairs(hulkWorn) do
				if not player.Parent then
					hulkWorn[player] = nil
				end
			end
		end
	end)
end

return BookService
