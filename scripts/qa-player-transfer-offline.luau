--!nocheck
-- Actual PlayerTransferService + actual ProfileService durable writes. All keys/stores/players are isolated fakes.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local rb = require("@lune/roblox")
local factory = require("./qa-profile-persistence-offline").fixture
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in value do
		result[k] = copy(v)
	end
	return result
end
local Reset = assert(loadstring(fs.readFile("src/shared/ProgressReset.luau")))
setfenv(
	Reset,
	setmetatable({
		script = { Parent = { Persistence = "Persistence" } },
		require = function()
			return { copy = copy }
		end,
	}, { __index = getfenv() })
)
Reset = Reset()
local function fixture(kind)
	local f = factory()
	local a, b = f:player(), f:player()
	a.UserId, b.UserId = -101, -202
	local boundary = f:profile("transfer-A")
	local sa, sb = f:session(boundary, a, "a"), f:session(boundary, b, "b")
	sa.profile.coins, sb.profile.coins, sa.profile.rubies, sb.profile.rubies = 10000, 1000, 90, 10
	sa.profile.inventory = {
		[1] = { id = "apple", count = 10 },
		[2] = {
			id = "ancient_book",
			count = 3,
			level = 2,
			books = { { id = "hammer", level = 2 } },
			rarity = "epic",
			applyChance = 73,
		},
	}
	sb.profile.inventory = {}
	assert(
		boundary.service.SaveNow(a) and boundary.service.SaveNow(b),
		"Fixture initial saves failed"
	)
	local service = f:playerTransfers(boundary)
	local function submit()
		local value = if kind == "gift" then copy(sa.profile.inventory[2]) else 250
		if kind == "gift" then
			value.count = 1
		elseif kind == "rubies" then
			value = 25
		end
		return service.Submit(a, b, kind or "pay", value, if kind == "gift" then 2 else nil)
	end
	local fixtureApi = {
		f = f,
		a = a,
		b = b,
		boundary = boundary,
		sa = sa,
		sb = sb,
		service = service,
		submit = submit,
	}
	function fixtureApi:pump()
		self.service.Resolve(a)
		self.service.Resolve(b)
		self.service.Resolve(a)
	end
	function fixtureApi:rejoin()
		f.beforeUpdate, f.afterUpdate = nil, nil
		f:advance(301)
		self.boundary = f:profile("transfer-B")
		self.sa, self.sb =
			f:session(self.boundary, a, "a-new"), f:session(self.boundary, b, "b-new")
		self.service = f:playerTransfers(self.boundary)
	end
	return fixtureApi
end
local function balance(t)
	return t.sa.profile.coins + t.sb.profile.coins
end
local function completed(t, name)
	for _ = 1, 4 do
		t:pump()
	end
	check(
		name .. " settles outgoing/incoming barriers",
		not t.sa.profile.playerTransfer
			and not t.sb.profile.playerTransferIncoming
			and t.boundary.service.CanExport(t.a)
			and t.boundary.service.CanExport(t.b)
	)
	check(
		name .. " coins conserve once",
		t.sa.profile.coins == 9750 and t.sb.profile.coins == 1250 and balance(t) == 11000
	)
	t.boundary.service.SaveNow(t.a)
	t.boundary.service.SaveNow(t.b)
	t:rejoin()
	for _ = 1, 3 do
		t:pump()
	end
	check(
		name .. " survives rejoin once",
		t.sa.profile.coins == 9750 and t.sb.profile.coins == 1250
	)
end
local t = fixture("pay")
check(
	"submit creates unexportable immutable debit outbox",
	t.submit()
		and t.sa.profile.coins == 9750
		and not t.boundary.service.CanExport(t.a)
		and t.a.attributes.SharedStorageBusy
)
check(
	"recipient not credited before sender checkpoint",
	t.sb.profile.coins == 1000 and t.f.disk["User_-101"].coins == 10000
)
check("second transfer while pending rejected", not t.submit())
check(
	"pending transfer blocks own reset",
	Reset.blocked(t.sa.profile) and not t.boundary.service.ResetOwnProgress(t.a)
)
completed(t, "happy path")

