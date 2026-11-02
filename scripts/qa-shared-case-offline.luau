--!nocheck
-- Actual CaseService + InventoryService under isolated Lune mocks.
-- Read hooks run another UI operation at the point where a real storage read can yield.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local env = getfenv()
local checks, failures = 0, {}
local function check(name, ok)
	checks += 1
	if not ok then
		table.insert(failures, name)
	end
end
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, child in v do
		out[k] = copy(child)
	end
	return out
end
local function fixture(seedInventory, seedPages)
	local f = {
		pages = copy(seedPages or { [1] = {}, [2] = {} }),
		calls = {},
		pending = false,
		mirrors = 0,
	}
	f.profile = {
		inventory = copy(seedInventory or {}),
		caseContents = {},
		casePages = {},
		coins = 0,
		faction = "slavs",
		gang = { id = "guild" },
		selectedSlot = 1,
		enderChest = {},
	}
	local attrs = {}
	f.actor = {
		Name = "Fixture",
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
	}
	local root = {
		Position = rb.Vector3.zero,
		IsA = function(_, k)
			return k == "BasePart"
		end,
	}
	f.root = root
	f.actor.Character = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return { Health = 100 }
		end,
	}
	local partAttrs = { Faction = "slavs", ChestIndex = 1 }
	f.part = {
		Position = rb.Vector3.zero,
		tag = "GangChest",
		GetAttribute = function(_, k)
			return partAttrs[k]
		end,
		IsA = function(_, k)
			return k == "BasePart"
		end,
		IsDescendantOf = function()
			return true
		end,
	}
	local names = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	})
	local modules = {
		Types = {},
		Boosters = {},
		Donate = {},
		Nicknames = {},
		ChatService = {},
		AncientCase = {},
		ArtifactService = {},
		NicknameService = {},
		Config = {
			tools = { pickaxe = true },
			rules = { survival = { enderChest = { slots = 27, sections = 3 } } },
		},
		Strings = {
			t = function(k)
				return k
			end,
			localeOf = function()
				return "en"
			end,
			money = tostring,
		},
		Sfx = { broadcast = function() end },
		Remotes = {
			event = function()
				return { FireClient = function() end }
			end,
		},
		GangHouseService = {
			allowed = function()
				return f.allowed ~= false
			end,
		},
		GangService = {
			gangOf = function(p)
				return p and p.gang
			end,
		},
		ProfileService = {
			Get = function()
				return f.profile
			end,
			IsReal = function()
				return true
			end,
			Mutate = function(_, fn)
				f.mirrors += 1
				fn(f.profile)
			end,
		},
	}
	local services = {
		CollectionService = {
			HasTag = function(_, part, tag)
				return part.tag == tag
			end,
		},
		HttpService = {},
		Players = {},
		RunService = {},
		ServerStorage = {},
		ReplicatedStorage = {
			Shared = names,
			WaitForChild = function()
				return names
			end,
		},
	}
	local function load(path, transform)
		local source = fs.readFile(path)
		if transform then
			source = transform(source)
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(
			fn,
			setmetatable({
				game = {
					GetService = function(_, k)
						return assert(services[k], k)
					end,
				},
				workspace = {},
				script = { Parent = names },
				require = function(k)
					return assert(modules[k], k)
				end,
				Random = {
					new = function()
						return {}
					end,
				},
			}, { __index = env })
		)
		return fn()
	end
	modules.Persistence = load("src/shared/Persistence.luau")
	modules.Numbers = load("src/shared/Numbers.luau")
	modules.InventoryService = load("src/server/Services/InventoryService.luau")
	modules.Vault = load("src/shared/Vault.luau")
	modules.SharedStorageRecord = load("src/server/Services/SharedStorageRecord.luau")
	modules.SharedStorageService = {
		Snapshot = function(_, _, page)
			local result = copy(f.pages[page])
			local hook = f.readHook
			f.readHook = nil
			if hook then
				hook()
			end
			return result, 0
		end,
	}
	modules.GangChestService = {
		MAX_PAGES = 8,
		Valid = function()
			return true
		end,
		Open = function()
			return true
		end,
		PageCount = function()
			local hook = f.countHook
			f.countHook = nil
			if hook then
				hook()
			end
			return f.pageCount or 2
		end,
		Page = function(_, page)
			local result = copy(f.pages[page])
			local hook = f.pageHook
			f.pageHook = nil
			if hook then
				hook()
			end
			return result
		end,
	}
	modules.FactionStorageService = {
		Chest = function(_, page)
			local result = copy(f.pages[page])
			local hook = f.factionHook
			f.factionHook = nil
			if hook then
				hook()
			end
			return result
		end,
	}
	modules.StorageTransferService = {
		Pending = function()
			return f.pending
		end,
		Begin = function(_, kind, key, page, revision, before, after, afterPage, coins)
			if f.pending then
				return false
			end
			table.insert(f.calls, {
				kind = kind,
				key = key,
				page = page,
				revision = revision,
				before = copy(before),
				after = copy(after),
				afterPage = copy(afterPage),
				coins = coins,
			})
			-- Transfer durability has its own source fixtures; this mock records and applies accepted intent.
			f.pages[page], f.profile.inventory = copy(afterPage), copy(after)
			f.profile.coins += coins
			return true
		end,
	}
	f.case = load("src/server/Services/CaseService.luau", function(source)
		return source:gsub(
			"return CaseService%s*$",
			"CaseService._open = openChest; CaseService._move = move; CaseService._page = turnPage; CaseService._close = close; CaseService._sessions = sessions; return CaseService"
		)
	end)
	function f:open()
		self.case._open(self.actor, self.part)
	end
	function f:move(from, to, count, page)
		self.case._move(
			self.actor,
			if self.part.tag == "GangChest" then "gangChest" else "factionChest",
			from,
			to,
			count,
			page or 1
		)
	end
	return f
