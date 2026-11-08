--!nocheck
-- Software renderer for the Studio Relay ("the agent's eye"): works in Play and while Studio is
-- minimized, because it uses raycasts (physics) and GUI layout instead of the GPU frame.
--   World: one ray per pixel through camera.CFrame / FieldOfView, invisible parts skipped, partial
--   transparency blended, colour from Part.Color, MaterialVariant colour maps, Textures and Decals
--   sampled per face (owner's assets), sun + moon with shadow rays, point/spot lights, Atmosphere or
--   legacy fog, sky gradient, ColorCorrection; extra rays only on object edges (edge anti-aliasing).
--   GUI: every visible ScreenGui drawn from AbsolutePosition/Size: backgrounds, UICorner, UIGradient,
--   UIStroke, images (ImageRect, ScaleType, 9-slice) and text with a bundled bitmap font.
-- Included into StudioRelay.server.luau by build-plugin.mjs; returns render(opts) -> ok, result.

local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local FONTS = nil -- loaded lazily from the Font module next to the plugin script
local BASE64 = nil

---------------------------------------------------------------- helpers
local function srgbToLin(c)
	return c * c * (0.8 + 0.2 * c) -- fast approximation of the sRGB curve (gamma ~2.2)
end
local function linToSrgb(c)
	if c <= 0 then
		return 0
	end
	if c >= 1 then
		return 1
	end
	return c ^ (1 / 2.2)
end
local function clamp01(x)
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

local budgetStart = os.clock()
local function maybeYield()
	if os.clock() - budgetStart > 0.006 then
		task.wait()
		budgetStart = os.clock()
	end
end

---------------------------------------------------------------- images (owner's assets)
local imageCache = {}
local imageStats = { ok = 0, fail = 0, failed = {} }
-- property read that tolerates properties missing in older Studio builds
local function prop(obj, name)
	local ok, v = pcall(function()
		return obj[name]
	end)
	return if ok then v else nil
end
local function uriOf(obj, contentName, legacyName)
	local c = prop(obj, contentName)
	if typeof(c) == "Content" and c.Uri and c.Uri ~= "" then
		return c.Uri
	end
	return prop(obj, legacyName)
end

local function contentId(v)
	if typeof(v) == "Content" then
		return v.Uri
	end
	return v
end
local function loadImage(id)
	id = contentId(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local c = imageCache[id]
	if c ~= nil then
		return c or nil
	end
	local ok, img = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(id))
	end)
	if not ok or not img then
		imageCache[id] = false
		imageStats.fail += 1
		if #imageStats.failed < 8 then
			table.insert(imageStats.failed, id .. " " .. string.sub(tostring(img), 1, 80))
		end
		return nil
	end
	imageStats.ok += 1
	local size = img.Size
	local okR, buf = pcall(function()
		return img:ReadPixelsBuffer(Vector2.zero, size)
	end)
	img:Destroy()
	if not okR then
		imageCache[id] = false
		return nil
	end
	local w, h = size.X, size.Y
	-- average colour (alpha-weighted), used for meshes whose UVs we cannot know
	local sr, sg, sb, sa = 0, 0, 0, 0
	local step = math.max(1, math.floor(w * h / 4096))
	for i = 0, w * h - 1, step do
		local a = buffer.readu8(buf, i * 4 + 3) / 255
		sr += buffer.readu8(buf, i * 4) * a
		sg += buffer.readu8(buf, i * 4 + 1) * a
		sb += buffer.readu8(buf, i * 4 + 2) * a
		sa += a
	end
	sa = math.max(sa, 1e-6)
	local rec = { w = w, h = h, buf = buf, avg = { sr / sa / 255, sg / sa / 255, sb / sa / 255 } }
	imageCache[id] = rec
	return rec
end

-- nearest sample, u/v in 0..1 (wrapped); returns r,g,b,a in 0..1
local function sampleNearest(img, u, v)
	local x = math.floor((u % 1) * img.w)
	local y = math.floor((v % 1) * img.h)
	local i = (y * img.w + x) * 4
	local b = img.buf
	return buffer.readu8(b, i) / 255,
		buffer.readu8(b, i + 1) / 255,
		buffer.readu8(b, i + 2) / 255,
		buffer.readu8(b, i + 3) / 255
end

-- bilinear sample in pixel space (clamped); for GUI images
local function sampleBilinearPx(img, fx, fy)
	local w, h = img.w, img.h
	fx = math.clamp(fx - 0.5, 0, w - 1)
	fy = math.clamp(fy - 0.5, 0, h - 1)
	local x0, y0 = math.floor(fx), math.floor(fy)
	local x1, y1 = math.min(x0 + 1, w - 1), math.min(y0 + 1, h - 1)
	local tx, ty = fx - x0, fy - y0
	local b = img.buf
	local function px(x, y, k)
		return buffer.readu8(b, (y * w + x) * 4 + k)
	end
	local r, g, bl, a = 0, 0, 0, 0
	for k = 0, 3 do
		local v = (px(x0, y0, k) * (1 - tx) + px(x1, y0, k) * tx) * (1 - ty)
			+ (px(x0, y1, k) * (1 - tx) + px(x1, y1, k) * tx) * ty
		if k == 0 then
			r = v
		elseif k == 1 then
			g = v
		elseif k == 2 then
			bl = v
		else
			a = v
		end
	end
	return r / 255, g / 255, bl / 255, a / 255
end

---------------------------------------------------------------- faces and UV
-- per face: normal axis, right vector R, up vector U (object space); image v grows downwards
local FACES = {
	[Enum.NormalId.Top] = { Vector3.new(1, 0, 0), Vector3.new(0, 0, -1) },
	[Enum.NormalId.Bottom] = { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) },
	[Enum.NormalId.Front] = { Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0) },
	[Enum.NormalId.Back] = { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0) },
	[Enum.NormalId.Right] = { Vector3.new(0, 0, -1), Vector3.new(0, 1, 0) },
	[Enum.NormalId.Left] = { Vector3.new(0, 0, 1), Vector3.new(0, 1, 0) },
}
local function faceOf(localNormal)
	local ax, ay, az = math.abs(localNormal.X), math.abs(localNormal.Y), math.abs(localNormal.Z)
	if ay >= ax and ay >= az then
		return if localNormal.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
	elseif ax >= az then
		return if localNormal.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	end
	return if localNormal.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
