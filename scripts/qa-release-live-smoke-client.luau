--!nocheck
-- Real current client; no profile grants/resets, purchases, server settings or OS input.
assert(game.RunService:IsStudio() and game.PlaceId == 92594200898716, "Confirmed Katorga only")
local player = game.Players.LocalPlayer
local debugHook = assert(player:FindFirstChild("ClientDebug"), "Client not ready")
assert(player:GetAttribute("LoadingBlocked") == false, "Loading unfinished")
local input = game.UserInputService
local report = {
	checks = {},
	profileMutated = false,
	physicalInputTested = false,
	viewport = { workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y },
	touch = input.TouchEnabled,
}
local function check(name, pass, evidence)
	table.insert(report.checks, { name = name, pass = pass, evidence = evidence })
end
local wasFirst = debugHook:Invoke("state").firstPerson
local brightness = game.Lighting:FindFirstChild("PlayerBrightness")
local originalBrightness = brightness and brightness.Brightness / 0.3 + 1 or 1
local originalMouse = input.MouseDeltaSensitivity
local preferences = require(player.PlayerScripts.Client.PlayerPreferences)
local ok, err = xpcall(function()
	debugHook:Invoke("close")
	task.wait(0.2)
	-- Prior privileged execute_luau calls restore their captured camera type on return.
	-- Normalize inside the actual LocalScript, and make no parallel Studio tool calls.
	debugHook:Invoke("toggleCamera")
	debugHook:Invoke("toggleCamera")
	if not wasFirst then
		debugHook:Invoke("toggleCamera")
	end
	for _, kind in
		{ "menu", "inventory", "settings", "actions", "upgrade", "level", "auction", "locations" }
	do
		debugHook:Invoke("close")
		local opened = debugHook:Invoke("open", kind)
		task.wait(0.25)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		local observed = {
			opened = opened,
			cursor = input.MouseIconEnabled,
			mouse = input.MouseBehavior.Name,
			camera = camera.CameraType.Name,
			modal = input.ModalEnabled,
			movement = humanoid.MoveDirection.Magnitude,
			jump = humanoid.Jump,
		}
		check(
			"first person menu " .. kind,
			opened == kind
				and observed.cursor
				and observed.mouse == "Default"
				and observed.camera == "Scriptable"
				and observed.modal
				and observed.movement == 0
				and not observed.jump,
			observed
		)
		debugHook:Invoke("close")
		task.wait(0.15)
		check(
			"camera returns after " .. kind,
			workspace.CurrentCamera.CameraType == Enum.CameraType.Custom
		)
	end
	preferences.Preview("brightness", 0.6)
	task.wait(0.15)
	brightness = game.Lighting:FindFirstChild("PlayerBrightness")
	local low = brightness and brightness.Brightness
	preferences.Preview("brightness", 1.4)
	task.wait(0.15)
	local high = brightness and brightness.Brightness
	check(
		"actual Lighting brightness preview",
		brightness
			and brightness.Enabled
			and math.abs(low + 0.12) < 0.00001
			and math.abs(high - 0.12) < 0.00001,
		{ low = low, high = high, parent = brightness and brightness.Parent.Name }
	)
	preferences.Preview("mouseSensitivity", 0.5)
	local lowMouse = input.MouseDeltaSensitivity
	preferences.Preview("mouseSensitivity", 1.5)
	check(
		"actual mouse multiplier preview",
		lowMouse == 0.5 and input.MouseDeltaSensitivity == 1.5,
		{ low = lowMouse, high = input.MouseDeltaSensitivity }
	)
	check("touch camera adapter installed", player:GetAttribute("TouchSensitivityReady") == true)
end, debug.traceback)
debugHook:Invoke("close")
if debugHook:Invoke("state").firstPerson ~= wasFirst then
	debugHook:Invoke("toggleCamera")
end
preferences.Preview("brightness", originalBrightness)
preferences.Preview("mouseSensitivity", originalMouse)
report.error = if not ok then tostring(err) else nil
report.status = if ok then "PASS" else "FAIL"
for _, result in report.checks do
	if not result.pass then
		report.status = "FAIL"
	end
end
player:SetAttribute("QAReleaseLiveSmoke", game.HttpService:JSONEncode(report))
script:Destroy()
