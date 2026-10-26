--!nocheck
-- ================================================================ farm: the farmstead (L0 x ≥ 116, the hill L1 and the mound east of x -24)
-- The red barn (BARN: x 152..200, z -36..4, walls 5 blocks, a dark stepped gable roof to y 44, a cupola with a
-- weathervane) with its big doors open to the west toward the east path end (132, 24); inside: stalls with a cow and
-- a horse, hay, a cart, a hay loft (x 184..196, y 12) with a ladder. The yard: a hay wagon, a fenced paddock
-- (x 160..204, z 12..40) with cows, a horse and sheep, troughs, a water pump, hay stacks, barrels.
-- The farmhouse (x 136..168, z 76..116, two storeys of cream clapboard, a dark roof to y 44, a porch facing west, a
-- red-brick chimney) in its fenced plot FARMHOUSE (gate at x 120..132 on the north side, reached by a lane x 120..132
-- from the east path): a vegetable garden, a washing line, flower boxes, a mailbox.
-- The hill: a dirt track z -104..-96 from the grove's track (x 4) east to the silo spur (x 148..164); the path
-- from the east stair top (x 80..104) to the MOUND STAIR, stretched to x 88..104, z -112 → -136 (12 one-stud steps,
-- y 16 → 28); the windmill on the mound (96, -168): a tapered tower (cobblestone 6×6 → stone bricks 5×5 → planks 4×4,
-- y 28..80) under a stepped dark cap to y 92, the door facing south, four white wool sails on a dark lattice (hub at
-- (96, 76, -153), Model "MillSails" tagged AmbientSpin with its pivot's Y axis along +Z, so it turns round the axle);
-- the red-brick silo at SILO (octagon 5 blocks across, y 16..64, a grey stepped dome to y 80) with a grain shed; an
-- orchard of apple trees, beehives, a pond, haystacks, fences, wild flowers; vines off the cliffs by the barn; rim trees.
local stead = folder("Farmstead")
local partsBefore = count
local TRIM = Color3.fromRGB(240, 236, 228)
local CREAM = Color3.fromRGB(238, 226, 196)
local GLASS = Color3.fromRGB(44, 54, 70)
local IRON = Color3.fromRGB(150, 150, 156)
local ROOF_TINT = Color3.fromRGB(125, 125, 135)
local LEAF_TINT = Color3.fromRGB(150, 210, 120)
local SACK = Color3.fromRGB(222, 206, 170)

-- the ground height of the 8-stud island cell holding (x, z) (the island is built from cell centres)
local function cellY(x, z)
	return groundY(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4)
end
-- true when the cells round (x, z) within r all lie at height y (keeps props off the cliff edges)
local function flatAt(x, z, r, y)
	for _, o in ipairs({ { 0, 0 }, { -r, -r }, { r, -r }, { -r, r }, { r, r }, { 0, -r }, { 0, r }, { -r, 0 }, { r, 0 } }) do
		if cellY(x + o[1], z + o[2]) ~= y then
			return false
		end
	end
	return true
end
-- footprints (x0, z0, x1, z1) the loose props keep out of: buildings, pens, my paths
local KEEP = {}
local function keep(x0, z0, x1, z1)
	table.insert(KEEP, { x0, z0, x1, z1 })
end
local function blocked(x, z, pad)
	for _, r in ipairs(KEEP) do
		if inRect(x, z, r, pad) then
			return true
		end
	end
	return false
end
-- the grove part's dirt track from the main stair top (0, 16, -82) via (-6, -102), (-20, -128) to x -24 at z ≈ -136
-- (16 wide) and the main stair corridor stay free of my solid props (rects round the track's legs)
keep(-18, -88, 18, -56)
keep(-16, -106, 8, -80)
keep(-28, -122, 2, -100)
keep(-30, -142, -8, -120)
-- a spot for a loose prop of radius r at height y: my zone, free ground, flat, not in a footprint
local function spot(x, z, r, y)
	return zoneOf(x, z) == "farmstead" and freeGround(x, z, r) and flatAt(x, z, r + 4, y) and not blocked(x, z, r)
end
-- a dirt path laid as thin plates on whatever level each cell has (equal cells along x merged)
local function dirtRect(x0, z0, x1, z1, parent, tint)
	keep(x0, z0, x1, z1)
	local cz = math.floor(z0 / 8) * 8
	while cz < z1 do
		local za, zb = math.max(z0, cz), math.min(z1, cz + 8)
		local cx = math.floor(x0 / 8) * 8
		local runA, runY = nil, nil
		while true do
			local xe = math.min(x1, math.max(x0, cx))
			local y = if cx < x1 then cellY(cx + 4, cz + 4) else nil
			if y ~= runY then
				if runA and xe > runA then
					decor(box("Path", runA, runY, za, xe, runY + 0.12, zb, "px_dirt", tint or PATH_DIRT, parent))
				end
				runA, runY = xe, y
			end
			if cx >= x1 then
				break
			end
			cx += 8
		end
		cz += 8
	end
end
-- a flat decor plate on a building face: face N/S (plane = z, a = x) or W/E (plane = x, a = z), `out` studs proud
local function fp(name, face, a0, y0, a1, y1, plane, out, variant, tint, parent)
	if face == "N" then
		return decor(box(name, a0, y0, plane - out, a1, y1, plane, variant, tint, parent))
	elseif face == "S" then
		return decor(box(name, a0, y0, plane, a1, y1, plane + out, variant, tint, parent))
	elseif face == "W" then
		return decor(box(name, plane - out, y0, a0, plane, y1, a1, variant, tint, parent))
	end
	return decor(box(name, plane, y0, a0, plane + out, y1, a1, variant, tint, parent))
end
-- a window: a frame, dark glass and a cross of glazing bars (a, yc = the centre on the face)
local function window(face, a, yc, w, h, plane, parent, frameVariant, frameTint)
	local fv, ft = frameVariant or "px_white_wool", frameTint or TRIM
	fp("WindowFrame", face, a - w / 2 - 0.6, yc - h / 2 - 0.6, a + w / 2 + 0.6, yc + h / 2 + 0.6, plane, 0.25, fv, ft, parent)
	fp("WindowGlass", face, a - w / 2, yc - h / 2, a + w / 2, yc + h / 2, plane, 0.35, nil, GLASS, parent)
	fp("WindowBar", face, a - 0.3, yc - h / 2, a + 0.3, yc + h / 2, plane, 0.45, fv, ft, parent)
	fp("WindowBar", face, a - w / 2, yc - 0.3, a + w / 2, yc + 0.3, plane, 0.45, fv, ft, parent)
end
local function hayBale(x, y, z, parent)
	return cube("HayBale", x, y + 2, z, B, B, B, "px_hay", nil, parent)
end
-- a stepped haystack (3×3, 2×2, 1 block) standing on y
local function haystack(x, z, y, parent)
	local f = folder("Haystack", parent)
	box("Haystack", x - 6, y, z - 6, x + 6, y + 4, z + 6, "px_hay", nil, f)
	box("Haystack", x - 4, y + 4, z - 4, x + 4, y + 8, z + 4, "px_hay", nil, f)
	box("Haystack", x - 2, y + 8, z - 2, x + 2, y + 12, z + 2, "px_hay", nil, f)
end
-- a flour/grain sack standing on cf (its bottom centre)
local function sack(cf, parent)
	local p = textured(part("Sack", Vector3.new(2.6, 3, 2.6), cf * CFrame.new(0, 1.5, 0), nil, nil, parent), "px_white_wool", SACK)
	textured(decor(part("SackTie", Vector3.new(1, 0.6, 1), cf * CFrame.new(0, 3.3, 0), nil, nil, parent)), "px_brown_wool")
	return p
end
-- a blocky farm animal looking along +Z of its yaw: "Cow", "Horse" or "Sheep"
local function animal(kind, x, y, z, yaw, parent)
	local f = folder(kind, parent)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function blk(name, sx, sy, sz, ox, oy, oz, tint, solid)
		local p = textured(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), nil, nil, f), "px_white_wool", tint)
		if not solid then
			decor(p)
		end
		return p
	end
	if kind == "Cow" then
		local hide, pale = Color3.fromRGB(96, 64, 44), Color3.fromRGB(235, 230, 222)
		blk("Body", 3.6, 3.2, 6, 0, 3.8, 0, hide, true)
		blk("Patch", 3.7, 1.8, 2.2, 0, 4.1, -0.9, pale)
		blk("Patch", 3.7, 1.4, 1.4, 0, 3.4, 1.6, pale)
		for _, l in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			blk("Leg", 1.2, 2.2, 1.2, l[1] * 1.1, 1.1, l[2] * 2.2, hide)
		end
		blk("Head", 2.6, 2.6, 2.2, 0, 5, 3.9, hide, true)
		blk("Snout", 1.8, 1.2, 0.5, 0, 4.3, 5.2, Color3.fromRGB(222, 166, 152))
		blk("Horn", 0.5, 0.8, 0.5, -1.4, 6.6, 3.9, pale)
		blk("Horn", 0.5, 0.8, 0.5, 1.4, 6.6, 3.9, pale)
	elseif kind == "Horse" then
		local coat, mane = Color3.fromRGB(128, 84, 50), Color3.fromRGB(50, 36, 28)
		blk("Body", 3, 3.2, 6.4, 0, 4.6, 0, coat, true)
		for _, l in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			blk("Leg", 1, 3, 1, l[1] * 0.9, 1.5, l[2] * 2.4, coat)
		end
		blk("Neck", 1.6, 3.4, 1.8, 0, 6.9, 3, coat, true)
		blk("Head", 1.6, 1.6, 3, 0, 8.4, 4.4, coat, true)
		blk("Mane", 0.5, 3.8, 1.2, 0, 7.4, 2.2, mane)
		blk("Tail", 0.8, 3, 0.8, 0, 4.2, -3.5, mane)
		blk("Saddle", 3.1, 0.6, 2.4, 0, 6.3, -0.2, Color3.fromRGB(90, 50, 30))
	else
		local wool, face = Color3.fromRGB(238, 236, 230), Color3.fromRGB(112, 102, 96)
		blk("Body", 3.2, 3, 4.6, 0, 3, 0, wool, true)
		for _, l in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			blk("Leg", 0.9, 1.6, 0.9, l[1] * 0.9, 0.8, l[2] * 1.5, face)
		end
		blk("Head", 1.8, 1.8, 1.8, 0, 3.9, 2.8, face, true)
		blk("WoolCap", 1.9, 0.7, 1.3, 0, 4.85, 2.6, wool)
	end
	return f