end
local function absDot(a, b)
	return math.abs(a.X * b.X + a.Y * b.Y + a.Z * b.Z)
end
-- returns u, v (0..1 across the face), face width, face height in studs
local function faceUV(part, pos, face)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local size = part.Size
	local f = FACES[face]
	local R, U = f[1], f[2]
	local fw, fh = absDot(size, R), absDot(size, U)
	local u = (lp.X * R.X + lp.Y * R.Y + lp.Z * R.Z) / fw + 0.5
	local v = 0.5 - (lp.X * U.X + lp.Y * U.Y + lp.Z * U.Z) / fh
	return u, v, fw, fh
end

---------------------------------------------------------------- per-part surface info (cached per render)
local partInfo = {}
local function infoOf(part)
	local inf = partInfo[part]
	if inf then
		return inf
	end
	inf = { decals = nil, variant = nil, avg = nil }
	for _, ch in part:GetChildren() do
		if (ch:IsA("Decal") or ch:IsA("Texture")) and ch.Transparency < 0.99 then
			local img = loadImage(uriOf(ch, "ColorMapContent", "Texture"))
			if img then
				inf.decals = inf.decals or {}
				table.insert(inf.decals, { obj = ch, img = img, isTexture = ch:IsA("Texture") })
			end
		elseif ch:IsA("SpecialMesh") and ch.TextureId ~= "" then
			local img = loadImage(ch.TextureId)
			if img then
				local vc = ch.VertexColor
				inf.avg = { img.avg[1] * vc.X, img.avg[2] * vc.Y, img.avg[3] * vc.Z }
			end
		end
	end
	if part:IsA("MeshPart") then
		local tex = uriOf(part, "TextureContent", "TextureID")
		if tex and tex ~= "" then
			local img = loadImage(tex)
			if img then
				inf.avg = img.avg
			end
		end
	end
	if part.MaterialVariant ~= "" then
		local mv = MaterialService:FindFirstChild(part.MaterialVariant, true)
		if mv and mv:IsA("MaterialVariant") then
			local cm = uriOf(mv, "ColorMapContent", "ColorMap")
			local img = loadImage(cm)
			if img then
				inf.variant = { img = img, studs = mv.StudsPerTile > 0 and mv.StudsPerTile or 10 }
			end
		end
	end
	partInfo[part] = inf
	return inf
end

local function hasVisualChildren(part)
	for _, ch in part:GetChildren() do
		if ch:IsA("Decal") or ch:IsA("Texture") or ch:IsA("SurfaceGui") then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- scene state (per render)
local scene = {}

local function collectScene(cam)
	scene.sun = Lighting:GetSunDirection()
	scene.moon = Lighting:GetMoonDirection()
	local day = scene.sun.Y > -0.05
	scene.lightDir = if day then scene.sun else scene.moon
	local brightness = Lighting.Brightness * (if day then math.clamp(scene.sun.Y * 4 + 0.2, 0, 1) else 0.12)
	local top = Lighting.ColorShift_Top
	scene.direct = {
		srgbToLin(clamp01(0.5 + top.R * 0.5)) * brightness,
		srgbToLin(clamp01(0.5 + top.G * 0.5)) * brightness,
		srgbToLin(clamp01(0.5 + top.B * 0.5)) * brightness,
	}
	if top == Color3.new(0, 0, 0) then
		scene.direct = { brightness * 0.95, brightness * 0.93, brightness * 0.88 }
	end
	local amb, out = Lighting.Ambient, Lighting.OutdoorAmbient
	scene.ambient = { srgbToLin(amb.R), srgbToLin(amb.G), srgbToLin(amb.B) }
	scene.outdoor = { srgbToLin(out.R), srgbToLin(out.G), srgbToLin(out.B) }
	scene.envDiffuse = Lighting.EnvironmentDiffuseScale
	scene.shadows = Lighting.GlobalShadows
	scene.exposure = 2 ^ Lighting.ExposureCompensation

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	scene.atm = atm
	if atm then
		scene.fogColor = { srgbToLin(atm.Color.R), srgbToLin(atm.Color.G), srgbToLin(atm.Color.B) }
		scene.decay = { srgbToLin(atm.Decay.R), srgbToLin(atm.Decay.G), srgbToLin(atm.Decay.B) }
		scene.density = atm.Density
		scene.haze = atm.Haze
		scene.glare = atm.Glare
	else
		scene.fogStart, scene.fogEnd = Lighting.FogStart, Lighting.FogEnd
		local fc = Lighting.FogColor
		scene.fogColor = { srgbToLin(fc.R), srgbToLin(fc.G), srgbToLin(fc.B) }
	end
	scene.cc = {}
	for _, e in Lighting:GetChildren() do
		if e:IsA("ColorCorrectionEffect") and e.Enabled then
			table.insert(scene.cc, e)
		end
	end
	if cam then
		for _, e in cam:GetChildren() do
			if e:IsA("ColorCorrectionEffect") and e.Enabled then
				table.insert(scene.cc, e)
			end
		end
	end

	-- local lights near the camera (capped)
	scene.lights = {}
	local camPos = cam.CFrame.Position
	local candidates = {}
	for _, l in workspace:GetDescendants() do
		if (l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight")) and l.Enabled and l.Brightness > 0 then
			local p = l.Parent
			local pos = if p and p:IsA("BasePart")
				then p.Position
				elseif p and p:IsA("Attachment") then p.WorldPosition
				else nil
			if pos then
				local d = (pos - camPos).Magnitude
				if d < 400 then
					table.insert(candidates, { l = l, pos = pos, d = d })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(24, #candidates) do
		local c = candidates[i]
		local col = c.l.Color
		table.insert(scene.lights, {
			pos = c.pos,
			range = c.l.Range,
			bright = c.l.Brightness,
			col = { srgbToLin(col.R), srgbToLin(col.G), srgbToLin(col.B) },
			shadows = c.l.Shadows,
			part = c.l.Parent,
			params = (function()
				local p = RaycastParams.new()
				p.FilterType = Enum.RaycastFilterType.Exclude
				p.IgnoreWater = true
				p.FilterDescendantsInstances = { c.l.Parent }
				return p
			end)(),
		})
	end
end

---------------------------------------------------------------- sky
-- skybox faces: forward F, right R, up U as seen from inside the cube (orientation tuned by comparison)
local SKY_FACES = {
	{ "SkyboxFt", Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0) },
	{ "SkyboxBk", Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0) },
	{ "SkyboxRt", Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0) },
	{ "SkyboxLf", Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0) },
	{ "SkyboxUp", Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) },
	{ "SkyboxDn", Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) },
}
local function loadSkybox()
	local sky = Lighting:FindFirstChildOfClass("Sky")
	scene.skybox = nil
	if not sky then
		return
	end
	local faces = {}
	for i, f in SKY_FACES do
		local img = loadImage(prop(sky, f[1]))
		if not img then
			return
		end
		faces[i] = img
	end
	scene.skybox = faces
