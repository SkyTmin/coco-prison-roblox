--!strict
-- Case / chest window in our own dark inventory style [владелец 28.10: «окно где забираешь предметы с кейсов …
-- сделать как наш инвентарь», the grey vanilla panel's button texts ran out of the buttons]: the case's 9×3 grid,
-- the backpack 9×3 and the hotbar in Ui.invSlot cells with captions, then the buttons: open with a key, take all,
-- key choice. Drag/drop and shift/double-tap quick moves come from DragDrop; the server validates every move.
-- The gang storage (gangChest) has pages of 27: «◀ Стр. x / N ▶» instead of the key buttons (player attributes
-- GangChestPage / GangChestPages from CaseService, GangChestPage(page) asks for another page).
-- The ender chest is the Хранилище (Shared/Vault): tabs «Отсек 1/2/3» over the grid, the tab is local and goes with
-- every CaseMove; a closed tab shows «Открыть за 10 000 $» / «за 199 кр.» (the next one only, a second tap
-- confirms) or «Не торопитесь!» when an earlier section is still closed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Vault = require(Shared.Vault)
local CreativeWindow = require(script.Parent.CreativeWindow)
local Ui = require(script.Parent.Ui)
local DragDrop = require(script.Parent.DragDrop)
local SlotView = require(script.Parent.SlotView)

type Address = DragDrop.Address
type SlotView = { address: Address, name: TextLabel, count: TextLabel, icon: ImageLabel }
local ChestWindow = {}

local SLOT, GAP, PAD = 44, 4, 16 -- the inventory window's sizes
local TITLES = {
	ordinaryCase = "case_contents_title", -- [меню] "Кейс с предметами"
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
	enderChest = "ender_chest",
	factionChest = "faction_chest", -- the faction storage on the faction base (contents mirrored by the server)
	gangChest = "gang_chest", -- the gang storage on the База банды (GangChestService)
}

function ChestWindow.build(
	parent: Instance,
	id: string,
	getProfile: () -> Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
): (Frame, () -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local isEnder = id == "enderChest"
	local isGang = id == "gangChest"
	local isStorage = isEnder or id == "factionChest" or isGang -- keeps items, no key, no Open button
	local gridWidth = 9 * SLOT + 8 * GAP
	local caseY = if isEnder then 38 else 4 -- the ender chest: the section tabs above
	local section = 1 -- the Хранилище section on screen
	local bagY = caseY + 18 + 3 * (SLOT + GAP) + 10
	local barY = bagY + 18 + 3 * (SLOT + GAP) + 10
	local rowY = barY + 18 + SLOT + 14
	local win, content = createWindow(
		parent,
		t(if isEnder then "vault_title" else TITLES[id] or "ordinary_case"),
		UDim2.fromOffset(gridWidth + 2 * PAD + 12, rowY + 34 + 26 + 44),
		onClose
	)
	win.BackgroundTransparency = 0 -- the HUD under it never shows through the slots
	local function caption(text: string, y: number): TextLabel
		local l =
			Ui.label(content, text, UDim2.fromOffset(gridWidth, 16), UDim2.fromOffset(PAD, y), 12)
		l.TextColor3 = Ui.colors.muted
		return l
	end
	local caseCaption = caption(t(TITLES[id] or "ordinary_case"), caseY)
	caption(t("inv_backpack"), bagY)
	caption(t("inv_hotbar"), barY)

	local views: { SlotView } = {}
	local configuredKeys = Config.keys.caseKeys[id]
	local accepted: { string } = if typeof(configuredKeys) == "string"
		then { configuredKeys }
		else configuredKeys or {}
	local selectedKey = accepted[1]
	local function stackAt(address: Address): Types.ItemStack?
		local profile = getProfile()
		if not profile then
			return nil
		end
		if address.container == "inv" then
			return profile.inventory[address.index]
		elseif isEnder then
			return profile.enderChest[Vault.slot(section, address.index)]
		end
		local container = profile.caseContents[id]
		return if container then container[address.index] else nil
	end
	-- a closed Хранилище section takes nothing (the server refuses it too)
	local function sectionOpen(): boolean
		return not isEnder or section <= Vault.unlocked(getProfile())
	end
	local function move(from: Address, to: Address, count: number?)
		if (from.container == "case" or to.container == "case") and not sectionOpen() then
			return
		end
		Remotes.event("CaseMove"):FireServer(id, from, to, count, if isEnder then section else nil)
	end
	local function quick(from: Address)
		local container: "case" | "inv" = if from.container == "case" then "inv" else "case"
		for index = 1, if container == "case" then 27 else 36 do
			local destination: Address = { container = container, index = index }
			if not stackAt(destination) then
				move(from, destination)
				return
			end
		end
	end
	local drag = DragDrop.new(win, stackAt, move, quick, function(from: Address, count: number?)
		Remotes.event("DropItem"):FireServer(from.index, count) -- only bag slots are thrown
	end)
	local function grid(container: "case" | "inv", first: number, rows: number, y: number)
		for row = 0, rows - 1 do
			for column = 0, 8 do
				local frame, name, count, icon = Ui.invSlot(content, SLOT)
				frame.Position =
					UDim2.fromOffset(PAD + column * (SLOT + GAP), y + row * (SLOT + GAP))
				local address: Address = { container = container, index = first + row * 9 + column }
				table.insert(views, { address = address, name = name, count = count, icon = icon })
				drag.Bind(frame, address)
				if container == "inv" and first == 1 then -- hotbar keys, as in the inventory
					local key = Ui.label(
						frame,
						tostring(column + 1),
						UDim2.fromOffset(12, 12),
						UDim2.fromOffset(4, 2),
						10
					)
					key.TextColor3 = Ui.colors.muted
					key.ZIndex = 5
				end
			end
		end
	end
	grid("case", 1, 3, caseY + 18)
	grid("inv", 10, 3, bagY + 18)
	grid("inv", 1, 1, barY + 18)
	local refresh: () -> ()

	-- the Хранилище section tabs
	local tabs: { TextButton } = {}
	if isEnder then
		local tabWidth = math.floor((gridWidth - (Vault.MAX - 1) * 8) / Vault.MAX)
		for n = 1, Vault.MAX do
			local tab = Ui.button(
				content,
				t("vault_section", n),
				UDim2.fromOffset(tabWidth, 28),
				UDim2.fromOffset(PAD + (n - 1) * (tabWidth + 8), 4),
				Ui.colors.buttonGrey
			)
			tab.TextSize = 14
			tab.Activated:Connect(function()
				if section ~= n then
					section = n
					drag.Clear() -- a stack picked up in another section must not land here
					refresh()
				end
			end)
			tabs[n] = tab
		end
	end

	-- plain buttons whose text fits (the old Minecraft buttons cut «Забрать всё»)
	local function button(text: string, x: number, width: number, color: Color3): TextButton
		local b =
			Ui.button(content, text, UDim2.fromOffset(width, 34), UDim2.fromOffset(x, rowY), color)
		b.TextSize = 15
		b.TextWrapped = true
		return b
	end
	local third = math.floor((gridWidth - 2 * 8) / 3)
	local open = button(t("case_open"), PAD, third, Ui.colors.buttonGreen)
	open.Visible = not isStorage
	local take = button(
		t("case_take_all"),
		if isStorage then PAD else PAD + third + 8,
		third,
		Ui.colors.buttonBlue
	)
	local keyButton: TextButton? = nil
	if #accepted > 1 then
		keyButton = button("", PAD + 2 * (third + 8), third, Ui.colors.buttonGrey)
	end
	local hint =
		Ui.label(content, "", UDim2.fromOffset(gridWidth, 18), UDim2.fromOffset(PAD, rowY + 40), 13)
	hint.TextColor3 = Ui.colors.muted
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	-- the gang storage pages
	local pageLabel: TextLabel? = nil
	local prevPage: TextButton?, nextPage: TextButton? = nil, nil
	local localPlayer = Players.LocalPlayer
	local function pageInfo(): (number, number)
		local page = localPlayer:GetAttribute("GangChestPage")
		local pages = localPlayer:GetAttribute("GangChestPages")
		return if typeof(page) == "number" then page else 1,
			if typeof(pages) == "number" then pages else 1
	end
	if isGang then
		local x = PAD + third + 8
		prevPage = button("◀", x, 44, Ui.colors.buttonGrey)
		pageLabel = Ui.label(
			content,
			"",
			UDim2.fromOffset(third - 96, 34),
			UDim2.fromOffset(x + 48, rowY),
			15
		)
		local labelRef = pageLabel :: TextLabel
		labelRef.TextXAlignment = Enum.TextXAlignment.Center
		nextPage = button("▶", x + third - 44, 44, Ui.colors.buttonGrey)
		local function turn(delta: number)
			local page, pages = pageInfo()
			local target = math.clamp(page + delta, 1, pages)
			if target ~= page then
				Remotes.event("GangChestPage"):FireServer(target)
			end
		end
		(prevPage :: TextButton).Activated:Connect(function()
			turn(-1)
		end);
		(nextPage :: TextButton).Activated:Connect(function()
			turn(1)
		end)
	end
	-- the Хранилище: the two prices of the next section; the first tap arms a button, a second tap within 4 s buys
	local buyDollars: TextButton?, buyCrystals: TextButton? = nil, nil
	local armed: string?, armedAt = nil, 0
	if isEnder then
		buyDollars = button("", PAD, third, Ui.colors.buttonGreen)
		buyCrystals = button("", PAD + third + 8, third, Ui.colors.buttonBlue)
		local function buy(currency: string, b: TextButton)
			if not b.Active then
				-- not enough money / crystals: the server says so
				Remotes.event("VaultUnlock"):FireServer(section, currency)
			elseif armed == currency and os.clock() - armedAt < 4 then
				armed = nil
				Remotes.event("VaultUnlock"):FireServer(section, currency)
			else
				armed, armedAt = currency, os.clock()
				task.delay(4.1, function()
					if armed == currency and os.clock() - armedAt >= 4 then
						armed = nil
						refresh()
					end
				end)
			end
			refresh()
		end
		(buyDollars :: TextButton).Activated:Connect(function()
			buy("dollars", buyDollars :: TextButton)
		end);
		(buyCrystals :: TextButton).Activated:Connect(function()
			buy("crystals", buyCrystals :: TextButton)
		end)
	end

	local function keyCount(key: string?): number
		local profile = getProfile()
		local n = 0
		if profile and key then
			for _, stack in pairs(profile.inventory) do
				if stack.id == key then
					n += stack.count
				end
			end
		end
		return n
	end
	open.Activated:Connect(function()
		CreativeWindow.LocalLog(
			string.format(
				"нажато «Открыть»: %s, ключ %s ×%d, кнопка активна: %s",
				id,
				tostring(selectedKey),
				keyCount(selectedKey),
				tostring(open.Active)
			)
		)
		if open.Active then
			Remotes.event("CaseOpen"):FireServer(id, selectedKey)
		end
	end)
	take.Activated:Connect(function()
		-- Reserve destinations locally, but send a separate validated intent for every stack.
		local free: { number } = {}
		for index = 1, 36 do
			if not stackAt({ container = "inv", index = index }) then
				table.insert(free, index)
			end
		end
		local nextFree = 1
		for index = 1, 27 do
			if stackAt({ container = "case", index = index }) then
				local destination = free[nextFree]
				if not destination then
					break
				end
				move(
					{ container = "case", index = index },
					{ container = "inv", index = destination }
				)
				nextFree += 1
			end
		end
	end)
	local function setActive(b: TextButton, active: boolean)
		b.Active = active
		b.AutoButtonColor = active
		b.BackgroundTransparency = if active then 0 else 0.5
		b.TextTransparency = if active then 0 else 0.4
	end
	-- the tabs, the caption «Хранилище · открыто N из 3» and the buttons of the section on screen
	local function refreshVault()
		local profile = getProfile()
		local unlocked = Vault.unlocked(profile)
		for n, tab in ipairs(tabs) do
			tab.BackgroundColor3 = if n == section
				then Ui.colors.buttonBlue
				elseif n <= unlocked then Ui.colors.buttonGrey
				else Ui.colors.slot
			tab.Text = t(if n <= unlocked then "vault_section" else "vault_section_locked", n)
		end
		caseCaption.Text = t("vault_opened", unlocked, Vault.MAX)
		local isOpen = section <= unlocked
		local price = if isOpen then nil else Vault.price(section)
		local isNext = section == unlocked + 1
		take.Visible = isOpen
		local dollars, crystals = buyDollars :: TextButton, buyCrystals :: TextButton
		dollars.Visible = not isOpen and isNext and price ~= nil
		crystals.Visible = dollars.Visible
		if price then
			local cost = t("vault_price_dollars", Strings.grouped(price.dollars, 0))
			local gems = t("vault_price_crystals", price.crystals)
			dollars.Text = if armed == "dollars" then t("vault_confirm", cost) else cost
			crystals.Text = if armed == "crystals" then t("vault_confirm", gems) else gems
			setActive(
				dollars,
				profile ~= nil and profile.coins >= price.dollars * Config.moneyScale
			)
			setActive(crystals, profile ~= nil and (profile.crystals or 0) >= price.crystals)
		end
		hint.Text = if isOpen
			then ""
			elseif not isNext then t("vault_in_order")
			else t("vault_buy_hint", section)
	end
	refresh = function()
		for _, view in ipairs(views) do
			local stack = stackAt(view.address)
			SlotView.render(view.name, view.count, view.icon, stack)
			-- a money bag shows whole dollars ("74$"): "74.156$" ran into the next slots; the tooltip has the exact sum
			if stack and stack.coins then
				view.count.Text = (
					if stack.coins >= 100 * Config.moneyScale
						then Strings.money(stack.coins)
						else tostring(math.floor(stack.coins / Config.moneyScale))
				) .. "$"
			end
		end
		if isGang and pageLabel then
			local page, pages = pageInfo()
			pageLabel.Text = t("gang_chest_page", page, pages)
			-- two pages of 27 per level of «Сундуки» (a double chest) [сеть S7]
			local maxPages = 0
			for _, u in ipairs(Config.gangs.upgrades) do
				if u.id == "chests" then
					maxPages = u.max * math.floor(Config.gangs.base.chest.slotsPerLevel / 27)
				end
			end
			hint.Text = if pages < maxPages then t("gang_chest_more") else ""
		end
		if isEnder then
			refreshVault()
		end
		if isStorage then
			return
		end
		local config = Config.keys[id]
		local rewards = if typeof(config) == "table" then config.rewards or config else {}
		local available = id == "ancientCase"
			or id == "nicknameCase"
			or (typeof(rewards) == "table" and #rewards > 0)
		if keyCount(selectedKey) == 0 then
			for _, key in ipairs(accepted) do
				if keyCount(key) > 0 then
					selectedKey = key
					break
				end
			end
		end
		local have = keyCount(selectedKey)
		if keyButton then
			keyButton.Text = Strings.itemName(selectedKey, nil, locale)
		end
		setActive(open, available and have > 0)
		hint.Text = if not available
			then t("case_locked")
			elseif have == 0 then t(
				"case_need_key",
				Strings.itemName(selectedKey or "ordinary_key", nil, locale)
			)
			else t("case_key_hint", Strings.itemName(selectedKey, nil, locale), have)
	end
	if keyButton then
		keyButton.Activated:Connect(function()
			selectedKey = accepted[(table.find(accepted, selectedKey) or 1) % #accepted + 1]
			refresh()
		end)
	end
	refresh()
	return win, refresh
end

return ChestWindow
