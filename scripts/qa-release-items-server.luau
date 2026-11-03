--!nocheck
-- Disposable STS integration harness: exactly one negative simulated account; never purchase/reset owner data.
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "release-items-v1" then
	return
end
local Services = game.ServerScriptService.Server.Services
local Shared = game.ReplicatedStorage.Shared
local P, Copy, Config, Book, Potions, Fall
local startedAt = os.clock()
local report = {
	status = "RUNNING",
	checks = {},
	jumps = {},
	realProfiles = false,
	realPurchases = false,
	auctionStoreWrites = false,
	startup = { timeoutSeconds = 60, phase = "server_modules", readyMessages = 0 },
	limitations = {
		"Negative simulated profile only; normal game services may access their configured stores.",
		"Auction comparator clone uses isolated in-memory index; cross-server propagation is not covered.",
		"VirtualInput availability and fallback boundary are recorded per client/trial; touchscreen needs device acceptance.",
	},
}
local folder = Instance.new("Folder")
folder.Name = "QAReleaseItems"
local session = game.HttpService:GenerateGUID(false)
folder:SetAttribute("Session", session)
local rpc = Instance.new("RemoteFunction")
rpc.Name, rpc.Parent = "RPC", folder
local ready = Instance.new("RemoteEvent")
ready.Name, ready.Parent = "Ready", folder
local clients = {}
-- QA_READY_SERVER_BEGIN: exercised verbatim by qa-release-items-harness-offline.luau.
local function acceptReady(sender, info)
	if sender.UserId >= 0 or typeof(info) ~= "table" or info.session ~= session then
		return
	end
	report.startup.readyMessages += 1
	report.startup.lastClient = info
	if info.phase == "ready" then
		clients[sender] = info
		ready:FireClient(sender, { session = session, ack = true })
	end
end
-- QA_READY_SERVER_END
ready.OnServerEvent:Connect(acceptReady)
-- Publish only after the listener is connected; ACK/retry also tolerates a lost first signal.
folder:SetAttribute("ListenerReady", true)
folder.Parent = game.ReplicatedStorage
local player, backup, creative, original, floor, ended
local observers = {}
local function check(name, value, observed)
	table.insert(report.checks, { name = name, pass = value == true, observed = observed })
end
local function waitFor(fn, seconds)
	local deadline = os.clock() + seconds
	repeat
		if fn() then
			return true
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return fn() and true or false
end
local function finish()
	if ended then
		return
	end
	ended = true
	for _, connection in observers do
		connection:Disconnect()
	end
	if player and player.Parent and player.UserId < 0 and backup then
		-- Never let an unresponsive client prevent EndTest/startup-timeout evidence.
		task.spawn(function()
			pcall(function()
				rpc:InvokeClient(player, "stop")
			end)
		end)
		if backup then
			P.Mutate(player, function(p)
				for key in p do
					p[key] = nil
				end
				for key, value in backup do
					p[key] = Copy(value)
				end
			end)
		end
		player:SetAttribute("Creative", creative)
		if player.Character then
			player.Character:SetAttribute("Hunger", nil)
			player.Character:SetAttribute("HungerUntil", nil)
			Fall.Reset(player)
			if original then
				player.Character:PivotTo(original)
			end
		end
	end
	if floor then
		floor:Destroy()
	end
	game.StudioTestService:EndTest(game.HttpService:JSONEncode(report))
