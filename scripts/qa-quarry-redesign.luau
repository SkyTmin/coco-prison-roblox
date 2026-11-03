--!nocheck
-- Native map queries only: no player/profile mutations. Edit or Server, not client fixture acceptance.
local q = assert(workspace:FindFirstChild("Quarry"))
local CS = game.CollectionService
local by = assert(q:GetAttribute("WorldBaseY"))
local r =
	{ checks = {}, parts = 0, lights = 0, neon = 0, particles = 0, physicalWalkthrough = false }
local function check(name, pass, detail)
	table.insert(r.checks, { name = name, pass = pass == true, detail = detail })
end
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { q }
ray.RespectCanCollide = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { q }
local function clear(x, y, z, w, h, d)
	local blocked = {}
	for _, p in
		workspace:GetPartBoundsInBox(CFrame.new(700 + x, by + y, z), Vector3.new(w, h, d), overlap)
	do
		if p.CanCollide then
			table.insert(blocked, p.Name)
		end
	end
	return #blocked == 0, table.concat(blocked, ",")
end
local function floor(x, z, from)
	local hit =
		workspace:Raycast(Vector3.new(700 + x, by + (from or 8), z), Vector3.new(0, -120, 0), ray)
	return hit and hit.Position.Y - by
end
local anchors, bosses, buyers, spots = {}, {}, {}, {}
for _, o in q:GetDescendants() do
	if o:IsA("BasePart") then
		r.parts += 1
		if o.Material == Enum.Material.Neon then
			r.neon += 1
		end
	end
	if o:IsA("Light") then
		r.lights += 1
	end
	if o:IsA("ParticleEmitter") or o:IsA("Fire") then
		r.particles += 1
	end
	if CS:HasTag(o, "MineAnchor") then
		table.insert(anchors, o)
	end
	if CS:HasTag(o, "BossSpawn") then
		table.insert(bosses, o)
	end
	if CS:HasTag(o, "SellPoint") then
		table.insert(buyers, o)
	end
	if CS:HasTag(o, "LocationSpawn") then
		spots[o:GetAttribute("Spot") or "spawn"] = o
	end
end
check("accepted open-air design", q:GetAttribute("DesignVersion") == "2026-11-03-open-air-accepted")
check(
	"bounded scenery and light budget",
	r.parts < 6000 and r.lights <= 20,
	{ parts = r.parts, lights = r.lights }
)
check("matte geometry without particle clouds", r.neon == 0 and r.particles == 0)
check(
	"original 40x16x40 mine, relocated with map",
	#anchors == 1
		and anchors[1]:GetAttribute("Size") == Vector3.new(40, 16, 40)
		and (anchors[1].Position - Vector3.new(700, by - 0.1, -20)).Magnitude < 0.02
)
check(
	"one shared guardian with original radius",
	#bosses == 1
		and bosses[1]:GetAttribute("BossId") == "basalt_guardian"
		and bosses[1]:GetAttribute("ArenaRadius") == 40
)
check(
	"one buyer at arrival",
	#buyers == 1
		and buyers[1].CFrame.LookVector.Z > 0.9
		and (buyers[1].Position - spots.spawn.Position).Magnitude < 70
)
for _, id in { "spawn", "mine", "boss" } do
	local p = spots[id]
	local h = p and floor(p.Position.X - 700, p.Position.Z)
	check("solid arrival " .. id, h ~= nil and math.abs(h) < 1.1)
end
for _, v in
	{
		{ 0, 148 },
		{ 0, 124 },
		{ 0, 100 },
		{ 0, 76 },
		{ 32, 142 },
		{ 56, 142 },
		{ -116, 76 },
		{ -148, 76 },
		{ -180, 80 },
		{ 112, 80 },
		{ 160, 72 },
		{ 208, 56 },
		{ 220, 52 },
		{ 112, -80 },
		{ -112, -80 },
		{ 0, -116 },
	}
do
	local h = floor(v[1], v[2])
	local free, why = clear(v[1], 3.8, v[2], 4, 5, 4)
	check("clear circulation " .. v[1] .. "," .. v[2], h ~= nil and math.abs(h) < 1.1 and free, why)
