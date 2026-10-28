--!strict
-- «Банда» [R] [клиент gang.gui.*; docs/research/remaining-features-design.md §1.6]: tabs Обзор (emblem, «name #TAG»,
-- members / slots, gang points, treasury, leave), Участники (roles; kick / promote / demote / make leader as the
-- role allows), Поручения (daily / weekly / goal cards with progress and reward), Улучшения («Прокачки» / «Перки»:
-- level, now → next, buy), Казна (deposit / withdraw, history), Настройки (PvP, colour, emblem, description,
-- disband). Without a gang: Создание (the form with a preview) and Приглашения. The server decides everything
-- (GangService); this window sends GangAction intents and draws the last GangState / GangInvites. Rules: Shared/Gangs.
-- A page is rebuilt when the tab or the state changes; typed text survives in `draft`; timers tick in place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local GangWindow = {}

local W, H = 720, 500
local TAB_H = 30
local GOLD = Color3.fromRGB(255, 200, 60)

local state: any = nil -- the last GangState: a view of the gang, false = no gang, nil = not known yet
local invites: { any } = {}
local onChange: (() -> ())? = nil
local listening = false
local draft = {
	name = "",
	tag = "",
	desc = "",
	color = 1,
	icon = 1,
	amount = "",
	invite = "",
	settingsDesc = nil :: string?,
}

function GangWindow.listen()
	if listening then
		return
	end
	listening = true
	Remotes.event("GangState").OnClientEvent:Connect(function(view: any)
		state = if typeof(view) == "table" then view else false
		if onChange then
			onChange()
		end
	end)
	Remotes.event("GangInvites").OnClientEvent:Connect(function(list: any)
		invites = if typeof(list) == "table" then list else {}
		if onChange then
			onChange()
		end
	end)
end

local function send(op: string, arg: any?)
	Remotes.event("GangAction"):FireServer(op, arg)
end

local function textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Size, box.Position = size, position
	box.BackgroundColor3 = Ui.colors.inset
	box.BorderSizePixel = 0
	box.Font = Ui.font
	box.TextSize = 14
	box.TextColor3 = Ui.colors.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Ui.colors.muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = box
	Kit.corner(box, 4)
	Kit.stroke(box, Ui.colors.border, 1)
	box.Parent = parent
	return box
end

-- a button that asks for a second press before it acts (leave, disband, make leader)
local function confirmButton(
	parent: Instance,
	text: string,
	confirmText: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	act: () -> ()
): TextButton
	local button = Ui.button(parent, text, size, position, color)
	button.TextSize = 14
	local armedUntil = 0
	button.Activated:Connect(function()
		if os.clock() < armedUntil then
			armedUntil = 0
			button.Text = text
			act()
			return
		end
		armedUntil = os.clock() + 3
		button.Text = confirmText
		task.delay(3, function()
			if button.Parent and os.clock() >= armedUntil then
				button.Text = text
			end
		end)
	end)
	return button
end

local function scroller(parent: Instance, size: UDim2, position: UDim2, gap: number): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Size, list.Position = size, position
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Ui.colors.border
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

function GangWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	GangWindow.listen()
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local icons = Config.icons.icons
	local cfg = Gangs.cfg
	local current: Types.Profile? = profile
	local win, content = createWindow(parent, T("gangs_title"), UDim2.fromOffset(W, H), function()
		onChange = nil
		onClose()
	end)
	win.Name = "Window_Gang"
	Ui.titleColor(win, Ui.colors.header)
	local inner = W - 12
	local pageH = H - 46 - TAB_H - 6

	local tabBar = Kit.frame(content, UDim2.new(1, 0, 0, TAB_H), UDim2.new(), Color3.new())
	tabBar.BackgroundTransparency = 1
	local page =
		Kit.frame(content, UDim2.new(1, 0, 0, pageH), UDim2.fromOffset(0, TAB_H + 6), Color3.new())
	page.BackgroundTransparency = 1

	local tab = ""
	local upgradesTab = "boosts"
	local dirty = false -- a redraw waits for the text box being typed in to lose focus
	local tickers: { () -> () } = {}
	local draw: () -> ()

	local function nowServer(): number
		return workspace:GetServerTimeNow()
	end

	local function label(
		parentFrame: Instance,
		text: string,
		size: UDim2,
		position: UDim2,
		textSize: number?,
		color: Color3?
	): TextLabel
		local l =
			Kit.text(parentFrame, text, size, position, textSize or 14, color or Ui.colors.text)
		return l
	end

	local function iconOr(id: string, fallback: string?): string
		return icons[id] or (fallback and icons[fallback]) or ""
	end

	local function myRole(): string?
		return if state then state.you else nil
	end

	local function nameTag(view: any): string
		return string.format(
			'<font color="%s">%s</font>',
			Ui.hex(Gangs.color(view.color)),
			T("gang_format", view.name, view.tag)
		)
	end

	-- ── pages ──────────────────────────────────────────────────────────────────────────────────────────────────

	local function drawOverview()
		local view = state
		local head = Ui.card(page, UDim2.new(1, -8, 0, 92), UDim2.fromOffset(4, 0))
		local emblem = Kit.image(
			head,
			Gangs.emblem(view.icon),
			UDim2.fromOffset(72, 72),
			UDim2.fromOffset(10, 10)
		)
		emblem.ResampleMode = Enum.ResamplerMode.Pixelated
		Kit.bob(emblem, 2, 2.8)
		local title = label(
			head,
			nameTag(view),
			UDim2.new(1, -110, 0, 30),
			UDim2.fromOffset(94, 8),
			22,
			Ui.colors.white
		)
		title.Font = Kit.BOLD
		Kit.fit(title)
		label(
			head,
			view.desc or "",
			UDim2.new(1, -110, 0, 22),
			UDim2.fromOffset(94, 38),
			14,
			Ui.colors.muted
		)
		label(
			head,
			T("gang_role_" .. (myRole() or "member")),
			UDim2.new(1, -110, 0, 20),
			UDim2.fromOffset(94, 62),
			14,
			GOLD
		)

		local rows = {
			{
				icons.gang_members or icons.hud_faction,
				T("gang_members_count", Gangs.memberCount(view), Gangs.slots(view)),
			},
			{ icons.gang_points or icons.ancient_star, T("gang_points", view.points or 0) },
			{
				icons.gang_treasury or icons.money_bag,
				T(
					"gang_treasury_line",
					Strings.money(view.treasury or 0),
					Strings.money(Gangs.treasuryCap(view))
				),
			},
			{ icons.hud_level, T("gang_level_avg", math.floor(Gangs.averageLevel(view) + 0.5)) },
			{
				icons.sword_diamond,
				T(if view.pvp then "gang_pvp_state_on" else "gang_pvp_state_off"),
			},
		}
		for i, row in ipairs(rows) do
			local card = Ui.card(
				page,
				UDim2.fromOffset(inner / 2 - 10, 40),
				UDim2.fromOffset(4 + ((i - 1) % 2) * (inner / 2 - 2), 100 + ((i - 1) // 2) * 46)
			)
			local img = Kit.image(card, row[1], UDim2.fromOffset(30, 30), UDim2.fromOffset(6, 5))
			img.ResampleMode = Enum.ResamplerMode.Pixelated
			local l = label(
				card,
				row[2],
				UDim2.new(1, -48, 1, 0),
				UDim2.fromOffset(42, 0),
				15,
				Ui.colors.white
			)
			Kit.fit(l)
		end
		label(
			page,
			T("gang_points_hint"),
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(6, 240),
			13,
			Ui.colors.muted
		)

		-- invite by name (deputies and the leader)
		if Gangs.can(myRole() :: any, "invite") then
			local box = textBox(
				page,
				T("gang_invite_player_hint"),
				UDim2.fromOffset(240, 34),
				UDim2.fromOffset(4, pageH - 40)
			)
			box.Text = draft.invite
			box:GetPropertyChangedSignal("Text"):Connect(function()
				draft.invite = box.Text
			end)
			local inviteButton = Ui.button(
				page,
				T("gang_invite"),
				UDim2.fromOffset(130, 34),
				UDim2.fromOffset(250, pageH - 40),
				Ui.colors.buttonGreen
			)
			inviteButton.TextSize = 15
			inviteButton.Activated:Connect(function()
				if box.Text ~= "" then
					send("invite", box.Text)
					draft.invite = ""
					box.Text = ""
				end
			end)
		end
		-- «Домой» = /gang home [дизайн §1.5]: the trip to the gang's own house on the База банды (GangHouseService)
		local home = Ui.button(
			page,
			T("gang_home"),
			UDim2.fromOffset(190, 34),
			UDim2.new(1, -194, 0, pageH - 80),
			Ui.colors.buttonBlue
		)
		home.TextSize = 15
		home.Activated:Connect(function()
			Remotes.event("GangHome"):FireServer()
		end)
		if myRole() ~= "leader" then
			confirmButton(
				page,
				T("gang_leave"),
				T("gang_confirm"),
				UDim2.fromOffset(190, 34),
				UDim2.new(1, -194, 0, pageH - 40),
				Ui.colors.close,
				function()
					send("leave")
				end
			)
		end
	end

	local function drawMembers()
		local view = state
		local list = scroller(page, UDim2.fromScale(1, 1), UDim2.new(), 6)
		local entries = {}
		for key, m in pairs(view.members) do
			table.insert(entries, { id = tonumber(key), m = m })
		end
		table.sort(entries, function(a, b)
			local ra, rb = Gangs.ROLE_RANK[a.m.role] or 0, Gangs.ROLE_RANK[b.m.role] or 0
			if ra ~= rb then
				return ra > rb
			end
			return tostring(a.m.name) < tostring(b.m.name)
		end)
		local role = myRole() :: any
		local me = game:GetService("Players").LocalPlayer.UserId
		for i, entry in ipairs(entries) do
			local m = entry.m
			local card = Ui.card(list, UDim2.new(1, -10, 0, 44), UDim2.new())
			card.LayoutOrder = i
			local roleColor = if m.role == "leader"
				then GOLD
				elseif m.role == "deputy" then Ui.colors.level
				else Ui.colors.muted
			label(
				card,
				string.format(
					'%s  <font color="%s">%s</font>',
					m.name,
					Ui.hex(roleColor),
					T("gang_role_" .. m.role)
				),
				UDim2.fromOffset(300, 44),
				UDim2.fromOffset(10, 0),
				15,
				Ui.colors.white
			)
			label(
				card,
				T("gang_level_of", m.level or 1, Config.levels.maxLevel),
				UDim2.fromOffset(90, 44),
				UDim2.fromOffset(300, 0),
				13,
				Ui.colors.muted
			)
			if entry.id == me then
				continue
			end
			local x = -4
			local function action(text: string, color: Color3, op: string, confirm: boolean?)
				x -= 112
				local size, pos = UDim2.fromOffset(108, 32), UDim2.new(1, x, 0, 6)
				if confirm then
					confirmButton(card, text, T("gang_confirm"), size, pos, color, function()
						send(op, entry.id)
					end)
				else
					local b = Ui.button(card, text, size, pos, color)
					b.TextSize = 13
					b.Activated:Connect(function()
						send(op, entry.id)
					end)
				end
			end
			if Gangs.canKick(role, m.role) then
				action(T("gang_kick"), Ui.colors.close, "kick", true)
			end
			if role == "leader" then
				if m.role == "member" then
					action(T("gang_promote"), Ui.colors.buttonBlue, "promote")
				elseif m.role == "deputy" then
					action(T("gang_demote"), Ui.colors.buttonGrey, "demote")
				end
				action(T("gang_transfer"), Color3.fromRGB(150, 110, 20), "transfer", true)
			end
		end
	end

	local function questCard(parentFrame: Instance, quest: any, order: number)
		local card = Ui.card(parentFrame, UDim2.new(1, -10, 0, 58), UDim2.new())
		card.LayoutOrder = order
		local kindIcon = ({
			dig = icons.pickaxe_diamond,
			mobs = icons.sword_diamond,
			boss = icons.req_kills,
			sell = icons.money,
			pvp = icons.hud_kd,
		} :: any)[quest.kind]
		Kit.image(
			card,
			kindIcon or icons.gang_quests,
			UDim2.fromOffset(36, 36),
			UDim2.fromOffset(8, 11)
		).ResampleMode =
			Enum.ResamplerMode.Pixelated
		label(
			card,
			T("gang_quest_" .. quest.kind, Strings.big(quest.target)),
			UDim2.fromOffset(330, 24),
			UDim2.fromOffset(52, 4),
			15,
			Ui.colors.white
		).Font =
			Kit.BOLD
		local bar = Kit.bar(
			card,
			UDim2.fromOffset(330, 12),
			UDim2.fromOffset(52, 34),
			if quest.done then Kit.GOOD else GOLD
		)
		bar.set(math.clamp((quest.progress or 0) / math.max(quest.target, 1), 0, 1))
		local right = if quest.done
			then T("gang_quest_done")
			else string.format(
				"%s / %s",
				Strings.big(quest.progress or 0),
				Strings.big(quest.target)
			)
		label(
			card,
			right,
			UDim2.fromOffset(120, 20),
			UDim2.fromOffset(390, 30),
			13,
			if quest.done then Kit.GOOD else Ui.colors.muted
		)
		local qcfg = cfg.quests
		local rewardText = T(
			"gang_quest_reward",
			Gangs.questPoints(quest.type),
			tostring(qcfg.booster.mult),
			qcfg.booster.minutes
		)
		local r =
			label(card, rewardText, UDim2.new(1, -520, 0, 44), UDim2.fromOffset(512, 7), 13, GOLD)
		r.TextWrapped = true
	end

	local function drawQuests()
		local view = state
		local openAt = Gangs.questsOpenAt(view)
		local quests = view.quests
		if nowServer() < openAt or not quests then
			local soon = label(
				page,
				"",
				UDim2.new(1, 0, 0, 40),
				UDim2.new(0, 0, 0.5, -20),
				17,
				Ui.colors.muted
			)
			soon.TextXAlignment = Enum.TextXAlignment.Center
			table.insert(tickers, function()
				soon.Text = T("gang_quests_soon", Gangs.clock(math.max(0, openAt - nowServer())))
			end)
			return
		end
		local list = scroller(page, UDim2.fromScale(1, 1), UDim2.new(), 6)
		local order = 0
		for _, questType in ipairs(Gangs.QUEST_TYPES) do
			order += 1
			local header =
				label(list, "", UDim2.new(1, -10, 0, 22), UDim2.new(), 15, Ui.colors.header)
			header.LayoutOrder = order
			header.Font = Kit.BOLD
			local title = T("gang_quest_" .. questType)
			if questType == "goal" then
				header.Text = title
			else
				table.insert(tickers, function()
					local t = nowServer()
					local nextAt = if questType == "daily"
						then Gangs.nextDayAt(t)
						else Gangs.nextWeekAt(t)
					header.Text = title
						.. '  <font color="'
						.. Ui.hex(Ui.colors.muted)
						.. '">'
						.. T("gang_quests_refresh", Gangs.clock(nextAt - t))
						.. "</font>"
				end)
			end
			for _, quest in ipairs(quests.list) do
				if quest.type == questType then
					order += 1
					questCard(list, quest, order)
				end
			end
		end
	end

	local function upgradeDesc(u: Gangs.Upgrade, level: number): string
		local fake: any = { upgrades = { [u.id] = level }, members = {} }
		if u.id == "members" then
			return T("gang_up_desc_members", tostring(Gangs.slots(fake)))
		elseif u.id == "treasury" then
			return T("gang_up_desc_treasury", Strings.money(Gangs.treasuryCap(fake)))
		elseif u.id == "chests" then
			return T("gang_up_desc_chests", tostring(level * (u.effect or 0)))
		elseif u.currency == "treasury" then
			return T("gang_up_desc_" .. u.id)
		end
		local pct = Gangs.perk(fake, u.id) * 100
		return T("gang_up_desc_" .. u.id, string.format("%g", math.floor(pct * 10 + 0.5) / 10))
	end

	local function drawUpgrades()
		local view = state
		local role = myRole() :: any
		for i, which in ipairs({ "boosts", "perks" }) do
			local b = Ui.button(
				page,
				T("gang_upgrades_" .. which),
				UDim2.fromOffset(130, 26),
				UDim2.fromOffset(4 + (i - 1) * 136, 0),
				if upgradesTab == which then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			)
			b.TextSize = 14
			b.Activated:Connect(function()
				upgradesTab = which
				draw()
			end)
		end
		label(
			page,
			T("gang_points", view.points or 0),
			UDim2.fromOffset(220, 26),
			UDim2.new(1, -440, 0, 0),
			14,
			GOLD
		)
		label(
			page,
			T(
				"gang_treasury_line",
				Strings.money(view.treasury or 0),
				Strings.money(Gangs.treasuryCap(view))
			),
			UDim2.fromOffset(220, 26),
			UDim2.new(1, -220, 0, 0),
			14,
			Ui.colors.money
		)
		local list = Instance.new("ScrollingFrame")
		list.Size = UDim2.new(1, 0, 1, -32)
		list.Position = UDim2.fromOffset(0, 32)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Parent = page
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(inner / 2 - 10, 112)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = list
		for i, u in ipairs(Gangs.upgrades) do
			if u.tab ~= upgradesTab then
				continue
			end
			local level = Gangs.level(view, u.id)
			local card = Ui.card(list, UDim2.new(), UDim2.new())
			card.LayoutOrder = i
			Kit.image(card, Gangs.upgradeIcon(u), UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 8)).ResampleMode =
				Enum.ResamplerMode.Pixelated
			local title = label(
				card,
				T("gang_up_" .. u.id),
				UDim2.new(1, -150, 0, 22),
				UDim2.fromOffset(60, 6),
				16,
				Ui.colors.white
			)
			title.Font = Kit.BOLD
			label(
				card,
				if u.max > 1
					then T("gang_level_of", level, u.max)
					elseif level >= 1 then T("gang_up_bought")
					else "",
				UDim2.fromOffset(90, 22),
				UDim2.new(1, -96, 0, 6),
				13,
				GOLD
			).TextXAlignment =
				Enum.TextXAlignment.Right
			local descText = if level >= u.max or u.currency == "treasury"
				then upgradeDesc(u, math.max(level, 1))
				else T("gang_now")
					.. ": "
					.. upgradeDesc(u, level)
					.. "\n"
					.. T("gang_next")
					.. ": "
					.. upgradeDesc(u, level + 1)
			local desc = label(
				card,
				descText,
				UDim2.new(1, -68, 0, 40),
				UDim2.fromOffset(60, 28),
				12,
				Ui.colors.muted
			)
			desc.TextWrapped = true
			desc.TextYAlignment = Enum.TextYAlignment.Top
			local cost = Gangs.nextCost(view, u.id)
			local buyText = if not cost
				then T("gang_max")
				elseif u.currency == "treasury" then T(
					"gang_buy_money",
					Strings.money(math.floor(cost * Config.moneyScale + 0.5))
				)
				else T("gang_buy_points", cost)
			local affordable = cost ~= nil
				and (
					if u.currency == "treasury"
						then (view.treasury or 0) >= cost * Config.moneyScale
						else (view.points or 0) >= cost
				)
			local canBuy = cost ~= nil and Gangs.can(role, "upgrade")
			local buy = Ui.button(
				card,
				buyText,
				UDim2.new(1, -16, 0, 30),
				UDim2.new(0, 8, 1, -36),
				if canBuy and affordable then Ui.colors.buttonGreen else Ui.colors.buttonGrey
			)
			buy.TextSize = 13
			buy.Activated:Connect(function()
				if canBuy then
					send("upgrade", u.id)
				end
			end)
		end
	end

	local function drawTreasury()
		local view = state
		local head = Ui.card(page, UDim2.new(1, -8, 0, 54), UDim2.fromOffset(4, 0))
		Kit.image(
			head,
			iconOr("gang_treasury", "money_bag"),
			UDim2.fromOffset(42, 42),
			UDim2.fromOffset(6, 6)
		).ResampleMode =
			Enum.ResamplerMode.Pixelated
		local line = label(
			head,
			T(
				"gang_treasury_line",
				Strings.money(view.treasury or 0),
				Strings.money(Gangs.treasuryCap(view))
			),
			UDim2.fromOffset(300, 54),
			UDim2.fromOffset(56, 0),
			17,
			Ui.colors.money
		)
		line.Font = Kit.BOLD
		local box = textBox(
			head,
			T("gang_amount_hint"),
			UDim2.fromOffset(110, 32),
			UDim2.new(1, -350, 0, 11)
		)
		box.Text = draft.amount
		box:GetPropertyChangedSignal("Text"):Connect(function()
			draft.amount = box.Text
		end)
		local function amount(): number?
			local n = tonumber((box.Text:gsub("[%s,$]", "")))
			return if n and n == n and n > 0 then n else nil
		end
		local dep = Ui.button(
			head,
			T("gang_deposit"),
			UDim2.fromOffset(110, 32),
			UDim2.new(1, -234, 0, 11),
			Ui.colors.buttonGreen
		)
		dep.TextSize = 14
		dep.Activated:Connect(function()
			local n = amount()
			if n then
				send("deposit", n)
			end
		end)
		local canWithdraw = Gangs.can(myRole() :: any, "withdraw")
		local wd = Ui.button(
			head,
			T("gang_withdraw"),
			UDim2.fromOffset(110, 32),
			UDim2.new(1, -118, 0, 11),
			if canWithdraw then Ui.colors.buttonBlue else Ui.colors.buttonGrey
		)
		wd.TextSize = 14
		wd.Activated:Connect(function()
			local n = amount()
			if n and canWithdraw then
				send("withdraw", n)
			end
		end)
		label(
			page,
			T("gang_log_title")
				.. '  <font color="'
				.. Ui.hex(Ui.colors.muted)
				.. '">'
				.. T("gang_withdraw_rights")
				.. "</font>",
			UDim2.new(1, -8, 0, 24),
			UDim2.fromOffset(6, 60),
			15,
			Ui.colors.header
		)
		local list = scroller(page, UDim2.new(1, 0, 1, -90), UDim2.fromOffset(0, 88), 4)
		local log = view.treasuryLog or {}
		if #log == 0 then
			label(
				list,
				T("gang_log_empty"),
				UDim2.new(1, -10, 0, 30),
				UDim2.new(),
				14,
				Ui.colors.muted
			)
		end
		for i = #log, 1, -1 do
			local e = log[i]
			local card = Ui.card(list, UDim2.new(1, -10, 0, 30), UDim2.new())
			card.LayoutOrder = #log - i
			local text = if e.kind == "in"
				then T("gang_log_in", e.by, Strings.money(e.amount))
				elseif e.kind == "out" then T("gang_log_out", e.by, Strings.money(e.amount))
				else T(
					"gang_log_buy",
					e.by,
					T("gang_up_" .. tostring(e.what)),
					Strings.money(e.amount)
				)
			label(
				card,
				os.date("%d.%m %H:%M", e.at) :: string,
				UDim2.fromOffset(100, 30),
				UDim2.fromOffset(8, 0),
				13,
				Ui.colors.muted
			)
			label(
				card,
				text,
				UDim2.new(1, -120, 1, 0),
				UDim2.fromOffset(110, 0),
				14,
				if e.kind == "in" then Ui.colors.money else Ui.colors.text
			)
		end
	end

	-- the colour swatches and emblem choices (create form and settings)
	local function pickers(
		parentFrame: Instance,
		y: number,
		color: number,
		icon: number,
		pick: (string, number) -> ()
	)
		label(
			parentFrame,
			T("gang_color"),
			UDim2.fromOffset(100, 24),
			UDim2.fromOffset(4, y),
			14,
			Ui.colors.text
		)
		for i = 1, #cfg.colors do
			local sw = Instance.new("TextButton")
			sw.Text = ""
			sw.AutoButtonColor = false
			sw.BackgroundColor3 = Gangs.color(i)
			sw.Size = UDim2.fromOffset(30, 30)
			sw.Position = UDim2.fromOffset(100 + (i - 1) * 36, y - 3)
			sw.Parent = parentFrame
			Kit.corner(sw, 6)
			Kit.stroke(
				sw,
				if i == color then Ui.colors.white else Kit.EDGE,
				if i == color then 2.5 else 1
			)
			sw.Activated:Connect(function()
				pick("color", i)
			end)
		end
		label(
			parentFrame,
			T("gang_icon"),
			UDim2.fromOffset(100, 24),
			UDim2.fromOffset(4, y + 40),
			14,
			Ui.colors.text
		)
		for i = 1, #cfg.emblems do
			local b = Instance.new("ImageButton")
			b.BackgroundColor3 = Kit.CARD
			b.AutoButtonColor = false
			b.Image = Gangs.emblem(i)
			b.ScaleType = Enum.ScaleType.Fit
			b.ResampleMode = Enum.ResamplerMode.Pixelated
			b.Size = UDim2.fromOffset(34, 34)
			b.Position = UDim2.fromOffset(100 + (i - 1) * 40, y + 35)
			b.Parent = parentFrame
			Kit.corner(b, 6)
			Kit.stroke(b, if i == icon then GOLD else Kit.EDGE, if i == icon then 2.5 else 1)
			b.Activated:Connect(function()
				pick("icon", i)
			end)
		end
	end

	local function drawSettings()
		local view = state
		local leader = myRole() == "leader"
		local pvp = Ui.card(page, UDim2.new(1, -8, 0, 54), UDim2.fromOffset(4, 0))
		label(
			pvp,
			T("gang_pvp_title"),
			UDim2.fromOffset(400, 24),
			UDim2.fromOffset(10, 4),
			16,
			Ui.colors.white
		).Font =
			Kit.BOLD
		label(
			pvp,
			T("gang_pvp_hint"),
			UDim2.fromOffset(400, 20),
			UDim2.fromOffset(10, 28),
			13,
			Ui.colors.muted
		)
		local toggle = Ui.button(
			pvp,
			T(if view.pvp then "gang_pvp_state_on" else "gang_pvp_state_off"),
			UDim2.fromOffset(200, 34),
			UDim2.new(1, -210, 0, 10),
			if view.pvp then Ui.colors.close else Ui.colors.buttonGrey
		)
		toggle.TextSize = 14
		toggle.Activated:Connect(function()
			if leader then
				send("settings", { pvp = not view.pvp })
			end
		end)
		label(
			page,
			T("gang_appearance_hint"),
			UDim2.new(1, -8, 0, 22),
			UDim2.fromOffset(6, 62),
			13,
			Ui.colors.muted
		)
		pickers(page, 92, view.color, view.icon, function(field, value)
			if leader then
				send("settings", { [field] = value })
			end
		end)
		label(
			page,
			T("gang_desc_hint", cfg.descMax),
			UDim2.fromOffset(300, 22),
			UDim2.fromOffset(4, 168),
			14,
			Ui.colors.text
		)
		local box = textBox(
			page,
			T("gang_desc_hint", cfg.descMax),
			UDim2.new(1, -150, 0, 34),
			UDim2.fromOffset(4, 192)
		)
		box.Text = draft.settingsDesc or view.desc or ""
		box:GetPropertyChangedSignal("Text"):Connect(function()
			draft.settingsDesc = box.Text
		end)
		box.TextEditable = leader
		local save = Ui.button(
			page,
			T("gang_save"),
			UDim2.fromOffset(130, 34),
			UDim2.new(1, -138, 0, 192),
			if leader then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		save.TextSize = 14
		save.Activated:Connect(function()
			if leader then
				send("settings", { desc = box.Text })
				draft.settingsDesc = nil
			end
		end)
		if leader then
			confirmButton(
				page,
				T("gang_disband"),
				T("gang_confirm"),
				UDim2.fromOffset(220, 34),
				UDim2.new(1, -224, 0, pageH - 40),
				Ui.colors.close,
				function()
					send("disband")
				end
			)
		else
			label(
				page,
				T("gang_err_rights_leader"),
				UDim2.new(1, -8, 0, 30),
				UDim2.fromOffset(6, pageH - 36),
				14,
				Ui.colors.muted
			)
		end
	end

	local function drawCreate()
		local y = 0
		local updatePreview: () -> () = function() end
		local function field(key: string, hint: string, max: number?)
			label(page, hint, UDim2.fromOffset(330, 20), UDim2.fromOffset(4, y), 14, Ui.colors.text)
			local box = textBox(page, hint, UDim2.fromOffset(330, 32), UDim2.fromOffset(4, y + 20))
			box.Text = (draft :: any)[key]
			box:GetPropertyChangedSignal("Text"):Connect(function()
				local text = box.Text
				if key == "tag" then
					text = string.upper(string.gsub(text, "[^%w]", ""))
				end
				if max and utf8.len(text) and (utf8.len(text) :: number) > max then
					text = string.sub(text, 1, (utf8.offset(text, max + 1) or (#text + 1)) - 1)
				end
				if text ~= box.Text then
					box.Text = text
				end
				(draft :: any)[key] = text
				updatePreview()
			end)
			y += 58
			return box
		end
		-- the preview card [клиент gang.gui.create «Предпросмотр банды»]
		local preview = Ui.card(page, UDim2.fromOffset(inner - 350, 120), UDim2.fromOffset(346, 0))
		label(
			preview,
			T("gang_preview"),
			UDim2.new(1, -16, 0, 22),
			UDim2.fromOffset(8, 4),
			13,
			Ui.colors.muted
		)
		Kit.image(
			preview,
			Gangs.emblem(draft.icon),
			UDim2.fromOffset(56, 56),
			UDim2.fromOffset(10, 32)
		).ResampleMode =
			Enum.ResamplerMode.Pixelated
		local shown = label(
			preview,
			"",
			UDim2.new(1, -86, 0, 28),
			UDim2.fromOffset(76, 34),
			18,
			Ui.colors.white
		)
		shown.Font = Kit.BOLD
		Kit.fit(shown)
		local shownDesc = label(
			preview,
			"",
			UDim2.new(1, -86, 0, 40),
			UDim2.fromOffset(76, 62),
			13,
			Ui.colors.muted
		)
		shownDesc.TextWrapped = true
		updatePreview = function()
			shown.Text = nameTag({
				color = draft.color,
				name = if draft.name ~= "" then draft.name else "…",
				tag = if draft.tag ~= "" then draft.tag else "???",
			})
			shownDesc.Text = draft.desc
		end
		updatePreview()

		field("name", T("gang_name_hint", cfg.nameMax), cfg.nameMax)
		field("tag", T("gang_tag_hint", cfg.tagLength), cfg.tagLength)
		field("desc", T("gang_desc_hint", cfg.descMax), cfg.descMax)
		pickers(page, y + 6, draft.color, draft.icon, function(fieldName, value)
			(draft :: any)[fieldName] = value
			draw()
		end)
		local p = current
		local cost = math.floor(cfg.createCost * Config.moneyScale + 0.5)
		local ready = p ~= nil and p.level >= cfg.minLevel and p.coins >= cost
		label(
			page,
			T("gang_create_needs", cfg.minLevel, Strings.money(cost)),
			UDim2.fromOffset(330, 22),
			UDim2.fromOffset(4, pageH - 70),
			13,
			if ready then Ui.colors.muted else Kit.BAD
		)
		label(
			page,
			T("gang_rules_warning"),
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(4, pageH - 50),
			12,
			Ui.colors.muted
		)
		local create = Ui.button(
			page,
			T("gang_create_button", Strings.money(cost)),
			UDim2.fromOffset(240, 36),
			UDim2.new(1, -244, 0, pageH - 40),
			if ready then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		create.TextSize = 15
		create.Activated:Connect(function()
			send("create", {
				name = draft.name,
				tag = draft.tag,
				desc = draft.desc,
				color = draft.color,
				icon = draft.icon,
			})
		end)
	end

	local function drawInvites()
		if #invites == 0 then
			local empty = label(
				page,
				T("gang_invites_empty"),
				UDim2.new(1, 0, 0, 40),
				UDim2.new(0, 0, 0.5, -20),
				17,
				Ui.colors.muted
			)
			empty.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		local list = scroller(page, UDim2.fromScale(1, 1), UDim2.new(), 6)
		for i, invite in ipairs(invites) do
			local card = Ui.card(list, UDim2.new(1, -10, 0, 50), UDim2.new())
			card.LayoutOrder = i
			label(
				card,
				string.format("%s #%s", tostring(invite.name), tostring(invite.tag)),
				UDim2.fromOffset(300, 26),
				UDim2.fromOffset(10, 2),
				16,
				Ui.colors.white
			).Font =
				Kit.BOLD
			local sub = label(
				card,
				"",
				UDim2.fromOffset(300, 20),
				UDim2.fromOffset(10, 26),
				13,
				Ui.colors.muted
			)
			table.insert(tickers, function()
				sub.Text = T(
					"gang_invite_from",
					tostring(invite.from),
					Gangs.clock(math.max(0, (invite.expires or 0) - nowServer()))
				)
			end)
			local accept = Ui.button(
				card,
				T("gang_accept"),
				UDim2.fromOffset(110, 34),
				UDim2.new(1, -234, 0, 8),
				Ui.colors.buttonGreen
			)
			accept.TextSize = 14
			accept.Activated:Connect(function()
				send("accept", invite.gang)
			end)
			local decline = Ui.button(
				card,
				T("gang_decline"),
				UDim2.fromOffset(110, 34),
				UDim2.new(1, -118, 0, 8),
				Ui.colors.buttonGrey
			)
			decline.TextSize = 14
			decline.Activated:Connect(function()
				send("decline", invite.gang)
			end)
		end
	end

	local PAGES: { [string]: () -> () } = {
		overview = drawOverview,
		members = drawMembers,
		quests = drawQuests,
		upgrades = drawUpgrades,
		treasury = drawTreasury,
		settings = drawSettings,
		create = drawCreate,
		invites = drawInvites,
	}

	local function tabsNow(): { string }
		if state then
			return { "overview", "members", "quests", "upgrades", "treasury", "settings" }
		end
		return { "create", "invites" }
	end

	draw = function()
		local tabs = tabsNow()
		if not table.find(tabs, tab) then
			tab = if state then "overview" elseif #invites > 0 then "invites" else "create"
		end
		for _, child in ipairs(tabBar:GetChildren()) do
			child:Destroy()
		end
		local tabW = math.floor((inner - (#tabs - 1) * 4) / #tabs)
		for i, kind in ipairs(tabs) do
			local text = T("gang_tab_" .. kind)
			if kind == "invites" and #invites > 0 then
				text ..= " (" .. #invites .. ")"
			end
			local b = Ui.button(
				tabBar,
				text,
				UDim2.fromOffset(tabW, TAB_H),
				UDim2.fromOffset((i - 1) * (tabW + 4), 0),
				if kind == tab then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			)
			b.TextSize = 14
			b.Name = "Tab_" .. kind
			b.Activated:Connect(function()
				if tab ~= kind then
					tab = kind
					draw()
				end
			end)
		end
		-- keep the focused text box: rebuilding while typing would drop the cursor; redraw when it loses focus
		local focused = game:GetService("UserInputService"):GetFocusedTextBox()
		if focused and focused:IsDescendantOf(page) then
			if not dirty then
				dirty = true
				focused.FocusLost:Once(function()
					dirty = false
					draw()
				end)
			end
			return
		end
		for _, child in ipairs(page:GetChildren()) do
			child:Destroy()
		end
		tickers = {}
		if state == nil then
			local wait = label(
				page,
				"…",
				UDim2.new(1, 0, 0, 40),
				UDim2.new(0, 0, 0.5, -20),
				20,
				Ui.colors.muted
			)
			wait.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		PAGES[tab]()
		for _, tick in ipairs(tickers) do
			tick()
		end
	end

	onChange = draw
	draw()
	send("state")
	task.spawn(function()
		while win.Parent do
			for _, tick in ipairs(tickers) do
				tick()
			end
			task.wait(1)
		end
	end)
	win.Destroying:Once(function()
		if onChange == draw then
			onChange = nil
		end
	end)
	return win,
		function(p: Types.Profile?)
			local hadGang = current ~= nil and current.gang ~= nil and current.gang.id ~= nil
			current = p
			local hasGang = p ~= nil and p.gang ~= nil and p.gang.id ~= nil
			if hadGang ~= hasGang and tab == "create" then
				draw()
			end
		end
end

return GangWindow
