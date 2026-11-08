--!nocheck
-- Run from the repository root: lune run scripts/qa-case-warzone-offline.luau
-- Real reward modules/configs and full builder; Lune supplies geometry, not Roblox rendering/physics.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local env = getfenv()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function execute(path, bindings, transform)
	local source = fs.readFile(path)
	if transform then
		source = transform(source)
	end
	local fn = assert(loadstring(source, "@" .. path))
	setfenv(fn, setmetatable(bindings, { __index = env }))
	return fn()
end
local Random = {}
local draws = 0
function Random.new(seed)
	local state = seed or 1729
	return {
		NextNumber = function(_, a, b)
			draws += 1
			state = (state * 16807) % 2147483647
			return (a or 0) + (state / 2147483647) * ((b or 1) - (a or 0))
		end,
		NextInteger = function(self, a, b)
			return math.floor(self:NextNumber(a, b + 1))
		end,
	}
end
local Config = {}
for _, name in ipairs({ "keys", "books", "tools", "artifacts", "rules" }) do
	Config[name] = serde.decode("json", fs.readFile("src/shared/Config/" .. name .. ".json"))
end
Config.tools = Config.tools.tools
Config.moneyScale = Config.rules.money.scale
local modules = { Config = Config, Types = {} }
local shared = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
for _, name in { "Numbers", "Persistence", "AncientRoll", "CaseRoll" } do
	modules[name] = execute("src/shared/" .. name .. ".luau", {
		script = { Parent = shared },
		require = function(id)
			return assert(modules[id], id)
		end,
	})
end
local gameMock = {
	GetService = function()
		return {
			Shared = shared,
			WaitForChild = function()
				return shared
			end,
		}
	end,
}
for _, name in ipairs({ "InventoryService", "BookTuning", "AncientCase" }) do
	modules[name] = execute("src/server/Services/" .. name .. ".luau", {
		game = gameMock,
		script = {
			Parent = setmetatable({}, {
				__index = function(_, k)
					return k
				end,
			}),
		},
		require = function(id)
			return assert(modules[id], id)
		end,
	})
