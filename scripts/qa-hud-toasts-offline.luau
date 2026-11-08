--!nocheck
-- Actual HudNotices queue/timer with deterministic clock and property signals.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local heartbeat, changed = signal(), signal()
local values = { Visible = false }
local frame = setmetatable({
	GetPropertyChangedSignal = function()
		return changed
	end,
}, {
	__index = values,
	__newindex = function(_, k, v)
		values[k] = v
		if k == "Visible" then
			changed:Fire()
		end
	end,
})
local player = { attributes = { HudGameplayOpen = true, LoadingBlocked = false } }
function player:SetAttribute(k, v)
	self.attributes[k] = v
end
function player:GetAttribute(k)
	return self.attributes[k]
end
local now, hidden, editing = 0, false, false
local label = { Text = "" }
local fn = assert(loadstring(fs.readFile("src/client/HudNotices.luau")))
setfenv(
	fn,
	setmetatable({
		game = {
			GetService = function()
				return { Heartbeat = heartbeat }
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
	}, { __index = getfenv() })
)
local show = fn().start(player, frame, label, function()
	return hidden
end, function()
	return editing
end)
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function tick(dt)
	now += dt
	heartbeat:Fire(dt)
end
player.attributes.HudBossActive = true
for i = 1, 10 do
	show(tostring(i))
end
tick(0.1)
check(
	"boss suppresses physical toast and published flag",
	not frame.Visible and not player.attributes.HudToastActive
)
player.attributes.HudBossActive = false
tick(0.1)
check("queue bounded to eight most recent", frame.Visible and label.Text == "3")
tick(3)
tick(0.01)
check("visible time advances next toast", label.Text == "4")
player.attributes.HudBossActive = true
tick(21)
player.attributes.HudBossActive = false
tick(0.01)
check("old ordinary notices expire while critical visible", not frame.Visible)
show("pause")
tick(0.1)
player.attributes.HudWarzoneActive = true
tick(1)
check("critical transition hides current toast", not frame.Visible)
player.attributes.HudWarzoneActive = false
tick(0.1)
check("current resumes after critical", frame.Visible and label.Text == "pause")
player.attributes.HudBossActive = true
player.attributes.HudGameplayOpen = false
show("menu result")
tick(0.1)
check("menu result bypasses stale critical flag", frame.Visible and label.Text == "menu result")
hidden = true
tick(0.1)
check(
	"settings publish actual hidden flag",
	not frame.Visible and not player.attributes.HudToastActive
)
hidden = false
editing = true
frame.Visible = true
tick(0.1)
check("editor sample publishes actual visible flag", player.attributes.HudToastActive)
editing = false
tick(0.1)
check(
	"editor exit clears stale queue and flag",
	not frame.Visible and not player.attributes.HudToastActive
)
show("loading")
player.attributes.LoadingBlocked = true
tick(0.1)
check("loader blocks toast", not frame.Visible)
player.attributes.LoadingBlocked = false
tick(0.1)
check("loader completion restores recent toast", frame.Visible and label.Text == "loading")
print(
	serde.encode("json", { passed = #checks, actualModule = true, nativeRendering = false }, true)
)