-- Failure before and after the debit/outbox is applied. No mailbox publish precedes a confirmed source save.
for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	local fired = false
	local function fault(key)
		if key == "User_-101" and not fired then
			fired = true
			error("source " .. phase)
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.a)
	check(
		"source " .. phase .. " cannot credit receiver",
		fired and t.sb.profile.coins == 1000 and t.f.disk["Inbox_-202"] == nil
	)
	check("source " .. phase .. " remains pending", not t.boundary.service.CanExport(t.a))
	t.f.beforeUpdate, t.f.afterUpdate = nil, nil
	completed(t, "source " .. phase .. " retry")
end

-- Mailbox update can apply and still error. A persisted source debit plus receiver receipt tolerates both.
for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	local fired = false
	local function fault(key)
		if key == "User_-101" and not fired then
			fired = true
			error("source crash " .. phase)
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.a)
	t:rejoin()
	if phase == "before" then
		for _ = 1, 3 do
			t:pump()
		end
		check(
			"uncommitted source crash loses neither balance",
			t.sa.profile.coins == 10000 and t.sb.profile.coins == 1000 and balance(t) == 11000
		)
	else
		completed(t, "source applied-error crash")
	end
end

for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	local fired = false
	local function fault(key)
		if key == "Inbox_-202" and not fired then
			fired = true
			error("mailbox " .. phase)
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.a)
	check(
		"mailbox " .. phase .. " retains durable source outbox",
		fired
			and t.f.disk["User_-101"].playerTransfer ~= nil
			and t.f.disk["User_-101"].coins == 9750
	)
	t.f.beforeUpdate, t.f.afterUpdate = nil, nil
	completed(t, "mailbox " .. phase .. " retry")
end

-- Receiver guard writes may also fail before/after apply, then retry from a new session.
for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	t.service.Resolve(t.a)
	local fired = false
	local function fault(key)
		if key == "User_-202" and not fired then
			fired = true
			error("incoming guard " .. phase)
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.b)
	check("incoming guard " .. phase .. " credits nothing", fired and t.sb.profile.coins == 1000)
	t:rejoin()
	completed(t, "incoming guard " .. phase .. " crash")
end

-- Fail the RECEIPT+GRANT write, after the earlier incoming-guard checkpoint has succeeded.
for _, phase in { "before", "after" } do
	for _, recovery in { "retry", "rejoin" } do
		t = fixture("pay")
		assert(t.submit())
		t.service.Resolve(t.a)
		local calls, fired = 0, false
		local function fault(key)
			if key == "User_-202" then
				calls += 1
				if calls == 2 then
					fired = true
					error("credit " .. phase)
				end
			end
		end
		if phase == "before" then
			t.f.beforeUpdate = fault
		else
			t.f.afterUpdate = fault
		end
		t.service.Resolve(t.b)
		check(
			"credit " .. phase .. " is not published before acknowledgement",
			fired and t.sb.profile.coins == 1000 and not t.boundary.service.CanExport(t.b)
		)
		check("credit " .. phase .. " blocks reset", Reset.blocked(t.sb.profile))
		t.f.beforeUpdate, t.f.afterUpdate = nil, nil
		if recovery == "rejoin" then
			t:rejoin()
		end
		completed(t, "credit " .. phase .. " " .. recovery)
	end
end

-- Sender cleanup is itself durable and retryable, including an applied-but-error clear.
for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	t.service.Resolve(t.a)
	local fired = false
	local function fault(key)
		if key == "Inbox_-202" and not fired then
			fired = true
			error("receipt ack " .. phase)
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.b)
	check(
		"ack " .. phase .. " still owns one durable receipt/grant",
		fired and t.sb.profile.coins == 1250 and t.f.disk["User_-202"].coins == 1250
	)
	t:rejoin()
	completed(t, "receipt ack " .. phase .. " crash")
end

for _, phase in { "before", "after" } do
	t = fixture("pay")
	assert(t.submit())
	t.service.Resolve(t.a)
	t.service.Resolve(t.b)
	local calls, fired = 0, false
	local function fault(key)
		if key == "User_-101" then
			calls += 1
			if calls == 2 then
				fired = true
				error("cleanup " .. phase)
			end
		end
	end
	if phase == "before" then
		t.f.beforeUpdate = fault
	else
		t.f.afterUpdate = fault
	end
	t.service.Resolve(t.a)
	check(
		"cleanup " .. phase .. " cannot repeat receiver credit",
		fired and t.sb.profile.coins == 1250
	)
	t.f.beforeUpdate, t.f.afterUpdate = nil, nil
	completed(t, "cleanup " .. phase)