end
local function skyboxColor(dir)
	local best, bi = -2, 1
	for i, f in SKY_FACES do
		local d = dir.X * f[2].X + dir.Y * f[2].Y + dir.Z * f[2].Z
		if d > best then
			best, bi = d, i
		end
	end
	local f = SKY_FACES[bi]
	local u = 0.5 + 0.5 * (dir.X * f[3].X + dir.Y * f[3].Y + dir.Z * f[3].Z) / best
	local v = 0.5 - 0.5 * (dir.X * f[4].X + dir.Y * f[4].Y + dir.Z * f[4].Z) / best
	local img = scene.skybox[bi]
	local r, g, b = sampleBilinearPx(img, u * img.w, v * img.h)
	return srgbToLin(r), srgbToLin(g), srgbToLin(b)
end

local function skyColor(dir)
	if scene.skybox then
		local r, g, b = skyboxColor(dir)
		if scene.atm then
			-- atmosphere haze over the skybox near the horizon
			local h = (1 - math.abs(dir.Y)) ^ 6 * clamp01(scene.haze * 0.35 + scene.density)
			local c = scene.fogColor
			r, g, b = r * (1 - h) + c[1] * h, g * (1 - h) + c[2] * h, b * (1 - h) + c[3] * h
		end
		return r, g, b
	end
	local y = dir.Y
	local day = scene.sun.Y > -0.05
	local zen, hor
	if scene.atm then
		local ac = scene.atm.Color
		hor = { srgbToLin(ac.R), srgbToLin(ac.G), srgbToLin(ac.B) }
	end
	if day then
		local k = clamp01(scene.sun.Y * 3)
		zen = { 0.10 * k + 0.01, 0.30 * k + 0.02, 0.85 * k + 0.05 }
		hor = hor or { 0.55 * k + 0.05, 0.70 * k + 0.05, 0.95 * k + 0.08 }
	else
		zen = { 0.004, 0.006, 0.02 }
		hor = hor and { hor[1] * 0.15, hor[2] * 0.15, hor[3] * 0.2 } or { 0.02, 0.025, 0.05 }
	end
	local t = clamp01(y * 1.6)
	t = t ^ 0.6
	local r = hor[1] * (1 - t) + zen[1] * t
	local g = hor[2] * (1 - t) + zen[2] * t
	local b = hor[3] * (1 - t) + zen[3] * t
	-- sun disc
	local s = scene.sun
	local dot = dir.X * s.X + dir.Y * s.Y + dir.Z * s.Z
	if day and dot > 0.9995 then
		r, g, b = 4, 3.8, 3.4
	elseif day and dot > 0.98 then
		local k2 = (dot - 0.98) / 0.0195
		r += k2 * k2 * 0.6
		g += k2 * k2 * 0.55
		b += k2 * k2 * 0.45
	end
	return r, g, b
end

---------------------------------------------------------------- surface shading
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false
local shadowParams = RaycastParams.new()
shadowParams.FilterType = Enum.RaycastFilterType.Exclude
shadowParams.IgnoreWater = true

local function partAlpha(inst)
	if inst:IsA("Terrain") then
		return 1
	end
	local t = math.max(inst.Transparency, inst.LocalTransparencyModifier)
	if inst.Transparency < 1 and inst.LocalTransparencyModifier > 0 then
		t = 1 - (1 - inst.Transparency) * (1 - inst.LocalTransparencyModifier)
	end
	return 1 - t
end

local function occluded(from, dir, dist, rp)
	local origin = from
	rp = rp or shadowParams
	for _ = 1, 4 do
		local hit = workspace:Raycast(origin, dir * dist, rp)
		if not hit then
			return false
		end
		local inst = hit.Instance
		if inst:IsA("Terrain") or partAlpha(inst) > 0.5 then
			return true
		end
		local travelled = (hit.Position - origin).Magnitude + 0.05
		dist -= travelled
		if dist <= 0 then
			return false
		end
		origin = hit.Position + dir * 0.05
	end
	return false
end

-- base albedo (linear) and alpha for a hit; nil alpha = use part alpha
local function albedo(hit)
	local inst = hit.Instance
	if inst:IsA("Terrain") then
		local mat = hit.Material
		if mat == Enum.Material.Water then
			local wc = workspace.Terrain.WaterColor
			return srgbToLin(wc.R),
				srgbToLin(wc.G),
				srgbToLin(wc.B),
				1 - workspace.Terrain.WaterTransparency * 0.7,
				false
		end
		local ok, c = pcall(function()
			return workspace.Terrain:GetMaterialColor(mat)
		end)
		c = ok and c or Color3.fromRGB(110, 120, 90)
		return srgbToLin(c.R), srgbToLin(c.G), srgbToLin(c.B), 1, false
	end
	local c = inst.Color
	local r, g, b = srgbToLin(c.R), srgbToLin(c.G), srgbToLin(c.B)
	local inf = infoOf(inst)
	local face, u, v, fw, fh
	if inf.variant or inf.decals then
		local ln = inst.CFrame:VectorToObjectSpace(hit.Normal)
		face = faceOf(ln)
		u, v, fw, fh = faceUV(inst, hit.Position, face)
	end
	if inf.variant then
		local st = inf.variant.studs
		local tr, tg, tb = sampleNearest(inf.variant.img, u * fw / st, v * fh / st)
		r, g, b = r * srgbToLin(tr), g * srgbToLin(tg), b * srgbToLin(tb)
	elseif inf.avg then
		r, g, b = srgbToLin(inf.avg[1]), srgbToLin(inf.avg[2]), srgbToLin(inf.avg[3])
	end
	local alpha = partAlpha(inst)
	if inf.decals then
		for _, d in inf.decals do
			local obj = d.obj
			if obj.Face == face then
				local su, sv = u, v
				if d.isTexture then
					local spu = obj.StudsPerTileU > 0 and obj.StudsPerTileU or 2
					local spv = obj.StudsPerTileV > 0 and obj.StudsPerTileV or 2
					su = (u * fw + obj.OffsetStudsU) / spu
					sv = (v * fh + obj.OffsetStudsV) / spv
				end
				local dr, dg, db, da = sampleNearest(d.img, su, sv)
				local tint = obj.Color3
				da *= 1 - obj.Transparency
				if da > 0.01 then
					r = r * (1 - da) + srgbToLin(dr * tint.R) * da
					g = g * (1 - da) + srgbToLin(dg * tint.G) * da
					b = b * (1 - da) + srgbToLin(db * tint.B) * da
					alpha = math.max(alpha, da)
				end
			end
		end
	end
	return r, g, b, alpha, inst.Material == Enum.Material.Neon
