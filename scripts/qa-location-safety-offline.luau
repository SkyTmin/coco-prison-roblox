--!nocheck
-- Actual LocationBounds/WorldSafetyService, isolated mock world/players, no Studio or profile writes.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rbx = require("@lune/roblox")
local env = getfenv()
local V, CF = rbx.Vector3, rbx.CFrame
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(callbacks) do
				fn(...)
			end
		end,
	}
end
local methods = {}
local function node(class, name, parent)
	local n = setmetatable({
		ClassName = class,
		Name = name,
		_parent = parent,
		children = {},
		attrs = {},
		Size = V.one,
		CFrame = CF.identity,
		Anchored = true,
		CanCollide = true,
		Health = 20,
		ChildRemoved = signal(),
	}, {
		__index = function(t, k)
			if k == "Parent" then
				return rawget(t, "_parent")
			end
			if k == "Position" then
				return t.CFrame.Position
			end
			return methods[k]
		end,
		__newindex = function(t, k, value)
			if k == "Parent" then
				local old = rawget(t, "_parent")
				if old then
					for i, child in ipairs(old.children) do
						if child == t then
							table.remove(old.children, i)
							break
						end
					end
				end
				rawset(t, "_parent", value)
				if value then
					table.insert(value.children, t)
				end
				if old then
					old.ChildRemoved:Fire(t)
				end
			else
				rawset(t, k, value)
			end
		end,
	})
	if parent then
		table.insert(parent.children, n)
	end
	return n
end
function methods:IsA(class)
	return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part")
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:GetDescendants()
	local result = {}
	local function walk(n)
		for _, child in ipairs(n.children) do
			table.insert(result, child)
			walk(child)
		end
	end
	walk(self)
	return result
end
function methods:FindFirstChild(name)
	for _, child in ipairs(self.children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildOfClass(class)
	for _, child in ipairs(self.children) do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function methods:IsDescendantOf(root)
	local p = self.Parent
	while p do
		if p == root then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:GetAttribute(k)
	return self.attrs[k]
end
function methods:SetAttribute(k, v)
	self.attrs[k] = v
end
function methods:GetFullName()
	return self.Name
end
function methods:PivotTo(cf)
	self:FindFirstChild("HumanoidRootPart").CFrame = cf
	self.pivots = (self.pivots or 0) + 1
end
function methods:Destroy()
	self.Parent = nil
end
local function part(parent, name, size, position)
	local p = node("Part", name, parent)
	p.Size, p.CFrame = size, CF.new(position)
	return p
end
local tags = {}
local collection = {
	AddTag = function(_, p, tag)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], p)
	end,
	HasTag = function(_, p, tag)
		return table.find(tags[tag] or {}, p) ~= nil
	end,
	GetTagged = function(_, tag)
		return tags[tag] or {}
	end,
}
local world, storage = node("Workspace", "Workspace"), node("ServerStorage", "ServerStorage")
world.StreamingEnabled = true
local players, jobs, streamHook = {}, {}, nil
local heartbeat = signal()
local services = {
	CollectionService = collection,
	ReplicatedStorage = {
		WaitForChild = function()
			return { LocationBounds = "LocationBounds", Config = "Config" }
		end,
	},
	Players = {
		GetPlayers = function()
			return players
		end,
		PlayerRemoving = signal(),
	},
	RunService = { Heartbeat = heartbeat },
}
local cards = serde.decode("json", fs.readFile("src/shared/Config/locations.json")).locations
local byId = {}
for _, card in ipairs(cards) do
	byId[card.id] = card