end
task.delay(60, function()
	if not ended and report.startup.phase ~= "complete" then
		report.status, report.error = "FAIL", "startup_timeout"
		report.startup.elapsed = os.clock() - startedAt
		finish()
	end
end)
task.delay(240, function()
	if not ended then
		report.status, report.error = "FAIL", "deadline"
		finish()
	end
end)
local ok, err = xpcall(function()
	-- The deadline exists before any game module require can yield.
	local function serverRequire(module)
		report.startup.phase = "requiring_" .. module.Name
		return require(module)
	end
	P = serverRequire(Services.ProfileService)
	Copy = serverRequire(Shared.Persistence).copy
	Config = serverRequire(Shared.Config)
	Book = serverRequire(Services.BookService)
	Potions = serverRequire(Shared.Potions)
	Fall = serverRequire(Services.FallService)
	if ended then
		return
	end
	report.startup.phase = "waiting_client_profile_character"
	local startupReady = waitFor(function()
		local all = game.Players:GetPlayers()
		local observed = {}
		for _, candidate in all do
			local c = candidate.Character
			table.insert(observed, {
				userId = candidate.UserId,
				ready = clients[candidate] ~= nil,
				profile = P.Get(candidate) ~= nil,
				character = c ~= nil,
				humanoid = c ~= nil and c:FindFirstChildOfClass("Humanoid") ~= nil,
				root = c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil,
			})
		end
		report.startup.players = observed
		report.startup.elapsed = os.clock() - startedAt
		if #all ~= 1 then
			return false
		end
		player = all[1]
		return clients[player]
			and P.Get(player)
			and player.Character
			and player.Character:FindFirstChildOfClass("Humanoid")
			and player.Character:FindFirstChild("HumanoidRootPart")
	end, math.max(0, 60 - (os.clock() - startedAt)))
	check("startup client ACK/profile/character ready", startupReady, Copy(report.startup))
	assert(
		startupReady,
		"startup_timeout: see report.startup for client phase/error and missing dependencies"
	)
	report.startup.phase = "complete"
	assert(player.UserId < 0, "Refuse real account fixture")
	backup, creative, original =
		Copy(P.Get(player)), player:GetAttribute("Creative"), player.Character:GetPivot()
	report.input = clients[player]
	player:SetAttribute("Creative", false)
	P.Mutate(player, function(p)
		p.level = 10
		p.location = "prison"
		p.faction = nil
		p.gangId = nil
		p.hunger = 20
		p.saturation = 10
		p.needsFree = true
		p.needs = { hygiene = 100, sleep = 100, toilet = 100 }
		p.armor = {}
		p.trainer = {}
		p.skills = {}
		p.inventory = {}
		p.selectedSlot = 1
		p.autosell = false
	end)
	local character, humanoid = player.Character, player.Character.Humanoid
	humanoid.MaxHealth, humanoid.Health = 100, 100
	report.lifecycle = { respawns = 0, deaths = 0 }
	table.insert(
		observers,
		player.CharacterAdded:Connect(function()
			report.lifecycle.respawns += 1
		end)
	)
	table.insert(
		observers,
		humanoid.Died:Connect(function()
			report.lifecycle.deaths += 1
		end)
	)
	floor = Instance.new("Part")
	floor.Name, floor.Anchored = "QAReleaseItemsFloor", true
	floor.Size, floor.Position = Vector3.new(300, 2, 300), Vector3.new(0, 200, 0)
	floor.Parent = workspace
	local start = CFrame.new(0, 206, 0)
	player:RequestStreamAroundAsync(start.Position)
	local function pose(cf)
		Fall.Reset(player)
		-- Reset and authoritative reposition must be synchronous (client transport has latency).
		player.Character:PivotTo(cf)
		player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		return rpc:InvokeClient(player, "pose", cf)
	end
	pose(start)
	task.wait(1)
	-- Real food remote and real timer/random effect, with repeat only to observe an 80% branch.
	local foodTrials, effectUntil = {}, nil
	for trial = 1, 12 do
		character:SetAttribute("Hunger", nil)
		character:SetAttribute("HungerUntil", nil)
		P.Mutate(player, function(p)
			p.inventory = { [1] = { id = "rotten_flesh", count = 2 } }
			p.selectedSlot = 1
			p.hunger = 10
			p.saturation = nil
		end)
		task.wait(0.25)
		local startedAt = os.clock()
		rpc:InvokeClient(player, "eat")
		task.wait(0.8)
		check("rotten early timer trial" .. trial, P.Get(player).inventory[1].count == 2)
		assert(
			waitFor(function()
				return P.Get(player).inventory[1].count == 1
			end, 2),
			"Food was not consumed"
		)
		local p = P.Get(player)
		local level = character:GetAttribute("Hunger")
		local remaining = (character:GetAttribute("HungerUntil") or 0)
			- workspace:GetServerTimeNow()
		table.insert(foodTrials, {
			elapsed = os.clock() - startedAt,
			hunger = p.hunger,
			saturation = p.saturation,
			level = level,
			remaining = remaining,
		})
		check(
			"rotten gives four food and saturation trial" .. trial,
			p.hunger > 13.8 and p.hunger <= 14 and (p.saturation or 0) > 0.7
		)
		if level == 1 then
			check("rotten Hunger lasts thirty seconds", remaining > 29 and remaining <= 30)
			effectUntil = character:GetAttribute("HungerUntil")
			break
		end
	end
	report.food = foodTrials
	check("observed real 80 percent Hunger branch", effectUntil ~= nil)
	assert(effectUntil, "No Hunger branch in twelve attempts")
	-- Compare two stationary measurements, including the real idle drain in both.
	local function measure(level)
		character:SetAttribute("Hunger", nil)
		character:SetAttribute("HungerUntil", nil)
		if level then
			Book.GiveHunger(player, 1, 30)
		end
		P.Mutate(player, function(p)
			p.hunger = 14
			p.saturation = 5
		end)
		local before, at = P.Get(player).saturation, os.clock()
		task.wait(4)
		return { drain = before - (P.Get(player).saturation or 0), seconds = os.clock() - at }
	end
	local baseline, hungry = measure(false), measure(true)
	local excess = hungry.drain - baseline.drain * hungry.seconds / baseline.seconds
	report.hungerDrain = {
		baseline = baseline,
		hungry = hungry,
		excess = excess,
		expected = Potions.HUNGER_PER_SECOND * hungry.seconds,
	}
	check(
		"Hunger produces real extra exhaustion",
		math.abs(excess - Potions.HUNGER_PER_SECOND * hungry.seconds) < 0.04,
		excess
	)
	effectUntil = character:GetAttribute("HungerUntil")
	-- Real physics, same direction/sprint warmup, ordinary vs Springs single vs Springs extra.
	for _, spec in
		{
			{ name = "ordinary sprint jump" },
			{ name = "ordinary rejects extra", extra = true },
			{ name = "Springs single jump", boots = true },
			{ name = "Springs second jump", boots = true, extra = true },
		}
	do
		P.Mutate(player, function(p)
			p.armor.boots = if spec.boots
				then {
					id = "boots",
					count = 1,
					level = 1,
					books = { { id = "springs", level = 1 } },
				}
				else nil
			p.hunger = 20
			p.saturation = 10
		end)
		task.wait(0.6)
		pose(start)
		local r = rpc:InvokeClient(
			player,
			"jump",
			{ pose = start, extra = spec.extra, third = spec.boots and spec.extra }
		)
		r.name = spec.name
		table.insert(report.jumps, r)
		check(
			spec.name .. " started sprinting",
			r.before.sprint and r.before.horizontal > 10,
			r.before
		)
		check(spec.name .. " real takeoff and landing", r.takeoff.vy > 1 and r.landed)
		check(
			spec.name .. " sprint survives takeoff",
			r.takeoff.sprint and r.takeoff.horizontal >= r.before.horizontal * 0.85
		)
		if spec.extra then
			local b, a = r.beforeSecond, r.afterSecond
			check(spec.name .. " second press is actually airborne", b.floor == "Air", b)
			check(
				spec.name .. " horizontal velocity retained",
				a.horizontal >= b.horizontal * 0.85
					and math.abs(a.vx - b.vx) < 2
					and math.abs(a.vz - b.vz) < 2,
				{ before = b, after = a }
			)
			if spec.boots then
				check(
					"second Spring supplies positive vertical impulse",
					a.vy > 10 and a.vy > b.vy + 4
				)
				check("second Spring retains sprint flag", a.sprint)
			else
				check("no airborne extra without Springs", a.vy <= b.vy + 1)
			end
			if spec.boots then
				check(
					"Spring third press is actually airborne",
					r.beforeThird ~= nil and r.beforeThird.floor == "Air" and r.afterThird ~= nil,
					r.beforeThird
				)
				check(
					spec.name .. " rejects third jump",
					r.afterThird ~= nil and r.afterThird.vy <= r.beforeThird.vy + 1
				)
			end
		end
	end
	check(
		"Springs first jump rises higher than normal",
		report.jumps[3].rise > report.jumps[1].rise + 0.3
	)
	check(
		"second Spring adds real airborne height",
		report.jumps[4].rise > report.jumps[3].rise + 0.5
	)
	-- Live UI, real profile patches and EconomyService upgrade, with no paid purchase.
	P.Mutate(player, function(p)
		p.coins = 100000000
		p.selectedSlot = 12
		p.armor = {}
		p.inventory = {}
		for i = 1, 20 do
			p.inventory[i] = { id = "pickaxe", count = 1, level = 1 }
		end
		for _, tool in Config.tools do
			for _, up in tool.upgrades do
				for id in up.requirements do
					p.counters[id] = 100000000
				end
			end
		end
	end)
	task.wait(0.6)
	report.upgrade = { before = rpc:InvokeClient(player, "upgradeOpen"), actions = {} }
	check(
		"upgrade selected slot12 and button visible",
		report.upgrade.before.selected == 12
			and report.upgrade.before.visible
			and report.upgrade.before.inside
			and report.upgrade.before.enabled,
		report.upgrade.before
	)
	for wanted = 2, 3 do
		local intents = {}
		local observe = require(Shared.Remotes)
			.event("UpgradeItem").OnServerEvent
			:Connect(function(sender, slot)
				if sender == player then
					table.insert(intents, slot)
				end
			end)
		local response = rpc:InvokeClient(
			player,
			"upgradeBuy",
			{ offset = report.upgrade.coordinateMode or "inset" }
		)
		table.insert(report.upgrade.actions, response)
		local changed = waitFor(function()
			return P.Get(player).inventory[12].level == wanted
		end, 3)
		-- Calibrate virtual-screen inset only when no ordinary UpgradeItem intent was delivered.
		-- Never click twice after a received request: delayed profile/UI refresh cannot double-buy.
		if
			not changed
			and #intents == 0
			and response.mode == "VirtualInput"
			and response.offset == "inset"
			and response.inset
			and response.inset.y ~= 0
		then
			response = rpc:InvokeClient(player, "upgradeBuy", { offset = "absolute" })
			table.insert(report.upgrade.actions, response)
			changed = waitFor(function()
				return P.Get(player).inventory[12].level == wanted
			end, 3)
		end
		observe:Disconnect()
		if changed then
			report.upgrade.coordinateMode = response.offset
		end
		check(
			"upgrade delivers one ordinary remote for selected slot at" .. wanted,
			#intents == 1 and intents[1] == 12,
			intents
		)
		check("upgrade selected item to" .. wanted, changed)
		task.wait(0.4)
		local ui = rpc:InvokeClient(player, "upgradeState")
		table.insert(report.upgrade.actions, ui)
		check(
			"upgrade keeps next action slot and scroll at" .. wanted,
			ui.enabled
				and ui.visible
				and ui.inside
				and ui.selected == 12
				and math.abs(ui.scroll - report.upgrade.before.scroll) < 1,
			ui
		)
	end
	rpc:InvokeClient(player, "stop")
	-- Actual query/index code under the engine, entirely separate memory cache; never AuctionDebug.seed.
	local auction = require(Services.QAReleaseItemsAuction)
	local now = os.time()
	local lots = {
		{
			id = "a",
			item = { id = "pickaxe", level = 4, count = 1 },
			price = 30000,
			createdAt = now - 4,
		},
		{
			id = "b",
			item = { id = "sword", level = 2, count = 1 },
			price = 10000,
			createdAt = now - 2,
		},
		{
			id = "c",
			item = { id = "pickaxe", level = 4, count = 1 },
			price = 30000,
			createdAt = now - 4,
		},
		{
			id = "d",
			item = { id = "apple", count = 3 },
			price = 9,
			cur = "rubies",
			createdAt = now - 1,
		},
		{
			id = "e",
			item = { id = "apple", count = 1 },
			price = 2,
			cur = "rubies",
			createdAt = now - 5,
		},
	}
	for _, lot in lots do
		lot.expiresAt = now + 1000
		lot.seller = -1000
		lot.sellerName = "QA"
		auction.add(lot)
	end
	local expected = {
		time = { "e,a,c,b,d", "d,b,a,c,e" },
		price = { "b,a,c,e,d", "a,c,b,d,e" },
		level = { "d,e,b,a,c", "a,c,b,d,e" },
	}
	local after = {
		time = { "e,a,c,b,d,new", "new,d,b,a,c,e" },
		price = { "new,b,a,c,e,d", "a,c,b,new,d,e" },
		level = { "d,e,b,a,c,new", "new,a,c,b,d,e" },
	}
	for phase, answers in { expected, after } do
		if phase == 2 then
			local lot = Copy(lots[1])
			lot.id = "new"
			lot.price = 5000
			lot.createdAt = now
			lot.item.level = 20
			auction.add(lot)
		end
		for sort, order in answers do
			for index, desc in { false, true } do
				task.wait(0.6)
				local answer = auction.query(player, { sort = sort, desc = desc })
				local ids = {}
				for _, lot in (answer and answer.lots) or {} do
					table.insert(ids, lot.id)
				end
				check(
					"auction " .. phase .. " " .. sort .. " " .. tostring(desc),
					table.concat(ids, ",") == order[index],
					ids
				)
			end
		end
	end
	-- Real normal-zone mine cells and DigService completion. Never invent/change mine contents.
	local Mine = require(Services.MineService)
	local Inventory = require(Services.InventoryService)
	local MiningRemotes = require(Shared.Remotes)
	-- QA_SILK_PLAN_BEGIN: also checked against the current real config offline.
	local silkPlan = {
		{ id = "stone_stone_tier", mine = "quarry", block = "stone", tool = "pickaxe", level = 5 },
		{ id = "stone_max_tier", mine = "quarry", block = "stone", tool = "pickaxe", level = 16 },
		{
			id = "coal_stone_tier",
			mine = "quarry",
			block = "coal_ore",
			tool = "pickaxe",
			level = 5,
		},
		{
			id = "iron_wrong_tier",
			mine = "quarry",
			block = "iron_ore",
			tool = "pickaxe",
			level = 1,
		},
		{
			id = "iron_correct_tier",
			mine = "quarry",
			block = "iron_ore",
			tool = "pickaxe",
			level = 5,
		},
		{ id = "melon_slices", mine = "prison_small", block = "melon", tool = "axe", level = 1 },
	}
	-- QA_SILK_PLAN_END
	report.silk = { pairs = {}, mines = {}, consumedCells = 0 }
	local function mineReady(id)
		assert(
			waitFor(function()
				local m = Mine.get(id)
				return m and not m.rebuilding and next(m.parts) ~= nil
			end, 20),
			"fixture_unavailable: mine " .. id .. " absent or still rebuilding"
		)
		local mine = Mine.get(id)
		assert(
			not mine.location.pvp and not mine.location.shot,
			"Expected normal non-PvP, non-shot mine"
		)
		assert(
			mine.location.id == (if id == "quarry" then "quarry" else "prison"),
			"Mine location mismatch"
		)
		if not report.silk.mines[id] then
			local exposed = {}
			for index, part in mine.parts do
				local _, y = Mine.coords(mine, index)
				local blockId = mine.cells[index]
				if y == 1 and part.Parent and blockId then
					exposed[blockId] = (exposed[blockId] or 0) + 1
				end
			end
			report.silk.mines[id] = {
				location = mine.location.id,
				generation = mine.generation,
				exposedTop = exposed,
				shares = Copy(mine.shares),
				pvp = mine.location.pvp,
				shot = mine.location.shot ~= nil,
			}
		end
		return mine
	end
	local function exposedCell(mine, blockId)
		local indices = {}
		for index in mine.parts do
			table.insert(indices, index)
		end
		table.sort(indices)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		for _, index in indices do
			local part = mine.parts[index]
			local x, y, z = Mine.coords(mine, index)
			if
				not part.Parent
				or y ~= 1
				or x < 2
				or z < 2
				or x > mine.size[1] - 1
				or z > mine.size[3] - 1
				or mine.cells[index] ~= blockId
			then
				continue
			end
			-- Quarry decoration can obstruct its rim. Stand on an adjacent actual unmined
			-- top cell, never the cell being removed; no synthetic support or LoS bypass.
			for _, offset in { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } do
				local supportIndex = Mine.index(mine, x + offset[1], 1, z + offset[2])
				local support = mine.parts[supportIndex]
				if
					not support
					or not support.Parent
					or not support.CanCollide
					or not mine.cells[supportIndex]
				then
					continue
				end
				local at = support.Position + Vector3.new(0, support.Size.Y / 2 + 4, 0)
				local ground = workspace:Raycast(at, Vector3.new(0, -12, 0), params)
				if not ground or ground.Instance ~= support then
					continue
				end
				local eye = Vector3.new(at.X, ground.Position.Y + 5, at.Z)
				local target = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
				local hit = workspace:Raycast(eye, target - eye, params)
				if (target - eye).Magnitude <= 18 and hit and hit.Instance == part then
					return part, index, CFrame.new(at)
				end
			end
		end
		error(
			"fixture_unavailable: no adjacent-support exposed top " .. blockId .. " in " .. mine.id
		)
	end
	for _, spec in silkPlan do
		local mine = mineReady(spec.mine)
		local block = assert(Config.block(spec.block))
		local pair = {
			id = spec.id,
			mine = spec.mine,
			block = spec.block,
			tool = spec.tool,
			level = spec.level,
			trials = {},
		}
		table.insert(report.silk.pairs, pair)
		for _, silk in { false, true } do
			local part, index, standingPose = exposedCell(mine, spec.block)
			local generation = mine.generation
			P.Mutate(player, function(p)
				p.location = mine.location.id
				p.armor = {}
				p.autosell = false
				p.selectedSlot = 1
				p.inventory = {
					[1] = {
						id = spec.tool,
						level = spec.level,
						count = 1,
						books = if silk then { { id = "silk_touch", level = 1 } } else nil,
					},
				}
			end)
			player:RequestStreamAroundAsync(standingPose.Position)
			local clientPose = pose(standingPose)
			task.wait(0.4) -- let the real profile patch/book and server character position settle
			local targetHit = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
			local function diagnostics()
				local c, profile = player.Character, P.Get(player)
				local root = c and c:FindFirstChild("HumanoidRootPart")
				local head = c and c:FindFirstChild("Head")
				local h = c and c:FindFirstChildOfClass("Humanoid")
				local eye = head and head.Position
					or (root and root.Position + Vector3.new(0, 1.5, 0))
				local ray
				if eye then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { c }
					ray = workspace:Raycast(eye, targetHit - eye, params)
				end
				local function v(value)
					return if value then { x = value.X, y = value.Y, z = value.Z } else nil
				end
				local held, heldLevel = Inventory.heldTool(profile)
				local drop = if silk then spec.block else (block.dropsAs or spec.block)
				local reasons = {}
				if mine.rebuilding or mine.generation ~= generation then
					table.insert(reasons, "mine_reset")
				end
				if profile.level < mine.location.unlockLevel then
					table.insert(reasons, "player_level")
				end
				if profile.needs.sleep <= 0 then
					table.insert(reasons, "insomnia")
				end
				if
					not Inventory.canAutoSell(profile, drop)
					and not Inventory.canAdd(profile, drop, 1)
				then
					table.insert(reasons, "bag_capacity")
				end
				if ray and ray.Instance ~= part then
					table.insert(reasons, "line_of_sight_blocked")
				end
				if eye and (targetHit - eye).Magnitude > 24 then
					table.insert(reasons, "reach_over_static_slack")
				end
				if held ~= spec.tool or heldLevel ~= spec.level then
					table.insert(reasons, "held_tool_changed")
				end
				if c ~= character then
					table.insert(reasons, "character_changed")
				end
				return {
					at = workspace:GetServerTimeNow(),
					root = root and v(root.Position),
					eye = v(eye),
					velocity = root and v(root.AssemblyLinearVelocity),
					health = h and h.Health,
					floor = h and h.FloorMaterial.Name,
					state = h and h:GetState().Name,
					sameCharacter = c == character,
					location = profile.location,
					tool = held,
					level = heldLevel,
					distance = eye and (targetHit - eye).Magnitude,
					ray = ray and ray.Instance:GetFullName(),
					rayTarget = ray ~= nil and ray.Instance == part,
					targetPresent = part.Parent ~= nil,
					generation = mine.generation,
					inferredRefusalCandidates = reasons,
				}
			end
			local beforePose = diagnostics()
			check(
				spec.id .. " stable living rim pose silk=" .. tostring(silk),
				beforePose.sameCharacter
					and beforePose.health > 0
					and beforePose.floor ~= "Air"
					and beforePose.rayTarget
					and beforePose.location == mine.location.id,
				beforePose
			)
			local haste = character:GetAttribute("Haste") or 0
			assert(
				haste == 0,
				"fixture_unavailable: unexpected Haste changes the timing comparison"
			)
			local expected = assert(Config.breakTime(block, spec.tool, spec.level))
			local beforeClean = P.Get(player).stats.blocksClean or 0
			local beforeOrange = P.Get(player).blocksTotal
			local beginAt, removedAfter, digReceivedAt, serverDigSeconds = os.clock(), nil, nil, nil
			local digStartCount = 0
			local samples, sampledAt = { beforePose }, 0
			local sampling = game.RunService.Heartbeat:Connect(function()
				if os.clock() - sampledAt >= 0.1 then
					sampledAt = os.clock()
					table.insert(samples, diagnostics())
				end
			end)
			local received = MiningRemotes.event("DigStart").OnServerEvent
				:Connect(function(sender, target)
					if sender == player and target == part then
						digStartCount += 1
						digReceivedAt = digReceivedAt or os.clock()
					end
				end)
			local removal = part.Destroying:Connect(function()
				removedAfter = os.clock() - beginAt
				serverDigSeconds = if digReceivedAt then os.clock() - digReceivedAt else nil
			end)
			local response = rpc:InvokeClient(player, "dig", {
				mine = mine.id,
				index = index,
				expectedSeconds = expected,
			})
			local completed = waitFor(function()
				return mine.cells[index] == nil
					and (P.Get(player).stats.blocksClean or 0) > beforeClean
			end, 2)
			removal:Disconnect()
			received:Disconnect()
			sampling:Disconnect()
			local p = P.Get(player)
			local drop = if silk then spec.block else (block.dropsAs or spec.block)
			local range = if not silk and typeof(block.dropCount) == "table"
				then block.dropCount
				else { 1, 1 }
			local itemCount = Inventory.count(p, drop)
			local alternative = if silk then (block.dropsAs or spec.block) else spec.block
			local wrongCount = if alternative ~= drop then Inventory.count(p, alternative) else 0
			local trial = {
				silk = silk,
				index = index,
				generation = generation,
				generationAfter = mine.generation,
				location = p.location,
				haste = haste,
				expectedSeconds = expected,
				response = response,
				serverRemovedAfter = removedAfter,
				serverDigSeconds = serverDigSeconds,
				digStartCount = digStartCount,
				completed = completed,
				drop = drop,
				count = itemCount,
				minCount = range[1],
				maxCount = range[2],
				wrongDropCount = wrongCount,
				clean = (p.stats.blocksClean or 0) - beforeClean,
				orange = p.blocksTotal - beforeOrange,
				material = Config.materialForLevel(spec.level),
				minTier = block.minTier,
				clientPose = clientPose,
				diagnostics = {
					before = beforePose,
					after = diagnostics(),
					samples = samples,
					limitation = "Refusal candidates mirror observable preconditions; private DigService rejection branch is not instrumented.",
				},
			}
			table.insert(pair.trials, trial)
			if completed and generation == mine.generation then
				report.silk.consumedCells += 1
			end
			local label = spec.id .. " silk=" .. tostring(silk)
			check(
				label .. " actual cell removed without reset",
				completed and generation == mine.generation,
				trial
			)
			check(
				label .. " exact drop identity/range and one clean block",
				itemCount >= range[1]
					and itemCount <= range[2]
					and wrongCount == 0
					and trial.clean == 1,
				trial
			)
			check(
				label .. " real accepted server duration matches tool/tier",
				response.accepted
					and not response.rejected
					and math.abs((response.seconds or -1) - expected) < 0.001,
				response
			)
			check(
				label .. " one real intent and full server timer before removal",
				digStartCount == 1
					and serverDigSeconds ~= nil
					and serverDigSeconds >= expected - 0.01,
				{ starts = digStartCount, elapsed = serverDigSeconds, expected = expected }
			)
		end
		check(
			spec.id .. " Silk preserves same-material speed/tier",
			pair.trials[1].response.accepted
				and pair.trials[2].response.accepted
				and math.abs(
						(pair.trials[1].response.seconds or -1)
							- (pair.trials[2].response.seconds or -2)
					)
					< 0.001
		)
	end
	check(
		"twelve actual mine cells exercised",
		report.silk.consumedCells == 12,
		report.silk.consumedCells
	)
	for side, label in { "ordinary", "Silk" } do
		local weak = report.silk.pairs[4].trials[side]
		local strong = report.silk.pairs[5].trials[side]
		check(
			label .. " actual wrong-tier iron remains slower and still drops",
			weak.completed
				and strong.completed
				and weak.count == 1
				and strong.count == 1
				and (weak.response.seconds or -1) > (strong.response.seconds or math.huge)
		)
	end
	if effectUntil then
		assert(
			waitFor(function()
				return workspace:GetServerTimeNow() > effectUntil + 0.5
			end, 32),
			"Hunger expiry wait timed out"
		)
		check("real Hunger status expires", character:GetAttribute("Hunger") == nil)
	end
	check(
		"fixture causes no death or character replacement",
		report.lifecycle.deaths == 0 and report.lifecycle.respawns == 0,
		report.lifecycle
	)
	report.status = "PASS"
	for _, result in report.checks do
		if not result.pass then
			report.status = "FAIL"
		end
	end
end, debug.traceback)
if not ok then
	report.status, report.error = "FAIL", tostring(err)
end
finish()