end

t = fixture("pay")
assert(t.submit())
t.service.Resolve(t.a)
t.service.Resolve(t.b)
local sourceWrites = 0
t.f.afterUpdate = function(key)
	if key == "User_-101" then
		sourceWrites += 1
		if sourceWrites == 2 then
			error("cleanup applied crash")
		end
	end
end
t.service.Resolve(t.a)
t:rejoin()
completed(t, "sender cleanup applied-error crash")

t = fixture("pay")
assert(t.submit())
t.service.Resolve(t.a)
local creditWrites = 0
t.f.beforeUpdate = function(key)
	if key == "User_-202" then
		creditWrites += 1
		if creditWrites == 2 then
			t.boundary.service.Mutate(t.b, function(p)
				p.coins += 37
			end)
		end
	end
end
t.service.Resolve(t.b)
t.f.beforeUpdate = nil
check("concurrent receiver earnings survive grant publication", t.sb.profile.coins == 1287)
t.boundary.service.SaveNow(t.b)
t:rejoin()
t:pump()
check("concurrent receiver earnings and one grant persist", t.sb.profile.coins == 1287)

t = fixture("pay")
assert(t.submit())
t.service.Resolve(t.a)
local packet = copy(t.sa.profile.playerTransfer)
t.service.Resolve(t.b)
t.service.Resolve(t.a)
t.f.disk["Inbox_-202"] = { [packet.id] = { packet = packet } }
t.service.Resolve(t.b)
check("replayed durable mailbox entry uses permanent receipt", t.sb.profile.coins == 1250)
check(
	"progress reset preserves transfer receipts",
	t.boundary.service.ResetOwnProgress(t.b) and t.sb.profile.playerTransferReceipts[packet.id]
)
t.f.disk["Inbox_-202"] = { [packet.id] = { packet = packet } }
t.service.Resolve(t.b)
check("replay after gameplay reset cannot recreate old grant", t.sb.profile.coins == 0)

t = fixture("pay")
assert(t.submit())
t.service.Resolve(t.a)
t.b.Parent = nil
t.service.Resolve(t.a)
check(
	"offline recipient leaves immutable mailbox and debit",
	t.f.disk["Inbox_-202"] ~= nil and t.sa.profile.playerTransfer ~= nil
)
t.b.Parent = true
t:rejoin()
completed(t, "offline receiver new session")

t = fixture("gift")
local original = copy(t.sa.profile.inventory[2])
assert(t.submit())
t.sa.profile.inventory[2].books[1].level = 99
check("gift outbox metadata is immutable", t.sa.profile.playerTransfer.stack.books[1].level == 2)
for i = 1, 36 do
	t.sb.profile.inventory[i] = { id = "stone", count = 64 }
end
t:pump()
local id = next(t.sb.profile.playerTransferGifts)
local received = t.sb.profile.playerTransferGifts[id]
check(
	"full recipient gets durable exact gift queue",
	received.count == 1
		and received.books[1].level == 2
		and received.applyChance == 73
		and received.rarity == "epic"
)
check(
	"settled unclaimed gift may be discarded by explicit own reset",
	not Reset.blocked(t.sb.profile)
)
t.boundary.service.SaveNow(t.b)
t:rejoin()
t:pump()
check(
	"overflow persists without reroll on rejoin",
	t.sb.profile.playerTransferGifts[id].applyChance == 73
)
t.sb.profile.inventory[8] = nil
check(
	"claim consumes queue into exact free slot once",
	t.service.Claim(t.b) == 1
		and t.sb.profile.inventory[8].books[1].level == original.books[1].level
		and t.sb.profile.playerTransferGifts == nil
)
check("repeat claim cannot grant again", t.service.Claim(t.b) == 0)
t.boundary.service.SaveNow(t.b)
t:rejoin()
t:pump()
check(
	"claimed metadata and receipt survive rejoin",
	t.sb.profile.inventory[8].applyChance == 73 and t.sb.profile.playerTransferReceipts[id]
)

