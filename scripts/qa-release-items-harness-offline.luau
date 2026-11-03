--!nocheck
-- Tests the actual live-harness protocol/selector/plan; no Studio, real profiles, or stores.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local server = fs.readFile("scripts/qa-release-items-server.luau")
local client = fs.readFile("scripts/qa-release-items-client.luau")
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function between(source, first, last)
	local a = assert(source:find(first, 1, true), first)
	local b = assert(source:find(last, a + #first, true), last)
	return source:sub(a, b - 1)
end
local function load(source, env)
	local fn = assert(loadstring(source))
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end
for path, source in { server = server, client = client } do
	check(path .. " whole live harness compiles", loadstring(source) ~= nil)
end
local installer = process.exec("node", { "scripts/make-release-items-qa.mjs" })
check("installer emission succeeds", installer.ok)
check("whole Edit installer compiles", loadstring(installer.stdout) ~= nil)
local embedded = 0
for source in installer.stdout:gmatch("%[====%[(.-)%]====%]") do
	embedded += 1
	check("embedded actual module/script " .. embedded .. " compiles", loadstring(source) ~= nil)
end
check("all four temporary instances embedded", embedded == 4)
local cleanup = process.exec("node", { "scripts/make-release-items-qa.mjs", "--cleanup" })
check("exact-name cleanup compiles", cleanup.ok and loadstring(cleanup.stdout) ~= nil)
check(
	"listener connected before published folder",
	server:find("ready.OnServerEvent:Connect(acceptReady)", 1, true)
		< server:find("folder.Parent = game.ReplicatedStorage", 1, true)
)
check(
	"OnClientInvoke installed before ready announcement",
	client:find("rpc.OnClientInvoke =", 1, true)
		< client:find("local function announceReady()", 1, true)
)
check(
	"live readiness waits for actual loading gate",
	client:find('player:GetAttribute("LoadingBlocked") == false', 1, true) ~= nil
)

local clock = 0
local actor = { UserId = -1 }
local serverEnv =
	{ clients = {}, report = { startup = { readyMessages = 0 } }, session = "current" }
local clientEnv = { session = "current", startedAt = 0, startupSeconds = 4, virtual = {} }
local attempts, ackCount, failures, connectAfter = 0, 0, {}, 1.5
serverEnv.ready = {
	FireClient = function(_, who, message)
		check(
			"ACK targets exact simulated client/session",
			who == actor and message.session == "current" and message.ack
		)
		ackCount += 1
		if ackCount > 1 then -- lose the first ACK after the delayed listener is finally present
			clientEnv.acked = true
		end
	end,
}
local accept = load(
	between(server, "-- QA_READY_SERVER_BEGIN", "-- QA_READY_SERVER_END") .. "\nreturn acceptReady",
	serverEnv
)
clientEnv.ready = {
	FireServer = function(_, message)
		attempts += 1
		if clock >= connectAfter then
			accept(actor, message)
		end
	end,
}
clientEnv.os = {
	clock = function()
		return clock
	end,
}
clientEnv.task = {
	wait = function(seconds)
		clock += seconds
	end,
}
clientEnv.progress = function(phase, err)
	table.insert(failures, { phase = phase, error = err })
end
local announce = load(
	between(client, "-- QA_READY_CLIENT_BEGIN", "-- QA_READY_CLIENT_END")
		.. "\nreturn announceReady",
	clientEnv
)
accept(actor, { session = "old", phase = "ready" })
accept({ UserId = 123 }, { session = "current", phase = "ready" })
accept(actor, "malformed")
check(
	"server refuses stale-session, real-account and malformed ready",
	serverEnv.report.startup.readyMessages == 0
)
accept(actor, { session = "current", phase = "waiting_ClientDebug" })
check(
	"progress recorded without promoting client to ready",
	serverEnv.report.startup.lastClient.phase == "waiting_ClientDebug"
		and serverEnv.clients[actor] == nil
)
check("actual retry loop survives late listener and lost ACK", announce())
check(
	"retry reaches ACK and stops promptly",
	attempts == 5 and ackCount == 2 and clock == 2 and #failures == 0
)
check(
	"server retains actionable ready input evidence",
	serverEnv.clients[actor].virtualInput == true and serverEnv.clients[actor].attempt == 5
)
clientEnv.acked, clock, attempts, connectAfter = nil, 0, 0, math.huge
clientEnv.startupSeconds = 1.25
check("actual retry loop terminates on missing server", announce() == false)
check(
	"Ready timeout includes explicit attempts and failure phase",
	attempts == 3
		and clock == 1.5
		and failures[1].phase == "failed"
		and failures[1].error:find("no Ready ACK after 3 attempts", 1, true) ~= nil
)

local timers, finished = {}, 0
local timeoutEnv = {
	startedAt = 0,
	report = { startup = { phase = "requiring_ProfileService" } },
	os = {
		clock = function()
			return 60
		end,
	},
	task = {
		delay = function(seconds, callback)
			timers[seconds] = callback
		end,
	},
	finish = function()
		finished += 1
	end,
}
load(between(server, "task.delay(60, function()", "local ok, err = xpcall"), timeoutEnv)
timers[60]()
check(
	"server startup watchdog covers yielding module bootstrap",
	finished == 1
		and timeoutEnv.report.error == "startup_timeout"
		and timeoutEnv.report.startup.elapsed == 60
		and timeoutEnv.report.startup.phase == "requiring_ProfileService"
)
timeoutEnv.report = { startup = { phase = "complete" } }
timers[60]()
check("startup watchdog leaves completed handshake alone", finished == 1)
timers[240]()
check(
	"overall watchdog remains bounded at 240 seconds",
	finished == 2 and timeoutEnv.report.error == "deadline"
)

local base = fs.readFile("scripts/qa-economy-audit-offline.luau")
base = base:sub(1, assert(base:find("local p = fresh()", 1, true)) - 1)
local Config = assert(loadstring(base .. "\nreturn modules.Config"))()
local plan =
	load(between(server, "-- QA_SILK_PLAN_BEGIN", "-- QA_SILK_PLAN_END") .. "\nreturn silkPlan")
check("live matrix contains six normal/Silk pairs", #plan == 6)
local expected = {}
for _, spec in plan do
	local location = Config.location(if spec.mine == "prison_small" then "prison" else spec.mine)
	local override = location.mines and location.mines[spec.mine]
	local shares = if override then override.shares else location.mine.shares
	check(spec.id .. " exists in actual mine composition", (shares[spec.block] or 0) > 0)
	check(
		spec.id .. " normal non-shot/non-PvP accessible fixture",
		not location.pvp and not location.shot and location.unlockLevel <= 10
	)
	local block = Config.block(spec.block)
	expected[spec.id] = Config.breakTime(block, spec.tool, spec.level)
	check(spec.id .. " real tier/time valid", expected[spec.id] ~= nil and expected[spec.id] >= 0)
end
check(
	"wrong-tier iron is actually slower in current config",
	expected.iron_wrong_tier > expected.iron_correct_tier
)
check(
	"stone compares finite and instant speed",
	expected.stone_stone_tier > expected.stone_max_tier
)
check(
	"actual melon produces 3-7 slices versus whole Silk block",
	Config.block("melon").dropsAs == "melon_slice"
		and Config.block("melon").dropCount[1] == 3
		and Config.block("melon").dropCount[2] == 7
)
check(
	"actual stone/coal have meaningful Silk identity contrast",
	Config.block("stone").dropsAs == "cobblestone" and Config.block("coal_ore").dropsAs == "coal"
)

local mine =
	{ id = "quarry", size = { 40, 16, 40 }, origin = rb.Vector3.zero, parts = {}, cells = {} }
local coordinates =
	{ { 1, 1, 1 }, { 2, 2, 2 }, { 3, 1, 2 }, { 4, 1, 2 }, { 5, 1, 2 }, { 6, 1, 2 }, { 7, 1, 2 } }
local covered = { Name = "gantry" }
local positionMap = {}
local rayEvidence = {}
local groundHeight = 2
local function positionKey(v)
	return string.format("%d,%d,%d", v.X, v.Y, v.Z)
end
for i, xyz in coordinates do
	mine.parts[i] = {
		Parent = true,
		CanCollide = true,
		Position = rb.Vector3.new((xyz[1] - 1) * 4, -(xyz[2] - 1) * 4, (xyz[3] - 1) * 4),
		Size = rb.Vector3.new(4, 4, 4),
		GetFullName = function()
			return "Mine_quarry.Cell" .. i
		end,
	}
	positionMap[positionKey(mine.parts[i].Position)] = mine.parts[i]
	mine.cells[i] = if i == 3 or i == 7 then "coal_ore" else "stone"
end
local selectCell = load(
	between(server, "local function exposedCell", "\n\tfor _, spec in silkPlan")
		.. "\nreturn exposedCell",
	{
		Mine = {
			coords = function(_, i)
				return table.unpack(coordinates[i])
			end,
			index = function(_, x, y, z)
				for i, p in coordinates do
					if p[1] == x and p[2] == y and p[3] == z then
						return i
					end
				end
				return -1
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = rb.Enum,
		Vector3 = rb.Vector3,
		CFrame = rb.CFrame,
		character = {},
		workspace = {
			Raycast = function(_, at, delta)
				if delta == rb.Vector3.new(0, -12, 0) then
					local support = positionMap[positionKey(at - rb.Vector3.new(0, 6, 0))]
					return if support
						then {
							Instance = support,
							Position = rb.Vector3.new(at.X, groundHeight, at.Z),
						}
						else nil
				end
				-- An open-end ray must cross the top plane, not merely end exactly on it.
				if delta.Y >= 0 then
					return nil
				end
				local fraction = (2 - at.Y) / delta.Y
				if fraction < 0 or fraction >= 1 - 1e-6 then
					return nil
				end
				local surface = at + delta * fraction
				local target = positionMap[positionKey(surface - rb.Vector3.new(0, 2, 0))]
				table.insert(rayEvidence, { overrun = delta.Magnitude - (surface - at).Magnitude })
				return { Instance = if target == mine.parts[4] then covered else target }
			end,
		},
	}
)
local part, index, standing = selectCell(mine, "stone")
check(
	"actual selector rejects edge buried wrong-material and roof-obstructed cells",
	part == mine.parts[5] and index == 5
)
check(
	"actual selector stands on a different real solid top cell",
	standing.Position == mine.parts[6].Position + rb.Vector3.new(0, 6, 0)
		and standing.Position.X ~= part.Position.X
)
check(
	"selector ray crosses open endpoint by exactly0point1stud",
	#rayEvidence > 0 and math.abs(rayEvidence[#rayEvidence].overrun - 0.1) < 1e-5
)
groundHeight = 20
check(
	"extended selector still rejects an original face beyond18studs",
	not pcall(selectCell, mine, "stone")
)
groundHeight = 2
-- Execute the actual per-trial diagnostics closure with the same open-end engine boundary.
local diagnosticTarget = part
local targetHit = part.Position + rb.Vector3.new(0, 2, 0)
local eyePosition = targetHit + rb.Vector3.new(4, 5, 0)
local obstruction = false
local diagnosticRays = 0
local lastDirection
local h = {
	Health = 20,
	FloorMaterial = rb.Enum.Material.Plastic,
	GetState = function()
		return rb.Enum.HumanoidStateType.Running
	end,
}
local c = {}
function c:FindFirstChild(name)
	return if name == "Head"
		then { Position = eyePosition }
		else {
			Position = eyePosition - rb.Vector3.new(0, 1.5, 0),
			AssemblyLinearVelocity = rb.Vector3.zero,
		}
end
function c:FindFirstChildOfClass()
	return h
end
local wall = {
	GetFullName = function()
		return "Quarry.RealWall"
	end,
}
local diagnostic = load(
	between(server, "local function diagnostics()", "\n\t\t\tlocal beforePose = diagnostics()")
		.. "\nreturn diagnostics",
	{
		player = { Character = c },
		character = c,
		part = diagnosticTarget,
		targetHit = targetHit,
		spec = { tool = "pickaxe", level = 5, block = "stone" },
		silk = false,
		block = Config.block("stone"),
		generation = 1,
		mine = { generation = 1, rebuilding = false, location = { unlockLevel = 1 } },
		P = {
			Get = function()
				return { level = 1, location = "quarry", needs = { sleep = 100 } }
			end,
		},
		Inventory = {
			heldTool = function()
				return "pickaxe", 5
			end,
			canAutoSell = function()
				return false
			end,
			canAdd = function()
				return true
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = rb.Enum,
		Vector3 = rb.Vector3,
		workspace = {
			GetServerTimeNow = function()
				return 100
			end,
			Raycast = function(_, at, direction)
				diagnosticRays += 1
				lastDirection = direction
				local fraction = (targetHit.Y - at.Y) / direction.Y
				return if fraction >= 0 and fraction < 1 - 1e-6
					then { Instance = if obstruction then wall else diagnosticTarget }
					else nil
			end,
		},
	}
)
local observed = diagnostic()
check(
	"actual diagnostics recognizes surface target after open-end extension",
	observed.rayTarget
		and #observed.inferredRefusalCandidates == 0
		and observed.distance == (targetHit - eyePosition).Magnitude
)
check(
	"diagnostic ray extends only0point1 and preserves measured face distance",
	math.abs(lastDirection.Magnitude - observed.distance - 0.1) < 1e-5
)
obstruction = true
observed = diagnostic()
check(
	"extended diagnostics still reports a real intervening obstruction",
	not observed.rayTarget
		and table.find(observed.inferredRefusalCandidates, "line_of_sight_blocked") ~= nil
)
eyePosition = targetHit
local beforeRays = diagnosticRays
observed = diagnostic()
check(
	"zero-length diagnostic direction avoids invalid Unit and raycast",
	diagnosticRays == beforeRays and not observed.rayTarget and observed.distance == 0
)
mine.parts[5].Parent = nil
part, index = selectCell(mine, "stone")
check("actual selector skips a previously removed cell", part == mine.parts[6] and index == 6)
mine.parts[6].Parent = nil
local selected, reason = pcall(selectCell, mine, "stone")
check(
	"missing real material fails without fabricated support or cell",
	not selected and tostring(reason):find("fixture_unavailable", 1, true) ~= nil
)
check(
	"VirtualInput prefers confirmed GUI inset conversion",
	server:find('coordinateMode or "inset"', 1, true) ~= nil
		and client:find("logicalPoint.X, logicalPoint.Y", 1, true) ~= nil
) -- Exercise the real client RPC branch: distant streaming, a 7.5 s wrong-tier dig, rejection,
-- and absent streamed material. Signal mocks model only delivery/time; all wait logic is actual source.
local digClock, digAt, cancelAt, didAccept, didReject, mode = 0, nil, nil, false, false, "success"
local clientPart = { Parent = true, Position = rb.Vector3.zero, Size = rb.Vector3.new(4, 4, 4) }
function clientPart:GetAttribute(key)
	return if key == "Index" then 17 else nil
end
local events, callbacks, digIntents = {}, {}, 0
for _, name in { "DigStart", "DigAccepted", "DigRejected", "DigCancel", "Toast" } do
	events[name] = {
		OnClientEvent = {
			Connect = function(_, callback)
				callbacks[name] = callback
				return {
					Disconnect = function()
						callbacks[name] = nil
					end,
				}
			end,
		},
		FireServer = function(_, target, hit)
			if name == "DigStart" then
				check(
					"client sends the actually streamed cell/top hit",
					target == clientPart and hit == rb.Vector3.new(0, 2, 0)
				)
				digAt, digIntents = digClock, digIntents + 1
			elseif name == "DigCancel" then
				cancelAt = digClock
			end
		end,
	}
end
local clientRpc = {}
local digEnv = {
	rpc = clientRpc,
	Vector3 = rb.Vector3,
	state = function()
		return { floor = "Air", health = 10 }
	end,
	os = {
		clock = function()
			return digClock
		end,
	},
	R = {
		event = function(name)
			return events[name]
		end,
	},
	workspace = {
		FindFirstChild = function(_, name)
			if name == "Mine_quarry" and digClock >= 0.5 and mode ~= "missing" then
				return {
					GetChildren = function()
						return { clientPart }
					end,
				}
			end
			return nil
		end,
	},
	Run = {
		Heartbeat = {
			Wait = function()
				digClock += 0.05
				if digAt and digClock - digAt >= 0.1 and not didAccept then
					didAccept = true
					callbacks.DigAccepted(clientPart, 7.5)
				end
				if digAt and mode == "reject" and digClock - digAt >= 0.2 and not didReject then
					didReject = true
					callbacks.DigRejected(clientPart)
				end
				if digAt and digClock - digAt >= 7.5 then
					clientPart.Parent = nil
				end
			end,
		},
	},
}
load(
	between(client, "local function waitFor", "local function jumpTrial")
		.. between(client, "rpc.OnClientInvoke = function", "-- QA_READY_CLIENT_BEGIN"),
	digEnv
)
local result =
	clientRpc.OnClientInvoke("dig", { mine = "quarry", index = 17, expectedSeconds = 7.5 })
check(
	"actual client waits for slow server completion instead of only acceptance",
	result.accepted
		and result.seconds == 7.5
		and result.elapsed >= 7.5
		and result.clientRemoved
		and not result.rejected
		and digIntents == 1
)
check("client does not cancel a slow in-progress dig", cancelAt - digAt >= 7.5)
check(
	"dig event listeners disconnected after completion",
	callbacks.DigAccepted == nil and callbacks.DigRejected == nil
)
digClock, digAt, cancelAt, didAccept, didReject, mode = 0, nil, nil, false, false, "reject"
clientPart.Parent = true
result = clientRpc.OnClientInvoke("dig", { mine = "quarry", index = 17, expectedSeconds = 7.5 })
check(
	"real DigRejected terminates client wait and is reported",
	result.rejected and not result.clientRemoved and result.elapsed < 1
)
digClock, digAt, cancelAt, mode = 0, nil, nil, "missing"
local oldIntents = digIntents
result = clientRpc.OnClientInvoke("dig", { mine = "quarry", index = 17, expectedSeconds = 7.5 })
check(
	"unstreamed target gives explicit timeout without sending a nil Instance",
	result.error == "target_stream_timeout"
		and not result.accepted
		and digClock >= 5
		and digIntents == oldIntents
)
print(
	serde.encode(
		"json",
		{ status = "PASS", count = #checks, checks = checks, expectedSeconds = expected }
	)
)
