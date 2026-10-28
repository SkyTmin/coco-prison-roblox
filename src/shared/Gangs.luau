--!strict
-- Gangs «Банды» [вики HANDBOOK-WIKI; клиент gang.*; docs/research/remaining-features-design.md §1]: the rules both the
-- server (GangService decides) and the client (GangWindow draws) read. A gang is one document shared by every server
-- (DataStore Gangs_v1, key = id); this module only reads and changes such a table — the storing, the races and the
-- money live in GangService. Every number comes from Config.gangs (scripts/design-decisions.json → gangs).
--   * roles [вики]: leader (everything), deputy (invites, kicks members, withdraws, buys upgrades), member;
--   * upgrades [клиент: 11]: points bought per level (cost × next level), one-time ones paid in $ from the treasury;
--     `Gangs.level(gang, id)` is the API the base / library / forge / ghetto stages read;
--   * quests [клиент: «Ежедневные», «Еженедельные», «Цель»]: generated inside the document's UpdateAsync with
--     `Gangs.refreshQuests`, progress added with `Gangs.addProgress`.
local Config = require(script.Parent.Config)

export type Role = "leader" | "deputy" | "member"
export type Member = { role: Role, name: string, joinedAt: number, level: number? }
export type Quest = {
	uid: string,
	type: string, -- daily / weekly / goal
	kind: string, -- dig / mobs / boss / sell / pvp
	target: number,
	progress: number,
	done: boolean?,
}
export type LogEntry = { at: number, by: string, kind: string, amount: number, what: string? }
export type Gang = {
	id: string,
	name: string,
	tag: string,
	color: number, -- index into Config.gangs.colors
	icon: number, -- index into Config.gangs.emblems
	desc: string,
	leader: number,
	members: { [string]: Member }, -- key = tostring(userId) (DataStore keeps string keys)
	upgrades: { [string]: number },
	points: number,
	treasury: number, -- coins (1 / Config.moneyScale), like p.coins
	treasuryLog: { LogEntry },
	pvp: boolean,
	quests: { day: number, week: number, seq: number, list: { Quest } }?,
	ops: { [string]: number }?, -- recent operation ids (money steps are applied once)
	createdAt: number,
	version: number?, -- +1 on every write: a server never replaces its copy with an older read
	disbanded: boolean?, -- a disbanded gang stays as a tombstone (late steps of other servers see it)
}
export type Upgrade = {
	id: string,
	tab: string, -- boosts / perks
	max: number,
	start: number?,
	currency: string, -- points / treasury
	cost: number,
	effect: number?,
	icon: string,
	fallback: string?,
}

local Gangs = {}
local cfg = Config.gangs
Gangs.cfg = cfg
Gangs.upgrades = cfg.upgrades :: { Upgrade }
Gangs.QUEST_KINDS = { "dig", "mobs", "boss", "sell", "pvp" }
Gangs.QUEST_TYPES = { "daily", "weekly", "goal" }
Gangs.ROLE_RANK = { leader = 3, deputy = 2, member = 1 } :: { [string]: number }

local byId: { [string]: Upgrade } = {}
for _, u in ipairs(Gangs.upgrades) do
	byId[u.id] = u
end

function Gangs.upgrade(id: string): Upgrade?
	return byId[id]
end

-- the current level of an upgrade (a «start» level counts from the creation: Сундуки 1)
function Gangs.level(gang: Gang?, id: string): number
	local u = byId[id]
	if not gang or not u then
		return 0
	end
	local level = gang.upgrades and gang.upgrades[id]
	return math.clamp(if typeof(level) == "number" then level else (u.start or 0), 0, u.max)
end

-- the price of the next level: points (cost × next level) or dollars from the treasury (one-time upgrades)
function Gangs.nextCost(gang: Gang?, id: string): number?
	local u = byId[id]
	if not u then
		return nil
	end
	local level = Gangs.level(gang, id)
	if level >= u.max then
		return nil
	end
	return if u.currency == "treasury" then u.cost else u.cost * (level + 1)
end

-- a perk's chance or share for its level (Фарт, Конверсия, Выносливость, Каратель, Охотник)
function Gangs.perk(gang: Gang?, id: string): number
	local u = byId[id]
	return if u then Gangs.level(gang, id) * (u.effect or 0) else 0
end

function Gangs.slots(gang: Gang?): number
	return cfg.baseSlots + Gangs.level(gang, "members") * (byId.members.effect or 1)
