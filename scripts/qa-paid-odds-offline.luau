--!nocheck
-- Exact actual-source distribution checks; optional pre-edit source parity via COCO_ODDS_BASELINE.
-- No Studio, real profiles, purchases or services.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local rb = require("@lune/roblox")
local checks, comparisons = 0, 0
local function check(name, ok)
	assert(ok, name)
	checks += 1
end
local function near(a, b)
	return math.abs(a - b) < 1e-11
end
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, x in a do
		if not equal(x, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function rng(seed)
	local state = seed
	return {
		NextNumber = function(_, a, b)
			state = state * 16807 % 2147483647
			return (a or 0) + state / 2147483647 * ((b or 1) - (a or 0))
		end,
		NextInteger = function(self, a, b)
			return math.floor(self:NextNumber(a, b + 1))
		end,
	}
end
local Config = {}
for _, name in { "keys", "books", "boosters", "artifacts", "rules", "tools" } do
	Config[name] = serde.decode("json", fs.readFile("src/shared/Config/" .. name .. ".json"))
end
Config.moneyScale = Config.rules.money.scale
Config.tools = Config.tools.tools
local modules = { Config = Config, Types = {}, ProfileService = {}, Strings = {}, Remotes = {} }
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local desiredFragment = 1
local env = setmetatable({
	game = {
		GetService = function(_, name)
			return if name == "ReplicatedStorage"
				then {
					Shared = names,
					WaitForChild = function()
						return names
					end,
				}
				else {}
		end,
	},
	script = { Parent = names },
	require = function(id)
		return assert(modules[id], id)
	end,
	Color3 = rb.Color3,
	Random = {
		new = function()
			return {
				NextInteger = function()
					return desiredFragment
				end,
			}
		end,
	},
}, { __index = getfenv() })
local function load(path, environment, transform)
	local source = fs.readFile(path)
	if transform then
		source = transform(source)
	end
	local fn = assert(loadstring(source, "@" .. path))
	setfenv(fn, environment or env)
	return fn()
end
for _, id in { "Numbers", "AncientRoll", "CaseRoll", "Nicknames", "RewardOdds" } do
	modules[id] = load("src/shared/" .. id .. ".luau")
end
for _, id in { "InventoryService", "BookTuning", "AncientCase", "ArtifactService" } do
	modules[id] = load("src/server/Services/" .. id .. ".luau")
end
local Odds, Ancient, Roll = modules.RewardOdds, modules.AncientRoll, modules.CaseRoll
local function sum(nodes)
	local result = 0
	for _, node in nodes do
		result += node.probability
	end
	return result
end
local function normalized(nodes, parent)
	check("branch normalization", near(sum(nodes), parent))
	for _, node in nodes do
		check("finite positive branch probability", node.probability > 0 and node.probability <= 1)
		if node.children then
			normalized(node.children, node.probability)
		end
		if node.range then
			local range = node.range
			check(
				"inclusive discrete range normalization",
				near(range.probabilityPerValue * (range.max - range.min + 1), node.probability)
			)
		end
	end
end
local ordinary = Odds.case("ordinaryCase")
local artifact = Odds.case("artifactCase")
local ancient = Odds.case("ancientCase")
local improved = Odds.case("ancientCase", nil, "improved_ancient_key")
local nick = Odds.case("nicknameCase")
for _, plan in { ordinary, artifact, ancient, improved, nick } do
	normalized(plan.outcomes, 1)
	check("draw count distribution", near(sum(plan.draws), 1))
	if #plan.bonuses > 0 then
		normalized(plan.bonuses, 1)
	end
end
check(
	"ordinary exact count probabilities",
	#ordinary.draws == 3
		and ordinary.draws[1].count == 2
		and ordinary.draws[2].count == 3
		and ordinary.draws[3].count == 4
		and ordinary.draws[1].probability == 1 / 3
)
check(
	"independent bonus happens once per opening",
	near(ordinary.bonuses[2].probability, 0.06) and #ordinary.bonuses[2].children == 9
)
check(
	"at least once incorporates 2,3,4 draws",
	near(Odds.atLeastOne(ordinary, 0.2), ((1 - 0.8 ^ 2) + (1 - 0.8 ^ 3) + (1 - 0.8 ^ 4)) / 3)
)
check(
	"other cases have one draw and no ordinary bonus",
	artifact.draws[1].count == 1 and #artifact.bonuses == 0 and #ancient.bonuses == 0
)
local function find(nodes, id)
	for _, node in nodes do
		if node.id == id then
			return node
		end
	end
	return nil
end
local money = find(ordinary.outcomes, "money")
check(
	"ordinary currency rounds before uniform integer roll",
	money.range.min == 3700
		and money.range.max == 14000
		and near(money.range.probabilityPerValue, money.probability / 10301)
)
money = find(artifact.outcomes, "money")
check(
	"artifact money full discrete metadata range",
	money.range.min == 200000
		and money.range.max == 1200000
		and money.stack.id == "money_bag"
		and near(money.range.probabilityPerValue, 25 / 113 / 1000001)
)
local lo, hi = Roll.moneyRange({ min = 0.000049, max = 0.000051 })
check("half-unit rounding boundary", lo == 0 and hi == 1)
local apple = find(ordinary.outcomes, "apple")
check(
	"food exact quantity chance",
	apple.range.min == 1
		and apple.range.max == 3
		and near(apple.range.probabilityPerValue, apple.probability / 3)
)
check(
	"four armor pieces equal unconditional chances",
	near(
		find(ordinary.outcomes, "helmet").probability,
		find(ordinary.outcomes, "boots").probability
	)
)
check(
	"silk pickaxe exact metadata",
	find(ordinary.outcomes, "pickaxe").stack.books[1].id == "silk_touch"
		and find(ordinary.outcomes, "pickaxe").stack.level == 1
)
check(
	"artifact nested ancient-book chance",
	near(find(artifact.outcomes, "ancient_book").probability, 5 / 113)
)
for _, kind in Config.boosters.kinds do
	check(
		"artifact booster concrete kind " .. kind,
		near(
			find(artifact.outcomes, "booster_" .. kind .. "_local").probability,
			8 / 113 / #Config.boosters.kinds
		)
	)
end
for _, node in improved.outcomes do
	check(
		"improved only supported III",
		node.stack.level == 3 and #Config.books.effects[node.stack.books[1].id] >= 3
	)
	check(
		"improved low/high final joint probabilities",
		#node.children == 2
			and near(node.children[1].probability, node.probability * 0.9)
			and near(node.children[2].probability, node.probability * 0.1)
	)
	check(
		"improved each apply integer is exact",
		near(node.children[1].range.probabilityPerValue, node.probability * 0.9 / 61)
			and near(node.children[2].range.probabilityPerValue, node.probability * 0.1 / 30)
	)
end
for _, node in ancient.outcomes do
	check(
		"normal level never exceeds catalog",
		node.stack.level <= #Config.books.effects[node.stack.books[1].id]
	)
	check(
		"normal apply chance has 91 equiprobable integers",
		node.children[1].range.min == 10
			and node.children[1].range.max == 100
			and near(node.children[1].range.probabilityPerValue, node.probability / 91)
	)
end
local choices = { "plastolom", "vampirism", "enlightened", "hammer", "trader" }
for _, effect in { "plastolom", "vampirism", "enlightened" } do
	local branches = Ancient.adjustments(effect, 3, choices)
	check(
		"adjusted III retains half " .. effect,
		branches[1].id == effect and branches[1].probability == 0.5 and #branches == 3
	)
	check(
		"adjusted III redistributes only to alternatives " .. effect,
		branches[2].id == "hammer"
			and branches[2].probability == 0.25
			and branches[3].id == "trader"
	)
	check(
		"lower levels unadjusted " .. effect,
		#Ancient.adjustments(effect, 2, choices) == 1
			and Ancient.adjustments(effect, 2, choices)[1].probability == 1
	)
end
for _, mode in { { plan = ancient, improved = false }, { plan = improved, improved = true } } do
	local sums = {}
	for _, node in mode.plan.outcomes do
		sums[node.rarity] = (sums[node.rarity] or 0) + node.probability
	end
	for rarity, weight in Config.keys.ancientCase.rarity do
		check("final rarity mass matches weighted selection", near(sums[rarity], weight / 100))
	end
	for _, effect in { "plastolom", "vampirism", "enlightened" } do
		local rarity = Config.books.catalog[effect].rarity
		local eligible = 0
		for id, levels in Config.books.effects do
			if
				Config.books.catalog[id].rarity == rarity and (not mode.improved or #levels >= 3)
			then
				eligible += 1
			end
		end
		local expected = Config.keys.ancientCase.rarity[rarity]
			/ 100
			/ eligible
			* 0.5
			* (if mode.improved then 1 else 0.1)
		check(
			"final adjusted III exact joint chance " .. effect,
			near(find(mode.plan.outcomes, effect .. ":3").probability, expected)
		)
	end
end
-- An empty selected rarity uses the actual fallback pool; normal and improved remain normalized.
local realRarity = Config.keys.ancientCase.rarity
Config.keys.ancientCase.rarity = { missing_catalog_rarity = 1 }
for _, isImproved in { false, true } do
	local fallback = Ancient.distribution(isImproved)
	check("empty rarity fallback normalization", near(sum(fallback), 1))
	local drawn = Ancient.roll(isImproved, rng(737))
	check(
		"empty rarity fallback still returns real eligible book",
		Config.books.catalog[drawn.books[1].id] ~= nil and (not isImproved or drawn.level == 3)
	)
end
Config.keys.ancientCase.rarity = realRarity
local owned = { modules.Nicknames.list[1], modules.Nicknames.list[2] }
local partial = Odds.case("nicknameCase", { nicknames = owned })
normalized(partial.outcomes, 1)
check(
	"owned nicknames omitted",
	find(partial.outcomes, owned[1]) == nil and #partial.outcomes == #nick.outcomes - 2
)
local remainingWeight = 0
for _, name in modules.Nicknames.list do
	if not table.find(owned, name) then
		remainingWeight += modules.Nicknames.weight(name)
	end
end
local cursor = 0
for _, node in partial.outcomes do
	check(
		"exact per-name weighted probability",
		near(node.probability, modules.Nicknames.weight(node.id) / remainingWeight)
	)
	local midpoint = cursor + node.probability / 2
	check(
		"actual nickname pick follows displayed remaining interval",
		modules.Nicknames.pick(owned, {
			NextNumber = function()
				return midpoint
			end,
		}) == node.id
	)
	cursor += node.probability
end
local all = Odds.case("nicknameCase", { nicknames = table.clone(modules.Nicknames.list) })
check(
	"all names owned means no possible paid roll",
	all.unavailable and all.unavailableReason == "nickname_all_owned" and #all.outcomes == 0
)
local exceptLast = table.clone(modules.Nicknames.list)
local finalName = table.remove(exceptLast)
local last = Odds.case("nicknameCase", { nicknames = exceptLast })
check(
	"last eligible nickname is certain",
	#last.outcomes == 1 and last.outcomes[1].id == finalName and last.outcomes[1].probability == 1
)

for _, state in
	{
		{ fragments = {}, duplicates = 0 },
		{ fragments = { [1] = 1 }, duplicates = 8 },
		{ fragments = { 1, 1, 1, 1, 1, 1, 1, 1, 1 }, duplicates = 9 },
		{ fragments = { [1] = 1 }, duplicates = 27 },
	}
do
	local p = { artifacts = { common = copy(state) } }
	local projection = Odds.case("ordinaryCase", p).bonuses[2].children
	check("odds do not mutate owned mosaic", equal(p.artifacts.common, state))
	for index = 1, 9 do
		desiredFragment = index
		local actual = { artifacts = { common = copy(state) } }
		local notices = modules.ArtifactService.GrantFragment(actual, "common")
		local indices = {}
		for _, notice in notices do
			table.insert(indices, notice.index)
		end
		check(
			"bonus matches actual fragment/duplicate conversion",
			equal(indices, projection[index].grantedIndices)
				and actual.artifacts.common.duplicates == projection[index].duplicatesAfter
		)
	end
end

-- Optional exact source comparison saved immediately before the factoring change.
local baseline = process.env.COCO_ODDS_BASELINE
if baseline then
	local oldModules = table.clone(modules)
	local oldEnv = setmetatable({
		require = function(id)
			return assert(oldModules[id], id)
		end,
	}, { __index = env })
	oldModules.BookTuning = load(baseline .. "/BookTuning.luau", oldEnv)
	oldModules.AncientCase = load(baseline .. "/AncientCase.luau", oldEnv)
	for _, isImproved in { false, true } do
		for seed = 1, 2000 do
			local before = oldModules.AncientCase.roll(isImproved, rng(seed * 97))
			local after = modules.AncientCase.roll(isImproved, rng(seed * 97))
			assert(equal(before, after), "Ancient RNG/output changed at seed " .. seed)
			comparisons += 1
		end
	end
	local source = fs.readFile(baseline .. "/CaseService.luau")
	local first = assert(source:find("\t\t\tlocal item, count, level = reward.id", 1, true))
	local lastAt = assert(source:find("\n\t\tend\n\t\tlocal contents =", first, true))
	local body = source:sub(first, lastAt - 1)
	local resolver = assert(
		loadstring(
			"return function(caseId, reward, random) local session={id=caseId}; local staged={inventory={}}; local money=0; local failure=nil; "
				.. body
				.. "\nreturn staged.inventory[1], money end"
		)
	)
	setfenv(
		resolver,
		setmetatable({
			Config = Config,
			ARMOR = Roll.ARMOR,
			AncientCase = oldModules.AncientCase,
			InventoryService = modules.InventoryService,
			Boosters = {
				kinds = Config.boosters.kinds,
				itemId = function(kind, scope)
					return "booster_" .. kind .. "_" .. scope
				end,
			},
		}, { __index = env })
	)
	local oldResolve = resolver()
	for _, caseId in { "ordinaryCase", "artifactCase" } do
		local rewards = Config.keys[caseId].rewards or Config.keys[caseId]
		for _, reward in rewards do
			for seed = 1, 100 do
				local before, oldMoney = oldResolve(caseId, reward, rng(seed * 1301))
				local after, newMoney = Roll.resolve(caseId, reward, rng(seed * 1301))
				assert(
					equal(before, after) and oldMoney == newMoney,
					"Case outcome changed " .. caseId .. ":" .. reward.id
				)
				comparisons += 1
			end
		end
	end
	check("actual pre-edit source parity", comparisons == 6000)
end
print(
	"PASS "
		.. checks
		.. " exact paid odds checks; "
		.. comparisons
		.. " pre-edit source seeded comparisons; offline only"
)
