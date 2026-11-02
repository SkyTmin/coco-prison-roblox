--!nocheck
-- Studio plugin/execute_luau Server context (writes temporary ModuleScript sources).
-- Isolated profiles and mine cells, real removal/accounting code; forced book procs.
-- No owner profile mutation. BookService clone alone uses the profile/notification doubles.
assert(game.RunService:IsStudio() and game.RunService:IsServer())
local S = game.ServerScriptService.Server.Services
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.MiningStats)
local Boosters = require(Shared.Boosters)
local Profile = require(S.ProfileService)
local Mine = require(S.MineService)
local Tuning = require(S.BookTuning)
local fixture = Instance.new("Folder")
fixture.Name = "QAMiningStatsFixture"
fixture.Parent = game.ServerStorage
local function module(name, source)
	local m = Instance.new("ModuleScript")
	m.Name, m.Source, m.Parent = name, source, fixture
	return m
end
local state = require(module("QAState", "return { profile = nil, events = {} }"))
module(
	"ProfileService",
	[[
local state = require(script.Parent.QAState)
return { Get = function() return state.profile end, Mutate = function(_, fn) fn(state.profile) end }
]]
)
module("GangService", "return { progress = function() end }")
module(
	"QARemotes",
	[[
local state = require(script.Parent.QAState)
return { event = function(name) return { FireClient = function(_, _, ...) table.insert(state.events, { name, ... }) end } end }
]]
)
local source = S.BookService.Source
for name in source:gmatch("require%(script%.Parent%.(%w+)%)") do
	if not fixture:FindFirstChild(name) then
		module(name, "return require(game.ServerScriptService.Server.Services." .. name .. ")")
	end
end
local function replace(text, old, new)
	local a, b = assert(text:find(old, 1, true))
	return text:sub(1, a - 1) .. new .. text:sub(b + 1)
end
source = replace(
	source,
	"local Remotes = require(Shared.Remotes)",
	"local Remotes = require(script.Parent.QARemotes)"
)
source = replace(source, "return chance > 0 and random:NextNumber() < chance", "return chance > 0")
local Books = require(module("BookService", source))
local actor = { UserId = 0 }
local checks, cases = {}, {}
local function check(name, pass)
	table.insert(checks, { name = name, pass = pass == true })
	assert(pass, name)
end
local function close(a, b)
	return math.abs(a - b) < 0.000001
end
local function profile(book, booster)
	Tuning.clear(actor)
	local p = Profile.defaultProfile()
	p.level = 50
	p.inventory =
		{ [1] = { id = "pickaxe", level = 1, count = 1, books = { { id = book, level = 3 } } } }
	if booster then
		p.activeBoosters = {
			{ kind = "blocks", mult = booster, startsAt = os.time() - 5, endsAt = os.time() + 600 },
		}
	end
	state.profile, state.events = p, {}
	return p
end
local function grid(width, depth, mixed)
	local mine =
		{ id = "qa-mining-stats", size = { width, 1, depth }, cells = {}, parts = {}, dug = 0 }
	for i = 1, width * depth do
		mine.cells[i] = if mixed and i % 2 == 0 then "dirt" else "stone"
		local part = Instance.new("Part")
		part.Parent = fixture
		mine.parts[i] = part -- pre-exposed cells: no map/streaming changes
	end
	return mine
