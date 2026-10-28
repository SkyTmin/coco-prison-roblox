--!strict
-- The TAB list (этап 9; docs/research/remaining-features-design.md, facts §9) [вики MENUS-SOCIAL: «(48 ур.) <ранг> ник
-- <тег банды>»; клиент tab.suffix «(%s%d ур.)»]: Tab on a computer, «Игроки» in the menu / the phone grid; Roblox's own
-- player list is switched off (init.client). Left: everyone on this server grouped by faction (the list order of
-- Config.factions, «Без фракции» last), highest level first; a row = rank emblem, «(48 ур.)» in the faction colour,
-- [PRIS+], the display name, the nickname in its tier colour and the gang tag in the gang colour — all from the
-- player attributes (Level, Faction, Nick, GangTag, GangColor, PrisPlus), so it stays live (checked once a second).
-- Right: the card of the picked player [клиент chat.message.hover.user]: faction, gang, nickname, then Блоков / Крыс /
-- Убийств / Смертей asked from the server (PlayerCard → PlayerCardService) and the quick actions — /pay with an
-- amount, /gift (the item in hand), invite to the gang (when the server says this player's role may and the other has
-- no gang; GangAction "invite"), /thx when he runs a shared booster, hide him for this session (HidePlayers), Roblox's
-- friend request and block prompts. The server answers /pay, /gift, /thx in the chat. The chat opens a card through
-- PlayerListWindow.focusUser (a click on a player's line).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Nicknames = require(Shared.Nicknames)
local PrisPlus = require(Shared.PrisPlus)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)
local HidePlayers = require(script.Parent.HidePlayers)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)

local PlayerListWindow = {}

-- the player whose card opens with the next build (the chat sets it)
PlayerListWindow.focusUser = nil :: number?

local PAD, LIST_W, CARD_W, H = 12, 340, 292, 420
local ROW_H, HEAD_H = 26, 22
local PRIS = Color3.fromRGB(255, 190, 40)
local ME = Color3.fromRGB(34, 44, 40)

local function attr(player: Player, name: string, kind: string): any
	local value = player:GetAttribute(name)
	return if typeof(value) == kind then value else nil
end

local function levelOf(player: Player): number
	return attr(player, "Level", "number") or 1
end

local function factionOf(player: Player): string?
	local f = attr(player, "Faction", "string")
	return if Config.faction(f) then f else nil
end

-- what a row shows; a change of it repaints the list
local function signature(player: Player): string
	return table.concat({
		tostring(player.UserId),
		player.DisplayName,
		tostring(levelOf(player)),
		factionOf(player) or "",
		attr(player, "Nick", "string") or "",
		attr(player, "GangTag", "string") or "",
		tostring(attr(player, "GangColor", "number") or 0),
		if PrisPlus.of(player) then "p" else "",
		if HidePlayers.isPlayerHidden(player.UserId) then "h" else "",
	}, "|")
end

