--!nocheck
-- Two negative-ID StudioTestService players only; args release-actions-v1. No owner reset or invites.
-- Uses fresh scoped QA profiles/mailboxes via TestSessionScope; snapshots restored before EndTest.
-- Durable reset/reload is exercised separately by qa-release-ui-onboarding's isolated store fixture.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-actions-v1"
then
	return
end
local P = require(game.ServerScriptService.Server.Services.ProfileService)
local Shared = game.ReplicatedStorage.Shared
local Persistence, Config = require(Shared.Persistence), require(Shared.Config)
local report = {
	status = "RUNNING",
	checks = {},
	realAccountsTouched = false,
	ownerResetExecuted = false,
	nativeTouchTested = false,
	moneyScale = Config.moneyScale,
	money = {},
	testScope = require(game.ServerScriptService.Server.Services.TestSessionScope).Get(),
}
assert(report.testScope, "Refuse unscoped Actions test")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QAReleaseActions", game.ReplicatedStorage
local rpc = Instance.new("RemoteFunction")
rpc.Name, rpc.Parent = "RPC", folder
local ready = Instance.new("RemoteEvent")
ready.Name, ready.Parent = "Ready", folder
local clients, backups, poses, creative = {}, {}, {}, {}
ready.OnServerEvent:Connect(function(p)
	if p.UserId < 0 then
		clients[p] = true
		folder:SetAttribute("Ready_" .. tostring(p.UserId), true)
	end
end)
local ended = false
local function finish()
	if ended then
		return
	end
	ended = true
	for p, backup in backups do
		P.Mutate(p, function(profile)
			for key in profile do
				profile[key] = nil
			end
			for key, value in backup do
				profile[key] = Persistence.copy(value)
			end
		end)
		p:SetAttribute("Creative", creative[p])
		if p.Character and poses[p] then
			p.Character:PivotTo(poses[p])
		end
		P.SaveNow(p)
	end
	game.StudioTestService:EndTest(game.HttpService:JSONEncode(report))
end
task.delay(420, function()
	if not ended then
		report.status, report.error = "FAIL", "deadline"
		finish()
	end
end)
local function check(name, value)
	table.insert(report.checks, { name = name, pass = value == true })
