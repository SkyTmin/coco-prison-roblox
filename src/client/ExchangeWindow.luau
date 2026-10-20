--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local ExchangeWindow = {}

local function itemCount(profile: Types.Profile?, id: string): number
	local count = 0
	if profile then
		for _, stack in pairs(profile.inventory) do
			if stack.id == id then
				count += stack.count
			end
		end
	end
	return count
end

function ExchangeWindow.build(
	parent: Instance,
	kind: string,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local win, content = createWindow(
		parent,
		Strings.t("exchange_" .. kind, locale),
		UDim2.fromOffset(600, 316),
		onClose
	)
	local offers = if kind == "stars"
		then Config.market.starExchange
		else Config.market.shardExchange
	local ids: { string } = {}
	for id in pairs(offers) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local updates: { (Types.Profile?) -> () } = {}
	for index, id in ipairs(ids) do
		local offer = offers[id]
		local input = if kind == "stars" then "ancient_star" else offer.input
		local cost = if kind == "stars" then offer else offer.count
		local row =
			Ui.panel(content, UDim2.new(1, -8, 0, 80), UDim2.fromOffset(4, 4 + (index - 1) * 88))
		local slot, name, _, icon = Ui.slot(row, 54)
		slot.Position = UDim2.fromOffset(8, 12)
		icon.Image = Config.iconFor(id) or ""
		icon.Visible = icon.Image ~= ""
		name.Text = if icon.Visible then "" else Strings.itemName(id, nil, locale)
		Ui.label(
			row,
			Strings.itemName(id, nil, locale),
			UDim2.new(1, -212, 0, 26),
			UDim2.fromOffset(72, 6),
			14,
			Ui.colors.header
		)
		local price = Ui.label(row, "", UDim2.new(1, -212, 0, 40), UDim2.fromOffset(72, 32), 12)
		price.TextWrapped = true
		local button = Ui.button(
			row,
			Strings.t("exchange", locale),
			UDim2.fromOffset(124, 40),
			UDim2.new(1, -132, 0, 20)
		)
		table.insert(updates, function(p: Types.Profile?)
			local have = itemCount(p, input)
			price.Text = string.format(
				"%s ×%d (%d/%d)",
				Strings.itemName(input, nil, locale),
				cost,
				have,
				cost
			)
			price.TextColor3 = if have >= cost then Ui.colors.money else Ui.colors.muted
			button.BackgroundColor3 = if have >= cost
				then Ui.colors.buttonGreen
				else Ui.colors.buttonGrey
			button.Interactable = p ~= nil and have >= cost
		end)
		button.Activated:Connect(function()
			Remotes.event("Exchange"):FireServer(kind, id)
		end)
	end
	local function refresh(p: Types.Profile?)
		for _, update in ipairs(updates) do
			update(p)
		end
	end
	refresh(profile)
	return win, refresh
end

return ExchangeWindow
