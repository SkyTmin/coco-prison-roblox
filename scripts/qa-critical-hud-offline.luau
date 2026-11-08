--!nocheck
-- Actual BossHud/WarzoneHud callbacks; isolated GUI, player, replicated-state and clock boundaries.
-- No Studio, remotes, real profiles or world mutations.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function signal()
	local callbacks = {}
	local event = {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in table.clone(callbacks) do
				if entry.active then
					entry.fn(...)
				end
			end
		end,
	}
	function event:Once(fn)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end
	return event
end
local function node(kind, name)
	local attrs, events, children, values = {}, {}, {}, {}
	local n = { ClassName = kind, Name = name or kind, Visible = true, Enabled = true }
	function n:GetChildren()
		return children
	end
	function n:FindFirstChild(id)
		for _, child in children do
			if child.Name == id then
				return child
			end
		end
	end
	function n:WaitForChild(id)
		return assert(self:FindFirstChild(id), id)
	end
	function n:IsA(id)
		return id == kind or id == "BasePart" and kind == "Part"
	end
	function n:GetAttribute(id)
		return attrs[id]
	end
	function n:GetAttributeChangedSignal(id)
		events[id] = events[id] or signal()
		return events[id]
	end
	function n:SetAttribute(id, value)
		local old = attrs[id]
		attrs[id] = value
		if old ~= value and events[id] then
			events[id]:Fire()
		end
	end
	n.AncestryChanged, n.Destroying = signal(), signal()
	return setmetatable(n, {
		__index = values,
		__newindex = function(self, key, value)
			if key == "Parent" then
				values.Parent = value
				if value then
					table.insert(value:GetChildren(), self)
				end
			else
				rawset(self, key, value)
			end
		end,
	})
end
local player, gui = node("Player"), node("ScreenGui")
gui.AbsolutePosition, gui.AbsoluteSize = rb.Vector2.new(0, -58), rb.Vector2.new(705, 338)
local character, root = node("Model"), node("Part", "HumanoidRootPart")
root.Parent, root.Position = character, rb.Vector3.zero
player.Character = character
player:SetAttribute("Faction", "red")
local replicated, shared = node("Folder"), node("Folder", "Shared")
shared.Parent = replicated
for _, id in { "Strings", "Config", "Warzone" } do
	shared[id] = id
end
local folder, boss = node("Folder", "Bosses"), node("Folder", "test_boss")
folder.Parent, boss.Parent = replicated, folder
for key, value in { Origin = rb.Vector3.zero, ArenaRadius = 40, Health = 75, MaxHealth = 100 } do
	boss:SetAttribute(key, value)
end
local beacon = node("Part", "Beacon")
beacon.Position = rb.Vector3.zero
beacon:SetAttribute("Point", "money")
local capture =
	{ active = true, lead = 1, leader = "red", scores = { red = 1 }, need = 100, untilAt = 100 }
local now, heartbeat = 0, signal()
local function label(parent, text, size, position)
	local object = node("TextLabel")
	object.Parent, object.Text, object.Size, object.Position = parent, text, size, position
	return object
end
local modules = {
	Strings = {
		localeOf = function()
			return "en"
		end,
		bossName = function()
			return "Test boss"
		end,
		t = function(key)
			return key
		end,
	},
	Config = {
		faction = function(id)
			return id == "red"
		end,
		factionColor = function()
			return rb.Color3.new(1, 0, 0)
		end,
	},
	Warzone = {
		POINT_TAG = "WarzonePoint",
		point = function()
			return true
		end,
		state = function()
			return capture
		end,
	},
	Ui = {
		colors = {
			panel = rb.Color3.new(),
			white = rb.Color3.new(1, 1, 1),
			red = rb.Color3.new(1, 0, 0),
		},
		label = label,
		rich = label,
		hex = function()
			return "#ff0000"
		end,
	},
}
local services = {
	CollectionService = {
		GetTagged = function(_, tag)
			return if tag == "WarzonePoint" then { beacon } else {}
		end,
		GetInstanceAddedSignal = function()
			return signal()
		end,
	},
	Players = { LocalPlayer = player },
	ReplicatedStorage = replicated,
	RunService = { Heartbeat = heartbeat },
	GuiService = {
		GetGuiInset = function()
			return rb.Vector2.new(0, 58)
		end,
	},
}
for _, id in { "BossHud", "WarzoneHud" } do
	local fn = assert(loadstring(fs.readFile("src/client/" .. id .. ".luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, key)
					return assert(services[key], key)
				end,
			},
			script = { Parent = { Ui = "Ui" } },
			require = function(key)
				return assert(modules[key], key)
			end,
			Instance = { new = node },
			Vector2 = rb.Vector2,
			Vector3 = rb.Vector3,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Color3 = rb.Color3,
			Enum = rb.Enum,
			os = {
				clock = function()
					return now
				end,
			},
			workspace = {
				GetServerTimeNow = function()
					return now
				end,
			},
		}, { __index = getfenv() })
	)
	fn().Start(gui)
end
local bossBar, hint =
	assert(gui:FindFirstChild("BossBar")), assert(gui:FindFirstChild("WarzoneHint"))
