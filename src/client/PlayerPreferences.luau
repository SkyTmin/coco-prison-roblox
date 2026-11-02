--!strict
-- Local camera input and a separate brightness correction; scene lighting remains independent.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preferences = require(ReplicatedStorage.Shared.Preferences)
local PlayerPreferences = {}
PlayerPreferences.PreviewExpired = Instance.new("BindableEvent")
local started = false
local touchSensitivity = 1
local correction: ColorCorrectionEffect? = nil
local PREVIEW_SECONDS = 5
local PREVIEW_KEYS: { [string]: boolean } =
	{ mouseSensitivity = true, touchSensitivity = true, brightness = true }
local confirmed: { [string]: number } = {}
local pending: { [string]: { value: number } } = {}

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

local function valueFor(key: string): number
	local preview = pending[key]
	return if preview then preview.value else Preferences.number(key, confirmed[key])
end

local function applyLocal()
	start()
	UserInputService.MouseDeltaSensitivity = valueFor("mouseSensitivity")
	touchSensitivity = valueFor("touchSensitivity")
	if not correction or not correction.Parent then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "PlayerBrightness"
		correction.Parent = Lighting
	end
	local brightness = (valueFor("brightness") - 1) * 0.3
	correction.Brightness = brightness
	correction.Enabled = math.abs(brightness) > 0.001
end

-- Apply only authoritative settings here; older profile patches cannot overwrite a newer preview.
function PlayerPreferences.Apply(settings: any)
	for key in PREVIEW_KEYS do
		confirmed[key] = Preferences.number(key, settings[key])
	end
	applyLocal()
end

function PlayerPreferences.Preview(key: string, value: any)
	if not PREVIEW_KEYS[key] or not Preferences.valid(key, value) then
		return
	end
	local preview = { value = value :: number }
	pending[key] = preview
	applyLocal()
	task.delay(PREVIEW_SECONDS, function()
		if pending[key] ~= preview then
			return
		end
		-- An older acknowledgement can equal the newest value after rapid +/-/reset.
		-- Keep the latest preview for this bounded window, then reconcile once with the server.
		local rollback = Preferences.number(key, confirmed[key]) ~= preview.value
		pending[key] = nil
		applyLocal() -- a rejected or unanswered request returns to the latest server state
		if rollback then
			PlayerPreferences.PreviewExpired:Fire()
		end
	end)
end

-- Window labels use the same preview without feeding it back into authoritative Apply().
function PlayerPreferences.WithPreview(settings: any): any
	local shown = table.clone(settings)
	for key, preview in pending do
		shown[key] = preview.value
	end
	return shown
end

return PlayerPreferences
