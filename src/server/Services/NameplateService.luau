--!strict
-- The name over a player [владелец 22.10: «ник персонажа: L(уровень, цвет фракции) Никнейм»; сеть 2019:
-- «цвет [9 УР] обозначает фракцию; если фракция не выбрана, цвет белый»]: «L5 [кличка] Ник», the level tag in
-- the faction's colour. A BillboardGui on the head replaces the Roblox name (hidden), refreshed once a
-- second when the level, the faction or the nickname change; not shown to the player themself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ProfileService = require(script.Parent.ProfileService)

local NameplateService = {}
local started = false
local shown: { [Player]: string } = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function textFor(player: Player): string?
	local profile = ProfileService.Get(player)
	if not profile then
		return nil
	end
	local color = if Config.faction(profile.faction)
		then Config.factionColor(profile.faction):Lerp(Color3.new(1, 1, 1), 0.15) -- a touch lighter: dark brown and grey stay readable
		else Color3.new(1, 1, 1)
	local nick = if typeof(profile.nickname) == "string" and profile.nickname ~= ""
		then "[" .. profile.nickname .. "] "
		else ""
	return string.format(
		'<font color="%s">L%d</font> %s%s',
		hex(color),
		profile.level,
		nick,
		player.DisplayName
	)
end

local function apply(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local text = textFor(player)
	if not head or not humanoid or not text then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = head:FindFirstChild("Nameplate") :: BillboardGui?
	if not gui then
		local new = Instance.new("BillboardGui")
		new.Name = "Nameplate"
		new.Size = UDim2.fromOffset(240, 26)
		new.StudsOffset = Vector3.new(0, 2.6, 0)
		new.MaxDistance = 90
		new.AlwaysOnTop = false
		new.PlayerToHideFrom = player
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
		new.Parent = head
		gui = new
		shown[player] = nil
	end
	if shown[player] ~= text then
		shown[player] = text
		local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
		label.Text = text
	end
end

function NameplateService.Start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				apply(player)
			end
			task.wait(1)
		end
	end)
end

return NameplateService
