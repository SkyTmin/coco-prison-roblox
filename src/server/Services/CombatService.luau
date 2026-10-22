--!strict
-- DigService / future MobService should call MarkHit after validated damage to a player.
-- Pass the attacker kind: player/boss hits lock teleport; ordinary mob hits do not.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local HurtService = require(script.Parent.HurtService)
local Combat = require(Shared.Combat)

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

-- Validated combat callers use this entry point so attribution precedes a lethal hit.
function CombatService.ApplyDamage(
	humanoid: Humanoid,
	amount: number,
	source: "player" | "boss" | "mob",
	attacker: Player?
)
	if amount ~= amount or amount <= 0 or amount == math.huge or humanoid.Health <= 0 then
		return
	end
	local character = humanoid.Parent
	if character and character:FindFirstChildOfClass("ForceField") then
		return
	end
	local victim = if character and character:IsA("Model")
		then Players:GetPlayerFromCharacter(character)
		else nil
	if victim then
		CombatService.MarkHit(victim, source, attacker)
		-- worn armor and Protection soften blows from players, mobs and bosses [ваниль]
		local profile = ProfileService.Get(victim)
		amount = Combat.armorReduce(amount, profile and profile.armor)
	else
		humanoid:SetAttribute(
			"LastHitBy",
			if source == "player" and attacker then attacker.UserId else nil
		)
		humanoid:SetAttribute("LastHitAt", os.clock())
	end
	humanoid:TakeDamage(amount)
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
		return vanilla.handDamage or 1, (vanilla.attackSpeed and vanilla.attackSpeed.hand) or 4
	end
	local material = Config.materialForLevel(level)
	local damage = 1
	local speed = 4
	if toolId == "sword" then
		damage = vanilla.swordDamage[material]
			+ Config.sharpnessBonus(Config.enchantForLevel("sword", level))
		speed = vanilla.attackSpeed.sword
	elseif vanilla.toolDamage and vanilla.toolDamage[toolId] then
		damage = vanilla.toolDamage[toolId][material]
		local s = vanilla.attackSpeed[toolId]
		speed = if typeof(s) == "table" then s[material] else s
	end
	return damage, speed
end

-- Better Combat-style melee [владелец 22.10]: the attack hits along an arc in front of the player, measured
-- to the target's bounding box (not a thin ray to its exact mesh — the boss was hard to hit), after the
-- weapon's upswing (the moment the animation reaches the blow). Reach = 3 blocks + the weapon bonus
-- [ваниль, Better Combat]. Every target inside the arc is hit; the combo picks the attack of the set.
local combos: { [Player]: Combat.ComboState } = {}

local function targetBox(model: Model): (CFrame, Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") and Players:GetPlayerFromCharacter(model) then
		-- a player: the standard character box around the root (accessories would inflate the bounds)
		return root.CFrame * CFrame.new(0, -0.5, 0), Vector3.new(4, 5.5, 2)
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

-- Minecraft crit particles: a burst of little stars at the target
local function critBurst(at: Vector3)
	local p = Instance.new("Part")
	p.Name = "CritBurst"
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at + Vector3.new(0, 1, 0)
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(190, 170, 120))
	stars.Size = NumberSequence.new(0.6, 0.1)
	stars.Lifetime = NumberRange.new(0.35, 0.6)
	stars.Speed = NumberRange.new(10, 18)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Drag = 6
	stars.LightEmission = 0.8
	stars.Enabled = false
	stars.Parent = p
	p.Parent = workspace
	stars:Emit(18)
	game:GetService("Debris"):AddItem(p, 1)
end

local function onAttack(player: Player, direction: any, falling: any, hint: any)
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
	if now - state.lastAt < duration * 0.7 then
		return -- still swinging: attacks come at the weapon's pace (lenient: the client clock jitters)
	end
	local _, attack = Combat.next(state, kind, duration, now)
	local baseDamage = weapon(profile)
	-- critical hit like Minecraft: struck while falling after a jump (not on a ladder, not in water). The
	-- client knows its own fall exactly (here the velocity arrives late); the server checks it is airborne.
	local stateNow = humanoid:GetState()
	local crit = falling == true
		and humanoid.FloorMaterial == Enum.Material.Air
		and stateNow ~= Enum.HumanoidStateType.Climbing
		and stateNow ~= Enum.HumanoidStateType.Swimming
	if crit then
		baseDamage *= Config.rules.combat.crit.multiplier
	end
	local look = direction.Unit
	task.delay(duration * attack.upswing, function()
		local head = character:FindFirstChild("Head")
		if not character.Parent or humanoid.Health <= 0 or not head or not head:IsA("BasePart") then
			return
		end
		local eye = head.Position
		local range = Combat.range(kind)
		-- [владелец 22.10: бой удобнее] the client's soft lock names its target: the blow goes at where that
		-- target is NOW (a running rat used to slip out of the arc during the upswing and the ping)
		if typeof(hint) == "Instance" and hint:IsA("Model") and hint:IsDescendantOf(workspace) then
			local th = hint:FindFirstChildOfClass("Humanoid")
			if th and th.Health > 0 and hint ~= character then
				local hcf, hsize = targetBox(hint)
				local toCentre = hcf.Position - eye
				if
					(closestPoint(hcf, hsize, eye) - eye).Magnitude <= range + 3
					and toCentre.Magnitude > 0.1
				then
					look = toCentre.Unit
				end
			end
		end
		local confirm = Remotes.event("HitConfirm")
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
		for _, model in ipairs(candidates) do
			local target = model:FindFirstChildOfClass("Humanoid")
			if target and target.Health > 0 then
				local cf, size = targetBox(model)
				if insideArc(attack, eye, look, cf, size, range) then
					local damage = baseDamage * attack.damage
					if crit then
						critBurst(cf.Position)
					end
					local victim = Players:GetPlayerFromCharacter(model)
					if victim then
						-- PvP only where the location allows it (both players there) [вики]
						local mine = Config.location(profile.location)
						local theirs = ProfileService.Get(victim)
						local other = theirs and Config.location(theirs.location)
						-- players of one faction do not fight [сеть, патч 2022; клиент: удар без урона]
						local sameFaction = theirs ~= nil
							and profile.faction ~= nil
							and theirs.faction == profile.faction
						if mine and mine.pvp and other and other.pvp and not sameFaction then
							local before = target.Health
							CombatService.ApplyDamage(target, damage, "player", player)
							HurtService.Knockback(model, look)
							local dealt = before - target.Health
							confirm:FireClient(
								player,
								model,
								dealt,
								crit,
								if target.Health <= 0
									then "killed"
									elseif dealt > 0 then "hit"
									else "blocked"
							)
						else
							confirm:FireClient(
								player,
								model,
								0,
								false,
								if sameFaction then "ally" else "nopvp"
							)
						end
					elseif model:FindFirstChildOfClass("ForceField") then
						-- a boss casting is invulnerable: no damage, no shove, and the attacker is told so
						confirm:FireClient(player, model, 0, false, "blocked")
					else
						target:SetAttribute("LastHitBy", player.UserId)
						target:SetAttribute("LastHitAt", os.clock())
						local before = target.Health
						target:TakeDamage(damage)
						HurtService.Knockback(model, look)
						local dealt = before - target.Health
						confirm:FireClient(
							player,
							model,
							dealt,
							crit,
							if target.Health <= 0 then "killed" else "hit"
						)
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
