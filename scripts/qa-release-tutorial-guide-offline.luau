--!nocheck
-- Execute unchanged Guide closures with fake geometry/UI boundaries; no Studio or real profiles.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local source = fs.readFile("src/client/TutorialGuide.luau")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function closure(first, last, returns, env)
	local a = assert(source:find(first, 1, true))
	local b = assert(source:find(last, a, true))
	local fn = assert(loadstring(source:sub(a, b - 1) .. "\nreturn " .. returns))
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end
local now, scans, rays = 1, 0, 0
local parts, byPosition, byCenter = {}, {}, {}
local function positionKey(v)
	return string.format("%.3f,%.3f,%.3f", v.X + 0, v.Y + 0, v.Z + 0)
end
local root = {
	Position = rb.Vector3.new(0, 8, 0),
	IsA = function()
		return true
	end,
}
local character = {
	FindFirstChild = function()
		return root
	end,
}
local world = {
	CurrentCamera = {
		CFrame = rb.CFrame.lookAt(rb.Vector3.new(0, 8, -12), rb.Vector3.new(0, 0, 8)),
	},
}
for i = 1, 12000 do
	local part = {
		Name = if i % 2 == 0 then "gravel" else "sand",
		Position = rb.Vector3.new(
			(i - 1) % 32 * 4,
			-math.floor((i - 1) / 1024) * 4,
			math.floor((i - 1) % 1024 / 32) * 4
		),
		Size = rb.Vector3.new(4, 4, 4),
		LocalTransparencyModifier = 0,
		Parent = world,
		exposed = false,
		IsA = function()
			return true
		end,
		IsDescendantOf = function(self)
			return self.Parent == world
		end,
		GetAttribute = function()
			return "prison"
		end,
	}
	table.insert(parts, part)
	byPosition[tostring(part.Position + rb.Vector3.new(0, 7, 0))] = part
	byCenter[positionKey(part.Position)] = part
end
parts[1].exposed, parts[3].exposed = true, true
function world:FindFirstChild()
	return {
		GetChildren = function()
			scans += 1
			return parts
		end,
	}
end
function world:Raycast(at, direction)
	rays += 1
	if at == self.CurrentCamera.CFrame.Position then
		local part = byCenter[positionKey(at + direction)]
		return if part and part.exposed and part.visible ~= false then { Instance = part } else nil
	end
	local part = byPosition[tostring(at)]
	return if part and part.exposed then { Instance = part } else nil
end
local function newSelector()
	return closure("local cachedTarget:", "local function chooseControl", "chooseTarget", {
		player = { Character = character },
		workspace = world,
		Vector3 = rb.Vector3,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = rb.Enum,
		os = {
			clock = function()
				return now
			end,
		},
		CollectionService = {
			GetTagged = function()
				return {}
			end,
		},
		Config = {
			block = function(id)
				return { tool = "shovel", upgradeCounter = id }
			end,
		},
	})
end
local selectTarget = newSelector()
local picked = selectTarget("mine", { sand = true })
check("actual nearest existing exposed target selected", picked == parts[1])
local previousScans, previousRays = scans, rays
for _ = 1, 100 do
	selectTarget("mine", { sand = true })
end
check("cached target avoids 100 full 12000-cell scans", scans == previousScans)
check("cached target uses two bounded visibility rays per tick", rays - previousRays == 200)
parts[1].Parent = nil
now += 0.6
check(
	"another player's removed target retargets existing cell",
	selectTarget("mine", { sand = true }) == parts[3]
)
parts[3].LocalTransparencyModifier = 1
now += 0.6
check("fast-hidden target is never retained", selectTarget("mine", { sand = true }) == nil)
parts[1].Parent, parts[1].exposed = world, true
previousRays = rays
now += 0.6
check(
	"missing exposed requested material falls back to real clearance block",
	selectTarget("mine", { gravel = true }) == parts[1]
)
check("retarget ray count capped despite 12000 candidates", rays - previousRays <= 130)
parts[1].exposed = false
previousScans = scans
check(
	"invalid target clears immediately and rescan is throttled",
	selectTarget("mine", { gravel = true }) == nil and scans == previousScans
)
check("no task mode clears target", selectTarget(nil, nil) == nil)

local template = parts[1]
local function cell(name, x, y, z)
	local part = table.clone(template)
	part.Name, part.Position, part.exposed, part.Parent = name, rb.Vector3.new(x, y, z), true, world
	return part
