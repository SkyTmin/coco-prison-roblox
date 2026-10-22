--!strict
-- How combat feels on the client [владелец 22.10: «бой с мобами и боссами неудобный — сделай удобнее и
-- приятнее»; research: docs/research/combat-feel.md]:
--   * soft lock: the best enemy (a mob, a boss, a player of another faction) within reach in a ±60° cone of
--     the camera gets a thin white outline; an attack turns the character to it and aims the blow at it
--     (the server then aims at where that target is when the blow lands); the lock sticks while it lasts;
--   * predicted hit: the moment the blow lands the client already plays the impact — a hit (crit) sound, a
--     red flash, a burst of particles, a 50 ms hitstop — or a clank
--     and «Блок» when the boss is shielded; a miss is just the swing whoosh; the damage numbers come from
--     the server (HitConfirm);
--   * health bars over mobs (shown when hurt, gone 4 s after the last hit); a rat about to bite flashes a
--     red outline (its wind-up); a shielded boss glows with a pale blue outline;
--   * when we get hurt: a red flash at the screen edges.
-- No vibration and no camera punch [владелец 22.10: «выключи вибрацию в игре»].

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Combat)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local HeldItem = require(script.Parent.HeldItem)

local CombatFeel = {}

local CONE = 60 -- degrees each side of the camera's look
local REACH_SLACK = 2 -- studs beyond the weapon's reach that still lock
local HITSTOP = 0.05
local BAR_HIDE = 4

local player = Players.LocalPlayer
local started = false
local current: Model? = nil
local outline: Highlight? = nil
local getKind: () -> string = function()
	return "hand"
end
local localeOf: () -> string = function()
	return "ru"
end

local function humanoidOf(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

local function alive(model: Model?): boolean
	if not model or not model.Parent then
		return false
	end
	local h = humanoidOf(model)
	return h ~= nil and h.Health > 0
end

local function centreOf(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and Players:GetPlayerFromCharacter(model) then
		return root.Position
	end
	local cf = model:GetBoundingBox()
	return cf.Position
end

-- a player we may hit: not us, not our own faction
local function enemyPlayerModel(other: Player): Model?
	if other == player or not other.Character then
		return nil
	end
	local mine = player:GetAttribute("Faction")
	if typeof(mine) == "string" and mine ~= "" and other:GetAttribute("Faction") == mine then
		return nil
	end
	return other.Character
end

local function candidates(): { Model }
	local list = {}
	for _, tag in ipairs({ "Mob", "Boss" }) do
		for _, m in ipairs(CollectionService:GetTagged(tag)) do
			if m:IsA("Model") then
				table.insert(list, m)
			end
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local m = enemyPlayerModel(other)
		if m then
			table.insert(list, m)
		end
	end
	return list
end

-- score of a target from where we stand and look (nil = not lockable)
local function score(
	model: Model,
	origin: Vector3,
	look: Vector3,
	reach: number,
	cone: number
): number?
	if not alive(model) then
		return nil
	end
	local offset = centreOf(model) - origin
	local flat = Vector3.new(offset.X, 0, offset.Z)
	-- distance to the near side of the target, so big bosses lock from their edge
	local _, size = model:GetBoundingBox()
	local radius = math.min(math.max(size.X, size.Z) / 2, 8)
	local dist = math.max(0, flat.Magnitude - radius)
	if dist > reach or math.abs(offset.Y) > 14 then
		return nil
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.5 or flatLook.Magnitude < 0.01 then
		return dist
	end
	local angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(flatLook.Unit), -1, 1)))
	if angle > cone then
		return nil
	end
	return dist + angle * 0.12 + (if CollectionService:HasTag(model, "Boss") then -2 else 0)
end

local function pick(): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not camera then
		return nil
	end
	local reach = Combat.range(getKind()) + REACH_SLACK
	local look = camera.CFrame.LookVector
	-- sticky: keep the current target while it is still reasonable
	if current and score(current, root.Position, look, reach + 1, CONE + 20) then
		return current
	end
	local best, bestScore = nil, math.huge
	for _, m in ipairs(candidates()) do
		if m ~= character then
			local s = score(m, root.Position, look, reach, CONE)
			if s and s < bestScore then
				best, bestScore = m, s
			end
		end
	end
	return best
end

function CombatFeel.Target(): Model?
	return current
end