end
check("no props inside excavation", clear(0, -32, -20, 155, 60, 155))
check("entire combat floor clear", clear(220, 18, -32, 78, 8, 78))
check("solid arena floor", math.abs((floor(220, -32, 18) or -999) - 12.3) < 0.1)
-- Dense lower-ground sampling catches the original sky holes at the floor/wall junction.
local holes = {}
local samples = 0
for x = -120, 120, 4 do
	for z = -124, 108, 4 do
		if x > -88 and x < 88 and z > -108 and z < 68 then
			continue
		end
		samples += 1
		if not floor(x, z, 80) then
			if #holes < 12 then
				table.insert(holes, { x, z })
			end
		end
	end
end
check("continuous floor around all mine edges", #holes == 0, { samples = samples, holes = holes })
for _, v in
	{
		{ 0, -20 },
		{ 0, 148 },
		{ -112, 0 },
		{ 112, 0 },
		{ 220, -32 },
		{ 0, -176 },
		{ -44, -176 },
		{
			40,
			-208,
		},
	}
do
	local hit =
		workspace:Raycast(Vector3.new(700 + v[1], by + 70, v[2]), Vector3.new(0, 400, 0), ray)
	check("open sky " .. v[1] .. "," .. v[2], hit == nil, hit and hit.Instance.Name)
end
local function stairs(name, x, z0, z1, y0, y1)
	local last = nil
	local ok = true
	local heights = {}
	for z = z0, z1, -4 do
		local h = floor(x, z, 80)
		table.insert(heights, h or -999)
		if not h or (last and math.abs(h - last) > 2.1) then
			ok = false
		end
		last = h
	end
	check(
		name,
		ok and math.abs(heights[1] - y0) < 0.1 and math.abs(heights[#heights] - y1) < 0.1,
		heights
	)
end
stairs("loading deck stairs", -180, 70, 42, 2, 16)
stairs("north terrace stair 1", 0, -116, -148, 0, 8)
stairs("north terrace stair 2", -44, -148, -176, 8, 20)
stairs("north terrace stair 3", 40, -184, -212, 20, 32)
stairs("arena stairs", 220, 42, 22, 2, 12)
local trusses, wheel, oldRoof = 0, 0, 0
for _, p in q:GetDescendants() do
	if p:IsA("TrussPart") then
		trusses += 1
	end
	if p.Name == "WheelRim" then
		wheel += 1
	end
	if p.Name == "VaultRock" or p.Name == "Vault" then
		oldRoof += 1
	end
end
check("four broad ladder shafts", trusses == 32)
check("full winding-wheel landmark", wheel >= 32)
check("old cave roof completely removed", oldRoof == 0)
local safety = q:FindFirstChild("ContourSafety")
check(
	"contour guards prevent stepping off irregular edges",
	safety ~= nil and #safety:GetChildren() > 40
)
local backup = game.ServerStorage:FindFirstChild("QuarryBeforeRedesign_20261103")
local tagged = 0
if backup then
	for _, v in backup:GetDescendants() do
		tagged += #CS:GetTags(v)
	end
end
check("original backup inert", backup ~= nil and tagged == 0)
-- Regression for the reported view below the loading deck: raised stone used to
-- intersect brick feet, exposing coincident surfaces directly at player height.
local intersectingFeet = {}
local feet = 0
for _, foot in q:GetDescendants() do
	if foot:IsA("BasePart") and foot.Name == "LoadingFoot" then
		feet += 1
		for _, p in
			workspace:GetPartBoundsInBox(foot.CFrame, foot.Size - Vector3.one * 0.08, overlap)
		do
			if p.Name == "TerraceGround" then
				table.insert(intersectingFeet, tostring(foot.Position))
			end
		end
	end
end
check(
	"loading supports clear of raised terrain",
	feet == 10 and #intersectingFeet == 0,
	intersectingFeet
)
r.passed, r.failed = 0, 0
for _, v in r.checks do
	if v.pass then
		r.passed += 1
	else
		r.failed += 1
	end
end
local out = game.ServerStorage:FindFirstChild("QAQuarryRedesign") or Instance.new("StringValue")
out.Name, out.Value, out.Parent =
	"QAQuarryRedesign", game.HttpService:JSONEncode(r), game.ServerStorage
return r