end
local function runBook(name, book, width, depth, booster, combo, mixed, autosell)
	local p = profile(book, booster)
	p.autosell = autosell
	local mine = grid(width, depth, mixed)
	local index = Mine.index(mine, math.ceil(width / 2), 1, math.ceil(depth / 2))
	local mult = Boosters.multiplier(p, "blocks") * combo
	local id = Mine.breakBlock(mine, index)
	Stats.credit(p, id, 1, mult) -- the initiating dig was already credited before BookService
	Books.onDug(actor, mine, index, Vector3.yAxis, Config.block(id).dropsAs or id, 1, combo)
	local actual = mine.dug
	check(name .. " clean equals removed cells", p.stats.blocksClean == actual)
	check(name .. " orange includes booster and combo", close(p.blocksTotal, actual * mult))
	local perType = {}
	for i = 1, width * depth do
		if not mine.cells[i] then
			local blockId = if mixed and i % 2 == 0 then "dirt" else "stone"
			local key = Config.block(blockId).upgradeCounter
			perType[key] = (perType[key] or 0) + mult
		end
	end
	for key, expected in perType do
		check(name .. " upgrade counter " .. key, close(Config.requirementHave(p, key), expected))
	end
	table.insert(cases, {
		name = name,
		removed = actual,
		clean = p.stats.blocksClean,
		orange = p.blocksTotal,
		multiplier = mult,
		counters = p.counters,
	})
	return p, mine
end
local ok, err = xpcall(function()
	local p = Profile.defaultProfile()
	Stats.credit(p, "stone", 100, 2)
	check(
		"100 real with x2 is 100 clean and 200 orange",
		p.stats.blocksClean == 100 and p.blocksTotal == 200
	)
	check(
		"upgrade requirement sees the boosted 200",
		Config.requirementHave(p, Config.block("stone").upgradeCounter) == 200
	)
	Stats.credit(p, "dirt", 10, 1.5)
	check(
		"different block types stay separate",
		p.blocksTotal == 215
			and p.stats.blocksClean == 110
			and Config.requirementHave(p, Config.block("dirt").upgradeCounter) == 15
	)
	local layer, mine = runBook("full mixed layer", "plastolom", 32, 32, 2, 1.1, true, false)
	check(
		"full layer exceeds former half/200 cap",
		mine.dug == 1024 and layer.stats.blocksClean == 1024
	)
	local before = layer.blocksTotal
	Tuning.clear(actor) -- retry the empty layer with an eligible proc, not just an active cooldown
	Books.onDug(actor, mine, 1, Vector3.yAxis, "stone", 1, 1.1)
	check(
		"empty cells and repeat proc do not duplicate credit",
		layer.blocksTotal == before and layer.stats.blocksClean == 1024
	)
	local hammer, hammerMine = runBook("hammer", "hammer", 3, 3, 2, 1.5, false, false)
	check(
		"hammer counts exactly nine real cells",
		hammerMine.dug == 9 and hammer.stats.blocksClean == 9
	)
	local sold = runBook("autosold layer", "plastolom", 5, 5, 2, 1.2, false, true)
	check(
		"fractional credits reach the exact 60-block upgrade gate",
		sold.blocksTotal == 60
			and Config.requirementHave(sold, Config.block("stone").upgradeCounter) == 60
	)
	check(
		"auto-sell pays without changing block accounting",
		sold.coins > 0 and #state.events > 0 and state.events[1][1] == "AutoSold"
	)
	local trader = profile("trader", 2)
	local traderMine = grid(1, 1)
	local id = Mine.breakBlock(traderMine, 1)
	Stats.credit(trader, id, 1, 2)
	Books.onDug(actor, traderMine, 1, Vector3.yAxis, "cobblestone", 7, 1)
	check(
		"seven copied drops do not add mined blocks",
		trader.stats.blocksClean == 1
			and trader.blocksTotal == 2
			and Config.requirementHave(trader, Config.block(id).upgradeCounter) == 2
	)
end, debug.traceback)
Tuning.clear(actor)
fixture:Destroy()
local report = {
	status = if ok then "PASS" else "FAIL",
	error = if ok then nil else err,
	checks = checks,
	cases = cases,
	limits = "Isolated profile fixtures; real MiningStats/MineService and cloned BookService with forced procs. No owner data mutation.",
}
local output = Instance.new("StringValue")
output.Name = "QAMiningStatsResult"
output.Value = game.HttpService:JSONEncode(report)
output.Parent = game.ServerStorage
