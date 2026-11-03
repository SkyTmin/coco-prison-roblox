--!nocheck
-- Actual early-loader/state/ProfileService code. No Studio, network or real profiles.
local fs, serde, Roblox = require("@lune/fs"), require("@lune/serde"), require("@lune/roblox")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function source(path, env, instrument)
	local text = fs.readFile(path)
	if instrument then
		text = instrument(text)
	end
	local fn = assert(loadstring(text, "@" .. path))
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end
local State = source("src/first/LoadingState.luau")
local Strings = source("src/first/LoadingStrings.luau")
local serverSource = fs.readFile("src/server/Services/ProfileService.luau")
local bootstrapStart = assert(serverSource:find("-- Initial replication can precede", 1, true))
local bootstrapEnd = assert(serverSource:find("sentCopies[player] = nil", bootstrapStart, true))
local bootstrapBody = assert(
	loadstring(
		"local player,restoring,ProfileService,restorePosition,task = ...\n"
			.. serverSource:sub(bootstrapStart, bootstrapEnd - 1)
	)
)
local function fixture()
	local f =
		{ now = 0, tasks = {}, stream = 0, preloads = 0, released = 0, floor = true, requests = {} }
	local player = { attributes = { LoadingBlocked = true, ProfileState = "ready" } }
	f.probes = {}
	function player:FindFirstChildOfClass()
		return {
			FindFirstChild = function()
				return f.hud
			end,
		}
	end
	function player:GetAttribute(key)
		return self.attributes[key]
	end
	function player:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function player:RequestStreamAroundAsync(position)
		f.stream += 1
		f.streamPosition = position
		if f.streamingHook then
			f.streamingHook()
		end
	end
	local root = {
		Position = Roblox.Vector3.new(1000, 200, 0),
		IsA = function(_, name)
			return name == "BasePart"
		end,
	}
	local humanoid = { Health = 20 }
	local character = { attributes = { SpawnReady = true, ArrivalPosition = root.Position } }
	function character:GetAttribute(key)
		return self.attributes[key]
	end
	function character:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function character:FindFirstChild()
		return root
	end
	function character:FindFirstChildOfClass()
		return humanoid
	end
	player.Character = character
	local remote = {
		IsA = function()
			return true
		end,
		FireServer = function(_, retry)
			table.insert(f.requests, retry)
			if f.bootstrapHook then
				f.bootstrapHook()
			end
		end,
	}
	local services = {
		Players = { LocalPlayer = player },
		UserInputService = {
			GetFocusedTextBox = function()
				return nil
			end,
		},
		RunService = {
			UnbindFromRenderStep = function()
				f.released += 1
			end,
		},
		ContextActionService = {
			UnbindAction = function()
				f.released += 1
			end,
		},
		ReplicatedFirst = {},
		GuiService = {},
		ReplicatedStorage = {
			FindFirstChild = function(_, name)
				if name == "Shared" and f.config then
					return {
						FindFirstChild = function()
							return "Config"
						end,
					}
				end
				if name == "Remotes" then
					return {
						FindFirstChild = function()
							return remote
						end,
					}
				end
				return nil
			end,
		},
		ContentProvider = {
			PreloadAsync = function(_, assets, callback)
				f.preloads += 1
				f.assets = assets
				if f.assertTyped then
					for _, asset in assets do
						assert(
							type(asset) == "table" and asset.IsA,
							"raw asset string uses wrong preload path"
						)
					end
				end
				if f.assetHook then
					f.assetHook()
				end
				callback("fixture", if f.assetFailure then "Failure" else "Success")
			end,
		},
	}
	local env = {
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		script = {
			Parent = { LoadingState = "State", LoadingStrings = "Strings", HudLayout = "HudLayout" },
		},
		require = function(name)
			return if name == "State"
				then State
				elseif name == "Strings" then Strings
				elseif name == "Config" then f.config
				else {
					isEditing = function()
						return false
					end,
				}
		end,
		os = {
			clock = function()
				return f.now
			end,
		},
		task = {
			spawn = function(fn)
				table.insert(f.tasks, fn)
			end,
		},
		Enum = {
			RaycastFilterType = { Exclude = "Exclude" },
			AssetFetchStatus = { Success = "Success" },
		},
		Vector3 = Roblox.Vector3,
		Instance = {
			new = function(class)
				local object = {
					ClassName = class,
					IsA = function(_, kind)
						return kind == class
					end,
				}
				function object:Destroy()
					self.destroyed = true
				end
				table.insert(f.probes, object)
				return object
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		workspace = {
			GetAttribute = function(_, key)
				return key == "RuntimeReady" and f.runtimeReady ~= false
			end,
			StreamingEnabled = true,
			Raycast = function()
				return if f.floor then {} else nil
			end,
			GetPartBoundsInRadius = function()
				return f.nearby or {}
			end,
		},
	}
	f.loader = source("src/first/LoadingController.luau", env, function(s)
		return (
			s:gsub(
				"return Controller%s*$",
				"return { api=Controller, state=state, step=step, retry=retry }"
			)
		)
	end)
	f.input = source("src/client/WindowInput.luau", env)
	f.player, f.root, f.character, f.humanoid = player, root, character, humanoid
	function f:serverBootstrap(restoring)
		bootstrapBody(player, restoring or {}, {
			IsReal = function()
				return player.attributes.ProfileState == "ready"
			end,
		}, function()
			self.restoreCalled = true
		end, {
			spawn = function(fn)
				fn()
			end,
		})
	end
	function f:pump()
		local tasks = self.tasks
		self.tasks = {}
		for _, fn in tasks do
			fn()
		end
	end
	function f:ready()
		self.loader.api.Profile({ inventory = {}, locale = "en" })
		self.loader.api.SnapshotReady(true)
		self.loader.api.ClientReady()
	end
	return f
end
local f = fixture()
f.loader.step()
check(
	"initial loader does not unlock on replicated server state alone",
	f.player.attributes.LoadingBlocked and f.stream == 0
)
check(
	"loading blocks gameplay despite live character and closed menus",
	f.input.GameplayBlocked(false)
)
f:ready()
f.loader.api.SnapshotReady(false)
f.loader.step()
check(
	"failed/default snapshot cannot masquerade as loaded profile",
	f.stream == 0 and not f.loader.state.facts.profile
)
f.loader.api.SnapshotReady(true)
f.character.attributes.SpawnReady = false
f.loader.step()
check("profile plus interface still waits for server spawn restore", f.stream == 0)
f.character.attributes.SpawnReady = true
f.root.Position = Roblox.Vector3.zero
f.loader.step()
check("client waits for actual restored position replication", f.stream == 0)
f.root.Position = f.character.attributes.ArrivalPosition
f.floor = false
f.loader.step()
f:pump()
check(
	"stream request completion without local floor is not ready",
	f.stream == 1 and not f.loader.state.facts.location and f.preloads == 0
)
f.floor = true
f.loader.step()
f:pump()
f.loader.step()
check("only actual local stream position is requested", f.streamPosition == f.root.Position)
check(
	"actual facts release both input owners exactly once",
	f.player.attributes.LoadingBlocked == false and f.released == 2 and f.preloads == 1
)
check("gameplay unlocks after successful readiness", not f.input.GameplayBlocked(false))
check("menu retains gameplay ownership after loader", f.input.GameplayBlocked(true))

f = fixture()
f:ready()
f.assetFailure = true
f.loader.step()
f:pump()
f.loader.step()
check(
	"failed critical fetch stays blocked and reports retryable failure",
	f.player.attributes.LoadingBlocked and f.loader.state.failure == "asset_error"
)
f.assetFailure = false
f.loader.retry()
f.loader.step()
f:pump()
f.loader.step()
check("asset retry can recover without fake completion", not f.player.attributes.LoadingBlocked)
f = fixture()
f:ready()
f.loader.step()
f.streamingHook = function()
	f.streamingHook = nil
	f.loader.retry()
end
f:pump()
check(
	"late stream completion from old retry cannot set readiness",
	not f.loader.state.facts.location and not f.loader.state.facts.assets
)
f.loader.step()
f:pump()
f.loader.step()
check("new retry generation can finish after stale worker", not f.player.attributes.LoadingBlocked)
f = fixture()
f:ready()
f.loader.step()
f.assetHook = function()
	f.assetHook = nil
	f.loader.retry()
end
f:pump()
check(
	"late asset callback cannot unlock newer attempt",
	not f.loader.state.facts.assets and f.player.attributes.LoadingBlocked
)
f = fixture()
f.loader.step()
f.now = 31
f.loader.step()
check(
	"timeout offers error and never unlocks arbitrary 100 percent",
	f.loader.state.failure == "error" and f.player.attributes.LoadingBlocked
)
f = fixture()
f.player.attributes.ProfileState = "error"
f.loader.step()
check("failed profile has explicit error state", f.loader.state.failure == "profile_error")
f.now = 3
f.loader.retry()
f.loader.step()
check("profile retry requests server recovery", f.requests[#f.requests] == true)
f.player.attributes.ProfileState = "loading"
f.loader.step()
check(
	"retry loading clears stale failure while retaining block",
	f.loader.state.failure == nil and f.player.attributes.LoadingBlocked
)
f = fixture()
f:ready() -- sends the normal snapshot handshake
f.player.attributes.ProfileState = "error"
f.loader.step()
f.now = 0.1
f.loader.retry()
f.loader.step()
check(
	"manual retry queues behind recent snapshot throttle",
	#f.requests == 1 and f.requests[1] == false
)
f.now = 2.3
f.loader.step()
check(
	"queued retry cannot be swallowed by automatic resync",
	#f.requests == 2 and f.requests[2] == true
)
for _, moment in { "before_client_observed_arrival", "during_assets" } do
	f = fixture()
	f:ready()
	f.bootstrapHook = function()
		f:serverBootstrap()
	end
	local function rescue()
		f.root.Position += Roblox.Vector3.new(0, 64, 0)
	end
	if moment == "during_assets" then
		f.assetHook = rescue
	else
		rescue()
	end
	f.loader.step()
	f:pump()
	check(
		"server rescue never completes using old geometry " .. moment,
		f.player.attributes.LoadingBlocked and not f.loader.state.facts.assets
	)
	f.assetHook = nil
	f.now = 3
	f.loader.step()
	f.loader.step()
	f:pump()
	f.loader.step()
	check(
		"authoritative restamp recovers actual arrival " .. moment,
		not f.player.attributes.LoadingBlocked
			and f.character.attributes.ArrivalPosition == f.root.Position
	)
end
f = fixture()
f:ready()
f.assetHook = function()
	f.root.Position -= Roblox.Vector3.new(0, 20, 0)
	f.floor = false
end
f.loader.step()
f:pump()
f.loader.step()
check(
	"moving off streamed floor during assets cannot unlock",
	f.player.attributes.LoadingBlocked
		and not f.loader.state.facts.location
		and not f.loader.state.facts.assets
)
f = fixture()
f.root.Position += Roblox.Vector3.new(0, 64, 0)
local originalArrival = f.character.attributes.ArrivalPosition
f:serverBootstrap({ [f.player] = f.character })
check(
	"bootstrap cannot restamp while original restore is in flight",
	f.character.attributes.ArrivalPosition == originalArrival
)
f.character.attributes.SpawnReady = false
f:serverBootstrap()
check(
	"missing arrival proof requests restoration instead of certifying position",
	f.restoreCalled and f.character.attributes.ArrivalPosition == originalArrival
)
f = fixture()
f:ready()
f.runtimeReady = false
f.loader.step()
f:pump()
check(
	"interface cannot unlock before authoritative runtime handlers are ready",
	f.stream == 0 and not f.loader.state.facts.interface and f.player.attributes.LoadingBlocked
)
f.runtimeReady = true
f.loader.step()
f:pump()
f.loader.step()
check(
	"runtime readiness and actual arrival facts can release loading",
	not f.player.attributes.LoadingBlocked
)
f = fixture()
f:ready()
f.assertTyped = true
f.config = {
	iconFor = function(id)
		return "rbxassetid://" .. id
	end,
}
local hudImage = {
	Image = "rbxassetid://pickaxe",
	IsLoaded = true,
	IsA = function(_, kind)
		return kind == "ImageLabel"
	end,
}
f.hud = {
	GetDescendants = function()
		return { hudImage }
	end,
}
local decal = {
	Texture = "rbxassetid://wall",
	IsA = function(_, kind)
		return kind == "Decal"
	end,
}
local mesh = {
	MeshId = "rbxassetid://mesh",
	TextureID = "rbxassetid://meshTexture",
	IsA = function(_, kind)
		return kind == "MeshPart"
	end,
	GetChildren = function()
		return { decal }
	end,
}
f.nearby = { mesh }
f.loader.api.Profile({ inventory = { { id = "pickaxe" }, { id = "shovel" }, { id = "pickaxe" } } })
f.loader.step()
f:pump()
f.loader.step()
check("typed preload reuses real loaded HUD consumer", f.assets[1] == hudImage)
check(
	"absent HUD icon gets one typed ImageLabel probe and is deduplicated",
	#f.probes == 1 and f.probes[1].Image == "rbxassetid://shovel" and #f.assets == 4
)
check(
	"nearby mesh and decal keep specialized engine instance path",
	table.find(f.assets, mesh) ~= nil and table.find(f.assets, decal) ~= nil
)
check(
	"preload destroys owned probes without destroying HUD/world consumers",
	f.probes[1].destroyed and not hudImage.destroyed and not mesh.destroyed
)
check(
	"typed success releases normal asset gate",
	not f.player.attributes.LoadingBlocked
		and f.player.attributes.LoadingAssetCount == 4
		and f.player.attributes.LoadingAssetFailures == nil
)
f = fixture()
f:ready()
f.config = {
	iconFor = function()
		return "rbxassetid://missing"
	end,
}
f.assertTyped = true
f.assetFailure = true
f.loader.api.Profile({ inventory = { { id = "pickaxe" } } })
f.loader.step()
f:pump()
f.loader.step()
check(
	"typed failure still blocks and records useful diagnostics",
	f.player.attributes.LoadingBlocked
		and f.loader.state.failure == "asset_error"
		and f.player.attributes.LoadingAssetFailures:find("Failure") ~= nil
)
check("owned probes are cleaned even on failed fetch", f.probes[1].destroyed)
for key, entry in Strings do
	for _, locale in { "ru", "en", "es", "fr" } do
		check(
			key .. " localized " .. locale,
			type(entry[locale]) == "string" and #entry[locale] > 0
		)
	end
end

local factory = require("./qa-profile-persistence-offline").fixture
local p = factory()
local player = p:player()
player.UserId = -7301
local boundary = p:profile("loader-job")
p.afterUpdate = function()
	p.afterUpdate = nil
	error("acquire applied but response lost")
end
boundary.load(player)
local failed = boundary.sessions[player]
check(
	"uncertain acquire publishes error and never spendable default",
	failed.loadFailed
		and player.attributes.ProfileState == "error"
		and not boundary.service.IsReal(player)
)
check(
	"failed profile cannot save its default over stored data",
	not boundary.service.SaveNow(player)
)
local token = failed.token
boundary.load(player, token)
check(
	"profile retry retains exact acquisition token",
	boundary.sessions[player].token == token
		and p.disk.User_7301 == nil
		and p.disk["User_-7301"]._lock.token == token
)
check(
	"same-token retry restores loaded ready session without self-lock kick",
	boundary.service.IsReal(player)
		and player.attributes.ProfileState == "ready"
		and #player.kicks == 0
)
boundary.flush()
local latest = p.messages[#p.messages]
check(
	"fresh successful snapshot carries explicit loaded proof",
	latest.remote == "ProfileUpdated" and latest.args[2] == true
)
for _, path in
	{
		"src/first/Bootstrap.client.luau",
		"src/first/LoadingController.luau",
		"src/client/init.client.luau",
		"src/server/Services/ProfileService.luau",
	}
do
	check(path .. " compiles", loadstring(fs.readFile(path)) ~= nil)
end
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualModules = true,
	realProfiles = false,
	realDataStores = false,
}, true))