for _, posted in { false, true } do
	t = fixture("gift")
	assert(t.submit())
	local oldPacket = copy(t.sa.profile.playerTransfer)
	if posted then
		t.service.Resolve(t.a)
	end
	check(
		"explicit reset accepts before incoming barrier, posted=" .. tostring(posted),
		t.boundary.service.ResetOwnProgress(t.b)
	)
	for _ = 1, 4 do
		t:pump()
	end
	check(
		"old gift outbox never resurrects after reset, posted=" .. tostring(posted),
		t.sb.profile.inventory[1].id == "shovel"
			and t.sb.profile.inventory[2] == nil
			and t.sb.profile.playerTransferGifts == nil
			and t.sb.profile.playerTransferReceipts[oldPacket.id]
			and t.sa.profile.playerTransfer == nil
	)
	t.boundary.service.SaveNow(t.b)
	t:rejoin()
	t.f.disk["Inbox_-202"] = { [oldPacket.id] = { packet = oldPacket } }
	t.service.Resolve(t.b)
	check(
		"old gift tombstone and cleared inventory survive rejoin, posted=" .. tostring(posted),
		t.sb.profile.inventory[2] == nil
			and t.sb.profile.playerTransferGifts == nil
			and t.sb.profile.playerTransferGeneration == 1
	)
	local newGift = copy(t.sa.profile.inventory[2])
	newGift.count = 1
	assert(t.service.Submit(t.a, t.b, "gift", newGift, 2))
	for _ = 1, 4 do
		t:pump()
	end
	check(
		"post-reset gift targets new generation, posted=" .. tostring(posted),
		t.sb.profile.inventory[2].id == "ancient_book"
	)
end
t = fixture("gift")
assert(t.submit())
local legacyPacket = copy(t.sa.profile.playerTransfer)
legacyPacket.recipientGeneration = nil
t.sa.profile.playerTransfer = nil
assert(t.boundary.service.ResetOwnProgress(t.b))
t.f.disk["Inbox_-202"] = { [legacyPacket.id] = { packet = legacyPacket } }
t.service.Resolve(t.b)
check(
	"legacy packet without generation is tombstoned after reset",
	t.sb.profile.playerTransferReceipts[legacyPacket.id] and t.sb.profile.inventory[2] == nil
)

t = fixture("rubies")
assert(t.submit())
t:pump()
check("same transport conserves rubies", t.sa.profile.rubies == 65 and t.sb.profile.rubies == 35)
for _, field in { "storageTransfer", "storageDeath", "bossRewardPending", "playerTransferIncoming" } do
	t = fixture("pay")
	t.sb.profile[field] = {}
	check("recipient pending " .. field .. " blocks new transfer", not t.submit())
end

-- Actual shared test scope + ProfileService store routing. STS never reuses real mailbox/profile keys.
local isolated = factory({ studio = true, testArgs = "release-actions-v1", runName = "run-one" })
isolated.disk["User_-101"] = { coins = 77777, sentinel = "old unscoped simulated profile" }
local qa, qb, real = isolated:player(), isolated:player(), isolated:player()
qa.UserId, qb.UserId, real.UserId = -101, -202, 777
local ib = isolated:profile("test-server")
local iqa, iqb = isolated:session(ib, qa, "qa"), isolated:session(ib, qb, "qb")
local owner = isolated:session(ib, real, "owner")
local scope = isolated.serverAttributes.TestSessionScope
check(
	"STS creates one shared nonempty run scope",
	type(scope) == "string" and scope:sub(1, 4) == "Run_"
)
check(
	"STS profile does not load old unscoped negative key",
	iqa.profile.coins == 0 and isolated.disk["User_-101"].coins == 77777
)
check(
	"positive owner profile stays on original store",
	isolated.disk.User_777 ~= nil and owner.profile.coins == 0
)
iqa.profile.coins = 1000
local transport = isolated:playerTransfers(ib)
check("STS source can submit a scoped transfer", transport.Submit(qa, qb, "pay", 250))
local scopedPacket = copy(iqa.profile.playerTransfer)
transport.Resolve(qa)
local mailboxKey = "PlayerTransfers_QA_v1@" .. scope .. "/Inbox_-202"
check(
	"STS mailbox and packet use shared scope",
	isolated.disk[mailboxKey][scopedPacket.id].packet.testScope == scope
)
check(
	"STS source save uses scoped profile store",
	isolated.disk["PlayerProfiles_v3_QA@" .. scope .. "/User_-101"].coins == 750
		and isolated.disk["User_-101"].coins == 77777
)
check("STS never creates unscoped mailbox key", isolated.disk["Inbox_-202"] == nil)
transport.Resolve(qb)
transport.Resolve(qa)
check("scoped recipient settles once", iqb.profile.coins == 250 and not iqa.profile.playerTransfer)
check(
	"test transfer cannot target positive owner",
	not transport.Submit(qa, real, "pay", 1) and owner.profile.coins == 0
)
owner.profile.coins = 10
check(
	"positive owner cannot target simulated profile",
	not transport.Submit(real, qb, "pay", 1) and owner.profile.coins == 10
)
local otherRun = factory({ studio = true, testArgs = "release-actions-v1", runName = "run-two" })
otherRun.disk = copy(isolated.disk)
local otherActor = otherRun:player()
otherActor.UserId = -202
local ob = otherRun:profile("next-test-server")
local osession = otherRun:session(ob, otherActor, "new")
local otherScope = otherRun.serverAttributes.TestSessionScope
check(
	"next STS run starts a fresh isolated profile",
	otherScope ~= scope and osession.profile.coins == 0
)
otherRun.disk["PlayerTransfers_QA_v1@" .. otherScope .. "/Inbox_-202"] =
	{ [scopedPacket.id] = { packet = scopedPacket } }
