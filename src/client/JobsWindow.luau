--!strict
-- «Работы» [O] [меню]: three professions (Каменщик — pickaxe blocks, Геодезист — shovel blocks, Мастер клинка — rats,
-- zombies, bats) level 0..50 by xp; every job level gives an upgrade point, the points go into three passive boosters
-- (+1 % each, up to 50). Interactive like the level window [владелец 27.10: «и в меню Работы тоже»]: the job cards
-- with their tool floating, the level big, the xp bar sliding and what gives xp; the points banner glows while there
-- are points; the booster cards show «×1.13 → ×1.14», their bar and a «+1» button that glows when a point can go in
-- and sinks when pressed. A job level or a booster level gained flashes its card and floats up. Built once, updated
-- in place (ProfessionService on the server owns every number).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local JobsWindow = {}

local JOBS = {
	{ id = "mason", icon = "pickaxe_diamond", color = Color3.fromRGB(255, 170, 80) },
	{ id = "surveyor", icon = "shovel_diamond", color = Color3.fromRGB(110, 195, 255) },
	{ id = "blademaster", icon = "sword_diamond", color = Color3.fromRGB(255, 105, 105) },
}
local BOOSTERS = {
	{ id = "blocks", color = Color3.fromRGB(120, 200, 255) },
	{ id = "money", color = Color3.fromRGB(110, 230, 120) },
	{ id = "mobs", color = Color3.fromRGB(255, 120, 120) },
}
local W, H = 744, 472
local CARD_W = 238

-- the xp a job needs for its next level (ProfessionService.threshold)
local function threshold(job: string, level: number): number
	local base = Config.professions.xpThresholds.base[job] or 100
	return math.floor(base * 1.6 ^ level)
end

local function card(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	color: Color3
): (Frame, UIStroke)
	local f = Kit.frame(parent, size, position, Kit.CARD)
	Kit.corner(f, 12)
	local edge = Kit.stroke(f, Kit.EDGE, 1.5)
	Kit.hoverable(f)
	local wash = Kit.frame(f, UDim2.fromScale(1, 0.7), UDim2.new(), color)
	Kit.corner(wash, 12)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.78, 1)
	fade.Parent = wash
	return f, edge
end

function JobsWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(parent, t("jobs"), UDim2.fromOffset(W, H), onClose)
	Ui.titleColor(win, Ui.colors.header)
	local updates: { (Types.Profile) -> () } = {}
	local maxLevel = Config.professions.levels :: number

	-- ------------------------------------------------------------------ the jobs
	for i, job in ipairs(JOBS) do
		local f = card(
			content,
			UDim2.fromOffset(CARD_W, 174),
			UDim2.fromOffset(4 + (i - 1) * (CARD_W + 8), 2),
			job.color
		)
		local icon = Kit.image(
			f,
			Config.icons.icons[job.icon],
			UDim2.fromOffset(60, 60),
			UDim2.fromOffset(12, 12)
		)
		Kit.bob(icon, 3, 2.2 + i * 0.3)
		local name = Kit.text(
			f,
			t("job_" .. job.id),
			UDim2.new(1, -94, 0, 24),
			UDim2.fromOffset(82, 14),
			19,
			job.color,
			Kit.BOLD
		)
		local nameEdge = Instance.new("UIStroke")
		nameEdge.Thickness = 1.5
		nameEdge.Transparency = 0.5
		nameEdge.Parent = name
		local level = Kit.text(
			f,
			"",
			UDim2.new(1, -94, 0, 28),
			UDim2.fromOffset(82, 42),
			22,
			Ui.colors.text,
			Kit.BOLD
		)
		-- [владелец 27.10: «где пишет уровень, скоро выйдет из рамки»] short «Ур.», and it shrinks rather than overflow
		Kit.fit(level)
		Kit.fit(name)
		local xpBar = Kit.bar(f, UDim2.new(1, -24, 0, 10), UDim2.fromOffset(12, 92), job.color)
		local xp = Kit.text(
			f,
			"",
			UDim2.new(1, -24, 0, 18),
			UDim2.fromOffset(12, 106),
			13,
			Ui.colors.text,
			Kit.BOLD
		)
		local how = Kit.text(
			f,
			t("jobs_how_" .. job.id),
			UDim2.new(1, -24, 0, 36),
			UDim2.fromOffset(12, 132),
			12,
			Ui.colors.muted
		)
		how.TextWrapped = true
		how.TextYAlignment = Enum.TextYAlignment.Top
		local known: number? = nil
		table.insert(updates, function(p: Types.Profile)
			local pro = p.professions
			local lv = pro.level[job.id] or 0
			level.Text = string.format(
				"%s %d %s",
				t("level_short"),
				lv,
				Kit.colored("/ " .. maxLevel, Ui.colors.muted)
			)
			if lv >= maxLevel then
				xpBar.set(1)
				xp.Text = t("level_max")
			else
				local need = threshold(job.id, lv)
				local have = pro.xp[job.id] or 0
				xpBar.set(have / need)
				xp.Text = t("jobs_xp", Strings.big(have), Strings.big(need))
			end
			if known and lv > known then
				Kit.flash(f, job.color)
				Kit.pop(icon, 1.35)
				Kit.floatText(f, t("level_short") .. " " .. lv, job.color, UDim2.new(0.5, 0, 0, 60))
			end
			known = lv
		end)
	end

	-- ------------------------------------------------------------------ the points
	local banner = Kit.frame(content, UDim2.new(1, -8, 0, 58), UDim2.fromOffset(4, 182), Kit.CARD)
	Kit.corner(banner, 12)
	Kit.stroke(banner, Kit.EDGE, 1.5)
	local bannerGlow = Kit.glow(banner, Ui.colors.level)
	local star = Kit.image(
		banner,
		Config.icons.icons["ancient_star"],
		UDim2.fromOffset(40, 40),
		UDim2.fromOffset(12, 9)
	)
	Kit.text(
		banner,
		t("jobs_points"),
		UDim2.fromOffset(300, 22),
		UDim2.fromOffset(62, 8),
		17,
		Ui.colors.text,
		Kit.BOLD
	)
	Kit.text(
		banner,
		t("jobs_points_hint"),
		UDim2.fromOffset(460, 18),
		UDim2.fromOffset(62, 31),
		12,
		Ui.colors.muted
	)
	local points = Kit.text(
		banner,
		"",
		UDim2.fromOffset(120, 40),
		UDim2.new(1, -134, 0, 9),
		32,
		Ui.colors.level,
		Kit.BOLD
	)
	points.TextXAlignment = Enum.TextXAlignment.Right
	local knownPoints: number? = nil
	table.insert(updates, function(p: Types.Profile)
		local n = p.professions.points
		points.Text = tostring(n)
		points.TextColor3 = if n > 0 then Ui.colors.level else Ui.colors.muted
		star.ImageTransparency = if n > 0 then 0 else 0.6
		bannerGlow(n > 0)
		if knownPoints and n > knownPoints then
			Kit.pop(points, 1.5)
			Kit.pop(star, 1.4)
		end
		knownPoints = n
	end)

	-- ------------------------------------------------------------------ the boosters
	Kit.text(
		content,
		t("jobs_boosters"),
		UDim2.fromOffset(300, 20),
		UDim2.fromOffset(8, 246),
		14,
		Ui.colors.header,
		Kit.BOLD
	)
	local upgradeMax = Config.professions.upgrades.maxLevel :: number
	for i, booster in ipairs(BOOSTERS) do
		local f = card(
			content,
			UDim2.fromOffset(CARD_W, 154),
			UDim2.fromOffset(4 + (i - 1) * (CARD_W + 8), 268),
			booster.color
		)
		local icon = Kit.image(
			f,
			Config.icons.icons["booster_" .. booster.id],
			UDim2.fromOffset(52, 52),
			UDim2.fromOffset(12, 10)
		)
		local boosterName = Kit.text(
			f,
			t("booster_" .. booster.id),
			UDim2.new(1, -80, 0, 22),
			UDim2.fromOffset(72, 12),
			16,
			booster.color,
			Kit.BOLD
		)
		local mult = Kit.text(
			f,
			"",
			UDim2.new(1, -80, 0, 22),
			UDim2.fromOffset(72, 36),
			16,
			Ui.colors.text,
			Kit.BOLD
		)
		Kit.fit(boosterName)
		Kit.fit(mult)
		local b = Kit.bar(f, UDim2.new(1, -24, 0, 8), UDim2.fromOffset(12, 70), booster.color)
		local count = Kit.text(
			f,
			"",
			UDim2.new(1, -24, 0, 16),
			UDim2.fromOffset(12, 82),
			12,
			Ui.colors.muted,
			Kit.BOLD
		)
		local button, buttonLabel, buttonBack =
			Kit.actionButton(f, UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 1, -48), 18)
		local buttonGradient = Kit.gradient(buttonBack, booster.color, booster.color, 90)
		Kit.pressable(button)
		local glow = Kit.glow(button, booster.color)
		local ready = false
		button.Activated:Connect(function()
			if ready then
				Remotes.event("SpendPoint"):FireServer(booster.id)
			end
		end)
		local step = (Config.professions.upgrades :: any)[booster.id] :: number
		local known: number? = nil
		table.insert(updates, function(p: Types.Profile)
			local lv = (p.professions.upgrades :: any)[booster.id] :: number
			local function x(level: number): string
				return string.format("×%.2f", 1 + level * step)
			end
			mult.Text = if lv >= upgradeMax
				then x(lv)
				else x(lv) .. "  →  " .. Kit.colored(x(lv + 1), Kit.GOOD)
			b.set(lv / upgradeMax)
			count.Text = string.format("%d / %d", lv, upgradeMax)
			ready = p.professions.points > 0 and lv < upgradeMax
			buttonLabel.Text = if lv >= upgradeMax
				then string.upper(t("level_max"))
				elseif ready then string.format("+%d%%", math.round(step * 100))
				else string.upper(t("jobs_no_points"))
			if ready then
				buttonGradient.Color = ColorSequence.new(
					booster.color:Lerp(Color3.new(1, 1, 1), 0.1),
					booster.color:Lerp(Color3.new(), 0.4)
				)
				buttonLabel.TextTransparency = 0
			else
				buttonGradient.Color = ColorSequence.new(Kit.GREY, Kit.GREY:Lerp(Color3.new(), 0.3))
				buttonLabel.TextTransparency = 0.3
			end
			glow(ready)
			if known and lv > known then
				Kit.flash(f, booster.color)
				Kit.pop(icon, 1.35)
				Kit.floatText(f, x(lv), booster.color, UDim2.new(0.5, 0, 0, 50))
			end
			known = lv
		end)
	end

	local function refresh(p: Types.Profile?)
		profile = p
		if not p then
			return
		end
		for _, update in ipairs(updates) do
			update(p)
		end
	end
	refresh(profile)
	return win, refresh
end

return JobsWindow