end
local case1, inv1, inv2 =
	{ container = "case", index = 1 },
	{ container = "inv", index = 1 },
	{ container = "inv", index = 2 }
local apple = { id = "apple", count = 10 }
local book =
	{ id = "ancient_book", count = 1, books = { { id = "hammer", level = 3 } }, applyChance = 73 }
local function amount(slots, id)
	local total = 0
	for _, stack in slots do
		if stack.id == id then
			total += stack.count
		end
	end
	return total
end

local f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f:open()
f.readHook = function()
	f.case._page(f.actor, 2)
end
f:move(case1, inv1)
check(
	"page change during snapshot never cross-copies page-one item into page two",
	#f.calls == 0 and amount(f.pages[1], book.id) == 1 and amount(f.profile.inventory, book.id) == 0
)

f = fixture({ [1] = apple })
f:open()
f.readHook = function()
	f.pending = true
end
f:move(inv1, inv2)
check(
	"pending transfer started during read blocks inventory-only replacement too",
	f.profile.inventory[1] and f.profile.inventory[1].count == 10 and f.profile.inventory[2] == nil
)

f = fixture()
f:open()
f.pageHook = function()
	f.case._close(f.actor)
end
f.case._page(f.actor, 2)
check(
	"closed session cannot be revived by delayed page read",
	f.case._sessions[f.actor] == nil
		and next(f.profile.caseContents.gangChest or {}) == nil
		and f.profile.casePages.gangChest == 1
)

f = fixture({}, { [1] = {}, [2] = { [1] = apple }, [3] = { [1] = book } })
f.pageCount = 3
f:open()
f.pageHook = function()
	f.case._page(f.actor, 3)
end
f.case._page(f.actor, 2)
check(
	"newer page response wins over delayed older request",
	f.case._sessions[f.actor].index == 3 and f.profile.casePages.gangChest == 3
)

f = fixture()
f:open()
f.countHook = function()
	f.case._close(f.actor)
