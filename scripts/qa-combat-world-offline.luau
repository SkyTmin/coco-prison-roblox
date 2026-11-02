--!nocheck
-- Lune: actual service sources with isolated engine/profile mocks; no live Roblox access.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rbx = require("@lune/roblox")
local env = getfenv()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local active = true
			table.insert(callbacks, function(...)
				if active then
					fn(...)
				end
			end)
			return {
				Disconnect = function()
					active = false
				end,
			}
		end,
		Once = function(self, fn)
			return self:Connect(fn)
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(callbacks) do
				fn(...)
			end
		end,
	}
end
local function node(class, name, parent)
	local n = { ClassName = class, Name = name, Parent = parent, children = {}, attributes = {} }
	if parent and parent.children then
		table.insert(parent.children, n)
	end
	function n:IsA(want)
		return want == class or (want == "BasePart" and class == "Part")
	end
	function n:GetChildren()
		return self.children
	end
	function n:FindFirstChild(want, recursive)
		for _, child in ipairs(self.children) do
			if child.Name == want then
				return child
			end
			if recursive then
				local found = child:FindFirstChild(want, true)
				if found then
					return found
				end
			end
		end
		return nil
	end
	function n:WaitForChild(want)
		return self:FindFirstChild(want)
	end
	function n:FindFirstChildOfClass(want)
		for _, child in ipairs(self.children) do
			if child:IsA(want) then
				return child
			end
		end
		return nil
	end
	function n:GetAttribute(key)
		return self.attributes[key]
	end
	function n:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function n:IsDescendantOf(ancestor)
		local p = self.Parent
		while p do
			if p == ancestor then
				return true
			end
			p = p.Parent
		end
		return false
	end
	function n:GetPivot()
		return self.PrimaryPart.CFrame
	end
	function n:PivotTo(cf)
		self.PrimaryPart.CFrame, self.PrimaryPart.Position = cf, cf.Position
	end
	function n:GetBoundingBox()
		return self.PrimaryPart.CFrame, rbx.Vector3.new(4, 5, 2)
	end
	function n:Destroy()
		self.Parent = nil
	end
	return n
end
local clock = 10
local dice = 0.99
local mockOs = table.clone(os)
mockOs.clock = function()
	return clock
end
mockOs.time = function()
	return 1000 + math.floor(clock)
end
local mockMath = table.clone(math)
mockMath.random = function()
	return dice
end
local delayed = {}
local taskMock = {
	spawn = function() end,
	defer = function() end,
	delay = function(_, fn, ...)
		table.insert(delayed, { fn = fn, args = { ... } })
	end,
}
local world = node("Workspace", "Workspace")
world.StreamingEnabled = false
world.GetServerTimeNow = function()
	return clock
end
local grounded = true
world.Raycast = function(_, _, delta)
	if delta.Y < 0 and math.abs(delta.X) < 1e-6 and math.abs(delta.Z) < 1e-6 and grounded then
		return { Instance = node("Part", "Ground", world) }
	end
	return nil
end
local tags = {}
local collection = {
	AddTag = function(_, item, tag)
		tags[tag] = tags[tag] or {}
		if not table.find(tags[tag], item) then
			table.insert(tags[tag], item)
		end
	end,
	HasTag = function(_, item, tag)
		return table.find(tags[tag] or {}, item) ~= nil
	end,
	GetTagged = function(_, tag)
		return tags[tag] or {}
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
	GetInstanceRemovedSignal = function()
		return signal()
	end,
}
local playersList = {}
local players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return playersList
	end,
	GetPlayerFromCharacter = function(_, model)
		return model.player
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in ipairs(playersList) do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
}
local shared = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
shared.WaitForChild = function(_, key)
	return key
end
local replicated = {
	Shared = shared,
	WaitForChild = function()
		return shared
	end,
}
local services = {
	Players = players,
	CollectionService = collection,
	ReplicatedStorage = replicated,
	HttpService = {},
	RunService = {
		Heartbeat = signal(),
		IsStudio = function()
			return false
		end,
	},
	ServerStorage = {},
}
local gameMock = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
local modules = {}
local remotes = {}
local function remote(name)
	if not remotes[name] then
		remotes[name] = {
			OnServerEvent = signal(),
			calls = {},
			FireClient = function(self, ...)
				table.insert(self.calls, { ... })
			end,
		}
	end
	return remotes[name]
