--!strict
-- Blocky mob models made in Blender [владелец 22.10: крыса в блендере, по фото от Codex, точь в точь]:
-- assets/models/<name>/<name>.py → src/shared/Models/<name>.json — boxes hanging on joints, plus clips of joint
-- keyframes (Roblox space, the model faces −Z, origin on the ground).
-- BlockRig.build (server): one invisible part per joint, chained by Motor6Ds (C0 = the pivot in the parent
-- joint's space), the boxes welded to their joints; the fur is one grey pixel-noise texture tinted per face
-- (top faces may take a darker colour); parts with glow = true are Neon. BlockRig.sample (client): the joint CFrames of a clip at a time, for
-- Motor6D.Transform (src/client/MobAnimator.luau).

local BlockRig = {}

export type Key = { t: number, cf: CFrame }
export type Clip = { length: number, loop: boolean, tracks: { [string]: { Key } } }
export type Prepared = { clips: { [string]: Clip }, joints: { string } }

local MIN_FACE = 0.25 -- faces smaller than this get no texture (eyes, teeth, plate edges)
local FACES = {
	{ Enum.NormalId.Top, "X", "Z" },
	{ Enum.NormalId.Front, "X", "Y" },
	{ Enum.NormalId.Back, "X", "Y" },
	{ Enum.NormalId.Left, "Z", "Y" },
	{ Enum.NormalId.Right, "Z", "Y" },
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function invisible(name: string, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- the grey tile × tint = the colour: the tile's mean brightness is def.texture.mean
-- the game lift (def.texture.saturate / gain): Roblox's cool sky light greys low-saturation colours
local function lift(c: Color3, saturate: number, gain: number): Color3
	local m = (c.R + c.G + c.B) / 3
	local function ch(v: number): number
		return math.clamp((m + (v - m) * saturate) * gain, 0, 1)
	end
	return Color3.new(ch(c.R), ch(c.G), ch(c.B))
end

local function tint(c: Color3, mean: number): Color3
	return Color3.new(math.min(1, c.R / mean), math.min(1, c.G / mean), math.min(1, c.B / mean))
end

-- Builds the boxes into model, rigged to root; origin = where the model's (0, 0, 0) lies (on the ground).
function BlockRig.build(def: any, model: Model, root: BasePart, origin: CFrame, texture: string?)
	local joints: { [string]: BasePart } = {}
	for _, j in ipairs(def.joints) do
		local part = invisible("J_" .. j.name, origin * CFrame.new(vec(j.pivot)), model)
		local parent = if j.parent then joints[j.parent] else root
		local motor = Instance.new("Motor6D")
		motor.Name = j.name
		motor.C0 = parent.CFrame:ToObjectSpace(part.CFrame)
		motor.Part0 = parent
		motor.Part1 = part
		motor.Parent = part
		joints[j.name] = part
	end
	local tex = def.texture or {}
	local studs = tex.studsPerTile or 2.25
	local mean = tex.mean or 0.92
	local saturate, gain = tex.saturate or 1, tex.gain or 1
	local rnd = Random.new(7)
	for i, raw in ipairs(def.parts) do
		-- big models store parts as arrays [joint, centre, size, colour, top, glow, rot] (blockmob export)
		local d = if raw.joint
			then raw
			else {
				name = "P" .. i,
				joint = raw[1],
				centre = raw[2],
				size = raw[3],
				colour = raw[4],
				top = raw[5],
				glow = raw[6] == 1,
				rot = raw[7],
			}
		local p = Instance.new("Part")
		p.Name = d.name
		p.Size = vec(d.size)
		local cf = origin * CFrame.new(vec(d.centre))
		if d.rot then
			cf *= CFrame.new(0, 0, 0, d.rot[1], d.rot[2], d.rot[3], d.rot[4])
		end
		p.CFrame = cf
		p.Color = if d.glow then rgb(d.colour) else lift(rgb(d.colour), saturate, gain) -- lava keeps its colour
		-- glowing parts (lava cracks, eyes): Neon in their own colour, no texture
		p.Material = if d.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = true
		p.CanTouch = false
		p.Massless = true
		if texture and not d.glow then
			local u, v = rnd:NextNumber(0, studs), rnd:NextNumber(0, studs)
			for _, f in ipairs(FACES) do
				local size = p.Size :: any
				if size[f[2]] >= MIN_FACE and size[f[3]] >= MIN_FACE then
					local t = Instance.new("Texture")
					t.Texture = texture
					t.Face = f[1]
					t.StudsPerTileU = studs
					t.StudsPerTileV = studs
					t.OffsetStudsU = u
					t.OffsetStudsV = v
					t.Color3 = tint(
						if f[1] == Enum.NormalId.Top and d.top
							then lift(rgb(d.top), saturate, gain)
							else p.Color,
						mean
					)
					t.Parent = p
				end
			end
		end
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = joints[d.joint]
		w.Part1 = p
		w.Parent = p
	end
end

-- Keyframes → CFrames once per definition.
local cache: { [any]: Prepared } = {}
function BlockRig.prepare(def: any): Prepared
	local hit = cache[def]
	if hit then
		return hit
	end
	local clips: { [string]: Clip } = {}
	for name, c in pairs(def.clips) do
		local tracks: { [string]: { Key } } = {}
		for joint, keys in pairs(c.tracks) do
			local list: { Key } = {}
			for _, k in ipairs(keys) do
				local q, p = k.q, k.p
				table.insert(
					list,
					{ t = k.t, cf = CFrame.new(p[1], p[2], p[3], q[1], q[2], q[3], q[4]) }
				)
			end
			tracks[joint] = list
		end
		clips[name] = { length = c.length, loop = c.loop, tracks = tracks }
	end
	local joints = {}
	for _, j in ipairs(def.joints) do
		table.insert(joints, j.name)
	end
	local out = { clips = clips, joints = joints }
	cache[def] = out
	return out
end

-- The joint CFrame of a clip at time t (looped clips wrap, the others hold their ends).
function BlockRig.sample(clip: Clip, joint: string, t: number): CFrame
	local keys = clip.tracks[joint]
	if not keys then
		return CFrame.identity
	end
	if clip.loop and clip.length > 0 then
		t = t % clip.length
	end
	if t <= keys[1].t then
		return keys[1].cf
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			return a.cf:Lerp(b.cf, (t - a.t) / math.max(1e-4, b.t - a.t))
		end
	end
	return keys[#keys].cf
end

return BlockRig