end
local resets, cancelled = 0, 0
local modules = {
	Config = {
		location = function(id)
			return byId[id]
		end,
		faction = function(id)
			return id and { id = id }
		end,
	},
	ProfileService = {
		Get = function(p)
			return p.profile
		end,
	},
	GangService = {
		gangOf = function(p)
			return p and p.gang
		end,
		level = function(p)
			return p.upgrade or 0
		end,
	},
	FallService = {
		Reset = function()
			resets += 1
		end,
	},
	LocationService = {
		CancelForRecovery = function()
			cancelled += 1
		end,
	},
}
local parent = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
local function load(path, expose)
	local source = fs.readFile(path)
	if expose then
		source = source:gsub(
			"return Service%s*$",
			"Service._step = step; Service._regions = regions; Service._arrival = arrival; Service._tracks = tracks; return Service"
		)
	end
	local fn = assert(loadstring(source, "@" .. path))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, id)
					return assert(services[id], id)
				end,
			},
			workspace = world,
			script = { Parent = parent },
			require = function(id)
				return assert(modules[id], id)
			end,
			Vector3 = V,
			CFrame = CF,
			Enum = rbx.Enum,
			Instance = {
				new = function(class)
					return node(class, class)
				end,
			},
			task = {
				spawn = function(fn)
					table.insert(jobs, fn)
				end,
			},
		}, { __index = env })
	)
	return fn()
end
local Bounds = load("src/shared/LocationBounds.luau")
modules.LocationBounds = Bounds
local function spawn(root, id, pos, faction, private)
	local p = part(root, "Arrival", V.new(4, 1, 4), pos)
	p:SetAttribute("LocationId", id)
	p:SetAttribute("Faction", faction)
	p:SetAttribute("PrivateArrival", private)
	collection:AddTag(p, "LocationSpawn")
	return p
end
local roots, arrivals = {}, {}
-- Isolated geometric fixtures for all configured ids. Builder source identity is checked separately;
-- these synthetic coordinates deliberately make no assertion about the cloud map's measured footprint.
for index, card in ipairs(cards) do
	local name = Bounds.ROOTS[card.id]
	check(name ~= nil, "all30: registry includes " .. card.id)
	local builder = fs.readFile("scripts/build-" .. card.id:gsub("_", "-") .. ".luau")
	check(
		builder:find('"' .. name .. '"', 1, true) ~= nil,
		"all30: root agrees with actual builder " .. card.id
	)
	local root = node(
		if card.id == "gang_base" then "Model" else "Folder",
		name,
		if card.id == "gang_base" then storage else world
	)
	local at = V.new(index * 600, index * 1000, 0)
	part(root, "Floor", V.new(120, 4, 120), at - V.new(0, 2, 0))
	part(root, "PitFloor", V.new(40, 4, 40), at - V.new(0, 66, 0))
	roots[card.id], arrivals[card.id] = root, spawn(root, card.id, at + V.new(40, 0.5, 40))
	if card.id == "fraction_base" then
		arrivals[card.id]:SetAttribute("Faction", "red")
		spawn(root, card.id, at + V.new(-40, 0.5, 40), "blue")
	end
