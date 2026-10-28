--!strict
-- Paid auction announcements on the client [владелец 28.10: «уведомления за 10 роблокосов … уведомить весь сервер,
-- что такой-то предмет, с такими качества и по такой цене и количество выставлено на аукционе»; «все серверы»]:
--   * AuctionListed(lotId) — our lot is on sale: the offer card «Объявить на всех серверах?» with the queue wait
--     (AuctionAnnounceInfo) and the ways to pay: a stored announcement, Robux, crystals → AuctionAnnounce(lotId, pay).
--   * AuctionAnnounced(m) — someone's announcement (AuctionService filtered out players who hid auction ads): a banner
--     at the top for BANNER_SECONDS with the item's icon, name, enchantments, count, price, seller and «Открыть»
--     (the auction window with the item's name in the search). One banner at a time, the rest wait.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local BANNER_W, BANNER_H = 460, 92
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
		local w = width(BANNER_W)
		local top = GuiService:GetGuiInset().Y + 8
		local card =
			Ui.card(gui, UDim2.fromOffset(w, BANNER_H), UDim2.new(0.5, -w / 2, 0, -BANNER_H - 8))
		card.Name = "Announce"
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(64, 64)
		icon.Position = UDim2.fromOffset(12, (BANNER_H - 64) / 2)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.iconFor(m.item.id, m.item.level) or ""
		icon.Parent = card
		local textW = w - 88 - 104
		local title = Ui.label(
			card,
			T("auction_announce_banner", m.seller),
			UDim2.fromOffset(textW, 20),
			UDim2.fromOffset(88, 8),
			15,
			Ui.colors.header
		)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		local name = Strings.itemName(m.item.id, m.item.level, locale())
		local line = Ui.label(
			card,
			if m.item.count > 1 then name .. " ×" .. m.item.count else name,
			UDim2.fromOffset(textW, 20),
			UDim2.fromOffset(88, 28),
			16,
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
			UDim2.fromOffset(textW, 18),
			UDim2.fromOffset(88, 48),
			13,
			Ui.colors.purple
		)
		enchants.TextTruncate = Enum.TextTruncate.AtEnd
		Ui.label(
			card,
			Auction.priceText({ cur = m.cur }, m.price, locale()),
			UDim2.fromOffset(textW, 18),
			UDim2.fromOffset(88, if #books > 0 then 66 else 50),
			15,
			Ui.colors.money
		)
		local open = Ui.button(
			card,
			T("auction_announce_open"),
			UDim2.fromOffset(92, 34),
			UDim2.new(1, -104, 0.5, -17),
			Ui.colors.buttonBlue
		)
		open.Activated:Connect(function()
			openAuction(name)
		end)
		TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0.5, -w / 2, 0, top) })
			:Play()
		task.wait(BANNER_SECONDS)
		local out = TweenService:Create(
			card,
			TweenInfo.new(0.3),
			{ Position = UDim2.new(0.5, -w / 2, 0, -BANNER_H - 8) }
		)
		out:Play()
		out.Completed:Wait()
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
