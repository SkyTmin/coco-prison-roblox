--!strict
-- Paid auction announcements on the client [владелец 28.10: «уведомления за 10 роблокосов … уведомить весь сервер,
-- что такой-то предмет, с такими качества и по такой цене и количество выставлено на аукционе»; «все серверы»]:
--   * AuctionListed(lotId) — our lot is on sale: the offer card «Объявить на всех серверах?» with the queue wait
--     (AuctionAnnounceInfo) and the ways to pay: a stored announcement, Robux, crystals → AuctionAnnounce(lotId, pay).
--   * AuctionAnnounced(m) — someone's announcement (AuctionService filtered out players who hid auction ads): a banner
--     at the first safe top edge for BANNER_SECONDS: a compact, tappable card and a separate close target.
--     It opens the auction with the item's name in the search. One banner at a time, the rest wait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auction = require(Shared.Auction)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)

local AuctionBanner = {}

local BANNER_SECONDS = 8
local BANNER_W, BANNER_H = 400, 52 -- [владелец 29.10] keep the play area clear on small phones
local TOP_GAP, EDGE_GAP, CLOSE_SIZE = 4, 8, 44
local OFFER_W, OFFER_H = 420, 210
local player = Players.LocalPlayer

-- Shared HUD contract uses raw GuiObject.AbsolutePosition pixels, not VirtualInput coordinates.
-- This gameplay GUI shares PrisonHud's device-safe bounds; never add GetGuiInset again.
local function notificationRect(gui: ScreenGui): (number, number, number, boolean)
	local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
	local left, top = origin.X, origin.Y
	local right, bottom = origin.X + size.X, origin.Y + size.Y
	local x, y, w, h =
		player:GetAttribute("HudNotificationX"),
		player:GetAttribute("HudNotificationY"),
		player:GetAttribute("HudNotificationWidth"),
		player:GetAttribute("HudNotificationHeight")
	local function finite(value: any): boolean
		return typeof(value) == "number" and value == value and math.abs(value) < math.huge
	end
	if finite(x) and finite(y) and finite(w) and finite(h) then
		left, right = math.max(left, x), math.min(right, x + w)
		top, bottom = math.max(top, y), math.min(bottom, y + h)
	else
		left, right, top = left + EDGE_GAP, right - EDGE_GAP, top + TOP_GAP
	end
	local width = math.max(0, math.min(BANNER_W, right - left))
	return left + math.max(0, (right - left - width) / 2) - origin.X,
		top - origin.Y,
		width,
		width >= 170 and bottom - top >= BANNER_H
end

type Announce = {
	lot: string,
	item: {
		id: string,
		count: number,
		level: number?,
		books: { { id: string, level: number } }?,
		rarity: string?,
	},
	price: number,
	cur: string?,
	seller: string,
}