end
check(#cards == 30, "exactly30 configured locations")
local rooms = node("Folder", "GangMineRooms", roots.ghetto)
local privateSpawns = {}
for index = 1, 4 do
	local room = node("Model", "GangMineRoom_" .. index, rooms)
	local pos = arrivals.ghetto.Position + V.new((index - 2.5) * 120, -300, 0)
	part(room, "Floor", V.new(68, 2, 68), pos - V.new(0, 33, 0))
	part(room, "Roof", V.new(72, 2, 72), pos + V.new(0, 24, 0))
	local anchor = part(room, "Anchor", V.one, pos)
	anchor:SetAttribute("GangMineOwner", "a")
	anchor:SetAttribute("GangMineUntil", os.time() + 60)
	anchor:SetAttribute("Size", V.new(12, 8, 12))
	collection:AddTag(anchor, "MineAnchor")
	privateSpawns[index] = spawn(room, "ghetto", pos + V.new(0, 1, 29), nil, true)
end
local showcase = node("Folder", "Showcase", world)
part(showcase, "Floor", V.new(160, 1, 80), arrivals.prison.Position + V.new(0, 0, -330))
local showSpawn = spawn(showcase, "prison", arrivals.prison.Position + V.new(0, 1, -330))
showSpawn:SetAttribute("Spot", "showcase")
local measured = Bounds.ApplyWorld(world, storage)
check(#measured == 35, "30 locations + four private mines + detached showcase")
local before = #world:GetDescendants()
local twice = Bounds.ApplyWorld(world, storage)
check(#world:GetDescendants() == before and #twice == 35, "repeated application does not add walls")
for _, region in ipairs(measured) do
	check(
		#region.root:FindFirstChild("LocationSafety"):GetChildren() == 4,
		"only four exterior walls: " .. region.root.Name
	)
	local walls = region.root:FindFirstChild("LocationSafety")
	check(
		not walls.West and walls:FindFirstChild("West").Position.X + 1 <= region.min.X,
		"walls stay outside legal geometry"
	)
end
local function regionFor(root)
	for _, r in ipairs(measured) do
		if r.root == root then
			return r
		end
	end
end
check(
	regionFor(roots.ghetto).floor > privateSpawns[1].Position.Y,
	"private mine depth does not lower public Ghetto rescue plane"
)
check(
	Bounds.Contains(regionFor(privateSpawns[1].Parent), privateSpawns[1].Position - V.new(0, 32, 0)),
	"private mine bottom remains legal"
)
local rotatedRoot = node("Folder", "RotatedFixture")
local rotated = part(rotatedRoot, "Floor", V.new(20, 4, 10), V.new(100, 50, 100))
rotated.CFrame *= CF.Angles(0, math.pi / 2, 0)
local rotatedRegion = Bounds.Measure(rotatedRoot, "prison")
check(
	math.abs(rotatedRegion.min.X - 95) < 0.001 and math.abs(rotatedRegion.max.Z - 110) < 0.001,
	"rotation-aware world bounds"
)
local npc = node("Model", "Npc", roots.prison)
node("Humanoid", "Humanoid", npc)
part(npc, "HumanoidRootPart", V.new(10, 10, 10), V.new(1e6, 1e6, 1e6))
local far = part(roots.prison, "LightingVolume", V.new(1000, 1000, 1000), V.new(-1e6, 0, 0))
far.CanCollide = false
local net = part(roots.prison, "VoidCatch", V.new(1000, 10, 1000), V.new(-1e6, 0, 0))
collection:AddTag(net, "VoidCatch")
check(
	Bounds.Measure(roots.prison, "prison").max == regionFor(roots.prison).max,
	"NPCs, noncolliding volumes and nets cannot enlarge footprint"
)
local empty = node("Folder", "Empty")
check(Bounds.Apply(empty, "prison") == nil, "missing geometry fails closed without invented bounds")
local waterEdge = part(rotatedRoot, "EdgeWall", V.new(2, 400, 200), V.new(200, 150, 100))
waterEdge.Transparency = 1
local withWater = Bounds.Measure(rotatedRoot, "prison")
check(
	withWater.max.X == 201 and withWater.min.Z == 0 and withWater.floor == rotatedRegion.floor,
	"existing edge-wall footprint preserves Terrain swimming without treating wall bottom as a floor"
)
-- Reproduce the exact four offending cloud parts. Legitimate distant mountain scenery stays intact.
local function legacy(spec)
	local model = node("Folder", spec.name)
	local edge = node("Folder", "Edge", model)
	local scenery = part(
		model,
		"RealMountainOrGround",
		V.new(spec.width + 80, 4, spec.sceneryDepth),
		V.new(spec.x, spec.y - 150, spec.sceneryZ)
	)
	local a = part(edge, "EdgeWall", V.new(spec.width, 500, 4), V.new(spec.x, spec.y, spec.north))
	local b = part(edge, "EdgeWall", V.new(spec.width, 500, 4), V.new(spec.x, spec.y, spec.south))
	local c = part(
		edge,
		"EdgeWall",
		V.new(4, 500, spec.south - spec.north),
		V.new(spec.x - spec.width / 2, spec.y, spec.bad)
	)
	local d = part(
		edge,
		"EdgeWall",
		V.new(4, 500, spec.south - spec.north),
		V.new(spec.x + spec.width / 2, spec.y, spec.bad)
	)
	for _, wall in ipairs({ a, b, c, d }) do
		wall.Transparency = 1
	end
	return model, a, b, c, d, scenery
end
local legacySpecs = {
	{
		name = "MountainFoot",
		id = "mountain_foot",
		x = 2400,
		y = 1650,
		width = 568,
		north = -300,
		south = 284,
		bad = -150142,
		sceneryDepth = 1228,
		sceneryZ = -334,
		expected = -948,
	},
	{
		name = "Pyramid",
		id = "pyramid",
		x = 4400,
		y = 4650,
		width = 636,
		north = -318,
		south = 318,
		bad = -159159,
		sceneryDepth = 640,
		sceneryZ = 0,
		expected = -320,
	},
}
for _, spec in ipairs(legacySpecs) do
	local model, a, b, c, d, scenery = legacy(spec)
	local original = scenery.CFrame
	check(
		Bounds.Measure(model, spec.id).min.Z < -100000,
		"actual legacy bad-wall extent reproduced: " .. spec.id
	)
	local fixed = Bounds.Apply(model, spec.id)
	check(
		fixed.repairedEdges == 2
			and c.Position.Z == (a.Position.Z + b.Position.Z) / 2
			and d.Position.Z == c.Position.Z,
		"repair derives both side centres from intact perpendicular pair: " .. spec.id
	)
	check(
		fixed.min.Z == spec.expected and scenery.CFrame == original,
		"repair preserves real distant geometry instead of clamping it: " .. spec.id
	)
	check(Bounds.Apply(model, spec.id).repairedEdges == 0, "legacy repair idempotent: " .. spec.id)
	local changed, _, _, changedSide = legacy(spec)
	changedSide.Size += V.new(0, 0, 1)
	check(
		Bounds.RepairLegacyEdges(changed) == 0,
		"mismatched rectangle dimensions are not guessed: " .. spec.id
	)
	local unrelated = legacy(spec)
	unrelated.Name = "OtherMap"
	check(
		Bounds.RepairLegacyEdges(unrelated) == 0,
		"legacy repair restricted to the two confirmed map roots"
	)
	local builder = fs.readFile("scripts/build-" .. spec.id:gsub("_", "-") .. ".luau")
	check(
		not builder:find(tostring(spec.bad), 1, true),
		"builder no longer regenerates malformed literal: " .. spec.id
	)
end
local Safety = load("src/server/Services/WorldSafetyService.luau", true)
Safety.Start()
local function actor(id, position)
	local p = node("Player", "Actor")
	p.profile = { location = id, faction = "blue", gang = { id = "a" }, upgrade = 1 }
	p.RequestStreamAroundAsync = function()
		if streamHook then
			streamHook()
		end
	end
	local char = node("Model", "Character", world)
	local root = part(char, "HumanoidRootPart", V.new(2, 2, 1), position)
	root.Anchored = false
	node("Humanoid", "Humanoid", char)
	p.Character = char
	players = { p }
	return p, char, root
end
local function flush()
	local pending = jobs
	jobs = {}
	for _, job in ipairs(pending) do
		job()
	end
end
for _, card in ipairs(cards) do
	if card.id == "gang_base" then
		continue
	end
	local p, char, root = actor(card.id, arrivals[card.id].Position + V.new(0, 3, 0))
	Safety._step()
	root.CFrame -= V.new(0, 1000, 0) -- skips any thin collision/overlap net in one step
	Safety._step()
	check(root.Anchored and #jobs == 1, "fast fall held while streaming: " .. card.id)
	flush()
	local target = Safety._arrival(Safety._regions[roots[card.id]], p)
	check(
		char.pivots == 1 and root.Position == target.Position + V.new(0, 4, 0) and not root.Anchored,
		"same-region rescue: " .. card.id
	)
end
local p, char, root = actor("quarry", arrivals.quarry.Position)
Safety._step()
local r = Safety._regions[roots.quarry]
root.CFrame = CF.new(r.min.X + 20, r.min.Y + 2, r.min.Z + 20)
Safety._step()
check(#jobs == 0 and not char.pivots, "deep legitimate mine/ladders are not rescued")
root.CFrame = CF.new(arrivals.quarry.Position + V.new(0, 50, 0))
Safety._step()
check(#jobs == 0, "ordinary high jump preserved; no ceiling")
root.CFrame = CF.new(r.max.X + 50, arrivals.quarry.Position.Y, r.max.Z)
Safety._step()
flush()
check(char.pivots == 1, "horizontal tunneling is recovered")
local nextLocation = arrivals.basement
p.profile.location = "basement"
root.CFrame = nextLocation.CFrame + V.new(0, 4, 0)
Safety._step()
check(
	#jobs == 0 and Safety._tracks[p].region.root == roots.basement,
	"valid cross-location teleport replaces old region first"
)
local foreignNet = part(roots.quarry, "VoidCatchOther", V.one, root.Position)
collection:AddTag(foreignNet, "VoidCatch")
check(
	not Safety.Catch(p, foreignNet) and #jobs == 0,
	"another location's net never becomes a destination"
)
p, char, root = actor("prison", showSpawn.Position)
Safety._step()
root.CFrame -= V.new(0, 500, 0)
Safety._step()
flush()
check(
	root.Position == showSpawn.Position + V.new(0, 4, 0),
	"showcase returns to showcase, not across prison wall"
)
p, char, root = actor("ghetto", privateSpawns[1].Position)
Safety._step()
root.CFrame -= V.new(0, 100, 0)
Safety._step()
flush()
check(
	root.Position == privateSpawns[1].Position + V.new(0, 4, 0),
	"leased room returns to its exact private arrival"
)
local anchor = privateSpawns[1].Parent:FindFirstChild("Anchor")
root.CFrame -= V.new(0, 100, 0)
Safety._step()
streamHook = function()
	anchor:SetAttribute("GangMineUntil", 0)
end
flush()
streamHook = nil
check(
	char.pivots == 1 and not root.Anchored,
	"expired lease during streaming cannot grant private reentry"
)
-- Two runtime gang clones, no template/global-first-spawn fallback.
local houses = {}
for index, gang in ipairs({ "a", "b" }) do
	local house = node("Model", "GangHouse_" .. gang, world)
	house:SetAttribute("GangId", gang)
	local pos = V.new(40000 + index * 200, 13200, 5000)
	part(house, "Floor", V.new(52, 2, 44), pos - V.new(0, 1, 0))
	houses[index] = spawn(house, "gang_base", pos + V.new(0, 0.2, 15))
	houses[index]:SetAttribute("HouseSpawn", true)
	Safety.Register(house, "gang_base")
end
p, char, root = actor("gang_base", houses[1].Position)
Safety._step()
root.CFrame -= V.new(0, 300, 0)
Safety._step()
flush()
check(
	root.Position == houses[1].Position + V.new(0, 4, 0),
	"new private clone protected and same gang selected"
)
check(Safety._arrival(Safety._regions[houses[2].Parent], p) == nil, "foreign gang arrival refused")
root.CFrame -= V.new(0, 300, 0)
Safety._step()
streamHook = function()
	p.profile.gang = { id = "b" }
end
flush()
streamHook = nil
check(char.pivots == 1 and not root.Anchored, "membership change while streaming cancels recovery")
-- Each async invalidation keeps the newer character/destination untouched and always releases our anchor.
for _, mode in ipairs({ "teleport", "character", "dead", "destroy", "streamError" }) do
	p, char, root = actor("prison", arrivals.prison.Position)
	Safety._step()
	root.CFrame -= V.new(0, 500, 0)
	Safety._step()
	streamHook = function()
		if mode == "teleport" then
			root.CFrame = arrivals.quarry.CFrame
			p.profile.location = "quarry"
		elseif mode == "character" then
			p.Character = node("Model", "NewCharacter", world)
		elseif mode == "dead" then
			char:FindFirstChildOfClass("Humanoid").Health = 0
		elseif mode == "destroy" then
			arrivals.prison.Parent = nil
		else
			error("stream unavailable")
		end
	end
	flush()
	streamHook = nil
	check(
		(char.pivots or 0) == (if mode == "streamError" then 1 else 0) and not root.Anchored,
		"stream race: " .. mode
	)
	if mode == "destroy" then
		arrivals.prison.Parent = roots.prison
	end
end
p, char, root = actor("paradise", arrivals.prison.Position)
Safety._step()
check(
	Safety._tracks[p].region.root == roots.prison and #jobs == 0,
	"fresh prison spawn ignores stale saved distant location"
)
check(
	resets > 0 and cancelled > 0,
	"recoveries reset fall history and cancel old teleport channels"
)
check(
	fs.readFile("src/server/Services/GangHouseService.luau")
		:find("require(script.Parent.WorldSafetyService).Register(model, LOCATION)", 1, true)
		~= nil,
	"runtime clone registration hook present"
)
print(
	string.format(
		"Location safety PASS: %d checks; actual modules, synthetic geometry, all30 builder identities; no Studio",
		checks
	)
)