function PlayerListWindow.build(
	parent: Instance,
	_profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local me = Players.LocalPlayer
	local width = PAD + LIST_W + 10 + CARD_W + PAD
	local win, content =
		createWindow(parent, T("players_title"), UDim2.fromOffset(width + 12, H + 52), onClose)
	win.Name = "Window_Players"
	Ui.titleColor(win, Ui.colors.header)

	-- ── the list ────────────────────────────────────────────────────────────────────────────────────────────────
	local online = Kit.text(
		content,
		"",
		UDim2.fromOffset(LIST_W, 18),
		UDim2.fromOffset(PAD, 4),
		13,
		Ui.colors.text,
		Kit.BOLD
	)
	local ping = Kit.text(
		content,
		"",
		UDim2.fromOffset(LIST_W, 18),
		UDim2.fromOffset(PAD, 4),
		12,
		Ui.colors.muted
	)
	ping.TextXAlignment = Enum.TextXAlignment.Right
	local listBack =
		Kit.frame(content, UDim2.fromOffset(LIST_W, H - 30), UDim2.fromOffset(PAD, 26), Kit.TRACK)
	Kit.corner(listBack, 8)
	Kit.stroke(listBack, Kit.EDGE, 1, 0.3)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -8, 1, -8)
	scroll.Position = UDim2.fromOffset(4, 4)
	scroll.ScrollBarThickness = 5
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = listBack
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll

	-- ── the card ────────────────────────────────────────────────────────────────────────────────────────────────
	local cardBack = Kit.frame(
		content,
		UDim2.fromOffset(CARD_W, H - 8),
		UDim2.fromOffset(PAD + LIST_W + 10, 4),
		Kit.CARD
	)
	Kit.corner(cardBack, 10)
	Kit.stroke(cardBack, Kit.EDGE, 1)

	local selected: number? = PlayerListWindow.focusUser
	PlayerListWindow.focusUser = nil
	local cardData: { [string]: any }? = nil
	local loading = false
	local amountText = ""
	local alive = true

	local drawCard: () -> ()
	local redraw: () -> ()

	local function line(parentFrame: Instance, y: number, key: string, value: string)
		Kit.text(
			parentFrame,
			T(key),
			UDim2.fromOffset(90, 18),
			UDim2.fromOffset(12, y),
			13,
			Ui.colors.muted
		)
		local v = Kit.text(
			parentFrame,
			value,
			UDim2.new(1, -110, 0, 18),
			UDim2.fromOffset(100, y),
			13,
			Ui.colors.text,
			Kit.BOLD
		)
		Kit.fit(v)
	end

	local function smallButton(
		parentFrame: Instance,
		text: string,
		size: UDim2,
		position: UDim2,
		color: Color3,
		onPress: () -> ()
	): TextButton
		local b = Ui.button(parentFrame, text, size, position, color)
		b.TextSize = 13
		Kit.pressable(b)
		b.Activated:Connect(onPress)
		return b
	end

	local asked = 0 -- the newest request wins: an answer for a player no longer picked is dropped
	local function request(userId: number)
		asked += 1
		local mine = asked
		loading = true
		task.spawn(function()
			local data: any = nil
			for _ = 1, 2 do -- the server refuses a second card within 0.25 s: one retry
				local ok, result = pcall(function()
					return Remotes.func("PlayerCard"):InvokeServer(userId)
				end)
				data = if ok and typeof(result) == "table" then result else nil
				if data or not alive or mine ~= asked then
					break
				end
				task.wait(0.3)
			end
			if mine ~= asked then
				return
			end
			loading = false
			if alive and selected == userId then
				cardData = data
				drawCard()
			end
		end)
	end

	local function thxAvailable(target: Player): boolean
		local now = Boosters.now()
		for _, a in ipairs(Boosters.shared()) do
			if a.by == target.Name and a.startsAt <= now and now < a.endsAt then
				return true
			end
		end
		return false
	end

	drawCard = function()
		for _, child in ipairs(cardBack:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end
		local target = if selected then Players:GetPlayerByUserId(selected) else nil
		if not selected or not target then
			local hint = Kit.text(
				cardBack,
				if selected then T("card_gone") else T("players_pick"),
				UDim2.new(1, -24, 1, 0),
				UDim2.fromOffset(12, 0),
				14,
				Ui.colors.muted
			)
			hint.TextWrapped = true
			hint.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		local level = levelOf(target)
		local rank = Ranks.of(level)
		local faction = factionOf(target)

		-- the head: picture, names, rank
		local face = Kit.image(cardBack, "", UDim2.fromOffset(60, 60), UDim2.fromOffset(12, 12))
		face.BackgroundColor3 = Kit.TRACK
		face.BackgroundTransparency = 0
		face.ResampleMode = Enum.ResamplerMode.Default
		Kit.corner(face, 8)
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					target.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
			end)
			if ok and face.Parent then
				face.Image = image
			end
		end)
		local name = Kit.text(
			cardBack,
			(if PrisPlus.of(target) then Kit.colored(T("pris_tag") .. " ", PRIS) else "")
				.. Chat.escape(target.DisplayName),
			UDim2.new(1, -92, 0, 22),
			UDim2.fromOffset(82, 12),
			17,
			Ui.colors.white,
			Kit.BOLD
		)
		Kit.fit(name)
		Kit.text(
			cardBack,
			"@" .. target.Name,
			UDim2.new(1, -92, 0, 16),
			UDim2.fromOffset(82, 34),
			12,
			Ui.colors.muted
		)
		local emblem = Kit.image(
			cardBack,
			Config.icons.icons[Ranks.icon(rank)],
			UDim2.fromOffset(16, 16),
			UDim2.fromOffset(82, 53)
		)
		emblem.Visible = Config.icons.icons[Ranks.icon(rank)] ~= nil
		Kit.text(
			cardBack,
			Kit.colored(T("rank_" .. rank.index), rank.color)
				.. "  "
				.. Kit.colored(
					T("players_level", level),
					if faction then Config.factionColor(faction) else Ui.colors.text
				),
			UDim2.new(1, -112, 0, 16),
			UDim2.fromOffset(102, 53),
			13,
			Ui.colors.text,
			Kit.BOLD
		)

		-- faction, gang, nickname
		local gangTag = attr(target, "GangTag", "string")
		local gangText = T("card_none")
		if gangTag then
			gangText = Kit.colored(
				"[" .. Chat.escape(gangTag) .. "]",
				Gangs.color(attr(target, "GangColor", "number"))
			)
			if cardData and typeof(cardData.gang) == "string" then
				gangText ..= " " .. Chat.escape(cardData.gang)
			end
		end
		local nick = attr(target, "Nick", "string")
		line(
			cardBack,
			84,
			"card_faction",
			if faction
				then Kit.colored(T("faction_" .. faction), Config.factionColor(faction))
				else T("faction_none")
		)
		line(cardBack, 104, "card_gang", gangText)
		line(
			cardBack,
			124,
			"card_nick",
			if nick then Kit.colored(Chat.escape(nick), Nicknames.color(nick)) else T("card_none")
		)

		-- the numbers
		local stats = {
			{ "card_blocks", "blocks" },
			{ "card_rats", "rats" },
			{ "card_kills", "kills" },
			{ "card_deaths", "deaths" },
		}
		for i, s in ipairs(stats) do
			local column, row = (i - 1) % 2, (i - 1) // 2
			local box = Kit.frame(
				cardBack,
				UDim2.fromOffset(129, 38),
				UDim2.fromOffset(12 + column * 139, 148 + row * 44),
				Kit.TRACK
			)
			Kit.corner(box, 6)
			Kit.text(
				box,
				T(s[1]),
				UDim2.new(1, -12, 0, 14),
				UDim2.fromOffset(8, 3),
				11,
				Ui.colors.muted
			)
			local value = cardData and cardData[s[2]]
			Kit.text(
				box,
				if typeof(value) == "number"
					then Strings.big(value)
					elseif loading then T("card_loading")
					else "—",
				UDim2.new(1, -12, 0, 18),
				UDim2.fromOffset(8, 17),
				15,
				Ui.colors.white,
				Kit.BOLD
			)
		end

		if target == me then
			local you = Kit.text(
				cardBack,
				T("card_you"),
				UDim2.new(1, -24, 0, 20),
				UDim2.fromOffset(12, 250),
				14,
				Kit.GOOD,
				Kit.BOLD
			)
			you.TextXAlignment = Enum.TextXAlignment.Center
			return
		end

		-- the quick actions
		Kit.text(
			cardBack,
			T("card_actions"),
			UDim2.new(1, -24, 0, 18),
			UDim2.fromOffset(12, 240),
			13,
			Ui.colors.header,
			Kit.BOLD
		)
		local amount = Instance.new("TextBox")
		amount.Size = UDim2.fromOffset(150, 28)
		amount.Position = UDim2.fromOffset(12, 262)
		amount.BackgroundColor3 = Kit.TRACK
		amount.BorderSizePixel = 0
		amount.ClearTextOnFocus = false
		amount.Font = Kit.TEXT
		amount.TextSize = 14
		amount.TextColor3 = Ui.colors.white
		amount.PlaceholderText = T("card_amount")
		amount.PlaceholderColor3 = Ui.colors.muted
		amount.Text = amountText
		amount.Parent = cardBack
		Kit.corner(amount, 6)
		Kit.stroke(amount, Kit.EDGE, 1)
		amount:GetPropertyChangedSignal("Text"):Connect(function()
			local clean = amount.Text:gsub("[^%d%.,]", "")
			if clean ~= amount.Text then
				amount.Text = clean
			end
			amountText = clean
		end)
		local toast = function()
			-- the server's answer arrives in the chat; a short line here says where to look
			StarterGui:SetCore(
				"SendNotification",
				{ Title = T("players_title"), Text = T("card_sent") }
			)
		end
		smallButton(
			cardBack,
			T("card_pay"),
			UDim2.fromOffset(112, 28),
			UDim2.fromOffset(168, 262),
			Ui.colors.buttonGreen,
			function()
				local n = tonumber((amountText:gsub(",", ".")))
				if n and n > 0 then
					Remotes.event("ChatCommand"):FireServer("pay", { target.Name, tostring(n) })
					pcall(toast)
				end
			end
		)
		type Action = { text: string, color: Color3, press: () -> () }
		local actions: { Action } = {
			{
				text = T("card_gift"),
				color = Ui.colors.buttonBlue,
				press = function()
					Remotes.event("ChatCommand"):FireServer("gift", { target.Name })
					pcall(toast)
				end,
			},
		}
		if cardData and cardData.canInvite == true then
			table.insert(actions, {
				text = T("card_invite"),
				color = Ui.colors.buttonBlue,
				press = function()
					Remotes.event("GangAction"):FireServer("invite", target.Name)
				end,
			})
		end
		if thxAvailable(target) then
			table.insert(actions, {
				text = T("card_thx"),
				color = Ui.colors.buttonGreen,
				press = function()
					Remotes.event("ChatCommand"):FireServer("thx", {})
					pcall(toast)
				end,
			})
		end
		local hiddenNow = HidePlayers.isPlayerHidden(target.UserId)
		table.insert(actions, {
			text = if hiddenNow then T("card_show") else T("card_hide"),
			color = Ui.colors.buttonGrey,
			press = function()
				HidePlayers.setPlayer(target.UserId, not hiddenNow)
				drawCard()
			end,
		})
		table.insert(actions, {
			text = T("card_friend"),
			color = Ui.colors.buttonGrey,
			press = function()
				pcall(function()
					StarterGui:SetCore("PromptSendFriendRequest", target)
				end)
			end,
		})
		table.insert(actions, {
			text = T("card_block"),
			color = Ui.colors.close,
			press = function()
				pcall(function()
					StarterGui:SetCore("PromptBlockPlayer", target)
				end)
			end,
		})
		for i, a in ipairs(actions) do
			local column, row = (i - 1) % 2, (i - 1) // 2
			smallButton(
				cardBack,
				a.text,
				UDim2.fromOffset(129, 30),
				UDim2.fromOffset(12 + column * 139, 298 + row * 36),
				a.color,
				a.press
			)
		end
	end

	local function pick(userId: number)
		if selected == userId and cardData then
			return
		end
		selected = userId
		cardData = nil
		amountText = ""
		request(userId) -- first: the card says «Загрузка…» while it waits
		drawCard()
		redraw() -- the picked row lights up
	end

	-- ── the rows ────────────────────────────────────────────────────────────────────────────────────────────────
	local shown = ""
	local function rowText(player: Player): string
		local faction = factionOf(player)
		local parts = {
			Kit.colored(
				T("players_level", levelOf(player)),
				if faction
					then Config.factionColor(faction):Lerp(Color3.new(1, 1, 1), 0.15)
					else Ui.colors.text
			),
		}
		if PrisPlus.of(player) then
			table.insert(parts, Kit.colored(T("pris_tag"), PRIS))
		end
		table.insert(parts, "<b>" .. Chat.escape(player.DisplayName) .. "</b>")
		local nick = attr(player, "Nick", "string")
		if nick then
			table.insert(parts, Kit.colored(Chat.escape(nick), Nicknames.color(nick)))
		end
		local tag = attr(player, "GangTag", "string")
		if tag then
			table.insert(
				parts,
				Kit.colored(
					"[" .. Chat.escape(tag) .. "]",
					Gangs.color(attr(player, "GangColor", "number"))
				)
			)
		end
		return table.concat(parts, " ")
	end

	redraw = function()
		local all = Players:GetPlayers()
		local sigs = {}
		for _, p in ipairs(all) do
			table.insert(sigs, signature(p))
		end
		table.sort(sigs)
		local sig = table.concat(sigs, "\n") .. "\n" .. tostring(selected)
		if sig == shown then
			return
		end
		shown = sig
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		online.Text = T("players_online", #all, Players.MaxPlayers)
		-- groups: the factions in the config's order, then no faction
		local groups: { { id: string?, players: { Player } } } = {}
		for _, f in ipairs(Config.factions.list) do
			table.insert(groups, { id = f.id, players = {} })
		end
		local none = { id = nil :: string?, players = {} :: { Player } }
		table.insert(groups, none)
		for _, p in ipairs(all) do
			local f = factionOf(p)
			local placed = false
			for _, g in ipairs(groups) do
				if f and g.id == f then
					table.insert(g.players, p)
					placed = true
					break
				end
			end
			if not placed then
				table.insert(none.players, p)
			end
		end
		local order = 0
		for _, g in ipairs(groups) do
			if #g.players > 0 then
				table.sort(g.players, function(a, b)
					local la, lb = levelOf(a), levelOf(b)
					if la ~= lb then
						return la > lb
					end
					return a.DisplayName:lower() < b.DisplayName:lower()
				end)
				order += 1
				local color = if g.id then Config.factionColor(g.id) else Ui.colors.muted
				local head = Kit.text(
					scroll,
					(if g.id then T("faction_" .. g.id) else T("players_no_faction"))
						.. "  "
						.. Kit.colored(tostring(#g.players), Ui.colors.muted),
					UDim2.new(1, -6, 0, HEAD_H),
					UDim2.new(),
					13,
					color,
					Kit.BOLD
				)
				head.LayoutOrder = order
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 6)
				pad.Parent = head
				for _, p in ipairs(g.players) do
					order += 1
					local isMe = p == me
					local base = if p.UserId == selected
						then Kit.CARD_HOVER
						elseif isMe then ME
						else Kit.CARD
					local row = Instance.new("TextButton")
					row.AutoButtonColor = false
					row.Text = ""
					row.Size = UDim2.new(1, -6, 0, ROW_H)
					row.BackgroundColor3 = base
					row.BorderSizePixel = 0
					row.LayoutOrder = order
					row.Parent = scroll
					Kit.corner(row, 5)
					Kit.hoverable(row, base, Kit.CARD_HOVER)
					local icon = Config.icons.icons[Ranks.icon(Ranks.of(levelOf(p)))]
					local emblem =
						Kit.image(row, icon, UDim2.fromOffset(18, 18), UDim2.fromOffset(5, 4))
					emblem.Visible = icon ~= nil
					local label = Kit.text(
						row,
						rowText(p),
						UDim2.new(1, -32, 1, 0),
						UDim2.fromOffset(28, 0),
						13,
						Ui.colors.white
					)
					label.TextTruncate = Enum.TextTruncate.AtEnd
					if HidePlayers.isPlayerHidden(p.UserId) then
						label.TextTransparency = 0.5
					end
					row.Activated:Connect(function()
						pick(p.UserId)
					end)
				end
			end
		end
	end

	-- live: the rows once a second (attributes, joins, leaves), the ping, a card whose player left
	local elapsed = 0
	local ticker = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		redraw()
		ping.Text = T("players_ping", math.floor(me:GetNetworkPing() * 1000 + 0.5))
		if selected and not Players:GetPlayerByUserId(selected) and cardData then
			cardData = nil
			drawCard()
		end
	end)
	win.Destroying:Once(function()
		alive = false
		ticker:Disconnect()
	end)

	redraw()
	ping.Text = T("players_ping", math.floor(me:GetNetworkPing() * 1000 + 0.5))
	if selected then
		request(selected)
	end
	drawCard()
	return win, function(_nextProfile: Types.Profile?) end
end

return PlayerListWindow
