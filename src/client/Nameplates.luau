--!strict
-- The name over other players [владелец 22.10: «ник персонажа: lvl (уровень, цвет фракции) Никнейм»]: «lvl 5
-- [кличка] Ник», the level tag in the faction's colour (white without one). Drawn here from the Player attributes
-- the server publishes (NameplateService: Level, Nick; FactionService: Faction) — a client-side BillboardGui is
-- rebuilt whenever the head streams back in, so it never shows a stale level. Sized in studs, so it shrinks
-- with distance like a Minecraft name tag [владелец 27.10: «ник игрока увеличивается»].

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Nameplates = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function textFor(player: Player): string
	local faction = player:GetAttribute("Faction")
	local color = if Config.faction(faction)
		then Config.factionColor(faction):Lerp(Color3.new(1, 1, 1), 0.15) -- a touch lighter: dark brown and grey stay readable
		else Color3.new(1, 1, 1)
	local nick = player:GetAttribute("Nick")
	local level = player:GetAttribute("Level")
	return string.format(
		'<font color="%s">lvl %d</font> %s%s',
		hex(color),
		if typeof(level) == "number" then level else 1,
		if typeof(nick) == "string" and nick ~= "" then "[" .. nick .. "] " else "",
		player.DisplayName
	)
end

local function plateOn(head: BasePart): TextLabel
	local gui = head:FindFirstChild("Nameplate")
	if gui and gui:IsA("BillboardGui") then
		return gui:FindFirstChild("Text") :: TextLabel
	end
	local new = Instance.new("BillboardGui")
	new.Name = "Nameplate"
	new.Size = UDim2.fromScale(12, 0.9) -- text ≈ 0.9 studs high (≈ ¼ block); the width only caps very long names
	new.StudsOffset = Vector3.new(0, 2.6, 0)
	new.MaxDistance = 90
	new.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.25
	label.Parent = new
	new.Adornee = head
	new.Parent = head
	return label
end

local function refresh(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local label = plateOn(head)
	local text = textFor(player)
	if label.Text ~= text then
		label.Text = text
	end
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return -- not shown to the player themself
	end
	player.AttributeChanged:Connect(function(name)
		if name == "Level" or name == "Nick" or name == "Faction" then
			refresh(player)
		end
	end)
	player:GetPropertyChangedSignal("DisplayName"):Connect(function()
		refresh(player)
	end)
end

function Nameplates.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- the head streams in and out and characters respawn: a cheap sweep puts the plate back
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= Players.LocalPlayer then
					refresh(player)
				end
			end
			task.wait(0.5)
		end
	end)
end

return Nameplates