local function step(seconds)
	now += seconds or 0.3
	heartbeat:Fire()
end
local function lane(x, y, width, height)
	for key, value in { X = x, Y = y, Width = width, Height = height } do
		player:SetAttribute("HudNotification" .. key, value)
	end
end
lane(236, 8, 243, 52)
step()
check("eligible Warzone owns notice lane", hint.Visible and player:GetAttribute("HudWarzoneActive"))
check(
	"no live boss does not reserve notice lane",
	not bossBar.Visible and not player:GetAttribute("HudBossActive")
)
check("Warzone converts absolute y8 into local y66", hint.Position.Y.Offset == 66)
check("Warzone uses bounded243x52 lane", hint.Size == rb.UDim2.fromOffset(243, 52))
boss:SetAttribute("Alive", true)
step(0.01) -- Warzone throttled: boss must nevertheless evict its previous hint immediately.
check("boss immediately owns notice lane", bossBar.Visible and player:GetAttribute("HudBossActive"))
check(
	"boss evicts Warzone before its next250ms refresh",
	not hint.Visible and not player:GetAttribute("HudWarzoneActive")
)
check("boss stays at safe-area local top", bossBar.Position == rb.UDim2.fromOffset(236, 0))
check("boss fills bounded243x52 lane", bossBar.Size == rb.UDim2.fromOffset(243, 52))
player:SetAttribute("HudNotificationY", 140)
step()
check("moving notification Y cannot move boss downward", bossBar.Position.Y.Offset == 0)
player:SetAttribute("HudNotificationY", 8)
local back = bossBar:GetChildren()[3]
check("health values remain actual source output", back:GetChildren()[2].Text == "75 / 100")
step()
check("simultaneous eligibility never has both visible", bossBar.Visible and not hint.Visible)
player:SetAttribute("HudGameplayOpen", false)
check(
	"opening full menu immediately releases critical lane",
	not bossBar.Visible
		and not hint.Visible
		and not player:GetAttribute("HudBossActive")
		and not player:GetAttribute("HudWarzoneActive")
)
step()
check(
	"menu refresh never reacquires critical lane",
	not bossBar.Visible
		and not hint.Visible
		and not player:GetAttribute("HudBossActive")
		and not player:GetAttribute("HudWarzoneActive")
)
player:SetAttribute("HudGameplayOpen", true)
step()
check(
	"closing full menu restores nearby boss",
	bossBar.Visible and player:GetAttribute("HudBossActive")
)
root.Position = rb.Vector3.new(0, 31, 0)
step()
check(
	"different floor clears boss priority",
	not bossBar.Visible and not player:GetAttribute("HudBossActive")
)
root.Position = rb.Vector3.zero
boss:SetAttribute("Alive", false)
step()
check("Warzone resumes after dead boss", hint.Visible and player:GetAttribute("HudWarzoneActive"))
capture.owner = "red"
step()
check(
	"captured point frees notice lane",
	not hint.Visible and not player:GetAttribute("HudWarzoneActive")
)
capture.owner = nil
gui.Enabled = false
boss:SetAttribute("Alive", true)
step()
check(
	"disabled gameplay GUI does not block transient notices",
	not player:GetAttribute("HudBossActive") and not player:GetAttribute("HudWarzoneActive")
)
gui.Enabled = true
for _, case in
	{
		{ 320, 568, 0, -58, 10, 8, 170 },
		{ 568, 320, 24, -58, 260, 8, 170 },
		{ 705, 338, 0, -58, 236, 8, 243 },
		{ 812, 375, 44, -24, 280, 42, 300 },
		{ 1280, 720, 0, 0, 440, 66, 400 },
	}
do
	gui.AbsoluteSize, gui.AbsolutePosition =
		rb.Vector2.new(case[1], case[2]), rb.Vector2.new(case[3], case[4])
	lane(case[5], case[6], case[7], 52)
	step()
	local absolute = gui.AbsolutePosition
		+ rb.Vector2.new(bossBar.Position.X.Offset, bossBar.Position.Y.Offset)
	check(
		tostring(case[1]) .. " boss preserves horizontal lane at safe-area top",
		absolute == rb.Vector2.new(case[5], gui.AbsolutePosition.Y)
	)
	check(tostring(case[1]) .. " boss width matches shared lane", bossBar.Size.X.Offset == case[7])
	boss:SetAttribute("Alive", false)
	step()
	check(
		tostring(case[1]) .. " Warzone retains notification Y and shared width",
		hint.Position == rb.UDim2.fromOffset(case[5] - case[3], case[6] - case[4])
			and hint.Size == bossBar.Size
	)
	boss:SetAttribute("Alive", true)
end
for _, key in { "X", "Y", "Width", "Height" } do
	player:SetAttribute("HudNotification" .. key, nil)
end
gui.AbsoluteSize, gui.AbsolutePosition = rb.Vector2.new(320, 568), rb.Vector2.new(0, -58)
step()
check(
	"pre-layout fallback fits320px screen",
	bossBar.Position.X.Offset == 10 and bossBar.Size.X.Offset == 300
)
check("pre-layout fallback remains at safe-area top", bossBar.Position.Y.Offset == 0)
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, realPlayers = false, realStudio = false }
	)
)