end
local function scene(cells, eye, towards)
	parts, byPosition, byCenter = cells, {}, {}
	for _, part in parts do
		byPosition[tostring(part.Position + rb.Vector3.new(0, 7, 0))] = part
		byCenter[positionKey(part.Position)] = part
	end
	world.CurrentCamera.CFrame = rb.CFrame.lookAt(eye, towards)
	now += 3
	return newSelector()
end
local far = cell("sand", 0, 0, 24)
local near = cell("gravel", 0, 0, 8)
local behind = cell("sand", 0, 0, -8)
selectTarget = scene({ far, near, behind }, root.Position, rb.Vector3.new(0, 0, 16))
check(
	"nearest of ALL unfinished materials ahead wins",
	selectTarget("mine", { sand = true, gravel = true }) == near
)
check("completed material no longer selected", selectTarget("mine", { sand = true }) == far)
world.CurrentCamera.CFrame = rb.CFrame.lookAt(root.Position, behind.Position)
now += 0.6
check(
	"camera turn replaces intact old target with block in view",
	selectTarget("mine", { sand = true }) == behind
)
local low = cell("sand", 0, -4, 8)
local high = cell("sand", 0, 0, 12)
selectTarget = scene({ low, high }, root.Position, rb.Vector3.new(0, 0, 16))
check(
	"nearby upper layer preferred over bottom of hole",
	selectTarget("mine", { sand = true }) == high
)
high.visible = false
now += 0.6
check("block occluded from player cannot be targeted", selectTarget("mine", { sand = true }) == low)
low.exposed = false
now += 0.6
check(
	"buried or occluded blocks never produce false marker",
	selectTarget("mine", { sand = true }) == nil
)
local left = cell("sand", -8, 0, 12)
local right = cell("sand", 8, 0, 12)
root.Position = rb.Vector3.new(-8, 8, 0)
selectTarget = scene({ left, right }, root.Position, left.Position)
check(
	"initial nearby block follows player's position",
	selectTarget("mine", { sand = true }) == left
)
root.Position = rb.Vector3.new(8, 8, 0)
world.CurrentCamera.CFrame = rb.CFrame.lookAt(root.Position, right.Position)
now += 0.6
check(
	"walking retargets even though old block still exists",
	selectTarget("mine", { sand = true }) == right
)

-- Regression: nearer buried/occluded cells must not permanently exclude the 33rd
-- valid requested material. Execute the unchanged production selector across ticks.
local crowded = {}
for i = 0, 31 do
	local candidate = cell("sand", -16 + (i % 8) * 4, 0, 40 + math.floor(i / 8) * 4)
	candidate.exposed, candidate.visible = i % 2 == 0, false
	table.insert(crowded, candidate)
end
local visible33 = cell("sand", 0, 0, 140)
table.insert(crowded, visible33)
root.Position = rb.Vector3.new(0, 8, 0)
selectTarget = scene(crowded, root.Position, rb.Vector3.new(0, 8, 140))
previousRays = rays
check("first blocked page has no fabricated target", selectTarget("mine", { sand = true }) == nil)
check("blocked first page retains ray budget", rays - previousRays <= 130)
previousScans = scans
now += 0.2
check(
	"blocked page continuation obeys half-second throttle",
	selectTarget("mine", { sand = true }) == nil and scans == previousScans
)
now += 0.4
previousRays = rays
check(
	"33rd visible requested block is found on bounded continuation",
	selectTarget("mine", { sand = true }) == visible33
)
check("continuation retains ray budget", rays - previousRays <= 130)
now += 2.1
check(
	"valid farther wanted target stays visible during another blocked page",
	selectTarget("mine", { sand = true }) == visible33
)
crowded[1].exposed, crowded[1].visible = true, true
now += 2.1
check(
	"fresh nearby probes rediscover a block another player exposed",
	selectTarget("mine", { sand = true }) == crowded[1]
)

local deeper = {}
for i = 0, 95 do
	local candidate = cell("sand", -16 + (i % 8) * 4, 0, 40 + math.floor(i / 8) * 4)
	candidate.visible = false
	table.insert(deeper, candidate)