end

local function shade(hit, dir, r, g, b, neon)
	if neon then
		return r * 1.6, g * 1.6, b * 1.6
	end
	local n = hit.Normal
	local pos = hit.Position
	-- ambient: indoor ambient everywhere, outdoor ambient weighted by how much the normal faces up
	local up = 0.5 + 0.5 * n.Y
	local lr = scene.ambient[1] + scene.outdoor[1] * (0.35 + 0.65 * up)
	local lg = scene.ambient[2] + scene.outdoor[2] * (0.35 + 0.65 * up)
	local lb = scene.ambient[3] + scene.outdoor[3] * (0.35 + 0.65 * up)
	-- sky light (environment diffuse)
	local sky = scene.envDiffuse * 0.25 * up
	lr += sky * 0.6
	lg += sky * 0.7
	lb += sky * 0.9
	-- sun / moon
	local L = scene.lightDir
	local ndl = n.X * L.X + n.Y * L.Y + n.Z * L.Z
	if ndl > 0 then
		local vis = 1
		if scene.shadows and occluded(pos + n * 0.05, L, 1000) then
			vis = 0
		end
		if vis > 0 then
			lr += scene.direct[1] * ndl
			lg += scene.direct[2] * ndl
			lb += scene.direct[3] * ndl
		end
	end
	-- local lights
	for _, l in scene.lights do
		local d = l.pos - pos
		local dist = d.Magnitude
		if dist < l.range and dist > 1e-3 then
			local ld = d / dist
			local nd = n.X * ld.X + n.Y * ld.Y + n.Z * ld.Z
			if nd > 0 then
				local att = (1 - dist / l.range)
				att = att * att * l.bright * nd
				if att > 0.01 and l.shadows and occluded(pos + n * 0.05, ld, dist - 0.2, l.params) then
					att = 0
				end
				lr += l.col[1] * att
				lg += l.col[2] * att
				lb += l.col[3] * att
			end
		end
	end
	return r * lr, g * lg, b * lb
end

local function applyFog(r, g, b, dist, dir)
	local f
	if scene.atm then
		f = 1 - math.exp(-dist * scene.density * 0.0035)
		f = clamp01(f * (0.7 + scene.haze * 0.25))
	else
		if scene.fogEnd >= 100000 then
			return r, g, b
		end
		f = clamp01((dist - scene.fogStart) / math.max(1, scene.fogEnd - scene.fogStart))
	end
	if f <= 0 then
		return r, g, b
	end
	local fr, fg, fb = scene.fogColor[1], scene.fogColor[2], scene.fogColor[3]
	if scene.atm then
		local sr, sg, sb = skyColor(Vector3.new(dir.X, 0.05, dir.Z).Unit)
		fr, fg, fb = fr * 0.5 + sr * 0.5, fg * 0.5 + sg * 0.5, fb * 0.5 + sb * 0.5
	end
	return r * (1 - f) + fr * f, g * (1 - f) + fg * f, b * (1 - f) + fb * f
end

-- returns linear r,g,b and the id of the first opaque instance (for edge detection)
local MAXD = 40000
local SEG = 10000
local function castLong(origin, dir, maxLen)
	local done = 0
	while done < maxLen do
		local len = math.min(SEG, maxLen - done)
		local hit = workspace:Raycast(origin + dir * done, dir * len, params)
		if hit then
			return hit
		end
		done += len
	end
	return nil
end
local function trace(origin, dir)
	local accR, accG, accB, remain = 0, 0, 0, 1
	local firstInst = nil
	local travelled = 0
	for _ = 1, 12 do
		local hit = castLong(origin, dir, MAXD - travelled)
		if not hit then
			local r, g, b = skyColor(dir)
			return accR + r * remain, accG + g * remain, accB + b * remain, firstInst or "sky"
		end
		local inst = hit.Instance
		local seg = (hit.Position - origin).Magnitude
		travelled += seg
		local r, g, b, alpha, neon = albedo(hit)
		if alpha <= 0.02 then
			if not inst:IsA("Terrain") and not hasVisualChildren(inst) then
				params:AddToFilter(inst)
			else
				origin = hit.Position + dir * 0.03
			end
		else
			r, g, b = shade(hit, dir, r, g, b, neon)
			r, g, b = applyFog(r, g, b, travelled, dir)
			firstInst = firstInst or inst
			accR += r * alpha * remain
			accG += g * alpha * remain
			accB += b * alpha * remain
			remain *= 1 - alpha
			if remain < 0.03 then
				return accR, accG, accB, firstInst
			end
			origin = hit.Position + dir * 0.03
		end
		if travelled >= MAXD then
			break
		end
	end
	local r, g, b = skyColor(dir)
	return accR + r * remain, accG + g * remain, accB + b * remain, firstInst or "sky"
end

---------------------------------------------------------------- post (colour correction, tone)
local function post(r, g, b)
	local e = scene.exposure
	r, g, b = r * e, g * e, b * e
	-- soft shoulder instead of a hard clip
	local function tone(x)
		return if x < 0.8 then x else 0.8 + (1 - math.exp(-(x - 0.8) * 5)) * 0.2
	end
	r, g, b = linToSrgb(tone(r)), linToSrgb(tone(g)), linToSrgb(tone(b))
	for _, cc in scene.cc do
		r, g, b = r + cc.Brightness, g + cc.Brightness, b + cc.Brightness
		local c = 1 + cc.Contrast
		r, g, b = (r - 0.5) * c + 0.5, (g - 0.5) * c + 0.5, (b - 0.5) * c + 0.5
		local lum = r * 0.299 + g * 0.587 + b * 0.114
		local s = 1 + cc.Saturation
		r, g, b = lum + (r - lum) * s, lum + (g - lum) * s, lum + (b - lum) * s
		local t = cc.TintColor
		r, g, b = r * t.R, g * t.G, b * t.B
	end
	return clamp01(r), clamp01(g), clamp01(b)
