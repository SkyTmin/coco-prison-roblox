--!strict
-- "Тренер" window of the original (NPC-MENU-RECOVERY npc-01): three dark cards — Сила / Ловкость /
-- Нужды — each with a round blue badge, coloured name, "Ур. 0 / 20", a description, a "Требования"
-- inset listing counters "have / need" (green when met, red otherwise) and a button: grey
-- "Требования не выполнены" or blue "Прокачать". Requirement growth per level is ours [решение].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local TrainerWindow = {}

local STATS = { "strength", "agility", "needs" }
local NAME_COLORS = { strength = Ui.colors.red, agility = Ui.colors.cyan, needs = Ui.colors.header }
local REQ_ORDER = { "zombies", "kills", "bats", "money" }
local CARD_W, CARD_H, GAP = 300, 400, 10

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
		local card = Ui.panel(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset((index - 1) * (CARD_W + GAP) + 4, 4)
		)
		local badge = Instance.new("ImageLabel")
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.Size = UDim2.fromOffset(96, 96)
		badge.Position = UDim2.new(0.5, 0, 0, 12)
		badge.BackgroundTransparency = 1
		badge.ScaleType = Enum.ScaleType.Fit
		badge.ResampleMode = Enum.ResamplerMode.Pixelated
		badge.Image = Config.icons.icons["trainer_" .. stat] or ""
		badge.Parent = card
		local name = Ui.label(
			card,
			t("trainer_" .. stat),
			UDim2.new(1, -16, 0, 22),
			UDim2.fromOffset(8, 112),
			16,
			NAME_COLORS[stat]
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local level = Ui.rich(card, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 134), 14)
		level.TextXAlignment = Enum.TextXAlignment.Center
		local desc = Ui.label(
			card,
			t("trainer_" .. stat .. "_desc"),
			UDim2.new(1, -24, 0, 44),
			UDim2.fromOffset(12, 160),
			13,
			Ui.colors.muted
		)
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		local box = Ui.inset(card, UDim2.new(1, -24, 0, 120), UDim2.fromOffset(12, 212))
		Ui.label(
			box,
			t("requirements"),
			UDim2.new(1, -16, 0, 22),
			UDim2.fromOffset(8, 4),
			14,
			Ui.colors.muted
		)
		local lines: { [string]: TextLabel } = {}
		local y = 28
		for _, req in ipairs(REQ_ORDER) do
			if Config.trainer[stat].first[req] then
				lines[req] = Ui.rich(box, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, y), 13)
				y += 24
			end
		end
		local button = Ui.button(
			card,
			"",
			UDim2.new(1, -24, 0, 38),
			UDim2.new(0, 12, 1, -50),
			Ui.colors.buttonGrey
		)
		button.Activated:Connect(function()
			if button.Interactable then
				Remotes.event("TrainerUpgrade"):FireServer(stat)
			end
		end)
		table.insert(updates, function(p: Types.Profile?)
			local current = if p and p.trainer then (p.trainer[stat] or 0) else 0
			local max = Config.trainer[stat].maxLevel
			level.Text = string.format(
				'%s %d <font color="%s">/ %d</font>',
				t("level_short"),
				current,
				Ui.hex(Ui.colors.money),
				max
			)
			local met = p ~= nil and current < max
			local needs = requirements(stat, current)
			for req, label in pairs(lines) do
				local need = needs[req] or 0
				local have = if p then progress(p, req) else 0
				local ok = have >= need
				met = met and ok
				-- [меню] whole numbers on both sides: "Деньги 1863 / 500"
				local haveText = tostring(math.floor(have))
				local needText = tostring(need)
				label.Text = string.format(
					'%s<font color="%s">%s</font>  <font color="%s">%s</font> / <font color="%s">%s</font>%s',
					if req == "money" then "$ " else "",
					Ui.hex(Ui.colors.muted),
					t("req_" .. req),
					Ui.hex(if ok then Ui.colors.money else Ui.colors.red),
					haveText,
					Ui.hex(Ui.colors.money),
					needText,
					if ok then " ✓" else ""
				)
			end
			button.Text = if current >= max
				then t("upgrade_max")
				elseif met then t("train")
				else t("requirements_not_met")
			button.BackgroundColor3 = if met then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			button.Interactable = met
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
