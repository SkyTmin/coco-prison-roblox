--!strict
-- DigService / future MobService should call MarkHit after validated damage to a player.
-- Pass the attacker kind: player/boss hits lock teleport; ordinary mob hits do not.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local BookService = require(script.Parent.BookService)
local ProfileService = require(script.Parent.ProfileService)
local GangService = require(script.Parent.GangService)
local InventoryService = require(script.Parent.InventoryService)
local HurtService = require(script.Parent.HurtService)
local MotionService = require(script.Parent.MotionService)
local TrainerService = require(script.Parent.TrainerService)
local Combat = require(Shared.Combat)
local BossDamage = require(script.Parent.BossDamage)
local DamageImmunity = require(script.Parent.DamageImmunity)
local Effects = require(Shared.Effects)
local Ladders = require(Shared.Ladders)
local Cobweb = require(Shared.Cobweb)
local Types = require(Shared.Types)

local CombatService = {}
local lastCombat: { [Player]: number } = {}
local started = false

function CombatService.MarkHit(player: Player, source: "player" | "boss" | "mob", attacker: Player?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetAttribute(
			"LastHitBy",
			if source == "player" and attacker then attacker.UserId else nil
		)
		humanoid:SetAttribute("LastHitAt", os.clock())
	end
	if source ~= "player" and source ~= "boss" then
		return
	end
	local now = os.clock()
	lastCombat[player] = now
	player:SetAttribute("LastCombatAt", now)
end

-- Validated combat callers use this entry point so attribution precedes a lethal hit. attackerModel (a mob or a
-- boss; a player's character by default) is who the armor books answer (BookService.afterHurt).
function CombatService.ApplyDamage(
	humanoid: Humanoid,
	amount: number,
	source: "player" | "boss" | "mob",
	attacker: Player?,
	attackerModel: Model?,
	dodgeable: boolean?,
	impactContext: any?
): (boolean, number, string)
	if amount ~= amount or amount <= 0 or amount == math.huge or humanoid.Health <= 0 then
		return false, 0, "protected"
	end
	local character = humanoid.Parent
	if
		character
		and not CollectionService:HasTag(character, "Boss")
		and (
			character:FindFirstChildOfClass("ForceField")
			or character:GetAttribute("Shielded") == true
		)
	then
		return false, 0, "protected"
	end
	local victim = if character and character:IsA("Model")
		then Players:GetPlayerFromCharacter(character)
		else nil
	local victimProfile = if victim then ProfileService.Get(victim) else nil
	if
		dodgeable ~= false
		and victimProfile
		and math.random() < TrainerService.dodgeChance(victimProfile)
	then
		return false, 0, "dodged" -- consumes neither health nor the target's hurt-immunity window
	end
	amount = DamageImmunity.Accept(humanoid, amount)
	if amount <= 0 then
		return false, 0, "cooldown"
	end
	local by = attackerModel or (if attacker then attacker.Character else nil)
	local byRoot = by and (by:FindFirstChild("HumanoidRootPart") or by.PrimaryPart)
	local context = impactContext or {}
	if not context.from and byRoot and byRoot:IsA("BasePart") then
		context.from = byRoot.Position
	end
	local beforeHealth = humanoid.Health
	local beforeGolden = if character
		then tonumber(character:GetAttribute("AbsorptionHealth")) or 0
		else 0
	local function outcome(): (boolean, number, string)
		local afterGolden = if character
			then tonumber(character:GetAttribute("AbsorptionHealth")) or 0
			else 0
		local dealt = math.max(0, beforeHealth - humanoid.Health + beforeGolden - afterGolden)
		return dealt > 0, dealt, if dealt > 0 then "hit" else "protected"
	end
	if victim then
		CombatService.MarkHit(victim, source, attacker)
		-- worn armor and Protection soften blows from players, mobs and bosses [ваниль]
		local profile = victimProfile
		amount = Combat.armorReduce(amount, profile and profile.armor)
		if profile then
			-- the armor's ancient books: Шныр, Халк, and the answers to the attacker
			amount = BookService.incoming(victim, profile, amount, source, by)
			if source == "boss" then
				amount = BossDamage.Limit(humanoid, amount)
			end
			local before = humanoid.Health
			HurtService.Damage(humanoid, amount, context)
			BookService.afterHurt(victim, profile, before - humanoid.Health, by)
			return outcome()
		end
		if source == "boss" then
			amount = BossDamage.Limit(humanoid, amount)
		end
	else
		humanoid:SetAttribute(
			"LastHitBy",
			if source == "player" and attacker then attacker.UserId else nil
		)
		humanoid:SetAttribute("LastHitAt", os.clock())
	end
	HurtService.Damage(humanoid, amount, context)
	return outcome()
end

function CombatService.remainingSeconds(player: Player): number
	local last = lastCombat[player]
	return if last
		then math.max(0, Config.rules.teleport.combatLockSeconds - (os.clock() - last))
		else 0
end

function CombatService.inCombat(player: Player): boolean
	return CombatService.remainingSeconds(player) > 0
end

-- Weapon in hand → base damage and attack speed (Minecraft Java) [ваниль]; sword enchant = Sharpness.
local function weapon(profile): (number, number)
	local toolId, level = InventoryService.heldTool(profile)
	local vanilla = Config.vanilla
	if not toolId then
		return vanilla.handDamage or 1, 0
	end
	local material = Config.materialForLevel(level)
	local damage = 1
	local enchant = 0
	if toolId == "sword" then
		damage = vanilla.swordDamage[material]
		enchant = Config.sharpnessBonus(Config.enchantPower("sword", level))
	elseif vanilla.toolDamage and vanilla.toolDamage[toolId] then
		damage = vanilla.toolDamage[toolId][material]
	end
	return damage, enchant
end

-- Better Combat-style melee [владелец 22.10]: the attack hits along an arc in front of the player, measured
-- to the target's bounding box (not a thin ray to its exact mesh — the boss was hard to hit), after the
-- weapon's upswing (the moment the animation reaches the blow). Reach = 3 blocks + the weapon bonus
-- [ваниль, Better Combat]. Every target inside the arc is hit; the combo picks the attack of the set.
local combos: { [Player]: Combat.ComboState } = {}

-- `at`: the server time the attacker was looking at (MotionService.viewTime) — players are tested where they were
-- drawn then (lag compensation); nil = their newest reported place.
function CombatService.targetBox(model: Model, at: number?): (CFrame, Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local player = Players:GetPlayerFromCharacter(model)
	if humanoid and root and root:IsA("BasePart") and player then
		-- a player: the standard character box around the root (accessories would inflate the bounds), where
		-- their own client put it (MotionService) at that moment, when its reports are fresh
		local cf = MotionService.rootAt(player, at) or root.CFrame
		return cf * CFrame.new(0, -0.5, 0), Vector3.new(4, 5.5, 2)
	end
	return model:GetBoundingBox()
end

local function closestPoint(cf: CFrame, size: Vector3, point: Vector3): Vector3
	local p = cf:PointToObjectSpace(point)
	local half = size / 2
	return cf:PointToWorldSpace(
		Vector3.new(
			math.clamp(p.X, -half.X, half.X),
			math.clamp(p.Y, -half.Y, half.Y),
			math.clamp(p.Z, -half.Z, half.Z)
		)
	)
end

local function insideArc(
	attack: Combat.Attack,
	eye: Vector3,
	look: Vector3,
	cf: CFrame,
	size: Vector3,
	range: number
): boolean
	local near = closestPoint(cf, size, eye)
	local offset = near - eye
	if offset.Magnitude > range then
		return false
	end
	if offset.Magnitude < 2.5 then
		return true -- standing in it
	end
	local centre = cf.Position - eye
	local function angleBetween(a: Vector3, b: Vector3): number
		if a.Magnitude < 1e-3 or b.Magnitude < 1e-3 then
			return 0
		end
		return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
	end
	local flatLook = look * Vector3.new(1, 0, 1)
	if attack.hitbox == "horizontal" then
		-- a wide horizontal sweep: the yaw towards the nearest point within half the arc, any height in reach
		return angleBetween(flatLook, offset * Vector3.new(1, 0, 1)) <= attack.angle / 2
			or angleBetween(flatLook, centre * Vector3.new(1, 0, 1)) <= attack.angle / 2
	elseif attack.hitbox == "vertical" then
		-- an overhead blow: a narrow yaw, but anything from above to the ground in front
		return angleBetween(flatLook, centre * Vector3.new(1, 0, 1)) <= 30
			and angleBetween(look, centre) <= attack.angle / 2 + 30
	end
	-- forward box (stab, punch): the box must come within 2.5 studs of the look line, measured flat — a
	-- rat on the ground is far below a level look line from the head and the stab used to miss it
	-- [владелец 22.10: бой неудобный]; height only has to be in reach
	local along = offset:Dot(look)
	if along < -1 then
		return false
	end
	local flatDir = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)
	local flatEye = Vector3.new(eye.X, 0, eye.Z)
	local flatCentre = Vector3.new(cf.Position.X, 0, cf.Position.Z)
	local onLine = flatEye + flatDir * math.max(0, (flatCentre - flatEye):Dot(flatDir))
	local flatCf = CFrame.new(flatCentre) * (cf - cf.Position)
	local lateral = (closestPoint(
		flatCf,
		size * Vector3.new(1, 0, 1) + Vector3.new(0, 0.1, 0),
		onLine
	) - onLine).Magnitude
	return lateral <= 2.5
end

-- Observers see a confirmed critical hit too. The attacker already receives HitConfirm.
local function critBurst(model: Model, attacker: Player)
	local cf = model:GetBoundingBox()
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if
			other ~= attacker
			and root
			and root:IsA("BasePart")
			and (root.Position - cf.Position).Magnitude <= 80
		then
			Remotes.unreliable("CombatCritFx"):FireClient(other, model)
		end
	end
end

-- One validated blow (a melee arc or an arrow) from `player` to `model`: PvP only where both players' locations
-- allow it and never between players of one faction; bosses remain vulnerable while casting; mobs and bosses remember the
-- attacker (LastHitBy → MobService / BossService rewards). Knockback along `look`; the attacker gets HitConfirm.
-- Returns the outcome: "killed" | "hit" | "cooldown" | "blocked" | "ally" | "nopvp".
function CombatService.HitModel(
	player: Player,
	profile: Types.Profile,
	model: Model,
	damage: number,
	crit: boolean,
	look: Vector3,
	weapon: Types.ItemStack?, -- the bow an arrow left (melee: the held item)
	ranged: boolean?,
	melee: { prepared: boolean?, sweep: boolean?, sprint: boolean? }?
): string
	-- the weapon's ancient books (BookService): Берсерк, Боксёр, Ярость before the blow, the rest after it
	weapon = weapon or profile.inventory[profile.selectedSlot]
	local bookHit
	if not (melee and melee.sweep) then
		damage *= TrainerService.multiplier(profile, "strength")
		damage, bookHit = BookService.outgoing(
			player,
			weapon,
			model,
			damage,
			ranged ~= true and not (melee and melee.prepared)
		)
	end
	local target = model:FindFirstChildOfClass("Humanoid")
	if not target or target.Health <= 0 then
		return "blocked"
	end
	local confirm = Remotes.event("HitConfirm")
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- PvP only where the location allows it (both players there) [вики]
		local mine = Config.location(profile.location)
		local theirs = ProfileService.Get(victim)
		local other = theirs and Config.location(theirs.location)
		-- players of one faction do not fight [сеть, патч 2022; клиент: удар без урона]
		-- and members of one gang with its PvP setting off [клиент gang.settings.pvp]
		-- (the Гетто allows hits inside a faction: friendlyFire [сеть TG/10])
		local sameFaction = theirs ~= nil
				and profile.faction ~= nil
				and theirs.faction == profile.faction
				and not (mine and mine.friendlyFire and other and other.friendlyFire)
			or GangService.allies(player, victim)
			-- inside a gang house nobody fights (GangHouseService sets NoPvp on the characters there)
			or model:GetAttribute("NoPvp") == true
			or (player.Character ~= nil and player.Character:GetAttribute("NoPvp") == true)
		if mine and mine.pvp and other and other.pvp and not sameFaction then
			local fromRoot = player.Character
				and player.Character:FindFirstChild("HumanoidRootPart")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local direction = if not ranged
					and fromRoot
					and fromRoot:IsA("BasePart")
					and targetRoot
					and targetRoot:IsA("BasePart")
				then targetRoot.Position - fromRoot.Position
				else look
			local _, dealt, verdict =
				CombatService.ApplyDamage(target, damage, "player", player, nil, nil, {
					push = HurtService.Impulse(
						model,
						direction,
						if melee and melee.sprint then 2 else 1
					),
				})
			local result = if target.Health <= 0
				then "killed"
				elseif dealt > 0 then "hit"
				else verdict
			confirm:FireClient(player, model, dealt, crit, result)
			if crit and dealt > 0 then
				critBurst(model, player)
			end
			if not (melee and melee.sweep) then
				BookService.afterHit(
					player,
					profile,
					weapon,
					model,
					dealt,
					look,
					ranged == true,
					bookHit
				)
			end
			return result
		end
		local result = if sameFaction then "ally" else "nopvp"
		confirm:FireClient(player, model, 0, false, result)
		return result
	elseif
		not CollectionService:HasTag(model, "Boss")
		and (model:GetAttribute("Shielded") == true or model:FindFirstChildOfClass("ForceField"))
	then
		confirm:FireClient(player, model, 0, false, "blocked")
		return "blocked"
	end
	damage = DamageImmunity.Accept(
		target,
		damage,
		if CollectionService:HasTag(model, "Boss") then player.UserId else nil
	)
	if damage <= 0 then
		-- Java's short hurt window is not a defensive block. Don't label it as one on bosses.
		local result = if CollectionService:HasTag(model, "Boss") then "cooldown" else "blocked"
		confirm:FireClient(player, model, 0, false, result)
		return result
	end
	target:SetAttribute("LastHitBy", player.UserId)
	target:SetAttribute("LastHitAt", os.clock())
	local before = target.Health
	HurtService.Damage(target, damage)
	local dealt = before - target.Health
	if dealt > 0 then
		HurtService.Knockback(model, look, if melee and melee.sprint then 2 else 1)
	end
	local result = if target.Health <= 0 then "killed" else "hit"
	confirm:FireClient(player, model, dealt, crit, result)
	if crit and dealt > 0 then
		critBurst(model, player)
	end
	if not (melee and melee.sweep) then
		BookService.afterHit(player, profile, weapon, model, dealt, look, ranged == true, bookHit)
	end
	return result
end

local function onAttack(player: Player, direction: any, falling: any, hint: any, viewTime: any)
	if
		typeof(direction) ~= "Vector3"
		or direction ~= direction
		or direction.Magnitude < 0.5
		or direction.Magnitude > 1.5
	then
		return
	end
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local toolId, level = InventoryService.heldTool(profile)
	local kind = Combat.kind(toolId)
	local duration = Combat.duration(kind, level)
	local now = os.clock()
	local state = combos[player] or { lastAt = -math.huge, index = 0 }
	combos[player] = state
	if now - state.lastAt < Config.rules.combat.attackIntentMinSeconds then
		return -- network flood limit; ordinary early clicks still make weak attacks
	end
	local resetAt = tonumber(character:GetAttribute("AttackResetAt")) or -math.huge
	local elapsed = math.min(now - state.lastAt, workspace:GetServerTimeNow() - resetAt)
	local charge = Combat.charge(elapsed, duration)
	local _, attack = Combat.next(state, kind, duration, now)
	local held = profile.inventory[profile.selectedSlot]
	local base, enchant = weapon(profile)
	base = math.max(
		0,
		base + 3 * Effects.level(character, "Strength") - 4 * Effects.level(character, "Weakness")
	)
	local root = character:FindFirstChild("HumanoidRootPart")
	local sprint = character:GetAttribute("Sprinting") == true and charge > 0.9
	local function criticalRestricted(): boolean
		local stateNow = humanoid:GetState()
		return character:GetAttribute("Sprinting") == true
			or humanoid.Sit
			or stateNow == Enum.HumanoidStateType.Climbing
			or stateNow == Enum.HumanoidStateType.Swimming
			or stateNow == Enum.HumanoidStateType.Flying
			or Ladders.near(character) ~= nil
			or Cobweb.holds(character)
			or Effects.level(character, "Blindness") > 0
			or Effects.level(character, "SlowFalling") > 0
			or Effects.level(character, "Levitation") > 0
	end
	local function observedGrounded(): boolean
		if not root or not root:IsA("BasePart") then
			return true
		end
		-- Target rewind uses render history; the attacker's own critical needs physical evidence.
		-- A finite cosmetic report up to 30 studs away must not turn a grounded player airborne.
		local cf = root.CFrame
		local ray = RaycastParams.new()
		ray.FilterType, ray.FilterDescendantsInstances =
			Enum.RaycastFilterType.Exclude, { character }
		ray.RespectCanCollide = true
		return workspace:Raycast(
			cf.Position,
			Vector3.new(0, -root.Size.Y / 2 - humanoid.HipHeight - 0.18, 0),
			ray
		) ~= nil
	end
	local function observedCrit(): boolean
		if not root or not root:IsA("BasePart") then
			return false
		end
		local speed = root.AssemblyLinearVelocity.Y
		-- The replicated velocity can still show ascent after the owner has crossed the apex.
		-- Prefer recent movement evidence during Freefall, as hit positions already do.
		-- Reports remain client-owned input; the physical ground ray below is mandatory.
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			speed = MotionService.verticalSpeed(player) or speed
		end
		return Combat.canCrit(
			charge,
			falling == true and speed < -0.5,
			observedGrounded(),
			criticalRestricted()
		)
	end
	local crit = observedCrit()
	local baseDamage = Combat.meleeDamage(base, enchant, charge, crit)
	local sweep = kind == "sword"
		and charge > 0.9
		and not crit
		and not sprint
		and observedGrounded()
	local look = direction.Unit
	-- Hit on the short visible swing; weapon recovery controls damage strength, not visual cadence.
	local upswing = math.min(duration, Combat.SWING_SECONDS) * attack.upswing
	-- lag compensation: the blow lands upswing seconds after the moment the attacker was looking at
	local seen = MotionService.viewTime(viewTime)
	local at = if seen then seen + upswing else nil
	task.delay(upswing, function()
		local head = character:FindFirstChild("Head")
		if
			player.Character ~= character
			or not character.Parent
			or humanoid.Health <= 0
			or not head
			or not head:IsA("BasePart")
			or profile.inventory[profile.selectedSlot] ~= held
		then
			return
		end
		-- Recheck at visible contact as well: a fall just after the apex may arrive after Attack.
		if not crit and observedCrit() then
			crit, sweep = true, false
			baseDamage = Combat.meleeDamage(base, enchant, charge, true)
		end
		local eye = head.Position
		local range = Combat.range(kind)
		-- [владелец 22.10: бой удобнее] the client's soft lock names its target: the blow goes at where that
		-- target is NOW (a running rat used to slip out of the arc during the upswing and the ping)
		if typeof(hint) == "Instance" and hint:IsA("Model") and hint:IsDescendantOf(workspace) then
			local th = hint:FindFirstChildOfClass("Humanoid")
			if th and th.Health > 0 and hint ~= character then
				local hcf, hsize = CombatService.targetBox(hint, at)
				local toCentre = hcf.Position - eye
				if
					(closestPoint(hcf, hsize, eye) - eye).Magnitude <= range + 3
					and toCentre.Magnitude > 0.1
				then
					look = toCentre.Unit
				end
			end
		end
		local candidates: { Model } = {}
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				table.insert(candidates, other.Character)
			end
		end
		for _, tag in ipairs({ "Mob", "Boss" }) do
			for _, model in ipairs(CollectionService:GetTagged(tag)) do
				if model:IsA("Model") then
					table.insert(candidates, model)
				end
			end
		end
		local valid = {}
		local visited = {}
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { character }
		ray.RespectCanCollide = true
		for _, model in ipairs(candidates) do
			local target = model:FindFirstChildOfClass("Humanoid")
			if target and target.Health > 0 and not visited[model] then
				visited[model] = true
				local cf, size = CombatService.targetBox(model, at)
				local point = closestPoint(cf, size, eye)
				local obstacle = workspace:Raycast(eye, point - eye, ray)
				if
					insideArc(attack, eye, look, cf, size, range)
					and (not obstacle or obstacle.Instance:IsDescendantOf(model))
				then
					table.insert(valid, { model = model, distance = (point - eye).Magnitude })
				end
			end
		end
		table.sort(valid, function(a, b)
			if a.model == hint then
				return true
			end
			if b.model == hint then
				return false
			end
			return a.distance < b.distance
		end)
		local primary = valid[1]
		if primary then
			local outcome = CombatService.HitModel(
				player,
				profile,
				primary.model,
				baseDamage,
				crit,
				look,
				held,
				false,
				{ prepared = true, sprint = sprint }
			)
			if outcome == "hit" or outcome == "killed" then
				if sprint then
					character:SetAttribute("StopSprint", true)
				end
				if sweep then
					local primaryCf, primarySize = CombatService.targetBox(primary.model, at)
					for i = 2, #valid do
						local cf = CombatService.targetBox(valid[i].model, at)
						if
							(closestPoint(primaryCf, primarySize, cf.Position) - cf.Position).Magnitude
							<= Config.rules.combat.blockStuds
						then
							CombatService.HitModel(
								player,
								profile,
								valid[i].model,
								1,
								false,
								look,
								held,
								false,
								{ prepared = true, sweep = true }
							)
						end
					end
				end
			end
		end
	end)
end

function CombatService.Start()
	if started then
		return
	end
	started = true
	Remotes.unreliable("CombatCritFx")
	Remotes.event("Attack").OnServerEvent:Connect(onAttack)
	-- swing animations: a player's client says it swings (chop / slash), the others nearby play it on that
	-- character (CharacterAnimator); unreliable — a lost swing only skips an animation
	local swingFx = Remotes.unreliable("SwingFx")
	local lastSwing: { [Player]: number } = {}
	local SWING_KINDS =
		{ slam = true, slash_right = true, slash_left = true, stab = true, punch = true }
	Remotes.event("Swing").OnServerEvent:Connect(function(player: Player, kind: any, duration: any)
		if typeof(kind) ~= "string" or not SWING_KINDS[kind] then
			return
		end
		duration = math.clamp(tonumber(duration) or 0.4, 0.1, 2)
		local now = os.clock()
		if now - (lastSwing[player] or -math.huge) < 0.1 then
			return
		end
		lastSwing[player] = now
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		for _, other in ipairs(Players:GetPlayers()) do
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if
				other ~= player
				and otherRoot
				and otherRoot:IsA("BasePart")
				and (otherRoot.Position - root.Position).Magnitude < 150
			then
				swingFx:FireClient(other, player.UserId, kind, duration)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCombat[player] = nil
		combos[player] = nil
	end)
end

return CombatService
