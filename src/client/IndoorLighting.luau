--!strict
-- Brighter light inside closed places [владелец 22.10: «в шахте плохое освещение, камня почти не видно»].
-- Under a roof the sky does not reach the blocks and only Lighting.Ambient lights them, which made the
-- quarry cave nearly black. Parts tagged IndoorLighting (scripts/build-quarry.luau: the cave volume)
-- carry the attributes Ambient (Color3) and Exposure (number); while the local player stands inside one,
-- the client eases Lighting toward those values and thins the outdoor haze, and eases back outside.
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
	local outdoor: { Ambient: Color3, ExposureCompensation: number, Density: number? }? = nil
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
					Density = if air then air.Density else nil,
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
			if air then
				TweenService:Create(air, EASE, { Density = INDOOR_HAZE }):Play()
			end
		elseif outdoor then
			TweenService:Create(Lighting, EASE, {
				Ambient = outdoor.Ambient,
				ExposureCompensation = outdoor.ExposureCompensation,
			}):Play()
			if air and outdoor.Density then
				TweenService:Create(air, EASE, { Density = outdoor.Density }):Play()
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
