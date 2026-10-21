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
local Ui = require(script.Parent.Ui)

local BOX = 40
local GAP = 4
local ROW = BOX + 18 -- box + timer line
local BASE_FOV = 70
local ROMAN = { "I", "II", "III", "IV", "V" }

type Box = { frame: Frame, icon: ImageLabel, level: TextLabel, timer: TextLabel }

local EffectsHud = {}

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
	frame.Size = UDim2.fromOffset(#Effects.list * (BOX + GAP), 2 * ROW)
	frame.Parent = gui

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
		hit.Size, hit.BackgroundTransparency, hit.Text = UDim2.fromScale(1, 1), 1, ""
		hit.Parent = panel
		local box: Box = { frame = panel, icon = icon, level = level, timer = timer }
		hit.Activated:Connect(function()
			for _, entry in ipairs(Effects.active(player.Character)) do
				if entry.effect.id == effect.id then
					local name = t("effect_" .. effect.id)
						.. " "
						.. (ROMAN[entry.level] or tostring(entry.level))
					showToast(
						if entry.endsAt
							then name .. " — " .. timeText(entry.endsAt)
							else name .. " — " .. t("effect_until_restored")
					)
				end
			end
		end)
		boxes[effect.id] = box
		return box
	end

	local function render()
		local active = Effects.active(player.Character)
		local shown: { [string]: boolean } = {}
		local anyBeneficial = false
		for _, entry in ipairs(active) do
			anyBeneficial = anyBeneficial or not entry.effect.harmful
		end
		-- right-aligned rows: the first effect of each row is the rightmost one
		local beneficial, harmful = 0, 0
		local width = frame.Size.X.Offset
		for _, entry in ipairs(active) do
			local box = boxFor(entry.effect)
			shown[entry.effect.id] = true
			local index, row
			if entry.effect.harmful then
				harmful += 1
				index, row = harmful, if anyBeneficial then 1 else 0
			else
				beneficial += 1
				index, row = beneficial, 0
			end
			box.frame.Position = UDim2.fromOffset(width - index * (BOX + GAP), row * ROW)
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
	task.spawn(function()
		while frame.Parent do
			render()
			task.wait(0.25)
		end
	end)

	-- screen effects, run right after Roblox's camera update; the previous frame's roll is removed first
	-- so a stationary camera never accumulates it
	local nausea = 0 -- 0..1, ramps in and out
	local fovFactor = 1
	local fovApplied = false
	local rolledCamera: Camera? = nil
	local baseCFrame: CFrame? = nil
	local appliedCFrame: CFrame? = nil
	RunService:BindToRenderStep(
		"PrisonEffects",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			if rolledCamera and baseCFrame and rolledCamera.CFrame == appliedCFrame then
				rolledCamera.CFrame = baseCFrame
			end
			rolledCamera, baseCFrame, appliedCFrame = nil, nil, nil
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local character = player.Character
			local function level(attribute: string): number
				local value = if character then character:GetAttribute(attribute) else nil
				return if typeof(value) == "number" then value else 0
			end
			nausea = math.clamp(nausea + (if level("Nausea") > 0 then dt / 3 else -dt / 1.5), 0, 1)
			local speed = (1 - Effects.SLOWNESS_PER_LEVEL * level("Slowness"))
				* (1 + Effects.SPEED_PER_LEVEL * level("Speed"))
			local target = (math.max(0, speed) + 1) / 2
			fovFactor += (target - fovFactor) * math.min(1, dt * 6)
			if nausea <= 0 and math.abs(fovFactor - 1) < 0.002 then
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
			if nausea > 0 then
				local base = camera.CFrame
				local rolled = base
					* CFrame.Angles(
						0,
						0,
						math.rad(6) * nausea * math.sin(now * 1.6)
							+ math.rad(2) * nausea * math.sin(now * 3.7)
					)
				rolledCamera, baseCFrame, appliedCFrame = camera, base, rolled
				camera.CFrame = rolled
			end
		end
	)
	return frame
end

return EffectsHud
