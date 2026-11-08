--!strict
-- Minecraft-style status effects of the local player (attributes set by NeedsService, list in
-- src/shared/Effects.luau):
--   * HUD: an icon box per effect, beneficial row above harmful as in Java [ваниль]; level numeral
--     from II, the time left under the box ("**:**" while it lasts until a need is restored), the icon
--     blinks in the last 10 s [ваниль]; tapping a box shows its name in the toast.
--   * Nausea: the view pulses (FOV) and rolls, fading in over 3 s and out over 1.5 s. Only roll and
--     FOV change — the centre ray stays put, so the crosshair still digs what it points at.
--   * Slowness / Speed: the FOV follows the movement speed like vanilla, (speed + 1) / 2 [ваниль].

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Effects = require(Shared.Effects)
local HudLayout = require(script.Parent.HudLayout)
local Ui = require(script.Parent.Ui)
local BowState = require(script.Parent.BowState)
local HurtFeedback = require(script.Parent.HurtFeedback)

local BOX = 40
local GAP = 4
local ROW = BOX + 18 -- box + timer line
local BASE_FOV = 70
local ROMAN = { "I", "II", "III", "IV", "V" }

type Box = { frame: Frame, icon: ImageLabel, level: TextLabel, timer: TextLabel }

local EffectsHud = {}

local function hudEffects(character: Model?): { any }
	local active = Effects.active(character)
	-- Owner 03.11: the permanent injection has no HUD icon or overflow entry; its mechanics remain active.
	for index = #active, 1, -1 do
		if active[index].effect.id == "needs_free" then
			table.remove(active, index)
		end
	end
	return active
end

