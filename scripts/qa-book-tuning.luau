--!nocheck
-- Server/Studio only. Server-private tuning; no profile mutations or player-facing text.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local Tuning = require(game.ServerScriptService.Server.Services.BookTuning)
local Books = require(game.ReplicatedStorage.Shared.Books)
local checks = {}
local function check(name, pass)
	table.insert(checks, { name = name, pass = pass })
	assert(pass, name)
end
local previous = 0
for level = 1, 3 do
	local stack = { id = "pickaxe", count = 1, books = { { id = "plastolom", level = level } } }
	local advertised = Books.value(stack, "plastolom")
	local chance = Tuning.proc("plastolom", level, advertised)
	check("tier " .. level .. " increases actual chance", chance > previous)
	check("tier " .. level .. " preserves public description", advertised == level * 0.001)
	previous = chance
end
-- The cooldown only uses identity as a table key; Studio forbids creating synthetic Players.
local a, b = {}, {}
local ok, err = pcall(function()
	check("fresh player ready", Tuning.layerReady(a, 100))
	Tuning.layerStarted(a, 100)
	check("immediate repeat blocked", not Tuning.layerReady(a, 100))
	check("other player unaffected", Tuning.layerReady(b, 100))
	check("89.99 seconds still blocked", not Tuning.layerReady(a, 189.99))
	check("90 seconds releases", Tuning.layerReady(a, 190))
	Tuning.layerStarted(a, 190)
	check("second success restarts cooldown", not Tuning.layerReady(a, 279.99))
	check("second cooldown expires", Tuning.layerReady(a, 280))
	Tuning.clear(a)
	check("session cleanup", Tuning.layerReady(a, 1))
	local choices = { "plastolom", "vampirism", "enlightened", "hammer", "trader" }
	for index, effect in { "plastolom", "vampirism", "enlightened" } do
		local random = Random.new(index)
		local retained = 0
		for i = 1, 10000 do
			if Tuning.roll(effect, 3, choices, random) == effect then
				retained += 1
			end
			if i % 1000 == 0 then
				task.wait()
			end
		end
		check(effect .. " reward adjustment", retained > 4700 and retained < 5300)
		check(
			effect .. " lower reward tier unchanged",
			Tuning.roll(effect, 2, choices, random) == effect
		)
	end
end)
Tuning.clear(a)
Tuning.clear(b)
return { ok = ok, error = if ok then nil else tostring(err), checks = checks }