end
-- a hand cart with square wheels (block style) and a load: "hay", "sacks" or "pumpkins"
local function cart(x, y, z, yaw, parent, load)
	local f = folder("Cart", parent)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	textured(part("CartBed", Vector3.new(5, 0.8, 7), cf * CFrame.new(0, 2.8, 0), nil, nil, f), "px_spruce_planks")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("CartSide", Vector3.new(0.6, 1.4, 7), cf * CFrame.new(s * 2.2, 3.9, 0), nil, nil, f), "px_spruce_planks")
		textured(decor(part("CartWheel", Vector3.new(0.8, 3.2, 3.2), cf * CFrame.new(s * 2.9, 1.6, -0.8), nil, nil, f)), "px_dark_oak_planks")
		textured(decor(part("CartHandle", Vector3.new(0.5, 0.5, 4), cf * CFrame.new(s * 1.8, 2.7, 5.4), nil, nil, f)), "px_dark_oak_planks")
	end
	decor(part("CartAxle", Vector3.new(5.4, 0.5, 0.5), cf * CFrame.new(0, 1.6, -0.8), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, f))
	if load == "hay" then
		textured(part("CartHay", Vector3.new(4, 3, 6), cf * CFrame.new(0, 4.7, 0), nil, nil, f), "px_hay")
	elseif load == "sacks" then
		sack(cf * CFrame.new(-1.1, 3.2, -1.6), f)
		sack(cf * CFrame.new(1.1, 3.2, -1.2), f)
		sack(cf * CFrame.new(0, 3.2, 1.6), f)
	elseif load == "pumpkins" then
		for _, o in ipairs({ { -1.1, -1.7 }, { 1.1, -1.7 }, { 0, 1.5 } }) do
			textured(part("Pumpkin", Vector3.new(2.6, 2.4, 2.6), cf * CFrame.new(o[1], 4.4, o[2]), nil, nil, f), "px_white_wool", PUMPKIN)
		end
	end
	return f
end
-- a wild flower (a stem and a block head)
local function flower(x, y, z, color, parent)
	decor(part("FlowerStem", Vector3.new(0.4, 1.4, 0.4), at(x, y + 0.7, z), Color3.fromRGB(70, 130, 50), Enum.Material.SmoothPlastic, parent))
	textured(decor(part("Flower", Vector3.new(1, 1, 1), at(x, y + 1.9, z), nil, nil, parent)), "px_white_wool", color)
end
local FLOWER_COLORS = {
	Color3.fromRGB(250, 220, 60),
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(110, 140, 240),
	Color3.fromRGB(250, 250, 245),
	Color3.fromRGB(240, 130, 200),
}

