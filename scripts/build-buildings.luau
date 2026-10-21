--!nocheck
-- Buildings of the Тюрьма location with full interiors (owner 20.10.2026: «Рынок, столовая, спальня
-- и баня должны быть прям хорошо сделаны, а не пустая коробка»). Run in Studio (Edit) after
-- scripts/build-prison.luau; idempotent (replaces Workspace.Prison.Buildings). Parts only, cubic
-- style, textures via MaterialVariants px_* (scripts/build-textures.luau). Need zones keep the tags
-- RestoreHygiene / RestoreSleep / RestoreToilet that NeedsService binds to.

local CollectionService = game:GetService("CollectionService")

local root = workspace:FindFirstChild("Prison")
if not root then
	error("[build-buildings] run scripts/build-prison.luau first")
end
for _, name in ipairs({
	"Buildings",
	"Bath",
	"Market",
	"Bedroom",
	"Canteen",
	"Trainer",
	"Toilet",
}) do
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local buildings = Instance.new("Folder")
buildings.Name = "Buildings"
buildings.Parent = root

local rng = Random.new(777)
local STONE = Color3.fromRGB(96, 96, 100)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(85, 60, 35)
local IRON = Color3.fromRGB(70, 70, 75)
local LAMP = Color3.fromRGB(255, 215, 130)
local GLASS = Color3.fromRGB(150, 190, 230)
local CLOTH = Color3.fromRGB(190, 60, 50)
local WHITE = Color3.fromRGB(235, 235, 240)
local TILE = Color3.fromRGB(190, 215, 225)
local WATER = Color3.fromRGB(60, 120, 200)

-- part(name, size, cf, color, material | "px_variant", parent)
local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	if typeof(material) == "string" then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = material
		p.Color = Color3.new(1, 1, 1)
	else
		p.Material = material or Enum.Material.SmoothPlastic
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color or LAMP
	l.Range = range or 24
	l.Brightness = brightness or 1.2
	l.Shadows = true
	l.Parent = parent
	return l