end
local visible97, clearance = cell("sand", 0, 0, 160), cell("gravel", 0, 0, 12)
table.insert(deeper, visible97)
table.insert(deeper, clearance)
selectTarget = scene(deeper, root.Position, rb.Vector3.new(0, 8, 160))
check(
	"clearance fallback is available while wanted search continues",
	selectTarget("mine", { sand = true }) == clearance
)
local foundWanted = false
for page = 1, 4 do
	now += 0.6
	previousRays = rays
	local target = selectTarget("mine", { sand = true })
	check("paged wanted search under fallback stays bounded " .. page, rays - previousRays <= 130)
	if target == visible97 then
		foundWanted = true
		break
	end
end
check("cached visible fallback cannot starve the 97th wanted block", foundWanted)

for _, candidate in deeper do
	candidate.exposed, candidate.visible = false, false
end
selectTarget = scene(deeper, root.Position, rb.Vector3.new(0, 8, 160))
for _ = 1, 5 do
	selectTarget("mine", { sand = true })
	now += 0.6
end
deeper[40].exposed, deeper[40].visible = true, true
local rediscovered = false
for page = 1, 5 do
	previousRays = rays
	local target = selectTarget("mine", { sand = true })
	check(
		"exhausted scan retries without exceeding ray budget " .. page,
		rays - previousRays <= 130
	)
	if target == deeper[40] then
		rediscovered = true
		break
	end
	now += 0.6
end
check("completed failed scan retries blocks exposed later", rediscovered)
local fallbackOnly = {}
for i = 0, 31 do
	local candidate = cell("gravel", -16 + (i % 8) * 4, 0, 40 + math.floor(i / 8) * 4)
	candidate.visible = false
	table.insert(fallbackOnly, candidate)
end
local fallback33 = cell("gravel", 0, 0, 140)
table.insert(fallbackOnly, fallback33)
selectTarget = scene(fallbackOnly, root.Position, rb.Vector3.new(0, 8, 140))
check(
	"occluded fallback page does not fabricate clearance",
	selectTarget("mine", { sand = true }) == nil
)
now += 0.6
previousRays = rays
check(
	"fallback search also reaches its33rd visible block",
	selectTarget("mine", { sand = true }) == fallback33
)
check("fallback continuation remains bounded", rays - previousRays <= 130)

local env = {
	itemConfirmed = false,
	seenButtons = {},
	gui = {},
	shortcut = {},
	visible = function()
		return true
	end,
}
local objects = {}
env.object = function(name)
	return objects[name]
end
local selector = {
	Name = "TextButton",
	attributes = {
		TutorialItemId = "shovel",
		TutorialItemTarget = "inv:7",
		TutorialSelected = true,
	},
}
function selector:IsA(kind)
	return kind == "GuiObject" or kind == "GuiButton"
end
function selector:GetAttribute(key)
	return self.attributes[key]
end
local clicked
selector.Activated = {
	Connect = function(_, fn)
		clicked = fn
	end,
}
env.gui.GetDescendants = function()
	return { selector }
end
local watch = closure("local function watch(", "local added =", "watch", env)
watch(selector) -- DescendantAdded occurs before caller assigns final Name/attributes.
selector.Name = "TutorialUpgradeItem"
local chooseControl =
	closure("local function chooseControl(", "local function watch(", "chooseControl", env)
local buy = { Name = "TutorialUpgrade" }
objects.TutorialUpgrade = buy
local selected, phase = chooseControl({ target = 7 })
check(
	"automatic default selection still points at actual shovel first",
	selected == selector and phase == "tutorial_choose_shovel"
)
check("late-named GuiButton gets real Activated observer", clicked ~= nil)
clicked()
selected, phase = chooseControl({ target = 7 })
check(
	"actual item Activated advances arrow to buy button",
	selected == buy and phase == "tutorial_buy_upgrade"
)
objects.TutorialUpgrade = nil
objects.Tile_upgrade = { Name = "Tile_upgrade" }
selected, phase = chooseControl({ target = 7 })
check(
	"menu points to upgrade tile and resets selection confirmation",
	selected == objects.Tile_upgrade and not env.itemConfirmed
)
objects.Tile_upgrade = nil
objects.MenuButton = { Name = "MenuButton" }
selected, phase = chooseControl({ target = 7 })
check(
	"closed menu points at actual menu button",
	selected == objects.MenuButton and phase == "tutorial_open_menu"
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	actualSourceClosures = true,
	realProfiles = false,
	realGeometry = false,
}))
