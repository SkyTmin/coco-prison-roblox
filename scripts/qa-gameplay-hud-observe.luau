--!nocheck
-- Read-only live geometry snapshot. Coordinates use viewport screen pixels, matching native virtual input.
assert(game.RunService:IsStudio() and game.PlaceId == 92594200898716, "Confirmed Katorga only")
local player = game.Players.LocalPlayer
local inset = game.GuiService:GetGuiInset()
local selected = {
	Scoreboard = true,
	FirstSteps = true,
	Boosters = true,
	Effects = true,
	Hotbar = true,
	SurvivalHud = true,
	HudView = true,
	TouchInventory = true,
	Touch_menu = true,
	TouchEat = true,
	Touch_attack = true,
	JumpButton = true,
	ThumbstickStart = true,
	ThumbstickEnd = true,
	BossBar = true,
	WarzoneHint = true,
	Announce = true,
	Toast = true,
	Touch_sprint = true,
}
local objects = {}
local function visible(object)
	local ancestor = object
	while ancestor and ancestor ~= player.PlayerGui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end
for _, object in player.PlayerGui:GetDescendants() do
	if
		object:IsA("GuiObject")
		and (
			selected[object.Name]
			or object.Name:match("^Booster_%d")
			or object.Name:match("^Effect_")
		)
	then
		local position, size = object.AbsolutePosition + inset, object.AbsoluteSize
		table.insert(objects, {
			name = object.Name,
			path = object:GetFullName(),
			visible = visible(object),
			x = position.X,
			y = position.Y,
			width = size.X,
			height = size.Y,
		})
	end
end
local hud = player.PlayerGui:FindFirstChild("PrisonHud")
return {
	viewport = { workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y },
	guiOrigin = hud and { hud.AbsolutePosition.X, hud.AbsolutePosition.Y },
	guiSize = hud and { hud.AbsoluteSize.X, hud.AbsoluteSize.Y },
	coreInset = { inset.X, inset.Y },
	touch = game.UserInputService.TouchEnabled,
	objects = objects,
}
