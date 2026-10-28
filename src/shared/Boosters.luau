--!strict
-- Boosters [вики DONATE-SHOP-BOOSTERS «Хранилище бустеров»; владелец 27.10: «локальные (то есть только для
-- игроков) … 1.10 … нужно им и хранилище», «если кто-то активировал бустер для всех, там его ник»]: rewards land in
-- the storage (p.boosters, same boosters stacked) and run only when the player activates them. Three scopes like
-- the original shop: local (only you; p.activeBoosters), faction (every member of your faction online) and global
-- (everyone online), plus gang (every member of a gang online: the gang quest reward, never stored; GangService) —
-- the shared ones live in a list shared by all servers (GlobalBoosterService, MemoryStore) and
-- reach the clients through ReplicatedStorage.SharedBoosters. A booster of a kind and scope that already runs waits
-- in the queue and starts when the one before it ends. Times are workspace:GetServerTimeNow() seconds (the client
-- counts down the same clock) and run on while the player is offline [решение]. Kinds: blocks (dug blocks), money
-- (selling), mobs (kills). Several boosters of one kind add up: 1 + Σ(mult − 1) [решение].
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

export type Stored = { kind: string, mult: number, minutes: number, count: number, scope: string? }
export type Active = {
	kind: string,
	mult: number,
	startsAt: number,
	endsAt: number,
	scope: string?, -- nil = local
	faction: string?, -- faction scope: whose members it boosts
	gang: string?, -- gang scope: the gang id whose members it boosts (quest rewards, GangService)
	by: string?, -- shared boosters: who started it (shown in the HUD)
	id: string?, -- shared boosters: the activation id
}

local Boosters = {}
Boosters.kinds = Config.boosters.kinds :: { string }
Boosters.scopes = Config.boosters.scopes :: { string }
Boosters.SHARED_VALUE = "SharedBoosters"

-- the frame colours of the original shop: blue local, orange faction, red global
Boosters.SCOPE_COLORS = {
	["local"] = Color3.fromRGB(80, 180, 255),
	faction = Color3.fromRGB(255, 154, 42),
	global = Color3.fromRGB(255, 70, 70),
	gang = Color3.fromRGB(90, 210, 90), -- [решение] green: the gang quest reward
} :: { [string]: Color3 }

-- the bottle picture (assets/models/booster, Blender) of a kind and scope; the flat sprite until it is uploaded
function Boosters.icon(kind: string, scope: string?): string
	local icons = Config.icons.icons
	return icons["booster_" .. kind .. "_" .. (scope or "local")] or icons["booster_" .. kind] or ""
end

-- a donate booster as an inventory item «booster_<kind>_<scope>» (×Donate.MULT for Donate.MINUTES) [владелец 28.10:
-- «всё, что можно купить в донат-магазине, можно выставлять на аукционе»]: taken out of the storage with
-- BoosterToItem, put back with «Использовать»
function Boosters.itemId(kind: string, scope: string?): string
	return "booster_" .. kind .. "_" .. (scope or "local")
end

function Boosters.fromItem(id: string): (string?, string?)
	local kind, scope = id:match("^booster_(%a+)_(%a+)$")
	if kind and Boosters.isKind(kind) and Boosters.SCOPE_COLORS[scope :: string] then
		return kind, scope
	end
	return nil, nil
end

function Boosters.isKind(kind: any): boolean
	return typeof(kind) == "string" and table.find(Boosters.kinds, kind) ~= nil
end

function Boosters.scopeOf(b: { scope: string? }): string
	return b.scope or "local"
end

function Boosters.now(): number
	return workspace:GetServerTimeNow()
end

-- the faction and global boosters every server knows (written by GlobalBoosterService)
local cachedJson, cachedList = "", {} :: { Active }
function Boosters.shared(): { Active }
	local value = ReplicatedStorage:FindFirstChild(Boosters.SHARED_VALUE)
	if not value or not value:IsA("StringValue") then
		return {}
	end
	if value.Value ~= cachedJson then
		cachedJson = value.Value
		local ok, list = pcall(HttpService.JSONDecode, HttpService, cachedJson)
		cachedList = if ok and typeof(list) == "table" then list else {}
	end
	return cachedList
end

local function applies(p: any, a: Active): boolean
	local scope = Boosters.scopeOf(a)
	if scope == "global" then
		return true
	elseif scope == "faction" then
		return a.faction ~= nil and p.faction == a.faction
	elseif scope == "gang" then
		return a.gang ~= nil and p.gang ~= nil and p.gang.id == a.gang
	end
	return true -- local ones come from the player's own profile
end

