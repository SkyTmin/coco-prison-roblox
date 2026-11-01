--!strict
-- Combat feedback [владелец 01.11]: immediate short swings, server-confirmed damage/block text
-- near the crosshair, red hurt models (HurtService), matte critical pixels and a brief lateral hurt roll
-- (EffectsHud). No hitstop, camera punch or predicted hit flashes. Mob bars / soft lock remain in-world.

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

local CombatFeel = {}

local CONE = 60 -- degrees each side of the camera's look
local REACH_SLACK = 2 -- studs beyond the weapon's reach that still lock
local BAR_HIDE = 4

local player = Players.LocalPlayer
local started = false
local current: Model? = nil
local outline: Highlight? = nil
local feedbackLayer: Frame? = nil
local feedbackLabels: { TextLabel } = {}
local particleCount = 0
local lastHitSound = -math.huge
local feedbackRight = true
local random = Random.new()
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

-- Small matte pixel fragments for critical hits / death, no glowing particle clouds.
local function burst(at: Vector3, color: Color3, count: number)
	for _ = 1, math.min(count, 24 - particleCount) do
		particleCount += 1
		local p = Instance.new("Part")
		p.Name = "CombatPixel"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = false
		p.Material, p.Color = Enum.Material.SmoothPlastic, color
		p.Size = Vector3.one * (math.random(12, 22) / 100)
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		p.Position = at + spread * 1.8
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Position = p.Position + spread * 2 + Vector3.new(0, -0.5, 0),
			Size = Vector3.one * 0.03,
			Transparency = 1,
		}):Play()
		task.delay(0.4, function()
			p:Destroy()
			particleCount -= 1
		end)
	end
end

-- Combat verdicts pop at varied positions beside the crosshair [владелец 01.11], never over a tall boss.
-- Alternate sides and bound the active labels so a sweeping attack does not fill a phone screen.
local function popText(text: string, color: Color3, big: boolean)
	local layer = feedbackLayer
	if not layer then
		return
	end
	for i = #feedbackLabels, 1, -1 do
		if not feedbackLabels[i].Parent then
			table.remove(feedbackLabels, i)
		end
	end
	if #feedbackLabels >= 3 then
		local oldest = table.remove(feedbackLabels)
		if oldest then
			oldest:Destroy()
		end
	end
	local label = Instance.new("TextLabel")
	label.Name = "DamagePop"
	local right = feedbackRight
	feedbackRight = not right
	local x, y = random:NextInteger(24, 38), random:NextInteger(-30, 32)
	for _, entry in ipairs(feedbackLabels) do
		if
			entry:GetAttribute("RightSide") == right
			and math.abs(y - entry.Position.Y.Offset) < 25
		then
			y = math.clamp(
				entry.Position.Y.Offset + (if y < entry.Position.Y.Offset then -26 else 26),
				-48,
				48
			)
		end
	end
	label.AnchorPoint = Vector2.new(if right then 0 else 1, 0.5)
	label.Position = UDim2.new(0.5, if right then x else -x, 0.5, y)
	label.Size = UDim2.fromOffset(math.min(240, math.max(80, layer.AbsoluteSize.X / 2 - 42)), 26)
	label.TextXAlignment = if right then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	label:SetAttribute("RightSide", right)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = if big then 23 else 20
	label.TextScaled = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize, textLimit.MaxTextSize = 12, label.TextSize
	textLimit.Parent = label
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3, label.TextStrokeTransparency = Color3.new(), 0
	label.ZIndex = 7
	label.Parent = layer
	table.insert(feedbackLabels, 1, label)
	TweenService:Create(label, TweenInfo.new(0.75, Enum.EasingStyle.Quad), {
		Position = label.Position - UDim2.fromOffset(0, 14),
	}):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
	task.delay(0.8, function()
		label:Destroy()
	end)
end

-- A visual swing is independent of damage recovery; hit/block effects wait for the server verdict.
function CombatFeel.OnSwing()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Sfx.play("swing", root, 0.35, 0.95 + math.random() * 0.15)
	end
end

-- Near the visible side of a tall target, instead of its possibly off-screen bounding-box centre.
local function impactAt(model: Model): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return centreOf(model)
	end
	local cf, size = model:GetBoundingBox()
	local localEye = cf:PointToObjectSpace(camera.CFrame.Position)
	local half = size / 2
	return cf:PointToWorldSpace(
		Vector3.new(
			math.clamp(localEye.X, -half.X, half.X),
			math.clamp(localEye.Y, -half.Y, half.Y),
			math.clamp(localEye.Z, -half.Z, half.Z)
		)
	)
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
		local root = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local at = model:GetAttribute("MobWindup")
		if
			not root
			or not root:IsA("BasePart")
			or humanoid.Health <= 0
			or typeof(at) ~= "number"
			or workspace:GetServerTimeNow() - at > 0.5
			or (root.Position - centreOf(model)).Magnitude > 24
		then
			return
		end
		local h = Instance.new("Highlight")
		h.Name = "MobWindup"
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

function CombatFeel.Start(gui: ScreenGui, kindProvider: () -> string, locale: () -> string)
	if started then
		return
	end
	started = true
	getKind, localeOf = kindProvider, locale
	local layer = Instance.new("Frame")
	layer.Name = "CombatFeedback"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 7
	layer.Parent = gui
	feedbackLayer = layer
	Remotes.unreliable("CombatCritFx").OnClientEvent:Connect(function(model: any)
		if
			typeof(model) == "Instance"
			and model:IsA("Model")
			and model:IsDescendantOf(workspace)
		then
			burst(impactAt(model), Color3.fromRGB(185, 151, 103), 6)
		end
	end)
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
	-- The server's verdict is also the only source of hit sounds and critical particles.
	Remotes.event("HitConfirm").OnClientEvent
		:Connect(function(model: any, dealt: any, crit: any, status: any)
			local target = if typeof(model) == "Instance"
					and model:IsA("Model")
					and model.Parent
				then model
				else nil
			local loc = localeOf()
			if status == "hit" or status == "killed" then
				if typeof(dealt) == "number" and dealt > 0 then
					popText(
						formatDamage(dealt) .. (if crit then "!" else ""),
						if crit then Color3.fromRGB(255, 220, 70) else Color3.new(1, 1, 1),
						crit == true
					)
					-- A sweeping hit may confirm several targets in one frame: one sound is enough.
					if os.clock() - lastHitSound > 0.06 then
						lastHitSound = os.clock()
						Sfx.play(
							if crit then "crit" else "hit",
							nil,
							0.55,
							0.92 + math.random() * 0.16
						)
					end
					if target and crit then
						burst(impactAt(target), Color3.fromRGB(185, 151, 103), 6)
					end
				end
				if target and status == "killed" then
					burst(impactAt(target), Color3.fromRGB(220, 220, 220), 8)
				end
			elseif status == "blocked" then
				popText(Strings.t("combat_blocked", loc), Color3.fromRGB(180, 200, 230), false)
				if os.clock() - lastHitSound > 0.06 then
					lastHitSound = os.clock()
					Sfx.play("block", nil, 0.5, 1.1)
				end
			elseif status == "ally" then
				popText(Strings.t("faction_same", loc), Color3.fromRGB(170, 170, 170), false)
			elseif status == "nopvp" then
				popText(Strings.t("combat_no_pvp", loc), Color3.fromRGB(170, 170, 170), false)
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
end

return CombatFeel