-- Turns the character towards the target (the client owns its character) and gives the blow direction.
function CombatFeel.FaceTarget(target: Model): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil
	end
	local centre = centreOf(target)
	local flat = Vector3.new(centre.X, root.Position.Y, centre.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
	local dir = centre - head.Position
	return if dir.Magnitude > 0.1 then dir.Unit else nil
end

local function flash(model: Model, color: Color3, seconds: number, name: string)
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = name
	h.FillColor = color
	h.FillTransparency = 0.45
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(seconds), { FillTransparency = 1 }):Play()
	task.delay(seconds, function()
		h:Destroy()
	end)
end

local function burst(at: Vector3, color: Color3, count: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Speed = NumberRange.new(6, 12)
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.3
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(0.8, function()
		p:Destroy()
	end)
end

-- a floating number / word over a model
local function popText(model: Model, text: string, color: Color3, big: boolean)
	local anchor = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamagePop"
	gui.Size = UDim2.fromOffset(if big then 120 else 90, if big then 40 else 30)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, size.Y / 2 + 0.8, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local rise = gui.StudsOffsetWorldSpace + Vector3.new(0, 2.2, 0)
	TweenService
		:Create(gui, TweenInfo.new(0.75, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = rise })
		:Play()
	TweenService
		:Create(label, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		:Play()
	task.delay(0.8, function()
		gui:Destroy()
	end)
end

local function shielded(model: Model): boolean
	return model:GetAttribute("Shielded") == true
		or model:FindFirstChildOfClass("ForceField") ~= nil
end

-- Called by the attack: the swing whoosh now, the predicted impact when the blow lands.
function CombatFeel.OnAttack(target: Model?, delay: number, crit: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Sfx.play("swing", root, 0.35, 0.95 + math.random() * 0.15)
	end
	if not target then
		return
	end
	task.delay(delay, function()
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not alive(target) or not r or not r:IsA("BasePart") then
			return
		end
		local model = target :: Model
		local reach = Combat.range(getKind()) + REACH_SLACK + 2
		local _, size = model:GetBoundingBox()
		local dist = (centreOf(model) - r.Position).Magnitude - math.max(size.X, size.Z) / 2
		if dist > reach then
			return -- it got away: the whoosh was the miss
		end
		local at = centreOf(model)
		if shielded(model) then
			Sfx.play("block", nil, 0.5, 1.1)
			popText(
				model,
				Strings.t("combat_blocked", localeOf()),
				Color3.fromRGB(180, 200, 230),
				false
			)
			burst(at, Color3.fromRGB(190, 225, 255), 6)
			return
		end
		Sfx.play(if crit then "crit" else "hit", nil, 0.55, 0.92 + math.random() * 0.16)
		flash(model, Color3.fromRGB(255, 40, 40), 0.22, "PredictFlash")
		burst(
			at,
			if crit then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(255, 90, 80),
			if crit then 14 else 8
		)
		HeldItem.Hitstop(if crit then HITSTOP * 1.8 else HITSTOP)
	end)
end

local function formatDamage(n: number): string
	local rounded = math.floor(n * 10 + 0.5) / 10
	return if rounded == math.floor(rounded)
		then string.format("%d", rounded)
		else string.format("%.1f", rounded)
end

-- ---------------------------------------------------------------- health bars over mobs
local bars: { [Model]: { gui: BillboardGui, fill: Frame, chip: Frame, hideAt: number } } = {}

local function barFor(model: Model)
	if bars[model] then
		return bars[model]
	end
	local anchor = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobHealth"
	gui.Size = UDim2.fromScale(3.4, 0.42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 0.9, 0)
	gui.MaxDistance = 70
	gui.Adornee = anchor
	gui.Enabled = false
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.fromRGB(255, 245, 230)
	chip.BorderSizePixel = 0
	chip.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 45, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(10, 10, 10)
	stroke.Parent = back
	gui.Parent = player:WaitForChild("PlayerGui")
	local entry = { gui = gui, fill = fill, chip = chip, hideAt = 0 }
	bars[model] = entry
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			gui:Destroy()
			bars[model] = nil
		end
	end)
	return entry
end

local function watchMob(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			local entry = barFor(model)
			if entry then
				local k = math.clamp(health / math.max(humanoid.MaxHealth, 1), 0, 1)
				entry.gui.Enabled = health > 0
				entry.fill.Size = UDim2.fromScale(k, 1)
				-- the white chip drains behind the red a moment later
				task.delay(0.25, function()
					TweenService
						:Create(entry.chip, TweenInfo.new(0.3), { Size = UDim2.fromScale(k, 1) })
						:Play()
				end)
				entry.hideAt = os.clock() + BAR_HIDE
			end
		end
		last = health
	end)
	-- the bite wind-up: a red outline for the moment the rat rears up
	model:GetAttributeChangedSignal("MobWindup"):Connect(function()
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 60, 40)
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = model
		h.Parent = model
		task.delay(0.35, function()
			h:Destroy()
		end)
	end)
end

local function watchBoss(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local glow: Highlight? = nil
	local function update()
		local on = model:GetAttribute("Shielded") == true
		if on and not glow then
			local h = Instance.new("Highlight")
			h.Name = "ShieldGlow"
			h.FillColor = Color3.fromRGB(150, 200, 255)
			h.FillTransparency = 0.82
			h.OutlineColor = Color3.fromRGB(190, 225, 255)
			h.OutlineTransparency = 0.2
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = model
			h.Parent = model
			glow = h
		elseif not on and glow then
			glow:Destroy()
			glow = nil
		end
	end
	model:GetAttributeChangedSignal("Shielded"):Connect(update)
	update()
end

-- ---------------------------------------------------------------- our own hurt
local function watchSelf(gui: ScreenGui)
	-- four red strips along the screen edges, fading inwards (a vignette made of gradients)
	local edges: { Frame } = {}
	for _, e in ipairs({
		{ UDim2.new(1, 0, 0, 90), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 90), UDim2.new(0, 0, 1, -90), -90 },
		{ UDim2.new(0, 90, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0, 90, 1, 0), UDim2.new(1, -90, 0, 0), 180 },
	}) do
		local f = Instance.new("Frame")
		f.Name = "HurtEdge"
		f.Size, f.Position = e[1], e[2]
		f.BackgroundColor3 = Color3.fromRGB(220, 20, 20)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = 50
		f.Active = false
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		table.insert(edges, f)
	end
	local function bind(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last - 0.01 then
				for _, f in ipairs(edges) do
					f.BackgroundTransparency = 0.35
					TweenService:Create(
						f,
						TweenInfo.new(0.45, Enum.EasingStyle.Quad),
						{ BackgroundTransparency = 1 }
					):Play()
				end
			end
			last = health
		end)
	end
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
end

function CombatFeel.Start(gui: ScreenGui, kindProvider: () -> string, locale: () -> string)
	if started then
		return
	end
	started = true
	getKind, localeOf = kindProvider, locale
	local h = Instance.new("Highlight")
	h.Name = "SoftLock"
	h.FillTransparency = 1
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.OutlineTransparency = 0.35
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = gui
	outline = h
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.08 then
			return
		end
		acc = 0
		current = pick()
		local o = outline :: Highlight
		o.Adornee = current
		o.Enabled = current ~= nil
		local now = os.clock()
		for _, entry in pairs(bars) do
			if entry.gui.Enabled and now >= entry.hideAt then
				entry.gui.Enabled = false
			end
		end
	end)
	-- the server's verdict on each blow: numbers, «Блок», «Своя фракция»
	Remotes.event("HitConfirm").OnClientEvent
		:Connect(function(model: any, dealt: any, crit: any, status: any)
			if typeof(model) ~= "Instance" or not model:IsA("Model") then
				return
			end
			local loc = localeOf()
			if status == "hit" or status == "killed" then
				if typeof(dealt) == "number" and dealt > 0 then
					popText(
						model,
						formatDamage(dealt) .. (if crit then "!" else ""),
						if crit then Color3.fromRGB(255, 220, 70) else Color3.fromRGB(255, 255, 255),
						crit == true
					)
				end
				if status == "killed" then
					burst(centreOf(model), Color3.fromRGB(235, 235, 235), 16)
				end
			elseif status == "blocked" then
				popText(
					model,
					Strings.t("combat_blocked", loc),
					Color3.fromRGB(180, 200, 230),
					false
				)
			elseif status == "ally" then
				popText(model, Strings.t("faction_same", loc), Color3.fromRGB(170, 170, 170), false)
			elseif status == "nopvp" then
				popText(
					model,
					Strings.t("combat_no_pvp", loc),
					Color3.fromRGB(170, 170, 170),
					false
				)
			end
		end)
	for _, m in ipairs(CollectionService:GetTagged("Mob")) do
		task.spawn(watchMob, m)
	end
	CollectionService:GetInstanceAddedSignal("Mob"):Connect(function(m)
		task.spawn(watchMob, m)
	end)
	for _, m in ipairs(CollectionService:GetTagged("Boss")) do
		watchBoss(m)
	end
	CollectionService:GetInstanceAddedSignal("Boss"):Connect(watchBoss)
	watchSelf(gui)
end

return CombatFeel
