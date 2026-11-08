--!nocheck
-- Native Roblox virtual input, not OS input. Only edits the owner's HUD preference.
-- Root verifies the saved layout and uses ResetLayout afterwards (baseline has no requirements entry).
assert(
	game.RunService:IsStudio() and game.PlaceId == 92594200898716,
	"Confirmed Katorga Studio only"
)
local player = game.Players.LocalPlayer
assert(
	player.UserId == 6182034556 and player:GetAttribute("LoadingBlocked") == false,
	"Owner must be loaded"
)
local gui = player.PlayerGui:WaitForChild("PrisonHud")
local input = assert(game.UserInputService:CreateVirtualInput())
local debugHook = player:WaitForChild("ClientDebug")
local report = { checks = {}, physicalTouchTested = false, osInputUsed = false }
local function check(name, pass, evidence)
	table.insert(report.checks, { name = name, pass = pass, evidence = evidence })
	assert(pass, name)
end
local function waitFor(fn)
	local untilAt = os.clock() + 5
	repeat
		local result = fn()
		if result then
			return result
		end
		task.wait(0.05)
	until os.clock() > untilAt
	error("UI wait timed out")
end
local function find(name)
	return gui:FindFirstChild(name, true)
end
local function point(object)
	return object.AbsolutePosition + object.AbsoluteSize / 2 + game.GuiService:GetGuiInset()
end
local function click(name)
	local object = assert(find(name), name)
	local p = point(object)
	-- Device-emulator changes can retain VirtualInput's button state independently of UIS.
	pcall(function()
		input:SendMouseButton(p, Enum.UserInputType.MouseButton1, false, 0)
	end)
	task.wait(0.05)
	input:SendMousePosition(p)
	input:SendMouseButton(p, Enum.UserInputType.MouseButton1, true, 0)
	task.wait(0.08)
	input:SendMouseButton(p, Enum.UserInputType.MouseButton1, false, 0)
	task.wait(0.25)
end
local panel
local ok, err = xpcall(function()
	debugHook:Invoke("close")
	task.wait(0.35)
	panel = waitFor(function()
		local p = find("FirstSteps")
		return p and p.Visible and p
	end)
	local initial = panel.AbsoluteSize
	report.viewport =
		{ workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y }
	report.touchEmulator = game.UserInputService.TouchEnabled
	report.initialSize = { initial.X, initial.Y }
	check("tracked level card compact by default", initial.X <= 221 and initial.Y <= 110)
	check("redundant heading hidden", not find("RequirementsTitle").Visible)
	check("redundant footer hidden", not find("TaskHint").Visible)
	click("EditRequirementsLayout")
	local overlay = waitFor(function()
		return find("HudLayoutEditor")
	end)
	local handles = 0
	for _, object in overlay:GetChildren() do
		if object.Name:sub(1, 7) == "Handle_" then
			handles += 1
		end
	end
	check("direct editor has one handle", handles == 1)
	check("size controls already visible", find("Sizer").Visible)
	click("Smaller")
	click("Smaller")
	local scale = panel:FindFirstChildOfClass("UIScale")
	check("minus reduces to 80 percent", scale and math.abs(scale.Scale - 0.8) < 0.001)
	local before = panel.AbsolutePosition
	local handle = assert(find("Handle_requirements"))
	local from = point(handle)
	local to = from + Vector2.new(110, 45)
	input:SendMousePosition(from)
	input:SendMouseButton(from, Enum.UserInputType.MouseButton1, true, 0)
	task.wait(0.1)
	for step = 1, 10 do
		input:SendMousePosition(from:Lerp(to, step / 10))
		task.wait(0.03)
	end
	input:SendMouseButton(to, Enum.UserInputType.MouseButton1, false, 0)
	task.wait(0.2)
	local moved = panel.AbsolutePosition
	check(
		"native header drag moves card",
		(moved - before).Magnitude > 50,
		{ before = tostring(before), after = tostring(moved) }
	)
	-- Normal profile resend must not overwrite the in-progress drag or chosen size.
	game.ReplicatedStorage.Remotes.ClientBootstrap:FireServer()
	task.wait(0.6)
	check("profile resend preserves edit position", (panel.AbsolutePosition - moved).Magnitude < 2)
	check("profile resend preserves edit size", math.abs(scale.Scale - 0.8) < 0.001)
	click("LockLayout")
	waitFor(function()
		return not find("HudLayoutEditor")
	end)
	task.wait(0.6)
	local locked = panel.AbsolutePosition
	local maxDrift = 0
	for _ = 1, 10 do
		task.wait(0.25)
		maxDrift = math.max(maxDrift, (panel.AbsolutePosition - locked).Magnitude)
	end
	check("locked card remains stationary through tutorial ticks", maxDrift < 2, maxDrift)
	game.ReplicatedStorage.Remotes.ClientBootstrap:FireServer()
	task.wait(0.6)
	check("saved position survives profile resend", (panel.AbsolutePosition - locked).Magnitude < 2)
	check("saved scale survives profile resend", math.abs(scale.Scale - 0.8) < 0.001)
	report.finalPosition = { panel.AbsolutePosition.X, panel.AbsolutePosition.Y }
	report.finalSize = { panel.AbsoluteSize.X, panel.AbsoluteSize.Y }
	report.scale = scale.Scale
end, debug.traceback)
report.status = if ok then "PASS" else "FAIL"
report.error = if not ok then tostring(err) else nil
player:SetAttribute("QARequirementsLive", game.HttpService:JSONEncode(report))
script:Destroy()
