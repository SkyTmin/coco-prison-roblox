--!nocheck
-- Read-only live inspection of the owner's HUD correction. No profile/input changes.
assert(game.RunService:IsStudio() and game.PlaceId == 92594200898716, "Confirmed Katorga only")
local player = game.Players.LocalPlayer
local gui = assert(player.PlayerGui:FindFirstChild("PrisonHud"))
local Strings = require(game.ReplicatedStorage.Shared.Strings)
local locale = Strings.localeOf(player)
local report =
	{ viewport = { gui.AbsoluteSize.X, gui.AbsoluteSize.Y }, checks = {}, panels = {}, texts = {} }
local function check(name, pass)
	table.insert(report.checks, { name = name, pass = pass })
end
local function visible(object)
	while object and object ~= player.PlayerGui do
		if object:IsA("GuiObject") and not object.Visible then
			return false
		end
		if object:IsA("ScreenGui") and not object.Enabled then
			return false
		end
		object = object.Parent
	end
	return true
end
for _, name in
	{
		"Scoreboard",
		"Hotbar",
		"HudView",
		"TouchInventory",
		"FirstSteps",
		"BossBar",
		"Effects",
		"Boosters",
		"Touch_menu",
	}
do
	local object = gui:FindFirstChild(name, true)
	if object then
		local p, s = object.AbsolutePosition - gui.AbsolutePosition, object.AbsoluteSize
		local v = visible(object)
		report.panels[name] = { x = p.X, y = p.Y, width = s.X, height = s.Y, visible = v }
		if v then
			check(
				name .. " within safe area",
				p.X >= -1
					and p.Y >= -1
					and p.X + s.X <= gui.AbsoluteSize.X + 1
					and p.Y + s.Y <= gui.AbsoluteSize.Y + 1
			)
		end
	end
end
local stats = assert(gui:FindFirstChild("Scoreboard"))
for _, key in { "sb_title", "level", "coins", "blocks", "sb_faction", "sb_rats", "sb_kd" } do
	local expected, found = Strings.t(key, locale), false
	for _, label in stats:GetDescendants() do
		if label:IsA("TextLabel") and label.Text == expected then
			found = visible(label)
		end
	end
	check("scoreboard label " .. key, found)
end
for _, label in stats:GetDescendants() do
	if label:IsA("TextLabel") and visible(label) then
		local p, s = label.AbsolutePosition - stats.AbsolutePosition, label.AbsoluteSize
		table.insert(
			report.texts,
			{
				text = label.Text,
				x = p.X,
				y = p.Y,
				width = s.X,
				height = s.Y,
				textWidth = label.TextBounds.X,
				textHeight = label.TextBounds.Y,
			}
		)
	end
end
for _, name in { "Hotbar", "HudView", "TouchInventory" } do
	local p = report.panels[name]
	if p and p.visible then
		check(name .. " at safe bottom", math.abs(p.y + p.height - gui.AbsoluteSize.Y) <= 1)
	end
end
local boss = report.panels.BossBar
if boss and boss.visible then
	check("boss at safe top", math.abs(boss.y) <= 1)
end
local injection = gui:FindFirstChild("Effect_needs_free", true)
check("injection icon removed", not injection or not visible(injection))
report.locale = locale
report.profileMutated = false
return report