end
modules.Remotes = { event = remote, unreliable = remote }
modules.Strings = {
	t = function(key)
		return key
	end,
	localeOf = function()
		return "en"
	end,
	money = tostring,
}
modules.Types = {}
modules.Sfx = { broadcast = function() end, toPlayer = function() end }
modules.Ladders = {
	near = function()
		return nil
	end,
}
modules.Cobweb = {
	holds = function()
		return false
	end,
	start = function() end,
}
modules.Effects = {
	UNTIL = "Until",
	SPRINT_MIN_HUNGER = 6,
	SPRINT = 1.3,
	SLOWNESS_PER_LEVEL = 0.15,
	SPEED_PER_LEVEL = 0.2,
	FROST_PER_STACK = 0.1,
	HULK_SLOWNESS = 0.1,
	level = function(model, id)
		return model and (model:GetAttribute(id) or 0) or 0
	end,
	active = function()
		return {}
	end,
	byId = function(id)
		return { attribute = id:sub(1, 1):upper() .. id:sub(2) }
	end,
}
modules.ProfileService = {
	Get = function(p)
		return p.profile
	end,
	Mutate = function(p, fn)
		if p.profile then
			fn(p.profile)
		end
	end,
}
modules.GangService = {
	gangOf = function(p)
		return p and p.gang
	end,
	level = function(p)
		return p and p.gang and 1 or 0
	end,
	allies = function()
		return false
	end,
}
modules.HurtService = {
	Damage = function(h, amount)
		h.Health = math.max(0, h.Health - amount)
	end,
	Knockback = function() end,
}
modules.BossDamage = {
	Limit = function(_, amount)
		return amount
	end,
}
modules.BookService = {
	outgoing = function(_, _, _, damage)
		return damage, {}
	end,
	incoming = function(_, _, damage)
		return damage
	end,
	afterHit = function() end,
	afterHurt = function() end,
	bonusHealth = function(p)
		return p.tankBonus or 0
	end,
}
modules.Books = {
	worn = function()
		return 0
	end,
}
modules.Potions = {}
modules.Boosters = {}
modules.Donate = {}
modules.SkillService = {}
modules.ChatService = { announceWith = function() end }
modules.AchievementService = {}
modules.FactionService = {
	Of = function(p)
		return p.profile and p.profile.faction
	end,
}
local base = {
	game = gameMock,
	workspace = world,
	os = mockOs,
	math = mockMath,
	task = taskMock,
	Vector3 = rbx.Vector3,
	CFrame = rbx.CFrame,
	Color3 = rbx.Color3,
	Enum = rbx.Enum,
	Instance = rbx.Instance,
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	OverlapParams = {
		new = function()
			return {}
		end,
	},
	Random = {
		new = function()
			return {
				NextNumber = function()
					return 0.5
				end,
				NextInteger = function(_, a)
					return a
				end,
			}
		end,
	},
	script = { Parent = shared, Services = shared },
	require = function(id)
		return assert(modules[id], tostring(id))
	end,
}
local function execute(path, additions, transform)
	local text = fs.readFile(path)
	if transform then
		text = transform(text)
	end
	local bindings = table.clone(base)
	for key, value in pairs(additions or {}) do
		bindings[key] = value
	end
	local fn = assert(loadstring(text, "@" .. path))
	setfenv(fn, setmetatable(bindings, { __index = env }))
	return fn()
end
local function expose(module, exports)
	return function(source)
		return source:gsub("return " .. module .. "%s*$", exports .. "\nreturn " .. module)
	end
