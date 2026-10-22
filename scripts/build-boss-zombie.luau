--!nocheck
-- Builds the template of the boss Зомбарь (giant_zombie) of the faction base: a giant blocky Minecraft
-- zombie [решение; клиент: «Груда плоти, источающая гной… Пробуждённый мертвец»] — green rotting skin,
-- a torn teal shirt, blue trousers, a pixel face with dark eye sockets, pus stains. Minecraft proportions
-- (head 8 px, body 8×12×4, limbs 4×12×4) at 0.38 studs per pixel ≈ 12 studs tall (about two players,
-- like the Базальтовый страж — the owner found bigger bosses too big, 22.10). The front faces −Z.
-- BossService rigs it from the limb names (Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg).
-- Run in Studio (Edit) via scripts/studio-loader.luau. Idempotent: replaces
-- ServerStorage.BossTemplates.giant_zombie.

local ServerStorage = game:GetService("ServerStorage")
local templates = ServerStorage:FindFirstChild("BossTemplates")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "BossTemplates"
	templates.Parent = ServerStorage
end
local old = templates:FindFirstChild("giant_zombie")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "giant_zombie"

local P = 0.38 -- studs per Minecraft pixel
local SKIN = Color3.fromRGB(88, 130, 70)
local SKIN_DARK = Color3.fromRGB(62, 98, 50)
local SHIRT = Color3.fromRGB(38, 140, 140)
local SHIRT_DARK = Color3.fromRGB(28, 104, 106)
local PANTS = Color3.fromRGB(62, 58, 140)
local PANTS_DARK = Color3.fromRGB(44, 42, 105)
local PUS = Color3.fromRGB(170, 200, 70)
local rng = Random.new(20261024)

