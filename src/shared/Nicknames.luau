--!strict
-- Клички (этап 9; docs/research/remaining-features-design.md, facts §9). The nickname case grants one the player does
-- not own yet [вики]; the original has 46 [клиент titles.list.*] — ours are as many, with our own names, in 4 rarity
-- tiers with a weight per name (scripts/design-decisions.json → keys.nicknameCase.tiers / weights) [решение].
-- p.nicknames = the owned ones, p.nickname = the active one (nil = none) [клиент ranks.*: one active, «Нажмите, чтобы
-- применить / снять»]. Server (CaseService, NicknameService) and client (NicknameWindow, CasePreviewWindow) share this.
local Config = require(script.Parent.Config)

local Nicknames = {}

Nicknames.TIERS = { "common", "rare", "epic", "legendary" }
-- Minecraft's rarity colours plus gold on top [решение]
Nicknames.COLORS = {
	common = Color3.fromRGB(255, 255, 255),
	rare = Color3.fromRGB(85, 255, 255),
	epic = Color3.fromRGB(255, 85, 255),
	legendary = Color3.fromRGB(255, 190, 40),
} :: { [string]: Color3 }

local cfg: any = Config.keys.nicknameCase or {}
local list: { string } = {}
local tierOf: { [string]: string } = {}
for _, tier in ipairs(Nicknames.TIERS) do
	local names = if typeof(cfg.tiers) == "table" then cfg.tiers[tier] else nil
	for _, name in ipairs(if typeof(names) == "table" then names else {}) do
		if typeof(name) == "string" and not tierOf[name] then
			table.insert(list, name)
			tierOf[name] = tier
		end
	end
end

-- every nickname, common first, in the config's order
Nicknames.list = list

function Nicknames.tier(name: any): string?
	return if typeof(name) == "string" then tierOf[name] else nil
end

function Nicknames.color(name: any): Color3
	return Nicknames.COLORS[Nicknames.tier(name) or "common"] or Nicknames.COLORS.common
end

function Nicknames.weight(name: string): number
	local tier = tierOf[name]
	local w = tier and typeof(cfg.weights) == "table" and cfg.weights[tier]
	return if typeof(w) == "number" and w > 0 then w else 1
end

function Nicknames.owns(p: any, name: any): boolean
	return typeof(p) == "table"
		and typeof(p.nicknames) == "table"
		and typeof(name) == "string"
		and table.find(p.nicknames, name) ~= nil
end

-- the owned nicknames that still exist in the list
function Nicknames.ownedCount(p: any): number
	local n = 0
	for _, name in ipairs(list) do
		if Nicknames.owns(p, name) then
			n += 1
		end
	end
	return n
end

-- the case roll: a nickname not in `owned`, weighted by its tier; nil when every one is owned
function Nicknames.pick(owned: { string }, random: Random): string?
	local pool: { string } = {}
	local total = 0
	for _, name in ipairs(list) do
		if not table.find(owned, name) then
			table.insert(pool, name)
			total += Nicknames.weight(name)
		end
	end
	if #pool == 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	for _, name in ipairs(pool) do
		roll -= Nicknames.weight(name)
		if roll < 0 then
			return name
		end
	end
	return pool[#pool]
end

-- chance (0..1) of each tier on the next roll for these owned names
function Nicknames.chances(owned: { string }): { [string]: number }
	local sums: { [string]: number } = {}
	local total = 0
	for _, name in ipairs(list) do
		if not table.find(owned, name) then
			local tier = tierOf[name]
			local w = Nicknames.weight(name)
			sums[tier] = (sums[tier] or 0) + w
			total += w
		end
	end
	local out: { [string]: number } = {}
	for _, tier in ipairs(Nicknames.TIERS) do
		out[tier] = if total > 0 then (sums[tier] or 0) / total else 0
	end
	return out
end

return Nicknames