end
modules.Config = execute("src/shared/Config/init.luau", {
	script = {
		WaitForChild = function(_, name)
			return name
		end,
	},
	require = function(name)
		return serde.decode("json", fs.readFile("src/shared/Config/" .. name .. ".json"))
	end,
})
modules.Numbers = execute("src/shared/Numbers.luau")
modules.InventoryService = execute("src/server/Services/InventoryService.luau")
modules.Combat = execute("src/shared/Combat.luau")
modules.DamageImmunity = execute("src/server/Services/DamageImmunity.luau")
modules.TrainerService = execute("src/server/Services/TrainerService.luau")
modules.MotionTiming = execute("src/shared/MotionTiming.luau")
modules.MotionService = execute(
	"src/server/Services/MotionService.luau",
	nil,
	expose("MotionService", "MotionService._report = onMotion")
)
modules.CombatService = execute(
	"src/server/Services/CombatService.luau",
	nil,
	expose("CombatService", "CombatService._attack = onAttack")
)
local function character(player)
	local model = node("Model", "Character", world)
	model.player = player
	local root = node("Part", "HumanoidRootPart", model)
	root.CFrame, root.Position, root.Size =
		rbx.CFrame.new(0, 3, 0), rbx.Vector3.new(0, 3, 0), rbx.Vector3.new(2, 2, 2)
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = rbx.Vector3.zero, rbx.Vector3.zero
	model.PrimaryPart = root
	local head = node("Part", "Head", model)
	head.Position = rbx.Vector3.new(0, 4.5, 0)
	local h = node("Humanoid", "Humanoid", model)
	h.Health, h.MaxHealth, h.HipHeight, h.WalkSpeed, h.FloorMaterial =
		100, 100, 2, 16, rbx.Enum.Material.Concrete
	h.Died = signal()
	h.GetState = function()
		return rbx.Enum.HumanoidStateType.Running
	end
	return model, h, root
end
local p = node("Player", "Test")
p.UserId, p.CharacterAdded = 1, signal()
p.GetAttributeChangedSignal = function()
	return signal()
end
p.profile = {
	level = 50,
	location = "ghetto",
	coins = 0,
	hunger = 20,
	needs = { hygiene = 100, toilet = 100, sleep = 100 },
	inventory = { [1] = { id = "sword", level = 1, count = 1 } },
	selectedSlot = 1,
	armor = {},
	trainer = { strength = 0, agility = 0 },
	passes = {},
	gang = { id = "A" },
}
p.Character = character(p)
playersList = { p }
local mob, mh, mr = character(nil)
mr.CFrame, mr.Position = rbx.CFrame.new(0, 3, -7), rbx.Vector3.new(0, 3, -7)
collection:AddTag(mob, "Mob")
modules.MotionService._report(
	p,
	p.Character.PrimaryPart.Position + rbx.Vector3.new(0, 10, 0),
	0,
	clock
)
clock += 0.03
modules.MotionService._report(
	p,
	p.Character.PrimaryPart.Position + rbx.Vector3.new(0, 9, 0),
	0,
	clock
)
check(
	(modules.MotionService.verticalSpeed(p) or 0) < -30,
	"Fixture must contain accepted forged falling reports"
)
modules.CombatService._attack(p, rbx.Vector3.new(0, 0, -1), true)
local function flushAttack()
	clock += 0.15
	local jobs = delayed
	delayed = {}
	for _, job in ipairs(jobs) do
		job.fn(table.unpack(job.args))
	end
end
flushAttack()
check(near(mh.Health, 96), "Grounded forged Motion reports must not grant a critical")
clock += 1
grounded = false
p.Character.PrimaryPart.AssemblyLinearVelocity = rbx.Vector3.new(0, -8, 0)
modules.CombatService._attack(p, rbx.Vector3.new(0, 0, -1), true)
flushAttack()
check(near(mh.Health, 90), "A real charged falling attack must retain its critical")
clock += 1
p.Character.PrimaryPart.AssemblyLinearVelocity = rbx.Vector3.new(0, 8, 0)
modules.CombatService._attack(p, rbx.Vector3.new(0, 0, -1), true)
flushAttack()
check(near(mh.Health, 86), "Ascending motion must not grant a critical")
grounded = true
for _, ranged in ipairs({ false, true }) do
	clock += 1
	p.profile.trainer.strength = 20
	mh.Health = 100
	modules.CombatService.HitModel(
		p,
		p.profile,
		mob,
		10,
		false,
		rbx.Vector3.new(0, 0, -1),
		nil,
		ranged
	)
	check(near(mh.Health, 86), "Paid Strength must affect both melee and arrow damage")
