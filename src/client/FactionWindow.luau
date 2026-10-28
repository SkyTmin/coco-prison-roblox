--!strict
-- The «Фракции» window [клиент: fraction.gui.*]: four cards — a banner in the faction colour, the name, the
-- tagline («Описание фракции»), how many of its players are on the server, and «Выбрать» (or «Ваша
-- фракция» on your own card). Below: your faction, «Смен фракций» and «Покинуть фракцию» for leaveCost $
-- [меню], pressed twice to confirm. The server decides everything (FactionService).
-- Under it the Дворы [клиент fraction.gui.*]: «Захваченные точки N/4», «Взято точек», a card per point (owner, the
-- hold left in minutes «13 мин.» [вики], or the capture race) and the button to the Дворы (/warzone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Warzone = require(Shared.Warzone)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local FactionWindow = {}

local CARD_W, CARD_H, GAP = 220, 330, 10
local POINTS_H = 110 -- the Дворы block under the footer

local function members(id: string): number
	local n = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Faction") == id then
			n += 1
		end
	end
	return n
end

function FactionWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local list = Config.factions.list
	local win, content = createWindow(
		parent,
		t("factions_title"),
		UDim2.fromOffset(#list * (CARD_W + GAP) + 10, CARD_H + 110 + POINTS_H),
		onClose
	)
	Ui.titleColor(win, Ui.colors.header)
	local updates: { (Types.Profile?) -> () } = {}
	for index, faction in ipairs(list) do
		local color = Config.factionColor(faction.id)
		local card = Ui.panel(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset((index - 1) * (CARD_W + GAP) + 4, 4)
		)
		-- the banner: cloth in the faction colour with a dark stripe and a diamond
		local cloth = Instance.new("Frame")
		cloth.AnchorPoint = Vector2.new(0.5, 0)
		cloth.Size = UDim2.fromOffset(56, 84)
		cloth.Position = UDim2.new(0.5, 0, 0, 14)
		cloth.BackgroundColor3 = color
		cloth.BorderSizePixel = 0
		cloth.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(40, 30, 20)
		stroke.Thickness = 2
		stroke.Parent = cloth
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 12, 0, 6)
		bar.Position = UDim2.fromOffset(-6, -6)
		bar.BackgroundColor3 = Color3.fromRGB(90, 60, 35)
		bar.BorderSizePixel = 0
		bar.Parent = cloth
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(1, 0, 0, 8)
		stripe.Position = UDim2.fromOffset(0, 14)
		stripe.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
		stripe.BorderSizePixel = 0
		stripe.Parent = cloth
		local diamond = Instance.new("Frame")
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Size = UDim2.fromOffset(20, 20)
		diamond.Position = UDim2.fromScale(0.5, 0.62)
		diamond.Rotation = 45
		diamond.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
		diamond.BorderSizePixel = 0
		diamond.Parent = cloth
		local name = Ui.label(
			card,
			t("faction_" .. faction.id),
			UDim2.new(1, -16, 0, 24),
			UDim2.fromOffset(8, 110),
			18,
			if faction.id == "latino" then Color3.fromRGB(205, 120, 80) else color
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local desc = Ui.label(
			card,
			t("faction_" .. faction.id .. "_desc"),
			UDim2.new(1, -24, 0, 92),
			UDim2.fromOffset(12, 140),
			13,
			Ui.colors.muted
		)
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		local count = Ui.label(
			card,
			"",
			UDim2.new(1, -24, 0, 20),
			UDim2.fromOffset(12, 236),
			13,
			Ui.colors.text
		)
		count.TextXAlignment = Enum.TextXAlignment.Center
		local button = Ui.button(
			card,
			"",
			UDim2.new(1, -24, 0, 38),
			UDim2.new(0, 12, 1, -50),
			Ui.colors.buttonBlue
		)
		button.Activated:Connect(function()
			if button.Interactable then
				Remotes.event("FactionChoose"):FireServer(faction.id)
			end
		end)
		table.insert(updates, function(p: Types.Profile?)
			count.Text = t("faction_members", members(faction.id))
			local mine = p ~= nil and p.faction == faction.id
			local inAny = p ~= nil and p.faction ~= nil
			button.Text = if mine then t("faction_yours") else t("faction_select")
			button.Interactable = not inAny
			button.BackgroundColor3 = if mine
				then Ui.colors.buttonGreen
				elseif inAny then Ui.colors.buttonGrey
				else Ui.colors.buttonBlue
			card.BackgroundColor3 = if mine
				then Ui.colors.panel:Lerp(color, 0.12)
				else Ui.colors.panel
		end)
	end
	-- the footer: your faction, the number of changes, leaving
	local footerY = CARD_H + 14
	local yours = Ui.rich(
		content,
		"",
		UDim2.fromOffset(#list * (CARD_W + GAP) - 260, 22),
		UDim2.fromOffset(8, footerY),
		15
	)
	local changes = Ui.label(
		content,
		"",
		UDim2.fromOffset(#list * (CARD_W + GAP) - 260, 20),
		UDim2.fromOffset(8, footerY + 24),
		13,
		Ui.colors.muted
	)
	local leaveCost = Strings.money(math.floor(Config.factions.leaveCost * Config.moneyScale + 0.5))
	local leave = Ui.button(
		content,
		t("faction_leave", leaveCost),
		UDim2.fromOffset(240, 38),
		UDim2.new(1, -248, 0, footerY + 4),
		Ui.colors.close
	)
	local armedAt = -math.huge
	leave.Activated:Connect(function()
		if not leave.Interactable then
			return
		end
		if os.clock() - armedAt < 4 then
			armedAt = -math.huge
			leave.Text = t("faction_leave", leaveCost)
			Remotes.event("FactionLeave"):FireServer()
		else
			armedAt = os.clock() -- [клиент] «Вы действительно хотите покинуть фракцию за %s?»
			leave.Text = t("faction_leave_confirm", leaveCost)
		end
	end)
	-- the Дворы: points held, points taken, a card per point, the way there
	local pointsY = footerY + 56
	local width = #list * (CARD_W + GAP) - 2
	local heldLabel =
		Ui.rich(content, "", UDim2.fromOffset(width - 190, 22), UDim2.fromOffset(8, pointsY), 15)
	local go = Ui.button(
		content,
		t("warzone_go"),
		UDim2.fromOffset(170, 26),
		UDim2.new(1, -178, 0, pointsY - 2),
		Ui.colors.buttonBlue
	)
	go.Activated:Connect(function()
		Remotes.event("Teleport"):FireServer(Warzone.LOCATION)
	end)
	local chipW = math.floor((width - 4 - (#Warzone.points - 1) * 8) / #Warzone.points)
	local chips: { { title: TextLabel, status: TextLabel, card: Frame } } = {}
	for i, point in ipairs(Warzone.points) do
		local chip = Ui.card(
			content,
			UDim2.fromOffset(chipW, 70),
			UDim2.fromOffset(4 + (i - 1) * (chipW + 8), pointsY + 28)
		)
		local title = Ui.label(
			chip,
			t("warzone_point_" .. point.id),
			UDim2.new(1, -12, 0, 20),
			UDim2.fromOffset(6, 4),
			14,
			Ui.colors.header
		)
		Ui.label(
			chip,
			t("warzone_bonus_" .. point.id, tostring(Warzone.cfg.bonus)),
			UDim2.new(1, -12, 0, 16),
			UDim2.fromOffset(6, 24),
			12,
			Ui.colors.money
		).TextTruncate =
			Enum.TextTruncate.AtEnd
		local status = Ui.rich(chip, "", UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 42), 12)
		status.TextTruncate = Enum.TextTruncate.AtEnd
		chips[i] = { title = title, status = status, card = chip }
	end
	local shownProfile: Types.Profile? = profile
	local function refreshPoints()
		local p = shownProfile
		local now = workspace:GetServerTimeNow()
		local mine = if p then p.faction else nil
		heldLabel.Text = string.format(
			'%s: <font color="%s">%d/%d</font>   %s: <font color="%s">%d</font>',
			t("warzone_held"),
			Ui.hex(Ui.colors.header),
			Warzone.heldBy(mine, now),
			#Warzone.points,
			t("warzone_taken"),
			Ui.hex(Ui.colors.header),
			if p then p.stats.warzonePoints or 0 else 0
		)
		for i, point in ipairs(Warzone.points) do
			local chip = chips[i]
			local state = Warzone.state(point.id, now)
			local owner = state.owner
			if owner then
				-- [вики] the hold left «13 мин.» (fraction.gui.point_time)
				local minutes = math.max(1, math.ceil((state.untilAt - now) / 60))
				chip.status.Text = string.format(
					'<font color="%s">%s</font> · %s',
					Ui.hex(Config.factionColor(owner)),
					t("faction_" .. owner),
					t("warzone_minutes", minutes)
				)
			elseif state.leader then
				chip.status.Text = string.format(
					'<font color="%s">%s</font> %d/%d',
					Ui.hex(Config.factionColor(state.leader)),
					t("faction_" .. state.leader),
					state.lead,
					state.need
				)
			else
				chip.status.Text = string.format(
					'<font color="%s">%s</font>',
					Ui.hex(Ui.colors.money),
					t("warzone_free")
				)
			end
			chip.card.BackgroundColor3 = if owner and owner == mine
				then Ui.colors.panel:Lerp(Config.factionColor(owner), 0.15)
				else Ui.colors.panel
		end
	end
	-- the timers run on their own (the window is refreshed only when the profile changes)
	task.spawn(function()
		while win.Parent do
			refreshPoints()
			task.wait(1)
		end
	end)

	local function refresh(p: Types.Profile?)
		shownProfile = p
		refreshPoints()
		for _, update in ipairs(updates) do
			update(p)
		end
		local id = if p then p.faction else nil
		yours.Text = string.format(
			'%s: <font color="%s">%s</font>',
			t("faction_yours"),
			Ui.hex(if id then Config.factionColor(id) else Ui.colors.gray),
			t("faction_" .. (id or "none"))
		)
		changes.Text = t("faction_changes")
			.. ": "
			.. tostring(if p then p.factionChanges or 0 else 0)
		leave.Visible = id ~= nil
		leave.Interactable = id ~= nil
	end
	refresh(profile)
	return win, refresh
end

return FactionWindow