end

-- the treasury ceiling in coins
function Gangs.treasuryCap(gang: Gang?): number
	local dollars = cfg.treasury.base + Gangs.level(gang, "treasury") * cfg.treasury.perLevel
	return math.floor(dollars * Config.moneyScale + 0.5)
end

function Gangs.memberCount(gang: Gang?): number
	local n = 0
	if gang then
		for _ in pairs(gang.members) do
			n += 1
		end
	end
	return n
end

function Gangs.countRole(gang: Gang, role: Role): number
	local n = 0
	for _, m in pairs(gang.members) do
		if m.role == role then
			n += 1
		end
	end
	return n
end

function Gangs.roleOf(gang: Gang?, userId: number): Role?
	local m = gang and gang.members[tostring(userId)]
	return if m then m.role else nil
end

-- what a role may do [вики: Лидер всё, Заместитель выгоняет участников; сеть TG/24: улучшения не для участников;
-- решение: приглашают, выводят и покупают Заместитель и Лидер, настройки — Лидер]
local NEEDS: { [string]: Role } = {
	invite = "deputy",
	kick = "deputy",
	withdraw = "deputy",
	upgrade = "deputy",
	promote = "leader",
	demote = "leader",
	transfer = "leader",
	disband = "leader",
	settings = "leader",
}
function Gangs.can(role: Role?, action: string): boolean
	local need = NEEDS[action]
	if not role then
		return false
	end
	return need == nil or Gangs.ROLE_RANK[role] >= Gangs.ROLE_RANK[need]
end

-- the error key for a refused action: «обратитесь к Лидеру» / «к Заместителю или Лидеру» [клиент]
function Gangs.rightsError(action: string): string
	return if NEEDS[action] == "leader" then "gang_err_rights_leader" else "gang_err_rights_deputy"
end

-- the actor may kick the target: the leader anyone but himself, a deputy plain members
function Gangs.canKick(actor: Role?, target: Role?): boolean
	if not actor or not target or target == "leader" then
		return false
	end
	return actor == "leader" or (actor == "deputy" and target == "member")
end

-- ── text checks (the server filters names and descriptions with TextService on top of these) ───────────────────