end
f.case._page(f.actor, 2)
check(
	"closed session during page-count read cannot update mirror",
	f.case._sessions[f.actor] == nil and f.profile.casePages.gangChest == 1
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f.part.tag = "FactionChest"
f.factionHook = function()
	f.profile.faction = nil
end
f:open()
check(
	"faction membership lost during open read prevents new session",
	f.case._sessions[f.actor] == nil
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f.part.tag = "FactionChest"
f.factionHook = function()
	f.root.Position = rb.Vector3.new(100, 0, 0)
end
f:open()
check("walking away during faction read prevents new session", f.case._sessions[f.actor] == nil)

f = fixture()
f.pageHook = function()
	f.allowed = false
end
f:open()
check(
	"changed gang-house permission during read prevents new session",
	f.case._sessions[f.actor] == nil
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
local newerPart = {
	Position = rb.Vector3.zero,
	tag = "EnderChest",
	GetAttribute = function()
		return nil
	end,
	IsA = function(_, k)
		return k == "BasePart"
	end,
	IsDescendantOf = function()
		return true
	end,
}
f.pageHook = function()
	f.case._open(f.actor, newerPart)
end
f:open()
check(
	"newer open wins over older shared chest read",
	f.case._sessions[f.actor] and f.case._sessions[f.actor].id == "enderChest"
)

f = fixture()
f.pageHook = function()
	f.countHook = function()
		f.case._close(f.actor)
	end
end
local openOk = pcall(function()
	f:open()
end)
check(
	"close during final page-count read cannot crash or resurrect open",
	openOk and f.case._sessions[f.actor] == nil
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f:open()
f:move(case1, inv1)
check(
	"ordinary withdrawal routes exact page and preserves book metadata",
	#f.calls == 1
		and f.calls[1].page == 1
		and f.profile.inventory[1].applyChance == 73
		and f.pages[1][1] == nil
)

f = fixture({ [1] = { id = "apple", count = 60 } }, { [1] = { [1] = apple }, [2] = {} })
f:open()
f:move(case1, inv1, 7)
check(
	"partial merge respects destination capacity and leaves source remainder",
	f.profile.inventory[1].count == 64 and f.pages[1][1].count == 6
)

f = fixture({ [1] = apple }, { [1] = { [1] = book }, [2] = {} })
f:open()
f:move(case1, inv1)
check(
	"full-stack swap carries both sides without loss",
	f.profile.inventory[1].id == book.id
		and f.pages[1][1].id == "apple"
		and f.pages[1][1].count == 10
)

f = fixture({ [1] = { id = "apple", count = 60 } }, { [1] = { [1] = apple }, [2] = {} })
f:open()
f:move(case1, "quick")
check(
	"quick move merges then finds a free inventory slot",
	f.profile.inventory[1].count == 64
		and f.profile.inventory[2].count == 6
		and f.pages[1][1] == nil
)

local full = {}
for i = 1, 36 do
	full[i] = { id = "pickaxe", count = 1, level = i }
end
f = fixture(full, { [1] = { [1] = book }, [2] = {} })
f:open()
f:move(case1, "quick")
check(
	"quick move into full inventory does not start a transfer or remove source",
	#f.calls == 0 and f.pages[1][1].id == book.id and amount(f.profile.inventory, "pickaxe") == 36
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f:open()
f:move(case1, inv1, 0 / 0)
check(
	"NaN count is a no-op at shared transfer integration",
	#f.calls == 0 and f.pages[1][1].id == book.id and next(f.profile.inventory) == nil
)

f = fixture({}, { [1] = { [1] = book }, [2] = {} })
f:open()
f:move(case1, inv1, nil, 2)
check(
	"stale client page cannot move current page contents",
	#f.calls == 0 and f.pages[1][1].id == book.id
)

if #failures > 0 then
	for _, message in failures do
		warn("FAIL: " .. message)
	end
	error(string.format("Shared Case integration: %d/%d failed", #failures, checks))
end
print(
	string.format(
		"Shared Case integration PASS: %d actual-source checks; mocked reads/transfer boundary, no Studio",
		checks
	)
)
