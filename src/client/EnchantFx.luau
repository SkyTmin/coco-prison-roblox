--!strict
-- PRIS+ particles of the ancient enchants [сеть S7, TG/27] (этап 8): the server sends EnchantFx(kind, position, power)
-- when the Вихрь (vortex), Ярость (rage) or Бульдозер (bulldozer) book of a PRIS+ player works near us (BookService).
-- Our own look, Roblox's built-in particle textures: a cyan whirl that climbs around the target, red sparks (more for
-- a longer Ярость streak), a puff of brown dust. Local only and cosmetic; settings.enchantFxOff hides them on this
-- screen [сеть TG/40: «эффекты чар можно выключить в /settings»].
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local EnchantFx = {}
local started = false

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function holder(position: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "EnchantFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	Debris:AddItem(part, 3)
	return part
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0.6
	for key, value in pairs(props) do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local DRAW: { [string]: (Vector3, number) -> () } = {
	vortex = function(position, _power)
		local part = holder(position, Vector3.new(5, 6, 5))
		local e = emitter(part, {
			Texture = SPARK,
			Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Color = ColorSequence.new(Color3.fromRGB(140, 240, 255), Color3.fromRGB(255, 255, 255)),
			Size = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 9, 0),
			RotSpeed = NumberRange.new(-360, 360),
			Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(180, 180),
		})
		e:Emit(36)
	end,
	rage = function(position, power)
		local part = holder(position + Vector3.new(0, 1, 0), Vector3.new(2, 3, 2))
		local e = emitter(part, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 70, 40), Color3.fromRGB(255, 190, 60)),
			Size = NumberSequence.new(0.5, 0),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(6, 12),
			Acceleration = Vector3.new(0, -20, 0),
			SpreadAngle = Vector2.new(180, 180),
		})
		e:Emit(math.clamp(6 * power, 6, 40))
	end,
	bulldozer = function(position, _power)
		local part = holder(position - Vector3.new(0, 2, 0), Vector3.new(4, 1, 4))
		local e = emitter(part, {
			Texture = SMOKE,
			LightEmission = 0,
			Color = ColorSequence.new(Color3.fromRGB(150, 115, 80), Color3.fromRGB(110, 90, 70)),
			Transparency = NumberSequence.new(0.3, 1),
			Size = NumberSequence.new(1.2, 3),
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 2, 0),
			SpreadAngle = Vector2.new(80, 80),
		})
		e:Emit(18)
	end,
}

function EnchantFx.start(profile: () -> Types.Profile?)
	if started then
		return
	end
	started = true
	task.spawn(function() -- the remote may not be replicated yet
		Remotes.unreliable("EnchantFx").OnClientEvent
			:Connect(function(kind: any, position: any, power: any)
				local draw = typeof(kind) == "string" and DRAW[kind]
				if not draw or typeof(position) ~= "Vector3" then
					return
				end
				local p = profile()
				if p and p.settings and p.settings.enchantFxOff then
					return
				end
				draw(position, if typeof(power) == "number" then power else 1)
			end)
	end)
end

return EnchantFx