-- ================================================================ the red barn
do
	local f = folder("Barn", stead)
	local X0, X1, Z0, Z1, H = 152, 200, -36, 4, 20
	local CZ = (Z0 + Z1) / 2 -- -16
	local RED = BARN_RED
	keep(X0 - 10, Z0 - 6, X1 + 6, Z1 + 6)
	-- the walls (one block thick), the west gable wall with the 4×4-block doorway
	box("BarnWall", X0, 0, Z0, X1, H, Z0 + B, "px_planks", RED, f)
	box("BarnWall", X0, 0, Z1 - B, X1, H, Z1, "px_planks", RED, f)
	box("BarnWall", X1 - B, 0, Z0 + B, X1, H, Z1 - B, "px_planks", RED, f)
	box("BarnWall", X0, 0, Z0 + B, X0 + B, H, CZ - 8, "px_planks", RED, f)
	box("BarnWall", X0, 0, CZ + 8, X0 + B, H, Z1 - B, "px_planks", RED, f)
	box("BarnLintel", X0, 16, CZ - 8, X0 + B, H, CZ + 8, "px_planks", RED, f)
	decor(box("BarnFloor", X0 + B, 0, Z0 + B, X1 - B, 0.15, Z1 - B, "px_spruce_planks", nil, f))
	-- the white trim: corner posts, an eave band, the doorway frame
	for _, c in ipairs({ { X0, Z0 }, { X1 - B, Z0 }, { X0, Z1 - B }, { X1 - B, Z1 - B } }) do
		decor(box("BarnTrim", c[1] - 0.35, 0, c[2] - 0.35, c[1] + B + 0.35, H, c[2] + B + 0.35, "px_white_wool", TRIM, f))
	end
	fp("BarnTrim", "N", X0, H - 1.2, X1, H, Z0, 0.25, "px_white_wool", TRIM, f)
	fp("BarnTrim", "S", X0, H - 1.2, X1, H, Z1, 0.25, "px_white_wool", TRIM, f)
	fp("BarnTrim", "E", Z0, H - 1.2, Z1, H, X1, 0.25, "px_white_wool", TRIM, f)
	fp("BarnTrim", "W", Z0, H - 1.2, Z1, H, X0, 0.25, "px_white_wool", TRIM, f)
	fp("DoorFrame", "W", CZ - 9.2, 0, CZ - 8, 17.2, X0, 0.3, "px_white_wool", TRIM, f)
	fp("DoorFrame", "W", CZ + 8, 0, CZ + 9.2, 17.2, X0, 0.3, "px_white_wool", TRIM, f)
	fp("DoorFrame", "W", CZ - 9.2, 16, CZ + 9.2, 17.2, X0, 0.3, "px_white_wool", TRIM, f)
	-- the big double doors swung open (perpendicular to the wall), red with a white frame and the white X
	for _, s in ipairs({ -1, 1 }) do
		local p = CZ + s * 8.6
		box("BarnDoor", X0 - 8, 0.4, p - 0.3, X0, 16, p + 0.3, "px_planks", RED, f)
		decor(box("DoorTrim", X0 - 8, 15, p - 0.5, X0, 16, p + 0.5, "px_white_wool", TRIM, f))
		decor(box("DoorTrim", X0 - 8, 0.4, p - 0.5, X0, 1.4, p + 0.5, "px_white_wool", TRIM, f))
		decor(box("DoorTrim", X0 - 8, 0.4, p - 0.5, X0 - 7, 16, p + 0.5, "px_white_wool", TRIM, f))
		decor(box("DoorTrim", X0 - 1, 0.4, p - 0.5, X0, 16, p + 0.5, "px_white_wool", TRIM, f))
		for _, d in ipairs({ { X0 - 7, 1.4, X0 - 1, 15 }, { X0 - 7, 15, X0 - 1, 1.4 } }) do
			local bar = decor(beam("DoorX", V(d[1], d[2], p), V(d[3], d[4], p), 0.9, TRIM, f))
			textured(bar, "px_white_wool", TRIM)
		end
	end
	-- windows on the long walls and the east gable
	for _, x in ipairs({ 164, 176, 188 }) do
		window("N", x, 10, 4, 4, Z0, f)
		window("S", x, 10, 4, 4, Z1, f)
	end
	window("E", CZ, 10, 4, 4, X1, f)
	-- the dark stepped gable roof: per layer red gable infill and two dark skins overhanging one block
	for i = 0, 5 do
		local y0, hw = H + 4 * i, 24 - 4 * i
		local w = hw - 4
		if w > 0 then
			box("BarnGable", X0, y0, CZ - w, X1, y0 + 4, CZ + w, "px_planks", RED, f)
			box("BarnRoof", X0 - 4, y0, CZ - hw, X1 + 4, y0 + 4, CZ - w, "px_dark_oak_planks", nil, f)
			box("BarnRoof", X0 - 4, y0, CZ + w, X1 + 4, y0 + 4, CZ + hw, "px_dark_oak_planks", nil, f)
			if i >= 1 then
				for _, g in ipairs({ { "W", X0 }, { "E", X1 } }) do
					fp("GableTrim", g[1], CZ - w, y0, CZ - w + 1, y0 + 4, g[2], 0.3, "px_white_wool", TRIM, f)
					fp("GableTrim", g[1], CZ + w - 1, y0, CZ + w, y0 + 4, g[2], 0.3, "px_white_wool", TRIM, f)
				end
			end
		else
			box("BarnRidge", X0 - 4, y0, CZ - hw, X1 + 4, y0 + 4, CZ + hw, "px_dark_oak_planks", nil, f)
		end
	end
	-- the hay loft door in the west gable and the hay hook over it
	fp("LoftDoor", "W", CZ - 4.6, 21.4, CZ + 4.6, 30.6, X0, 0.25, "px_white_wool", TRIM, f)
	fp("LoftDoor", "W", CZ - 4, 22, CZ + 4, 30, X0, 0.35, nil, Color3.fromRGB(34, 24, 18), f)
	textured(box("HayHook", X0 - 6, 32.4, CZ - 0.6, X0, 33.6, CZ + 0.6, nil, nil, f), "px_dark_oak_planks")
	decor(part("HookRope", Vector3.new(0.3, 4, 0.3), at(X0 - 5.4, 30.4, CZ), Color3.fromRGB(120, 100, 70), Enum.Material.Fabric, f))
	decor(part("Hook", Vector3.new(1, 1, 0.4), at(X0 - 5.4, 28, CZ), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, f))
	textured(decor(part("HookBale", Vector3.new(3, 3, 3), at(X0 - 5.4, 25.8, CZ), nil, nil, f)), "px_hay")
	-- the cupola on the ridge with a weathervane
	do
		local cx = (X0 + X1) / 2
		box("Cupola", cx - 4, 44, CZ - 4, cx + 4, 51, CZ + 4, "px_white_wool", TRIM, f)
		for _, face in ipairs({ { "N", CZ - 4 }, { "S", CZ + 4 } }) do
			fp("Louvre", face[1], cx - 2.4, 45.6, cx + 2.4, 49.6, face[2], 0.25, nil, Color3.fromRGB(40, 30, 24), f)
		end
		for _, face in ipairs({ { "W", cx - 4 }, { "E", cx + 4 } }) do
			fp("Louvre", face[1], CZ - 2.4, 45.6, CZ + 2.4, 49.6, face[2], 0.25, nil, Color3.fromRGB(40, 30, 24), f)
		end
		box("CupolaRoof", cx - 6, 51, CZ - 6, cx + 6, 53, CZ + 6, "px_dark_oak_planks", nil, f)
		box("CupolaRoof", cx - 4, 53, CZ - 4, cx + 4, 55, CZ + 4, "px_dark_oak_planks", nil, f)
		box("CupolaRoof", cx - 2, 55, CZ - 2, cx + 2, 57, CZ + 2, "px_dark_oak_planks", nil, f)
		local metal, dark = Color3.fromRGB(60, 60, 66), Color3.fromRGB(30, 30, 34)
		decor(part("VanePole", Vector3.new(0.5, 9, 0.5), at(cx, 61.5, CZ), metal, Enum.Material.Metal, f))
		decor(part("VaneArm", Vector3.new(8, 0.5, 0.5), at(cx, 63.6, CZ), metal, Enum.Material.Metal, f))
		decor(part("VaneArm", Vector3.new(0.5, 0.5, 4), at(cx, 62.4, CZ), metal, Enum.Material.Metal, f))
		decor(part("VaneTip", Vector3.new(1.4, 1.4, 0.4), at(cx - 4.4, 63.6, CZ), metal, Enum.Material.Metal, f))
		decor(part("VaneFin", Vector3.new(1.6, 2, 0.3), at(cx + 4, 63.8, CZ), metal, Enum.Material.Metal, f))
		decor(part("Rooster", Vector3.new(2.6, 2.2, 0.4), at(cx, 66.2, CZ), dark, Enum.Material.Metal, f))
		decor(part("RoosterTail", Vector3.new(1, 1.6, 0.4), at(cx + 1.6, 67, CZ), dark, Enum.Material.Metal, f))
		decor(part("RoosterComb", Vector3.new(0.8, 0.8, 0.45), at(cx - 1, 67.6, CZ), Color3.fromRGB(180, 40, 30), Enum.Material.SmoothPlastic, f))
	end
	-- a lantern by the doorway
	decor(box("LampBracket", X0 - 2, 15, CZ - 11.4, X0, 15.6, CZ - 10.8, "px_dark_oak_planks", nil, f))
	lantern(V(X0 - 1.6, 13.4, CZ - 11.1), f, false, BY + 15)
	task.wait()

	-- inside: stalls along both long walls, the loft at the east end, hay, a cart, lanterns
	local inside = folder("BarnInside", f)
	for _, x in ipairs({ 160, 168, 176, 184 }) do
		box("StallWall", x - 0.5, 0, Z0 + B, x + 0.5, 6, Z0 + 12, "px_spruce_planks", nil, inside)
		box("StallWall", x - 0.5, 0, Z1 - 12, x + 0.5, 6, Z1 - B, "px_spruce_planks", nil, inside)
	end
	for _, x in ipairs({ 164, 172, 180 }) do
		decor(box("StallHay", x - 3.5, 0.15, Z0 + B, x + 3.5, 0.4, Z0 + 12, "px_hay", nil, inside))
		decor(box("StallHay", x - 3.5, 0.15, Z1 - 12, x + 3.5, 0.4, Z1 - B, "px_hay", nil, inside))
	end
	animal("Cow", 164, 0.15, Z0 + 8, 0, inside)
	animal("Horse", 172, 0.15, Z1 - 8, math.pi, inside)
	hayBale(180, 0.15, Z0 + 6, inside)
	hayBale(180, 0.15, Z0 + 10, inside)
	hayBale(180, 4.15, Z0 + 6, inside)
	textured(box("Trough", 162, 0.15, Z1 - 6, 166, 2, Z1 - B, "px_spruce_planks", nil, inside), "px_spruce_planks")
	barrel(180, 0.15, Z1 - 7, inside)
	crate(158, 0.15, Z0 + 7, inside)
	barrel(158, 0.15, Z1 - 7, inside, "px_hay")
	-- the hay loft over the east end, two posts, a ladder up its west edge (a climbable truss behind the picture)
	box("LoftFloor", 184, 11, Z0 + B, X1 - B, 12, Z1 - B, "px_spruce_planks", nil, inside)
	for _, z in ipairs({ CZ - 8, CZ + 8 }) do
		box("LoftPost", 184.2, 0, z - 0.6, 185.4, 11, z + 0.6, "px_dark_oak_planks", nil, inside)
	end
	for _, b in ipairs({ { 188, Z0 + 6 }, { 192, Z0 + 6 }, { 188, Z0 + 10 }, { 192, Z1 - 6 }, { 192, Z1 - 10 } }) do
		hayBale(b[1], 12, b[2], inside)
	end
	hayBale(192, 16, Z0 + 6, inside)
	do
		local truss = Instance.new("TrussPart")
		truss.Name = "LoftLadder"
		truss.Size = Vector3.new(2, 12, 2)
		truss.CFrame = at(183, 6, CZ)
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = inside
		local plate = decor(part("LoftLadderFace", Vector3.new(0.2, 12, 4), at(181.9, 6, CZ), nil, nil, inside))
		plate.Transparency = 1
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
	cart(190, 0.15, CZ, math.pi / 2, inside, "hay")
	-- a second ladder leaning on the north wall (picture only)
	textured(decor(part("LeaningLadder", Vector3.new(3, 10, 0.4), at(170, 5, Z0 + B + 0.8) * CFrame.Angles(-0.12, 0, 0), nil, nil, inside)), "px_spruce_planks")
	lantern(V(166, 15.5, CZ), inside, false, BY + H)
	lantern(V(178, 15.5, CZ), inside, false, BY + H)