end
clock += 1
mh.Health = 100
modules.CombatService.HitModel(
	p,
	p.profile,
	mob,
	1,
	false,
	rbx.Vector3.new(0, 0, -1),
	nil,
	false,
	{ sweep = true }
)
check(near(mh.Health, 99), "Java secondary sweep retains its fixed one HP")
local ph = p.Character:FindFirstChildOfClass("Humanoid")
p.profile.trainer.agility = 20
dice = 0.19
clock += 1
ph.Health = 100
check(not modules.CombatService.ApplyDamage(ph, 10, "mob"), "Agility 20 must dodge a roll below .2")
check(ph.Health == 100, "Dodge must lose no health")
dice = 0.21
check(modules.CombatService.ApplyDamage(ph, 10, "boss"), "A non-dodged hit must still land")
check(ph.Health == 90, "A dodge must not consume hurt immunity for the next hit")
clock += 1
dice = 0
check(
	modules.CombatService.ApplyDamage(ph, 1, "player", nil, nil, false),
	"Burning is not a dodgeable strike"
)
dice = 0.99
p.profile.trainer.agility = 0

-- Run the actual bootstrap health-capacity block, without executing server startup.
local initText = fs.readFile("src/server/init.server.luau")
local capacity = assert(initText:match("local target = .-freshCharacters%[character%] = nil"))
local h = { Health = 1, MaxHealth = 20 }
local gear = { tankBonus = 0 }
local c = {}
local fresh = {}
local capacityFn = assert(loadstring(capacity))
setfenv(
	capacityFn,
	setmetatable({
		profile = gear,
		humanoid = h,
		character = c,
		freshCharacters = fresh,
		rule = { hearts = 10 },
		require = base.require,
		script = base.script,
	}, { __index = env })
)
for _ = 1, 6 do
	gear.tankBonus = 6
	capacityFn()
	gear.tankBonus = 0
	capacityFn()
end
check(h.Health == 1 and h.MaxHealth == 20, "Tank equip cycles must not manufacture health")
fresh[c] = true
gear.tankBonus = 6
capacityFn()
check(
	h.Health == 26 and h.MaxHealth == 26,
	"Fresh character still starts at its full trained/equipped capacity"
)
gear.tankBonus = 0
capacityFn()
check(
	h.Health == 20 and h.MaxHealth == 20,
	"Removing Tank must clamp health to the remaining capacity"
)

local Bow = execute(
	"src/server/Services/BowService.luau",
	nil,
	expose("BowService", "BowService._burn = burn; BowService._burning = burning")
)
ph.Health = 100
p.Character:SetAttribute("FireResistance", 1)
Bow._burning[ph] = { untilAt = clock + 8, nextAt = clock, by = p, model = p.Character }
Bow._burn()
check(ph.Health == 100, "Flame must not damage a fire-resistant player")
clock += 1
p.Character:SetAttribute("FireResistance", nil)
Bow._burn()
check(ph.Health == 99, "Flame resumes after resistance expires")
clock += 1
p.Character:SetAttribute("FireResistance", 1)
Bow._burn()
check(ph.Health == 99, "Resistance acquired after ignition must stop fire damage")
p.Character:SetAttribute("FireResistance", nil)

modules.NeedsService = execute(
	"src/server/Services/NeedsService.luau",
	nil,
	expose("NeedsService", "NeedsService._states = states; NeedsService._timed = timed")
)
local Needs = modules.NeedsService
Needs._states[p] = { previous = {}, movementMultiplier = 1, sprinting = false }
Needs.Start()
modules.Warzone = { cfg = modules.Config.warzone, points = modules.Config.warzone.points }
local Warzone = execute(
	"src/server/Services/WarzoneService.luau",
	nil,
	expose(
		"WarzoneService",
		"WarzoneService._points = points; WarzoneService._refresh = refreshHaste"
	)
)
p.profile.faction = "slavs"
Warzone._points.haste = { def = { effect = "haste" }, owner = "slavs", untilAt = clock + 1800 }
Warzone._refresh()
check(p.Character:GetAttribute("Haste") == 1, "Current faction member gets owned-point Haste")
local oldCharacter = p.Character
p.Character = character(p)
p.CharacterAdded:Fire(p.Character)
Warzone._refresh()
check(
	p.Character ~= oldCharacter and p.Character:GetAttribute("Haste") == 1,
	"Respawned member gets Haste again"
)
Needs.GiveEffect(p, "haste", 2, 12)
check(p.Character:GetAttribute("Haste") == 2, "Stronger personal Haste wins")
p.profile.faction = nil
Warzone._refresh()
check(
	p.Character:GetAttribute("WarzoneHaste") == nil and p.Character:GetAttribute("Haste") == 2,
	"Faction removal revokes only the faction source"
)
clock += 13
Needs.Refresh(p)
check(
	p.Character:GetAttribute("Haste") == nil,
	"Former member has no point Haste after potion expiry"
)
p.profile.faction = "slavs"
Warzone._refresh()
check(p.Character:GetAttribute("Haste") == 1, "Rejoining current owner restores point source")
Warzone._points.haste.untilAt = clock
Warzone._refresh()
check(p.Character:GetAttribute("Haste") == nil, "Point expiry revokes its source")

