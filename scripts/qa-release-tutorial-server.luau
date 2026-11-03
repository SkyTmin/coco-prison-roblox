--!nocheck
-- One fresh negative-ID STS actor, retained real Prison geometry. Never resets a profile/tutorial.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-tutorial-v1"
then
	return
end
local startedAt = os.clock()
local report = {
	status = "RUNNING",
	checks = {},
	transitions = {},
	fixtures = {},
	startup = { phase = "server_bootstrap", timeoutSeconds = 60, messages = 0 },
	rpc = { started = 0, completed = 0, recent = {} },
	realAccountsTouched = false,
	ownerResetExecuted = false,
	syntheticTutorialHooks = false,
	limitations = {
		"Scripted poses/camera framing are fixture movement, not a physical walking-path acceptance test.",
		"UI instances, viewport projection and rendered frames are recorded; no screenshot pixel comparison is claimed.",
		"Reset persistence/rejoin remain the separate isolated qa-release-ui-onboarding suite.",
	},
}
local folder = Instance.new("Folder")
folder.Name = "QAReleaseTutorial"
local session = game.HttpService:GenerateGUID(false)
folder:SetAttribute("Session", session)
folder:SetAttribute("FlowPhase", "startup")
local rpc = Instance.new("RemoteFunction")
rpc.Name, rpc.Parent = "RPC", folder
local ready = Instance.new("RemoteEvent")
ready.Name, ready.Parent = "Ready", folder
local clients = {}
ready.OnServerEvent:Connect(function(sender, info)
	if sender.UserId >= 0 or typeof(info) ~= "table" or info.session ~= session then
		return
	end
	report.startup.messages += 1
	report.startup.lastClient = info
	if info.phase == "ready" then
		clients[sender] = info
		ready:FireClient(sender, { session = session, ack = true })
	end
end)
folder:SetAttribute("ListenerReady", true)
folder.Parent = game.ReplicatedStorage
local P, Copy, Config, Tutorial, Mine, Fall, R
local player, originalPose, originalCreative, ended
local connections = {}
local function check(name, pass, observed)
	table.insert(report.checks, { name = name, pass = pass == true, observed = observed })
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
local function flow(phase)
	report.flowPhase, report.flowPhaseAt = phase, os.clock() - startedAt
	folder:SetAttribute("FlowPhase", phase)
end

-- InvokeClient can wait forever if its client callback stalls/disconnects. Bound each
-- QA observation/action, fail visibly, and never retry an action that may have executed.
local function callClient(op, args, timeoutOverride)
	local record = op ~= "stop"
	assert(not ended or not record, "rpc_aborted: test already ended")
	local budgets =
		{ inspect = 20, pose = 10, sell = 10, upgrade = 20, level = 10, select = 5, stop = 3 }
	local timeout = timeoutOverride
		or (
			if op == "dig"
				then math.max(15, (args.expectedSeconds or 0) + 12)
				else budgets[op] or 20
		)
	local began = os.clock()
	local entry = {
		id = report.rpc.started + 1,
		op = op,
		started = began - startedAt,
		timeout = timeout,
		status = "pending",
	}
	if record then
		report.rpc.started += 1
		report.rpc.active = entry
		table.insert(report.rpc.recent, entry)
		if #report.rpc.recent > 12 then
			table.remove(report.rpc.recent, 1)
		end
		folder:SetAttribute("RpcId", entry.id)
		folder:SetAttribute("RpcOp", op)
		folder:SetAttribute("RpcStatus", "pending")
		folder:SetAttribute("RpcStarted", entry.started)
		folder:SetAttribute("RpcTimeout", timeout)
	end
	local completed, succeeded, response, abandoned = false, false, nil, false
	local worker = task.spawn(function()
		local ok, result = pcall(function()
			return rpc:InvokeClient(player, op, args, entry.id)
		end)
		if abandoned then
			return
		end
		succeeded, response, completed = ok, result, true
	end)
	while not completed and os.clock() - began < timeout and (not ended or not record) do
		task.wait(0.05)
	end
	entry.elapsed = os.clock() - began
	entry.lastClient = report.startup.lastClient
	if not completed then
		abandoned = true
		entry.cancelled = pcall(task.cancel, worker)
		entry.status = if ended and record then "aborted" else "timeout"
		entry.error = "rpc_" .. entry.status .. ": " .. op .. " #" .. entry.id
		if record then
			folder:SetAttribute("RpcStatus", entry.status)
		end
		error(entry.error, 0)
	end
	if not succeeded then
		entry.status, entry.error = "error", tostring(response)
		if record then
			folder:SetAttribute("RpcStatus", "error")
		end
		error("rpc_error: " .. op .. " #" .. entry.id .. ": " .. tostring(response), 0)
	end
	entry.status = "complete"
	if record then
		report.rpc.completed += 1
		report.rpc.active = nil
		folder:SetAttribute("RpcStatus", "complete")
	end
	return response
