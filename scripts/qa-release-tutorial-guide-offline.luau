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
local parts, byPosition = {}, {}
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
local world = {}
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
function world:Raycast(at)
	rays += 1
	local part = byPosition[tostring(at)]
	return if part and part.exposed then { Instance = part } else nil
end
local selectTarget =
	closure("local cachedTarget:", "local function chooseControl", "chooseTarget", {
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
local picked = selectTarget("mine", "sand")
check("actual nearest existing exposed target selected", picked == parts[1])
local previousScans, previousRays = scans, rays
for _ = 1, 100 do
	selectTarget("mine", "sand")
end
check("cached target avoids 100 full 12000-cell scans", scans == previousScans)
check("cached target uses one bounded exposure ray per tick", rays - previousRays == 100)
parts[1].Parent = nil
now += 0.6
check(
	"another player's removed target retargets existing cell",
	selectTarget("mine", "sand") == parts[3]
)
parts[3].LocalTransparencyModifier = 1
now += 0.6
check("fast-hidden target is never retained", selectTarget("mine", "sand") == nil)
parts[1].Parent, parts[1].exposed = world, true
previousRays = rays
now += 0.6
check(
	"missing exposed requested material falls back to real clearance block",
	selectTarget("mine", "gravel") == parts[1]
)
check("retarget ray count capped despite 12000 candidates", rays - previousRays <= 64)
parts[1].exposed = false
previousScans = scans
check(
	"invalid target clears immediately and rescan is throttled",
	selectTarget("mine", "gravel") == nil and scans == previousScans
)
check("no task mode clears target", selectTarget(nil, nil) == nil)

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
	attributes = { TutorialItemId = "shovel", TutorialItemTarget = "inv:7", TutorialSelected = true },
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
print(
	serde.encode(
		"json",
		{
			status = "PASS",
			count = #checks,
			checks = checks,
			actualSourceClosures = true,
			realProfiles = false,
			realGeometry = false,
		}
	)
)