modules.FallService = execute(
	"src/server/Services/FallService.luau",
	nil,
	expose("FallService", "FallService._step = step")
)
local Fall = modules.FallService
ph = p.Character:FindFirstChildOfClass("Humanoid")
local pr = p.Character.PrimaryPart
ph.Health = 100
pr.Position = rbx.Vector3.new(0, 1504, 0)
ph.FloorMaterial = rbx.Enum.Material.Concrete
for _ = 1, 8 do
	Fall._step()
end
Fall.Reset(p)
pr.Position = rbx.Vector3.new(0, 4, 0)
ph.FloorMaterial = rbx.Enum.Material.Air
Fall._step()
pr.Position = rbx.Vector3.new(0, 3, 0)
ph.FloorMaterial = rbx.Enum.Material.Concrete
Fall._step()
check(ph.Health == 100, "Authoritative downwards teleport must discard old height history")
Fall.Reset(p)
pr.Position = rbx.Vector3.new(0, 43, 0)
ph.FloorMaterial = rbx.Enum.Material.Air
Fall._step()
pr.Position = rbx.Vector3.new(0, 3, 0)
ph.FloorMaterial = rbx.Enum.Material.Concrete
Fall._step()
check(ph.Health == 93, "A real 10-block fall after reset still deals seven HP")

-- Real LocationService channel and GhettoMineService claim, with no inventory change on failed/cancelled channels.
modules.CombatService = {
	inCombat = function()
		return false
	end,
}
modules.LocationService = execute(
	"src/server/Services/LocationService.luau",
	nil,
	expose(
		"LocationService",
		"LocationService._channels = updateChannels; LocationService._pending = pending"
	)
)
local Locations = modules.LocationService
local ghetto = node("Folder", "Ghetto", world)
local rooms = node("Folder", "GangMineRooms", ghetto)
local room = node("Model", "Room", rooms)
local anchor = node("Part", "Anchor", room)
anchor:SetAttribute("MineId", "ghetto_private_1")
local arrival = node("Part", "Arrival", room)
arrival.CFrame = rbx.CFrame.new(0, 100, 0)
arrival.Position = arrival.CFrame.Position
arrival:SetAttribute("LocationId", "ghetto")
arrival:SetAttribute("PrivateArrival", true)
collection:AddTag(arrival, "LocationSpawn")
local public = node("Part", "LocationSpawn_ghetto", ghetto)
public.CFrame = rbx.CFrame.new(100, 200, 0)
public.Position = public.CFrame.Position
public:SetAttribute("LocationId", "ghetto")
collection:AddTag(public, "LocationSpawn")
local mine = { rebuilding = false, dug = 0 }
modules.MineService = {
	get = function()
		return mine
	end,
}
local Ghetto = execute(
	"src/server/Services/GhettoMineService.luau",
	nil,
	expose("Service", "Service._enter = enter")
)
p.profile.faction = nil
p.profile.inventory[2] = { id = "gang_mine_pass", count = 3 }
playersList = { p, { profile = { gang = { id = "A" } } }, { profile = { gang = { id = "A" } } } }
clock += 1
pr.Position = rbx.Vector3.zero
pr.CFrame = rbx.CFrame.new()
ph.Health = 100
Ghetto._enter(p, p.profile.gang)
check(
	p.profile.inventory[2].count == 3 and anchor:GetAttribute("GangMineOwner") == nil,
	"Starting channel must not spend pass or start lease"
)
pr.Position = rbx.Vector3.new(20, 0, 0)
Locations._channels()
check(
	Locations._pending[p] == nil and p.profile.inventory[2].count == 3,
	"Cancelled channel must not spend pass"
)
clock += 1
Ghetto._enter(p, p.profile.gang)
clock += 6
Locations._channels()
check(
	p.profile.inventory[2].count == 2 and anchor:GetAttribute("GangMineOwner") == "A",
	"Successful arrival charges exactly one pass"
)
check(pr.Position.Y == 104, "Successful private channel reaches its chosen room")
clock += 1
Ghetto._enter(p, p.profile.gang)
clock += 6
Locations._channels()
check(p.profile.inventory[2].count == 2, "Active same-gang reentry is free")
clock += 1
Locations.Request(p, "ghetto")
clock += 6
Locations._channels()
check(
	pr.Position.X == 100 and pr.Position.Y == 204,
	"Public Ghetto teleport must never select a private room"
)
anchor:SetAttribute("GangMineUntil", 0)
clock += 1
Ghetto._enter(p, p.profile.gang)
anchor:SetAttribute("GangMineOwner", "B")
anchor:SetAttribute("GangMineUntil", mockOs.time() + 600)
clock += 6
Locations._channels()
check(
	p.profile.inventory[2].count == 2 and pr.Position.X == 100,
	"Concurrent foreign claim must cancel without consuming pass"
)
anchor:SetAttribute("GangMineUntil", 0)
tags.LocationSpawn = { public }
clock += 1
Ghetto._enter(p, p.profile.gang)
clock += 6
Locations._channels()
check(
	p.profile.inventory[2].count == 2 and anchor:GetAttribute("GangMineUntil") == 0,
	"Invalid untagged arrival must not charge or lease"
)
collection:AddTag(arrival, "LocationSpawn")
clock += 1
Ghetto._enter(p, p.profile.gang)
playersList = { p }
clock += 6
Locations._channels()
check(
	p.profile.inventory[2].count == 2 and anchor:GetAttribute("GangMineUntil") == 0,
	"Losing minimum online members during channel must not charge or lease"
)
anchor:SetAttribute("GangMineOwner", "A")
anchor:SetAttribute("GangMineUntil", mockOs.time() + 3)
clock += 1
Ghetto._enter(p, p.profile.gang)
clock += 6
Locations._channels()
check(
	p.profile.inventory[2].count == 2 and pr.Position.X == 100,
	"Expired free reentry must not silently purchase another lease"
)

