--!strict
-- Lighting of the place, kept in code (the place file drifted: brightness 3.1 + bloom made sand in the
-- mine look blown out — owner 21.10). Minecraft-like daylight: soft sun, even ambient light, no bloom,
-- weak specular so textured blocks keep their colours; post effects are created here and owned by
-- this service (names Prison*). Applied once on server start; scripts/setup-lighting.luau runs the
-- same in Edit mode.

local Lighting = game:GetService("Lighting")

local LightingService = {}

local SETTINGS = {
	ClockTime = 13.5,
	GeographicLatitude = 35,
	Brightness = 1.7,
	ExposureCompensation = -0.1,
	Ambient = Color3.fromRGB(95, 95, 105),
	OutdoorAmbient = Color3.fromRGB(135, 135, 145),
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 0.08,
	ShadowSoftness = 0.25,
	GlobalShadows = true,
}

function LightingService.Apply()
	for property, value in pairs(SETTINGS) do
		(Lighting :: any)[property] = value
	end
	-- glare off: bloom and sun rays wash out light blocks (sand, quartz)
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") then
			effect.Enabled = false
		end
	end
	local grade = Lighting:FindFirstChild("PrisonColor")
	if not grade then
		local new = Instance.new("ColorCorrectionEffect")
		new.Name = "PrisonColor"
		new.Parent = Lighting
		grade = new
	end
	local correction = grade :: ColorCorrectionEffect
	correction.Brightness = -0.02
	correction.Contrast = 0.06
	correction.Saturation = 0.08
	correction.TintColor = Color3.fromRGB(255, 252, 245)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		local new = Instance.new("Atmosphere")
		new.Parent = Lighting
		atmosphere = new
	end
	local air = atmosphere :: Atmosphere
	air.Density = 0.22
	air.Offset = 0.1
	air.Haze = 0.6
	air.Glare = 0
	air.Color = Color3.fromRGB(200, 215, 235)
	air.Decay = Color3.fromRGB(110, 130, 160)
end

function LightingService.Start()
	LightingService.Apply()
end

return LightingService