end

---------------------------------------------------------------- canvas
local Canvas = {}
Canvas.__index = Canvas
local function newCanvas(w, h)
	return setmetatable({ w = w, h = h, buf = buffer.create(w * h * 3) }, Canvas)
end
function Canvas:set(x, y, r, g, b)
	local i = (y * self.w + x) * 3
	buffer.writeu8(self.buf, i, math.floor(r * 255 + 0.5))
	buffer.writeu8(self.buf, i + 1, math.floor(g * 255 + 0.5))
	buffer.writeu8(self.buf, i + 2, math.floor(b * 255 + 0.5))
end
function Canvas:blend(x, y, r, g, b, a)
	if a <= 0 or x < 0 or y < 0 or x >= self.w or y >= self.h then
		return
	end
	local i = (y * self.w + x) * 3
	local bf = self.buf
	if a >= 1 then
		buffer.writeu8(bf, i, math.floor(r * 255 + 0.5))
		buffer.writeu8(bf, i + 1, math.floor(g * 255 + 0.5))
		buffer.writeu8(bf, i + 2, math.floor(b * 255 + 0.5))
		return
	end
	buffer.writeu8(bf, i, math.floor(buffer.readu8(bf, i) * (1 - a) + r * 255 * a + 0.5))
	buffer.writeu8(bf, i + 1, math.floor(buffer.readu8(bf, i + 1) * (1 - a) + g * 255 * a + 0.5))
	buffer.writeu8(bf, i + 2, math.floor(buffer.readu8(bf, i + 2) * (1 - a) + b * 255 * a + 0.5))
end

---------------------------------------------------------------- world pass
local function renderWorld(canvas, cam, opts)
	local W, H = canvas.w, canvas.h
	local cf = cam.CFrame
	local fov = cam.FieldOfView
	if type(opts.cam) == "table" and #opts.cam >= 6 then
		local c = opts.cam
		cf = CFrame.lookAt(Vector3.new(c[1], c[2], c[3]), Vector3.new(c[4], c[5], c[6]))
	end
	if tonumber(opts.fov) then
		fov = tonumber(opts.fov)
	end
	local origin = cf.Position
	local tanHalf = math.tan(math.rad(fov) / 2)
	local aspect = W / H
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	local function rayDir(px, py)
		local x = (2 * px / W - 1) * tanHalf * aspect
		local y = (1 - 2 * py / H) * tanHalf
		return (right * x + up * y + look).Unit
	end

	-- skip the local character in first person (its parts are hidden by LocalTransparencyModifier anyway)
	local filter = {}
	for _, inst in workspace:GetChildren() do
		if inst.Name == "__StudioRelayTmp" then
			table.insert(filter, inst)
		end
	end
	params.FilterDescendantsInstances = filter
	scene.shadowFilter = {}
	shadowParams.FilterDescendantsInstances = scene.shadowFilter

	local ids = {}
	local idOf = {}
	local nextId = 0
	local lin = table.create(W * H * 3, 0)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local r, g, b, inst = trace(origin, rayDir(x + 0.5, y + 0.5))
			local k = (y * W + x) * 3
			lin[k + 1], lin[k + 2], lin[k + 3] = r, g, b
			local id = idOf[inst]
			if not id then
				nextId += 1
				id = nextId
				idOf[inst] = id
			end
			ids[y * W + x + 1] = id
			maybeYield()
		end
	end

	-- edge anti-aliasing: 4 extra rays where a neighbour shows another object
	local extra = 0
	if opts.aa ~= false then
		local offs = { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } }
		for y = 0, H - 1 do
			for x = 0, W - 1 do
				local id = ids[y * W + x + 1]
				local edge = (x + 1 < W and ids[y * W + x + 2] ~= id)
					or (y + 1 < H and ids[(y + 1) * W + x + 1] ~= id)
					or (x > 0 and ids[y * W + x] ~= id)
					or (y > 0 and ids[(y - 1) * W + x + 1] ~= id)
				if edge then
					local k = (y * W + x) * 3
					local sr, sg, sb = lin[k + 1], lin[k + 2], lin[k + 3]
					for _, o in offs do
						local r, g, b = trace(origin, rayDir(x + o[1], y + o[2]))
						sr += r
						sg += g
						sb += b
					end
					lin[k + 1], lin[k + 2], lin[k + 3] = sr / 5, sg / 5, sb / 5
					extra += 4
					maybeYield()
				end
			end
		end
	end

	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local k = (y * W + x) * 3
			local r, g, b = post(lin[k + 1], lin[k + 2], lin[k + 3])
			canvas:set(x, y, r, g, b)
		end
		maybeYield()
	end
	return W * H + extra
end

---------------------------------------------------------------- text
local glyphCache = {}
local function getFonts()
	if FONTS then
		return FONTS
	end
	return {}
end
local function decodeGlyph(sizeIdx, cp)
	local key = sizeIdx * 0x200000 + cp
	local g = glyphCache[key]
	if g ~= nil then
		return g or nil
	end
	local font = getFonts()[sizeIdx]
	local raw = font and font.glyphs[cp]
	if not raw then
		glyphCache[key] = false
		return nil
	end
	local w, adv, xoff, yoff, h, data = raw[1], raw[2], raw[3], raw[4], raw[5], raw[6]
	local alpha = buffer.create(math.max(1, w * h))
	local o = 0
	for i = 1, #data do
		local c = string.byte(data, i)
		if c >= 103 then -- g..z: run of zeros
			o += c - 102
		else
			local v = if c <= 57 then c - 48 else c - 87
			buffer.writeu8(alpha, o, math.floor(v * 17))
			o += 1
		end
	end
	g = { w = w, adv = adv, xoff = xoff, yoff = yoff, h = h, a = alpha }
	glyphCache[key] = g
	return g
end

local function pickFont(px)
	local fonts = getFonts()
	local best, bestIdx = nil, 1
	for i, f in fonts do
		if not best or math.abs(f.line - px) < math.abs(best.line - px) then
			best, bestIdx = f, i
		end
	end
	return best, bestIdx