otherRun:playerTransfers(ob).Resolve(otherActor)
check(
	"another run's packet cannot credit or freeze current actor",
	osession.profile.coins == 0 and ob.service.CanExport(otherActor)
)
for _, mode in
	{ { studio = true, testArgs = "" }, { studio = false, testArgs = "release-actions-v1" } }
do
	local ordinary = factory(mode)
	local actor = ordinary:player()
	actor.UserId = -303
	ordinary:session(ordinary:profile("ordinary"), actor, "token")
	check(
		"isolation requires both Studio and nonempty test args " .. tostring(mode.studio),
		ordinary.serverAttributes.TestSessionScope == nil and ordinary.disk["User_-303"] ~= nil
	)
end

-- The same actual transport gate protects money, rubies and item gifts, not just the Actions UI.
for _, kind in { "pay", "rubies", "gift" } do
	for _, distance in { 4, 15.999, 16, 16.001, 32 } do
		local near = fixture(kind)
		near.b.Character.root.Position = rb.Vector3.new(distance, 0, 0)
		local beforeA, beforeB = copy(near.sa.profile), copy(near.sb.profile)
		local writes = near.f.writes
		local accepted, reason = near.submit()
		check(kind .. " range decision at " .. distance, accepted == (distance <= 16))
		if distance > 16 then
			check(
				kind .. " too far leaves no debit/journal/write at " .. distance,
				reason == "release_transfer_nearby"
					and near.sa.profile.coins == beforeA.coins
					and near.sa.profile.rubies == beforeA.rubies
					and near.sa.profile.inventory[2].count == beforeA.inventory[2].count
					and near.sb.profile.coins == beforeB.coins
					and not near.sa.profile.playerTransfer
					and near.f.writes == writes
			)
		end
	end
end
for _, state in { "sender_dead", "recipient_dead", "sender_left", "recipient_left", "missing_body" } do
	local near = fixture("pay")
	if state == "sender_dead" then
		near.a.Character.humanoid.Health = 0
	end
	if state == "recipient_dead" then
		near.b.Character.humanoid.Health = 0
	end
	if state == "sender_left" then
		near.a.Parent = nil
	end
	if state == "recipient_left" then
		near.b.Parent = nil
	end
	if state == "missing_body" then
		near.b.Character = nil
	end
	check(
		state .. " refuses new transfer without debit",
		not near.submit() and near.sa.profile.coins == 10000 and not near.sa.profile.playerTransfer
	)
end
local accepted = fixture("pay")
assert(accepted.submit())
accepted.b.Character.root.Position = rb.Vector3.new(32, 0, 0)
accepted.b.Character.humanoid.Health = 0
accepted.b.Parent = nil
-- Distance/life are eligibility at acceptance. Once debited, leaving must not strand the journal.
accepted.service.Resolve(accepted.a)
check(
	"accepted outbox posts after recipient walks away/dies/leaves",
	accepted.f.disk["Inbox_-202"] ~= nil
)
accepted.b.Parent = true
completed(accepted, "accepted nearby transfer recovers after departure")

print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualTransferAndProfile = true,
	realProfiles = false,
	realDataStores = false,
}, true))
