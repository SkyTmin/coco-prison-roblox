--!strict
-- Case / chest window in our own dark inventory style [владелец 28.10: «окно где забираешь предметы с кейсов …
-- сделать как наш инвентарь», the grey vanilla panel's button texts ran out of the buttons]: the case's 9×3 grid,
-- the backpack 9×3 and the hotbar in Ui.invSlot cells with captions, then the buttons: open with a key, take all,
-- key choice. Drag/drop and shift/double-tap quick moves come from DragDrop; the server validates every move.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
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
	local isStorage = isEnder or id == "factionChest" -- keeps items, no key, no Open button
	local gridWidth = 9 * SLOT + 8 * GAP
	local caseY = 4
	local bagY = caseY + 18 + 3 * (SLOT + GAP) + 10
	local barY = bagY + 18 + 3 * (SLOT + GAP) + 10
	local rowY = barY + 18 + SLOT + 14
	local win, content = createWindow(
		parent,
		t(TITLES[id] or "ordinary_case"),
		UDim2.fromOffset(gridWidth + 2 * PAD + 12, rowY + 34 + 26 + 44),
		onClose
	)
	win.BackgroundTransparency = 0 -- the HUD under it never shows through the slots
	local function caption(text: string, y: number)
		local l =
			Ui.label(content, text, UDim2.fromOffset(gridWidth, 16), UDim2.fromOffset(PAD, y), 12)
		l.TextColor3 = Ui.colors.muted
	end
	caption(t(TITLES[id] or "ordinary_case"), caseY)
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
		local container = if address.container == "inv"
			then profile.inventory
			elseif isEnder then profile.enderChest
			else profile.caseContents[id]
		return if container then container[address.index] else nil
	end
	local function move(from: Address, to: Address, count: number?)
		Remotes.event("CaseMove"):FireServer(id, from, to, count)
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
	local function refresh()
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
