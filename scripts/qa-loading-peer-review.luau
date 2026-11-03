--!nocheck
-- Reuses the existing isolated engine fixture; executes the current production loader.
-- Peer regressions: no Studio, network, owner profile or production edits.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Roblox = require("@lune/roblox")
local suite = fs.readFile("scripts/qa-loading-offline.luau")
local marker = assert(suite:find("\nlocal f = fixture()", 1, true), "loader fixture boundary")
local factory =
	assert(loadstring(suite:sub(1, marker - 1) .. "\nreturn fixture", "@loading-peer-fixture"))()
local results = {}
for _, moment in ipairs({ "before_arrival_observed", "during_asset_load" }) do
	local f = factory()
	f.bootstrapHook = function()
		f:serverBootstrap()
	end
	f:ready()
	local function reposition()
		f.root.Position += Roblox.Vector3.new(0, 64, 0)
	end
	if moment == "before_arrival_observed" then
		reposition()
	else
		f.assetHook = reposition
	end
	f.loader.step()
	f:pump()
	f.assetHook = nil
	f.loader.step()
	f.loader.retry()
	for _ = 1, 4 do
		f.now += 3
		f.loader.step()
		f:pump()
		f.loader.step()
	end
	assert(
		f.player.attributes.LoadingBlocked == false,
		"legitimate reposition must recover: " .. moment
	)
	table.insert(results, {
		case = moment,
		blocked = f.player.attributes.LoadingBlocked,
		characterReady = f.loader.state.facts.character,
		failure = f.loader.state.failure,
		requests = f.requests,
		streams = f.stream,
	})
end
do
	local f = factory()
	f:ready()
	f.assetHook = function()
		f.root.Position -= Roblox.Vector3.new(0, 20, 0)
		f.floor = false
	end
	f.loader.step()
	f:pump()
	f.loader.step()
	assert(
		f.player.attributes.LoadingBlocked == true and not f.loader.state.facts.location,
		"old streamed floor must not authorize completion after same-character displacement"
	)
	table.insert(results, {
		case = "same_character_moves_off_loaded_floor_during_assets",
		blocked = f.player.attributes.LoadingBlocked,
		localFloorExists = f.floor,
		locationReady = f.loader.state.facts.location,
		characterReady = f.loader.state.facts.character,
	})
end
do
	local profileSuite = fs.readFile("scripts/qa-profile-persistence-offline.luau")
	local profileMarker = assert(profileSuite:find("\n-- Exact acquisition ownership", 1, true))
	local profileFactory = assert(
		loadstring(
			profileSuite:sub(1, profileMarker - 1) .. "\nreturn fixture",
			"@reset-peer-fixture"
		)
	)()
	local source = fs.readFile("src/server/Services/ProfileService.luau")
	local first = assert(source:find("\tlocal function rememberPosition", 1, true))
	local last = assert(source:find("\tonLoaded = function", first, true))
	local body = source:sub(first, last - 1)
	local function characterAt(position)
		local root = {
			Position = position,
			IsA = function(_, kind)
				return kind == "BasePart"
			end,
		}
		local humanoid = { Health = 20 }
		return {
			attributes = {},
			FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end,
			WaitForChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end,
			FindFirstChildOfClass = function(_, kind)
				return if kind == "Humanoid" then humanoid else nil
			end,
			SetAttribute = function(self, key, value)
				self.attributes[key] = value
			end,
			GetAttribute = function(self, key)
				return self.attributes[key]
			end,
		}
	end
	for _, phase in ipairs({ "leave_before_replacement", "replacement_arrives" }) do
		local f = profileFactory()
		local actor = f:player()
		actor.UserId = -9001
		actor.Character = characterAt(Roblox.Vector3.new(4400, 4504, 0))
		local oldCharacter = actor.Character
		local boundary = f:profile("reset-position-peer")
		-- Attribute/cosmetic replication is outside this persistence/position regression.
		boundary.service.Replicate = function() end
		local session = f:session(boundary, actor, "reset-position-token")
		local positions = assert(
			loadstring(
				body .. "\nreturn { remember = rememberPosition, restore = restorePosition }",
				"@ProfileService.position-boundaries"
			)
		)
		setfenv(
			positions,
			setmetatable({
				sessions = boundary.sessions,
				restored = { [actor] = true },
				restoring = {},
				ProfileService = boundary.service,
				os = {
					time = function()
						return f.time
					end,
				},
			}, { __index = getfenv() })
		)
		local tracking = positions()
		tracking.remember(actor)
		assert(
			session.profile.lastPosition[1] == 4400,
			"positive control: ordinary old body was tracked"
		)
		assert(boundary.service.ResetOwnProgress(actor), "actual durable reset must succeed")
		assert(
			session.resetCharacter == oldCharacter,
			"confirmed reset binds the old body before unfreezing"
		)
		assert(
			session.profile.lastPosition == nil and session.profile.location == "prison",
			"confirmed reset clears the old arrival and resets the location"
		)
		tracking.remember(actor)
		assert(
			session.profile.lastPosition == nil,
			"old body cannot refill cleared position before deferred respawn"
		)
		if phase == "leave_before_replacement" then
			assert(boundary.save(actor, session, true), "actual leave checkpoint must succeed")
			local rejoin = f:profile("reset-position-rejoin")
			local rejoined = f:session(rejoin, actor, "new-token")
			assert(
				rejoined.profile.lastPosition == nil and rejoined.profile.location == "prison",
				"durable rejoin cannot return level-one reset player to the old advanced map"
			)
		else
			tracking.restore(actor, oldCharacter)
			assert(
				session.resetCharacter == oldCharacter
					and oldCharacter.attributes.SpawnReady ~= true,
				"late old-body arrival cannot clear the position guard or announce readiness"
			)
			table.insert(
				results,
				{ case = "old_arrival_cannot_release_reset_guard", passed = true }
			)
			actor.Character = characterAt(Roblox.Vector3.new(12, 8, 16))
			tracking.restore(actor, actor.Character)
			assert(
				session.resetCharacter == nil and actor.Character.attributes.SpawnReady == true,
				"replacement arrival clears only the old-body guard"
			)
			tracking.remember(actor)
			assert(
				session.profile.lastPosition[1] == 12 and session.profile.lastPosition[3] == 16,
				"normal replacement position tracking resumes"
			)
			assert(boundary.save(actor, session, false), "replacement checkpoint must succeed")
			assert(
				f.disk["User_-9001"].lastPosition[1] == 12,
				"only the replacement position reaches the real persistence boundary"
			)
		end
		table.insert(results, { case = "reset_position_" .. phase, passed = true })
	end
end
print(serde.encode("json", {
	actualLoader = true,
	actualProfile = true,
	regressions = #results,
	passed = true,
	scenarios = results,
}, true))
