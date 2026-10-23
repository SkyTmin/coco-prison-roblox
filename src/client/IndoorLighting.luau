--!strict
-- Brighter light inside closed places [владелец 22.10: «в шахте плохое освещение, камня почти не видно»].
-- Under a roof the sky does not reach the blocks and only Lighting.Ambient lights them, which made the
-- quarry cave nearly black. Parts tagged IndoorLighting (scripts/build-quarry.luau: the cave volume)
-- carry the attributes Ambient (Color3) and Exposure (number); while the local player stands inside one,
-- the client eases Lighting toward those values and thins the outdoor haze, and eases back outside.
-- Optional attributes tint the air of a whole location (Преисподняя: a red murk, scripts/build-underworld.luau):
-- Haze (Atmosphere.Density instead of the thin indoor haze), AtmosphereColor, AtmosphereDecay (Color3);
-- ClockTime and Brightness turn an open location to night (Пустотная крепость: scripts/build-end-castle.luau).
-- Local only: other players keep their own lighting.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local IndoorLighting = {}

local CHECK_EVERY = 0.25
local EASE = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
local INDOOR_HAZE = 0.05 -- Atmosphere.Density inside: the outdoor haze turned the cave grey

local started = false

local function inside(volume: BasePart, position: Vector3): boolean
	local p = volume.CFrame:PointToObjectSpace(position)
	local half = volume.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function IndoorLighting.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local outdoor: {
		Ambient: Color3,
		ExposureCompensation: number,
		ClockTime: number,
		Brightness: number,
		Density: number?,
		Color: Color3?,
		Decay: Color3?,
		Haze: number?,
	}? =
		nil
	local current: BasePart? = nil
	local function atmosphere(): Atmosphere?
		return Lighting:FindFirstChildOfClass("Atmosphere")
	end
	local function apply(volume: BasePart?)
		if volume == current then
			return
		end
		local air = atmosphere()
		if volume then
			if not current then
				-- remember the outdoor values (the server sets them) to come back to
				outdoor = {
					Ambient = Lighting.Ambient,
					ExposureCompensation = Lighting.ExposureCompensation,
					ClockTime = Lighting.ClockTime,
					Brightness = Lighting.Brightness,
					Density = if air then air.Density else nil,
					Color = if air then air.Color else nil,
					Decay = if air then air.Decay else nil,
					Haze = if air then air.Haze else nil,
				}
			end
			local ambient = volume:GetAttribute("Ambient")
			local exposure = volume:GetAttribute("Exposure")
			TweenService:Create(Lighting, EASE, {
				Ambient = if typeof(ambient) == "Color3" then ambient else Lighting.Ambient,
				ExposureCompensation = if typeof(exposure) == "number"
					then exposure
					else Lighting.ExposureCompensation,
			}):Play()
			-- the clock jumps (a tween would sweep the sun across the sky)
			local clock = volume:GetAttribute("ClockTime")
			local brightness = volume:GetAttribute("Brightness")
			if outdoor then
				Lighting.ClockTime = if typeof(clock) == "number" then clock else outdoor.ClockTime
				Lighting.Brightness = if typeof(brightness) == "number"
					then brightness
					else outdoor.Brightness
			end
			if air and outdoor then
				local haze = volume:GetAttribute("Haze")
				local color = volume:GetAttribute("AtmosphereColor")
				local decay = volume:GetAttribute("AtmosphereDecay")
				TweenService
					:Create(air, EASE, {
						Density = if typeof(haze) == "number" then haze else INDOOR_HAZE,
						Color = if typeof(color) == "Color3"
							then color
							else outdoor.Color or air.Color,
						Decay = if typeof(decay) == "Color3"
							then decay
							else outdoor.Decay or air.Decay,
						-- the outdoor haze glows in the sky colour; indoors it washed everything milky white
						Haze = 0,
					})
					:Play()
			end
		elseif outdoor then
			TweenService:Create(Lighting, EASE, {
				Ambient = outdoor.Ambient,
				ExposureCompensation = outdoor.ExposureCompensation,
			}):Play()
			Lighting.ClockTime = outdoor.ClockTime
			Lighting.Brightness = outdoor.Brightness
			if air and outdoor.Density then
				TweenService:Create(air, EASE, {
					Density = outdoor.Density,
					Color = outdoor.Color or air.Color,
					Decay = outdoor.Decay or air.Decay,
					Haze = outdoor.Haze or air.Haze,
				}):Play()
			end
			outdoor = nil
		end
		current = volume
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local found: BasePart? = nil
			if root and root:IsA("BasePart") then
				for _, volume in ipairs(CollectionService:GetTagged("IndoorLighting")) do
					if volume:IsA("BasePart") and inside(volume, root.Position) then
						found = volume
						break
					end
				end
			end
			apply(found)
		end
	end)
end

return IndoorLighting
