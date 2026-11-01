--!strict
-- Local camera input and a separate brightness correction; scene lighting remains independent.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Shared.Preferences)
local PlayerPreferences = {}
local started = false
local touchSensitivity = 1
local correction: ColorCorrectionEffect? = nil

local function start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		-- Adapt Roblox's existing camera input, keeping its pitch limits, collision and UI/touch filtering.
		-- Verified against the installed PlayerModule.CameraModule.CameraInput (02.11).
		local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local playerModule = scripts:WaitForChild("PlayerModule")
		local cameraModule = playerModule:WaitForChild("CameraModule")
		local input = require(cameraModule:WaitForChild("CameraInput") :: ModuleScript) :: any
		local original = input.getRotation
		input.getRotation = function(dt: number, disableKeyboardRotation: boolean?): Vector2
			local rotation = original(dt, disableKeyboardRotation)
			if
				touchSensitivity ~= 1
				and UserInputService:GetLastInputType() == Enum.UserInputType.Touch
			then
				-- dt=0 excludes keyboard/gamepad rates. Scale only the current pointer gesture.
				return rotation + original(0, true) * (touchSensitivity - 1)
			end
			return rotation
		end
		Players.LocalPlayer:SetAttribute("TouchSensitivityReady", true)
	end)
end

function PlayerPreferences.Apply(settings: any)
	start()
	UserInputService.MouseDeltaSensitivity =
		Preferences.number("mouseSensitivity", settings.mouseSensitivity)
	touchSensitivity = Preferences.number("touchSensitivity", settings.touchSensitivity)
	if not correction or not correction.Parent then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "PlayerBrightness"
		correction.Parent = Lighting
	end
	local brightness = (Preferences.number("brightness", settings.brightness) - 1) * 0.3
	correction.Brightness = brightness
	correction.Enabled = math.abs(brightness) > 0.001
end

return PlayerPreferences