end
local AncientCase = modules.AncientCase
local random, high, ordinaryLevels = Random.new(2042), 0, {}
local samples = 50000
for _ = 1, samples do
	local book = AncientCase.roll(true, random)
	check(book.level == 3 and book.books[1].level == 3, "Improved key yielded a lower-level book")
	check(#Config.books.effects[book.books[1].id] >= 3, "Unsupported III effect")
	check(book.applyChance >= 10 and book.applyChance <= 100, "Invalid application chance")
	if book.applyChance > 70 then
		high += 1
	end
end
check(high / samples > 0.09 and high / samples < 0.11, "High application chance is not rare")
for _ = 1, 1000 do
	local book = AncientCase.roll(false, random)
	ordinaryLevels[book.level] = true
	check(book.level <= #Config.books.effects[book.books[1].id], "Ordinary unsupported level")
end
check(ordinaryLevels[1] and ordinaryLevels[2] and ordinaryLevels[3], "Ordinary key lost a level")
local book = AncientCase.roll(true, random)
local function profile(keys, fullBag, fullChest)
	local p = { inventory = {}, caseContents = { ancientCase = {} } }
	if fullBag then
		for slot = 1, 36 do
			p.inventory[slot] = { id = "pickaxe", count = 1, level = 1 }
		end
	end
	p.inventory[1] = { id = "improved_ancient_key", count = keys }
	if fullChest then
		for slot = 1, 27 do
			p.caseContents.ancientCase[slot] = table.clone(book)
		end
	end
	return p
end
local p = profile(2)
check(
	AncientCase.deliver(p, "improved_ancient_key", book) == "inventory",
	"Book not sent to inventory"
)
check(
	p.inventory[2].books == book.books and p.inventory[2].applyChance == book.applyChance,
	"Book metadata lost"
)
check(
	p.inventory[1].count == 1 and next(p.caseContents.ancientCase) == nil,
	"Wrong key cost or duplicate reward"
)
p = profile(1, true, true)
check(
	AncientCase.deliver(p, "improved_ancient_key", book) == "inventory",
	"Consumed last key did not free its slot"
)
check(p.inventory[1].id == "ancient_book", "Last key slot not reused")
p = profile(2, true)
check(
	AncientCase.deliver(p, "improved_ancient_key", book) == "case",
	"Full bag did not use overflow"
)
check(
	p.caseContents.ancientCase[1].applyChance == book.applyChance and p.inventory[1].count == 1,
	"Overflow metadata/cost"
)
p = profile(2, true, true)
local before = serde.encode("json", p)
check(
	AncientCase.deliver(p, "improved_ancient_key", book) == "case_full",
	"Full containers accepted a roll"
)
check(serde.encode("json", p) == before, "Failed roll mutated the profile")
check(AncientCase.deliver(p, "ancient_key", book) == "case_no_key", "Wrong key accepted")
check(serde.encode("json", p) == before, "Missing key mutated the profile")
print(
	string.format(
		"Ancient case PASS: %d improved rolls, %.2f%% above 70; ordinary levels and atomic delivery",
		samples,
		high / samples * 100
	)
)

-- Lune does not implement Roblox's Position alias. Supply only that alias under a custom name;
-- the layout source substitutes the property name, leaving its geometry/operations unchanged.
roblox.implementProperty("BasePart", "QaPosition", function(part)
	return part.CFrame.Position
end, function(part, value)
	part.CFrame = roblox.CFrame.new(value) * part.CFrame.Rotation
end)
local workspace = roblox.Instance.new("Folder")
workspace.Name = "Workspace"
local collection = {
	AddTag = function(_, p, tag)
		p:AddTag(tag)
	end,
	HasTag = function(_, p, tag)
		return p:HasTag(tag)
	end,
}
-- Exercise the actual server session flow as well as the delivery helper.
local currentProfile, messages, serverClock = nil, {}, 100
local randomAllowed = true
local remotes = {
	event = function(name)
		return {
			FireClient = function(_, _, ...)
				table.insert(messages, { name = name, args = { ... } })
			end,
		}
	end,
}
local mockModules = setmetatable({
	ProfileService = {
		Get = function()
			return currentProfile
		end,
		Mutate = function(_, callback)
			callback(currentProfile)
		end,
	},
	Remotes = remotes,
	Sfx = { broadcast = function() end },
	ArtifactService = {
		Notify = function() end,
		GrantFragment = function()
			return {}
		end,
	},
	CommercePolicyService = {
		CanRandom = function()
			return randomAllowed
		end,
		RequireRandom = function()
			return randomAllowed
		end,
	},
	Strings = {
		localeOf = function()
			return "en"
		end,
		t = function(key)
			return key
		end,
		itemName = function(id)
			return id
		end,
		money = tostring,
	},
	Vault = {
		slot = function(_, index)
			return index
		end,
	},
}, {
	__index = function(_, name)
		return modules[name] or {}
	end,
})
local names = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
local caseGame = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return collection
		end
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function()
					return names
				end,
			}
		end
		return {}
	end,
}
local flow = execute("src/server/Services/CaseService.luau", {
	game = caseGame,
	workspace = workspace,
	Random = Random,
	Vector3 = roblox.Vector3,
	script = { Parent = names },
	require = function(name)
		return mockModules[name]
	end,
	os = {
		clock = function()
			return serverClock
		end,
	},
}, function(source)
	return (
		source:gsub("%.Position", ".QaPosition"):gsub(
			"return CaseService%s*$",
			"return {open=openChest,roll=openCase,close=close,validate=validate,move=move}"
		)
	)
end)
local part = roblox.Instance.new("Part")
part.CFrame = roblox.CFrame.new()
part.Parent = workspace
part:AddTag("AncientCase")
local character = roblox.Instance.new("Model")
character.Parent = workspace
local humanoid = roblox.Instance.new("Humanoid")
humanoid.Health = 20
humanoid.Parent = character
local playerRoot = roblox.Instance.new("Part")
playerRoot.Name = "HumanoidRootPart"
playerRoot.CFrame = part.CFrame
playerRoot.Parent = character
local player = {
	Name = "OfflineQA",
	Character = character,
	GetAttribute = function()
		return nil
	end,
}
local function fresh(keys, full)
	currentProfile = profile(keys, full)
	currentProfile.selectedSlot = 1
	currentProfile.coins = 0
	serverClock += 10
	messages = {}
end
local function eventCount(name)
	local count = 0
	for _, event in ipairs(messages) do
		if event.name == name then
			count += 1
		end
	end
	return count
end
fresh(2)
randomAllowed = false
local beforeDraws = draws
flow.open(player, part)
flow.roll(player, "ancientCase", "improved_ancient_key")
check(eventCount("CaseOpened") == 1, "Restricted user cannot inspect the case")
check(
	currentProfile.inventory[1].count == 2
		and draws == beforeDraws
		and eventCount("AncientRoll") == 0,
	"Restricted prompt or direct remote spent a key or rolled"
)
flow.close(player)
randomAllowed = true
fresh(2)
flow.open(player, part)
check(
	eventCount("AncientRoll") == 1 and eventCount("CaseOpened") == 0,
	"Direct reward opened a modal chest"
)
check(currentProfile.inventory[2].id == "ancient_book", "Direct reward missing before roulette")
flow.open(player, part)
flow.roll(player, "ancientCase", "improved_ancient_key")
check(
	currentProfile.inventory[1].count == 1 and eventCount("AncientRoll") == 1,
	"Reopened session bypassed roulette cooldown"
)
fresh(2, true)
flow.open(player, part)
check(
	eventCount("AncientRoll") == 1 and eventCount("CaseOpened") == 0,
	"Overflow blocked movement during roulette"
)
check(currentProfile.caseContents.ancientCase[1] ~= nil, "Missing overflow")
playerRoot.CFrame = roblox.CFrame.new(100, 0, 0)
check(flow.validate(player, "ancientCase") == nil, "Remote move accepted outside case range")
check(currentProfile.caseContents.ancientCase[1] ~= nil, "Walking away discarded overflow")
playerRoot.CFrame = part.CFrame
currentProfile.inventory[1] = nil -- no key; still must be able to claim the previous reward
flow.open(player, part)
check(eventCount("CaseOpened") == 1, "Overflow could not be reopened without a key")
flow.move(
	player,
	"ancientCase",
	{ container = "inv", index = 2 },
	{ container = "case", index = 2 }
)
check(currentProfile.caseContents.ancientCase[2] == nil, "Overflow accepted a storage deposit")
flow.move(player, "ancientCase", { container = "case", index = 1 }, "quick")
flow.move(player, "ancientCase", { container = "case", index = 1 }, "quick")
check(
	currentProfile.inventory[1].id == "ancient_book"
		and next(currentProfile.caseContents.ancientCase) == nil,
	"Claim did not transfer exactly once"
)
check(
	modules.InventoryService.count(currentProfile, "ancient_book") == 1,
	"Replayed claim duplicated the book"
)
flow.close(player)
part:RemoveTag("AncientCase")
part:AddTag("OrdinaryCase")
fresh(2)
currentProfile.inventory[1] = { id = "ordinary_key", count = 2 }
local contents = {}
for slot = 1, 24 do
	contents[slot] = { id = "apple", count = 1 }
