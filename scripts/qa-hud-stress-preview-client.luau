--!nocheck
-- Native render fixture only: fake boost profile and a separate character inside a temporary effect module.
-- No profile grants, real effects, purchases, camera hooks or OS input.
assert(game.RunService:IsStudio() and game.PlaceId == 92594200898716, "Confirmed Katorga only")
local player = game.Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("PrisonHud")
local client = player.PlayerScripts.Client
local Strings = require(game.ReplicatedStorage.Shared.Strings)
local function t(key, ...)
	return Strings.t(key, player:GetAttribute("Locale") or "ru", ...)
end
local now = workspace:GetServerTimeNow()
local fake = { settings = {}, activeBoosters = {} }
for i = 1, 6 do
	table.insert(fake.activeBoosters, {
		kind = ({ "blocks", "money", "mobs" })[(i - 1) % 3 + 1],
		mult = 1 + i / 10,
		startsAt = now - 20,
		endsAt = now + 300,
	})
end
local originalB = assert(gui:FindFirstChild("Boosters"), "Missing boost HUD")
local originalE = assert(gui:FindFirstChild("Effects"), "Missing effects HUD")
local b = require(client.BoosterHud).start(gui, function()
	return fake
end, t, function() end)
b.Name = "QABoosters"
local effectModule =
	assert(script:FindFirstChild("QARenderEffects"), "Missing isolated render-only module")
local e = require(effectModule).start(gui, t, function() end)
e.Name = "QAEffects"
local function mirror(source, target)
	target.Position, target.AnchorPoint = source.Position, source.AnchorPoint
	for key, value in source:GetAttributes() do
		target:SetAttribute(key, value)
	end
	local sourceScale = source:FindFirstChildOfClass("UIScale")
	if sourceScale then
		local targetScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		targetScale.Scale, targetScale.Parent = sourceScale.Scale, target
	end
end
local connection = game.RunService.RenderStepped:Connect(function()
	mirror(originalB, b)
	mirror(originalE, e)
end)
script:SetAttribute("Ready", true)
task.wait(60)
connection:Disconnect()
b:Destroy()
e:Destroy()
effectModule:Destroy()
script:Destroy()