end

local function utf8chars(s)
	local out = {}
	for _, cp in utf8.codes(s) do
		table.insert(out, cp)
	end
	return out
end

local function measure(fontIdx, cps, scale)
	local w = 0
	for _, cp in cps do
		local g = decodeGlyph(fontIdx, cp) or decodeGlyph(fontIdx, 63)
		w += (g and g.adv or 4) * scale
	end
	return w
end

local function wrapLines(text, fontIdx, scale, maxW, wrap)
	local lines = {}
	for para in string.gmatch(text .. "\n", "(.-)\n") do
		if not wrap then
			table.insert(lines, utf8chars(para))
		else
			local cur, curW = {}, 0
			for word, sp in string.gmatch(para, "(%S*)(%s*)") do
				if word == "" and sp == "" then
					break
				end
				local wc = utf8chars(word)
				local ww = measure(fontIdx, wc, scale)
				local spc = utf8chars(sp)
				local sw = measure(fontIdx, spc, scale)
				if curW > 0 and curW + ww > maxW then
					table.insert(lines, cur)
					cur, curW = {}, 0
				end
				for _, cp in wc do
					table.insert(cur, cp)
				end
				for _, cp in spc do
					table.insert(cur, cp)
				end
				curW += ww + sw
			end
			table.insert(lines, cur)
		end
	end
	return lines
end

local function drawGlyph(canvas, g, x0, y0, scale, r, gg, b, alpha, clip)
	local tw = math.max(1, math.floor(g.w * scale + 0.5))
	local th = math.max(1, math.floor(g.h * scale + 0.5))
	for ty = 0, th - 1 do
		local py = y0 + ty
		if py >= clip[2] and py < clip[4] then
			local sy = math.min(g.h - 1, math.floor((ty + 0.5) / scale))
			for tx = 0, tw - 1 do
				local px = x0 + tx
				if px >= clip[1] and px < clip[3] then
					local sx = math.min(g.w - 1, math.floor((tx + 0.5) / scale))
					local a = buffer.readu8(g.a, sy * g.w + sx) / 255
					if a > 0 then
						canvas:blend(px, py, r, gg, b, a * alpha)
					end
				end
			end
		end
	end
end

local function drawText(canvas, obj, rect, s, clip)
	local text = obj.ContentText
	if obj:IsA("TextBox") and text == "" then
		text = obj.PlaceholderText
	end
	if text == "" or obj.TextTransparency >= 0.99 then
		return
	end
	local color = if obj:IsA("TextBox") and obj.ContentText == "" then obj.PlaceholderColor3 else obj.TextColor3
	local px = obj.TextSize
	local tb = obj.TextBounds
	local nLines = select(2, string.gsub(text, "\n", "")) + 1
	if obj.TextScaled or obj.TextWrapped then
		-- Roblox reports the final layout in TextBounds; derive the line height from it
		local guess = obj.TextScaled and math.max(1, tb.Y / nLines) or px
		px = if obj.TextScaled then guess else px
	end
	local font, fi = pickFont(px * s)
	if not font then
		return
	end
	local scale = px * s / font.line
	local maxW = rect[3] - rect[1]
	local lines = wrapLines(text, fi, scale, maxW, obj.TextWrapped or obj.TextScaled)
	-- match Roblox widths: squeeze/stretch to TextBounds for single lines
	local squeeze = 1
	if #lines == 1 and tb.X > 0 then
		local ourW = measure(fi, lines[1], scale)
		if ourW > 0 then
			squeeze = math.clamp(tb.X * s / ourW, 0.6, 1.6)
		end
	end
	local lineH = font.line * scale
	local totalH = lineH * #lines
	local top
	if obj.TextYAlignment == Enum.TextYAlignment.Top then
		top = rect[2]
	elseif obj.TextYAlignment == Enum.TextYAlignment.Bottom then
		top = rect[4] - totalH
	else
		top = (rect[2] + rect[4]) / 2 - totalH / 2
	end
	local alpha = 1 - obj.TextTransparency
	local strokeA = 1 - obj.TextStrokeTransparency
	local strokeC = obj.TextStrokeColor3
	for _, st in obj:GetChildren() do
		if st:IsA("UIStroke") and st.Enabled and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			strokeA = 1 - st.Transparency
			strokeC = st.Color
		end
	end
	for li, cps in lines do
		local lw = measure(fi, cps, scale) * squeeze
		local left
		if obj.TextXAlignment == Enum.TextXAlignment.Left then
			left = rect[1]
		elseif obj.TextXAlignment == Enum.TextXAlignment.Right then
			left = rect[3] - lw
		else
			left = (rect[1] + rect[3]) / 2 - lw / 2
		end
		local passes = {}
		if strokeA > 0.05 then
			for _, d in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
				table.insert(passes, { d[1], d[2], strokeC, strokeA * alpha })
			end
		end
		table.insert(passes, { 0, 0, color, alpha })
		for _, pass in passes do
			local x = left
			local baseY = top + (li - 1) * lineH
			for _, cp in cps do
				local g = decodeGlyph(fi, cp) or decodeGlyph(fi, 63)
				if g then
					if g.w > 0 then
						drawGlyph(
							canvas,
							g,
							math.floor(x + g.xoff * scale * squeeze + pass[1]),
							math.floor(baseY + g.yoff * scale + pass[2]),
							scale,
							pass[3].R,
							pass[3].G,
							pass[3].B,
							pass[4],
							clip
						)
					end
					x += g.adv * scale * squeeze
				end
			end
		end
	end
end

---------------------------------------------------------------- GUI pass
local function cornerRadius(obj, w, h)
	local c = obj:FindFirstChildOfClass("UICorner")
	if not c then
		return 0
	end
	return math.min(c.CornerRadius.Scale * math.min(w, h) + c.CornerRadius.Offset, math.min(w, h) / 2)
end

local function insideRounded(x, y, rect, rad)
	if rad <= 0 then
		return true
	end
	local cx = math.clamp(x, rect[1] + rad, rect[3] - rad)
	local cy = math.clamp(y, rect[2] + rad, rect[4] - rad)
	local dx, dy = x - cx, y - cy
	return dx * dx + dy * dy <= rad * rad
end

