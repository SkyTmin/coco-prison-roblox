--!strict
-- "Тренер" window of the original (NPC-MENU-RECOVERY npc-01): three cards — Сила / Ловкость / Нужды — each with its
-- round badge, coloured name, "Ур. 0 / 20", a description, "Требования" with counters "have / need" (green when
-- met, red otherwise) and a button: grey "Требования не выполнены" or "Прокачать". Requirement growth per level is
-- ours [решение]. Interactive like the level window [владелец 27.10: «к навыкам, там тоже нужна интерактивность»]:
-- the card is tinted in its stat's colour and lights up under the mouse, the badge floats, twenty pips show the
-- level, «now → next» what the next level gives, every requirement has its bar and a tick, the ready button glows in
-- the stat's colour and sinks when pressed; a level gained flashes the card and floats «Ур. N» up. Built once and
-- updated in place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local TrainerWindow = {}

local STATS = { "strength", "agility", "needs" }
local STAT_COLORS = {
	strength = Color3.fromRGB(255, 96, 96),
	agility = Color3.fromRGB(80, 220, 235),
	needs = Color3.fromRGB(255, 196, 70),
}
local REQ_ORDER = { "zombies", "kills", "bats", "money" }
-- the counters' pictures (Codex → Blender like every icon); a coloured letter only if one is missing
local REQ_ICONS =
	{ zombies = "req_zombies", kills = "req_kills", bats = "req_bats", money = "money" }
local CARD_W, CARD_H, GAP = 290, 446, 10
local PIPS = 20

local function requirements(stat: string, current: number): { [string]: number }
	local rule = Config.trainer[stat]
	local growth = (Config.trainer.costGrowth :: number) ^ current
	local out: { [string]: number } = {}
	for name, first in pairs(rule.first) do
		out[name] = math.floor(first * growth + 0.5)
	end
	return out
end

local function progress(profile: Types.Profile, name: string): number
	if name == "money" then
		return profile.coins / Config.moneyScale
	end
	return profile.stats[name] or 0
end

-- [меню] whole numbers on both sides ("Деньги 1863 / 500"); very big ones short
local function count(n: number): string
	n = math.floor(n)
	return if n >= 100000 then Strings.big(n) else tostring(n)
end

function TrainerWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(
		parent,
		t("trainer"),
		UDim2.fromOffset(#STATS * (CARD_W + GAP) + 10, CARD_H + 56),
		onClose
	)
	Ui.titleColor(win, Ui.colors.header)
	local updates: { (Types.Profile?) -> () } = {}
	for index, stat in ipairs(STATS) do
		local color = STAT_COLORS[stat]
		local rule = Config.trainer[stat]
		local card = Kit.frame(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset((index - 1) * (CARD_W + GAP) + 4, 4),
			Kit.CARD
		)
		Kit.corner(card, 12)
		local edge = Kit.stroke(card, Kit.EDGE, 1.5)
		Kit.hoverable(card)
		-- the stat's colour washing down from the top
		local wash = Kit.frame(card, UDim2.new(1, 0, 0, 170), UDim2.new(), color)
		Kit.corner(wash, 12)
		local washFade = Instance.new("UIGradient")
		washFade.Rotation = 90
		washFade.Transparency = NumberSequence.new(0.72, 1)
		washFade.Parent = wash

		local halo = Kit.frame(card, UDim2.fromOffset(88, 88), UDim2.new(0.5, -44, 0, 8), color)
		halo.BackgroundTransparency = 0.82
		Kit.corner(halo, 44)
		local badge = Kit.image(
			card,
			Config.icons.icons["trainer_" .. stat],
			UDim2.fromOffset(74, 74),
			UDim2.new(0.5, -37, 0, 15)
		)
		badge.ZIndex = 2
		Kit.bob(badge, 3)

		local name = Kit.text(
			card,
			t("trainer_" .. stat),
			UDim2.new(1, -16, 0, 26),
			UDim2.fromOffset(8, 98),
			22,
			color,
			Kit.BOLD
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		Kit.fit(name)
		local nameEdge = Instance.new("UIStroke")
		nameEdge.Thickness = 1.5
		nameEdge.Transparency = 0.5
		nameEdge.Parent = name
		local level = Kit.text(
			card,
			"",
			UDim2.new(1, -16, 0, 18),
			UDim2.fromOffset(8, 124),
			14,
			Ui.colors.text,
			Kit.BOLD
		)
		level.TextXAlignment = Enum.TextXAlignment.Center
		-- one pip per level
		local pipW = (CARD_W - 40 - (PIPS - 1) * 2) / PIPS
		local pips: { Frame } = {}
		for i = 1, PIPS do
			local pip = Kit.frame(
				card,
				UDim2.fromOffset(pipW, 6),
				UDim2.fromOffset(20 + (i - 1) * (pipW + 2), 146),
				Kit.TRACK
			)
			Kit.corner(pip, 2)
			pips[i] = pip
		end
		local desc = Kit.text(
			card,
			t("trainer_" .. stat .. "_desc"),
			UDim2.new(1, -28, 0, 34),
			UDim2.fromOffset(14, 158),
			13,
			Ui.colors.muted
		)
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextXAlignment = Enum.TextXAlignment.Center

		-- what the level gives now → after the next one
		local bonusBox =
			Kit.frame(card, UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 194), Kit.TRACK)
		Kit.corner(bonusBox, 8)
		Kit.stroke(bonusBox, color, 1, 0.6)
		local bonus =
			Kit.text(bonusBox, "", UDim2.fromScale(1, 1), UDim2.new(), 15, Ui.colors.text, Kit.BOLD)
		bonus.TextXAlignment = Enum.TextXAlignment.Center
		Kit.fit(bonus)

		local reqTitle = Kit.text(
			card,
			"",
			UDim2.new(1, -28, 0, 20),
			UDim2.fromOffset(14, 236),
			14,
			Ui.colors.header,
			Kit.BOLD
		)
		type Row = { have: TextLabel, bar: Kit.Bar, tick: Frame, frame: Frame, done: boolean? }
		local rows: { [string]: Row } = {}
		local y = 258
		for _, req in ipairs(REQ_ORDER) do
			if not rule.first[req] then
				continue
			end
			local row =
				Kit.frame(card, UDim2.new(1, -28, 0, 40), UDim2.fromOffset(14, y), Kit.TRACK)
			row.BackgroundTransparency = 0.35
			Kit.corner(row, 8)
			local icon = REQ_ICONS[req] and Config.icons.icons[REQ_ICONS[req]]
			if icon then
				Kit.image(row, icon, UDim2.fromOffset(24, 24), UDim2.fromOffset(6, 8))
			else
				local dot = Kit.frame(row, UDim2.fromOffset(24, 24), UDim2.fromOffset(6, 8), color)
				dot.BackgroundTransparency = 0.6
				Kit.corner(dot, 12)
				local letter = Kit.text(
					dot,
					string.upper(string.sub(t("req_" .. req), 1, 2)),
					UDim2.fromScale(1, 1),
					UDim2.new(),
					11,
					Color3.new(1, 1, 1),
					Kit.BOLD
				)
				letter.TextXAlignment = Enum.TextXAlignment.Center
			end
			Kit.text(
				row,
				t("req_" .. req),
				UDim2.fromOffset(110, 18),
				UDim2.fromOffset(36, 4),
				13,
				Ui.colors.text,
				Kit.BOLD
			)
			local have = Kit.text(
				row,
				"",
				UDim2.new(1, -150, 0, 18),
				UDim2.fromOffset(114, 4),
				13,
				Ui.colors.text,
				Kit.BOLD
			)
			have.TextXAlignment = Enum.TextXAlignment.Right
			local b = Kit.bar(row, UDim2.new(1, -72, 0, 6), UDim2.fromOffset(36, 26), color)
			local tick = Kit.frame(row, UDim2.fromOffset(22, 22), UDim2.new(1, -28, 0, 9), Kit.GOOD)
			Kit.corner(tick, 11)
			local tickMark = Kit.text(
				tick,
				"✓",
				UDim2.fromScale(1, 1),
				UDim2.new(),
				14,
				Color3.new(1, 1, 1),
				Kit.BOLD
			)
			tickMark.TextXAlignment = Enum.TextXAlignment.Center
			rows[req] = { have = have, bar = b, tick = tick, frame = row }
			y += 44
		end

		local button, buttonLabel, buttonBack =
			Kit.actionButton(card, UDim2.new(1, -28, 0, 42), UDim2.new(0, 14, 1, -52), 16)
		local buttonGradient = Kit.gradient(buttonBack, color, color, 90)
		Kit.pressable(button)
		local glow = Kit.glow(button, color)
		local ready = false
		button.Activated:Connect(function()
			if ready then
				Remotes.event("TrainerUpgrade"):FireServer(stat)
			end
		end)

		local known: number? = nil
		table.insert(updates, function(p: Types.Profile?)
			local current = if p and p.trainer then (p.trainer[stat] or 0) else 0
			local max = rule.maxLevel
			level.Text = string.format(
				"%s %d %s",
				t("level_short"),
				current,
				Kit.colored("/ " .. max, Ui.colors.money)
			)
			for i, pip in ipairs(pips) do
				local lit = i <= math.round(current * PIPS / max)
				TweenService:Create(
					pip,
					TweenInfo.new(0.3),
					{ BackgroundColor3 = if lit then color else Kit.TRACK }
				):Play()
			end
			local per = math.round(rule.perLevel * 100)
			local now = t("trainer_bonus_" .. stat, current * per)
			bonus.Text = if current >= max
				then now
				else now .. "  →  " .. Kit.colored(
					t("trainer_bonus_" .. stat, (current + 1) * per),
					Kit.GOOD
				)

			local needs = requirements(stat, current)
			local total, met = 0, 0
			for req, row in pairs(rows) do
				local need = needs[req] or 0
				local have = if p then progress(p, req) else 0
				local ok = have >= need
				total += 1
				met += if ok then 1 else 0
				row.have.Text = Kit.colored(count(have), if ok then Kit.GOOD else Kit.BAD)
					.. " / "
					.. Kit.colored(count(need), Ui.colors.money)
				row.bar.set(if need > 0 then have / need else 1)
				row.bar.fill.BackgroundColor3 = if ok then Kit.GOOD else color
				if row.done ~= ok then
					row.tick.Visible = ok
					if ok and row.done ~= nil then
						Kit.pop(row.tick, 1.6)
					end
					row.done = ok
				end
			end
			reqTitle.Text = t("level_requirements", met, total)
			local maxed = current >= max
			ready = p ~= nil and not maxed and met == total
			buttonLabel.Text = string.upper(
				if maxed
					then t("level_max")
					elseif ready then t("train")
					else t("requirements_not_met")
			)
			if ready then
				buttonGradient.Color = ColorSequence.new(
					color:Lerp(Color3.new(1, 1, 1), 0.15),
					color:Lerp(Color3.new(), 0.35)
				)
				buttonLabel.TextTransparency = 0
			else
				buttonGradient.Color = ColorSequence.new(Kit.GREY, Kit.GREY:Lerp(Color3.new(), 0.3))
				buttonLabel.TextTransparency = 0.25
			end
			glow(ready)
			edge.Color = if ready then color else Kit.EDGE
			-- a level gained here: the card celebrates
			if known and current > known then
				Kit.flash(card, color)
				Kit.pop(badge, 1.3)
				Kit.floatText(
					card,
					t("level_short") .. " " .. current,
					color,
					UDim2.new(0.5, 0, 0, 120)
				)
			end
			known = current
		end)
	end
	local function refresh(p: Types.Profile?)
		profile = p
		for _, update in ipairs(updates) do
			update(p)
		end
	end
	refresh(profile)
	return win, refresh
end

return TrainerWindow