-- the tag: exactly tagLength of A–Z / 0–9, not banned; returns the upper-cased tag or nil and the error key
function Gangs.checkTag(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "gang_err_tag"
	end
	local tag = string.upper(raw)
	if #tag ~= cfg.tagLength or not string.match(tag, "^[A-Z0-9]+$") then
		return nil, "gang_err_tag"
	end
	if table.find(cfg.bannedTags, tag) then
		return nil, "gang_err_tag_banned"
	end
	return tag, nil
end

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

function Gangs.checkName(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "gang_err_name"
	end
	local name = trim(string.gsub(raw, "[%c<>&]", ""))
	local length = utf8.len(name)
	if not length or length < 1 or length > cfg.nameMax then
		return nil, "gang_err_name"
	end
	return name, nil
end

function Gangs.checkDesc(raw: any): (string?, string?)
	if raw == nil then
		return "", nil
	end
	if typeof(raw) ~= "string" then
		return nil, "gang_err_desc"
	end
	local desc = trim(string.gsub(raw, "[%c<>&]", " "))
	local length = utf8.len(desc)
	if not length or length > cfg.descMax then
		return nil, "gang_err_desc"
	end
	return desc, nil
end

function Gangs.color(index: number?): Color3
	local c = cfg.colors[index or 1] or cfg.colors[1]
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Gangs.emblem(index: number?): string
	local id = cfg.emblems[index or 1] or cfg.emblems[1]
	return Config.icons.icons[id] or ""
end

-- the picture of an upgrade (our Blender icon, else the fallback item icon until it is uploaded)
function Gangs.upgradeIcon(u: Upgrade): string
	local icons = Config.icons.icons
	return icons[u.icon] or (u.fallback and icons[u.fallback]) or ""
end

-- ── quests ───────────────────────────────────────────────────────────────────────────────────────────────────────
local q = cfg.quests
local DAY = 86400

-- day / week numbers on Moscow time [решение: обновление 00:00 МСК, неделя с понедельника]
function Gangs.dayIndex(now: number): number
	return (now + q.dayOffsetHours * 3600) // DAY
end

function Gangs.weekIndex(now: number): number
	return (Gangs.dayIndex(now) + 3) // 7 -- day 0 (1 Jan 1970) was a Thursday: +3 starts weeks on Monday
end

function Gangs.nextDayAt(now: number): number
	return (Gangs.dayIndex(now) + 1) * DAY - q.dayOffsetHours * 3600
end

function Gangs.nextWeekAt(now: number): number
	return ((Gangs.weekIndex(now) + 1) * 7 - 3) * DAY - q.dayOffsetHours * 3600
end

-- the first quests come firstAfterHours after the creation [клиент gang.gui.quests.soon]
function Gangs.questsOpenAt(gang: Gang): number
	return gang.createdAt + q.firstAfterHours * 3600
end

function Gangs.averageLevel(gang: Gang): number
	local sum, n = 0, 0
	for _, m in pairs(gang.members) do
		sum += m.level or 1
		n += 1
	end
	return if n > 0 then sum / n else 1
end

-- k = 1 + average level / levelDivisor [решение]
function Gangs.questTarget(kind: string, questType: string, averageLevel: number): number
	local k = 1 + averageLevel / q.levelDivisor
	local mult = if questType == "weekly"
		then q.weeklyMultiplier
		elseif questType == "goal" then q.goalMultiplier
		else 1
	return math.max(1, math.floor(q.targets[kind] * k * mult + 0.5))
end

function Gangs.questPoints(questType: string): number
	return q.points[questType] or 0
end

function Gangs.questBoosterKind(kind: string): string
	return q.boosterKind[kind] or "blocks"
end

local function pickKinds(count: number, rng: Random): { string }
	local pool = table.clone(Gangs.QUEST_KINDS)
	local out = {}
	for _ = 1, math.min(count, #pool) do
		table.insert(out, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	return out
end

-- new day / week / finished goal → fresh quests; returns whether the list changed (call inside the UpdateAsync)
function Gangs.refreshQuests(gang: Gang, now: number, rng: Random): boolean
	if now < Gangs.questsOpenAt(gang) then
		return false
	end
	local state = gang.quests or { day = -1, week = -1, seq = 0, list = {} }
	gang.quests = state
	local changed = false
	local average = Gangs.averageLevel(gang)
	local function add(questType: string, kind: string)
		state.seq += 1
		table.insert(state.list, {
			uid = tostring(state.seq),
			type = questType,
			kind = kind,
			target = Gangs.questTarget(kind, questType, average),
			progress = 0,
		})
		changed = true
	end
	local function replace(questType: string, count: number)
		for i = #state.list, 1, -1 do
			if state.list[i].type == questType then
				table.remove(state.list, i)
			end
		end
		for _, kind in ipairs(pickKinds(count, rng)) do
			add(questType, kind)
		end
	end
	local day, week = Gangs.dayIndex(now), Gangs.weekIndex(now)
	if state.day ~= day then
		state.day = day
		replace("daily", q.daily)
	end
	if state.week ~= week then
		state.week = week
		replace("weekly", q.weekly)
	end
	-- a goal is replaced as soon as it is done [клиент: «Цель»; решение: сразу]
	local goals = 0
	for i = #state.list, 1, -1 do
		local quest = state.list[i]
		if quest.type == "goal" then
			if quest.done then
				table.remove(state.list, i)
				changed = true
			else
				goals += 1
			end
		end
	end
	for _, kind in ipairs(pickKinds(q.goal - goals, rng)) do
		add("goal", kind)
	end
	return changed
end

-- adds progress of a kind to the open quests; returns the quests it finished (their points are already added)
function Gangs.addProgress(gang: Gang, kind: string, amount: number): { Quest }
	local finished = {}
	local state = gang.quests
	if not state or amount <= 0 then
		return finished
	end
	for _, quest in ipairs(state.list) do
		if quest.kind == kind and not quest.done then
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress >= quest.target then
				quest.done = true
				gang.points += Gangs.questPoints(quest.type)
				table.insert(finished, quest)
			end
		end
	end
	return finished
end

-- whether a kind of progress would count now (the server skips collecting it otherwise)
function Gangs.wants(gang: Gang?, kind: string): boolean
	local state = gang and gang.quests
	if not state then
		return false
	end
	for _, quest in ipairs(state.list) do
		if quest.kind == kind and not quest.done then
			return true
		end
	end
	return false
end

-- «1:05:09» / «12:04»
function Gangs.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

return Gangs