end
task.wait()

-- ================================================================ the barn yard: wagon, paddock with animals, troughs, pump, hay, barrels
do
	local f = folder("BarnYard", stead)
	-- the apron from the east path end to the barn doors
	dirtRect(132, -24, 148, 32, f)
	-- the hay wagon (along x) in the north-west corner of the yard
	do
		local w = folder("HayWagon", f)
		box("WagonBed", 134, 3, -44, 150, 4, -36, "px_spruce_planks", nil, w)
		box("WagonSide", 134, 4, -44, 150, 5.4, -43.4, "px_spruce_planks", nil, w)
		box("WagonSide", 134, 4, -36.6, 150, 5.4, -36, "px_spruce_planks", nil, w)
		for _, x in ipairs({ 137, 147 }) do
			for _, z in ipairs({ -44.6, -35.4 }) do
				decor(box("WagonWheel", x - 1.8, 0, z - 0.5, x + 1.8, 3.6, z + 0.5, "px_dark_oak_planks", nil, w))
			end
			decor(part("WagonAxle", Vector3.new(0.6, 0.6, 9.6), at(x, 1.8, -40), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, w))
		end
		for _, z in ipairs({ -42, -38 }) do
			textured(decor(beam("WagonShaft", V(134, 3, z), V(127, 2, z), 0.6, nil, w)), "px_dark_oak_planks")
		end
		for _, b in ipairs({ { 137, -42 }, { 137, -38 }, { 141, -42 }, { 141, -38 }, { 145, -40 } }) do
			hayBale(b[1], 4, b[2], w)
		end
		hayBale(139, 8, -40, w)
	end
	-- the paddock south of the barn: fence with a gate gap on the west, animals, a trough, hay
	do
		local p = folder("Paddock", f)
		keep(158, 10, 206, 42)
		fence(160, 12, 204, 12, p)
		fence(204, 12, 204, 40, p)
		fence(160, 40, 204, 40, p)
		fence(160, 12, 160, 22, p)
		fence(160, 30, 160, 40, p)
		animal("Cow", 176, 0, 26, math.pi * 0.6, p)
		animal("Cow", 190, 0, 32, -math.pi * 0.3, p)
		animal("Horse", 184, 0, 20, math.pi / 2, p)
		animal("Sheep", 170, 0, 34, math.pi, p)
		animal("Sheep", 196, 0, 22, -math.pi / 2, p)
		box("Trough", 168, 0, 14, 180, 2.4, 17.2, "px_spruce_planks", nil, p)
		decor(box("TroughWater", 168.5, 2.4, 14.5, 179.5, 2.5, 16.7, "px_water", nil, p))
		hayBale(200, 0, 36, p)
		hayBale(196, 0, 36, p)
		hayBale(200, 4, 36, p)
		decor(box("PaddockHay", 194, 0, 14, 202, 0.2, 20, "px_hay", nil, p))
	end
	-- the water pump and a trough at the yard's south edge, barrels and crates
	do
		local metal = Color3.fromRGB(70, 74, 80)
		box("PumpBase", 142, 0, 34, 146, 1, 38, "px_cobblestone", nil, f)
		part("Pump", Vector3.new(1.6, 5, 1.6), at(144, 3.5, 36), metal, Enum.Material.Metal, f)
		decor(part("PumpSpout", Vector3.new(0.6, 0.6, 2), at(144, 4.6, 37.6), metal, Enum.Material.Metal, f))
		decor(part("PumpHandle", Vector3.new(0.4, 0.4, 3.2), at(144, 6.2, 34.2) * CFrame.Angles(0.5, 0, 0), metal, Enum.Material.Metal, f))
		box("Trough", 140, 0, 38.2, 152, 2.4, 41.4, "px_spruce_planks", nil, f)
		decor(box("TroughWater", 140.5, 2.4, 38.7, 151.5, 2.5, 40.9, "px_water", nil, f))
		barrel(136, 0, 36, f)
		barrel(136, 0, 40, f, "px_hay")
		for _, x in ipairs({ 160, 164, 172 }) do
			barrel(x, 0, -42, f)
		end
		crate(168, 0, -42, f)
		crate(168, 4, -42, f, 3)
		-- hay stacks: by the north-east corner and against the east wall
		for _, b in ipairs({ { 192, -44, 0 }, { 196, -44, 0 }, { 200, -44, 0 }, { 194, -44, 4 }, { 198, -44, 4 }, { 196, -44, 8 } }) do
			hayBale(b[1], b[3], b[2], f)
		end
		hayBale(204, 0, -24, f)
		hayBale(204, 0, -20, f)
		hayBale(204, 4, -22, f)
		zoneSign(130, 12, "Амбар", math.pi / 2, f)
	end
end
task.wait()

