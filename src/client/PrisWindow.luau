--!strict
-- «PRIS+» (/pp, /mining, the menu tile; этап 8) [клиент prison_plus.*, donate.list.subscribe.description]: on top the
-- term («Активна ещё 12 д 5 ч») or «Для начала приобретите подписку в /donate» with the button to the donate shop's
-- PRIS+ tab; then the switches — Автокопание, Ночь, AppleSkin, Эффекты чар (profile.settings through SetSetting;
-- PrisPerks / EnchantFx act on them); then two boards [клиент prison_plus.gui.*]:
--   «Респавн шахт» — every mine location: its blocks, «Кулдаун респавна», «Время до респавна» (or «< 5 мин»),
--     «Телепортироваться на шахту»; the timers come from the server (PrisQuery "mines", PrisService) every 5 s and
--     count down here between the answers;
--   «Респавн боссов» — every boss: possible rewards (money, ancient stars, «Древний порошок (1-50⁒)»), «Босс возрождён»
--     or the time left (ReplicatedStorage.Bosses, BossService), «Телепортироваться на локацию босса».
-- A location above the player's level says «Повышайте уровень…». Without PRIS+ the switches and the boards are
-- replaced by the list of what it gives. Dark inventory style (WindowKit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)

local PrisWindow = {}

local W, H = 680, 580
local PAD = 10
local ROW_H = 70
local GOLD = Color3.fromRGB(255, 190, 40)
local SWITCHES = {
	{ key = "autoDig", caption = "pris_autodig", invert = false },
	{ key = "night", caption = "pris_night", invert = false },
	{ key = "appleSkinOff", caption = "pris_appleskin", invert = true },
	{ key = "enchantFxOff", caption = "pris_enchant_fx", invert = true },
}

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s % 3600) // 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

local function term(seconds: number, locale: string): string
	local d, h, m = PrisPlus.split(seconds)
	if d > 0 then
		return Strings.t("pris_term_days", locale, d, h)
	end
	return Strings.t("pris_term_hours", locale, h, m)
end

function PrisWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow,
	openKind: (string) -> ()
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(parent, T("pris_title"), UDim2.fromOffset(W, H), onClose)
	win.Name = "Window_Pris"
	Ui.titleColor(win, GOLD)
	local current = profile
	local player = Players.LocalPlayer

	-- ── the term ──
	local header = Kit.frame(content, UDim2.new(1, -8, 0, 64), UDim2.fromOffset(4, 2), Kit.CARD)
	Kit.corner(header, 12)
	Kit.stroke(header, Kit.EDGE, 1.5)
	Kit.gradient(header, GOLD:Lerp(Kit.CARD, 0.7), Kit.CARD, 0)
	local crown = Kit.image(
		header,
		Config.icons.icons.menu_pris or Config.icons.icons.top_crown,
		UDim2.fromOffset(44, 44),
		UDim2.fromOffset(12, 10)
	)
	crown.ScaleType = Enum.ScaleType.Fit
	Kit.bob(crown, 3, 2.4)
	Kit.text(
		header,
		T("pris_title"),
		UDim2.fromOffset(200, 24),
		UDim2.fromOffset(66, 8),
		22,
		GOLD,
		Kit.BOLD
	)
	local status = Kit.text(
		header,
		"",
		UDim2.new(1, -280, 0, 20),
		UDim2.fromOffset(66, 34),
		14,
		Ui.colors.text
	)
	Kit.fit(status)
	local buyButton, buyLabel, buyBack =
		Kit.actionButton(header, UDim2.fromOffset(180, 40), UDim2.new(1, -192, 0, 12), 17)
	Kit.gradient(buyBack, GOLD, GOLD:Lerp(Color3.new(), 0.4), 90)
	Kit.fit(buyLabel)
	Kit.pressable(buyButton)
	buyButton.Activated:Connect(function()
		require(script.Parent.DonateWindow).startTab = "pris"
		openKind("donate")
	end)

	-- ── the switches ──
	local switchRow = Kit.frame(content, UDim2.new(1, -8, 0, 44), UDim2.fromOffset(4, 74), Kit.CARD)
	switchRow.BackgroundTransparency = 1
	local switchW = (W - 20 - 3 * 8) / #SWITCHES
	type Switch = { label: TextLabel, gradient: UIGradient }
	local switches: { [string]: Switch } = {}
	for i, s in ipairs(SWITCHES) do
		local button, label, back = Kit.actionButton(
			switchRow,
			UDim2.fromOffset(switchW, 40),
			UDim2.fromOffset((i - 1) * (switchW + 8), 0),
			13
		)
		Kit.fit(label)
		Kit.pressable(button)
		switches[s.key] = { label = label, gradient = Kit.gradient(back, Kit.GREY, Kit.GREY, 90) }
		button.Activated:Connect(function()
			local settings = current and current.settings :: any
			local value = settings ~= nil and settings[s.key] == true
			Remotes.event("SetSetting"):FireServer(s.key, not value)
		end)
	end

	-- ── what PRIS+ gives (without it) ──
	local perks = Kit.text(
		content,
		T("pris_perks"),
		UDim2.new(1, -2 * PAD, 1, -140),
		UDim2.fromOffset(PAD, 128),
		15,
		Ui.colors.text
	)
	perks.TextWrapped = true
	perks.TextYAlignment = Enum.TextYAlignment.Top

	-- ── the boards ──
	local tabRow = Kit.frame(content, UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 124), Kit.CARD)
	tabRow.BackgroundTransparency = 1
	local board = "mines"
	type Tab = { button: TextButton, edge: UIStroke }
	local tabs: { [string]: Tab } = {}
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -8, 1, -170)
	list.Position = UDim2.fromOffset(4, 164)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Kit.EDGE
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content

	type Row = { status: TextLabel, button: TextButton, label: TextLabel, update: (number) -> () }
	local rows: { Row } = {}
	local timers: { [string]: { left: number, cycle: number, at: number } } = {}
	local fillBoard: () -> () = function() end
	local ask: () -> () = function() end

	local function row(
		index: number,
		title: string,
		info: string
	): (Frame, TextLabel, TextButton, TextLabel)
		local f = Kit.frame(
			list,
			UDim2.new(1, -10, 0, ROW_H - 6),
			UDim2.fromOffset(2, (index - 1) * ROW_H + 2),
			Kit.CARD
		)
		Kit.corner(f, 10)
		Kit.stroke(f, Kit.EDGE, 1)
		Kit.hoverable(f)
		local name = Kit.text(
			f,
			title,
			UDim2.new(1, -230, 0, 20),
			UDim2.fromOffset(12, 6),
			15,
			Ui.colors.text,
			Kit.BOLD
		)
		Kit.fit(name)
		local details = Kit.text(
			f,
			info,
			UDim2.new(1, -230, 0, 16),
			UDim2.fromOffset(12, 26),
			12,
			Ui.colors.muted
		)
		Kit.fit(details)
		local state = Kit.text(
			f,
			"",
			UDim2.new(1, -230, 0, 16),
			UDim2.fromOffset(12, 44),
			12,
			Ui.colors.text,
			Kit.BOLD
		)
		Kit.fit(state)
		local button, label, back =
			Kit.actionButton(f, UDim2.fromOffset(200, 40), UDim2.new(1, -210, 0, 12), 13)
		Kit.gradient(back, Kit.GOOD, Kit.GOOD:Lerp(Color3.new(), 0.4), 90)
		Kit.fit(label)
		Kit.pressable(button)
		return f, state, button, label
	end

	local function teleportRow(
		index: number,
		title: string,
		info: string,
		location: Config.Location?,
		buttonKey: string,
		update: (TextLabel, number) -> ()
	)
		local _, state, button, label = row(index, title, info)
		local level = if current then current.level else 1
		local locked = location ~= nil and level < location.unlockLevel
		label.Text = if locked
			then T("pris_level_locked", (location :: Config.Location).unlockLevel)
			else T(buttonKey)
		button.Activated:Connect(function()
			if location and not locked then
				Remotes.event("Teleport"):FireServer(location.id)
				onClose()
			end
		end)
		if locked then
			button.AutoButtonColor = false
			label.TextTransparency = 0.35
		end
		table.insert(rows, {
			status = state,
			button = button,
			label = label,
			update = function(t: number)
				update(state, t)
			end,
		})
	end

	local function fillMines()
		local locations = {}
		for _, location in ipairs(Config.locationsFile.locations :: { Config.Location }) do
			if location.kind == "mine" then
				table.insert(locations, location)
			end
		end
		table.sort(locations, function(a, b)
			return if a.unlockLevel == b.unlockLevel
				then a.id < b.id
				else a.unlockLevel < b.unlockLevel
		end)
		for i, location in ipairs(locations) do
			local names = {}
			for blockId in pairs(location.mine.shares) do
				local block = Config.block(blockId)
				if block then
					table.insert(names, Strings.blockName(blockId, block.name, locale))
				end
			end
			table.sort(names)
			local info = T("pris_mine_blocks", table.concat(names, ", "))
				.. "  ·  "
				.. T("pris_mine_cooldown", clock(location.mine.resetSeconds))
			teleportRow(
				i,
				Strings.locationName(location.name, locale),
				info,
				location,
				"pris_mine_teleport",
				function(state: TextLabel, t: number)
					local timer = timers[location.id]
					if not timer then
						state.Text = T("pris_mine_unknown")
						state.TextColor3 = Ui.colors.muted
						return
					end
					local left = timer.left - (t - timer.at)
					while left < 0 and timer.cycle > 0 do
						left += timer.cycle -- the reset came: the next cycle runs (an answer every 5 s corrects it)
					end
					state.Text = if left < PrisPlus.cfg.soonSeconds
						then T("pris_mine_left", T("pris_mine_soon")) .. "  ·  " .. clock(left)
						else T("pris_mine_left", clock(left))
					state.TextColor3 = if left < PrisPlus.cfg.soonSeconds
						then GOLD
						else Ui.colors.text
				end
			)
		end
		return #locations
	end

	local function bossName(card: any): string
		return if locale == "ru" then card.name else card.nameEn or card.name
	end

	local function fillBosses()
		local cards = table.clone(Config.bosses.bosses :: { any })
		table.sort(cards, function(a, b)
			return if a.unlockLevel == b.unlockLevel
				then a.id < b.id
				else a.unlockLevel < b.unlockLevel
		end)
		for i, card in ipairs(cards) do
			local location = Config.location(card.locationId)
			local rewards = {}
			if typeof(card.money) == "table" and (card.money[2] or 0) > 0 then
				table.insert(
					rewards,
					T(
						"pris_boss_money",
						Strings.big(card.money[1] or 0),
						Strings.big(card.money[2])
					)
				)
			end
			if typeof(card.ancientStars) == "table" then
				table.insert(
					rewards,
					T("pris_boss_stars", card.ancientStars[1] or 0, card.ancientStars[2] or 0)
				)
			end
			local powder = card.powderChance and card.powderChance.percentQualifier
			if typeof(powder) == "table" and powder.min and powder.max then
				table.insert(rewards, T("pris_boss_powder", powder.min, powder.max))
			end
			local place = if location then Strings.locationName(location.name, locale) else ""
			teleportRow(
				i,
				bossName(card) .. Kit.colored("  ·  " .. place, Ui.colors.muted),
				T("pris_boss_rewards", table.concat(rewards, ", ")),
				location,
				"pris_boss_teleport",
				function(state: TextLabel, t: number)
					local folder = ReplicatedStorage:FindFirstChild("Bosses")
					local boss = folder and folder:FindFirstChild(card.id)
					if not boss then
						state.Text = T("pris_mine_unknown")
						state.TextColor3 = Ui.colors.muted
					elseif boss:GetAttribute("Alive") == true then
						state.Text = T("pris_boss_alive")
						state.TextColor3 = Kit.GOOD
					else
						local at = tonumber(boss:GetAttribute("RespawnAt")) or 0
						state.Text = T("pris_boss_left", clock(at - t))
						state.TextColor3 = Ui.colors.text
					end
				end
			)
		end
		return #cards
	end

	local function tick()
		local t = workspace:GetServerTimeNow()
		for _, r in ipairs(rows) do
			r.update(t)
		end
	end

	fillBoard = function()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(rows)
		local n = if board == "mines" then fillMines() else fillBosses()
		list.CanvasSize = UDim2.fromOffset(0, n * ROW_H + 4)
		list.CanvasPosition = Vector2.zero
		for id, tab in pairs(tabs) do
			tab.button.BackgroundColor3 = if id == board
				then GOLD:Lerp(Kit.CARD, 0.55)
				else Kit.CARD
			tab.edge.Color = if id == board then GOLD else Kit.EDGE
		end
		tick()
	end
	for i, id in ipairs({ "mines", "bosses" }) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Size = UDim2.new(0.5, -4, 1, 0)
		button.Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0)
		button.BackgroundColor3 = Kit.CARD
		button.Font = Kit.BOLD
		button.TextSize = 15
		button.TextColor3 = Ui.colors.text
		button.Text = T("pris_board_" .. id)
		button.Parent = tabRow
		Kit.corner(button, 9)
		local edge = Kit.stroke(button, Kit.EDGE, 1.5)
		Kit.pressable(button)
		tabs[id] = { button = button, edge = edge }
		button.Activated:Connect(function()
			if board ~= id then
				board = id
				fillBoard()
				ask()
			end
		end)
	end

	-- the mine timers: asked every 5 s while the board is open (the server answers PRIS+ players only)
	local asking = false
	ask = function()
		if asking or board ~= "mines" or not PrisPlus.of(player) then
			return
		end
		asking = true
		task.spawn(function()
			local ok, answer = pcall(function()
				return Remotes.func("PrisQuery"):InvokeServer("mines")
			end)
			asking = false
			if not ok or typeof(answer) ~= "table" or typeof(answer.mines) ~= "table" then
				return
			end
			local t = workspace:GetServerTimeNow()
			table.clear(timers)
			for _, m in ipairs(answer.mines) do
				local left = tonumber(m.left) or 0
				local old = timers[m.location]
				-- a location with several mines (Подвал): the soonest one
				if typeof(m.location) == "string" and (not old or left < old.left) then
					timers[m.location] = { left = left, cycle = tonumber(m.cycle) or 0, at = t }
				end
			end
			tick()
		end)
	end

	local shownActive: boolean? = nil
	local function render()
		local p = current
		local active = PrisPlus.of(player)
		local left = PrisPlus.left(p, workspace:GetServerTimeNow())
		status.Text = if active and left > 0
			then T("pris_active", term(left, locale))
			elseif active then T("pris_active_sub")
			else T("pris_need")
		buyLabel.Text = if active then T("pris_extend") else T("pris_buy")
		local settings = (p and p.settings or {}) :: any
		for _, s in ipairs(SWITCHES) do
			local value = settings[s.key] == true
			local on = if s.invert then not value else value
			local entry = switches[s.key]
			entry.label.Text = T(s.caption)
				.. ": "
				.. T(if on then "settings_on" else "settings_off")
			local c = if on then Kit.GOOD else Kit.GREY
			entry.gradient.Color = ColorSequence.new(c, c:Lerp(Color3.new(), 0.35))
		end
		if shownActive ~= active then
			shownActive = active
			switchRow.Visible = active
			tabRow.Visible = active
			list.Visible = active
			perks.Visible = not active
			if active then
				fillBoard()
				ask()
			end
		end
	end

	local elapsed, sinceAsk = 0, 0
	local ticker = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sinceAsk += dt
		if elapsed >= 1 then
			elapsed = 0
			render()
			if shownActive then
				tick()
			end
		end
		if sinceAsk >= 5 then
			sinceAsk = 0
			ask()
		end
	end)
	win.Destroying:Once(function()
		ticker:Disconnect()
	end)

	render()
	return win, function(nextProfile: Types.Profile?)
		current = nextProfile
		render()
	end
end

return PrisWindow
