--!nocheck
-- Actual BoosterHud factory and EffectsHud prefix before camera hooks, with isolated attributes/profile.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local suite = fs.readFile("scripts/qa-hud-notifications-offline.luau")
local firstCases = assert(suite:find("\nfor _, case in", 1, true))
local factory = assert(loadstring(suite:sub(1, firstCases - 1) .. "\nreturn fixture"))()
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function setup()
	local f = factory(705, 338, rb.Vector2.new(0, -58), rb.Vector2.new(0, 58))
	f.heartbeat, f.toasts, f.storageOpened, f.editing = f.signal(), {}, 0, false
	f.profile = { settings = {}, activeBoosters = {} }
	f.player.Character = f.node("Model")
	f.Ui.panel, f.Ui.rich, f.Ui.hex = f.Ui.card, f.Ui.label, function()
		return "#ffffff"
	end
	local effectSource = fs.readFile("src/shared/Effects.luau")
	local effectFactory = assert(loadstring(effectSource))
	local world = {
		GetServerTimeNow = function()
			return f.now
		end,
	}
	setfenv(
		effectFactory,
		setmetatable({ Color3 = rb.Color3, workspace = world }, { __index = getfenv() })
	)
	f.Effects = effectFactory()
	local modules = {
		Types = {},
		Effects = f.Effects,
		HudLayout = {
			isEditing = function()
				return f.editing
			end,
		},
		BowState = {},
		HurtFeedback = {},
		Boosters = {
			now = function()
				return f.now
			end,
			runningAll = function(profile)
				return profile.activeBoosters
			end,
			scopeOf = function(item)
				return item.scope or "local"
			end,
			icon = function(kind, scope)
				return kind .. ":" .. scope
			end,
			queueAfter = function()
				return 0
			end,
			SCOPE_COLORS = { ["local"] = rb.Color3.new(), global = rb.Color3.new() },
		},
	}
	local catalog = assert(loadstring(fs.readFile("src/shared/Strings/Part1.luau")))()
	for key, value in assert(loadstring(fs.readFile("src/shared/Strings/Part2.luau")))() do
		catalog[key] = value
	end
	f.locale = "en"
	function f:t(key, ...)
		local row = assert(catalog[key], key)
		return string.format(assert(row[self.locale], key .. ":" .. self.locale), ...)
	end
	local function load(path, prefix)
		local source = fs.readFile(path)
		if prefix then
			source = source:sub(1, assert(source:find("\t-- screen effects", 1, true)) - 1)
				.. "\nreturn frame\nend\nreturn EffectsHud"
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(
			fn,
			setmetatable({
				game = {
					GetService = function(_, name)
						return if name == "RunService"
							then { Heartbeat = f.heartbeat }
							else f.env.game:GetService(name)
					end,
				},
				require = function(id)
					return modules[id] or f.env.require(id)
				end,
				workspace = world,
				UDim = rb.UDim,
			}, { __index = f.env })
		)
		return fn()
	end
	f.boosters = load("src/client/BoosterHud.luau").start(f.gui, function()
		return f.profile
	end, function(...)
		return f:t(...)
	end, function()
		f.storageOpened += 1
	end)
	f.effects = load("src/client/EffectsHud.luau", true).start(f.gui, function(...)
		return f:t(...)
	end, function(message)
		table.insert(f.toasts, message)
	end)
	function f:tick()
		self:advance(0.3)
		self.heartbeat:Fire(0.3)
	end
	return f
end
local f = setup()
f.boosters:SetAttribute("Compact", true)
f.effects:SetAttribute("Compact", true)
check("empty compact factories are absent", not f.boosters.Visible and not f.effects.Visible)
for i = 1, 6 do
	table.insert(
		f.profile.activeBoosters,
		{ kind = "money", scope = "global", mult = 2, startsAt = 0, endsAt = 90 + i }
	)
end
f:tick()
local summary = f.boosters:FindFirstChild("BoosterSummary")
check(
	"six boosters use one exact100x44 tile",
	f.boosters.Size == rb.UDim2.fromOffset(100, 44)
		and f.boosters.AutomaticSize == rb.Enum.AutomaticSize.None
		and summary.Visible
		and summary.Size == rb.UDim2.fromOffset(100, 44)
)
check(
	"summary retains count multiplier icon and live timer",
	summary:FindFirstChild("ActiveCount").Text == "6"
		and summary:FindFirstChild("Multiplier").Text == "×2"
		and summary:FindFirstChild("Icon").Image == "money:global"
		and summary:FindFirstChild("Time").Text == "1:30"
)
local rows = 0
for _, child in f.boosters:GetChildren() do
	if child.Name:match("^Booster_%d") and child.Visible then
		rows += 1
	end
end
check("compact mode hides all desktop rows", rows == 0)
summary.Activated:Fire()
check("summary opens existing storage action once", f.storageOpened == 1)
f.profile.settings.hideBoosters = true
f:tick()
check("hideBoosters setting still suppresses summary", not f.boosters.Visible)
f.profile.settings.hideBoosters = false
f.boosters:SetAttribute("Compact", false)
rows = 0
for _, child in f.boosters:GetChildren() do
	if child.Name:match("^Booster_%d") and child.Visible then
		rows += 1
	end