function AuctionBanner.start(locale: () -> string, openAuction: (search: string?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale(), ...)
	end
	local function minutes(seconds: number): string
		local _, _, m, s = Auction.timeLeft(seconds)
		return T("auction_time_ms", m, s)
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AuctionBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Keep the purchase window's original bounds while announcements can use the
	-- owner's notice lane at the very top of the gameplay HUD.
	local offerGui = Instance.new("ScreenGui")
	offerGui.Name = "AuctionOffer"
	offerGui.ResetOnSpawn = false
	offerGui.DisplayOrder = gui.DisplayOrder
	offerGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	offerGui.ZIndexBehavior = gui.ZIndexBehavior
	offerGui.Parent = gui.Parent

	local function width(wanted: number): number
		local camera = workspace.CurrentCamera
		local vw = if camera then camera.ViewportSize.X else 1280
		return math.min(wanted, vw - 24)
	end

	-- ── the banner ──────────────────────────────────────────────────────────────────────────────────────────
	local queue: { Announce } = {}
	local showing = false

	local function show(m: Announce)
		local lane = Instance.new("Frame")
		lane.Name = "NotificationLane"
		lane.BackgroundTransparency, lane.ClipsDescendants, lane.Visible = 1, true, false
		lane.Parent = gui
		local card = Ui.card(lane, UDim2.fromScale(1, 1), UDim2.new())
		card.Name = "Announce"
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(32, 32)
		icon.Position = UDim2.fromOffset(EDGE_GAP, 10)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.iconFor(m.item.id, m.item.level) or ""
		icon.Parent = card
		if m.item.count > 1 then
			local count =
				Ui.label(icon, tostring(m.item.count), UDim2.fromScale(1, 1), UDim2.new(), 13)
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.TextYAlignment = Enum.TextYAlignment.Bottom
			count.TextStrokeTransparency = 0
		end
		local seller = Ui.label(
			card,
			T("auction_announce_banner", m.seller),
			UDim2.new(),
			UDim2.fromOffset(48, 3),
			12,
			Ui.colors.header
		)
		seller.TextTruncate = Enum.TextTruncate.AtEnd
		local name = Strings.itemName(m.item.id, m.item.level, locale())
		local line = Ui.label(
			card,
			name,
			UDim2.new(1, -96, 0, 18),
			UDim2.fromOffset(48, 17),
			14,
			Ui.colors.white
		)
		line.TextTruncate = Enum.TextTruncate.AtEnd
		local books = {}
		for _, book in ipairs(m.item.books or {}) do
			table.insert(books, ItemInfo.bookName(book.id, book.level, locale()))
		end
		local enchants = Ui.label(
			card,
			table.concat(books, ", "),
			UDim2.new(),
			UDim2.fromOffset(48, 34),
			12,
			Ui.colors.purple
		)
		enchants.TextTruncate = Enum.TextTruncate.AtEnd
		local price = Ui.label(
			card,
			Auction.priceText({ cur = m.cur }, m.price, locale()),
			UDim2.new(),
			UDim2.new(),
			14,
			Ui.colors.money
		)
		price.TextXAlignment = Enum.TextXAlignment.Right
		price.TextTruncate = Enum.TextTruncate.AtEnd
		local hint = Ui.label(
			card,
			T("auction_announce_open"),
			UDim2.new(),
			UDim2.new(),
			12,
			Ui.colors.level
		)
		hint.TextXAlignment = Enum.TextXAlignment.Right
		hint.TextTruncate = Enum.TextTruncate.AtEnd
		local priceWidth = TextService:GetTextSize(
			price.Text,
			price.TextSize,
			price.Font,
			Vector2.new(1000, 100)
		).X
		local function layout()
			local compact = card.AbsoluteSize.X < 300
			local textX = if compact then 40 else 48
			local contentWidth = math.max(0, card.AbsoluteSize.X - textX - 48)
			local pw = math.min(
				contentWidth,
				priceWidth + 4,
				if compact and #books > 0 then math.max(54, contentWidth * 0.65) else math.huge
			)
			local hw = math.min(contentWidth, 64)
			icon.Size = UDim2.fromOffset(if compact then 28 else 32, if compact then 28 else 32)
			icon.Position = UDim2.fromOffset(EDGE_GAP, if compact then 12 else 10)
			seller.Position, line.Position, enchants.Position =
				UDim2.fromOffset(textX, 2), UDim2.fromOffset(textX, 16), UDim2.fromOffset(textX, 34)
			line.Size = UDim2.fromOffset(contentWidth, 18)
			seller.Size = UDim2.fromOffset(
				if compact then contentWidth else math.max(0, contentWidth - pw - 6),
				14
			)
			price.Size = UDim2.fromOffset(pw, 14)
			price.Position = UDim2.new(1, -48 - pw, 0, if compact then 34 else 2)
			enchants.Size =
				UDim2.fromOffset(math.max(0, contentWidth - (if compact then pw else hw) - 6), 15)
			hint.Visible = not compact
			hint.Size = UDim2.fromOffset(hw, 15)
			hint.Position = UDim2.new(1, -48 - hw, 0, 34)
		end
		local connections = { card:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout) }
		layout()

		-- The whole card opens the auction; the close target remains 44 px even on narrow phones.
		-- No full-screen input layer: only these two targets consume touches.
		local open = Instance.new("TextButton")
		open.Name = "Open"
		open.Text = ""
		open.BackgroundTransparency = 1
		open.Size = UDim2.new(1, -CLOSE_SIZE, 1, 0)
		open.ZIndex = 2
		open.Parent = card
		local close = Instance.new("ImageButton")
		close.Name = "Close"
		close.BackgroundTransparency = 1
		close.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
		close.Position = UDim2.new(1, -CLOSE_SIZE, 0.5, -CLOSE_SIZE / 2)
		close.ZIndex = 2
		close.Parent = card
		local cross = Instance.new("ImageLabel")
		cross.Size = UDim2.fromOffset(18, 18)
		cross.Position = UDim2.fromScale(0.5, 0.5)
		cross.AnchorPoint = Vector2.new(0.5, 0.5)
		cross.BackgroundTransparency = 1
		cross.Image = Config.icons.icons.ui_close or ""
		cross.ScaleType = Enum.ScaleType.Fit
		cross.ResampleMode = Enum.ResamplerMode.Pixelated
		cross.Parent = close
		local closed = false
		local remaining, visibleSince = BANNER_SECONDS, nil :: number?
		local fits = false
		local function visibility()
			local visible = not closed
				and fits
				and player:GetAttribute("HudToastActive") ~= true
				and player:GetAttribute("HudBossActive") ~= true
				and player:GetAttribute("HudWarzoneActive") ~= true
				and player:GetAttribute("LoadingBlocked") ~= true
				and player:GetAttribute("HudGameplayOpen") ~= false
			if visibleSince and not visible then
				remaining -= os.clock() - visibleSince
				visibleSince = nil
			elseif visible and not visibleSince then
				visibleSince = os.clock()
			end
			if remaining <= 0 then
				closed, visible = true, false
			end
			lane.Visible = visible
			player:SetAttribute("HudAuctionActive", visible)
		end
		local function place()
			local x, y, w, allowed = notificationRect(gui)
			lane.Position, lane.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, BANNER_H)
			fits = allowed
			visibility()
		end
		local function dismiss()
			if not closed then
				closed = true
				visibility()
			end
		end
		close.Activated:Connect(dismiss)
		open.Activated:Connect(function()
			if closed or not lane.Visible then
				return
			end
			dismiss()
			openAuction(name)
		end)
		for _, name in
			{
				"HudToastActive",
				"HudBossActive",
				"HudWarzoneActive",
				"LoadingBlocked",
				"HudGameplayOpen",
			}
		do
			table.insert(connections, player:GetAttributeChangedSignal(name):Connect(visibility))
		end
		for _, name in
			{
				"HudNotificationX",
				"HudNotificationY",
				"HudNotificationWidth",
				"HudNotificationHeight",
			}
		do
			table.insert(connections, player:GetAttributeChangedSignal(name):Connect(place))
		end
		for _, name in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(connections, gui:GetPropertyChangedSignal(name):Connect(place))
		end
		place()
		while not closed do
			if visibleSince and os.clock() - visibleSince >= remaining then
				dismiss()
			else
				task.wait(0.1)
			end
		end
		open.Active, close.Active = false, false
		for _, connection in connections do
			connection:Disconnect()
		end
		lane:Destroy()
	end

	local function pump()
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 do
				show(table.remove(queue, 1) :: Announce)
			end
			showing = false
		end)
	end

	Remotes.event("AuctionAnnounced").OnClientEvent:Connect(function(m: any)
		if typeof(m) == "table" and typeof(m.item) == "table" and #queue < 5 then
			table.insert(queue, m)
			pump()
		end
	end)

	-- ── the offer after listing ─────────────────────────────────────────────────────────────────────────────
	local offer: Frame? = nil
	local function closeOffer()
		if offer then
			offer:Destroy()
			offer = nil
		end
	end

	Remotes.event("AuctionListed").OnClientEvent:Connect(function(lotId: string)
		local ok, info = pcall(function()
			return Remotes.func("AuctionAnnounceInfo"):InvokeServer()
		end)
		if not ok or typeof(info) ~= "table" or info.busy then
			return
		end
		closeOffer()
		local w = width(OFFER_W)
		local card = Ui.card(
			offerGui,
			UDim2.fromOffset(w, OFFER_H),
			UDim2.new(0.5, -w / 2, 0.5, -OFFER_H / 2)
		)
		card.Name = "AnnounceOffer"
		card.Active = true
		offer = card
		Ui.label(
			card,
			T("auction_announce_title"),
			UDim2.new(1, -24, 0, 24),
			UDim2.fromOffset(12, 10),
			18,
			Ui.colors.header
		)
		local text = Ui.label(
			card,
			T("auction_announce_text"),
			UDim2.new(1, -24, 0, 54),
			UDim2.fromOffset(12, 36),
			14,
			Ui.colors.text
		)
		text.TextWrapped = true
		text.TextYAlignment = Enum.TextYAlignment.Top
		local full = info.wait > info.maxWait
		Ui.label(
			card,
			if full
				then T("auction_announce_full")
				elseif info.wait <= 5 then T("auction_announce_wait_now")
				else T("auction_announce_wait", minutes(info.wait)),
			UDim2.new(1, -24, 0, 20),
			UDim2.fromOffset(12, 94),
			15,
			if full then Ui.colors.red else Ui.colors.muted
		)
		local function send(pay: string)
			Remotes.event("AuctionAnnounce"):FireServer(lotId, pay)
			closeOffer()
		end
		local y = 124
		if not full then
			if info.credits > 0 then
				Ui.button(
					card,
					T("auction_announce_free", info.credits),
					UDim2.new(1, -24, 0, 34),
					UDim2.fromOffset(12, y),
					Ui.colors.buttonGreen
				).Activated
					:Connect(function()
						send("credit")
					end)
			else
				Ui.button(
					card,
					T("auction_announce_robux", info.robux),
					UDim2.new(0.5, -18, 0, 34),
					UDim2.fromOffset(12, y),
					Ui.colors.buttonGreen
				).Activated
					:Connect(function()
						send("robux")
					end)
				Ui.button(
					card,
					T("auction_announce_crystals", info.crystals),
					UDim2.new(0.5, -18, 0, 34),
					UDim2.new(0.5, 6, 0, y),
					Color3.fromRGB(100, 50, 200)
				).Activated
					:Connect(function()
						send("crystals")
					end)
			end
		end
		Ui.button(
			card,
			T("auction_announce_no"),
			UDim2.new(1, -24, 0, 30),
			UDim2.fromOffset(12, OFFER_H - 42),
			Ui.colors.buttonGrey
		).Activated
			:Connect(closeOffer)
	end)
end

return AuctionBanner
