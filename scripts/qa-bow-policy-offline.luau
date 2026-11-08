--!nocheck
-- Actual BowService stick/pickup with local geometry and fake players/policies. No Studio/services.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local checks = 0
local function check(name, value)
	assert(value, name)
	checks += 1
end
local names = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
local function fixture()
	local f = { at = 10, allowed = {}, online = {}, profiles = {}, noises = 0 }
	f.world = rb.Instance.new("Folder")
	f.wall = rb.Instance.new("Part")
	f.wall.Parent = f.world
	local function player(id, x)
		local character = rb.Instance.new("Model")
		local root = rb.Instance.new("Part")
		root.Name, root.Position, root.Parent =
			"HumanoidRootPart", rb.Vector3.new(x, 0, 0), character
		local p = { UserId = id, Character = character }
		f.online[id], f.allowed[p], f.profiles[p] = p, true, { arrows = 0 }
		return p
	end
	f.owner, f.recipient = player(11, 100), player(22, 0)
	f.list = { f.recipient, f.owner }
	local modules = {
		Config = {
			vanilla = serde.decode("json", fs.readFile("src/shared/Config/tools.json")).vanilla,
			rules = serde.decode("json", fs.readFile("src/shared/Config/rules.json")),
		},
		Effects = {},
		Remotes = {},
		Strings = {},
		Types = {},
		BookService = {},
		CombatService = {},
		MotionService = {},
		HurtService = {},
		Sfx = {
			broadcast = function() end,
			toPlayer = function()
				f.noises += 1
			end,
		},
		CommercePolicyService = {
			CanTrade = function(p)
				return f.allowed[p] == true and f.online[p.UserId] == p
			end,
		},
		ProfileService = {
			Get = function(p)
				return f.profiles[p]
			end,
			Mutate = function(p, fn)
				fn(f.profiles[p])
			end,
		},
		InventoryService = {
			canAdd = function(p)
				return not p.full
			end,
			add = function(p, _, count)
				p.arrows += count
				return 0
			end,
		},
	}
	local services = {
		CollectionService = { AddTag = function() end },
		RunService = {},
		ReplicatedStorage = {
			WaitForChild = function()
				return names
			end,
		},
		Players = {
			GetPlayers = function()
				return f.list
			end,
			GetPlayerByUserId = function(_, id)
				return f.online[id]
			end,
		},
	}
	local source = fs.readFile("src/server/Services/BowService.luau"):gsub(
		"return BowService%s*$",
		"return {stick=stick,pickUp=pickUp,stuck=stuck,setFolder=function(value) folder=value end}"
	)
	local fn = assert(loadstring(source, "@src/server/Services/BowService.luau"))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, name)
					return assert(services[name], name)
				end,
			},
			script = { Parent = names },
			require = function(name)
				return assert(modules[name], name)
			end,
			Vector3 = rb.Vector3,
			CFrame = rb.CFrame,
			Instance = rb.Instance,
			Enum = rb.Enum,
			RaycastParams = {
				new = function()
					return {}
				end,
			},
			Random = {
				new = function()
					return {}
				end,
			},
			os = setmetatable({
				clock = function()
					return f.at
				end,
			}, { __index = os }),
		}, { __index = getfenv() })
	)
	f.bow = fn()
	f.bow.setFolder(f.world)
	function f:stick(creative, saved)
		self.bow.stick(
			{
				shooter = self.owner,
				velocity = rb.Vector3.new(0, 0, 1),
				creative = creative,
				saved = saved,
			},
			rb.Vector3.zero,
			self.wall
		)
		return self.bow.stuck[#self.bow.stuck]
	end
	function f:pickUp()
		self.at += 1
		self.bow.pickUp()
	end
	return f
end

local f = fixture()
local entry = f:stick()
check("real stick stores server origin", entry.owner == 11 and entry.tradeAuthorized)
f:pickUp()
check(
	"two allowed players can transfer one recoverable arrow",
	f.profiles[f.recipient].arrows == 1 and #f.bow.stuck == 0 and f.noises == 1
)
f:pickUp()
check("same arrow never grants twice", f.profiles[f.recipient].arrows == 1)

f = fixture()
f.allowed[f.recipient] = false
f:stick()
f:pickUp()
check(
	"restricted recipient cannot take arrow",
	f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
)
f.allowed[f.recipient] = true
f:pickUp()
check("recipient permission recovery can take retained arrow", f.profiles[f.recipient].arrows == 1)

f = fixture()
f.allowed[f.owner] = false
entry = f:stick()
f:pickUp()
check(
	"origin denial is recorded and blocks transfer",
	not entry.tradeAuthorized and f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
)
f.allowed[f.owner] = true
f:pickUp()
check(
	"later owner permission cannot retroactively authorize origin",
	f.profiles[f.recipient].arrows == 0
)

f = fixture()
f:stick()
f.allowed[f.owner] = false
f:pickUp()
check(
	"online owner permission rechecked at pickup",
	f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
)

f = fixture()
f.allowed[f.owner] = false
f:stick()
f.owner.Character.HumanoidRootPart.Position = rb.Vector3.zero
f.list = { f.owner }
f:pickUp()
check(
	"restricted shooter can reclaim own arrow",
	f.profiles[f.owner].arrows == 1 and #f.bow.stuck == 0
)

f = fixture()
f:stick()
f.online[f.owner.UserId] = nil
f.list = { f.recipient }
f:pickUp()
check("known authorized origin survives shooter departure", f.profiles[f.recipient].arrows == 1)
f = fixture()
f.allowed[f.owner] = false
f:stick()
f.online[f.owner.UserId] = nil
f.list = { f.recipient }
f:pickUp()
check("departed restricted origin remains blocked", f.profiles[f.recipient].arrows == 0)
f = fixture()
entry = f:stick()
entry.owner = nil
f:pickUp()
check(
	"unknown origin cannot become unrestricted loot",
	f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
)

for _, flags in { { true, false }, { false, true } } do
	f = fixture()
	f:stick(flags[1], flags[2])
	f:pickUp()
	check(
		"creative or economy-saved arrows remain unrecoverable",
		f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
	)
end
f = fixture()
f.profiles[f.recipient].full = true
f:stick()
f:pickUp()
check(
	"full inventory leaves authorized arrow",
	f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1
)
f.profiles[f.recipient].full = false
f:pickUp()
check("capacity recovery grants one arrow", f.profiles[f.recipient].arrows == 1)
f = fixture()
f:stick()
f.at += 0.49
f.bow.pickUp()
check("original pickup delay retained", f.profiles[f.recipient].arrows == 0 and #f.bow.stuck == 1)
print("PASS " .. checks .. " actual-source arrow policy checks (offline only)")
