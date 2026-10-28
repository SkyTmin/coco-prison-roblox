--!strict
-- Столовая and «Ежедневные награды» (этап 7, docs/research/remaining-features-design.md) — the rules both sides share
-- (DailyService grants, DailyWindow draws). Times are workspace:GetServerTimeNow() seconds, the same on every server
-- and on the client.
--   * Столовая [клиент canteen.*]: open openMinutes out of every periodMinutes [решение: 5 из 30], one portion per
--     opening (p.canteen = the number of the opening the portion was taken in).
--   * /daily [клиент daily.*]: 7 days in a circle, a new reward at 00:00 МСК [решение]; more than resetAfterHours since
--     the last one starts the circle again from day 1 [решение: 48 ч]. p.daily = { streak, lastDay, lastAt }: streak =
--     rewards taken in a row, lastDay = the Moscow day number of the last one, lastAt = its time.
local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)

export type Reward = {
	money: number?, -- $ (a money check, paid at once)
	item: string?,
	count: number?,
	booster: string?, -- kind of a local booster that goes into the booster storage
	mult: number?,
	minutes: number?,
}
export type State = {
	day: number, -- the card of today: the one to take, or the one taken today
	claimed: boolean, -- today's reward is taken
	taken: number, -- cards of the current circle already taken (0…7)
	nextAt: number, -- when the next reward opens (the next Moscow midnight)
}

local Daily = {}
local DAY = 86400
local canteen = Config.daily.canteen
local daily = Config.daily.daily

Daily.days = daily.days :: { Reward }
Daily.CYCLE = #Daily.days

-- ── Столовая ─────────────────────────────────────────────────────────────────────────────────────────────────────

local PERIOD = canteen.periodMinutes * 60
local OPEN = canteen.openMinutes * 60

-- the number of the canteen's current period (one opening each)
function Daily.canteenPeriod(now: number): number
	return now // PERIOD
end

-- open now?, and when it changes (closes when open, opens when closed)
function Daily.canteenOpen(now: number): (boolean, number)
	local start = Daily.canteenPeriod(now) * PERIOD
	if now - start < OPEN then
		return true, start + OPEN
	end
	return false, start + PERIOD
end

Daily.portion = canteen.portion :: { item: string, count: number }

-- ── /daily ───────────────────────────────────────────────────────────────────────────────────────────────────────

function Daily.dayIndex(now: number): number
	return (now + daily.dayOffsetHours * 3600) // DAY
end

function Daily.nextDayAt(now: number): number
	return (Daily.dayIndex(now) + 1) * DAY - daily.dayOffsetHours * 3600
end

-- the streak that still counts now: a gap longer than resetAfterHours breaks it
function Daily.streak(p: any, now: number): number
	local d = p.daily
	if typeof(d) ~= "table" or typeof(d.streak) ~= "number" then
		return 0
	end
	if d.lastDay < Daily.dayIndex(now) and now - d.lastAt > daily.resetAfterHours * 3600 then
		return 0
	end
	return d.streak
end

function Daily.state(p: any, now: number): State
	local d = p.daily
	local claimed = typeof(d) == "table"
		and typeof(d.lastDay) == "number"
		and d.lastDay >= Daily.dayIndex(now)
	local streak = Daily.streak(p, now)
	local taken = if claimed then (streak - 1) % Daily.CYCLE + 1 else streak % Daily.CYCLE
	return {
		day = if claimed then taken else taken + 1,
		claimed = claimed,
		taken = taken,
		nextAt = Daily.nextDayAt(now),
	}
end

-- the reward's name in a language: «Денежный чек на 500 $», «Древняя звезда ×2», «Локальный бустер денег ×1.5 на 30 минут»
function Daily.rewardText(reward: Reward, locale: string): string
	if reward.money then
		return Strings.t("money_check", locale, Strings.grouped(reward.money, 0))
	elseif reward.booster then
		return Strings.t(
			"booster_for_minutes",
			locale,
			Strings.boosterName(reward.booster, nil, locale) .. " ×" .. tostring(reward.mult or 1),
			reward.minutes or Config.boosters.minutes
		)
	end
	local name = Strings.itemName(reward.item or "", nil, locale)
	return if (reward.count or 1) > 1 then name .. " ×" .. tostring(reward.count) else name
end

-- 3725 → "1:02:05"
function Daily.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

return Daily
