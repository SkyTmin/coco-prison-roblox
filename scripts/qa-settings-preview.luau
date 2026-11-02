--!nocheck
-- Privileged Studio execute_luau, Server or Client. Actual module, fake services and clock.
-- No real preferences, camera input, Lighting, profiles or network requests are changed.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local source = game.StarterPlayer.StarterPlayerScripts.Client.PlayerPreferences.Source
local setup = [==[
local ranges = require(game.ReplicatedStorage.Shared.Preferences)
local now, expired, cameraStarts = 0, 0, 0
local timers, effects = {}, {}
local inputType = Enum.UserInputType.MouseMovement
local cameraInput = { getRotation = function(dt)
	return Vector2.new(2 + dt * 3, 4 + dt * 5)
end }
local inputToken = {}
local cameraModule = { WaitForChild = function(_, name)
	assert(name == "CameraInput")
	return inputToken
end }
local playerModule = { WaitForChild = function(_, name)
	assert(name == "CameraModule")
	return cameraModule
end }
local playerScripts = { WaitForChild = function(_, name)
	assert(name == "PlayerModule")
	return playerModule
end }
local actor = {
	WaitForChild = function(_, name)
		assert(name == "PlayerScripts")
		return playerScripts
	end,
	SetAttribute = function(_, name, value)
		assert(name == "TouchSensitivityReady" and value == true)
		cameraStarts += 1
	end,
}
local shared = { Preferences = {} }
local input = { GetLastInputType = function() return inputType end }
local lighting = {}
local services = {
	Players = { LocalPlayer = actor },
	Lighting = lighting,
	UserInputService = input,
	ReplicatedStorage = { Shared = shared },
}
local game = { GetService = function(_, name)
	return assert(services[name], "Unexpected service: " .. name)
end }
local Instance = { new = function(class)
	if class == "BindableEvent" then
		return { Fire = function() expired += 1 end }
	end
	assert(class == "ColorCorrectionEffect", "Unexpected instance: " .. class)
	local effect = {}
	table.insert(effects, effect)
	return effect
end }
local task = {
	spawn = function(fn) fn() end,
	delay = function(seconds, fn)
		table.insert(timers, { at = now + seconds, fn = fn })
	end,
}
local function require(module)
	if module == shared.Preferences then return ranges end
	assert(module == inputToken, "Unexpected require")
	return cameraInput
end
local function advance(seconds)
	now += seconds
	for i = #timers, 1, -1 do
		if timers[i].at <= now then
			local timer = table.remove(timers, i)
			timer.fn()
		end
	end
end
local function runModule()
]==]
local checks = [==[
end
local preferences = runModule()
local checks = {}
local function check(name, condition)
	assert(condition, name)
	table.insert(checks, name)
end
local function near(a, b) return math.abs(a - b) < 0.000001 end
local function state(brightness, mouse, touch)
	return { brightness = brightness or 1, mouseSensitivity = mouse or 1, touchSensitivity = touch or 1 }
end
local function shown(raw) return preferences.WithPreview(raw).brightness end
preferences.Apply(state())
check("baseline neutral", input.MouseDeltaSensitivity == 1 and not effects[1].Enabled)
preferences.Preview("brightness", 1.5)
check("brightness immediately previews", near(effects[1].Brightness, 0.15) and effects[1].Enabled)
local raw = state(1.1)
preferences.Apply(raw)
check("stale profile cannot override effect", near(effects[1].Brightness, 0.15))
check("stale profile cannot override label or mutate profile", shown(raw) == 1.5 and raw.brightness == 1.1)
preferences.Apply(state(1.5))
advance(5.1)
check("confirmed value survives reconciliation", near(effects[1].Brightness, 0.15) and expired == 0)

preferences.Apply(state())
preferences.Preview("brightness", 1.1)
advance(0.1)
preferences.Preview("brightness", 1.2)
advance(0.1)
preferences.Preview("brightness", 1.1)
preferences.Apply(state(1.1)) -- older response equals the newest request
preferences.Apply(state(1.2))
check("rapid return-to-value ignores matching intermediate response", near(effects[1].Brightness, 0.03))
check("rapid return-to-value label remains newest", shown(state(1.2)) == 1.1)
preferences.Apply(state(1.1))
advance(5.1)
check("rapid return-to-value settles without rollback", expired == 0 and near(effects[1].Brightness, 0.03))

preferences.Apply(state())
preferences.Preview("brightness", 1.1)
advance(2)
preferences.Preview("brightness", 1.5)
preferences.Apply(state(0.8)) -- latest server value, request has not succeeded
advance(3.1)
check("superseded timeout cannot clear newer preview", near(effects[1].Brightness, 0.15) and expired == 0)
advance(2)
check("unanswered preview rolls back to latest server value", near(effects[1].Brightness, -0.06) and expired == 1)
check("rollback label uses latest confirmed profile", shown(state(0.8)) == 0.8)

preferences.Apply(state())
preferences.Preview("mouseSensitivity", 0.5)
preferences.Preview("touchSensitivity", 3)
preferences.Apply(state(1, 0.8, 2))
check("mouse preview survives older patch", input.MouseDeltaSensitivity == 0.5)
local mouseRotation = cameraInput.getRotation(0, true)
check("mouse rotation is not additionally multiplied", near(mouseRotation.X, 2) and near(mouseRotation.Y, 4))
inputType = Enum.UserInputType.Touch
local touchRotation = cameraInput.getRotation(0, true)
check("touch preview changes existing rotation wrapper", near(touchRotation.X, 6) and near(touchRotation.Y, 12))
preferences.Apply(state(1, 0.5, 3))
advance(5.1)
check("independent mouse and touch acknowledgements settle", input.MouseDeltaSensitivity == 0.5 and expired == 1)
preferences.Preview("brightness", 0 / 0)
preferences.Preview("brightness", 0)
preferences.Preview("volume", 0)
check("invalid or unrelated previews do nothing", not effects[1].Enabled and #timers == 0)
check("repeated preview keeps one correction and one camera adapter", #effects == 1 and cameraStarts == 1)
return { status = "PASS", checks = checks, count = #checks, realPlayerStateChanged = false }
]==]
local isolated = Instance.new("ModuleScript")
isolated.Name = "QAIsolatedSettingsPreview"
isolated.Source = setup .. source .. checks
isolated.Parent = game.ServerStorage
local ok, result = pcall(require, isolated)
isolated:Destroy()
assert(ok, result)
return game.HttpService:JSONEncode(result)
