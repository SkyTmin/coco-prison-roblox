--!strict
-- Minecraft-style block breaking feedback, purely client-side cosmetics:
--   * crack decals in 10 stages on every face of the block being dug (Config.effects.cracks),
--   * a hit sound every 0.25 s while digging and a break sound when the block goes (per material),
--   * crumb particles while digging and a burst of block-textured particles on break.
-- The server still owns the dig (DigService); this module only reacts to the local dig state.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local BlockBreak = {}

local FACES = Enum.NormalId:GetEnumItems()
local HIT_INTERVAL = 0.25 -- [ваниль] hit sound/particles every 5 ticks
local current: BasePart? = nil
local decals: { Decal } = {}
local stage = -1
local lastHit = 0

local function stages(): { string }
	local effects = Config.effects
	return if effects
			and effects.cracks
			and effects.cracks.stages
		then effects.cracks.stages
		else {}
end

local function materialOf(part: BasePart): string
	local effects = Config.effects
	local id = part:GetAttribute("Block")
	local map = effects and effects.sounds and effects.sounds.blockMaterial
	if typeof(id) == "string" and map then
		return map[id] or map._default or "stone"
	end
	return "stone"
end

local function soundFor(part: BasePart, kind: "hit" | "break"): string?
	local effects = Config.effects
	local materials = effects and effects.sounds and effects.sounds.materials
	local entry = materials and materials[materialOf(part)]
	return if entry then entry[kind] else nil
end

local function playAt(position: Vector3, id: string?, volume: number, pitch: number)
	if not id or id == "" then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "BlockSound"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
	holder.Position = position
	holder.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMaxDistance = 60
	sound.RollOffMinDistance = 8
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 3)
end

local function textureOf(part: BasePart): string?
	local id = part:GetAttribute("Block")
	local textures = Config.textures and Config.textures.textures
	return if typeof(id) == "string" and textures then textures[id] else nil
end

-- Block-textured particles. amount ≈ 6 for a hit, 30 for a break.
local function emit(part: BasePart, amount: number, strong: boolean)
	local holder = Instance.new("Part")
	holder.Name = "BlockParticles"
	holder.Size = part.Size * 0.9
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
	holder.CFrame = part.CFrame
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	local texture = textureOf(part)
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = if texture
		then ColorSequence.new(Color3.new(1, 1, 1))
		else ColorSequence.new(part.Color)
	e.Size = NumberSequence.new(if strong then 0.45 else 0.3)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(if strong then 5 else 2, if strong then 11 else 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Drag = 2
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightInfluence = 1
	e.Parent = holder
	e:Emit(amount)
	Debris:AddItem(holder, 2)
end

local function clearDecals()
	for _, d in ipairs(decals) do
		d:Destroy()
	end
	table.clear(decals)
	stage = -1
end

-- Called every frame while digging with progress k in [0, 1].
function BlockBreak.Update(part: BasePart, k: number)
	local list = stages()
	if part ~= current then
		clearDecals()
		current = part
		lastHit = 0
		if #list > 0 then
			for _, face in ipairs(FACES) do
				local d = Instance.new("Decal")
				d.Name = "Crack"
				d.Face = face
				d.Texture = list[1]
				d.ZIndex = 2
				d.Parent = part
				table.insert(decals, d)
			end
		end
	end
	if #list > 0 then
		local s = math.clamp(math.floor(k * #list) + 1, 1, #list)
		if s ~= stage then
			stage = s
			for _, d in ipairs(decals) do
				d.Texture = list[s]
			end
		end
	end
	local now = os.clock()
	if now - lastHit >= HIT_INTERVAL then
		lastHit = now
		playAt(part.Position, soundFor(part, "hit"), 0.6, 0.9 + math.random() * 0.2)
		emit(part, 5, false)
	end
end

-- Digging stopped before the block broke: Minecraft drops the progress immediately.
function BlockBreak.Clear()
	clearDecals()
	current = nil
end

-- The block is about to disappear: burst of particles + break sound.
function BlockBreak.Break(part: BasePart)
	clearDecals()
	current = nil
	playAt(part.Position, soundFor(part, "break"), 0.9, 0.95 + math.random() * 0.1)
	emit(part, 32, true)
end

-- Preload sounds so the first hit is not silent.
function BlockBreak.Start()
	local effects = Config.effects
	local materials = effects and effects.sounds and effects.sounds.materials
	if not materials then
		return
	end
	for _, entry in pairs(materials) do
		for _, kind in ipairs({ "hit", "break" }) do
			local id = entry[kind]
			if id then
				local s = Instance.new("Sound")
				s.SoundId = id
				s.Volume = 0
				s.Parent = SoundService
				task.spawn(function()
					pcall(function()
						game:GetService("ContentProvider"):PreloadAsync({ s })
					end)
					s:Destroy()
				end)
			end
		end
	end
end

return BlockBreak