local function gradientColor(grad, base, tx, ty)
	if not grad or not grad.Enabled then
		return base.R, base.G, base.B, 0
	end
	local rot = math.rad(grad.Rotation)
	local t = clamp01((tx - 0.5) * math.cos(rot) + (ty - 0.5) * math.sin(rot) + 0.5 + grad.Offset.X)
	local c = grad.Color.Keypoints
	local col = c[1].Value
	for i = 1, #c - 1 do
		if t >= c[i].Time and t <= c[i + 1].Time then
			local k = (t - c[i].Time) / math.max(1e-6, c[i + 1].Time - c[i].Time)
			col = c[i].Value:Lerp(c[i + 1].Value, k)
			break
		end
	end
	if t > c[#c].Time then
		col = c[#c].Value
	end
	local tk = grad.Transparency.Keypoints
	local tr = tk[1].Value
	for i = 1, #tk - 1 do
		if t >= tk[i].Time and t <= tk[i + 1].Time then
			local k = (t - tk[i].Time) / math.max(1e-6, tk[i + 1].Time - tk[i].Time)
			tr = tk[i].Value + (tk[i + 1].Value - tk[i].Value) * k
			break
		end
	end
	return base.R * col.R, base.G * col.G, base.B * col.B, tr
end

local function fillRect(canvas, rect, color, alpha, clip, rad, grad)
	local x0 = math.max(math.floor(rect[1]), clip[1])
	local y0 = math.max(math.floor(rect[2]), clip[2])
	local x1 = math.min(math.ceil(rect[3]), clip[3])
	local y1 = math.min(math.ceil(rect[4]), clip[4])
	local w, h = rect[3] - rect[1], rect[4] - rect[2]
	for y = y0, y1 - 1 do
		for x = x0, x1 - 1 do
			if insideRounded(x + 0.5, y + 0.5, rect, rad) then
				local r, g, b, tr =
					gradientColor(grad, color, (x - rect[1]) / math.max(w, 1), (y - rect[2]) / math.max(h, 1))
				canvas:blend(x, y, r, g, b, alpha * (1 - tr))
			end
		end
	end
end

local function strokeRect(canvas, rect, color, alpha, thick, clip, rad)
	local outer = { rect[1] - thick, rect[2] - thick, rect[3] + thick, rect[4] + thick }
	local x0 = math.max(math.floor(outer[1]), clip[1])
	local y0 = math.max(math.floor(outer[2]), clip[2])
	local x1 = math.min(math.ceil(outer[3]), clip[3])
	local y1 = math.min(math.ceil(outer[4]), clip[4])
	for y = y0, y1 - 1 do
		for x = x0, x1 - 1 do
			local cx, cy = x + 0.5, y + 0.5
			if insideRounded(cx, cy, outer, rad + thick) and not insideRounded(cx, cy, rect, rad) then
				canvas:blend(x, y, color.R, color.G, color.B, alpha)
			end
		end
	end
end

local function drawImage(canvas, obj, rect, clip, s)
	local img = loadImage(uriOf(obj, "ImageContent", "Image"))
	if not img then
		return
	end
	local alpha = 1 - obj.ImageTransparency
	if alpha <= 0.01 then
		return
	end
	local tint = obj.ImageColor3
	-- source rectangle (ImageRectOffset/Size)
	local sx0, sy0, sw, sh = 0, 0, img.w, img.h
	if obj.ImageRectSize.X > 0 and obj.ImageRectSize.Y > 0 then
		sx0, sy0, sw, sh = obj.ImageRectOffset.X, obj.ImageRectOffset.Y, obj.ImageRectSize.X, obj.ImageRectSize.Y
	end
	local dx0, dy0 = rect[1], rect[2]
	local dw, dh = rect[3] - rect[1], rect[4] - rect[2]
	local st = obj.ScaleType
	if st == Enum.ScaleType.Fit or st == Enum.ScaleType.Crop then
		local k = if st == Enum.ScaleType.Fit then math.min(dw / sw, dh / sh) else math.max(dw / sw, dh / sh)
		local nw, nh = sw * k, sh * k
		dx0, dy0 = dx0 + (dw - nw) / 2, dy0 + (dh - nh) / 2
		dw, dh = nw, nh
	end
	local pixelated = prop(obj, "ResampleMode") == Enum.ResamplerMode.Pixelated
	local slice = st == Enum.ScaleType.Slice and obj.SliceCenter
	local sliceScale = (prop(obj, "SliceScale") or 1) * s
	local x0 = math.max(math.floor(math.max(dx0, rect[1])), clip[1])
	local y0 = math.max(math.floor(math.max(dy0, rect[2])), clip[2])
	local x1 = math.min(math.ceil(math.min(dx0 + dw, rect[3])), clip[3])
	local y1 = math.min(math.ceil(math.min(dy0 + dh, rect[4])), clip[4])
	local function mapSlice(d, total, a, b, srcTotal)
		-- d: distance into destination; a,b: slice borders in source px
		local ea, eb = a * sliceScale, (srcTotal - b) * sliceScale
		if d < ea then
			return d / sliceScale
		elseif d > total - eb then
			return b + (d - (total - eb)) / sliceScale
		end
		local mid = total - ea - eb
		return a + (d - ea) / math.max(mid, 1e-6) * (b - a)
	end
	for y = y0, y1 - 1 do
		for x = x0, x1 - 1 do
			local fx, fy
			if slice then
				fx = sx0 + mapSlice(x + 0.5 - dx0, dw, slice.Min.X, slice.Max.X, sw)
				fy = sy0 + mapSlice(y + 0.5 - dy0, dh, slice.Min.Y, slice.Max.Y, sh)
			elseif st == Enum.ScaleType.Tile then
				local ts = obj.TileSize
				local tw, th = ts.X.Scale * dw + ts.X.Offset * s, ts.Y.Scale * dh + ts.Y.Offset * s
				fx = sx0 + ((x + 0.5 - dx0) % math.max(tw, 1)) / math.max(tw, 1) * sw
				fy = sy0 + ((y + 0.5 - dy0) % math.max(th, 1)) / math.max(th, 1) * sh
			else
				fx = sx0 + (x + 0.5 - dx0) / dw * sw
				fy = sy0 + (y + 0.5 - dy0) / dh * sh
			end
			local r, g, b, a
			if pixelated then
				local ix = math.clamp(math.floor(fx), 0, img.w - 1)
				local iy = math.clamp(math.floor(fy), 0, img.h - 1)
				local i = (iy * img.w + ix) * 4
				r, g, b, a =
					buffer.readu8(img.buf, i) / 255,
					buffer.readu8(img.buf, i + 1) / 255,
					buffer.readu8(img.buf, i + 2) / 255,
					buffer.readu8(img.buf, i + 3) / 255
			else
				r, g, b, a = sampleBilinearPx(img, fx, fy)
			end
			if a > 0.004 then
				canvas:blend(x, y, r * tint.R, g * tint.G, b * tint.B, a * alpha)
			end
		end
	end
end

local function guiVisible(obj)
	return obj.Visible
end

local function drawGui(canvas, obj, offset, s, clip, stats)
	if not obj:IsA("GuiObject") or not guiVisible(obj) then
		return
	end
	local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
	local rect = {
		(ap.X + offset.X) * s,
		(ap.Y + offset.Y) * s,
		(ap.X + offset.X + as.X) * s,
		(ap.Y + offset.Y + as.Y) * s,
	}
	stats.gui += 1
	local rad = cornerRadius(obj, rect[3] - rect[1], rect[4] - rect[2])
	local grad = obj:FindFirstChildOfClass("UIGradient")
	local bgA = 1 - obj.BackgroundTransparency
	if bgA > 0.01 and not obj:IsA("ViewportFrame") or (obj:IsA("ViewportFrame") and bgA > 0.01) then
		fillRect(canvas, rect, obj.BackgroundColor3, bgA, clip, rad, grad)
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		drawImage(canvas, obj, rect, clip, s)
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		local pad = obj:FindFirstChildOfClass("UIPadding")
		local tr = rect
		if pad then
			local w, h = rect[3] - rect[1], rect[4] - rect[2]
			tr = {
				rect[1] + (pad.PaddingLeft.Scale * w + pad.PaddingLeft.Offset * s),
				rect[2] + (pad.PaddingTop.Scale * h + pad.PaddingTop.Offset * s),
				rect[3] - (pad.PaddingRight.Scale * w + pad.PaddingRight.Offset * s),
				rect[4] - (pad.PaddingBottom.Scale * h + pad.PaddingBottom.Offset * s),
			}
		end
		drawText(canvas, obj, tr, s, clip)
	end
	for _, st in obj:GetChildren() do
		if
			st:IsA("UIStroke")
			and st.Enabled
			and (
				st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
				or not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox"))
			)
		then
			strokeRect(canvas, rect, st.Color, 1 - st.Transparency, math.max(1, st.Thickness * s), clip, rad)
		end
	end
	local childClip = clip
	if obj.ClipsDescendants then
		childClip = {
			math.max(clip[1], math.floor(rect[1])),
			math.max(clip[2], math.floor(rect[2])),
			math.min(clip[3], math.ceil(rect[3])),
			math.min(clip[4], math.ceil(rect[4])),
		}
		if childClip[1] >= childClip[3] or childClip[2] >= childClip[4] then
			return
		end
	end
	local kids = {}
	for i, ch in obj:GetChildren() do
		if ch:IsA("GuiObject") then
			table.insert(kids, { ch, i })
		end
	end
	table.sort(kids, function(a, b)
		if a[1].ZIndex ~= b[1].ZIndex then
			return a[1].ZIndex < b[1].ZIndex
		end
		return a[2] < b[2]
	end)
	for _, k in kids do
		drawGui(canvas, k[1], offset, s, childClip, stats)
	end
	maybeYield()
end

local function renderGui(canvas, s, stats)
	local player = Players.LocalPlayer
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local inset = GuiService:GetGuiInset()
	local guis = {}
	for _, g in pg:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			table.insert(guis, g)
		end
	end
	table.sort(guis, function(a, b)
		return a.DisplayOrder < b.DisplayOrder
	end)
	local clip = { 0, 0, canvas.w, canvas.h }
	for _, g in guis do
		-- AbsolutePosition is measured below the top bar; screen space adds the inset back
		local offset = Vector2.new(inset.X, inset.Y)
		local kids = {}
		for i, ch in g:GetChildren() do
			if ch:IsA("GuiObject") then
				table.insert(kids, { ch, i })
			end
		end
		table.sort(kids, function(a, b)
			if a[1].ZIndex ~= b[1].ZIndex then
				return a[1].ZIndex < b[1].ZIndex
			end
			return a[2] < b[2]
		end)
		for _, k in kids do
			drawGui(canvas, k[1], offset, s, clip, stats)
		end
	end
end

---------------------------------------------------------------- entry
-- opts: { w = width, aa = bool, gui = bool, maxSide = n }
local function render(opts, deps)
	FONTS = deps.fonts
	BASE64 = deps.base64
	partInfo = {}
	budgetStart = os.clock()
	local t0 = os.clock()
	local cam = workspace.CurrentCamera
	if not cam then
		return false, { error = "no camera" }
	end
	local vp = cam.ViewportSize
	local minimized = vp.X < 200 or vp.Y < 120
	local maxSide = math.clamp(tonumber(opts.max) or 640, 64, 1280)
	local vw, vh = vp.X, vp.Y
	if tonumber(opts.vw) and tonumber(opts.vh) and opts.cam then
		vw, vh = tonumber(opts.vw), tonumber(opts.vh)
	end
	if minimized then
		vw, vh = tonumber(opts.vw) or 1280, tonumber(opts.vh) or 720
	end
	local s = math.min(1, maxSide / math.max(vw, vh))
	local W, H = math.max(16, math.floor(vw * s)), math.max(16, math.floor(vh * s))
	local canvas = newCanvas(W, H)
	collectScene(cam)
	loadSkybox()
	local stats = { gui = 0 }
	local rays = renderWorld(canvas, cam, opts)
	local tWorld = os.clock() - t0
	if opts.gui ~= false and not minimized and not opts.cam then
		renderGui(canvas, s, stats)
	end
	return true,
		{
			w = W,
			h = H,
			srcW = vw,
			srcH = vh,
			b64 = BASE64(canvas.buf),
			rays = rays,
			guiObjects = stats.gui,
			seconds = math.floor((os.clock() - t0) * 100) / 100,
			worldSeconds = math.floor(tWorld * 100) / 100,
			minimized = minimized,
			lights = #scene.lights,
			images = imageStats,
		}
end

return render