end
check(
	"desktop rotation restores width and six original rows",
	f.boosters.Size.X.Offset == 200
		and f.boosters.AutomaticSize == rb.Enum.AutomaticSize.Y
		and rows == 6
		and not summary.Visible
)
f.profile.activeBoosters = {}
f:tick()
check("last booster removal hides whole factory", not f.boosters.Visible)

for _, compact in { true, false } do
	local injection = setup()
	injection.effects:SetAttribute("Compact", compact)
	injection.player.Character:SetAttribute("NeedsFree", 1)
	injection:tick()
	check(
		"injection alone has no HUD in compact=" .. tostring(compact),
		not injection.effects.Visible and not injection.effects:FindFirstChild("Effect_needs_free")
	)
	check(
		"injection mechanic stays active in compact=" .. tostring(compact),
		injection.Effects.level(injection.player.Character, "NeedsFree") == 1
			and #injection.Effects.active(injection.player.Character) == 1
	)
	injection.player.Character:SetAttribute("Speed", 1)
	injection.player.Character:SetAttribute("Strength", 2)
	injection:tick()
	local shown = 0
	for _, child in injection.effects:GetChildren() do
		if child.Name:match("^Effect_") and child.Visible then
			shown += 1
		end
	end
	check(
		"injection does not consume one of two icons in compact=" .. tostring(compact),
		shown == 2
			and injection.effects:FindFirstChild("Effect_speed").Visible
			and injection.effects:FindFirstChild("Effect_strength").Visible
	)
	check(
		"injection does not create an overflow count in compact=" .. tostring(compact),
		not injection.effects:FindFirstChild("EffectOverflow").Visible
			and not injection.effects:FindFirstChild("Effect_needs_free")
	)
end

for index, effect in f.Effects.list do
	f.player.Character:SetAttribute(effect.attribute, index % 3 + 1)
	f.player.Character:SetAttribute(effect.attribute .. "Until", 120)
end
f:tick()
check(
	"many effects remain exactly132x44 compact",
	f.effects.Size == rb.UDim2.fromOffset(132, 44) and f.effects.Visible
)
local visible = {}
for _, child in f.effects:GetChildren() do
	if child.Name:match("^Effect_") and child.Visible then
		table.insert(visible, child)
	end
end
check("only two effect icons are visible", #visible == 2)
for _, panel in visible do
	local id = panel.Name:sub(8)
	check(
		id .. " harmful priority and44px target",
		f.Effects.byId(id).harmful
			and panel.Size == rb.UDim2.fromOffset(44, 44)
			and panel:FindFirstChild("EffectDetails").AbsoluteSize == rb.Vector2.new(44, 44)
	)
	for _, child in panel:GetChildren() do
		if child.ClassName == "TextLabel" then
			check(
				id .. " text remains inside compact height",
				child.Position.Y.Offset + child.Size.Y.Offset <= 44
			)
		end
	end
end
local overflow = f.effects:FindFirstChild("EffectOverflow")
local displayedCount = #f.Effects.list - 1 -- permanent NeedsFree remains mechanical, never a HUD effect
local hiddenCount = displayedCount - 2
check(
	"overflow count and third44px target exact",
	overflow.Visible
		and overflow.Text == "+" .. hiddenCount
		and overflow.Size == rb.UDim2.fromOffset(44, 44)
		and overflow.Position.X.Offset == 88
)
local hidden = {}
for _, harmful in { true, false } do
	for _, effect in f.Effects.list do
		if effect.harmful == harmful and effect.id ~= "needs_free" then
			table.insert(hidden, effect)
		end
	end
end
table.remove(hidden, 1)
table.remove(hidden, 1)
for _, locale in { "ru", "en", "es", "fr" } do
	f.locale = locale
	for index, effect in hidden do
		overflow.Activated:Fire()
		local message = f.toasts[#f.toasts]
		check(
			locale .. " remaining effect reachable " .. effect.id,
			message:sub(1, #tostring(index) + 1) == tostring(index) .. "/"
				and message:find(f:t("effect_" .. effect.id), 1, true) ~= nil
				and message:find(" — ", 1, true) ~= nil
				and not message:find("\n", 1, true)
		)
	end
end
f.effects:SetAttribute("Compact", false)
local desktopCount = 0
for _, panel in f.effects:GetChildren() do
	if panel.Name:match("^Effect_") and panel.Visible then
		desktopCount += 1
		check(
			"desktop wrapped bounds " .. panel.Name,
			panel.Position.X.Offset >= 0
				and panel.Position.X.Offset + panel.Size.X.Offset <= 264
				and panel.Position.Y.Offset + panel.Size.Y.Offset + 16
					<= f.effects.Size.Y.Offset
		)
	end
end
check(
	"desktop restores all effects without horizontal overflow",
	f.effects.Size.X.Offset == 264 and desktopCount == displayedCount and not overflow.Visible
)
for _, effect in f.Effects.list do
	f.player.Character:SetAttribute(effect.attribute, nil)
end
f:tick()
check("no desktop effects means no empty panel", not f.effects.Visible)
f.effects:SetAttribute("Compact", true)
f.editing = true
f:tick()
check(
	"HUD editor still has compact samples to position",
	f.effects.Visible and f.effects.Size == rb.UDim2.fromOffset(132, 44)
)
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualFactories = true,
	realProfiles = false,
	cameraHooksExecuted = false,
}, true))