local function timeText(endsAt: number?): string
	if not endsAt then
		return "**:**" -- vanilla Java shows endless effects like this
	end
	local left = math.max(0, math.floor(endsAt - workspace:GetServerTimeNow()))
	return string.format("%d:%02d", left // 60, left % 60)
end

-- Builds the HUD row under `gui` and starts the screen effects. Returns the frame (positioned by the
-- caller's layout code). `t` translates with the current locale, `showToast` shows a message.
function EffectsHud.start(
	gui: Instance,
	t: (string, ...any) -> string,
	showToast: (string) -> ()
): Frame
	local player = Players.LocalPlayer
	local frame = Instance.new("Frame")
	frame.Name = "Effects"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Size = UDim2.fromOffset(6 * (BOX + GAP), 2 * ROW)
	frame.Visible = false
	frame.Parent = gui
	local function describe(entry: any): string
		return t("effect_" .. entry.effect.id)
			.. " "
			.. (ROMAN[entry.level] or tostring(entry.level))
			.. " — "
			.. (
				if entry.endsAt
					then timeText(entry.endsAt)
					else t(
						if entry.effect.harmful then "effect_until_restored" else "effect_forever"
					)
			)
	end
	local overflow =
		Ui.button(frame, "", UDim2.fromOffset(44, 44), UDim2.fromOffset(88, 0), Ui.colors.panel)
	overflow.Name, overflow.Visible = "EffectOverflow", false
	local remaining: { any } = {}
	local remainingKey, overflowIndex = "", 0
	overflow.Activated:Connect(function()
		if #remaining == 0 then
			return
		end
		overflowIndex = overflowIndex % #remaining + 1
		-- One readable page per tap: the existing 52px toast cannot hold a dozen effect lines.
		showToast(
			string.format(
				"%d/%d · %s",
				overflowIndex,
				#remaining,
				describe(remaining[overflowIndex])
			)
		)
	end)

	local boxes: { [string]: Box } = {}
	local function boxFor(effect: Effects.Effect): Box
		local existing = boxes[effect.id]
		if existing then
			return existing
		end
		local panel = Ui.panel(frame, UDim2.fromOffset(BOX, BOX), UDim2.new())
		panel.Name = "Effect_" .. effect.id
		local stroke = Instance.new("UIStroke")
		stroke.Color = effect.color
		stroke.Thickness = 1.5
		stroke.Parent = panel
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromOffset(28, 28)
		icon.BackgroundColor3 = effect.color
		icon.BackgroundTransparency = 1
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.icons.icons["effect_" .. effect.id] or ""
		if icon.Image == "" then
			icon.BackgroundTransparency = 0 -- no icon uploaded yet: a square in the effect colour
		end
		icon.Parent = panel
		local level = Ui.label(
			panel,
			"",
			UDim2.fromOffset(BOX - 4, 14),
			UDim2.fromOffset(2, BOX - 15),
			12,
			Ui.colors.white
		)
		level.TextXAlignment = Enum.TextXAlignment.Right
		level.TextStrokeTransparency = 0.3
		local timer = Ui.label(
			panel,
			"",
			UDim2.new(1, GAP, 0, 14),
			UDim2.new(0, -GAP / 2, 1, 2),
			12,
			Ui.colors.white
		)
		timer.TextXAlignment = Enum.TextXAlignment.Center
		timer.TextStrokeTransparency = 0.3
		local hit = Instance.new("TextButton")
		hit.Name = "EffectDetails"
		hit.Size, hit.BackgroundTransparency, hit.Text = UDim2.fromScale(1, 1), 1, ""
		hit.Parent = panel
		local box: Box = { frame = panel, icon = icon, level = level, timer = timer }
		hit.Activated:Connect(function()
			for _, entry in ipairs(hudEffects(player.Character)) do
				if entry.effect.id == effect.id then
					showToast(describe(entry))
				end
			end
		end)
		boxes[effect.id] = box
		return box
	end

	local function render()
		local active = hudEffects(player.Character)
		-- the layout editor [владелец 28.10: «возможность передвигать иконки с эффектами»]: two sample icons to grab
		if #active == 0 and HudLayout.isEditing() then
			for _, id in ipairs({ "speed", "regeneration" }) do
				local effect = Effects.byId(id)
				if effect then
					table.insert(active, { effect = effect, level = 1, endsAt = nil })
				end
			end
		end
		local shown: { [string]: boolean } = {}
		local compact = frame:GetAttribute("Compact") == true
		local beneficialCount, harmfulCount = 0, 0
		for _, entry in ipairs(active) do
			if entry.effect.harmful then
				harmfulCount += 1
			else
				beneficialCount += 1
			end
		end
		if compact then
			local ordered = {}
			for _, harmful in { true, false } do
				for _, entry in active do
					if entry.effect.harmful == harmful then
						table.insert(ordered, entry)
					end
				end
			end
			active = ordered
		end
		frame.Visible = #active > 0
		frame.Size = UDim2.fromOffset(
			if compact then 132 else 6 * (BOX + GAP),
			if compact
				then 44
				else (math.ceil(beneficialCount / 6) + math.ceil(harmfulCount / 6)) * ROW
		)
		table.clear(remaining)
		local ids = {}
		if compact then
			for i = 3, #active do
				table.insert(remaining, active[i])
				table.insert(ids, active[i].effect.id)
			end
		end
		local key = table.concat(ids, ",")
		if key ~= remainingKey then
			remainingKey, overflowIndex = key, 0
		end
		overflow.Visible, overflow.Text = #remaining > 0, "+" .. tostring(#remaining)
		-- right-aligned rows: the first effect of each row is the rightmost one
		local beneficial, harmful = 0, 0
		local width = frame.Size.X.Offset
		for activeIndex, entry in ipairs(active) do
			if compact and activeIndex > 2 then
				continue
			end
			local box = boxFor(entry.effect)
			shown[entry.effect.id] = true
			local index, row
			if entry.effect.harmful then
				harmful += 1
				index, row =
					(harmful - 1) % 6 + 1,
					math.ceil(beneficialCount / 6) + math.floor((harmful - 1) / 6)
			else
				beneficial += 1
				index, row = (beneficial - 1) % 6 + 1, math.floor((beneficial - 1) / 6)
			end
			box.frame.Size =
				UDim2.fromOffset(if compact then 44 else BOX, if compact then 44 else BOX)
			box.frame.Position = if compact
				then UDim2.fromOffset((activeIndex - 1) * 44, 0)
				else UDim2.fromOffset(width - index * (BOX + GAP), row * ROW)
			box.icon.Size = UDim2.fromOffset(if compact then 22 else 28, if compact then 22 else 28)
			box.icon.Position = if compact
				then UDim2.new(0.5, 0, 0, 13)
				else UDim2.fromScale(0.5, 0.5)
			box.level.Size = UDim2.new(1, -4, 0, 14)
			box.level.Position = UDim2.fromOffset(2, if compact then 17 else BOX - 15)
			box.timer.Size = if compact then UDim2.new(1, 0, 0, 12) else UDim2.new(1, GAP, 0, 14)
			box.timer.Position = if compact
				then UDim2.fromOffset(0, 31)
				else UDim2.new(0, -GAP / 2, 1, 2)
			box.frame.Visible = true
			box.level.Text = if entry.level > 1
				then (ROMAN[entry.level] or tostring(entry.level))
				else ""
			box.timer.Text = timeText(entry.endsAt)
			local left = if entry.endsAt
				then entry.endsAt - workspace:GetServerTimeNow()
				else math.huge
			-- vanilla blinks the icon during the last 10 seconds
			local blink = left < 10 and math.floor(os.clock() * 4) % 2 == 0
			box.icon.ImageTransparency = if blink then 0.7 else 0
		end
		for id, box in pairs(boxes) do
			if not shown[id] then
				box.frame.Visible = false
			end
		end
	end
	frame:GetAttributeChangedSignal("Compact"):Connect(render)
	task.spawn(function()
		while frame.Parent do
			render()
			task.wait(0.25)
		end
	end)

	-- screen effects, run right after Roblox's camera update; the previous frame's roll is removed first
	-- so a stationary camera never accumulates it
	local nausea = 0 -- 0..1, ramps in and out
	-- Minecraft-shaped hurt envelope, 0.5 s. [владелец 01.11] keep aim steady:
	-- a brief 8-degree lateral roll [решение], never a pitch/yaw deflection. Knockback chooses its side.
	local HURT_SECONDS = 0.5
	local hurtAt = -math.huge
	local hurtDir = 0 -- degrees, Minecraft's: 0 = from the left, 90 = from the front, 180 = from the right
	HurtFeedback.Start(gui)
	player.CharacterAdded:Connect(function()
		hurtAt, hurtDir = -math.huge, 0
	end)
	HurtFeedback.Impact:Connect(function(packet: any)
		hurtAt, hurtDir = os.clock(), 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if typeof(packet.from) == "Vector3" and root and root:IsA("BasePart") then
			local camera = workspace.CurrentCamera
			local from = (packet.from - root.Position) * Vector3.new(1, 0, 1)
			if camera and from.Magnitude > 0.01 then
				local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
				if look.Magnitude > 0.01 then
					look = look.Unit
					local right = look:Cross(Vector3.yAxis)
					hurtDir = 90 + math.deg(math.atan2(from.Unit:Dot(right), from.Unit:Dot(look)))
				end
			end
		end
	end)
	local fovFactor = 1
	local fovApplied = false
	local rolledCamera: Camera? = nil
	local baseCFrame: CFrame? = nil
	local appliedCFrame: CFrame? = nil
	local blind = 0
	local darkness = Instance.new("Frame")
	darkness.Name = "Blindness"
	darkness.BackgroundColor3 = Color3.new()
	darkness.BorderSizePixel = 0
	darkness.Size = UDim2.fromScale(1, 1)
	darkness.ZIndex = -10
	darkness.Visible = false
	darkness.Parent = gui
	-- Undo last frame's cosmetic roll BEFORE the camera controller reads its previous orientation.
	-- Undoing it after the controller ran allowed boss hits to accumulate into downward aim drift.
	RunService:BindToRenderStep(
		"PrisonEffectsUnroll",
		Enum.RenderPriority.Camera.Value - 1,
		function()
			if rolledCamera and baseCFrame and rolledCamera.CFrame == appliedCFrame then
				rolledCamera.CFrame = baseCFrame
			end
			rolledCamera, baseCFrame, appliedCFrame = nil, nil, nil
		end
	)
	RunService:BindToRenderStep(
		"PrisonEffects",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local character = player.Character
			if not character then
				nausea, blind, fovFactor = 0, 0, 1
				hurtAt = -math.huge
				darkness.Visible = false
				if fovApplied then
					camera.FieldOfView = BASE_FOV
					fovApplied = false
				end
				return
			end
			local function level(attribute: string): number
				local value = if character then character:GetAttribute(attribute) else nil
				return if typeof(value) == "number" then value else 0
			end
			nausea = math.clamp(nausea + (if level("Nausea") > 0 then dt / 3 else -dt / 1.5), 0, 1)
			-- Blindness (the book Слепота): the screen goes dark under the HUD [ваниль: тёмный туман]
			blind =
				math.clamp(blind + (if level("Blindness") > 0 then dt / 0.4 else -dt / 0.8), 0, 1)
			darkness.Visible = blind > 0
			darkness.BackgroundTransparency = 1 - 0.85 * blind
			local speed = (1 - Effects.SLOWNESS_PER_LEVEL * level("Slowness"))
				* (1 + Effects.SPEED_PER_LEVEL * level("Speed"))
				* (if character:GetAttribute("Sprinting") == true then Effects.SPRINT else 1)
			-- [ваниль] drawing a bow zooms in: FOV × (1 − 0.15 · f), f = (t / 1 s)², at most 1
			local drawn = math.min(BowState.Drawn(character) / Config.vanilla.bow.drawSeconds, 1)
			local target = (math.max(0, speed) + 1) / 2 * (1 - 0.15 * drawn * drawn)
			fovFactor += (target - fovFactor) * math.min(1, dt * 6)
			local hurtAge = os.clock() - hurtAt
			local hurtLeft = if hurtAge < HURT_SECONDS then 1 - hurtAge / HURT_SECONDS else 0
			local hurt = math.sin(hurtLeft ^ 4 * math.pi)
			if nausea <= 0 and hurtLeft <= 0 and math.abs(fovFactor - 1) < 0.002 then
				if fovApplied then
					camera.FieldOfView = BASE_FOV
					fovApplied = false
				end
				fovFactor = 1
				return
			end
			local now = os.clock()
			camera.FieldOfView = BASE_FOV * fovFactor + 10 * nausea * math.sin(now * 2.4)
			fovApplied = true
			if nausea > 0 or hurtLeft > 0 then
				local base = camera.CFrame
				local dir = math.rad(hurtDir)
				local rolled = base
					* CFrame.Angles(
						0,
						0,
						math.rad(6) * nausea * math.sin(now * 1.6)
							+ math.rad(2) * nausea * math.sin(now * 3.7)
					)
					* CFrame.Angles(
						0,
						0,
						math.rad(8) * hurt * (if math.cos(dir) < 0 then -1 else 1)
					)
				rolledCamera, baseCFrame, appliedCFrame = camera, base, rolled
				camera.CFrame = rolled
			end
		end
	)
	return frame
end

return EffectsHud
