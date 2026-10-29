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
local TweenService = game:GetService("TweenService")
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
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function width(wanted: number): number
		local camera = workspace.CurrentCamera
		local vw = if camera then camera.ViewportSize.X else 1280
		return math.min(wanted, vw - 24)
	end

	-- ── the banner ──────────────────────────────────────────────────────────────────────────────────────────
	local queue: { Announce } = {}
	local showing = false

	local function show(m: Announce)
		-- ScreenGui already excludes the Roblox bar and device cutouts. Do not add GetGuiInset again.
		-- Relative width follows the *safe* area immediately, including rotation while the banner is visible.
		local hidden = UDim2.new(0.5, 0, 0, -BANNER_H - EDGE_GAP)
		local card = Ui.card(gui, UDim2.new(1, -EDGE_GAP * 2, 0, BANNER_H), hidden)
		card.Name = "Announce"
		card.AnchorPoint = Vector2.new(0.5, 0)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(BANNER_W, BANNER_H)
		limit.Parent = card
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
			local contentWidth = math.max(0, card.AbsoluteSize.X - 96)
			local pw = math.min(contentWidth, priceWidth + 4)
			local hw = math.min(contentWidth, 64)
			seller.Size = UDim2.fromOffset(math.max(0, contentWidth - pw - 6), 16)
			price.Size = UDim2.fromOffset(pw, 16)
			price.Position = UDim2.new(1, -48 - pw, 0, 3)
			enchants.Size = UDim2.fromOffset(math.max(0, contentWidth - hw - 6), 15)
			hint.Size = UDim2.fromOffset(hw, 15)
			hint.Position = UDim2.new(1, -48 - hw, 0, 34)
		end
		card:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
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
		local dismissed = Instance.new("BindableEvent")
		local closed = false
		local function dismiss()
			if not closed then
				closed = true
				dismissed:Fire()
			end
		end
		close.Activated:Connect(dismiss)
		open.Activated:Connect(function()
			if closed then
				return
			end
			dismiss()
			openAuction(name)
		end)
		TweenService:Create(card, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, TOP_GAP) })
			:Play()
		task.delay(BANNER_SECONDS, dismiss)
		dismissed.Event:Wait()
		open.Active, close.Active = false, false
		local out = TweenService:Create(card, TweenInfo.new(0.2), { Position = hidden })
		out:Play()
		out.Completed:Wait()
		dismissed:Destroy()
		card:Destroy()
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
		local card =
			Ui.card(gui, UDim2.fromOffset(w, OFFER_H), UDim2.new(0.5, -w / 2, 0.5, -OFFER_H / 2))
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
