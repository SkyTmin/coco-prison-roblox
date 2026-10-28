--!strict
-- Дворы (warzone) and the four faction points [клиент fraction.warzone.*; вики; docs/research/remaining-features-
-- design.md этап 2]: Деньги, Блоки, Мобы, Спешка. WarzoneService owns the state and mirrors it into
-- ReplicatedStorage.Warzone.<point> attributes, so the server and the client read the same thing:
--   Owner = faction id holding it ("" = free), Since / Until = workspace:GetServerTimeNow() of the capture and of the
--   end of the hold, Score_<faction> = capture points of each faction while it is free, Need = points to capture.
-- While a faction holds a point, every member of it on this server gets +bonus to the multiplier of the point's kind
-- (Boosters.runningAll lists it as a faction booster with `point` set) or the point's effect (Спешка).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

export type Point = { id: string, kind: string?, effect: string? }
export type State = {
	owner: string?,
	since: number,
	untilAt: number,
	scores: { [string]: number },
	leader: string?, -- the faction with the most capture points (nil = nobody dug yet)
	lead: number,
	need: number,
}

local Warzone = {}
Warzone.cfg = Config.warzone
Warzone.points = Config.warzone.points :: { Point }
Warzone.FOLDER = "Warzone"
Warzone.LOCATION = "warzone"
Warzone.POINT_TAG = "WarzonePoint" -- the beacon top of a point (attribute Point): the client hangs its board there
Warzone.BEAM_TAG = "WarzoneBeam" -- the beacon beam (attribute Point): the server paints it in the owner's colour
Warzone.MINE_PREFIX = "warzone_" -- the pad at a point is the mini-mine warzone_<point>

local byId: { [string]: Point } = {}
for _, point in ipairs(Warzone.points) do
	byId[point.id] = point
end

function Warzone.point(id: any): Point?
	return if typeof(id) == "string" then byId[id] else nil
end

function Warzone.mineId(pointId: string): string
	return Warzone.MINE_PREFIX .. pointId
end

function Warzone.pointOfMine(mineId: string): Point?
	if string.sub(mineId, 1, #Warzone.MINE_PREFIX) ~= Warzone.MINE_PREFIX then
		return nil
	end
	return byId[string.sub(mineId, #Warzone.MINE_PREFIX + 1)]
end

local function folderOf(pointId: string): Instance?
	local root = ReplicatedStorage:FindFirstChild(Warzone.FOLDER)
	return root and root:FindFirstChild(pointId)
end

local function number(value: any): number
	return if typeof(value) == "number" then value else 0
end

-- the mirrored state of a point; a point whose hold has run out (the server clears it within a second) reads free
function Warzone.state(pointId: string, now: number?): State
	local t = now or workspace:GetServerTimeNow()
	local folder = folderOf(pointId)
	local state: State = {
		owner = nil,
		since = 0,
		untilAt = 0,
		scores = {},
		leader = nil,
		lead = 0,
		need = Warzone.cfg.captureScore,
	}
	if not folder then
		return state
	end
	local owner = folder:GetAttribute("Owner")
	local untilAt = number(folder:GetAttribute("Until"))
	if typeof(owner) == "string" and owner ~= "" and untilAt > t then
		state.owner = owner
		state.since = number(folder:GetAttribute("Since"))
		state.untilAt = untilAt
	end
	for _, f in ipairs(Config.factions.list) do
		local score = number(folder:GetAttribute("Score_" .. f.id))
		state.scores[f.id] = score
		if score > state.lead then
			state.leader, state.lead = f.id, score
		end
	end
	return state
end

-- how many points a faction holds now (the faction window: «Захваченные точки N/4»)
function Warzone.heldBy(faction: string?, now: number?): number
	if not faction then
		return 0
	end
	local n = 0
	for _, point in ipairs(Warzone.points) do
		if Warzone.state(point.id, now).owner == faction then
			n += 1
		end
	end
	return n
end

export type Bonus = { point: string, kind: string, faction: string, since: number, untilAt: number }

-- the multiplier bonuses of the points the player's faction holds (Boosters adds them like faction boosters)
function Warzone.bonuses(p: any, now: number?): { Bonus }
	local out = {}
	local faction = p and p.faction
	if typeof(faction) ~= "string" then
		return out
	end
	for _, point in ipairs(Warzone.points) do
		if point.kind then
			local state = Warzone.state(point.id, now)
			if state.owner == faction then
				table.insert(out, {
					point = point.id,
					kind = point.kind,
					faction = faction,
					since = state.since,
					untilAt = state.untilAt,
				})
			end
		end
	end
	return out
end

return Warzone