end
local function sign(target, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(96, 18)
	gui.StudsOffset = Vector3.new(0, offset or 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 190, 60)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end
local function boardText(target, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 140)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end
local function particles(parent, color, rate, size, speed, lifetime, transparency)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Size = NumberSequence.new(size)
	e.Speed = NumberRange.new(speed)
	e.Lifetime = NumberRange.new(lifetime)
	e.Transparency = NumberSequence.new(transparency or 0.5)
	e.LightEmission = 0.2
	e.Parent = parent
	return e
end

-- ------------------------------------------------------------------ building shell
-- spec: { name, cx, cz, w, d, h, doors = { {side="S"|"N"|"E"|"W", at=offset along the side, width} },
--         windows = { {side, at, width, height, y} }, floor = "px_*", wall = "px_*"|Color, roof = "flat"|"gable" }
-- Returns the model and a table of useful frames. Door openings are real gaps.
local function shell(spec)
	local m = Instance.new("Model")
	m.Name = spec.name
	m.Parent = buildings
	local cx, cz, w, d, h = spec.cx, spec.cz, spec.w, spec.d, spec.h
	local T = 1.5 -- wall thickness
	local function floorSlab(x0, x1, z0, z1)
		if x1 - x0 < 0.5 or z1 - z0 < 0.5 then
			return
		end
		local f = part(
			"Floor",
			Vector3.new(x1 - x0, 0.6, z1 - z0),
			CFrame.new((x0 + x1) / 2, 0.3, (z0 + z1) / 2),
			spec.floorColor or STONE,
			spec.floor or "px_planks",
			m
		)
		f.CanCollide = true
	end
	local holes = spec.floorHoles or {}
	if #holes == 0 then
		floorSlab(cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2)
	else
		local xs = { cx - w / 2, cx + w / 2 }
		for _, h in ipairs(holes) do
			table.insert(xs, h.x0)
			table.insert(xs, h.x1)
		end
		table.sort(xs)
		for i = 1, #xs - 1 do
			local x0, x1 = xs[i], xs[i + 1]
			local cuts = { cz - d / 2, cz + d / 2 }
			for _, h in ipairs(holes) do
				if h.x0 <= x0 and h.x1 >= x1 then
					table.insert(cuts, h.z0)
					table.insert(cuts, h.z1)
				end
			end
			table.sort(cuts)
			for j = 1, #cuts - 1 do
				local z0, z1 = cuts[j], cuts[j + 1]
				local inside = false
				for _, h in ipairs(holes) do
					if h.x0 <= x0 and h.x1 >= x1 and h.z0 <= z0 and h.z1 >= z1 then
						inside = true
					end
				end
				if not inside then
					floorSlab(x0, x1, z0, z1)
				end
			end
		end
	end
	-- Walls per side, split around door openings.
	local sides = {
		N = { len = w, axisX = true, fixed = cz - d / 2 },
		S = { len = w, axisX = true, fixed = cz + d / 2 },
		W = { len = d, axisX = false, fixed = cx - w / 2 },
		E = { len = d, axisX = false, fixed = cx + w / 2 },
	}
	local function wallSeg(side, a0, a1, y0, y1)
		if a1 - a0 < 0.1 or y1 - y0 < 0.1 then
			return
		end
		local s = sides[side]
		local mid = (a0 + a1) / 2
		local size = if s.axisX
			then Vector3.new(a1 - a0, y1 - y0, T)
			else Vector3.new(T, y1 - y0, a1 - a0)
		local cf = if s.axisX
			then CFrame.new(mid, (y0 + y1) / 2, s.fixed)
			else CFrame.new(s.fixed, (y0 + y1) / 2, mid)
		local p = part("Wall", size, cf, STONE, spec.wall or "px_prison_wall", m)
		p.CanCollide = true
	end
	for side, s in pairs(sides) do
		local start = if s.axisX then cx - s.len / 2 else cz - s.len / 2
		local cuts = {} -- door openings along this side: {a0, a1, top}
		for _, door in ipairs(spec.doors or {}) do
			if door.side == side then
				local c = start + s.len / 2 + (door.at or 0)
				table.insert(cuts, { c - door.width / 2, c + door.width / 2, door.height or 8 })
			end
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local a = start
		for _, cut in ipairs(cuts) do
			wallSeg(side, a, cut[1], 0, h)
			wallSeg(side, cut[1], cut[2], cut[3], h) -- lintel
			-- door frame
			local fy = cut[3] / 2
			if s.axisX then
				part(
					"Frame",
					Vector3.new(0.6, cut[3], T + 0.4),
					CFrame.new(cut[1], fy, s.fixed),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				part(
					"Frame",
					Vector3.new(0.6, cut[3], T + 0.4),
					CFrame.new(cut[2], fy, s.fixed),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				part(
					"Frame",
					Vector3.new(cut[2] - cut[1] + 0.6, 0.6, T + 0.4),
					CFrame.new((cut[1] + cut[2]) / 2, cut[3], s.fixed),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				local dl = part(
					"DoorLamp",
					Vector3.new(0.8, 0.8, 0.8),
					CFrame.new(
						cut[2] + 1.5,
						cut[3] + 1,
						s.fixed + (if side == "S" then 1.2 else -1.2)
					),
					LAMP,
					Enum.Material.Neon,
					m
				)
				light(dl, LAMP, 16, 1)
			else
				part(
					"Frame",
					Vector3.new(T + 0.4, cut[3], 0.6),
					CFrame.new(s.fixed, fy, cut[1]),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				part(
					"Frame",
					Vector3.new(T + 0.4, cut[3], 0.6),
					CFrame.new(s.fixed, fy, cut[2]),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				part(
					"Frame",
					Vector3.new(T + 0.4, 0.6, cut[2] - cut[1] + 0.6),
					CFrame.new(s.fixed, cut[3], (cut[1] + cut[2]) / 2),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
				local dl = part(
					"DoorLamp",
					Vector3.new(0.8, 0.8, 0.8),
					CFrame.new(
						s.fixed + (if side == "E" then 1.2 else -1.2),
						cut[3] + 1,
						cut[2] + 1.5
					),
					LAMP,
					Enum.Material.Neon,
					m
				)
				light(dl, LAMP, 16, 1)
			end
			-- doorstep
			local stepCf = if s.axisX
				then CFrame.new(
					(cut[1] + cut[2]) / 2,
					0.25,
					s.fixed + (if side == "S" then 2 else -2)
				)
				else CFrame.new(
					s.fixed + (if side == "E" then 2 else -2),
					0.25,
					(cut[1] + cut[2]) / 2
				)
			part(
				"Step",
				if s.axisX
					then Vector3.new(cut[2] - cut[1] + 2, 0.5, 3)
					else Vector3.new(3, 0.5, cut[2] - cut[1] + 2),
				stepCf,
				STONE,
				"px_cobblestone",
				m
			).CanCollide =
				true
			a = cut[2]
		end
		wallSeg(side, a, start + s.len, 0, h)
	end
	-- Windows: glass + frame on the wall surface (no hole), plus a sill and a flower box outside.
	for _, win in ipairs(spec.windows or {}) do
		local s = sides[win.side]
		local c = (if s.axisX then cx else cz) + (win.at or 0)
		local y = win.y or h * 0.55
		local ww, wh = win.width or 6, win.height or 4
		local out = if win.side == "S" or win.side == "E" then 1 else -1
		local size = if s.axisX then Vector3.new(ww, wh, T + 0.3) else Vector3.new(T + 0.3, wh, ww)
		local cf = if s.axisX then CFrame.new(c, y, s.fixed) else CFrame.new(s.fixed, y, c)
		local g = part("Window", size, cf, GLASS, Enum.Material.Glass, m)
		g.Transparency = 0.45
		local fsize = if s.axisX
			then Vector3.new(ww + 0.8, wh + 0.8, T + 0.5)
			else Vector3.new(T + 0.5, wh + 0.8, ww + 0.8)
		local frame = part("WindowFrame", fsize, cf, DARK_WOOD, Enum.Material.Wood, m)
		frame.Transparency = 0
		-- cross bars
		if s.axisX then
			part("Bar", Vector3.new(0.3, wh, T + 0.6), cf, DARK_WOOD, Enum.Material.Wood, m)
			part("Bar", Vector3.new(ww, 0.3, T + 0.6), cf, DARK_WOOD, Enum.Material.Wood, m)
		else
			part("Bar", Vector3.new(T + 0.6, wh, 0.3), cf, DARK_WOOD, Enum.Material.Wood, m)
			part("Bar", Vector3.new(T + 0.6, 0.3, ww), cf, DARK_WOOD, Enum.Material.Wood, m)
		end
		-- flower box outside
		local boxCf = if s.axisX
			then CFrame.new(c, y - wh / 2 - 0.5, s.fixed + out * (T / 2 + 0.8))
			else CFrame.new(s.fixed + out * (T / 2 + 0.8), y - wh / 2 - 0.5, c)
		part(
			"FlowerBox",
			if s.axisX then Vector3.new(ww, 1, 1.4) else Vector3.new(1.4, 1, ww),
			boxCf,
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		for i = 1, math.floor(ww / 1.5) do
			local off = -ww / 2 + 0.75 + (i - 1) * 1.5
			local fcf = if s.axisX
				then boxCf * CFrame.new(off, 0.9, 0)
				else boxCf * CFrame.new(0, 0.9, off)
			part(
				"Flower",
				Vector3.new(0.6, 0.9, 0.6),
				fcf,
				({
					Color3.fromRGB(230, 70, 70),
					Color3.fromRGB(240, 200, 60),
					Color3.fromRGB(200, 90, 200),
				})[rng:NextInteger(1, 3)],
				Enum.Material.Neon,
				m
			)
		end
	end
	-- Roof
	local overhang = 2
	if spec.roof == "gable" then
		local ridgeH = h + math.min(w, d) * 0.25
		local half = (if w <= d then w else d) / 2 + overhang
		local slopeLen = math.sqrt(half * half + (ridgeH - h) ^ 2) + 0.5
		local ang = math.atan2(ridgeH - h, half)
		local alongX = w > d -- ridge runs along the longer axis
		for _, sgn in ipairs({ -1, 1 }) do
			local size = if alongX
				then Vector3.new(w + 2 * overhang, 0.8, slopeLen)
				else Vector3.new(slopeLen, 0.8, d + 2 * overhang)
			local cf = if alongX
				then CFrame.new(cx, (h + ridgeH) / 2, cz + sgn * half / 2) * CFrame.Angles(
					sgn * ang,
					0,
					0
				)
				else CFrame.new(cx + sgn * half / 2, (h + ridgeH) / 2, cz) * CFrame.Angles(
					0,
					0,
					-sgn * ang
				)
			part("Roof", size, cf, DARK_WOOD, "px_planks", m).CanCollide = true
		end
		-- gable triangles as stacked slabs
		local steps = 5
		for i = 1, steps do
			local frac = i / steps
			local width = (if alongX then d else w) * (1 - frac) + 0.5
			local y = h + (ridgeH - h) * (frac - 0.5 / steps)
			local sh = (ridgeH - h) / steps + 0.1
			for _, sgn in ipairs({ -1, 1 }) do
				local size = if alongX then Vector3.new(T, sh, width) else Vector3.new(width, sh, T)
				local cf = if alongX
					then CFrame.new(cx + sgn * w / 2, y, cz)
					else CFrame.new(cx, y, cz + sgn * d / 2)
				part("Gable", size, cf, STONE, spec.wall or "px_prison_wall", m)
			end
		end
		part(
			"Ridge",
			if alongX
				then Vector3.new(w + 2 * overhang + 0.5, 0.8, 1.2)
				else Vector3.new(1.2, 0.8, d + 2 * overhang + 0.5),
			CFrame.new(cx, ridgeH + 0.3, cz),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	else
		part(
			"Roof",
			Vector3.new(w + 2 * overhang, 1, d + 2 * overhang),
			CFrame.new(cx, h + 0.5, cz),
			DARK_WOOD,
			"px_planks",
			m
		).CanCollide =
			true
		part(
			"Parapet",
			Vector3.new(w + 2 * overhang, 1.2, 1),
			CFrame.new(cx, h + 1.6, cz - d / 2 - overhang + 0.5),
			STONE,
			"px_prison_wall",
			m
		)
		part(
			"Parapet",
			Vector3.new(w + 2 * overhang, 1.2, 1),
			CFrame.new(cx, h + 1.6, cz + d / 2 + overhang - 0.5),
			STONE,
			"px_prison_wall",
			m
		)
		part(
			"Parapet",
			Vector3.new(1, 1.2, d + 2 * overhang),
			CFrame.new(cx - w / 2 - overhang + 0.5, h + 1.6, cz),
			STONE,
			"px_prison_wall",
			m
		)
		part(
			"Parapet",
			Vector3.new(1, 1.2, d + 2 * overhang),
			CFrame.new(cx + w / 2 + overhang - 0.5, h + 1.6, cz),
			STONE,
			"px_prison_wall",
			m
		)
	end
	-- Ceiling lamps
	local nx, nz = math.max(1, math.floor(w / 18)), math.max(1, math.floor(d / 18))
	for ix = 1, nx do
		for iz = 1, nz do
			local lx = cx - w / 2 + w * (ix - 0.5) / nx
			local lz = cz - d / 2 + d * (iz - 0.5) / nz
			part(
				"LampCord",
				Vector3.new(0.2, 2, 0.2),
				CFrame.new(lx, h - 1, lz),
				IRON,
				Enum.Material.Metal,
				m
			)
			local l = part(
				"CeilingLamp",
				Vector3.new(2.2, 0.7, 2.2),
				CFrame.new(lx, h - 2.2, lz),
				LAMP,
				Enum.Material.Neon,
				m
			)
			light(l, spec.lampColor or LAMP, 30, 1.1)
		end
	end
	-- Chimney with smoke
	if spec.chimney then
		local chx, chz = cx + spec.chimney[1], cz + spec.chimney[2]
		local top = h + 8
		part(
			"Chimney",
			Vector3.new(3, 10, 3),
			CFrame.new(chx, h + 4, chz),
			CLOTH,
			"px_red_brick",
			m
		)
		part(
			"ChimneyCap",
			Vector3.new(3.6, 0.6, 3.6),
			CFrame.new(chx, top + 0.6, chz),
			DARK,
			Enum.Material.Slate,
			m
		)
		local smoke = part(
			"Smoke",
			Vector3.new(1, 1, 1),
			CFrame.new(chx, top + 1, chz),
			DARK,
			Enum.Material.SmoothPlastic,
			m
		)
		smoke.Transparency = 1
		smoke.CanCollide = false
		local e = particles(smoke, Color3.fromRGB(180, 180, 185), 6, 3, 3, 4, 0.6)
		e.Acceleration = Vector3.new(0.5, 1, 0)
	end
	-- Name board above the main door
	local main = spec.doors and spec.doors[1]
	if main and spec.label then
		local s = sides[main.side]
		local c = (if s.axisX then cx else cz) + (main.at or 0)
		local out = if main.side == "S" or main.side == "E" then 1 else -1
		local bcf = if s.axisX
			then CFrame.new(c, (main.height or 8) + 2.5, s.fixed + out * (T / 2 + 0.3))
			else CFrame.new(s.fixed + out * (T / 2 + 0.3), (main.height or 8) + 2.5, c)
		local board = part(
			"NameBoard",
			if s.axisX
				then Vector3.new(main.width + 6, 2.6, 0.5)
				else Vector3.new(0.5, 2.6, main.width + 6),
			bcf,
			DARK_WOOD,
			"px_planks",
			m
		)
		local face = if main.side == "S"
			then Enum.NormalId.Front
			elseif main.side == "N" then Enum.NormalId.Back
			elseif main.side == "E" then Enum.NormalId.Right
			else Enum.NormalId.Left
		boardText(board, face, spec.label)
		sign(board, spec.label, 6)
	end
	return m, { cx = cx, cz = cz, w = w, d = d, h = h, T = T }
end

-- ------------------------------------------------------------------ furniture kit
local function table_(m, cx, y, cz, w, d, rotY)
	local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, rotY or 0, 0)
	part("TableTop", Vector3.new(w, 0.5, d), cf * CFrame.new(0, y, 0), WOOD, "px_planks", m).CanCollide =
		true
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(
			"TableLeg",
			Vector3.new(0.5, y - 0.25, 0.5),
			cf * CFrame.new(c[1] * (w / 2 - 0.5), (y - 0.25) / 2, c[2] * (d / 2 - 0.5)),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
	return cf
end
local function bench(m, cf, len)
	part(
		"BenchSeat",
		Vector3.new(len, 0.4, 1.6),
		cf * CFrame.new(0, 1.5, 0),
		WOOD,
		Enum.Material.Wood,
		m
	).CanCollide =
		true
	for _, dx in ipairs({ -len / 2 + 0.6, len / 2 - 0.6 }) do
		part(
			"BenchLeg",
			Vector3.new(0.5, 1.3, 1.4),
			cf * CFrame.new(dx, 0.65, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
end
local function chair(m, cf)
	part(
		"ChairSeat",
		Vector3.new(1.8, 0.4, 1.8),
		cf * CFrame.new(0, 1.6, 0),
		WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"ChairBack",
		Vector3.new(1.8, 2.2, 0.3),
		cf * CFrame.new(0, 2.9, -0.75),
		WOOD,
		Enum.Material.Wood,
		m
	)
	for _, c in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do
		part(
			"ChairLeg",
			Vector3.new(0.3, 1.4, 0.3),
			cf * CFrame.new(c[1], 0.7, c[2]),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
end
local function plate(m, cf)
	local p = part("Plate", Vector3.new(1.4, 0.15, 1.4), cf, WHITE, Enum.Material.SmoothPlastic, m)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	p.Size = Vector3.new(0.15, 1.4, 1.4)
	if rng:NextNumber() < 0.6 then
		part(
			"Food",
			Vector3.new(0.7, 0.4, 0.7),
			cf * CFrame.new(0, 0.3, 0),
			({
				Color3.fromRGB(200, 120, 60),
				Color3.fromRGB(220, 60, 50),
				Color3.fromRGB(230, 200, 120),
			})[rng:NextInteger(1, 3)],
			Enum.Material.SmoothPlastic,
			m
		)
	end
	local mug = part(
		"Mug",
		Vector3.new(0.5, 0.7, 0.5),
		cf * CFrame.new(1.1, 0.35, 0.3),
		Color3.fromRGB(120, 90, 70),
		Enum.Material.SmoothPlastic,
		m
	)
	mug.Shape = Enum.PartType.Cylinder
	mug.CFrame = cf * CFrame.new(1.1, 0.35, 0.3) * CFrame.Angles(0, 0, math.pi / 2)
	mug.Size = Vector3.new(0.7, 0.5, 0.5)
end
local function shelf(m, cx, cz, len, rotY, levels, goods)
	local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, rotY or 0, 0)
	for _, dx in ipairs({ -len / 2 + 0.3, len / 2 - 0.3 }) do
		part(
			"ShelfPost",
			Vector3.new(0.5, levels * 2.6 + 0.5, 1.8),
			cf * CFrame.new(dx, (levels * 2.6 + 0.5) / 2, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
	for lv = 1, levels do
		local y = lv * 2.6
		part(
			"ShelfBoard",
			Vector3.new(len, 0.3, 1.8),
			cf * CFrame.new(0, y, 0),
			WOOD,
			"px_planks",
			m
		)
		local n = math.floor(len / 1.6)
		for i = 1, n do
			if rng:NextNumber() < 0.8 then
				local g = goods[rng:NextInteger(1, #goods)]
				local gx = -len / 2 + 0.9 + (i - 1) * 1.6
				local size = g.size or Vector3.new(1.1, 1.1, 1.1)
				part(
					"Goods",
					size,
					cf * CFrame.new(gx, y + 0.15 + size.Y / 2, 0),
					g.color or Color3.new(1, 1, 1),
					g.mat,
					m
				)
			end
		end
	end
end
local function crate(m, x, y, z, s, variant)
	return part(
		"Crate",
		Vector3.new(s, s, s),
		CFrame.new(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
		WOOD,
		variant or "px_planks",
		m
	)
end
local function barrel(m, x, z)
	local p = part(
		"Barrel",
		Vector3.new(4, 3, 3),
		CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	p.Shape = Enum.PartType.Cylinder
	part(
		"BarrelRing",
		Vector3.new(0.4, 3.2, 3.2),
		CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal,
		m
	)
	return p
end
local function rug(m, cx, cz, w, d, color)
	part(
		"Rug",
		Vector3.new(w, 0.15, d),
		CFrame.new(cx, 0.68, cz),
		color or CLOTH,
		Enum.Material.Fabric,
		m
	)
	part(
		"RugBorder",
		Vector3.new(w + 0.8, 0.12, d + 0.8),
		CFrame.new(cx, 0.66, cz),
		Color3.fromRGB(230, 190, 100),
		Enum.Material.Fabric,
		m
	)
end
local function wallLamp(m, cf)
	part("Bracket", Vector3.new(0.4, 0.4, 1.2), cf, IRON, Enum.Material.Metal, m)
	local l = part(
		"WallLamp",
		Vector3.new(0.9, 1.2, 0.9),
		cf * CFrame.new(0, 0.6, 0.6),
		LAMP,
		Enum.Material.Neon,
		m
	)
	light(l, Color3.fromRGB(255, 190, 110), 18, 1)
end
local GOODS = {
	{ mat = "px_melon", color = Color3.new(1, 1, 1) },
	{ mat = "px_oak_log", color = Color3.new(1, 1, 1) },
	{ mat = "px_sand", color = Color3.new(1, 1, 1) },
	{ mat = "px_coal_ore", color = Color3.new(1, 1, 1) },
	{
		mat = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(220, 60, 50),
		size = Vector3.new(0.8, 0.8, 0.8),
	}, -- apples
	{
		mat = Enum.Material.Fabric,
		color = Color3.fromRGB(230, 200, 120),
		size = Vector3.new(1.4, 0.8, 0.8),
	}, -- bread
	{
		mat = Enum.Material.Glass,
		color = Color3.fromRGB(90, 200, 90),
		size = Vector3.new(0.6, 1.2, 0.6),
	}, -- potion
	{
		mat = Enum.Material.Metal,
		color = Color3.fromRGB(200, 200, 210),
		size = Vector3.new(1, 0.6, 1),
	}, -- tin
}

-- ================================================================== РЫНОК (market)
do
	local m = shell({
		name = "Market",
		label = "Рынок",
		cx = 120,
		cz = -110,
		w = 60,
		d = 40,
		h = 14,
		doors = {
			{ side = "S", at = 0, width = 7, height = 8 },
			{ side = "W", at = 14, width = 5, height = 7 },
		},
		windows = {
			{ side = "S", at = -18, width = 7, height = 4 },
			{ side = "S", at = 18, width = 7, height = 4 },
			{ side = "N", at = -15, width = 7, height = 4 },
			{ side = "N", at = 15, width = 7, height = 4 },
			{ side = "E", at = 0, width = 8, height = 4 },
		},
		floor = "px_planks",
		wall = "px_red_brick",
		roof = "gable",
		chimney = { 22, -12 },
	})
	-- Counter in the middle, shelves along N wall, stalls along E/W walls, rugs, barrels.
	rug(m, 120, -110, 24, 14, Color3.fromRGB(120, 50, 45))
	table_(m, 120, 3, -118, 18, 3)
	for i = -2, 2 do
		part(
			"CounterGoods",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(120 + i * 3.5, 3.95, -118),
			Color3.new(1, 1, 1),
			GOODS[rng:NextInteger(1, 4)].mat,
			m
		)
	end
	part(
		"Scale",
		Vector3.new(2, 0.3, 1.2),
		CFrame.new(128, 3.4, -118),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"ScalePost",
		Vector3.new(0.3, 2.5, 0.3),
		CFrame.new(128, 4.5, -118),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"ScalePan",
		Vector3.new(1.2, 0.2, 1.2),
		CFrame.new(127.3, 5.6, -118),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"ScalePan",
		Vector3.new(1.2, 0.2, 1.2),
		CFrame.new(128.7, 5.6, -118),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"CashBox",
		Vector3.new(1.6, 1, 1.2),
		CFrame.new(112, 3.75, -118),
		Color3.fromRGB(60, 80, 60),
		Enum.Material.Metal,
		m
	)
	shelf(m, 105, -128, 24, 0, 3, GOODS)
	shelf(m, 135, -128, 24, 0, 3, GOODS)
	shelf(m, 92, -110, 22, math.pi / 2, 3, GOODS)
	shelf(m, 148, -102, 12, math.pi / 2, 3, GOODS)
	-- display tables with cloth
	for _, x in ipairs({ 104, 136 }) do
		local cf = table_(m, x, 2.6, -100, 8, 5)
		part(
			"Cloth",
			Vector3.new(8.4, 0.2, 5.4),
			cf * CFrame.new(0, 2.95, 0),
			({ Color3.fromRGB(190, 60, 50), Color3.fromRGB(60, 90, 160) })[rng:NextInteger(1, 2)],
			Enum.Material.Fabric,
			m
		)
		for i = 1, 4 do
			local g = GOODS[rng:NextInteger(1, #GOODS)]
			local size = g.size or Vector3.new(1.1, 1.1, 1.1)
			part(
				"Goods",
				size,
				cf * CFrame.new(-3 + (i - 1) * 2, 3.05 + size.Y / 2, rng:NextNumber(-1.2, 1.2)),
				g.color,
				g.mat,
				m
			)
		end
	end
	for _, p in ipairs({ { 94, -94 }, { 97, -94 }, { 146, -94 }, { 146, -97 } }) do
		barrel(m, p[1], p[2])
	end
	crate(m, 143, 0.6, -120, 3)
	crate(m, 143, 3.6, -120, 2.5)
	crate(m, 140, 0.6, -122, 2.5, "px_oak_log")
	-- hanging banners and sacks
	for _, x in ipairs({ 100, 120, 140 }) do
		part(
			"Banner",
			Vector3.new(3, 5, 0.2),
			CFrame.new(x, 10, -129),
			({ CLOTH, Color3.fromRGB(60, 90, 160), Color3.fromRGB(220, 170, 60) })[rng:NextInteger(
				1,
				3
			)],
			Enum.Material.Fabric,
			m
		)
	end
	for i = 1, 5 do
		local s = part(
			"Sack",
			Vector3.new(1.8, 2, 1.6),
			CFrame.new(96 + i * 2.2, 1.6, -126 + (i % 2) * 1.5)
				* CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Color3.fromRGB(200, 180, 140),
			Enum.Material.Fabric,
			m
		)
		s.Shape = Enum.PartType.Ball
	end
	wallLamp(m, CFrame.new(92.6, 9, -100) * CFrame.Angles(0, math.pi / 2, 0))
	wallLamp(m, CFrame.new(92.6, 9, -120) * CFrame.Angles(0, math.pi / 2, 0))
	wallLamp(m, CFrame.new(147.4, 9, -120) * CFrame.Angles(0, -math.pi / 2, 0))
	-- outside: awning over the main door and two market stalls by the facade
	part(
		"Awning",
		Vector3.new(14, 0.3, 5),
		CFrame.new(120, 9.5, -87) * CFrame.Angles(0.25, 0, 0),
		CLOTH,
		Enum.Material.Fabric,
		m
	)
	for _, x in ipairs({ 100, 140 }) do
		part(
			"StallTop",
			Vector3.new(10, 0.5, 7),
			CFrame.new(x, 7, -84),
			({ CLOTH, Color3.fromRGB(60, 120, 90) })[rng:NextInteger(1, 2)],
			Enum.Material.Fabric,
			m
		)
		part("StallCounter", Vector3.new(10, 3, 3), CFrame.new(x, 1.5, -82), WOOD, "px_planks", m).CanCollide =
			true
		for _, dx in ipairs({ -4.5, 4.5 }) do
			part(
				"StallPost",
				Vector3.new(0.6, 7, 0.6),
				CFrame.new(x + dx, 3.5, -87),
				DARK_WOOD,
				Enum.Material.Wood,
				m
			)
		end
		for i = 1, 4 do
			local g = GOODS[rng:NextInteger(1, #GOODS)]
			local size = g.size or Vector3.new(1.1, 1.1, 1.1)
			part(
				"Goods",
				size,
				CFrame.new(x - 3.5 + (i - 1) * 2.3, 3 + size.Y / 2, -82),
				g.color,
				g.mat,
				m
			)
		end
	end
end

-- ================================================================== СТОЛОВАЯ (canteen)
do
	local m = shell({
		name = "Canteen",
		label = "Столовая",
		cx = 140,
		cz = 10,
		w = 40,
		d = 80,
		h = 14,
		doors = {
			{ side = "W", at = 0, width = 7, height = 8 },
			{ side = "N", at = 0, width = 5, height = 7 },
		},
		windows = {
			{ side = "W", at = -26, width = 8, height = 4 },
			{ side = "W", at = 26, width = 8, height = 4 },
			{ side = "E", at = -24, width = 8, height = 4 },
			{ side = "E", at = 0, width = 8, height = 4 },
			{ side = "E", at = 24, width = 8, height = 4 },
			{ side = "S", at = 0, width = 10, height = 4 },
		},
		floor = "px_concrete_floor",
		wall = "px_prison_wall",
		roof = "flat",
		chimney = { 14, -32 },
		lampColor = Color3.fromRGB(255, 230, 180),
	})
	-- Dining hall: 3 rows × 3 long tables with benches and plates.
	for col = -1, 1, 2 do
		for row = 0, 2 do
			local x = 142 + col * 8
			local z = -14 + row * 20
			local cf = table_(m, x, 3, z, 5, 14)
			bench(m, cf * CFrame.new(-3.6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 12)
			bench(m, cf * CFrame.new(3.6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 12)
			for i = -2, 2 do
				if rng:NextNumber() < 0.75 then
					plate(m, cf * CFrame.new(rng:NextNumber(-1, 1), 3.35, i * 2.6))
				end
			end
			local candle = part(
				"Candle",
				Vector3.new(0.3, 0.8, 0.3),
				cf * CFrame.new(0, 3.65, 0),
				WHITE,
				Enum.Material.SmoothPlastic,
				m
			)
			local flame = part(
				"Flame",
				Vector3.new(0.25, 0.3, 0.25),
				cf * CFrame.new(0, 4.2, 0),
				Color3.fromRGB(255, 200, 80),
				Enum.Material.Neon,
				m
			)
			light(flame, Color3.fromRGB(255, 170, 90), 8, 0.8)
			candle.CanCollide = false
		end
	end
	-- Kitchen at the south end: counter, stove, pots, shelves with bread, serving window.
	part(
		"KitchenCounter",
		Vector3.new(34, 3.5, 3),
		CFrame.new(140, 1.75, 34),
		STONE,
		"px_cobblestone",
		m
	).CanCollide =
		true
	part(
		"CounterTop",
		Vector3.new(34.4, 0.4, 3.4),
		CFrame.new(140, 3.7, 34),
		DARK,
		Enum.Material.Slate,
		m
	)
	for i = 1, 6 do
		plate(m, CFrame.new(126 + i * 3.5, 3.95, 34))
	end
	part("Stove", Vector3.new(8, 4, 4), CFrame.new(130, 2, 44), CLOTH, "px_red_brick", m).CanCollide =
		true
	part(
		"StoveTop",
		Vector3.new(8.4, 0.4, 4.4),
		CFrame.new(130, 4.2, 44),
		DARK,
		Enum.Material.Metal,
		m
	)
	local fire = part(
		"StoveFire",
		Vector3.new(6, 1.2, 0.3),
		CFrame.new(130, 1.5, 41.8),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon,
		m
	)
	light(fire, Color3.fromRGB(255, 140, 60), 14, 1.5)
	particles(fire, Color3.fromRGB(255, 160, 60), 8, 0.8, 2, 0.8, 0.3)
	for _, dx in ipairs({ -2.2, 1.2 }) do
		local pot = part(
			"Pot",
			Vector3.new(2.2, 1.6, 2.2),
			CFrame.new(130 + dx, 5.2, 44),
			DARK,
			Enum.Material.Metal,
			m
		)
		pot.Shape = Enum.PartType.Cylinder
		pot.CFrame = CFrame.new(130 + dx, 5.2, 44) * CFrame.Angles(0, 0, math.pi / 2)
		pot.Size = Vector3.new(1.6, 2.2, 2.2)
		local steam = part(
			"Steam",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(130 + dx, 6.2, 44),
			WHITE,
			Enum.Material.SmoothPlastic,
			m
		)
		steam.Transparency = 1
		particles(steam, WHITE, 4, 1.2, 1.5, 1.6, 0.7)
	end
	part("Sink", Vector3.new(5, 3.5, 3), CFrame.new(148, 1.75, 44), IRON, Enum.Material.Metal, m)
	part(
		"SinkBasin",
		Vector3.new(4, 0.6, 2.2),
		CFrame.new(148, 3.6, 44),
		WATER,
		Enum.Material.Glass,
		m
	).Transparency =
		0.5
	part(
		"Tap",
		Vector3.new(0.3, 1.5, 0.3),
		CFrame.new(148, 4.5, 45.2),
		IRON,
		Enum.Material.Metal,
		m
	)
	shelf(m, 140, 48, 30, 0, 2, { GOODS[6], GOODS[5], GOODS[8], { mat = "px_melon" } })
	for i = 1, 3 do
		barrel(m, 123 + i * 3.2, 46)
	end
	crate(m, 156, 0.6, 46, 2.5)
	crate(m, 156, 3.1, 46, 2)
	-- Notice board and coat hooks by the entrance
	local board = part(
		"MenuBoard",
		Vector3.new(0.4, 4, 6),
		CFrame.new(121, 7, -12),
		DARK_WOOD,
		"px_planks",
		m
	)
	boardText(
		board,
		Enum.NormalId.Right,
		"МЕНЮ\nЯблоко 0.03$\nХлеб 0.25$\nКурица 0.5$"
	)
	for i = 1, 5 do
		part(
			"Hook",
			Vector3.new(0.3, 0.3, 0.6),
			CFrame.new(121, 7.5, 2 + i * 1.5),
			IRON,
			Enum.Material.Metal,
			m
		)
		if i % 2 == 1 then
			part(
				"Coat",
				Vector3.new(0.5, 2.8, 1.2),
				CFrame.new(121.4, 6, 2 + i * 1.5),
				({ Color3.fromRGB(60, 60, 70), Color3.fromRGB(110, 60, 40) })[rng:NextInteger(1, 2)],
				Enum.Material.Fabric,
				m
			)
		end
	end
	for _, z in ipairs({ -30, 0, 30 }) do
		wallLamp(m, CFrame.new(159.4, 9, z) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	-- Outdoor terrace by the west door: three round tables with chairs under umbrellas.
	for i = -1, 1 do
		local x, z = 104, 10 + i * 14
		part(
			"TerraceTable",
			Vector3.new(0.4, 2.8, 0.4),
			CFrame.new(x, 1.4, z),
			IRON,
			Enum.Material.Metal,
			m
		)
		local top = part(
			"TerraceTop",
			Vector3.new(0.3, 4, 4),
			CFrame.new(x, 2.9, z) * CFrame.Angles(0, 0, math.pi / 2),
			WOOD,
			Enum.Material.Wood,
			m
		)
		top.Shape = Enum.PartType.Cylinder
		part(
			"UmbrellaPole",
			Vector3.new(0.3, 7, 0.3),
			CFrame.new(x, 6, z),
			IRON,
			Enum.Material.Metal,
			m
		)
		local u = part(
			"Umbrella",
			Vector3.new(0.6, 7, 7),
			CFrame.new(x, 9.2, z) * CFrame.Angles(0, 0, math.pi / 2),
			({ CLOTH, Color3.fromRGB(240, 230, 200) })[(i + 2) % 2 + 1],
			Enum.Material.Fabric,
			m
		)
		u.Shape = Enum.PartType.Cylinder
		chair(m, CFrame.new(x - 3, 0, z) * CFrame.Angles(0, -math.pi / 2, 0))
		chair(m, CFrame.new(x + 3, 0, z) * CFrame.Angles(0, math.pi / 2, 0))
		plate(m, CFrame.new(x - 0.8, 3.15, z + 0.4))
	end
end

-- ================================================================== СПАЛЬНЯ (bedroom)
do
	local m = shell({
		name = "Bedroom",
		label = "Спальня",
		cx = -120,
		cz = 110,
		w = 60,
		d = 40,
		h = 13,
		doors = {
			{ side = "N", at = 0, width = 6, height = 8 },
			{ side = "E", at = 8, width = 4, height = 7 },
		},
		windows = {
			{ side = "N", at = -20, width = 6, height = 3.5, y = 8 },
			{ side = "N", at = 20, width = 6, height = 3.5, y = 8 },
			{ side = "S", at = -18, width = 6, height = 3.5, y = 8 },
			{ side = "S", at = 0, width = 6, height = 3.5, y = 8 },
			{ side = "S", at = 18, width = 6, height = 3.5, y = 8 },
			{ side = "W", at = 0, width = 8, height = 3.5, y = 8 },
		},
		floor = "px_planks",
		wall = "px_prison_wall",
		roof = "gable",
		lampColor = Color3.fromRGB(255, 200, 150),
	})
	rug(m, -120, 110, 40, 10, Color3.fromRGB(70, 90, 140))
	-- Two rows of bunk beds (5 bunks per row = 20 sleeping places), each bed restores sleep.
	local function bunk(x, z, rotY)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rotY, 0)
		for _, c in ipairs({ { -2.6, -4.4 }, { 2.6, -4.4 }, { -2.6, 4.4 }, { 2.6, 4.4 } }) do
			part(
				"BunkPost",
				Vector3.new(0.5, 8, 0.5),
				cf * CFrame.new(c[1], 4, c[2]),
				DARK_WOOD,
				Enum.Material.Wood,
				m
			)
		end
		for lv, y in ipairs({ 1.2, 5.2 }) do
			part(
				"BedFrame",
				Vector3.new(5.6, 0.5, 9.4),
				cf * CFrame.new(0, y, 0),
				DARK_WOOD,
				"px_planks",
				m
			).CanCollide =
				true
			local bed = part(
				"Bed",
				Vector3.new(5, 0.9, 9),
				cf * CFrame.new(0, y + 0.7, 0),
				({
					Color3.fromRGB(60, 120, 200),
					Color3.fromRGB(170, 60, 60),
					Color3.fromRGB(70, 140, 90),
				})[rng:NextInteger(1, 3)],
				Enum.Material.Fabric,
				m
			)
			bed.CanCollide = true
			CollectionService:AddTag(bed, "RestoreSleep")
			part(
				"Pillow",
				Vector3.new(3.6, 0.6, 1.8),
				cf * CFrame.new(0, y + 1.45, -3.3),
				WHITE,
				Enum.Material.Fabric,
				m
			)
			part(
				"Blanket",
				Vector3.new(5.1, 0.3, 5.5),
				cf * CFrame.new(0, y + 1.25, 1.5),
				Color3.fromRGB(200, 200, 210),
				Enum.Material.Fabric,
				m
			)
			if lv == 2 then
				part(
					"Rail",
					Vector3.new(0.3, 1.2, 9.4),
					cf * CFrame.new(2.7, y + 1.6, 0),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
			end
		end
		-- ladder
		for i = 1, 4 do
			part(
				"Rung",
				Vector3.new(1.2, 0.25, 0.25),
				cf * CFrame.new(-2.6, 1.5 + i * 0.9, 4.7),
				DARK_WOOD,
				Enum.Material.Wood,
				m
			)
		end
		-- locker and chest
		part(
			"Locker",
			Vector3.new(2, 6, 2),
			cf * CFrame.new(4.6, 3, -3.4),
			Color3.fromRGB(80, 90, 100),
			Enum.Material.Metal,
			m
		).CanCollide =
			true
		part(
			"LockerDoorLine",
			Vector3.new(0.1, 5.4, 1.6),
			cf * CFrame.new(3.6, 3, -3.4),
			DARK,
			Enum.Material.Metal,
			m
		)
		local chest = part(
			"FootChest",
			Vector3.new(3, 1.6, 1.6),
			cf * CFrame.new(0, 0.8, 5.8),
			WOOD,
			"px_planks",
			m
		)
		chest.CanCollide = true
		part(
			"ChestBand",
			Vector3.new(3.1, 0.4, 1.7),
			cf * CFrame.new(0, 1.3, 5.8),
			IRON,
			Enum.Material.Metal,
			m
		)
	end
	for i = 0, 4 do
		-- [владелец 21.10] the middle bunk of the front row stood in the north doorway: keep the way in free
		if i ~= 2 then
			bunk(-144 + i * 12, 96, 0)
		end
		bunk(-144 + i * 12, 124, math.pi)
	end
	-- Wardrobe, stove and a reading corner on the east side
	part("Wardrobe", Vector3.new(6, 9, 3), CFrame.new(-93, 4.5, 122), DARK_WOOD, "px_planks", m).CanCollide =
		true
	part(
		"WardrobeDoors",
		Vector3.new(5.4, 8, 0.2),
		CFrame.new(-93, 4.5, 120.4),
		WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"WardrobeHandle",
		Vector3.new(0.3, 1.2, 0.3),
		CFrame.new(-93.4, 4.5, 120.2),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"WardrobeHandle",
		Vector3.new(0.3, 1.2, 0.3),
		CFrame.new(-92.6, 4.5, 120.2),
		IRON,
		Enum.Material.Metal,
		m
	)
	part("Stove", Vector3.new(3, 4, 3), CFrame.new(-93, 2, 100), DARK, Enum.Material.Metal, m).CanCollide =
		true
	part(
		"StovePipe",
		Vector3.new(0.8, 8, 0.8),
		CFrame.new(-93, 8, 100),
		DARK,
		Enum.Material.Metal,
		m
	)
	local glow = part(
		"StoveGlow",
		Vector3.new(1.6, 1.2, 0.2),
		CFrame.new(-93, 1.6, 98.4),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon,
		m
	)
	light(glow, Color3.fromRGB(255, 140, 70), 16, 1.5)
	chair(m, CFrame.new(-98, 0, 104) * CFrame.Angles(0, math.pi / 2, 0))
	chair(m, CFrame.new(-98, 0, 112) * CFrame.Angles(0, math.pi / 2, 0))
	table_(m, -102, 2.6, 108, 4, 4)
	part(
		"Book",
		Vector3.new(1.4, 0.3, 1),
		CFrame.new(-102, 3, 108),
		Color3.fromRGB(150, 50, 50),
		Enum.Material.SmoothPlastic,
		m
	)
	part(
		"Lantern",
		Vector3.new(0.8, 1.1, 0.8),
		CFrame.new(-101, 3.4, 109.3),
		LAMP,
		Enum.Material.Neon,
		m
	)
	-- Curtains on windows, wall lamps, carpet runner
	for _, z in ipairs({ 90.6, 129.4 }) do
		for _, x in ipairs({ -140, -100 }) do
			part(
				"Curtain",
				Vector3.new(7, 5, 0.3),
				CFrame.new(x, 8, z),
				Color3.fromRGB(140, 60, 60),
				Enum.Material.Fabric,
				m
			)
		end
	end
	for _, x in ipairs({ -140, -120, -100 }) do
		wallLamp(m, CFrame.new(x, 8.5, 90.9))
		wallLamp(m, CFrame.new(x, 8.5, 129.1) * CFrame.Angles(0, math.pi, 0))
	end
	-- Porch with two benches outside the north door
	part("Porch", Vector3.new(14, 0.5, 6), CFrame.new(-120, 0.25, 86), STONE, "px_cobblestone", m).CanCollide =
		true
	part("PorchRoof", Vector3.new(14, 0.5, 6), CFrame.new(-120, 9.5, 86), DARK_WOOD, "px_planks", m)
	part(
		"PorchPost",
		Vector3.new(0.6, 9, 0.6),
		CFrame.new(-126.5, 4.75, 83.5),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"PorchPost",
		Vector3.new(0.6, 9, 0.6),
		CFrame.new(-113.5, 4.75, 83.5),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	bench(m, CFrame.new(-125, 0, 86) * CFrame.Angles(0, math.pi / 2, 0), 4)
	bench(m, CFrame.new(-115, 0, 86) * CFrame.Angles(0, math.pi / 2, 0), 4)
end

-- ================================================================== БАНЯ (bath)
do
	local m = shell({
		name = "Bath",
		label = "Баня",
		cx = -120,
		cz = -110,
		w = 60,
		d = 40,
		h = 13,
		doors = {
			{ side = "S", at = 0, width = 6, height = 8 },
			{ side = "E", at = 16, width = 4, height = 7 },
		},
		windows = {
			{ side = "S", at = -20, width = 5, height = 3, y = 9 },
			{ side = "S", at = 20, width = 5, height = 3, y = 9 },
			{ side = "N", at = -15, width = 5, height = 3, y = 9 },
			{ side = "N", at = 15, width = 5, height = 3, y = 9 },
		},
		floor = Enum.Material.Marble,
		floorColor = TILE,
		wall = "px_prison_wall",
		roof = "flat",
		chimney = { -24, -14 },
		lampColor = Color3.fromRGB(200, 230, 255),
		-- pools are sunken basins with terrain water (cut out of the ground by build-prison)
		floorHoles = {
			{ x0 = -144, x1 = -128, z0 = -122, z1 = -110 },
			{ x0 = -124, x1 = -108, z0 = -122, z1 = -110 },
			{ x0 = -102, x1 = -94, z0 = -122, z1 = -114 },
		},
	})
	-- Tiled floor band and a tiled wall skirt
	for _, seg in ipairs({
		{ Vector3.new(58, 3, 0.3), CFrame.new(-120, 2.1, -129.2) }, -- N
		{ Vector3.new(24, 3, 0.3), CFrame.new(-137, 2.1, -90.8) }, -- S left of the door
		{ Vector3.new(24, 3, 0.3), CFrame.new(-103, 2.1, -90.8) }, -- S right of the door
		{ Vector3.new(0.3, 3, 38), CFrame.new(-149.2, 2.1, -110) }, -- W
		{ Vector3.new(0.3, 3, 32), CFrame.new(-90.8, 2.1, -113) }, -- E below the door (door z -96..-92)
	}) do
		part("WallTiles", seg[1], seg[2], Color3.fromRGB(80, 140, 170), Enum.Material.Marble, m)
	end
	-- Three sunken pools (hot, warm, cold): water surface at y 0 (terrain), low rims, steps, steam.
	for _, p in ipairs({
		{ -136, -116, 16, 12, true },
		{ -116, -116, 16, 12, true },
		{ -98, -118, 8, 8, false },
	}) do
		local x, z, w, d, hot = p[1], p[2], p[3], p[4], p[5]
		for _, seg in ipairs({
			{ Vector3.new(w + 2.4, 1, 1.2), CFrame.new(x, 1.1, z - d / 2 - 0.6) },
			{ Vector3.new(w + 2.4, 1, 1.2), CFrame.new(x, 1.1, z + d / 2 + 0.6) },
			{ Vector3.new(1.2, 1, d + 2.4), CFrame.new(x - w / 2 - 0.6, 1.1, z) },
			{ Vector3.new(1.2, 1, d + 2.4), CFrame.new(x + w / 2 + 0.6, 1.1, z) },
		}) do
			part("PoolRim", seg[1], seg[2], STONE, "px_cobblestone", m).CanCollide = true
		end
		local zone = part(
			"BathWater",
			Vector3.new(w, 1, d),
			CFrame.new(x, -0.5, z),
			WATER,
			Enum.Material.Glass,
			m
		)
		zone.Transparency = 1
		zone.CanCollide = false
		zone.CanQuery = false
		CollectionService:AddTag(zone, "RestoreHygiene")
		if hot then
			local steam = part(
				"Steam",
				Vector3.new(w - 2, 0.2, d - 2),
				CFrame.new(x, 0.6, z),
				WHITE,
				Enum.Material.SmoothPlastic,
				m
			)
			steam.Transparency = 1
			steam.CanCollide = false
			particles(steam, WHITE, 10, 2.5, 1, 3, 0.75)
		end
		part(
			"PoolStep",
			Vector3.new(w - 1, 1.2, 2),
			CFrame.new(x, -3.4, z + d / 2 - 1),
			STONE,
			"px_cobblestone",
			m
		).CanCollide =
			true
	end
	-- Showers along the north wall
	for i = 1, 5 do
		local x = -146 + i * 9
		part(
			"ShowerPipe",
			Vector3.new(0.4, 9, 0.4),
			CFrame.new(x, 4.5, -127.5),
			IRON,
			Enum.Material.Metal,
			m
		)
		part(
			"ShowerArm",
			Vector3.new(0.4, 0.4, 2.5),
			CFrame.new(x, 9, -126.2),
			IRON,
			Enum.Material.Metal,
			m
		)
		local head = part(
			"ShowerHead",
			Vector3.new(1.4, 0.4, 1.4),
			CFrame.new(x, 8.8, -125),
			IRON,
			Enum.Material.Metal,
			m
		)
		local drops = particles(head, Color3.fromRGB(190, 220, 255), 14, 0.25, 8, 1, 0.3)
		drops.Acceleration = Vector3.new(0, -20, 0)
		drops.EmissionDirection = Enum.NormalId.Bottom
		-- [владелец 21.10] the showers wash too (the pools were the only RestoreHygiene zones)
		CollectionService:AddTag(
			part("Drain", Vector3.new(1.6, 0.1, 1.6), CFrame.new(x, 0.82, -125), DARK, Enum.Material.Metal, m),
			"RestoreHygiene"
		)
		if i < 5 then
			part(
				"ShowerDivider",
				Vector3.new(0.3, 6, 4),
				CFrame.new(x + 4.5, 3.8, -126),
				TILE,
				Enum.Material.Marble,
				m
			)
		end
	end
	-- Benches, towel racks, buckets, soap
	bench(m, CFrame.new(-110, 0, -96), 12)
	bench(m, CFrame.new(-130, 0, -96), 12)
	for _, x in ipairs({ -140, -100 }) do
		part(
			"TowelRack",
			Vector3.new(6, 0.3, 0.3),
			CFrame.new(x, 6, -91.4),
			IRON,
			Enum.Material.Metal,
			m
		)
		for i = 1, 3 do
			part(
				"Towel",
				Vector3.new(1.4, 3, 0.3),
				CFrame.new(x - 2 + (i - 1) * 2, 4.6, -91.4),
				({ WHITE, Color3.fromRGB(120, 180, 220), Color3.fromRGB(230, 200, 120) })[i],
				Enum.Material.Fabric,
				m
			)
		end
	end
	for _, p in ipairs({ { -146, -100 }, { -144, -98 }, { -93, -96 } }) do
		local b = part(
			"Bucket",
			Vector3.new(1.6, 1.4, 1.6),
			CFrame.new(p[1], 1.5, p[2]) * CFrame.Angles(0, 0, math.pi / 2),
			WOOD,
			Enum.Material.Wood,
			m
		)
		b.Shape = Enum.PartType.Cylinder
		b.Size = Vector3.new(1.4, 1.6, 1.6)
	end
	part(
		"Soap",
		Vector3.new(0.9, 0.4, 0.6),
		CFrame.new(-110, 2, -96),
		Color3.fromRGB(240, 200, 220),
		Enum.Material.SmoothPlastic,
		m
	)
	-- Toilet stalls (RestoreToilet) in the east annex with doors
	for i = 1, 3 do
		local z = -124 + i * 7
		-- [владелец 21.10] the 6-stud front walls left a 1-stud gap: now a pillar, the stall is open
		part(
			"StallWall",
			Vector3.new(0.3, 7, 1),
			CFrame.new(-96, 4.3, z - 3),
			TILE,
			Enum.Material.Marble,
			m
		).CanCollide =
			true
		part(
			"StallBack",
			Vector3.new(7, 7, 0.3),
			CFrame.new(-93, 4.3, z + 3.3),
			TILE,
			Enum.Material.Marble,
			m
		)
		local door = part(
			"StallDoor",
			Vector3.new(0.3, 6, 4.2),
			CFrame.new(-97.9, 3.8, z - 0.6) * CFrame.Angles(0, math.pi / 2, 0), -- swung fully open
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		door.CanCollide = false
		local toilet = part(
			"Toilet",
			Vector3.new(1.8, 1.6, 2.4),
			CFrame.new(-92, 1.6, z + 1.5),
			WHITE,
			Enum.Material.SmoothPlastic,
			m
		)
		toilet.CanCollide = true
		CollectionService:AddTag(toilet, "RestoreToilet")
		part(
			"Tank",
			Vector3.new(1.8, 2, 0.8),
			CFrame.new(-92, 3.2, z + 2.6),
			WHITE,
			Enum.Material.SmoothPlastic,
			m
		)
		part(
			"Lever",
			Vector3.new(0.3, 0.3, 0.8),
			CFrame.new(-91, 4.3, z + 2.2),
			IRON,
			Enum.Material.Metal,
			m
		)
		part(
			"PaperRoll",
			Vector3.new(0.8, 0.8, 0.6),
			CFrame.new(-93.5, 2.8, z - 0.5),
			WHITE,
			Enum.Material.SmoothPlastic,
			m
		)
	end
	part(
		"StallWall",
		Vector3.new(0.3, 7, 1),
		CFrame.new(-96, 4.3, -97),
		TILE,
		Enum.Material.Marble,
		m
	).CanCollide =
		true
	part(
		"Sinks",
		Vector3.new(8, 3, 2),
		CFrame.new(-110, 1.5, -127.5),
		WHITE,
		Enum.Material.SmoothPlastic,
		m
	).CanCollide =
		true
	for i = 1, 3 do
		part(
			"Tap",
			Vector3.new(0.3, 1.2, 0.3),
			CFrame.new(-113 + i * 1.5 * 1.5, 3.6, -128.2),
			IRON,
			Enum.Material.Metal,
			m
		)
	end
	local mirror = part(
		"Mirror",
		Vector3.new(8, 3, 0.2),
		CFrame.new(-110, 6.5, -128.2),
		Color3.fromRGB(200, 220, 240),
		Enum.Material.Glass,
		m
	)
	mirror.Reflectance = 0.6
	-- Outside: wood pile and a water tower
	for i = 1, 3 do
		for j = 1, 4 - i do
			local log = part(
				"Log",
				Vector3.new(4, 1.2, 1.2),
				CFrame.new(-150 + j * 1.3 + i * 0.6, -0.4 + i * 1.1, -86)
					* CFrame.Angles(0, 0, math.pi / 2),
				WOOD,
				"px_oak_log",
				m
			)
			log.Shape = Enum.PartType.Cylinder
			log.Size = Vector3.new(1.2, 4, 1.2)
			log.CFrame = CFrame.new(-150 + j * 1.3 + i * 0.6, -0.4 + i * 1.1, -86)
				* CFrame.Angles(math.pi / 2, 0, 0)
		end
	end
	part(
		"TowerLeg",
		Vector3.new(0.8, 14, 0.8),
		CFrame.new(-92, 7, -134),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"TowerLeg",
		Vector3.new(0.8, 14, 0.8),
		CFrame.new(-86, 7, -134),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"TowerLeg",
		Vector3.new(0.8, 14, 0.8),
		CFrame.new(-92, 7, -140),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"TowerLeg",
		Vector3.new(0.8, 14, 0.8),
		CFrame.new(-86, 7, -140),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	local tank = part(
		"WaterTank",
		Vector3.new(6, 7, 7),
		CFrame.new(-89, 17.5, -137) * CFrame.Angles(0, 0, math.pi / 2),
		WOOD,
		Enum.Material.Wood,
		m
	)
	tank.Shape = Enum.PartType.Cylinder
	tank.Size = Vector3.new(7, 6, 6)
	part(
		"TankRing",
		Vector3.new(0.5, 6.3, 6.3),
		CFrame.new(-89, 16, -137) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"TankRing",
		Vector3.new(0.5, 6.3, 6.3),
		CFrame.new(-89, 19, -137) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal,
		m
	)
	part(
		"TankPipe",
		Vector3.new(0.5, 14, 0.5),
		CFrame.new(-91, 7, -130.5),
		IRON,
		Enum.Material.Metal,
		m
	)
end

-- ================================================================== ТРЕНЕР (training yard)
do
	local m = Instance.new("Model")
	m.Name = "Trainer"
	m.Parent = buildings
	local cx, cz = 92, 132
	part("YardFloor", Vector3.new(44, 0.4, 34), CFrame.new(cx, 0.2, cz), STONE, "px_dirt", m)
	-- fence
	for x = cx - 22, cx + 22, 4 do
		for _, z in ipairs({ cz - 17, cz + 17 }) do
			part(
				"FencePost",
				Vector3.new(0.8, 4, 0.8),
				CFrame.new(x, 2, z),
				DARK_WOOD,
				Enum.Material.Wood,
				m
			)
		end
	end
	for z = cz - 17, cz + 17, 4 do
		for _, x in ipairs({ cx - 22, cx + 22 }) do
			if not (x == cx - 22 and math.abs(z - cz) < 5) then
				part(
					"FencePost",
					Vector3.new(0.8, 4, 0.8),
					CFrame.new(x, 2, z),
					DARK_WOOD,
					Enum.Material.Wood,
					m
				)
			end
		end
	end
	for _, z in ipairs({ cz - 17, cz + 17 }) do
		part(
			"FenceRail",
			Vector3.new(44, 0.4, 0.4),
			CFrame.new(cx, 3.2, z),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		part(
			"FenceRail",
			Vector3.new(44, 0.4, 0.4),
			CFrame.new(cx, 1.6, z),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
	part(
		"FenceRail",
		Vector3.new(0.4, 0.4, 34),
		CFrame.new(cx + 22, 3.2, cz),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	part(
		"FenceRail",
		Vector3.new(0.4, 0.4, 34),
		CFrame.new(cx + 22, 1.6, cz),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	-- roofed shed with weapon racks
	part(
		"ShedRoof",
		Vector3.new(16, 0.6, 10),
		CFrame.new(cx + 12, 9, cz - 10) * CFrame.Angles(0.15, 0, 0),
		DARK_WOOD,
		"px_planks",
		m
	)
	for _, c in ipairs({ { -7, -4 }, { 7, -4 }, { -7, 4 }, { 7, 4 } }) do
		part(
			"ShedPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(cx + 12 + c[1], 4.5, cz - 10 + c[2]),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
	part(
		"Rack",
		Vector3.new(12, 0.4, 0.4),
		CFrame.new(cx + 12, 5.5, cz - 14),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	for i = 1, 6 do
		local x = cx + 7 + i * 1.7
		part(
			"Blade",
			Vector3.new(0.3, 3, 0.8),
			CFrame.new(x, 3.6, cz - 14),
			({ WOOD, STONE, Color3.fromRGB(200, 200, 210) })[(i % 3) + 1],
			Enum.Material.Metal,
			m
		)
		part(
			"Hilt",
			Vector3.new(0.4, 1.2, 0.4),
			CFrame.new(x, 5.6, cz - 14),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		part(
			"Guard",
			Vector3.new(1.2, 0.3, 0.3),
			CFrame.new(x, 5.1, cz - 14),
			IRON,
			Enum.Material.Metal,
			m
		)
	end
	-- training dummies
	for i = 1, 4 do
		local x = cx - 16 + i * 7
		local z = cz + 6
		part(
			"DummyPost",
			Vector3.new(0.8, 6, 0.8),
			CFrame.new(x, 3, z),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		part(
			"DummyArms",
			Vector3.new(5, 0.6, 0.6),
			CFrame.new(x, 5.2, z),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		part(
			"DummyBody",
			Vector3.new(2.2, 3, 1.6),
			CFrame.new(x, 4.6, z),
			Color3.fromRGB(220, 190, 120),
			Enum.Material.Fabric,
			m
		)
		local head = part(
			"DummyHead",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(x, 6.9, z),
			Color3.fromRGB(220, 190, 120),
			Enum.Material.Fabric,
			m
		)
		head.Shape = Enum.PartType.Ball
		part(
			"DummyBand",
			Vector3.new(2.3, 0.3, 1.7),
			CFrame.new(x, 4.6, z),
			CLOTH,
			Enum.Material.Fabric,
			m
		)
	end
	-- archery targets, hay bales, sand pit
	for i = 1, 2 do
		local x = cx - 18 + i * 10
		local z = cz - 13
		local t = part(
			"Target",
			Vector3.new(0.4, 4, 4),
			CFrame.new(x, 3.5, z) * CFrame.Angles(0, 0, 0),
			WHITE,
			Enum.Material.SmoothPlastic,
			m
		)
		t.Shape = Enum.PartType.Cylinder
		t.CFrame = CFrame.new(x, 3.5, z) * CFrame.Angles(0, math.pi / 2, 0)
		local r = part(
			"TargetRing",
			Vector3.new(0.5, 2.6, 2.6),
			CFrame.new(x, 3.5, z + 0.1) * CFrame.Angles(0, math.pi / 2, 0),
			CLOTH,
			Enum.Material.SmoothPlastic,
			m
		)
		r.Shape = Enum.PartType.Cylinder
		local c = part(
			"TargetCenter",
			Vector3.new(0.6, 1, 1),
			CFrame.new(x, 3.5, z + 0.2) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(240, 200, 60),
			Enum.Material.SmoothPlastic,
			m
		)
		c.Shape = Enum.PartType.Cylinder
		part(
			"TargetLeg",
			Vector3.new(0.5, 3, 0.5),
			CFrame.new(x - 1.2, 1.5, z - 0.8),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		part(
			"TargetLeg",
			Vector3.new(0.5, 3, 0.5),
			CFrame.new(x + 1.2, 1.5, z - 0.8),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
	end
	for i = 1, 5 do
		local b = part(
			"HayBale",
			Vector3.new(3, 2.2, 2.2),
			CFrame.new(cx + 16 - (i % 3) * 3.3, 1.1 + math.floor((i - 1) / 3) * 2.2, cz + 12)
				* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
			Color3.fromRGB(220, 190, 90),
			Enum.Material.Fabric,
			m
		)
		part("HayBand", Vector3.new(3.1, 0.3, 2.3), b.CFrame, DARK_WOOD, Enum.Material.Fabric, m)
	end
	part("SandPit", Vector3.new(12, 0.5, 8), CFrame.new(cx - 14, 0.45, cz - 2), STONE, "px_sand", m)
	part(
		"Weights",
		Vector3.new(0.4, 0.4, 3),
		CFrame.new(cx - 14, 1.2, cz - 2),
		IRON,
		Enum.Material.Metal,
		m
	)
	for _, dz in ipairs({ -1.3, 1.3 }) do
		local w = part(
			"Weight",
			Vector3.new(0.5, 1.6, 1.6),
			CFrame.new(cx - 14, 1.2, cz - 2 + dz) * CFrame.Angles(math.pi / 2, 0, 0),
			DARK,
			Enum.Material.Metal,
			m
		)
		w.Shape = Enum.PartType.Cylinder
		w.CFrame = CFrame.new(cx - 14, 1.2, cz - 2 + dz) * CFrame.Angles(0, 0, 0)
		w.Size = Vector3.new(1.6, 1.6, 0.5)
	end
	local signPost = part(
		"SignPost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(cx - 22, 3.5, cz - 8),
		DARK_WOOD,
		Enum.Material.Wood,
		m
	)
	local board = part(
		"SignBoard",
		Vector3.new(0.4, 2, 7),
		CFrame.new(cx - 22.6, 6, cz - 8),
		DARK_WOOD,
		"px_planks",
		m
	)
	boardText(board, Enum.NormalId.Left, "ТРЕНЕР")
	sign(signPost, "Тренер", 5)
	for _, p in ipairs({
		{ cx - 22, cz - 17 },
		{ cx + 22, cz - 17 },
		{ cx - 22, cz + 17 },
		{ cx + 22, cz + 17 },
	}) do
		local t = part(
			"Torch",
			Vector3.new(0.5, 5, 0.5),
			CFrame.new(p[1], 4.5, p[2]),
			DARK_WOOD,
			Enum.Material.Wood,
			m
		)
		local fl = part(
			"TorchFlame",
			Vector3.new(0.7, 0.9, 0.7),
			CFrame.new(p[1], 7.3, p[2]),
			Color3.fromRGB(255, 160, 60),
			Enum.Material.Neon,
			m
		)
		light(fl, Color3.fromRGB(255, 150, 70), 18, 1.2)
		particles(fl, Color3.fromRGB(255, 140, 50), 6, 0.6, 2, 0.7, 0.3)
		t.CanCollide = false
	end
end

local n = 0
for _, d in ipairs(buildings:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "[build-buildings] " .. n .. " parts"
