--!strict
-- «Банда» [R] like the original [владелец 28.10, скриншоты; facts docs/research/remaining-features-facts.md §1].
-- Without a gang: «Вы ещё не состоите в банде» (+ Создать банду / Приглашения), the create form (name ≤ 15, tag of 3,
-- 15 icons, 15 colours, description ≤ 300; preview, «Требования», «Информация», «Внимание»; «Создать за 15,000 $» or
-- «за 499 💎» with a Да / Нет confirmation) and the invites. With a gang: the left panel (emblem on the gang colour,
-- «name #TAG», members, gang points, treasury, description with a pencil, home / leave, the leader at the bottom), the
-- tabs Участники / Улучшения (Прокачки for $ — own money or «Из казны» — and Перки for gang points; a list and the
-- selected card: «Описание», «Что изменится · Сейчас · Станет», «⬆ Улучшить», «Уже имеется!» / «Куплено») /
-- Задания (Ежедневные, Еженедельные and the «★ Задания» goal with the multiplier bar and a row per member) / Казна,
-- and ⚙ — the settings popup (Внешний вид, Общие, Опасная зона). The server decides everything (GangService): this
-- window sends GangAction intents and draws the last GangState / GangInvites; rules in Shared/Gangs.
-- A page is rebuilt when the tab or the state changes; typed text survives in `draft`; timers tick in place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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

local W, H = 780, 520
local TAB_H = 30
local SIDE = 200
local GOLD = Color3.fromRGB(255, 200, 60)
local PURPLE = Color3.fromRGB(110, 60, 200)
local RED = Color3.fromRGB(190, 45, 45)
local TAG_RED = Color3.fromRGB(255, 70, 70)

local state: any = nil -- the last GangState: a view of the gang, false = no gang, nil = not known yet
local invites: { any } = {}
local onChange: (() -> ())? = nil
local listening = false
local draft = {
	name = "",
	tag = "",
	desc = "",
	color = 0, -- 0 = not picked yet («Требования»)
	icon = 0,
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
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = box
	Kit.corner(box, 4)
	Kit.stroke(box, Ui.colors.border, 1)
	box.Parent = parent
	return box
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

-- whole dollars with thousands separators, like the original («15,000 $»)
local function dollars(units: number): string
	return Strings.grouped(math.floor(units / Config.moneyScale), 0)
end

-- cuts a text to `max` characters (utf8)
local function clip(text: string, max: number): string
	local length = utf8.len(text)
	if length and length > max then
		return string.sub(text, 1, (utf8.offset(text, max + 1) or (#text + 1)) - 1)
	end
	return text
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
	local CW, CH = W - 12, H - 46

	-- with a gang: the left panel, the tab bar with ⚙ and the page; without one the page takes the whole window
	local side = Kit.frame(content, UDim2.fromOffset(SIDE, CH), UDim2.new(), Color3.new())
	side.BackgroundTransparency = 1
	local tabBar = Kit.frame(
		content,
		UDim2.fromOffset(CW - SIDE - 8, TAB_H),
		UDim2.fromOffset(SIDE + 8, 0),
		Color3.new()
	)
	tabBar.BackgroundTransparency = 1
	local page = Kit.frame(content, UDim2.fromOffset(CW, CH), UDim2.new(), Color3.new())
	page.BackgroundTransparency = 1
	local layer = Kit.frame(content, UDim2.fromScale(1, 1), UDim2.new(), Color3.new()) -- popups
	layer.BackgroundTransparency = 1
	local PW, PH = CW, CH -- the page size of the current layout

	local tab = "members" -- members | upgrades | tasks | treasury
	local view = "none" -- without a gang: none | create | invites
	local upgradesTab = "boosts"
	local selected: { [string]: string } = {}
	local tasksTab = "daily"
	local popup: any = nil -- { kind = "settings" } | { kind = "confirm", text, yes }
	local dirty = false -- a redraw waits for the text box being typed in to lose focus
	local tickers: { () -> () } = {}
	local draw: () -> ()
	local drawnMode = ""

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
		return Kit.text(parentFrame, text, size, position, textSize or 14, color or Ui.colors.text)
	end

	local function wrapped(l: TextLabel): TextLabel
		l.TextWrapped = true
		l.TextYAlignment = Enum.TextYAlignment.Top
		return l
	end

	local function button(
		parentFrame: Instance,
		text: string,
		size: UDim2,
		position: UDim2,
		color: Color3,
		act: (() -> ())?
	): TextButton
		local b = Ui.button(parentFrame, text, size, position, color)
		b.TextSize = 14
		if act then
			b.Activated:Connect(act)
		end
		return b
	end

	local function myRole(): string?
		return if state then state.you else nil
	end

	-- «Название #ТЕГ»: the tag in red [владелец 28.10]
	local function nameTag(name: string, tag: string): string
		return string.format('%s <font color="%s">#%s</font>', name, Ui.hex(TAG_RED), tag)
	end

	-- the emblem on a plate of the gang colour
	local function plate(
		parentFrame: Instance,
		icon: number,
		color: number,
		legacy: boolean?,
		px: number,
		pos: UDim2
	)
		local f = Kit.frame(
			parentFrame,
			UDim2.fromOffset(px, px),
			pos,
			if color > 0 then Gangs.color(color) else Kit.GREY
		)
		Kit.corner(f, 8)
		Kit.stroke(f, Kit.EDGE, 1)
		local img = Kit.image(
			f,
			if icon > 0 then Gangs.emblem(icon, legacy) else "",
			UDim2.fromScale(0.76, 0.76),
			UDim2.fromScale(0.12, 0.12)
		)
		img.ResampleMode = Enum.ResamplerMode.Pixelated
		return f
	end

	local function leaderName(v: any): string
		local m = v.members and v.members[tostring(v.leader)]
		return if m then tostring(m.name) else "?"
	end

	-- a dark overlay with a card in the middle (confirmations, settings)
	local function overlay(w: number, h: number): Frame
		local shade = Kit.frame(layer, UDim2.fromScale(1, 1), UDim2.new(), Color3.new())
		shade.BackgroundTransparency = 0.45
		shade.Active = true
		return Ui.card(shade, UDim2.fromOffset(w, h), UDim2.new(0.5, -w / 2, 0.5, -h / 2))
	end

	local function confirm(text: string, yes: () -> ())
		popup = { kind = "confirm", text = text, yes = yes }
		draw()
	end

	local function drawConfirm()
		local card = overlay(380, 140)
		wrapped(
			label(
				card,
				popup.text,
				UDim2.new(1, -24, 0, 60),
				UDim2.fromOffset(12, 14),
				16,
				Ui.colors.white
			)
		)
		local act = popup.yes
		button(
			card,
			T("gang_yes"),
			UDim2.fromOffset(160, 36),
			UDim2.new(0, 12, 1, -48),
			Ui.colors.buttonGreen,
			function()
				popup = nil
				act()
				draw()
			end
		)
		button(
			card,
			T("gang_no"),
			UDim2.fromOffset(160, 36),
			UDim2.new(1, -172, 1, -48),
			Ui.colors.buttonGrey,
			function()
				popup = nil
				draw()
			end
		)
	end

	-- the 3 × 5 grids of icons and colours (create form and settings)
	local function iconGrid(parentFrame: Instance, pos: UDim2, chosen: number, pick: (number) -> ())
		for i = 1, #cfg.emblems do
			local b = Instance.new("ImageButton")
			b.BackgroundColor3 = Kit.CARD
			b.AutoButtonColor = false
			b.Image = Gangs.emblem(i)
			b.ScaleType = Enum.ScaleType.Fit
			b.ResampleMode = Enum.ResamplerMode.Pixelated
			b.Size = UDim2.fromOffset(38, 38)
			b.Position = pos + UDim2.fromOffset(((i - 1) % 5) * 43, ((i - 1) // 5) * 43)
			b.Parent = parentFrame
			Kit.corner(b, 6)
			Kit.stroke(b, if i == chosen then GOLD else Kit.EDGE, if i == chosen then 2.5 else 1)
			b.Activated:Connect(function()
				pick(i)
			end)
		end
	end

	local function colorGrid(
		parentFrame: Instance,
		pos: UDim2,
		chosen: number,
		pick: (number) -> ()
	)
		for i = 1, #cfg.colors do
			local sw = Instance.new("TextButton")
			sw.Text = ""
			sw.AutoButtonColor = false
			sw.BackgroundColor3 = Gangs.color(i)
			sw.Size = UDim2.fromOffset(30, 30)
			sw.Position = pos + UDim2.fromOffset(((i - 1) % 5) * 36, ((i - 1) // 5) * 36)
			sw.Parent = parentFrame
			Kit.corner(sw, 6)
			Kit.stroke(
				sw,
				if i == chosen then Ui.colors.white else Kit.EDGE,
				if i == chosen then 2.5 else 1
			)
			sw.Activated:Connect(function()
				pick(i)
			end)
		end
	end

	local function heading(
		parentFrame: Instance,
		text: string,
		pos: UDim2,
		w: number,
		color: Color3?
	): TextLabel
		local l =
			label(parentFrame, text, UDim2.fromOffset(w, 22), pos, 15, color or Ui.colors.header)
		l.Font = Kit.BOLD
		return l
	end

	-- ── without a gang ─────────────────────────────────────────────────────────────────────────────────────────

	local function drawNone()
		local card = Ui.card(page, UDim2.fromOffset(460, 220), UDim2.new(0.5, -230, 0.5, -110))
		local title = label(
			card,
			T("gang_none_title"),
			UDim2.new(1, -24, 0, 30),
			UDim2.fromOffset(12, 18),
			20,
			Ui.colors.white
		)
		title.Font = Kit.BOLD
		title.TextXAlignment = Enum.TextXAlignment.Center
		local text = wrapped(
			label(
				card,
				T("gang_none_text"),
				UDim2.new(1, -40, 0, 44),
				UDim2.fromOffset(20, 56),
				15,
				Ui.colors.muted
			)
		)
		text.TextXAlignment = Enum.TextXAlignment.Center
		button(
			card,
			T("gang_create_open"),
			UDim2.fromOffset(200, 40),
			UDim2.fromOffset(20, 140),
			Ui.colors.buttonBlue,
			function()
				view = "create"
				draw()
			end
		).Name =
			"CreateOpen"
		local inviteText = T("gang_invites_open")
			.. (if #invites > 0 then " (" .. #invites .. ")" else "")
		button(
			card,
			inviteText,
			UDim2.fromOffset(200, 40),
			UDim2.new(1, -220, 0, 140),
			PURPLE,
			function()
				view = "invites"
				draw()
			end
		).Name =
			"InvitesOpen"
	end

	local function drawCreate()
		local p = current
		local LW = 412
		local left = scroller(page, UDim2.new(0, LW, 1, -44), UDim2.new(), 0)
		local leftList = left:FindFirstChildOfClass("UIListLayout")
		if leftList then
			leftList:Destroy()
		end
		left.AutomaticCanvasSize = Enum.AutomaticSize.None
		left.CanvasSize = UDim2.fromOffset(0, 470)
		local updatePreview: () -> () = function() end
		local function field(
			key: string,
			hint: string,
			max: number,
			size: UDim2,
			pos: UDim2,
			multi: boolean?
		): TextBox
			local box = textBox(left, hint, size, pos)
			box.Text = (draft :: any)[key]
			if multi then
				box.MultiLine = true
				box.TextWrapped = true
				box.TextYAlignment = Enum.TextYAlignment.Top
			end
			box:GetPropertyChangedSignal("Text"):Connect(function()
				local text = box.Text
				if key == "tag" then
					text = string.upper((string.gsub(text, "[^%w]", "")))
				end
				text = clip(text, max)
				if text ~= box.Text then
					box.Text = text
				end
				(draft :: any)[key] = text
				updatePreview()
			end)
			return box
		end
		label(left, T("gang_name_label"), UDim2.fromOffset(250, 20), UDim2.fromOffset(4, 0), 14)
		label(left, T("gang_tag_label"), UDim2.fromOffset(120, 20), UDim2.fromOffset(266, 0), 14)
		field(
			"name",
			T("gang_name_label"),
			cfg.nameMax,
			UDim2.fromOffset(254, 32),
			UDim2.fromOffset(4, 20)
		).Name =
			"NameBox"
		field("tag", "ABC", cfg.tagLength, UDim2.fromOffset(120, 32), UDim2.fromOffset(266, 20)).Name =
			"TagBox"
		label(left, T("gang_icon"), UDim2.fromOffset(210, 20), UDim2.fromOffset(4, 62), 14)
		label(left, T("gang_color"), UDim2.fromOffset(180, 20), UDim2.fromOffset(222, 62), 14)
		iconGrid(left, UDim2.fromOffset(4, 84), draft.icon, function(i)
			draft.icon = i
			draw()
		end)
		colorGrid(left, UDim2.fromOffset(222, 84), draft.color, function(i)
			draft.color = i
			draw()
		end)
		label(left, T("gang_desc_label"), UDim2.fromOffset(250, 20), UDim2.fromOffset(4, 222), 14)
		local counter = label(
			left,
			"",
			UDim2.fromOffset(120, 20),
			UDim2.fromOffset(266, 222),
			13,
			Ui.colors.muted
		)
		counter.TextXAlignment = Enum.TextXAlignment.Right
		field(
			"desc",
			T("gang_desc_placeholder"),
			cfg.descMax,
			UDim2.fromOffset(382, 96),
			UDim2.fromOffset(4, 244),
			true
		).Name =
			"DescBox"
		button(
			page,
			T("gang_back"),
			UDim2.fromOffset(130, 34),
			UDim2.new(0, 4, 1, -38),
			Ui.colors.buttonGrey,
			function()
				view = "none"
				draw()
			end
		)

		-- the right column: preview, requirements, information, warning, the two buttons
		local RX = LW + 10
		local RW = PW - RX
		local preview = Ui.card(page, UDim2.fromOffset(RW, 84), UDim2.fromOffset(RX, 0))
		local plateFrame: Frame? = nil
		local shown = label(
			preview,
			"",
			UDim2.new(1, -86, 0, 26),
			UDim2.fromOffset(78, 14),
			18,
			Ui.colors.white
		)
		shown.Font = Kit.BOLD
		Kit.fit(shown)
		local me = Players.LocalPlayer
		label(
			preview,
			T("gang_leader_line", me.Name),
			UDim2.new(1, -86, 0, 20),
			UDim2.fromOffset(78, 44),
			13,
			GOLD
		)
		local reqCard = Ui.card(page, UDim2.fromOffset(RW, 112), UDim2.fromOffset(RX, 92))
		heading(reqCard, T("gang_requirements"), UDim2.fromOffset(10, 4), RW - 20)
		local ticks: { TextLabel } = {}
		local reqKeys =
			{ "gang_name_label", "gang_tag_label", "gang_icon", "gang_color", "gang_req_level" }
		for i, key in ipairs(reqKeys) do
			local text = if key == "gang_req_level" then T(key, cfg.minLevel) else T(key)
			ticks[i] = label(
				reqCard,
				text,
				UDim2.fromOffset(RW / 2 - 14, 20),
				UDim2.fromOffset(10 + ((i - 1) % 2) * (RW / 2 - 6), 30 + ((i - 1) // 2) * 24),
				14
			)
		end
		local info = Ui.card(page, UDim2.fromOffset(RW, 92), UDim2.fromOffset(RX, 212))
		heading(info, T("gang_info_title"), UDim2.fromOffset(10, 4), RW - 20)
		wrapped(
			label(
				info,
				T("gang_info_text", cfg.nameMax, cfg.tagLength, cfg.descMax),
				UDim2.new(1, -20, 0, 62),
				UDim2.fromOffset(10, 26),
				12,
				Ui.colors.muted
			)
		)
		local warnCard = Ui.card(page, UDim2.fromOffset(RW, 70), UDim2.fromOffset(RX, 312))
		heading(warnCard, T("gang_warning_title"), UDim2.fromOffset(10, 4), RW - 20, TAG_RED)
		wrapped(
			label(
				warnCard,
				T("gang_warning_text"),
				UDim2.new(1, -20, 0, 40),
				UDim2.fromOffset(10, 26),
				12,
				Ui.colors.muted
			)
		)

		local money = math.floor(cfg.createCost * Config.moneyScale + 0.5)
		local crystals = cfg.createCrystals
		local createMoney = button(
			page,
			T("gang_create_button", dollars(money)),
			UDim2.fromOffset(RW / 2 - 4, 40),
			UDim2.new(0, RX, 1, -44),
			Ui.colors.buttonBlue
		)
		createMoney.Name = "CreateMoney"
		local createCrystals = button(
			page,
			T("gang_create_crystals", Strings.grouped(crystals, 0)),
			UDim2.fromOffset(RW / 2 - 4, 40),
			UDim2.new(0, RX + RW / 2 + 4, 1, -44),
			PURPLE
		)
		createCrystals.Name = "CreateCrystals"
		local function ready(): boolean
			local ok = Gangs.checkName(draft.name) ~= nil
				and Gangs.checkTag(draft.tag) ~= nil
				and draft.icon > 0
				and draft.color > 0
				and p ~= nil
				and p.level >= cfg.minLevel
			return ok
		end
		updatePreview = function()
			if plateFrame then
				plateFrame:Destroy()
			end
			plateFrame =
				plate(preview, draft.icon, draft.color, false, 60, UDim2.fromOffset(10, 12))
			shown.Text = nameTag(
				if draft.name ~= "" then draft.name else T("gang_name_label"),
				if draft.tag ~= "" then draft.tag else "???"
			)
			counter.Text = T("gang_counter", utf8.len(draft.desc) or 0, cfg.descMax)
			local okList = {
				Gangs.checkName(draft.name) ~= nil,
				Gangs.checkTag(draft.tag) ~= nil,
				draft.icon > 0,
				draft.color > 0,
				p ~= nil and p.level >= cfg.minLevel,
			}
			for i, l in ipairs(ticks) do
				local text = if reqKeys[i] == "gang_req_level"
					then T(reqKeys[i], cfg.minLevel)
					else T(reqKeys[i])
				l.Text = (if okList[i] then "✔ " else "✖ ") .. text
				l.TextColor3 = if okList[i] then Kit.GOOD else Kit.BAD
			end
			local go = ready()
			createMoney.BackgroundColor3 = if go
					and p
					and p.coins >= money
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
			createCrystals.BackgroundColor3 = if go
					and p
					and (p.crystals or 0) >= crystals
				then PURPLE
				else Ui.colors.buttonGrey
		end
		updatePreview()
		local function ask(pay: string)
			if not ready() then
				return
			end
			local price = if pay == "crystals"
				then Strings.grouped(crystals, 0) .. " 💎"
				else dollars(money) .. " $"
			confirm(T("gang_create_confirm", draft.name, price), function()
				send("create", {
					name = draft.name,
					tag = draft.tag,
					desc = draft.desc,
					color = draft.color,
					icon = draft.icon,
					pay = pay,
				})
			end)
		end
		createMoney.Activated:Connect(function()
			ask("money")
		end)
		createCrystals.Activated:Connect(function()
			ask("crystals")
		end)
	end

	local function drawInvites()
		button(
			page,
			T("gang_back"),
			UDim2.fromOffset(130, 30),
			UDim2.fromOffset(4, 0),
			Ui.colors.buttonGrey,
			function()
				view = "none"
				draw()
			end
		)
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
		local list = scroller(page, UDim2.new(1, 0, 1, -38), UDim2.fromOffset(0, 38), 6)
		for i, invite in ipairs(invites) do
			local card = Ui.card(list, UDim2.new(1, -10, 0, 50), UDim2.new())
			card.LayoutOrder = i
			label(
				card,
				nameTag(tostring(invite.name), tostring(invite.tag)),
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
			button(
				card,
				T("gang_accept"),
				UDim2.fromOffset(110, 34),
				UDim2.new(1, -234, 0, 8),
				Ui.colors.buttonGreen,
				function()
					send("accept", invite.gang)
				end
			)
			button(
				card,
				T("gang_decline"),
				UDim2.fromOffset(110, 34),
				UDim2.new(1, -118, 0, 8),
				Ui.colors.buttonGrey,
				function()
					send("decline", invite.gang)
				end
			)
		end
	end

	-- ── with a gang: the left panel ─────────────────────────────────────────────────────────────────────────────

	local function drawSide()
		local v = state
		local card = Ui.card(side, UDim2.fromScale(1, 1), UDim2.new())
		plate(
			card,
			v.icon,
			v.color,
			Gangs.legacy(v) and not v.newIcon,
			76,
			UDim2.new(0.5, -38, 0, 10)
		)
		local title = label(
			card,
			nameTag(v.name, v.tag),
			UDim2.new(1, -16, 0, 26),
			UDim2.fromOffset(8, 92),
			18,
			Ui.colors.white
		)
		title.Font = Kit.BOLD
		title.TextXAlignment = Enum.TextXAlignment.Center
		Kit.fit(title)
		local rows = {
			{
				T("gang_side_members"),
				string.format("%d / %d", Gangs.memberCount(v), Gangs.slots(v)),
				Ui.colors.white,
			},
			{ T("gang_side_points"), tostring(v.points or 0), GOLD },
			{ T("gang_side_treasury"), dollars(v.treasury or 0) .. " $", Ui.colors.money },
		}
		for i, row in ipairs(rows) do
			local y = 124 + (i - 1) * 24
			label(
				card,
				row[1],
				UDim2.fromOffset(100, 22),
				UDim2.fromOffset(10, y),
				13,
				Ui.colors.muted
			)
			local value = label(
				card,
				row[2],
				UDim2.fromOffset(SIDE - 112, 22),
				UDim2.fromOffset(102, y),
				14,
				row[3]
			)
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.Font = Kit.BOLD
		end
		heading(card, T("gang_side_desc"), UDim2.fromOffset(10, 200), 140)
		if myRole() == "leader" then
			local pencil = button(
				card,
				"",
				UDim2.fromOffset(26, 22),
				UDim2.new(1, -36, 0, 200),
				Ui.colors.buttonGrey,
				function()
					popup = { kind = "settings" }
					draw()
				end
			)
			pencil.Name = "EditDesc" -- the settings picture: the font has no pencil glyph
			Kit.image(
				pencil,
				icons.menu_settings or "",
				UDim2.fromOffset(16, 16),
				UDim2.fromOffset(5, 3)
			).ResampleMode =
				Enum.ResamplerMode.Pixelated
		end
		wrapped(
			label(
				card,
				v.desc or "",
				UDim2.new(1, -20, 0, 110),
				UDim2.fromOffset(10, 224),
				12,
				Ui.colors.text
			)
		)
		-- «Домой» = /gang home: the gang's own house on the База банды (GangHouseService)
		button(
			card,
			T("gang_home"),
			UDim2.new(1, -20, 0, 32),
			UDim2.new(0, 10, 1, -112),
			Ui.colors.buttonBlue,
			function()
				Remotes.event("GangHome"):FireServer()
			end
		)
		if myRole() ~= "leader" then
			button(
				card,
				T("gang_leave"),
				UDim2.new(1, -20, 0, 32),
				UDim2.new(0, 10, 1, -74),
				RED,
				function()
					confirm(T("gang_leave") .. "?", function()
						send("leave")
					end)
				end
			)
		end
		local crown = Kit.image(
			card,
			icons.top_crown or "",
			UDim2.fromOffset(18, 18),
			UDim2.new(0, 10, 1, -30)
		)
		crown.ResampleMode = Enum.ResamplerMode.Pixelated
		local leader = label(
			card,
			T("gang_leader_line", leaderName(v)),
			UDim2.new(1, -40, 0, 22),
			UDim2.new(0, 32, 1, -32),
			13,
			GOLD
		)
		Kit.fit(leader)
	end

	-- ── tabs ───────────────────────────────────────────────────────────────────────────────────────────────────

	local function drawMembers()
		local v = state
		heading(
			page,
			T("gang_members_count", Gangs.memberCount(v), Gangs.slots(v)),
			UDim2.fromOffset(4, 0),
			300
		)
		local head = Kit.frame(page, UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 26), Kit.TRACK)
		Kit.corner(head, 4)
		label(
			head,
			T("gang_col_level"),
			UDim2.fromOffset(50, 22),
			UDim2.fromOffset(8, 0),
			13,
			Ui.colors.muted
		)
		label(
			head,
			T("gang_col_name"),
			UDim2.fromOffset(180, 22),
			UDim2.fromOffset(60, 0),
			13,
			Ui.colors.muted
		)
		label(
			head,
			T("gang_col_status"),
			UDim2.fromOffset(120, 22),
			UDim2.fromOffset(240, 0),
			13,
			Ui.colors.muted
		)
		local canInvite = Gangs.can(myRole() :: any, "invite")
		local list = scroller(
			page,
			UDim2.new(1, 0, 1, if canInvite then -98 else -54),
			UDim2.fromOffset(0, 52),
			4
		)
		local entries = {}
		for key, m in pairs(v.members) do
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
		local me = Players.LocalPlayer.UserId
		for i, entry in ipairs(entries) do
			local m = entry.m
			local row = Ui.card(list, UDim2.new(1, -10, 0, 36), UDim2.new())
			row.LayoutOrder = i
			label(
				row,
				tostring(m.level or 1),
				UDim2.fromOffset(50, 36),
				UDim2.fromOffset(8, 0),
				14,
				Ui.colors.level
			)
			local nameLabel = label(
				row,
				tostring(m.name),
				UDim2.fromOffset(176, 36),
				UDim2.fromOffset(60, 0),
				15,
				Ui.colors.white
			)
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			local roleColor = if m.role == "leader"
				then GOLD
				elseif m.role == "deputy" then Ui.colors.level
				else Ui.colors.muted
			label(
				row,
				Kit.colored("● ", roleColor) .. T("gang_role_" .. m.role),
				UDim2.fromOffset(130, 36),
				UDim2.fromOffset(240, 0),
				14,
				roleColor
			)
			if entry.id == me then
				continue
			end
			local x = -4
			local function action(text: string, color: Color3, op: string, ask: boolean?)
				x -= 92
				button(row, text, UDim2.fromOffset(88, 28), UDim2.new(1, x, 0, 4), color, function()
					if ask then
						confirm(text .. ": " .. tostring(m.name) .. "?", function()
							send(op, entry.id)
						end)
					else
						send(op, entry.id)
					end
				end).TextSize =
					12
			end
			if Gangs.canKick(role, m.role) then
				action(T("gang_kick"), RED, "kick", true)
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
		if canInvite then
			local box = textBox(
				page,
				T("gang_invite_player_hint"),
				UDim2.new(1, -228, 0, 36),
				UDim2.new(0, 4, 1, -40)
			)
			box.Text = draft.invite
			box:GetPropertyChangedSignal("Text"):Connect(function()
				draft.invite = box.Text
			end)
			button(
				page,
				T("gang_invite_button"),
				UDim2.fromOffset(216, 36),
				UDim2.new(1, -220, 1, -40),
				PURPLE,
				function()
					if box.Text ~= "" then
						send("invite", box.Text)
						draft.invite = ""
						box.Text = ""
					end
				end
			).Name =
				"InviteButton"
		end
	end

	-- the values of a levelled upgrade at a level (the «Что изменится» table)
	local function changeRow(u: Gangs.Upgrade, level: number): (string, string)
		local fake: any = { upgrades = { [u.id] = level }, members = {}, v2 = true }
		if u.id == "chests" then
			return T("gang_change_chests"), tostring(level * (u.effect or 0))
		elseif u.id == "members" then
			return T("gang_change_members"), tostring(Gangs.slots(fake))
		elseif u.id == "treasury" then
			return T("gang_change_treasury"), dollars(Gangs.treasuryCap(fake)) .. " $"
		end
		local pct = math.floor(Gangs.perk(fake, u.id) * 1000 + 0.5) / 10
		return T(if u.id == "stamina" then "gang_change_stamina" else "gang_change_chance"),
			string.format("%g%%", pct)
	end

	local function priceText(u: Gangs.Upgrade, cost: number): string
		return if u.currency == "money"
			then dollars(math.floor(cost * Config.moneyScale + 0.5)) .. " $"
			else T("gang_buy_points", cost)
	end

	local function drawUpgrades()
		local v = state
		local role = myRole() :: any
		for i, which in ipairs({ "boosts", "perks" }) do
			button(
				page,
				T("gang_upgrades_" .. which),
				UDim2.fromOffset(130, 26),
				UDim2.fromOffset(4 + (i - 1) * 136, 0),
				if upgradesTab == which then Ui.colors.buttonBlue else Ui.colors.buttonGrey,
				function()
					upgradesTab = which
					draw()
				end
			).Name = "Sub_"
				.. which
		end
		local list = scroller(page, UDim2.new(0, 250, 1, -32), UDim2.fromOffset(0, 32), 4)
		local shownList = {}
		for _, u in ipairs(Gangs.upgrades) do
			if u.tab == upgradesTab then
				table.insert(shownList, u)
			end
		end
		if not selected[upgradesTab] or not Gangs.upgrade(selected[upgradesTab]) then
			selected[upgradesTab] = shownList[1] and shownList[1].id
		end
		for i, u in ipairs(shownList) do
			local level = Gangs.level(v, u.id)
			local cost = Gangs.nextCost(v, u.id)
			local row = Instance.new("TextButton")
			row.Text = ""
			row.AutoButtonColor = false
			row.Size = UDim2.new(1, -10, 0, 52)
			row.BackgroundColor3 = if selected[upgradesTab] == u.id
				then Kit.CARD_HOVER
				else Kit.CARD
			row.LayoutOrder = i
			row.Name = "Up_" .. u.id
			row.Parent = list
			Kit.corner(row, 6)
			Kit.stroke(row, if selected[upgradesTab] == u.id then GOLD else Kit.EDGE, 1)
			Kit.image(row, Gangs.upgradeIcon(u), UDim2.fromOffset(38, 38), UDim2.fromOffset(7, 7)).ResampleMode =
				Enum.ResamplerMode.Pixelated
			label(
				row,
				T("gang_up_" .. u.id),
				UDim2.new(1, -56, 0, 22),
				UDim2.fromOffset(52, 4),
				15,
				Ui.colors.white
			).Font =
				Kit.BOLD
			local sub = if not cost and u.max == 1
				then Kit.colored(T("gang_upgrade_have"), Kit.GOOD)
				elseif not cost then Kit.colored(T("gang_max"), Kit.GOOD)
				elseif u.max > 1 then T("gang_level_of", level, u.max) .. " · " .. priceText(
					u,
					cost
				)
				else priceText(u, cost)
			label(row, sub, UDim2.new(1, -56, 0, 20), UDim2.fromOffset(52, 26), 12, Ui.colors.muted)
			row.Activated:Connect(function()
				selected[upgradesTab] = u.id
				draw()
			end)
		end

		-- the card of the selected upgrade
		local u = Gangs.upgrade(selected[upgradesTab] or "")
		if not u then
			return
		end
		local upgrade = u :: Gangs.Upgrade
		local level = Gangs.level(v, upgrade.id)
		local cost = Gangs.nextCost(v, upgrade.id)
		local CX = 258
		local card = Ui.card(page, UDim2.new(1, -CX, 1, -32), UDim2.fromOffset(CX, 32))
		card.Name = "UpgradeCard"
		Kit.image(
			card,
			Gangs.upgradeIcon(upgrade),
			UDim2.fromOffset(56, 56),
			UDim2.fromOffset(12, 10)
		).ResampleMode =
			Enum.ResamplerMode.Pixelated
		local title = label(
			card,
			T("gang_up_" .. upgrade.id),
			UDim2.new(1, -90, 0, 26),
			UDim2.fromOffset(78, 10),
			19,
			Ui.colors.white
		)
		title.Font = Kit.BOLD
		local subText = if upgrade.max > 1 and cost
			then T("gang_upgrade_level", level, level + 1)
			elseif cost then T("gang_upgrade_for", priceText(upgrade, cost))
			else T("gang_upgrade_have")
		label(
			card,
			subText,
			UDim2.new(1, -90, 0, 22),
			UDim2.fromOffset(78, 38),
			14,
			if cost then GOLD else Kit.GOOD
		)
		heading(card, T("gang_desc_label"), UDim2.fromOffset(12, 76), 200)
		wrapped(
			label(
				card,
				T("gang_up_text_" .. upgrade.id),
				UDim2.new(1, -24, 0, 54),
				UDim2.fromOffset(12, 98),
				13,
				Ui.colors.text
			)
		)
		local y = 156
		if upgrade.max > 1 then
			heading(card, T("gang_upgrade_change"), UDim2.fromOffset(12, y), 200)
			local box =
				Kit.frame(card, UDim2.new(1, -24, 0, 52), UDim2.fromOffset(12, y + 24), Kit.TRACK)
			Kit.corner(box, 6)
			local what, now = changeRow(upgrade, level)
			local _, nextValue = changeRow(upgrade, math.min(level + 1, upgrade.max))
			label(box, "", UDim2.fromOffset(150, 22), UDim2.fromOffset(8, 2), 12, Ui.colors.muted)
			label(
				box,
				T("gang_now"),
				UDim2.fromOffset(90, 22),
				UDim2.new(1, -196, 0, 2),
				12,
				Ui.colors.muted
			)
			label(
				box,
				T("gang_next"),
				UDim2.fromOffset(90, 22),
				UDim2.new(1, -98, 0, 2),
				12,
				Ui.colors.muted
			)
			label(
				box,
				what,
				UDim2.new(1, -210, 0, 24),
				UDim2.fromOffset(8, 24),
				14,
				Ui.colors.white
			)
			label(box, now, UDim2.fromOffset(90, 24), UDim2.new(1, -196, 0, 24), 14, Ui.colors.text)
			label(
				box,
				if cost then nextValue else "—",
				UDim2.fromOffset(90, 24),
				UDim2.new(1, -98, 0, 24),
				14,
				Kit.GOOD
			)
		end
		-- the price line and the buttons
		local rights = Gangs.can(role, "upgrade")
		local BY = -48
		if not cost then
			button(
				card,
				if upgrade.max == 1 then T("gang_up_bought") else T("gang_max"),
				UDim2.new(1, -24, 0, 38),
				UDim2.new(0, 12, 1, BY),
				Ui.colors.buttonGrey
			).Name =
				"Bought"
			return
		end
		if not rights then
			wrapped(
				label(
					card,
					T(Gangs.rightsError("upgrade")),
					UDim2.new(1, -24, 0, 20),
					UDim2.new(0, 12, 1, BY - 26),
					12,
					Kit.BAD
				)
			)
		end
		if upgrade.currency == "money" then
			local price = math.floor(cost * Config.moneyScale + 0.5)
			local p = current
			label(
				card,
				T("gang_upgrade_pay_hint"),
				UDim2.new(1, -24, 0, 20),
				UDim2.new(0, 12, 1, BY - 50),
				12,
				Ui.colors.muted
			)
			local own = rights and p ~= nil and p.coins >= price
			button(
				card,
				T("gang_upgrade_button"), -- the price is in the header «Улучшить за N $»
				UDim2.new(0.5, -16, 0, 38),
				UDim2.new(0, 12, 1, BY),
				if own then Ui.colors.buttonBlue else Ui.colors.buttonGrey,
				function()
					if rights then
						send("upgrade", { id = upgrade.id, pay = "self" })
					end
				end
			).Name =
				"BuySelf"
			local fromTreasury = rights and (v.treasury or 0) >= price
			button(
				card,
				T("gang_upgrade_treasury"),
				UDim2.new(0.5, -16, 0, 38),
				UDim2.new(0.5, 4, 1, BY),
				if fromTreasury then Ui.colors.buttonGreen else Ui.colors.buttonGrey,
				function()
					if rights then
						send("upgrade", { id = upgrade.id, pay = "treasury" })
					end
				end
			).Name =
				"BuyTreasury"
		else
			label(
				card,
				T("gang_upgrade_points_line", v.points or 0),
				UDim2.new(1, -24, 0, 20),
				UDim2.new(0, 12, 1, BY - 24),
				13,
				GOLD
			)
			button(
				card,
				T("gang_upgrade_button") .. "  " .. T("gang_buy_points", cost),
				UDim2.new(1, -24, 0, 38),
				UDim2.new(0, 12, 1, BY),
				if rights and (v.points or 0) >= cost then PURPLE else Ui.colors.buttonGrey,
				function()
					if rights then
						send("upgrade", { id = upgrade.id, pay = "points" })
					end
				end
			).Name =
				"BuyPoints"
		end
	end

	local KIND_ICONS: { [string]: string } = {
		dig = "pickaxe_diamond",
		sellItems = "money",
		pvpMoney = "money_bag",
		pvpDamage = "sword_diamond",
		bossKill = "req_kills",
		bossDamage = "req_kills",
		mobKill = "req_zombies",
		heal = "heart",
	}

	local function questCard(parentFrame: Instance, quest: any, order: number)
		local card = Ui.card(parentFrame, UDim2.new(1, -10, 0, 56), UDim2.new())
		card.LayoutOrder = order
		local kindIcon = icons[KIND_ICONS[quest.kind] or ""] or icons.gang_quests or ""
		Kit.image(card, kindIcon, UDim2.fromOffset(36, 36), UDim2.fromOffset(8, 10)).ResampleMode =
			Enum.ResamplerMode.Pixelated
		local text = label(
			card,
			Gangs.questText(quest, locale),
			UDim2.new(1, -170, 0, 22),
			UDim2.fromOffset(52, 4),
			14,
			Ui.colors.white
		)
		text.Font = Kit.BOLD
		Kit.fit(text)
		local bar = Kit.bar(
			card,
			UDim2.new(1, -230, 0, 12),
			UDim2.fromOffset(52, 32),
			if quest.done then Kit.GOOD else GOLD
		)
		bar.set(math.clamp((quest.progress or 0) / math.max(quest.target, 1), 0, 1))
		local right = if quest.done
			then T("gang_quest_done")
			else string.format(
				"%s / %s",
				Strings.grouped(math.floor(quest.progress or 0), 0),
				Strings.grouped(quest.target, 0)
			)
		label(
			card,
			right,
			UDim2.fromOffset(110, 20),
			UDim2.new(1, -172, 0, 28),
			12,
			if quest.done then Kit.GOOD else Ui.colors.muted
		)
		local reward = label(
			card,
			T("gang_quest_points", Gangs.questPoints(quest)),
			UDim2.fromOffset(60, 56),
			UDim2.new(1, -66, 0, 0),
			15,
			GOLD
		)
		reward.Font = Kit.BOLD
		reward.TextXAlignment = Enum.TextXAlignment.Right
	end

	local function drawGoal(top: number)
		local v = state
		local qcfg = cfg.quests
		local head = Ui.card(page, UDim2.new(1, -8, 0, 104), UDim2.fromOffset(4, top))
		heading(head, T("gang_goal_title"), UDim2.fromOffset(10, 6), 200, GOLD)
		local timer = label(
			head,
			"",
			UDim2.fromOffset(160, 22),
			UDim2.new(1, -170, 0, 6),
			14,
			Ui.colors.muted
		)
		timer.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(tickers, function()
			local t = nowServer()
			timer.Text = Gangs.clock(math.max(0, Gangs.nextDayAt(t) - t))
		end)
		local mult = Gangs.goalMultiplier(v, nowServer())
		local maxMult = qcfg.goal.maxMultiplier
		label(head, "x1.0", UDim2.fromOffset(40, 18), UDim2.fromOffset(10, 34), 12, Ui.colors.muted)
		local maxLabel = label(
			head,
			"x" .. string.format("%.1f", maxMult),
			UDim2.fromOffset(40, 18),
			UDim2.new(1, -50, 0, 34),
			12,
			Ui.colors.muted
		)
		maxLabel.TextXAlignment = Enum.TextXAlignment.Right
		local bar = Kit.bar(head, UDim2.new(1, -110, 0, 14), UDim2.fromOffset(54, 36), PURPLE)
		bar.set((mult - 1) / math.max(maxMult - 1, 1e-6))
		label(
			head,
			T("gang_goal_mult", string.format("%.1f", mult)),
			UDim2.fromOffset(200, 20),
			UDim2.fromOffset(10, 54),
			14,
			Ui.colors.white
		).Font =
			Kit.BOLD
		wrapped(
			label(
				head,
				T(
					"gang_goal_hint",
					Strings.grouped(qcfg.goal.blocks, 0),
					string.format("%.1f", maxMult)
				),
				UDim2.new(1, -20, 0, 28),
				UDim2.fromOffset(10, 74),
				11,
				Ui.colors.muted
			)
		)
		local list =
			scroller(page, UDim2.new(1, 0, 1, -(top + 112)), UDim2.fromOffset(0, top + 112), 4)
		local entries = {}
		for key, m in pairs(v.members) do
			table.insert(entries, { key = key, m = m, done = Gangs.goalOf(v, key, nowServer()) })
		end
		table.sort(entries, function(a, b)
			if a.done ~= b.done then
				return a.done > b.done
			end
			return tostring(a.m.name) < tostring(b.m.name)
		end)
		for i, e in ipairs(entries) do
			local row = Ui.card(list, UDim2.new(1, -10, 0, 34), UDim2.new())
			row.LayoutOrder = i
			label(
				row,
				tostring(e.m.name),
				UDim2.fromOffset(160, 34),
				UDim2.fromOffset(10, 0),
				14,
				Ui.colors.white
			)
			local full = e.done >= qcfg.goal.blocks
			local b = Kit.bar(
				row,
				UDim2.new(1, -340, 0, 10),
				UDim2.fromOffset(176, 12),
				if full then Kit.GOOD else GOLD
			)
			b.set(e.done / qcfg.goal.blocks)
			local n = label(
				row,
				Strings.grouped(e.done, 0) .. " / " .. Strings.grouped(qcfg.goal.blocks, 0),
				UDim2.fromOffset(150, 34),
				UDim2.new(1, -160, 0, 0),
				13,
				if full then Kit.GOOD else Ui.colors.muted
			)
			n.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	local function drawTasks()
		local v = state
		for i, which in ipairs({ "daily", "weekly", "goal" }) do
			button(
				page,
				if which == "goal" then T("gang_tab_tasks") else T("gang_quest_" .. which),
				UDim2.fromOffset(110, 26),
				UDim2.fromOffset(4 + (i - 1) * 114, 0),
				if tasksTab == which then Ui.colors.buttonBlue else Ui.colors.buttonGrey,
				function()
					tasksTab = which
					draw()
				end
			).Name = "Sub_"
				.. which
		end
		local openAt = Gangs.questsOpenAt(v)
		local quests = v.quests
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
		if tasksTab == "goal" then
			drawGoal(32)
			return
		end
		local timer = label(
			page,
			"",
			UDim2.fromOffset(200, 26),
			UDim2.new(1, -204, 0, 0),
			13,
			Ui.colors.muted
		)
		timer.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(tickers, function()
			local t = nowServer()
			local nextAt = if tasksTab == "daily" then Gangs.nextDayAt(t) else Gangs.nextWeekAt(t)
			timer.Text = T("gang_quests_refresh", Gangs.clock(nextAt - t))
		end)
		local list = scroller(page, UDim2.new(1, 0, 1, -32), UDim2.fromOffset(0, 32), 6)
		local order = 0
		for _, quest in ipairs(quests.list) do
			if quest.type == tasksTab then
				order += 1
				questCard(list, quest, order)
			end
		end
	end

	local function drawTreasury()
		local v = state
		local cap = Gangs.treasuryCap(v)
		local head = Ui.card(page, UDim2.new(1, -8, 0, 128), UDim2.fromOffset(4, 0))
		Kit.image(
			head,
			icons.gang_treasury or icons.money_bag or "",
			UDim2.fromOffset(44, 44),
			UDim2.fromOffset(10, 10)
		).ResampleMode =
			Enum.ResamplerMode.Pixelated
		heading(head, T("gang_treasury_header"), UDim2.fromOffset(62, 8), 200)
		local line = label(
			head,
			dollars(v.treasury or 0) .. " / " .. dollars(cap) .. " $",
			UDim2.new(1, -80, 0, 24),
			UDim2.fromOffset(62, 30),
			18,
			Ui.colors.money
		)
		line.Font = Kit.BOLD
		local bar =
			Kit.bar(head, UDim2.new(1, -20, 0, 12), UDim2.fromOffset(10, 62), Ui.colors.money)
		bar.set((v.treasury or 0) / math.max(cap, 1))
		local box = textBox(
			head,
			T("gang_amount_hint"),
			UDim2.fromOffset(150, 36),
			UDim2.fromOffset(10, 84)
		)
		box.Name = "AmountBox"
		box.Text = draft.amount
		box:GetPropertyChangedSignal("Text"):Connect(function()
			draft.amount = box.Text
		end)
		local function amount(): number?
			local n = tonumber((box.Text:gsub("[%s,$]", "")))
			return if n and n == n and n > 0 then n else nil
		end
		button(
			head,
			T("gang_deposit_button"),
			UDim2.fromOffset(170, 36),
			UDim2.fromOffset(168, 84),
			PURPLE,
			function()
				local n = amount()
				if n then
					send("deposit", n)
				end
			end
		).Name =
			"Deposit"
		local canWithdraw = Gangs.can(myRole() :: any, "withdraw")
		button(
			head,
			T("gang_withdraw_button"),
			UDim2.fromOffset(170, 36),
			UDim2.fromOffset(346, 84),
			if canWithdraw then RED else Ui.colors.buttonGrey,
			function()
				local n = amount()
				if n and canWithdraw then
					send("withdraw", n)
				end
			end
		).Name =
			"Withdraw"
		heading(page, T("gang_log_title"), UDim2.fromOffset(6, 136), 300)
		local list = scroller(page, UDim2.new(1, 0, 1, -164), UDim2.fromOffset(0, 162), 4)
		local log = v.treasuryLog or {}
		if #log == 0 then
			label(
				list,
				T("gang_log_none"),
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
				then T("gang_log_in", e.by, dollars(e.amount))
				elseif e.kind == "out" then T("gang_log_out", e.by, dollars(e.amount))
				else T(
					"gang_log_buy",
					e.by,
					T("gang_up_" .. tostring(e.what)),
					dollars(e.amount)
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

	-- ⚙ «Настройки банды»: Внешний вид, Общие, Опасная зона (the leader acts, the others see)
	local function drawSettings()
		local v = state
		local leader = myRole() == "leader"
		local card = overlay(math.min(560, CW - 20), CH - 20)
		card.Name = "GangSettings"
		heading(card, T("gang_create_title"), UDim2.fromOffset(12, 8), 300, Ui.colors.white)
		button(card, "X", UDim2.fromOffset(30, 26), UDim2.new(1, -40, 0, 6), RED, function()
			popup = nil
			draft.settingsDesc = nil
			draw()
		end).Name =
			"CloseSettings"
		local body = scroller(card, UDim2.new(1, -16, 1, -44), UDim2.fromOffset(8, 40), 0)
		local bodyList = body:FindFirstChildOfClass("UIListLayout")
		if bodyList then
			bodyList:Destroy()
		end
		body.AutomaticCanvasSize = Enum.AutomaticSize.None
		body.CanvasSize = UDim2.fromOffset(0, 520)
		heading(body, T("gang_look_title"), UDim2.fromOffset(4, 0), 300)
		local look = Ui.card(body, UDim2.new(1, -14, 0, 70), UDim2.fromOffset(4, 24))
		plate(look, v.icon, v.color, Gangs.legacy(v) and not v.newIcon, 54, UDim2.fromOffset(8, 8))
		label(
			look,
			nameTag(v.name, v.tag),
			UDim2.new(1, -80, 0, 26),
			UDim2.fromOffset(72, 10),
			17,
			Ui.colors.white
		).Font =
			Kit.BOLD
		label(
			look,
			T("gang_look_hint"),
			UDim2.new(1, -80, 0, 20),
			UDim2.fromOffset(72, 38),
			12,
			Ui.colors.muted
		)
		label(body, T("gang_icon"), UDim2.fromOffset(200, 20), UDim2.fromOffset(4, 100), 14)
		label(body, T("gang_color"), UDim2.fromOffset(180, 20), UDim2.fromOffset(232, 100), 14)
		iconGrid(
			body,
			UDim2.fromOffset(4, 122),
			if Gangs.legacy(v) and not v.newIcon then 0 else v.icon,
			function(i)
				if leader then
					send("settings", { icon = i })
				end
			end
		)
		colorGrid(body, UDim2.fromOffset(232, 122), v.color, function(i)
			if leader then
				send("settings", { color = i })
			end
		end)
		heading(body, T("gang_general_title"), UDim2.fromOffset(4, 262), 300)
		local pvp = Ui.card(body, UDim2.new(1, -14, 0, 50), UDim2.fromOffset(4, 286))
		label(
			pvp,
			T("gang_pvp_title"),
			UDim2.new(1, -150, 0, 22),
			UDim2.fromOffset(10, 4),
			15,
			Ui.colors.white
		).Font =
			Kit.BOLD
		label(
			pvp,
			T("gang_pvp_hint"),
			UDim2.new(1, -200, 0, 20),
			UDim2.fromOffset(10, 26),
			12,
			Ui.colors.muted
		)
		button(
			pvp,
			T(if v.pvp then "gang_pvp_state_on" else "gang_pvp_state_off"),
			UDim2.fromOffset(176, 32),
			UDim2.new(1, -184, 0, 9),
			if v.pvp then Ui.colors.buttonGreen else Ui.colors.buttonGrey,
			function()
				if leader then
					send("settings", { pvp = not v.pvp })
				end
			end
		).Name =
			"PvpToggle"
		local descCard = Ui.card(body, UDim2.new(1, -14, 0, 92), UDim2.fromOffset(4, 342))
		label(
			descCard,
			T("gang_desc_label"),
			UDim2.fromOffset(200, 22),
			UDim2.fromOffset(10, 4),
			15,
			Ui.colors.white
		).Font =
			Kit.BOLD
		local box = textBox(
			descCard,
			T("gang_desc_placeholder"),
			UDim2.new(1, -20, 0, 34),
			UDim2.fromOffset(10, 28)
		)
		box.Name = "SettingsDesc"
		box.Text = draft.settingsDesc or v.desc or ""
		box.TextEditable = leader
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local text = clip(box.Text, cfg.descMax)
			if text ~= box.Text then
				box.Text = text
			end
			draft.settingsDesc = text
		end)
		button(
			descCard,
			T("gang_desc_change"),
			UDim2.fromOffset(180, 24),
			UDim2.new(1, -190, 0, 64),
			if leader then Ui.colors.buttonBlue else Ui.colors.buttonGrey,
			function()
				if leader then
					send("settings", { desc = box.Text })
					draft.settingsDesc = nil
				end
			end
		).TextSize =
			12
		heading(body, T("gang_danger_title"), UDim2.fromOffset(4, 442), 300, TAG_RED)
		local danger = Ui.card(body, UDim2.new(1, -14, 0, 50), UDim2.fromOffset(4, 466))
		label(
			danger,
			T("gang_danger_hint"),
			UDim2.new(1, -200, 0, 50),
			UDim2.fromOffset(10, 0),
			13,
			Ui.colors.muted
		)
		button(
			danger,
			T("gang_disband"),
			UDim2.fromOffset(170, 32),
			UDim2.new(1, -178, 0, 9),
			if leader then RED else Ui.colors.buttonGrey,
			function()
				if leader then
					confirm(T("gang_disband_confirm", v.name), function()
						send("disband")
					end)
				end
			end
		).Name =
			"Disband"
	end

	local PAGES: { [string]: () -> () } = {
		members = drawMembers,
		upgrades = drawUpgrades,
		tasks = drawTasks,
		treasury = drawTreasury,
	}
	local TABS = { "members", "upgrades", "tasks", "treasury" }
	local TAB_KEYS = {
		members = "gang_tab_members",
		upgrades = "gang_tab_upgrades",
		tasks = "gang_tab_tasks",
		treasury = "gang_tab_treasury",
	}

	local function clear(frame: Instance)
		for _, child in ipairs(frame:GetChildren()) do
			child:Destroy()
		end
	end

	draw = function()
		-- keep the focused text box: rebuilding while typing would drop the cursor; redraw when it loses focus
		-- (only while the same page stays: a new page — the gang was created, another tab — drops the focus)
		local mode = table.concat({
			if state then "gang" elseif state == false then "none" else "wait",
			view,
			tab,
			if popup then popup.kind else "",
		}, "|")
		local focused = UserInputService:GetFocusedTextBox()
		local samePage = mode == drawnMode
		drawnMode = mode
		if focused and not samePage then
			focused:ReleaseFocus()
			focused = nil
		end
		if focused and (focused:IsDescendantOf(page) or focused:IsDescendantOf(layer)) then
			if not dirty then
				dirty = true
				focused.FocusLost:Once(function()
					dirty = false
					draw()
				end)
			end
			return
		end
		clear(side)
		clear(tabBar)
		clear(page)
		clear(layer)
		tickers = {}
		if state == nil then
			page.Position, page.Size = UDim2.new(), UDim2.fromOffset(CW, CH)
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
		if state then
			side.Visible, tabBar.Visible = true, true
			PW, PH = CW - SIDE - 8, CH - TAB_H - 6
			page.Position, page.Size =
				UDim2.fromOffset(SIDE + 8, TAB_H + 6), UDim2.fromOffset(PW, PH)
			drawSide()
			local tabW = math.floor((PW - 40 - 3 * 4) / 4)
			for i, kind in ipairs(TABS) do
				button(
					tabBar,
					T(TAB_KEYS[kind]),
					UDim2.fromOffset(tabW, TAB_H),
					UDim2.fromOffset((i - 1) * (tabW + 4), 0),
					if kind == tab then Ui.colors.buttonBlue else Ui.colors.buttonGrey,
					function()
						if tab ~= kind then
							tab = kind
							draw()
						end
					end
				).Name = "Tab_"
					.. kind
			end
			button(
				tabBar,
				"⚙",
				UDim2.fromOffset(34, TAB_H),
				UDim2.new(1, -34, 0, 0),
				Ui.colors.buttonGrey,
				function()
					popup = { kind = "settings" }
					draw()
				end
			).Name =
				"Tab_settings"
			PAGES[tab]()
		else
			side.Visible, tabBar.Visible = false, false
			PW, PH = CW, CH
			page.Position, page.Size = UDim2.new(), UDim2.fromOffset(CW, CH)
			if view == "create" then
				drawCreate()
			elseif view == "invites" then
				drawInvites()
			else
				drawNone()
			end
		end
		if popup and popup.kind == "settings" and state then
			drawSettings()
		elseif popup and popup.kind == "confirm" then
			drawConfirm()
		elseif popup then
			popup = nil
		end
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
			local before = current
			current = p
			local hadGang = before ~= nil and before.gang ~= nil and before.gang.id ~= nil
			local hasGang = p ~= nil and p.gang ~= nil and p.gang.id ~= nil
			local moneyMoved = (before and before.coins) ~= (p and p.coins)
				or (before and before.crystals) ~= (p and p.crystals)
			if hadGang ~= hasGang or (moneyMoved and (view == "create" or tab == "upgrades")) then
				draw()
			end
		end
end

return GangWindow