-- every booster running for this player now: own local ones first, then faction, then global
function Boosters.runningAll(p: any, now: number?): { Active }
	local t = now or Boosters.now()
	local out = {}
	for _, a in ipairs(p.activeBoosters or {}) do
		if a.startsAt <= t and t < a.endsAt then
			table.insert(out, a)
		end
	end
	for _, a in ipairs(Boosters.shared()) do
		if a.startsAt <= t and t < a.endsAt and applies(p, a) then
			table.insert(out, a)
		end
	end
	return out
end

-- the running local booster of a kind (nil when none runs)
function Boosters.running(p: any, kind: string, now: number?): Active?
	local t = now or Boosters.now()
	for _, a in ipairs(p.activeBoosters or {}) do
		if a.kind == kind and a.startsAt <= t and t < a.endsAt then
			return a
		end
	end
	return nil
end

function Boosters.multiplier(p: any, kind: string, now: number?): number
	local total = 1
	for _, a in ipairs(Boosters.runningAll(p, now)) do
		if a.kind == kind then
			total += a.mult - 1
		end
	end
	return total
end

-- queued after `a` in the same line (kind, scope, faction / gang): how many wait and the seconds till the last one ends
function Boosters.queueAfter(p: any, a: Active): (number, number)
	local list = if Boosters.scopeOf(a) == "local"
		then p.activeBoosters or {}
		else Boosters.shared()
	local waiting, last = 0, a.endsAt
	for _, b in ipairs(list) do
		if
			b ~= a
			and b.kind == a.kind
			and Boosters.scopeOf(b) == Boosters.scopeOf(a)
			and b.faction == a.faction
			and b.gang == a.gang
		then
			if b.startsAt >= a.endsAt then
				waiting += 1
				last = math.max(last, b.endsAt)
			end
		end
	end
	return waiting, last
end

function Boosters.storedCount(p: any): number
	local n = 0
	for _, s in ipairs(p.boosters or {}) do
		n += s.count
	end
	return n
end

-- server: a reward into the storage (the same kind, scope, multiplier and length stack)
function Boosters.store(
	p: any,
	kind: string,
	scope: string?,
	mult: number?,
	minutes: number?,
	count: number?
)
	local m = mult or Config.boosters.localMultiplier
	local min = minutes or Config.boosters.minutes
	local sc = if scope == "local" then nil else scope
	local n = count or 1
	p.boosters = p.boosters or {}
	if Boosters.storedCount(p) + n > Config.boosters.maxStored then
		return
	end
	for _, s in ipairs(p.boosters) do
		if s.kind == kind and s.mult == m and s.minutes == min and s.scope == sc then
			s.count += n
			return
		end
	end
	table.insert(p.boosters, { kind = kind, mult = m, minutes = min, count = n, scope = sc })
end

-- server: drops finished local boosters
function Boosters.prune(p: any, now: number?)
	local t = now or Boosters.now()
	local list = p.activeBoosters
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i].endsAt <= t then
			table.remove(list, i)
		end
	end
end

-- server: takes one booster #index out of the storage; returns a copy of it
function Boosters.take(p: any, index: number): Stored?
	local stored = p.boosters and p.boosters[index]
	if not stored then
		return nil
	end
	stored.count -= 1
	if stored.count <= 0 then
		table.remove(p.boosters, index)
	end
	return {
		kind = stored.kind,
		mult = stored.mult,
		minutes = stored.minutes,
		count = 1,
		scope = stored.scope,
	}
end

-- whose line a shared booster is in: its faction or its gang (nil for local and global ones)
function Boosters.ownerOf(a: { faction: string?, gang: string? }): string?
	return a.faction or a.gang
end

-- start time for a new booster in a line: now, or when the last one of that line ends (owner: faction or gang id)
function Boosters.queueStart(
	list: { Active },
	kind: string,
	scope: string,
	owner: string?,
	now: number
): number
	local startsAt = now
	for _, a in ipairs(list) do
		if a.kind == kind and Boosters.scopeOf(a) == scope and Boosters.ownerOf(a) == owner then
			startsAt = math.max(startsAt, a.endsAt)
		end
	end
	return startsAt
end

-- server: starts a local booster (or queues it behind the running one); returns whether it waits
function Boosters.startLocal(p: any, stored: Stored, now: number?): boolean
	local t = now or Boosters.now()
	Boosters.prune(p, t)
	p.activeBoosters = p.activeBoosters or {}
	local startsAt = Boosters.queueStart(p.activeBoosters, stored.kind, "local", nil, t)
	table.insert(p.activeBoosters, {
		kind = stored.kind,
		mult = stored.mult,
		startsAt = startsAt,
		endsAt = startsAt + stored.minutes * 60,
	})
	return startsAt > t
end

return Boosters