-- ================================================================ the farmhouse in its fenced plot
do
	local f = folder("Farmhouse", stead)
	local X0, X1, Z0, Z1 = 136, 168, 76, 116
	local CX = (X0 + X1) / 2 -- 152
	local DARK = "px_dark_oak_planks"
	keep(FARMHOUSE[1] - 2, FARMHOUSE[2] - 2, FARMHOUSE[3] + 2, FARMHOUSE[4] + 2)
	-- the lane from the east path to the gate, the path inside to the porch
	dirtRect(120, 32, 132, 64, f)
	dirtRect(120, 64, 128, 100, f)
	-- the house: a cream clapboard block of two storeys on a cobblestone footing, dark corner posts and floor band
	box("HouseWalls", X0, 0, Z0, X1, 24, Z1, "px_white_wool", CREAM, f)
	box("HouseFooting", X0 - 0.4, 0, Z0 - 0.4, X1 + 0.4, 1.6, Z1 + 0.4, "px_cobblestone", nil, f)
	decor(box("FloorBand", X0 - 0.3, 11.4, Z0 - 0.3, X1 + 0.3, 12.6, Z1 + 0.3, DARK, nil, f))
	for _, c in ipairs({ { X0, Z0 }, { X1, Z0 }, { X0, Z1 }, { X1, Z1 } }) do
		decor(box("HousePost", c[1] - 0.6, 1.6, c[2] - 0.6, c[1] + 0.6, 24, c[2] + 0.6, DARK, nil, f))
	end
	-- the roof: ridge north-south, stepped dark tiles overhanging one block, cream gables north and south
	for i = 0, 4 do
		local y0, hw = 24 + 4 * i, 20 - 4 * i
		local w = hw - 4
		if w > 0 then
			box("HouseGable", CX - w, y0, Z0, CX + w, y0 + 4, Z1, "px_white_wool", CREAM, f)
			box("HouseRoof", CX - hw, y0, Z0 - 4, CX - w, y0 + 4, Z1 + 4, "px_roof_tiles", ROOF_TINT, f)
			box("HouseRoof", CX + w, y0, Z0 - 4, CX + hw, y0 + 4, Z1 + 4, "px_roof_tiles", ROOF_TINT, f)
		else
			box("HouseRidge", CX - hw, y0, Z0 - 4, CX + hw, y0 + 4, Z1 + 4, "px_roof_tiles", ROOF_TINT, f)
		end
	end
	-- windows (dark frames), the door, flower boxes
	for _, z in ipairs({ 84, 108 }) do
		window("W", z, 6, 4, 4, X0, f, DARK)
	end
	for _, z in ipairs({ 84, 96, 108 }) do
		window("W", z, 18, 4, 4, X0, f, DARK)
	end
	for _, y in ipairs({ 6, 18 }) do
		window("N", 144, y, 4, 4, Z0, f, DARK)
		window("N", 160, y, 4, 4, Z0, f, DARK)
		window("S", 144, y, 4, 4, Z1, f, DARK)
		window("E", 88, y, 4, 4, X1, f, DARK)
		window("E", 104, y, 4, 4, X1, f, DARK)
	end
	window("N", CX, 30, 3, 3, Z0, f, DARK)
	window("S", CX - 6, 30, 3, 3, Z1, f, DARK)
	fp("DoorFrame", "W", 93.4, 1, 98.6, 9.8, X0, 0.25, DARK, nil, f)
	fp("Door", "W", 94, 1, 98, 9.2, X0, 0.4, "px_spruce_planks", nil, f)
	fp("DoorKnob", "W", 94.6, 4.6, 95.2, 5.2, X0, 0.6, nil, Color3.fromRGB(200, 170, 60), f)
	for _, b in ipairs({ { 84, 2.4 }, { 108, 2.4 }, { 84, 14.4 }, { 96, 14.4 }, { 108, 14.4 } }) do
		local z, y = b[1], b[2]
		fp("FlowerBox", "W", z - 2.6, y, z + 2.6, y + 1.4, X0, 1.4, "px_spruce_planks", nil, f)
		for k = -1, 1 do
			textured(decor(part("BoxFlower", Vector3.new(1, 1, 1), at(X0 - 0.7, y + 1.9, z + k * 1.6), nil, nil, f)), "px_white_wool", FLOWER_COLORS[(k + 2 + math.floor(z / 12)) % #FLOWER_COLORS + 1])
		end
	end
	-- the porch facing west: a plank deck, posts, a railing with a gap at the steps, a stepped roof, a lantern
	box("PorchDeck", 128, 0, 80, X0, 1, 112, "px_spruce_planks", nil, f)
	box("PorchStep", 126, 0, 92, 128, 0.5, 100, "px_spruce_planks", nil, f)
	for _, z in ipairs({ 80.6, 92, 100, 111.4 }) do
		box("PorchPost", 128, 1, z - 0.6, 129.2, 12, z + 0.6, DARK, nil, f)
	end
	fence(128.6, 81, 128.6, 92, f, 1, DARK)
	fence(128.6, 100, 128.6, 111, f, 1, DARK)
	box("PorchRoof", 126, 12, 78, 132, 13, 114, "px_roof_tiles", ROOF_TINT, f)
	box("PorchRoof", 132, 12, 78, X0, 14, 114, "px_roof_tiles", ROOF_TINT, f)
	box("PorchBench", 131, 1, 102, 133.4, 3, 109, "px_spruce_planks", nil, f)
	box("PorchBench", 133.4, 1, 102, 134.4, 5.4, 109, "px_spruce_planks", nil, f)
	lantern(V(130.4, 9.6, 96), f, false, BY + 12)
	-- the red-brick chimney on the south gable with a little smoke
	box("Chimney", 156, 0, Z1, 164, 36, Z1 + 4, "px_red_brick", nil, f)
	box("Chimney", 157, 36, Z1 + 0.4, 163, 48, Z1 + 3.6, "px_red_brick", nil, f)
	box("ChimneyCap", 156.4, 48, Z1, 163.6, 49.4, Z1 + 4, "px_stone_bricks", nil, f)
	do
		local smoke = decor(part("Smoke", Vector3.new(3, 0.5, 2), at(160, 49.8, Z1 + 2), nil, nil, f))
		smoke.Transparency = 1
		emitter(smoke, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
			Size = NumberSequence.new(1.5, 4),
			Transparency = NumberSequence.new(0.45, 1),
			Lifetime = NumberRange.new(4, 6),
			Rate = 2,
			Speed = NumberRange.new(1.5, 2.5),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
		})
	end
	-- a woodpile against the north wall
	box("Woodpile", 147.4, 0, Z0 - 3.4, 156.6, 4, Z0 - 0.4, "px_oak_log", nil, f)
	box("Woodpile", 149, 4, Z0 - 3.4, 155, 6, Z0 - 0.4, "px_oak_log", nil, f)
	task.wait()

	-- the vegetable garden east of the house: three beds in a low fence
	do
		local g = folder("Garden", f)
		fence(174, 74, 194, 74, g)
		fence(194, 74, 194, 126, g)
		fence(174, 126, 194, 126, g)
		fence(174, 74, 174, 96, g)
		fence(174, 104, 174, 126, g)
		for r, x in ipairs({ 178, 184, 190 }) do
			decor(box("GardenBed", x - 2, 0, 78, x + 2, 0.2, 122, "px_dirt", FARMLAND, g))
			for z = 80, 120, 4 do
				if r == 1 then
					textured(decor(part("Cabbage", Vector3.new(2.4, 2, 2.4), at(x, 1.2, z), nil, nil, g)), "px_hedge", LEAF_TINT)
				elseif r == 2 then
					textured(decor(part("CarrotTops", Vector3.new(1.6, 1.4, 1.6), at(x, 0.9, z), nil, nil, g)), "px_hedge")
					textured(decor(part("Carrot", Vector3.new(1, 0.4, 1), at(x, 0.35, z), nil, nil, g)), "px_white_wool", PUMPKIN)
				elseif z % 8 == 0 then
					textured(part("Pumpkin", Vector3.new(3, 2.6, 3), at(x, 1.5, z), nil, nil, g), "px_white_wool", PUMPKIN)
				else
					textured(decor(part("PumpkinLeaves", Vector3.new(2.6, 0.8, 2.6), at(x, 0.6, z), nil, nil, g)), "px_hedge")
				end
			end
		end
	end
	-- the washing line south of the house
	do
		local w = folder("WashingLine", f)
		for _, x in ipairs({ 140, 168 }) do
			box("LinePost", x - 0.5, 0, 124.5, x + 0.5, 9, 125.5, DARK, nil, w)
			box("LineBar", x - 0.5, 8.4, 123, x + 0.5, 9, 127, DARK, nil, w)
		end
		decor(beam("Line", V(140, 8.6, 125), V(168, 8.6, 125), 0.15, Color3.fromRGB(230, 230, 230), w, Enum.Material.Fabric))
		local clothes = {
			Color3.fromRGB(250, 250, 245),
			Color3.fromRGB(90, 130, 200),
			Color3.fromRGB(200, 60, 50),
			Color3.fromRGB(240, 210, 80),
			Color3.fromRGB(250, 250, 245),
		}
		for i, c in ipairs(clothes) do
			local h = if i % 2 == 0 then 3.6 else 2.6
			textured(decor(part("Laundry", Vector3.new(3, h, 0.2), at(140 + i * 4.7, 8.5 - h / 2, 125), nil, nil, w)), "px_white_wool", c)
		end
	end
	-- the plot fence with the gate arch at x 120..132 on the north side, the mailbox by it
	do
		local p = folder("PlotFence", f)
		fence(132, 64, 196, 64, p)
		fence(196, 64, 196, 132, p)
		fence(120, 132, 196, 132, p)
		fence(120, 64, 120, 132, p)
		for _, x in ipairs({ 120, 132 }) do
			box("GatePost", x - 0.8, 0, 63.2, x + 0.8, 9, 64.8, "px_oak_log", nil, p)
		end
		box("GateBeam", 119, 9, 63.4, 133, 10.2, 64.6, DARK, nil, p)
		local board = textured(part("GateSign", Vector3.new(8, 2, 0.4), at(126, 7.6, 64), nil, nil, p), "px_spruce_planks")
		boardText(board, "Усадьба")
		decor(part("SignChain", Vector3.new(0.2, 0.6, 0.2), at(123, 8.8, 64), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, p))
		decor(part("SignChain", Vector3.new(0.2, 0.6, 0.2), at(129, 8.8, 64), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, p))
		box("MailPost", 134.6, 0, 59.6, 135.4, 3.6, 60.4, DARK, nil, p)
		part("Mailbox", Vector3.new(1.6, 1.4, 2.6), at(135, 4.3, 60), Color3.fromRGB(60, 90, 140), Enum.Material.Metal, p)
		decor(part("MailFlag", Vector3.new(0.2, 1, 0.6), at(135.9, 5, 60.6), Color3.fromRGB(200, 40, 30), Enum.Material.SmoothPlastic, p))
	end
end
task.wait()

-- ================================================================ the hill: the track, the east-stair path, the mound stair
do
	local f = folder("HillPaths", stead)
	dirtRect(4, -104, 168, -96, f) -- the track east along the hill (joins the grove's track from the main stair top)
	dirtRect(80, -96, 104, -88, f) -- from the east stair top
	dirtRect(88, -112, 104, -104, f) -- to the mound stair
	dirtRect(148, -136, 164, -104, f) -- the silo spur
	dirtRect(92, -156, 100, -136, f) -- on the mound, to the windmill door
	-- the mound stair, stretched south to z -112 so the 12-stud rise is 12 one-stud steps (2-stud treads)
	local S = STAIRS.mound
	local zBot, zTop = -112, -136
	keep(S.x0 - 10, zTop, S.x1 + 10, zBot + 2)
	stairs("MoundStair", (S.x0 + S.x1) / 2, zBot, zTop, L1_Y, MOUND_Y - L1_Y, S.x1 - S.x0, "px_stone_bricks", f)
	for k = 0, 11 do
		local top = L1_Y + k + 1
		local za, zb = zBot - 2 * k, zBot - 2 * (k + 1)
		if top - B > L1_Y then
			box("StairFill", S.x0, L1_Y, zb, S.x1, top - B, za, "px_stone_bricks", nil, f)
		end
		box("StairCheek", S.x0 - 2, L1_Y, zb, S.x0, top + 2, za, "px_cobblestone", nil, f)
		box("StairCheek", S.x1, L1_Y, zb, S.x1 + 2, top + 2, za, "px_cobblestone", nil, f)
	end
	-- lamp posts along the track (north side, the lantern over the track)
	for _, x in ipairs({ 36, 120 }) do
		lampPost(x, -106.5, f, false, math.pi, L1_Y)
	end
	lampPost(108, -130, f, false, math.pi / 2, L1_Y)
end
task.wait()

-- ================================================================ the windmill on the mound (hero)
do
	local f = folder("Windmill", stead)
	local MX, MZ, Y = MOUND.x, MOUND.z, MOUND_Y
	local DARK = "px_dark_oak_planks"
	keep(MX - 18, MZ - 18, MX + 18, MZ + 24)
	-- the tapered tower: cobblestone 6×6 (4 blocks), stone bricks 5×5 (4), planks 4×4 (5), a stepped dark cap
	box("MillPlinth", MX - 13, Y, MZ - 13, MX + 13, Y + 1.2, MZ + 13, "px_mossy_cobblestone", nil, f)
	box("MillBase", MX - 12, Y, MZ - 12, MX + 12, Y + 16, MZ + 12, "px_cobblestone", nil, f)
	box("MillMid", MX - 10, Y + 16, MZ - 10, MX + 10, Y + 32, MZ + 10, "px_stone_bricks", nil, f)
	decor(box("MillBand", MX - 10.4, Y + 31.6, MZ - 10.4, MX + 10.4, Y + 32.6, MZ + 10.4, DARK, nil, f))
	box("MillTop", MX - 8, Y + 32, MZ - 8, MX + 8, Y + 52, MZ + 8, "px_planks", nil, f)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		decor(box("MillFrame", MX + c[1] * 8 - 0.6, Y + 32, MZ + c[2] * 8 - 0.6, MX + c[1] * 8 + 0.6, Y + 52, MZ + c[2] * 8 + 0.6, DARK, nil, f))
	end
	decor(box("MillBand", MX - 8.4, Y + 41.6, MZ - 8.4, MX + 8.4, Y + 42.4, MZ + 8.4, DARK, nil, f))
	box("MillCap", MX - 10, Y + 52, MZ - 10, MX + 10, Y + 56, MZ + 10, DARK, nil, f)
	box("MillCap", MX - 7, Y + 56, MZ - 7, MX + 7, Y + 60, MZ + 7, DARK, nil, f)
	box("MillCap", MX - 4, Y + 60, MZ - 4, MX + 4, Y + 63, MZ + 4, DARK, nil, f)
	box("MillCap", MX - 1.5, Y + 63, MZ - 1.5, MX + 1.5, Y + 66, MZ + 1.5, DARK, nil, f)
	-- the door facing south (to the mound stair), windows, a lantern
	local S0 = MZ + 12
	fp("MillDoorFrame", "S", MX - 3, Y, MX + 3, Y + 9.4, S0, 0.25, "px_stone_bricks", nil, f)
	fp("MillDoor", "S", MX - 2.2, Y, MX + 2.2, Y + 8.6, S0, 0.4, "px_spruce_planks", nil, f)
	fp("MillStep", "S", MX - 3, Y, MX + 3, Y + 0.6, S0, 1.6, "px_stone_bricks", nil, f)
	window("S", MX, Y + 24, 3, 4, MZ + 10, f, DARK)
	window("W", MZ, Y + 24, 3, 4, MX - 10, f, DARK)
	window("E", MZ, Y + 24, 3, 4, MX + 10, f, DARK)
	window("W", MZ, Y + 46, 3, 3, MX - 8, f, DARK)
	window("E", MZ, Y + 46, 3, 3, MX + 8, f, DARK)
	window("N", MX, Y + 38, 3, 3, MZ - 8, f, DARK)
	decor(box("LampBracket", MX + 4.4, Y + 9, S0, MX + 5, Y + 9.6, S0 + 1.4, DARK, nil, f))
	lantern(V(MX + 4.7, Y + 7.4, S0 + 1.1), f, false, BY + Y + 9)
	-- flour sacks by the door and a cart of sacks
	for _, s in ipairs({ { -6, 0 }, { -8.8, 0 }, { -7.4, 3 } }) do
		sack(at(MX + s[1], Y + s[2], S0 + 1.8), f)
	end
	sack(at(MX + 7, Y, S0 + 2), f)
	cart(MX + 12, Y, S0 + 9, -math.pi * 0.35, f, "sacks")
	hayBale(MX - 14, Y, S0 + 6, f)
	-- the sails: axle, hub, four stocks with white wool panels on a dark lattice, in one Model that spins about the
	-- axle (AmbientSpin turns round the pivot's Y axis, so the pivot's Y points south along the axle)
	local HY, HZ = Y + 48, MZ + 15
	local sails = Instance.new("Model")
	sails.Name = "MillSails"
	sails.Parent = f
	textured(decor(box("MillAxle", MX - 1.2, HY - 1.2, MZ + 8, MX + 1.2, HY + 1.2, HZ, nil, nil, sails)), "px_dark_oak_log")
	textured(decor(box("MillHub", MX - 2, HY - 2, HZ - 1, MX + 2, HY + 2, HZ + 1.4, nil, nil, sails)), DARK)
	local hub = V(MX, HY, HZ)
	local CLOTH = Color3.fromRGB(246, 244, 238)
	for i = 0, 3 do
		local hcf = CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(45 + 90 * i))
		local function piece(name, size, ox, oy, oz, variant, tint)
			return textured(decor(part(name, size, hcf * CFrame.new(ox, oy, oz), nil, nil, sails)), variant, tint)
		end
		piece("SailStock", Vector3.new(1.6, 40, 1.6), 0, 19, 0, DARK)
		for _, rx in ipairs({ 6.8, 12.4 }) do
			piece("SailRail", Vector3.new(0.8, 30.8, 0.6), rx, 23, 0, DARK)
		end
		for k = 0, 4 do
			piece("SailBar", Vector3.new(12, 0.8, 0.6), 6.8, 8 + 7.5 * k, 0, DARK)
		end
		for c = 0, 1 do
			for r = 0, 3 do
				piece("SailCloth", Vector3.new(5.2, 6.7, 0.3), 3.8 + 5.8 * c, 11.75 + 7.5 * r, 0.45, "px_white_wool", CLOTH)
			end
		end
	end
	sails.WorldPivot = CFrame.fromMatrix(hub, Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
	sails.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	sails:SetAttribute("Speed", 0.3)
	CollectionService:AddTag(sails, "AmbientSpin")
end
task.wait()

-- ================================================================ the silo and the grain shed on the hill
do
	local f = folder("Silo", stead)
	local SX, SZ, Y = SILO.x, SILO.z, L1_Y
	keep(SX - 20, SZ - 14, SX + 34, SZ + 14)
	-- an octagon of two crossed boxes: r = the half width, cut = the corner notch
	local function oct(name, r, cut, y0, y1, variant, tint)
		box(name, SX - r + cut, y0, SZ - r, SX + r - cut, y1, SZ + r, variant, tint, f)
		box(name, SX - r, y0, SZ - r + cut, SX + r, y1, SZ + r - cut, variant, tint, f)
	end
	oct("SiloFoot", 11, 4.4, Y, Y + 1.6, "px_cobblestone", nil)
	oct("SiloWall", 10, 4, Y, Y + 48, "px_red_brick", nil)
	for _, by in ipairs({ Y + 12, Y + 24, Y + 36, Y + 46.6 }) do
		oct("SiloBand", 10.3, 3.7, by, by + 1, "px_iron_block", IRON)
	end
	oct("SiloDome", 11, 4, Y + 48, Y + 52, "px_smooth_stone", nil)
	oct("SiloDome", 8, 3, Y + 52, Y + 56, "px_smooth_stone", nil)
	oct("SiloDome", 5, 2, Y + 56, Y + 60, "px_smooth_stone", nil)
	box("SiloCap", SX - 2, Y + 60, SZ - 2, SX + 2, Y + 64, SZ + 2, "px_iron_block", IRON, f)
	decor(part("SiloFinial", Vector3.new(0.6, 4, 0.6), at(SX, Y + 66, SZ), Color3.fromRGB(70, 70, 76), Enum.Material.Metal, f))
	-- the ladder up the south face (picture) and a little hatch at its top
	do
		local plate = decor(part("SiloLadder", Vector3.new(4, 44, 0.2), at(SX, Y + 24, SZ + 10.15), nil, nil, f))
		plate.Transparency = 1
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = Enum.NormalId.Back
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
		fp("SiloHatch", "S", SX - 2, Y + 41, SX + 2, Y + 45, SZ + 10, 0.3, nil, Color3.fromRGB(50, 50, 56), f)
	end
	-- hay bales stacked at its foot (west and south-west)
	for _, b in ipairs({
		{ SX - 16, SZ - 2, 0 },
		{ SX - 16, SZ + 2, 0 },
		{ SX - 16, SZ + 6, 0 },
		{ SX - 12, SZ + 12, 0 },
		{ SX - 8, SZ + 13, 0 },
		{ SX - 16, SZ, 4 },
		{ SX - 16, SZ + 4, 4 },
		{ SX - 16, SZ + 2, 8 },
	}) do
		hayBale(b[1], Y + b[3], b[2], f)
	end
	-- the grain shed east of the silo, open to the south: grain heap, sacks, a lantern
	local g = folder("GrainShed", f)
	local G0, G1, H0, H1 = SX + 16, SX + 32, SZ - 8, SZ + 8 -- x 172..188, z -158..-142
	box("ShedWall", G0, Y, H0, G1, Y + 12, H0 + 4, "px_spruce_planks", nil, g)
	box("ShedWall", G0, Y, H0 + 4, G0 + 4, Y + 12, H1, "px_spruce_planks", nil, g)
	box("ShedWall", G1 - 4, Y, H0 + 4, G1, Y + 12, H1, "px_spruce_planks", nil, g)
	box("ShedRoof", G0 - 2, Y + 12, H0 - 2, G1 + 2, Y + 14, H1 + 2, "px_dark_oak_planks", nil, g)
	box("ShedRoof", G0 + 2, Y + 14, H0, G1 - 2, Y + 16, H1, "px_dark_oak_planks", nil, g)
	box("GrainHeap", G0 + 4, Y, H0 + 4, G1 - 4, Y + 2, H0 + 10, "px_hay", WHEAT, g)
	box("GrainHeap", G0 + 6, Y + 2, H0 + 4, G1 - 6, Y + 3.4, H0 + 7, "px_hay", WHEAT, g)
	sack(at(G0 + 6, Y, H1 - 3), g)
	sack(at(G0 + 9, Y, H1 - 2.6), g)
	sack(at(G1 - 6.5, Y, H1 - 3), g)
	lantern(V((G0 + G1) / 2, Y + 9.6, H1 - 1), g, false, BY + Y + 12)
end
task.wait()

-- ================================================================ the hill: orchard, beehives, pond, haystacks, fences, flowers
do
	local f = folder("Hill", stead)
	-- the pond east of the mound: flush water in a cobblestone edge, reeds and lily pads
	do
		local P0, Q0, P1, Q1 = 136, -200, 160, -180
		keep(P0 - 4, Q0 - 4, P1 + 4, Q1 + 4)
		local p = folder("Pond", f)
		decor(box("PondEdge", P0 - 2, L1_Y, Q0 - 2, P1 + 2, L1_Y + 0.2, Q1 + 2, "px_cobblestone", nil, p))
		decor(box("PondWater", P0, L1_Y, Q0, P1, L1_Y + 0.3, Q1, "px_water", nil, p))
		for _, r in ipairs({ { P0 + 1, Q0 + 1 }, { P0 + 2.4, Q0 + 1.2 }, { P1 - 1, Q1 - 1.4 }, { P1 - 2.4, Q1 - 1 } }) do
			textured(decor(part("Reed", Vector3.new(0.8, 4, 0.8), at(r[1], L1_Y + 2, r[2]), nil, nil, p)), "px_hedge", LEAF_TINT)
		end
		for _, l in ipairs({ { P0 + 8, Q0 + 6 }, { P0 + 15, Q0 + 12 }, { P0 + 6, Q0 + 14 } }) do
			textured(decor(part("LilyPad", Vector3.new(2.4, 0.1, 2.4), at(l[1], L1_Y + 0.35, l[2]), nil, nil, p)), "px_hedge")
		end
	end
	-- the orchard west of the mound: apple trees in staggered rows, crates of apples
	do
		local o = folder("Orchard", f)
		local APPLE = Color3.fromRGB(205, 32, 30)
		local n = 0
		for j = 0, 3 do
			for i = 0, 2 do
				local x, z = -12 + 24 * i + (j % 2) * 12, -124 - 24 * j
				if spot(x, z, 6, L1_Y) then
					local h = 12 + rng:NextInteger(0, 1) * 4
					tree(x, z, h, o, "px_hedge", "px_oak_log", L1_Y)
					-- apples on the faces of the wide lower crown
					for _ = 1, 4 do
						local side = rng:NextInteger(1, 4)
						local u = rng:NextInteger(-3, 3) * 2.4
						local ax, az = x + u, z + u
						if side == 1 then
							ax = x + 10.5
						elseif side == 2 then
							ax = x - 10.5
						elseif side == 3 then
							az = z + 10.5
						else
							az = z - 10.5
						end
						local ay = L1_Y + h - 4 + rng:NextInteger(-1, 1)
						decor(part("Apple", Vector3.new(1.4, 1.4, 1.4), at(ax, ay, az), APPLE, Enum.Material.SmoothPlastic, o))
					end
					n += 1
					if n % 3 == 0 then
						local c = crate(x + 4, L1_Y, z + 4, o)
						decor(part("Apples", Vector3.new(3.4, 0.6, 3.4), c.CFrame * CFrame.new(0, 2.2, 0), APPLE, Enum.Material.SmoothPlastic, o))
					end
					keep(x - 10, z - 10, x + 10, z + 10)
				end
			end
		end
		-- a fence along the track's north side with an opening into the orchard
		fence(28, -110, 60, -110, o, L1_Y)
		fence(-20, -148, -20, -196, o, L1_Y)
	end
	-- beehives on stands at the orchard edge
	do
		local h = folder("Beehives", f)
		local HONEY = Color3.fromRGB(236, 196, 104)
		for _, b in ipairs({ { 52, -116 }, { 58, -116 }, { 64, -116 } }) do
			local x, z = b[1], b[2]
			if not blocked(x, z, 0) and cellY(x, z) == L1_Y then
				box("HiveStand", x - 2.2, L1_Y, z - 2.2, x + 2.2, L1_Y + 1.2, z + 2.2, "px_spruce_planks", nil, h)
				box("Beehive", x - 2, L1_Y + 1.2, z - 2, x + 2, L1_Y + 5.2, z + 2, "px_planks", HONEY, h)
				box("HiveRoof", x - 2.4, L1_Y + 5.2, z - 2.4, x + 2.4, L1_Y + 5.8, z + 2.4, "px_spruce_planks", nil, h)
				fp("HiveSlot", "S", x - 1.2, L1_Y + 2, x + 1.2, L1_Y + 2.8, z + 2, 0.2, nil, Color3.fromRGB(40, 28, 16), h)
				keep(x - 3, z - 3, x + 3, z + 3)
			end
		end
	end
	-- haystacks on the open grass of the east hill
	do
		local hs = folder("Haystacks", f)
		local placed = 0
		for _, c in ipairs({ { 124, -120 }, { 196, -112 }, { 200, -136 }, { 120, -200 }, { 180, -196 }, { 132, -148 }, { 60, -208 } }) do
			if placed < 5 and spot(c[1], c[2], 8, L1_Y) then
				haystack(c[1], c[2], L1_Y, hs)
				keep(c[1] - 7, c[2] - 7, c[1] + 7, c[2] + 7)
				placed += 1
			end
		end
	end
	-- wild flowers in clumps over the hill (and a few by the farmhouse)
	do
		local fl = folder("Flowers", f)
		local clumps = 0
		for _ = 1, 160 do
			if clumps >= 22 then
				break
			end
			local x, z = rng:NextInteger(-20, 200), rng:NextInteger(-215, -106)
			if spot(x, z, 2, L1_Y) then
				local col = pick(FLOWER_COLORS)
				for k = 0, 2 do
					flower(x + (k - 1) * 1.8, L1_Y, z + (if k == 1 then 1.6 else 0), col, fl)
				end
				keep(x - 2, z - 2, x + 2, z + 2)
				clumps += 1
			end
		end
		for _ = 1, 40 do
			local x, z = rng:NextInteger(120, 210), rng:NextInteger(136, 210)
			if spot(x, z, 2, 0) then
				flower(x, 0, z, pick(FLOWER_COLORS), fl)
				flower(x + 1.8, 0, z + 1, pick(FLOWER_COLORS), fl)
			end
		end
	end
end
task.wait()

-- ================================================================ vines and hanging grass off the cliffs by the barn (L1 → L0)
do
	local f = folder("CliffVines", stead)
	local VINE = Color3.fromRGB(96, 150, 66)
	local n = 0
	for cz = -128, -48, 8 do
		for cx = 112, 208, 8 do
			local x, z = cx + 4, cz + 4
			if cellY(x, z) == L1_Y and onIsland(x, z, 4) then
				-- each face of this cell that drops to L0 (south, east, west)
				for _, d in ipairs({ { 0, 8, "S" }, { 8, 0, "E" }, { -8, 0, "W" } }) do
					local nx, nz = x + d[1], z + d[2]
					if cellY(nx, nz) == 0 and zoneOf(nx, nz) == "farmstead" and onIsland(nx, nz, 4) then
						local face = d[3]
						local plane = if face == "S" then cz + 8 else (if face == "E" then cx + 8 else cx)
						local a0 = if face == "S" then cx else cz
						local off = if face == "W" then -0.2 else 0.2 -- the plate stands 0.2..0.6 off the face
						fp("HangingGrass", face, a0, L1_Y - 2, a0 + 8, L1_Y, plane + off, 0.4, "px_grass_top", GRASS, f)
						for _ = 1, rng:NextInteger(1, 2) do
							local u = a0 + rng:NextInteger(0, 1) * 4
							local len = rng:NextInteger(1, 3) * 4
							fp("Vine", face, u, L1_Y - 2 - len, u + 4, L1_Y - 2, plane + off, 0.4, "px_hedge", VINE, f)
						end
						n += 1
					end
				end
			end
		end
	end
	print(("[build-farm] farmstead: %d cliff faces with vines"):format(n))
end
task.wait()

-- ================================================================ rim decor: trees and bushes near the island edge in my zone
do
	local f = folder("RimGreen", stead)
	local trees, bushes = 0, 0
	for _ = 1, 600 do
		if trees >= 14 and bushes >= 26 then
			break
		end
		local x, z = rng:NextInteger(-24, 220), rng:NextInteger(-220, 220)
		local y = cellY(x, z)
		local isTree = trees < 14 and rng:NextNumber() < 0.45
		local r = if isTree then 10 else 4
		if onIsland(x, z, 10 + r) and not onIsland(x, z, 26 + r) and spot(x, z, r, y) then
			if isTree then
				tree(x, z, 12 + rng:NextInteger(0, 2) * 4, f, "px_hedge", if rng:NextNumber() < 0.3 then "px_birch_log" else "px_oak_log", y)
				keep(x - 10, z - 10, x + 10, z + 10)
				trees += 1
			elseif bushes < 26 then
				box("Bush", x - 4, y, z - 4, x + 4, y + 4, z + 4, "px_hedge", nil, f)
				box("Bush", x - 2 + rng:NextInteger(-1, 1) * 2, y + 4, z - 2, x + 2 + rng:NextInteger(-1, 1) * 2, y + 8, z + 2, "px_hedge", nil, f)
				keep(x - 5, z - 5, x + 5, z + 5)
				bushes += 1
			end
		end
	end
	print(("[build-farm] farmstead: %d parts, rim trees %d, bushes %d"):format(count - partsBefore, trees, bushes))
end