end
local function finish()
	if ended then
		return
	end
	ended = true
	for _, connection in connections do
		connection:Disconnect()
	end
	if player and player.Parent and player.UserId < 0 and originalPose then
		task.spawn(function()
			pcall(function()
				callClient("stop")
			end)
		end)
		player:SetAttribute("Creative", originalCreative)
		if player.Character then
			Fall.Reset(player)
			player.Character:PivotTo(originalPose)
		end
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
task.delay(1200, function()
	if not ended then
		report.status, report.error = "FAIL", "deadline"
		finish()
	end
end)
local ok, err = xpcall(function()
	local Services, Shared = game.ServerScriptService.Server.Services, game.ReplicatedStorage.Shared
	local function load(module)
		report.startup.phase = "requiring_" .. module.Name
		return require(module)
	end
	P = load(Services.ProfileService)
	Copy = load(Shared.Persistence).copy
	Config = load(Shared.Config)
	Tutorial = load(Shared.Tutorial)
	Mine = load(Services.MineService)
	Fall = load(Services.FallService)
	R = load(Shared.Remotes)
	report.testScope = load(Services.TestSessionScope).Get()
	assert(report.testScope, "Refuse unscoped test session")
	report.moneyScale = Config.moneyScale
	if ended then
		return
	end
	report.startup.phase = "waiting_client_profile_character"
	local started = waitFor(function()
		local all = game.Players:GetPlayers()
		report.startup.players = {}
		for _, actor in all do
			local c = actor.Character
			table.insert(report.startup.players, {
				userId = actor.UserId,
				ready = clients[actor] ~= nil,
				profile = P.Get(actor) ~= nil,
				character = c ~= nil,
				root = c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil,
			})
		end
		report.startup.elapsed = os.clock() - startedAt
		if #all ~= 1 then
			return false
		end
		player = all[1]
		return player.UserId < 0
			and clients[player]
			and P.IsReal(player)
			and player.Character
			and player.Character:FindFirstChild("HumanoidRootPart")
			and player.Character:FindFirstChildOfClass("Humanoid")
	end, math.max(0, 60 - (os.clock() - startedAt)))
	check("fresh simulated actor and ACK bootstrap", started, Copy(report.startup))
	assert(started, "startup_timeout: see startup state")
	report.startup.phase = "complete"
	flow("validate_fresh_spawn")
	local p = P.Get(player)
	report.initialProfile = {
		tutorial = Copy(p.tutorial),
		level = p.level,
		coins = p.coins,
		blocksTotal = p.blocksTotal,
		inventory = Copy(p.inventory),
		location = p.location,
	}
	local fresh = Tutorial.step(p) == 3
		and p.level == 1
		and p.blocksTotal == 0
		and p.coins == 0
		and p.location == "prison"
		and p.inventory[1]
		and p.inventory[1].id == "shovel"
		and p.inventory[1].level == 1
		and not p.autosell
	check(
		"fresh entry starts exact upgrade requirements without reward",
		fresh,
		report.initialProfile
	)
	assert(fresh, "Refuse to reset or manufacture fresh tutorial state")
	assert(workspace:FindFirstChild("Prison"), "fixture_unavailable: retained real Prison missing")
	local prisonSpawn = workspace.Prison:FindFirstChildWhichIsA("SpawnLocation", true)
	assert(
		prisonSpawn and (player.Character:GetPivot().Position - prisonSpawn.Position).Magnitude < 15,
		"fixture_unavailable: fresh actor did not use the real Prison spawn"
	)
	assert(
		waitFor(function()
			return Mine.get("prison") and not Mine.get("prison").rebuilding
		end, 20),
		"Main prison mine unavailable"
	)
	local mine = Mine.get("prison")
	assert(
		mine.location.id == "prison" and not mine.location.pvp and not mine.location.shot,
		"Expected normal main spawn mine"
	)
	originalPose, originalCreative = player.Character:GetPivot(), player:GetAttribute("Creative")
	player:SetAttribute("Creative", false)
	report.fixtures = { { kind = "Creative", before = originalCreative, after = false } }
	report.noResourceGrants = true
	report.digs = {
		count = 0,
		samples = {},
		rejected = 0,
		resetsWaited = 0,
		ordinaryMiningAchievementIncome = 0,
	}
	report.saleIncome = 0
	report.sales = {}
	report.caseGuide = {
		status = "NOT_OBSERVED",
		reason = "No naturally earned ordinary key in hotbar before level 2; no key is granted",
	}
	flow("inspect_spawn")
	report.ui = { spawn = callClient("inspect", { marker = "mine" }) }
	check(
		"initial camera faces actual main spawn mine",
		(report.ui.spawn.mineFacing or -1) > 0.65,
		report.ui.spawn.mineFacing
	)
	flow("inspect_first_target")
	report.ui.first = callClient("inspect", { marker = "mine", frame = true })
	local first = report.ui.first
	check(
		"initial rendered progress card targets existing main-mine block and player path",
		first.panelVisible
			and first.marker.enabled
			and first.marker.mine == "prison"
			and first.marker.inWorkspace
			and first.highlight.sameTarget
			and first.renderedFrames >= 2
			and first.marker.onScreen
			and first.pathConnected
			and not first.requirementsReady,
		first
	)
	local firstGoal = Tutorial.upgradeGoal(p)
	check(
		"mine marker uses action word and asset-free directional path",
		first.marker.caption == require(Shared.Strings).t("tutorial_marker_mine", p.locale)
			and first.beamTexture == ""
			and first.groundArrowParts <= 36,
		{
			caption = first.marker.caption,
			texture = first.beamTexture,
			arrows = first.groundArrows,
			parts = first.groundArrowParts,
		}
	)
	report.requiredUpgrade = Copy(firstGoal)
	check(
		"real first upgrade balance retained",
		firstGoal.cost == 5 * Config.moneyScale and #firstGoal.requirements == 3,
		firstGoal
	)
	local seller
	for _, npc in game.CollectionService:GetTagged("SellPoint") do
		if npc:IsDescendantOf(workspace.Prison) then
			seller = npc
			break
		end
	end
	assert(seller, "No real Prison SellPoint")
	local poses = 0
	local function pose(at, purpose)
		local streamBegan = os.clock()
		folder:SetAttribute("StreamStatus", "pending")
		folder:SetAttribute("StreamTimeout", 10)
		local streamOk, streamError = pcall(function()
			player:RequestStreamAroundAsync(at, 10)
		end)
		report.lastStream = {
			purpose = purpose,
			elapsed = os.clock() - streamBegan,
			timeout = 10,
			returned = streamOk,
		}
		folder:SetAttribute("StreamStatus", if streamOk then "returned" else "error")
		assert(streamOk, "stream_request_error: " .. tostring(streamError))
		Fall.Reset(player)
		player.Character:PivotTo(CFrame.new(at))
		player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		local result = callClient("pose", CFrame.new(at))
		poses += 1
		if poses <= 3 or poses % 100 == 0 then
			table.insert(
				report.fixtures,
				{ kind = "scripted_pose", purpose = purpose, observed = result }
			)
		end
		assert(result.grounded and result.speed < 1, "fixture_unavailable: standing pose unstable")
	end
	local function bagValue(profile)
		local units, count = 0, 0
		for _, stack in profile.inventory do
			local block = Config.block(stack.id)
			if
				block
				and block.sellable ~= false
				and block.basePrice > 0
				and not Config.blockLocked(stack.id, profile.level)
			then
				units += math.floor(block.basePrice * Config.moneyScale + 0.5) * stack.count
				count += stack.count
			end
		end
		return units, count
	end
	local function sell(inspectGuide)
		local before = P.Get(player).coins
		local beforeGoal = if Tutorial.step(P.Get(player)) == 3
			then Tutorial.upgradeGoal(P.Get(player))
			else Tutorial.levelGoal(P.Get(player))
		check(
			"sale begins only after all resource requirements",
			beforeGoal and beforeGoal.resourcesReady,
			Copy(beforeGoal)
		)
		local _, count = bagValue(P.Get(player))
		if count == 0 then
			return
		end
		if inspectGuide then
			report.ui.sell = callClient("inspect", { marker = "sell", frame = true })
			local view = report.ui.sell
			check(
				"money deficit with loot points to real seller",
				view.marker.sellPoint
					and view.pathConnected
					and view.panelVisible
					and not view.requirementsReady,
				view
			)
		end
		pose(
			seller.Position + seller.CFrame.LookVector * 6 + Vector3.new(0, 2, 0),
			"real seller proximity"
		)
		local distance = (player.Character.HumanoidRootPart.Position - seller.Position).Magnitude
		assert(distance <= 16, "SellPoint out of reach")
		local action = callClient("sell", { expectHighlight = inspectGuide })
		assert(
			waitFor(function()
				return P.Get(player).coins > before
			end, 4),
			"Actual Sell did not pay"
		)
		local _, remaining = bagValue(P.Get(player))
		local sale = {
			goalBefore = Copy(beforeGoal),
			before = before,
			after = P.Get(player).coins,
			items = count,
			remaining = remaining,
			distance = distance,
			action = action,
		}
		table.insert(report.sales, sale)
		report.saleIncome += sale.after - sale.before
		assert(remaining == 0, "SellAll left unlocked mined resources")
	end
	local function inspectEarnedCaseKey()
		if report.caseGuide.status ~= "NOT_OBSERVED" then
			return
		end
		local profile = P.Get(player)
		local keySlot
		for slot = 1, 9 do
			local stack = profile.inventory[slot]
			if stack and stack.id == "ordinary_key" then
				keySlot = slot
				break
			end
		end
		if not keySlot or profile.tutorial.ordinaryCaseOpened then
			return
		end
		local previous = profile.selectedSlot
		local keyCount = profile.inventory[keySlot].count
		callClient("select", { slot = keySlot })
		assert(
			waitFor(function()
				return P.Get(player).selectedSlot == keySlot
			end, 3),
			"Ordinary SelectSlot did not select earned key"
		)
		local held = callClient("inspect", { marker = "case", phase = "tutorial_first_case" })
		check(
			"naturally earned held key points to ordinary case",
			held.marker.ordinaryCase and held.pathConnected and not held.highlight.enabled,
			held
		)
		callClient("select", { slot = previous })
		assert(
			waitFor(function()
				return P.Get(player).selectedSlot == previous
			end, 3),
			"Ordinary SelectSlot did not restore shovel"
		)
		local restored = callClient("inspect", { close = true })
		check(
			"key in backpack does not replace current tutorial guidance",
			not restored.marker.ordinaryCase and restored.phase ~= "tutorial_first_case",
			restored
		)
		check(
			"case guidance test neither consumes nor grants key",
			P.Get(player).inventory[keySlot].count == keyCount
		)
		report.caseGuide = {
			status = "PASS",
			keySlot = keySlot,
			held = held,
			restored = restored,
			openingTested = false,
		}
	end
	local function chooseCell(counter)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		-- Stand on a different real, unmined top cell. This allows the full genuine surface,
		-- without falling into the cell being mined or manufacturing a support platform.
		for z = 2, mine.size[3] - 1 do
			for x = 2, mine.size[1] - 1 do
				local index = Mine.index(mine, x, 1, z)
				local part = mine.parts[index]
				local block = part and Config.block(mine.cells[index])
				if
					not part
					or not part.Parent
					or not block
					or (counter and block.upgradeCounter ~= counter)
				then
					continue
				end
				for _, offset in { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } do
					local support = mine.parts[Mine.index(mine, x + offset[1], 1, z + offset[2])]
					if not support or not support.Parent then
						continue
					end
					local at = support.Position + Vector3.new(0, support.Size.Y / 2 + 4, 0)
					local target = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
					local eye = at + Vector3.new(0, 1, 0)
					-- Native rays ending exactly on the face can miss it. Extend only this
					-- fixture probe; the real dig intent still uses the actual surface/reach checks.
					local direction = target - eye
					local hit = workspace:Raycast(eye, direction + direction.Unit * 0.1, params)
					if hit and hit.Instance == part then
						return part, index, at
					end
				end
			end
		end
		return nil
	end
	local function digOne(counter)
		if mine.rebuilding or mine.resetAt - os.clock() < 3 then
			report.digs.resetsWaited += 1
			assert(
				waitFor(function()
					return not mine.rebuilding and mine.resetAt - os.clock() > 4
				end, 25),
				"Natural reset did not finish"
			)
		end
		local part, index, at = chooseCell(counter)
		if not part and counter then
			part, index, at = chooseCell(nil)
		end
		if not part then
			report.digs.resetsWaited += 1
			local old = mine.generation
			assert(
				waitFor(function()
					return mine.generation ~= old and not mine.rebuilding
				end, 310),
				"No safe remaining surface before natural reset"
			)
			part, index, at = chooseCell(counter)
		end
		assert(part, "No genuinely exposed cell")
		pose(at, "adjacent actual top cell support")
		local before = P.Get(player)
		local blockId = mine.cells[index]
		local block = Config.block(blockId)
		local tool = before.inventory[before.selectedSlot]
		assert(tool and tool.id == "shovel", "Actual starter shovel is not held")
		local seconds = Config.breakTime(
			block,
			tool.id,
			tool.level,
			player.Character:GetAttribute("Haste") or 0
		)
		local clean = before.stats.blocksClean or 0
		local coinsBeforeDig = before.coins
		local generation = mine.generation
		local began, removed, intents = nil, nil, 0
		local intent = R.event("DigStart").OnServerEvent:Connect(function(sender, target)
			if sender == player and target == part then
				intents += 1
				began = began or os.clock()
			end
		end)
		local destroying = part.Destroying:Connect(function()
			removed = began and os.clock() - began
		end)
		local action =
			callClient("dig", { mine = "prison", index = index, expectedSeconds = seconds })
		intent:Disconnect()
		destroying:Disconnect()
		local after = P.Get(player)
		report.digs.ordinaryMiningAchievementIncome += after.coins - coinsBeforeDig
		local evidence = {
			index = index,
			block = blockId,
			seconds = seconds,
			removedAfter = removed,
			intents = intents,
			action = action,
			cleanDelta = (after.stats.blocksClean or 0) - clean,
			generation = generation,
			generationAfter = mine.generation,
			health = player.Character.Humanoid.Health,
			location = after.location,
		}
		local passed = action.accepted
			and not action.rejected
			and intents == 1
			and removed
			and removed >= seconds - 0.02
			and math.abs((action.seconds or -1) - seconds) < 0.001
			and mine.cells[index] == nil
			and generation == mine.generation
			and evidence.cleanDelta == 1
		if not passed then
			report.digs.failure = evidence
			report.digs.rejected += 1
			error("Real dig failed; see digs.failure")
		end
		report.digs.count += 1
		if report.digs.count <= 3 or report.digs.count % 50 == 0 then
			table.insert(report.digs.samples, evidence)
		end
	end
	flow("dig_first_block")
	digOne(firstGoal.requirements[1].counter)
	flow("inspect_after_first_block")
	report.ui.afterFirst = callClient("inspect", { marker = "mine" })
	check(
		"first real block keeps mining rather than premature selling",
		Tutorial.step(P.Get(player)) == 3
			and not Tutorial.upgradeGoal(P.Get(player)).saleReady
			and report.ui.afterFirst.marker.mine == "prison",
		report.ui.afterFirst
	)
	local function gather(stage)
		while not ended do
			local profile = P.Get(player)
			local goal = if stage == 3
				then Tutorial.upgradeGoal(profile)
				else Tutorial.levelGoal(profile)
			assert(goal, "Expected real progression goal")
			flow(
				if goal.ready
					then "ready_" .. stage
					elseif goal.saleReady then "sell_" .. stage
					elseif stage == 3 and profile.tutorial.upgradeSold then "earn_upgrade"
					else "mine_" .. stage
			)
			inspectEarnedCaseKey()
			if goal.ready then
				return goal
			end
			if goal.saleReady then
				sell(true)
				if stage == 3 and not report.ui.afterFirstSale then
					local after = Tutorial.upgradeGoal(P.Get(player))
					if not after.ready then
						report.ui.afterFirstSale = callClient(
							"inspect",
							{ marker = "none", phase = "tutorial_earn_upgrade", close = true }
						)
						local view = report.ui.afterFirstSale
						check(
							"first real sale records earning phase without block highlight or beam",
							P.Get(player).tutorial.upgradeSold == true
								and view.panelVisible
								and not view.highlight.enabled
								and not view.pathConnected,
							view
						)
					else
						report.ui.afterFirstSale = {
							skipped = true,
							reason = "Actual income already covered upgrade; no forced deficit",
						}
					end
				end
				continue
			end
			local wanted
			if stage == 3 then
				for _, requirement in goal.requirements do
					if requirement.have < requirement.needed then
						wanted = requirement.counter
						break
					end
				end
			end
			digOne(wanted)
			if stage == 3 and profile.tutorial.upgradeSold and not report.ui.afterPostSaleBlock then
				local after = Tutorial.upgradeGoal(P.Get(player))
				if not after.ready and not after.saleReady then
					report.ui.afterPostSaleBlock = callClient(
						"inspect",
						{ marker = "none", phase = "tutorial_earn_upgrade", close = true }
					)
					local view = report.ui.afterPostSaleBlock
					check(
						"one post-sale block does not restart individual highlights or seller trip",
						not view.marker.enabled
							and not view.highlight.enabled
							and not view.pathConnected,
						view
					)
				end
			end
			if report.digs.count % 50 == 0 then
				folder:SetAttribute("Mined", report.digs.count)
				folder:SetAttribute("Coins", P.Get(player).coins)
				folder:SetAttribute("Stage", stage)
			end
		end
		error("Test ended while gathering")
	end
	local goal = gather(3)
	flow("inspect_upgrade_menu")
	report.ui.upgradeMenuButton =
		callClient("inspect", { marker = "none", control = "menu", close = true })
	check(
		"affordable shovel first points at actual Menu button",
		report.ui.upgradeMenuButton.settled and report.ui.upgradeMenuButton.uiArrowVisible,
		report.ui.upgradeMenuButton
	)
	report.ui.upgradeReady = callClient("inspect", { marker = "none", menu = true })
	check(
		"all actual requirements unlock Menu to Upgrade guidance",
		report.ui.upgradeReady.requirementsReady and report.ui.upgradeReady.menuUpgradeHighlighted,
		report.ui.upgradeReady
	)
	local coinsBefore = P.Get(player).coins
	flow("upgrade_shovel")
	report.upgradeAction = callClient("upgrade", { slot = goal.target })
	assert(
		waitFor(function()
			return Tutorial.step(P.Get(player)) == 4
		end, 5),
		"Actual upgrade did not start level task"
	)
	p = P.Get(player)
	check(
		"actual UpgradeItem debits cost and opens new level task",
		p.inventory[goal.target].level == goal.to
			and p.coins == coinsBefore - goal.cost
			and p.tutorial.completedAt == nil,
		Copy(p.tutorial)
	)
	table.insert(report.transitions, Copy(p.tutorial))
	report.requiredLevel = Copy(Tutorial.levelGoal(p))
	flow("inspect_level_task")
	report.ui.levelTask = callClient("inspect", { close = true })
	check(
		"upgrade leaves level progress card visible",
		report.ui.levelTask.panelVisible
			and report.ui.levelTask.step == 4
			and not report.ui.levelTask.requirementsReady
			and not report.ui.levelTask.highlight.enabled,
		report.ui.levelTask
	)
	local levelGoal = gather(4)
	flow("inspect_level_menu")
	report.ui.levelMenuButton =
		callClient("inspect", { marker = "none", control = "menu", close = true })
	check(
		"affordable level first points at actual Menu button",
		report.ui.levelMenuButton.settled and report.ui.levelMenuButton.uiArrowVisible,
		report.ui.levelMenuButton
	)
	coinsBefore = P.Get(player).coins
	report.ui.levelReady = callClient("inspect", { marker = "none", menu = true, level = true })
	check(
		"level requirements unlock real level menu guidance",
		report.ui.levelReady.requirementsReady and report.ui.levelReady.menuLevelHighlighted,
		report.ui.levelReady
	)
	flow("level_up")
	report.levelAction = callClient("level")
	assert(
		waitFor(function()
			return Tutorial.step(P.Get(player)) == 5
		end, 5),
		"Actual LevelUp did not complete guide"
	)
	p = P.Get(player)
	report.finalProfile = {
		tutorial = Copy(p.tutorial),
		shovelLevel = p.inventory[goal.target].level,
		level = p.level,
		coins = p.coins,
		blocksTotal = p.blocksTotal,
		clean = p.stats.blocksClean,
	}
	check(
		"actual LevelUp completes guide and debits configured money",
		p.level == levelGoal.level
			and p.coins == coinsBefore - levelGoal.cost
			and p.tutorial.completedAt ~= nil,
		report.finalProfile
	)
	table.insert(report.transitions, Copy(p.tutorial))
	flow("verify_completion")
	report.ui.completed = callClient("inspect", { marker = "none", close = true })
	local complete = report.ui.completed
	check(
		"completion hides card markers beam and strokes",
		not complete.panelVisible
			and not complete.marker.enabled
			and not complete.highlight.enabled
			and not complete.pathConnected
			and complete.guideStrokes == 0,
		complete
	)
	if report.caseGuide.status == "PASS" then
		local previous = P.Get(player).selectedSlot
		callClient("select", { slot = report.caseGuide.keySlot })
		assert(
			waitFor(function()
				return P.Get(player).selectedSlot == report.caseGuide.keySlot
			end, 3),
			"Cannot select earned key after level2"
		)
		report.caseGuide.afterLevelTwo = callClient("inspect", { marker = "none", close = true })
		check(
			"level two ends even unopened-case guidance with key held",
			not report.caseGuide.afterLevelTwo.marker.enabled
				and not report.caseGuide.afterLevelTwo.pathConnected,
			report.caseGuide.afterLevelTwo
		)
		callClient("select", { slot = previous })
	end
	check(
		"every counted cell passed real intent acceptance completion and clean+1",
		report.digs.count > 0 and report.digs.rejected == 0,
		report.digs.count
	)
	flow("save_completion")
	report.scopedSaveConfirmed = P.SaveNow(player)
	check("completed guide saved in isolated test scope", report.scopedSaveConfirmed == true)
	report.elapsed = os.clock() - startedAt
	report.status = "PASS"
	for _, result in report.checks do
		if not result.pass then
			report.status = "FAIL"
		end
	end
	flow("complete")
end, debug.traceback)
if not ok then
	report.status, report.error = "FAIL", tostring(err)
end
finish()