-- Actual idempotent map repair on Lune instances (Position alias only is replaced by equivalent CFrame.Position).
local Layout = execute("src/shared/GhettoLayout.luau", nil, function(s)
	return s:gsub("public%.Position", "public.CFrame.Position")
end)
local map = rbx.Instance.new("Folder")
map.Name = "Ghetto"
local rs = rbx.Instance.new("Folder")
rs.Name, rs.Parent = "GangMineRooms", map
for i = 1, 4 do
	local rm = rbx.Instance.new("Model")
	rm.Name, rm.Parent = "Room" .. i, rs
	local a = rbx.Instance.new("Part")
	a.Name, a.Parent = "Arrival", rm
end
local result = Layout.apply(map, rbx.Vector3.new(11400, 15000, 4000))
check(
	result.arrivals == 4 and result.batsCreated == 5,
	"Map patch repairs all four rooms and creates five bats"
)
result = Layout.apply(map, rbx.Vector3.new(11400, 15000, 4000))
check(result.arrivals == 4 and result.batsCreated == 0, "Map patch is idempotent")
for _, rm in ipairs(rs:GetChildren()) do
	local a = rm:FindFirstChild("Arrival")
	check(
		a:GetAttribute("PrivateArrival") == true and collection:HasTag(a, "LocationSpawn"),
		"Patched arrival keeps private routing tag"
	)
end
local inferred = rbx.Instance.new("Folder")
local publicPart = rbx.Instance.new("Part")
publicPart.Name, publicPart.Parent = "LocationSpawn_ghetto", inferred
publicPart.CFrame = rbx.CFrame.new(11400, 15000.6, 4206)
result = Layout.apply(inferred)
local firstBat = inferred:FindFirstChild("MobSpawns"):FindFirstChild("MobSpawn_bat_1")
check(
	result.batsCreated == 5
		and (firstBat.CFrame.Position - rbx.Vector3.new(11466, 15000.8, 3905)).Magnitude < 0.01,
	"Cloud patch infers the same raised origin from the public arrival"
)
print(
	string.format(
		"Combat/world actual-source fixtures PASS: %d checks; mocked engine, no Studio",
		checks
	)
)
