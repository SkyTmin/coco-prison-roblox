--!strict
-- Boss bar [владелец 22.10]: while a boss is alive and the player is in its location, a bar at the top of
-- the screen shows its name and health (and "invulnerable" / "stunned" while that lasts). Over the arena a
-- board counts down to the next appearance while it is dead. Reads ReplicatedStorage.Bosses.<id>
-- attributes (BossService), so it works whether or not the arena is streamed in.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)

local BossHud = {}
local SHOW_RADIUS = 320 -- studs from the arena: the whole quarry cave

local function nameOf(state: Instance): string
	local locale = Strings.localeOf(Players.LocalPlayer)
	local name = state:GetAttribute(if locale == "ru" then "Name" else "NameEn")
	return if typeof(name) == "string" then name else state.Name
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BossHud.Start(gui: ScreenGui)
	local player = Players.LocalPlayer
	local bar = Instance.new("Frame")
	bar.Name = "BossBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Size = UDim2.fromOffset(340, 46)
	bar.BackgroundColor3 = Ui.colors.panel
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.ZIndex = 5
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bar
	local title = Ui.label(
		bar,
		"",
		UDim2.new(1, -12, 0, 20),
		UDim2.fromOffset(6, 2),
		16,
		Color3.fromRGB(255, 120, 70)
	)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.4
	title.ZIndex = 6
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, -16, 0, 16)
	back.Position = UDim2.fromOffset(8, 24)
	back.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
	back.BorderSizePixel = 0
	back.ZIndex = 6
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(215, 40, 35)
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = back
	local numbers = Ui.label(back, "", UDim2.fromScale(1, 1), UDim2.new(), 12, Ui.colors.white)
	numbers.TextXAlignment = Enum.TextXAlignment.Center
	numbers.TextStrokeTransparency = 0.3
	numbers.ZIndex = 8

	-- countdown boards over the arenas (attached to each streamed-in BossSpawn part)
	local boards: { [BasePart]: TextLabel } = {}
	local function attach(part: Instance)
		if not part:IsA("BasePart") or boards[part] then
			return
		end
		local board = Instance.new("BillboardGui")
		board.Name = "BossRespawnBoard"
		board.Size = UDim2.fromOffset(260, 40)
		board.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
		board.AlwaysOnTop = true
		board.MaxDistance = 200
		board.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 150, 90)
		label.TextStrokeTransparency = 0.3
		label.Parent = board
		boards[part] = label
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) then
				boards[part] = nil
			end
		end)
	end
	for _, part in ipairs(CollectionService:GetTagged("BossSpawn")) do
		attach(part)
	end
	CollectionService:GetInstanceAddedSignal("BossSpawn"):Connect(attach)

	RunService.Heartbeat:Connect(function()
		local folder = ReplicatedStorage:FindFirstChild("Bosses")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local shown: Instance? = nil
		for _, state in ipairs(if folder then folder:GetChildren() else {}) do
			local origin = state:GetAttribute("Origin")
			if
				state:GetAttribute("Alive") == true
				and root
				and root:IsA("BasePart")
				and typeof(origin) == "Vector3"
				and (root.Position - origin).Magnitude <= SHOW_RADIUS
			then
				shown = state
			end
		end
		bar.Visible = shown ~= nil
		-- [владелец 22.10: «бар босса выше, к краю верха экрана»] at the very top, between the Roblox
		-- buttons in the corners (the centre of the top bar is free)
		bar.Position = UDim2.new(0.5, 0, 0, 4)
		if shown then
			local hp = tonumber(shown:GetAttribute("Health")) or 0
			local max = math.max(1, tonumber(shown:GetAttribute("MaxHealth")) or 1)
			local status = if shown:GetAttribute("Stunned") == true
				then " · " .. Strings.t("boss_stunned", Strings.localeOf(player))
				elseif shown:GetAttribute("Invulnerable") == true then " · " .. Strings.t(
					"boss_invulnerable",
					Strings.localeOf(player)
				)
				else ""
			title.Text = nameOf(shown) .. status
			fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			fill.BackgroundColor3 = if shown:GetAttribute("Invulnerable") == true
				then Color3.fromRGB(150, 150, 160)
				else Color3.fromRGB(215, 40, 35)
			numbers.Text = string.format("%d / %d", math.ceil(hp), max)
		end
		-- arena boards: the countdown while the boss is dead
		for part, label in pairs(boards) do
			local id = part:GetAttribute("BossId")
			local state = folder and typeof(id) == "string" and folder:FindFirstChild(id)
			local board = label.Parent :: BillboardGui
			if state and state:GetAttribute("Alive") ~= true then
				local at = tonumber(state:GetAttribute("RespawnAt")) or 0
				label.Text = Strings.t(
					"boss_respawn",
					Strings.localeOf(player),
					nameOf(state),
					clock(at - workspace:GetServerTimeNow())
				)
				board.Enabled = true
			else
				board.Enabled = false
			end
		end
	end)
end

return BossHud
