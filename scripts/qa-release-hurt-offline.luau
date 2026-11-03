--!nocheck
-- Actual HurtService, HurtFeedback, Knockback and Sfx.broadcast; isolated engine/event mocks.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local base = getfenv()
local checks = 0
local function check(label, ok)
	checks += 1
	assert(ok, label)
end
local function near(a, b)
	return math.abs(a - b) < 1e-5
end
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn)
		table.insert(self.callbacks, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.callbacks do
			fn(...)
		end
	end
	return s
end
local function fixture(deferred)
	local f = {
		now = 100,
		events = {},
		delays = {},
		remotes = {},
		sent = {},
		sounds = {},
		flashes = 0,
		impacts = 0,
		tags = {},
	}
	local function node(class, name)
		local p = { ClassName = class, Name = name or class, children = {}, attrs = {} }
		local n = {}
		local methods = {
			IsA = function(_, want)
				return want == class or (want == "BasePart" and class == "Part")
			end,
			GetAttribute = function(_, k)
				return p.attrs[k]
			end,
			SetAttribute = function(_, k, v)
				p.attrs[k] = v
			end,
			FindFirstChild = function(_, k)
				for _, c in p.children do
					if c.Name == k and c.Parent == n then
						return c
					end
				end
				return nil
			end,
			FindFirstChildOfClass = function(_, k)
				for _, c in p.children do
					if c.ClassName == k and c.Parent == n then
						return c
					end
				end
				return nil
			end,
			Destroy = function()
				n.Parent = nil
			end,
		}
		if class == "Humanoid" then
			p.Health, p.MaxHealth, p.FloorMaterial = 20, 20, rb.Enum.Material.Concrete
			p.HealthChanged, p.AncestryChanged = signal(), signal()
			methods.TakeDamage = function(_, amount)
				if not n.Parent:FindFirstChildOfClass("ForceField") then
					n.Health -= amount
				end
			end
		elseif class == "BindableEvent" then
			p.Event = signal()
			methods.Fire = function(_, ...)
				p.Event:Fire(...)
			end
		elseif class == "Highlight" then
			f.flashes += 1
		end
		setmetatable(n, {
			__index = function(_, k)
				return methods[k] or p[k]
			end,
			__newindex = function(_, k, v)
				if k == "Health" and class == "Humanoid" then
					v = math.clamp(v, 0, p.MaxHealth)
					local old = p.Health
					p.Health = v
					if old ~= v then
						if deferred then
							table.insert(f.events, function()
								p.HealthChanged:Fire(v)
							end)
						else
							p.HealthChanged:Fire(v)
						end
					end
				else
					p[k] = v
				end
				if k == "Parent" and v then
					table.insert(v.children, n)
				end
			end,
		})
		return n
	end
	f.node = node
	local function character(x)
		local m = node("Model")
		local root = node("Part", "HumanoidRootPart")
		root.Position, root.AssemblyLinearVelocity = rb.Vector3.new(x, 0, 0), rb.Vector3.zero
		root.Parent = m
		local h = node("Humanoid")
		h.Parent = m
		m.PrimaryPart = root
		return m, root, h
	end
	f.model, f.root, f.h = character(0)
	f.player = { Character = f.model, CharacterAdded = signal() }
	f.observer = { Character = character(5), CharacterAdded = signal() }
	f.far = { Character = character(100), CharacterAdded = signal() }
	local players = {
		LocalPlayer = f.player,
		PlayerAdded = signal(),
		GetPlayers = function()
			return { f.player, f.observer, f.far }
		end,
		GetPlayerFromCharacter = function(_, m)
			return if m == f.model
				then f.player
				elseif m == f.observer.Character then f.observer
				else nil
		end,
	}
	local names = setmetatable({
		WaitForChild = function(_, k)
			return k
		end,
	}, {
		__index = function(_, k)
			return k
		end,
	})
	local modules = { Config = { mobs = { mobs = {} } } }
	modules.Remotes = {
		event = function(name)
			if not f.remotes[name] then
				f.remotes[name] = {
					OnClientEvent = signal(),
					FireClient = function(_, player, ...)
						local packet = { ... }
						table.insert(f.sent, { name = name, player = player, args = packet })
						if player == f.player then
							f.remotes[name].OnClientEvent:Fire(...)
						end
					end,
				}
			end
			return f.remotes[name]
		end,
	}
	local services = {
		Players = players,
		CollectionService = {
			HasTag = function(_, m, tag)
				return f.tags[m] and f.tags[m][tag] == true
			end,
			GetTagged = function(tag)
				local out = {}
				for m, tags in f.tags do
					if tags[tag] then
						table.insert(out, m)
					end
				end
				return out
			end,
			GetInstanceAddedSignal = function()
				return signal()
			end,
		},
		ReplicatedStorage = {
			Shared = names,
			WaitForChild = function()
				return names
			end,
		},
		RunService = {
			RenderStepped = signal(),
			IsServer = function()
				return true
			end,
		},
		SoundService = {},
	}
	local globals = {
		game = {
			GetService = function(_, k)
				return assert(services[k], k)
			end,
		},
		script = { Parent = names },
		require = function(k)
			return assert(modules[k], k)
		end,
		Instance = { new = node },
		Enum = rb.Enum,
		Vector3 = rb.Vector3,
		Vector2 = rb.Vector2,
		Color3 = rb.Color3,
		UDim2 = rb.UDim2,
		Random = {
			new = function()
				return {}
			end,
		},
		workspace = {},
		task = {
			delay = function(t, fn)
				table.insert(f.delays, { at = f.now + t, fn = fn })
			end,
		},
		os = {
			clock = function()
				return f.now
			end,
		},
	}
	local function load(path, extra)
		local fn = assert(loadstring(fs.readFile(path), "@" .. path))
		local g = table.clone(globals)
		for k, v in extra or {} do
			g[k] = v
		end
		setfenv(fn, setmetatable(g, { __index = base }))
		return fn()
	end
	modules.Knockback = load("src/shared/Knockback.luau")
	f.knockback = modules.Knockback
	modules.Sfx = load("src/shared/Sfx.luau")
	f.hurt = load("src/server/Services/HurtService.luau")
	local clientMods = table.clone(modules)
	clientMods.Sfx = {
		play = function(...)
			table.insert(f.sounds, { ... })
		end,
	}
	f.feedback = load("src/client/HurtFeedback.luau", {
		require = function(k)
			return clientMods[k]
		end,
	})
	f.feedback.Impact:Connect(function()
		f.impacts += 1
	end)
	f.feedback.Start(node("ScreenGui"))
	f.hurt.Start()
	function f:flush()
		while #self.events > 0 do
			table.remove(self.events, 1)()
		end
	end
	function f:packets(name, player)
		local out = {}
		for _, p in self.sent do
			if p.name == name and (not player or p.player == player) then
				table.insert(out, p)
			end
		end
		return out
	end
	return f
end

for _, deferred in { false, true } do
	local f = fixture(deferred)
	local push = f.hurt.Impulse(f.model, rb.Vector3.new(1, 0, 0))
	local dealt = f.hurt.Damage(f.h, 3, { push = push, from = rb.Vector3.new(-3, 0, 0) })
	f:flush()
	check(
		"one impact/audio for own health decrease " .. tostring(deferred),
		dealt == 3
			and f.h.Health == 17
			and #f:packets("HurtImpact") == 1
			and #f.sounds == 1
			and f.impacts == 1
	)
	check(
		"one positional sound excludes victim and distant observer " .. tostring(deferred),
		#f:packets("Sfx") == 1 and #f:packets("Sfx", f.observer) == 1
	)
	check(
		"one primary impulse and no redundant Knockback remote " .. tostring(deferred),
		f.root.AssemblyLinearVelocity == rb.Vector3.new(26, 14, 0) and #f:packets("Knockback") == 0
	)
	local packet = f:packets("HurtImpact")[1].args[1]
	check(
		"packet includes authoritative final health and source " .. tostring(deferred),
		packet.health == 17
			and packet.maxHealth == 20
			and packet.damage == 3
			and packet.from.X == -3
	)
	f.remotes.HurtImpact.OnClientEvent:Fire(packet)
	check(
		"client duplicate id has no second sound/impulse " .. tostring(deferred),
		#f.sounds == 1 and f.impacts == 1 and f.root.AssemblyLinearVelocity.X == 26
	)
	f.h.Health = 15
	f:flush()
	check(
		"external health drop emits exactly once " .. tostring(deferred),
		#f:packets("HurtImpact") == 2 and #f.sounds == 2
	)
	f.h.Health = 18
	f:flush()
	check(
		"external healing never emits hurt " .. tostring(deferred),
		#f:packets("HurtImpact") == 2 and #f.sounds == 2
	)
	f.hurt.Damage(f.h, 2)
	f.hurt.Damage(f.h, 1)
	f:flush()
	check(
		"rapid owned drops each emit once " .. tostring(deferred),
		#f:packets("HurtImpact") == 4 and #f.sounds == 4
	)
end

local f = fixture(true)
f.model:SetAttribute("AbsorptionHealth", 5)
check("full absorption returns accepted damage", f.hurt.Damage(f.h, 3) == 3)
f:flush()
local packet = f:packets("HurtImpact")[1].args[1]
check(
	"full absorption emits one hit without HP loss",
	f.h.Health == 20
		and f.model:GetAttribute("AbsorptionHealth") == 2
		and packet.absorbed == 3
		and packet.golden == 2
		and #f.sounds == 1
)
check("partial absorption returns full accepted damage", f.hurt.Damage(f.h, 5) == 5)
f:flush()
packet = f:packets("HurtImpact")[2].args[1]
check(
	"partial absorption clears gold and emits once",
	f.h.Health == 17
		and f.model:GetAttribute("AbsorptionHealth") == nil
		and packet.absorbed == 2
		and packet.damage == 5
		and #f.sounds == 2
)
f = fixture(false)
local shield = f.node("ForceField")
shield.Parent = f.model
f.model:SetAttribute("AbsorptionHealth", 4)
check(
	"ForceField consumes neither HP nor absorption",
	f.hurt.Damage(f.h, 8) == 0
		and f.h.Health == 20
		and f.model:GetAttribute("AbsorptionHealth") == 4
)
check("protected hit has no impact/sound/flash", #f.sent == 0 and #f.sounds == 0 and f.flashes == 0)
f.tags[f.model] = { Boss = true }
check(
	"boss cannot block with ForceField or absorption",
	f.hurt.Damage(f.h, 6) == 6
		and f.h.Health == 14
		and f.model:GetAttribute("AbsorptionHealth") == 4
)
check("boss has heavy hurt sound", f:packets("HurtImpact")[1].args[1].sound == "hit_heavy")
check("boss impulse is disabled", f.hurt.Impulse(f.model, rb.Vector3.xAxis) == nil)

f = fixture(false)
for _, amount in { 0, -1, math.huge, -math.huge, 0 / 0 } do
	check("invalid damage ignored " .. tostring(amount), f.hurt.Damage(f.h, amount) == 0)
end
check("invalid damage emits no packet", #f.sent == 0 and f.h.Health == 20)
check("lethal damage clamps at existing HP", f.hurt.Damage(f.h, 500) == 20 and f.h.Health == 0)
check(
	"dead target ignores subsequent damage",
	f.hurt.Damage(f.h, 1) == 0 and #f:packets("HurtImpact") == 1
)

f = fixture(false)
f.h.FloorMaterial = rb.Enum.Material.Air
f.root.AssemblyLinearVelocity = rb.Vector3.new(10, -24, 6)
f.hurt.Damage(f.h, 1, { push = rb.Vector3.new(26, 14, 0) })
check(
	"airborne falling hit preserves Y and half horizontal momentum",
	f.root.AssemblyLinearVelocity == rb.Vector3.new(31, -24, 3)
)
f.root.AssemblyLinearVelocity = rb.Vector3.new(0, 30, 0)
f.hurt.Knockback(f.model, rb.Vector3.zAxis, 2, 2)
check(
	"separate book impulse preserves rising arc",
	f.root.AssemblyLinearVelocity == rb.Vector3.new(0, 30, 52)
)
check("separate impulse never repeats hurt sound or impact", #f.sounds == 1 and f.impacts == 1)
local before = f.root.AssemblyLinearVelocity
f.remotes.Knockback.OnClientEvent:Fire(rb.Vector3.new(0 / 0, 1, 1))
check("client rejects nonfinite impulse", f.root.AssemblyLinearVelocity == before)
f.tags[f.model] = { Mob = true }
local impulse = f.hurt.Impulse(f.model, rb.Vector3.xAxis)
check("mob impulse is scaled", near(impulse.X, 15.6) and near(impulse.Y, 8.4))
check("zero horizontal direction has no impulse", f.hurt.Impulse(f.model, rb.Vector3.yAxis) == nil)
local stale = table.clone(f:packets("HurtImpact")[1].args[1])
stale.id += 100
stale.character = f.observer.Character
f.remotes.HurtImpact.OnClientEvent:Fire(stale)
check("client ignores stale other-character packet", #f.sounds == 1 and f.impacts == 1)
print(
	string.format(
		"Release hurt PASS: %d actual-source checks; synchronous/deferred signals, no Studio/audio",
		checks
	)
)
