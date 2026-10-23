--!strict
-- Cobwebs as in Minecraft [ваниль]: the block is drawn as a cross sprite — two crossed planes along the
-- block's diagonals with the web picture on both sides (Config.textures.sprites.cobweb: VoxeLibre
-- mcl_core_web.png recoloured white, CC BY-SA 4.0) — it has no collision, and an entity inside it moves
-- at 0.25 of its speed sideways and 0.05 vertically (Entity.makeStuckInBlock), which also cancels the fall.
-- A web is any part tagged "Cobweb" (mine blocks of type cobweb, decor webs of the locations); the
-- part's box is the web's box. Both the server (fall damage) and the client (movement) keep an index.

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

local Cobweb = {}

Cobweb.TAG = "Cobweb"
Cobweb.HORIZONTAL = 0.25 -- [ваниль] stuckSpeedMultiplier (0.25, 0.05, 0.25)
Cobweb.VERTICAL = 0.05
-- What that feels like [ваниль]: Entity.move multiplies the tick's motion by the multiplier AND zeroes the
-- velocity, so momentum never builds — every tick moves only that tick's input acceleration × 0.25. Walking
-- on the ground: 0.098 blocks/tick of acceleration against a 0.2159 blocks/tick top speed (4.317 m/s) →
-- 0.098 · 0.25 / 0.2159 ≈ 0.113 of the walk speed (≈ 0.49 blocks/s). Hanging in the web (airborne) the
-- input is 0.02 · 0.98 a tick → 0.0196 · 0.25 / 0.2159 ≈ 0.023 (≈ 0.1 blocks/s): you barely crawl until
-- your feet touch the floor. A jump gives 0.42 · 0.05 ≈ 0.02 blocks — no jump at all.
Cobweb.WALK = 0.098 * Cobweb.HORIZONTAL / 0.2159
Cobweb.AIR = 0.02 * 0.98 * Cobweb.HORIZONTAL / 0.2159

local sprites = (Config.textures :: any).sprites
Cobweb.TEXTURE = (if sprites then sprites.cobweb else nil) :: string?

-- Two crossed planes filling a cube of `size` studs centred at cf, children of parent (named "CobwebSprite").
-- They never collide, are never hit by rays and cast no shadow; the decals face both ways.
function Cobweb.sprite(cf: CFrame, size: number, parent: Instance, color: Color3?)
	for _, yaw in ipairs({ math.pi / 4, -math.pi / 4 }) do
		local plane = Instance.new("Part")
		plane.Name = "CobwebSprite"
		plane.Size = Vector3.new(size * math.sqrt(2), size, 0.05)
		plane.CFrame = cf * CFrame.Angles(0, yaw, 0)
		plane.Anchored = true
		plane.CanCollide = false
		plane.CanQuery = false
		plane.CanTouch = false
		plane.CastShadow = false
		plane.Transparency = 1
		if Cobweb.TEXTURE then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local decal = Instance.new("Decal")
				decal.Texture = Cobweb.TEXTURE :: string
				decal.Face = face
				decal.Color3 = color or Color3.new(1, 1, 1)
				decal.Parent = plane
			end
		end
		plane.Parent = parent
	end
end

-- ---------------------------------------------------------------- the index (x, z buckets of 16 studs)
local BUCKET = 16
local buckets: { [number]: { [BasePart]: true } } = {}
local placed: { [BasePart]: { number } } = {}
local function key(bx: number, bz: number): number
	return bx * 65536 + bz
end

local function remove(part: BasePart)
	local keys = placed[part]
	if not keys then
		return
	end
	for _, k in ipairs(keys) do
		local b = buckets[k]
		if b then
			b[part] = nil
			if next(b) == nil then
				buckets[k] = nil
			end
		end
	end
	placed[part] = nil
end

local function add(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	remove(inst)
	local half = inst.Size / 2
	local p = inst.Position
	local keys = {}
	for bx = math.floor((p.X - half.X) / BUCKET), math.floor((p.X + half.X) / BUCKET) do
		for bz = math.floor((p.Z - half.Z) / BUCKET), math.floor((p.Z + half.Z) / BUCKET) do
			local k = key(bx, bz)
			local b = buckets[k]
			if not b then
				b = {}
				buckets[k] = b
			end
			b[inst] = true
			table.insert(keys, k)
		end
	end
	placed[inst] = keys
end

local started = false
function Cobweb.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(Cobweb.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Cobweb.TAG):Connect(function(inst)
		if inst:IsA("BasePart") then
			remove(inst)
		end
	end)
	for _, inst in ipairs(CollectionService:GetTagged(Cobweb.TAG)) do
		add(inst)
	end
end

-- Does the axis-aligned box lo..hi touch a web (the webs' own boxes, as axis-aligned cubes)?
function Cobweb.touching(lo: Vector3, hi: Vector3): boolean
	local seen: { [BasePart]: true } = {}
	for bx = math.floor(lo.X / BUCKET), math.floor(hi.X / BUCKET) do
		for bz = math.floor(lo.Z / BUCKET), math.floor(hi.Z / BUCKET) do
			local b = buckets[key(bx, bz)]
			if b then
				for part in pairs(b) do
					if not seen[part] then
						seen[part] = true
						if part.Parent then
							local p, h = part.Position, part.Size / 2
							if
								lo.X < p.X + h.X
								and hi.X > p.X - h.X
								and lo.Y < p.Y + h.Y
								and hi.Y > p.Y - h.Y
								and lo.Z < p.Z + h.Z
								and hi.Z > p.Z - h.Z
							then
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end

-- Is this character inside a web? (its body box: feet to the top of the head, a little narrower than the rig)
function Cobweb.holds(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root then
		return false
	end
	local p = root.Position
	local feet = p.Y - root.Size.Y / 2 - humanoid.HipHeight
	return Cobweb.touching(
		Vector3.new(p.X - 0.9, feet + 0.05, p.Z - 0.9),
		Vector3.new(p.X + 0.9, p.Y + 2.4, p.Z + 0.9)
	)
end

return Cobweb
