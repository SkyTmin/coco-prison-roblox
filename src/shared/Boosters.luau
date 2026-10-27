--!strict
-- Local boosters [вики DONATE-SHOP-BOOSTERS «Хранилище бустеров»; владелец 27.10: «локальные (то есть только для
-- игроков) … 1.10 … нужно им и хранилище»]: rewards land in the storage (p.boosters, same boosters stacked) and run
-- only when the player activates them; a booster of a kind that is already running waits in the queue and starts
-- when the one before it ends. Times are workspace:GetServerTimeNow() seconds, so the client counts down the same
-- clock; they run on while the player is offline [решение]. Kinds: blocks (dug blocks), money (selling), mobs
-- (kills). Pure profile functions shared by BoosterService and the client.
local Config = require(script.Parent.Config)

export type Stored = { kind: string, mult: number, minutes: number, count: number }
export type Active = { kind: string, mult: number, startsAt: number, endsAt: number }

local Boosters = {}
Boosters.kinds = Config.boosters.kinds :: { string }

function Boosters.isKind(kind: any): boolean
	return typeof(kind) == "string" and table.find(Boosters.kinds, kind) ~= nil
end

function Boosters.now(): number
	return workspace:GetServerTimeNow()
end

-- the running booster of a kind (nil when none runs)
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
	local a = Boosters.running(p, kind, now)
	return if a then a.mult else 1
end

-- seconds of this kind still ahead, the queue included
function Boosters.remaining(p: any, kind: string, now: number?): number
	local t = now or Boosters.now()
	local last = 0
	for _, a in ipairs(p.activeBoosters or {}) do
		if a.kind == kind then
			last = math.max(last, a.endsAt)
		end
	end
	return math.max(0, last - t)
end

function Boosters.storedCount(p: any): number
	local n = 0
	for _, s in ipairs(p.boosters or {}) do
		n += s.count
	end
	return n
end

-- server: a reward into the storage (the same kind, multiplier and length stack)
function Boosters.store(p: any, kind: string, mult: number?, minutes: number?)
	local m = mult or Config.boosters.localMultiplier
	local min = minutes or Config.boosters.minutes
	p.boosters = p.boosters or {}
	if Boosters.storedCount(p) >= Config.boosters.maxStored then
		return
	end
	for _, s in ipairs(p.boosters) do
		if s.kind == kind and s.mult == m and s.minutes == min then
			s.count += 1
			return
		end
	end
	table.insert(p.boosters, { kind = kind, mult = m, minutes = min, count = 1 })
end

-- server: drops finished boosters
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

-- server: starts stored booster #index (or queues it behind the running one); returns the booster and whether it waits
function Boosters.activate(p: any, index: number, now: number?): (Stored?, boolean)
	local stored = p.boosters and p.boosters[index]
	if not stored then
		return nil, false
	end
	local t = now or Boosters.now()
	Boosters.prune(p, t)
	local startsAt = t
	for _, a in ipairs(p.activeBoosters or {}) do
		if a.kind == stored.kind then
			startsAt = math.max(startsAt, a.endsAt)
		end
	end
	p.activeBoosters = p.activeBoosters or {}
	table.insert(p.activeBoosters, {
		kind = stored.kind,
		mult = stored.mult,
		startsAt = startsAt,
		endsAt = startsAt + stored.minutes * 60,
	})
	stored.count -= 1
	if stored.count <= 0 then
		table.remove(p.boosters, index)
	end
	return stored, startsAt > t
end

return Boosters