end
currentProfile.caseContents.ordinaryCase = contents
beforeDraws = draws
flow.open(player, part)
check(
	currentProfile.inventory[1].count == 2 and draws == beforeDraws,
	"Ordinary case with three free slots must refuse before RNG or debit"
)
check(messages[#messages - 1].args[1] == "case_space_rolls", "Capacity failure has no reason")
contents[24] = nil
serverClock += 1
flow.roll(player, "ordinaryCase", "ordinary_key")
check(
	currentProfile.inventory[1].count == 1 and draws > beforeDraws,
	"Four free slots allow one ordinary opening"
)
flow.close(player)
part:Destroy()
character:Destroy()
print(
	"CaseService PASS: non-modal direct/overflow rolls, cooldown, distance close, no-key recovery, withdrawal-only and replay-safe claim"
)

local textures = serde.decode("json", fs.readFile("src/shared/Config/textures.json"))
local gameMap = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return collection
		end
		if name == "RunService" then
			return {
				IsRunning = function()
					return false
				end,
			}
		end
		return { Shared = { WarzoneLayout = "layout", Config = { textures = "textures" } } }
	end,
}
local bindings =
	{ game = gameMap, workspace = workspace, Random = Random, task = { wait = function() end } }
for _, name in ipairs({ "Instance", "CFrame", "Vector3", "Vector2", "Color3", "Enum", "UDim2" }) do
	bindings[name] = roblox[name]
end
local layout = execute("src/shared/WarzoneLayout.luau", bindings, function(source)
	return (source:gsub("%.Position", ".QaPosition"))
end)
bindings.require = function(id)
	return if id == "textures" then textures else layout
end
execute("scripts/build-warzone.luau", bindings)
local root = workspace:FindFirstChild("Warzone")
local count = #root:GetDescendants()
check(not layout.apply(root) and #root:GetDescendants() == count, "Layout repair is not idempotent")
local anchors, surfaces = {}, {}
local surfaceNames = {
	Grass = true,
	RoadNS = true,
	RoadEW = true,
	Sidewalk = true,
	Square = true,
	Driveway = true,
	DoorWalk = true,
	Path = true,
	PadRim = true,
}
local function extents(p)
	local cf, h = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local e = roblox.Vector3.new(
		math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
		math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
		math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
	)
	return cf.Position - e, cf.Position + e
end
local function overlapsXZ(a, b, c, d)
	return a.X < d.X - 0.01 and b.X > c.X + 0.01 and a.Z < d.Z - 0.01 and b.Z > c.Z + 0.01
end
for _, part in ipairs(root:GetDescendants()) do
	if part:IsA("BasePart") then
		if part:HasTag("MineAnchor") then
			table.insert(anchors, part)
		end
		if surfaceNames[part.Name] then
			table.insert(surfaces, part)
		end
	end
end
check(#anchors == 4, "Wrong mine count")
for _, anchor in ipairs(anchors) do
	local a, b = extents(anchor)
	for _, part in ipairs(root:GetDescendants()) do
		if
			part:IsA("BasePart")
			and part ~= anchor
			and part.Transparency < 1
			and part.Name ~= "Ladder"
		then
			local c, d = extents(part)
			check(
				not (d.Y > b.Y + 0.05 and c.Y < b.Y + 30 and overlapsXZ(a, b, c, d)),
				"Obstructed mine: " .. anchor.Name .. " / " .. part.Name
			)
		end
	end
end
for i, part in ipairs(surfaces) do
	local a, b = extents(part)
	for j = i + 1, #surfaces do
		local c, d = extents(surfaces[j])
		check(
			not overlapsXZ(a, b, c, d),
			"Overlapping ground: " .. part.Name .. " / " .. surfaces[j].Name
		)
	end
end
print(
	string.format(
		"Дворы PASS: %d parts/instances, four unobstructed mine tops, %d disjoint terrain pieces, idempotent repair; %d assertions total",
		count,
		#surfaces,
		checks
	)
)
