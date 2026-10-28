--!strict
-- «Нравится игра?» (docs/research/remaining-features-design.md, этап 10): after Config.referrals.favorite.playMinutes
-- of play (p.stats.playSeconds, counted by ReferralService) and from favorite.level, once a session, a small dark card
-- slides in at the top: «Поставь лайк и добавь в Избранное». «В Избранное» opens Roblox's own favourite prompt
-- (AvatarEditorService:PromptSetFavorite); when the player adds the game it is never shown again, «Позже» / a
-- cancelled prompt shows it again in favorite.laterDays days (the server stores both, remote Favorite). NO reward of
-- any kind: rewarding a like or a favourite is against the Roblox rules. Ignoring it hides it after HIDE_SECONDS (back
-- next session). The emoji 👍 is left out of the text on purpose [решение]: the UI fonts may not draw it.
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

local FavoriteCard = {}

local W, H = 360, 128
local CHECK_SECONDS = 20
local HIDE_SECONDS = 40
local GOLD, GOLD_DARK = Color3.fromRGB(255, 200, 40), Color3.fromRGB(205, 120, 10)

local function due(p: any): boolean
	local rule = Config.referrals.favorite
	if not p or not p.stats or game.PlaceId == 0 then
		return false
	end
	local state = p.favorite
	if state and state.done then
		return false
	end
	if state and (state.laterUntil or 0) > workspace:GetServerTimeNow() then
		return false
	end
	return p.level >= rule.level and (p.stats.playSeconds or 0) >= rule.playMinutes * 60
end

-- the card itself; onDone(choice) with "done" | "later" | nil (ignored)
local function show(parent: Instance, locale: string, onDone: (string?) -> ())
	local function T(key: string): string
		return Strings.t(key, locale)
	end
	local card = Ui.card(parent, UDim2.fromOffset(W, H), UDim2.new(0.5, 0, 0, -H - 20))
	card.Name = "FavoriteCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.ZIndex = 20
	local icon = Config.icons.icons.menu_favorite
	local textX = if icon then 84 else 16
	if icon then
		Kit.image(card, icon, UDim2.fromOffset(60, 60), UDim2.fromOffset(14, 14))
	end
	local title = Kit.text(
		card,
		T("favorite_title"),
		UDim2.new(1, -textX - 12, 0, 24),
		UDim2.fromOffset(textX, 10),
		18,
		GOLD,
		Kit.BOLD
	)
	Kit.fit(title)
	local body = Kit.text(
		card,
		T("favorite_text"),
		UDim2.new(1, -textX - 12, 0, 40),
		UDim2.fromOffset(textX, 36),
		13,
		Ui.colors.text
	)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	local add, addLabel, addBack =
		Kit.actionButton(card, UDim2.fromOffset(160, 34), UDim2.new(1, -176, 1, -44), 15)
	addLabel.Text = T("favorite_add")
	Kit.gradient(addBack, GOLD, GOLD_DARK, 90)
	Kit.pressable(add)
	local later, laterLabel, laterBack =
		Kit.actionButton(card, UDim2.fromOffset(110, 34), UDim2.new(1, -296, 1, -44), 15)
	laterLabel.Text = T("favorite_later")
	laterBack.BackgroundColor3 = Kit.GREY
	Kit.pressable(later)
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex += 20
		end
	end

	local finished = false
	local function close(choice: string?)
		if finished then
			return
		end
		finished = true
		onDone(choice)
		local tween = TweenService:Create(
			card,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -H - 20) }
		)
		tween.Completed:Once(function()
			card:Destroy()
		end)
		tween:Play()
	end
	add.Activated:Connect(function()
		if finished then
			return
		end
		card.Visible = false
		-- Roblox's own prompt; its answer decides: added → never again, cancelled → later
		local connection: RBXScriptConnection? = nil
		connection = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
			if connection then
				connection:Disconnect()
			end
			close(if result == Enum.AvatarPromptResult.Success then "done" else "later")
		end)
		local ok = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		if not ok then
			if connection then
				connection:Disconnect()
			end
			close("later")
		end
	end)
	later.Activated:Connect(function()
		close("later")
	end)
	TweenService:Create(
		card,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 64) }
	):Play()
	task.delay(HIDE_SECONDS, function()
		if card.Visible then
			close(nil) -- ignored: no answer stored, back next session
		end
	end)
end

-- Starts the check loop. getProfile / getLocale read the client's current copies.
function FavoriteCard.start(parent: Instance, getProfile: () -> any, getLocale: () -> string)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			if due(getProfile()) then
				show(parent, getLocale(), function(choice: string?)
					if choice then
						Remotes.event("Favorite"):FireServer(choice)
					end
				end)
				return -- once a session
			end
		end
	end)
end

return FavoriteCard