end
local ok, err = xpcall(function()
	local players
	repeat
		task.wait(0.2)
		players = game.Players:GetPlayers()
		for _, player in players do
			assert(player.UserId < 0, "Refuse any real account fixture")
		end
	until #players == 2
		and clients[players[1]]
		and clients[players[2]]
		and P.Get(players[1])
		and P.Get(players[2])
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local a, b = players[1], players[2]
	for _, player in players do
		assert(
			P.IsReal(player) and P.CanExport(player),
			"Simulated profile not loaded or has pending operation"
		)
		backups[player], creative[player] =
			Persistence.copy(P.Get(player)), player:GetAttribute("Creative")
		poses[player] = player.Character:GetPivot()
		player:SetAttribute("Creative", true)
		P.Mutate(player, function(profile)
			profile.inventory, profile.armor, profile.coins, profile.location, profile.selectedSlot =
				{}, {}, 10 * Config.moneyScale, "prison", 1
			profile.settings = { payOff = false, giftOff = false, hidePlayers = false }
		end)
	end
	P.Mutate(a, function(profile)
		profile.inventory[1] = { id = "apple", count = 5 }
		profile.inventory[2] = {
			id = "ancient_book",
			count = 3,
			level = 2,
			books = { { id = "hammer", level = 2 } },
			rarity = "epic",
			applyChance = 73,
		}
	end)
	-- In the same prison position so normal gift range/location validation remains active.
	rpc:InvokeClient(b, "pose", a.Character:GetPivot() * CFrame.new(4, 0, 0))
	task.wait(1)
	local function settle()
		local deadline = os.clock() + 60
		repeat
			local pa, pb = P.Get(a), P.Get(b)
			if
				not pa.playerTransfer
				and not pa.playerTransferIncoming
				and not pb.playerTransfer
				and not pb.playerTransferIncoming
			then
				return
			end
			task.wait(0.2)
		until os.clock() > deadline
		error("Durable transfer did not settle before deadline")
	end
	local function request(who, op, payload)
		local answer = rpc:InvokeClient(who, "action", op, payload)
		if op == "confirm" and answer.ok then
			settle()
		end
		return answer
	end
	local function review(kind, count, slot)
		task.wait(Config.chat.commandCooldownSeconds + 0.25)
		return request(
			a,
			"quote",
			{ kind = kind, recipient = b.UserId, amount = count, count = count, slot = slot }
		)
	end
	local beforeA, beforeB = P.Get(a).coins, P.Get(b).coins
	local payAmount = 2.5
	local payUnits = math.floor(payAmount * Config.moneyScale + 0.5)
	local q = review("pay", payAmount)
	check(
		"money review is read-only",
		q.ok and P.Get(a).coins == beforeA and P.Get(b).coins == beforeB
	)
	local result = request(a, "confirm", q.token)
	report.money.remote = {
		requestedAmount = payAmount,
		expectedUnits = payUnits,
		before = { sender = beforeA, recipient = beforeB },
		after = { sender = P.Get(a).coins, recipient = P.Get(b).coins },
		actualUnits = { debited = beforeA - P.Get(a).coins, credited = P.Get(b).coins - beforeB },
		quote = q,
		reply = result,
	}
	check(
		"normal remote money confirmation",
		result.ok and P.Get(a).coins == beforeA - payUnits and P.Get(b).coins == beforeB + payUnits
	)
	check("coins conserved", P.Get(a).coins + P.Get(b).coins == beforeA + beforeB)
	local replayBefore = { sender = P.Get(a).coins, recipient = P.Get(b).coins }
	result = request(a, "confirm", q.token)
	report.money.replay = {
		reply = result,
		before = replayBefore,
		after = { sender = P.Get(a).coins, recipient = P.Get(b).coins },
	}
	check(
		"money token replay refused",
		not result.ok
			and P.Get(a).coins == beforeA - payUnits
			and P.Get(b).coins == beforeB + payUnits
	)
	q = review("gift", 2, 1)
	result = request(a, "confirm", q.token)
	check(
		"partial stack count conserved",
		result.ok
			and P.Get(a).inventory[1].count == 3
			and P.Get(b).inventory[1].id == "apple"
			and P.Get(b).inventory[1].count == 2
	)
	local book = Persistence.copy(P.Get(a).inventory[2])
	book.count = 1
	q = review("gift", 1, 2)
	result = request(a, "confirm", q.token)
	check(
		"partial metadata stack preserved exactly",
		result.ok
			and P.Get(a).inventory[2].count == 2
			and Persistence.equal(P.Get(b).inventory[2], book)
	)
	check(
		"gift token replay refused",
		not request(a, "confirm", q.token).ok and P.Get(a).inventory[2].count == 2
	)
	q = review("gift", 1, 1)
	P.Mutate(a, function(profile)
		profile.inventory[1].count = 4
	end)
	result = request(a, "confirm", q.token)
	check(
		"changed reviewed stack cannot be retargeted",
		not result.ok and P.Get(a).inventory[1].count == 4 and P.Get(b).inventory[1].count == 2
	)
	P.Mutate(b, function(profile)
		profile.settings.payOff = true
	end)
	local preferenceBefore = { sender = P.Get(a).coins, recipient = P.Get(b).coins }
	q = review("pay", 1)
	result = request(a, "confirm", q.token)
	report.money.preference = {
		quote = q,
		reply = result,
		before = preferenceBefore,
		after = { sender = P.Get(a).coins, recipient = P.Get(b).coins },
	}
	check(
		"recipient payment preference enforced",
		not result.ok
			and P.Get(a).coins == beforeA - payUnits
			and P.Get(b).coins == beforeB + payUnits
	)
	P.Mutate(b, function(profile)
		profile.settings.payOff = false
	end)
	task.wait(Config.chat.commandCooldownSeconds + 0.25)
	result = request(a, "hide")
	check(
		"hide works through normal nonchat action",
		result.ok and P.Get(a).settings.hidePlayers == true
	)
	check(
		"simulated nonowner cannot prepare progress reset",
		not rpc:InvokeClient(a, "resetDenied").ok
	)
	report.layouts = rpc:InvokeClient(a, "layout", P.Get(a))
	for _, layout in report.layouts do
		check(
			"native layout fits " .. layout.viewport.x,
			layout.w <= layout.viewport.x - 24
				and layout.h <= layout.viewport.y - 82
				and layout.formHeight >= 44
		)
		for _, row in layout.rows do
			check(
				"44px target " .. row.name .. " at " .. layout.viewport.x,
				row.h >= 43.5 and row.w >= 43.5
			)
		end
	end
	task.wait(Config.chat.commandCooldownSeconds + 0.25)
	local moneyBeforeUi, recipientBeforeUi = P.Get(a).coins, P.Get(b).coins
	local uiAmount = 3
	local uiUnits = math.floor(uiAmount * Config.moneyScale + 0.5)
	report.ui = rpc:InvokeClient(a, "uiPay", { recipient = b.UserId, amount = uiAmount })
	if not report.ui.skipped then
		settle()
		check("native mouse review and confirmation activate", report.ui.ok)
		check(
			"native UI confirmation transfers once",
			P.Get(a).coins == moneyBeforeUi - uiUnits
				and P.Get(b).coins == recipientBeforeUi + uiUnits
		)
	end
	report.money.ui = {
		requestedAmount = uiAmount,
		expectedUnits = uiUnits,
		before = { sender = moneyBeforeUi, recipient = recipientBeforeUi },
		after = { sender = P.Get(a).coins, recipient = P.Get(b).coins },
		actualUnits = {
			debited = moneyBeforeUi - P.Get(a).coins,
			credited = P.Get(b).coins - recipientBeforeUi,
		},
		result = report.ui.text,
	}
	P.Mutate(a, function(profile)
		profile.tutorial = require(Shared.Tutorial).new()
	end)
	report.guide = rpc:InvokeClient(a, "guide")
	check("first-login guide renders from server profile", report.guide.visible == true)
	-- No synthetic mine/sell/upgrade completion and no destructive reset in this live test.
	report.status = "PASS"
	for _, c in report.checks do
		if not c.pass then
			report.status = "FAIL"
		end
	end
end, debug.traceback)
if not ok then
	report.status, report.error = "FAIL", tostring(err)
end
finish()