local function part(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function limb(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = model
	return m
end
-- a few pixel-sized patches on a face of a part, for the Minecraft skin noise
local function speckle(parent, base, size, face, colors, count)
	local half = size / 2
	for _ = 1, count do
		local w, h = P * rng:NextInteger(1, 2), P * rng:NextInteger(1, 2)
		local u = rng:NextNumber(-half.X + w / 2, half.X - w / 2)
		local v = rng:NextNumber(-half.Y + h / 2, half.Y - h / 2)
		local cf = if face == "front"
			then base * CFrame.new(u, v, -half.Z - 0.02)
			elseif face == "back" then base * CFrame.new(u, v, half.Z + 0.02)
			elseif face == "left" then base * CFrame.new(-half.X - 0.02, v, rng:NextNumber(-half.Z + w / 2, half.Z - w / 2)) * CFrame.Angles(0, math.pi / 2, 0)
			else base * CFrame.new(half.X + 0.02, v, rng:NextNumber(-half.Z + w / 2, half.Z - w / 2)) * CFrame.Angles(0, math.pi / 2, 0)
		part("Speck", Vector3.new(w, h, 0.05), cf, colors[rng:NextInteger(1, #colors)], parent)
	end
end

local legH, bodyH, head = 12 * P, 12 * P, 8 * P
local legW, bodyW, bodyD = 4 * P, 8 * P, 4 * P
local hip = legH
local shoulder = hip + bodyH

-- legs: trousers with darker seams, shoes of rotten skin at the bottom
for _, s in ipairs({ -1, 1 }) do
	local m = limb(if s < 0 then "LeftLeg" else "RightLeg")
	local size = Vector3.new(legW, legH, legW)
	local cf = CFrame.new(s * legW / 2, legH / 2, 0)
	part("Leg", size, cf, PANTS, m)
	part("Foot", Vector3.new(legW + 0.04, 2 * P, legW + 0.04), CFrame.new(s * legW / 2, P, 0), SKIN_DARK, m)
	speckle(m, cf, size, "front", { PANTS_DARK }, 4)
	speckle(m, cf, size, if s < 0 then "left" else "right", { PANTS_DARK }, 3)
end
-- the body: the torn shirt, skin showing through the holes, pus stains
do
	local m = limb("Torso")
	local size = Vector3.new(bodyW, bodyH, bodyD)
	local cf = CFrame.new(0, hip + bodyH / 2, 0)
	part("Body", size, cf, SHIRT, m)
	part("Belt", Vector3.new(bodyW + 0.04, 1.2 * P, bodyD + 0.04), CFrame.new(0, hip + 0.6 * P, 0), PANTS, m)
	speckle(m, cf, size, "front", { SHIRT_DARK, SKIN, SKIN_DARK }, 8)
	speckle(m, cf, size, "back", { SHIRT_DARK, SKIN }, 6)
	part("Hole", Vector3.new(3 * P, 2 * P, 0.05), cf * CFrame.new(-1 * P, -2 * P, -bodyD / 2 - 0.03), SKIN, m)
	part("Pus", Vector3.new(1 * P, 2 * P, 0.05), cf * CFrame.new(2 * P, 1 * P, -bodyD / 2 - 0.04), PUS, m)
end
-- arms: stretched forward like every Minecraft zombie (BossAnimator keeps them up while it walks);
-- short sleeves of the shirt, the rest rotting skin
for _, s in ipairs({ -1, 1 }) do
	local m = limb(if s < 0 then "LeftArm" else "RightArm")
	local size = Vector3.new(legW, bodyH, legW)
	local cf = CFrame.new(s * (bodyW / 2 + legW / 2), hip + bodyH / 2, 0)
	part("Arm", size, cf, SKIN, m)
	part("Sleeve", Vector3.new(legW + 0.04, 4 * P, legW + 0.04), cf * CFrame.new(0, bodyH / 2 - 2 * P, 0), SHIRT, m)
	speckle(m, cf, size, "front", { SKIN_DARK, PUS }, 4)
	speckle(m, cf, size, if s < 0 then "left" else "right", { SKIN_DARK }, 4)
end
-- the head: dark eye sockets with a sick glow, a nose, a gaping mouth
do
	local m = limb("Head")
	local size = Vector3.new(head, head, head)
	local cf = CFrame.new(0, shoulder + head / 2, 0)
	part("Skull", size, cf, SKIN, m)
	speckle(m, cf, size, "front", { SKIN_DARK }, 6)
	speckle(m, cf, size, "left", { SKIN_DARK }, 5)
	speckle(m, cf, size, "right", { SKIN_DARK }, 5)
	speckle(m, cf, size, "back", { SKIN_DARK }, 5)
	local front = -head / 2 - 0.04
	for _, s in ipairs({ -1, 1 }) do
		part("EyeSocket", Vector3.new(2 * P, 1 * P, 0.06), cf * CFrame.new(s * 2 * P, 0.5 * P, front), Color3.fromRGB(20, 25, 18), m)
		local eye = part("Eye", Vector3.new(1 * P, 1 * P, 0.07), cf * CFrame.new(s * 1.5 * P, 0.5 * P, front - 0.01), Color3.fromRGB(150, 255, 110), m)
		eye.Material = Enum.Material.Neon
	end
	part("Nose", Vector3.new(2 * P, 1 * P, 0.06), cf * CFrame.new(0, -0.6 * P, front), SKIN_DARK, m)
	part("Mouth", Vector3.new(4 * P, 1 * P, 0.06), cf * CFrame.new(0, -2.2 * P, front), Color3.fromRGB(35, 45, 30), m)
	part("Hair", Vector3.new(head + 0.04, 1 * P, head + 0.04), cf * CFrame.new(0, head / 2 - 0.5 * P, 0), SKIN_DARK, m)
end
-- flies buzzing around the rotting head
local fliesAt = part("Flies", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, shoulder + head + 1, 0), SKIN, model.Head)
fliesAt.Transparency = 1
local flies = Instance.new("ParticleEmitter")
flies.Rate = 6
flies.Lifetime = NumberRange.new(1, 2)
flies.Speed = NumberRange.new(1, 3)
flies.SpreadAngle = Vector2.new(180, 180)
flies.Size = NumberSequence.new(0.12)
flies.Color = ColorSequence.new(Color3.fromRGB(20, 20, 20))
flies.Parent = fliesAt
-- green stench rising from the body
local stench = Instance.new("ParticleEmitter")
stench.Rate = 4
stench.Lifetime = NumberRange.new(2, 3)
stench.Speed = NumberRange.new(0.5, 1.2)
stench.SpreadAngle = Vector2.new(30, 30)
stench.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2) })
stench.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
stench.Color = ColorSequence.new(PUS)
stench.Parent = model.Torso.Body

model.PrimaryPart = model.Torso.Body
model.Parent = templates
local n = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "[build-boss-zombie] template giant_zombie, parts: " .. n .. ", height: " .. string.format("%.1f", shoulder + head)
