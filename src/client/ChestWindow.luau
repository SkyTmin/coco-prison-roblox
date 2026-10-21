--!strict
-- Case / chest window in the look of the original: the vanilla Minecraft 3-row chest GUI
-- (reference: owner's screenshots of the "Кейс с предметами" chest — light grey bevelled panel,
-- dark-grey titles "Кейс с предметами" / "Инвентарь", 9×3 chest grid, 9×3 inventory, hotbar row).
-- Below the vanilla area a row of Minecraft-style buttons: open with a key, take all, key choice.
-- Drag/drop and shift/double-tap quick moves come from DragDrop; the server validates every move.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local BlockColors = require(Shared.BlockColors)
local Ui = require(script.Parent.Ui)
local DragDrop = require(script.Parent.DragDrop)

type Address = DragDrop.Address
type SlotView = { address: Address, name: TextLabel, count: TextLabel, icon: ImageLabel }
local ChestWindow = {}

local MC = Ui.MC
local TITLES = {
	ordinaryCase = "case_contents_title", -- [меню] "Кейс с предметами"
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
	enderChest = "ender_chest",
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
	-- vanilla chest GUI is 176×168 GUI px; our button row adds 30
	local width, height = 176 * MC, (168 + 36) * MC
	local win, raw = createWindow(
		parent,
		t(TITLES[id] or "ordinary_case"),
		UDim2.fromOffset(width, height),
		onClose
	)
	local content = Ui.toMc(win, raw)
	Ui.mcText(
		content,
		t(TITLES[id] or "ordinary_case"),
		UDim2.fromOffset(150 * MC, 10 * MC),
		UDim2.fromOffset(8 * MC, 5 * MC)
	)
	Ui.mcText(
		content,
		t("inventory"),
		UDim2.fromOffset(150 * MC, 10 * MC),
		UDim2.fromOffset(8 * MC, 72 * MC)
	)

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
				local frame, name, count, icon = Ui.mcSlot(content)
				frame.Position = UDim2.fromOffset((8 + column * 18) * MC, (y + row * 18) * MC)
				local address: Address = { container = container, index = first + row * 9 + column }
				table.insert(views, { address = address, name = name, count = count, icon = icon })
				drag.Bind(frame, address)
			end
		end
	end
	grid("case", 1, 3, 17) -- [ваниль] chest rows at y = 17
	grid("inv", 10, 3, 84) -- [ваниль] inventory at y = 84
	grid("inv", 1, 1, 142) -- [ваниль] hotbar at y = 142

	local rowY = 168 * MC
	local open = Ui.mcButton(
		content,
		t("case_open"),
		UDim2.fromOffset(54 * MC, 20 * MC),
		UDim2.fromOffset(8 * MC, rowY)
	)
	open.Visible = not isEnder
	local take = Ui.mcButton(
		content,
		t("case_take_all"),
		UDim2.fromOffset(54 * MC, 20 * MC),
		UDim2.fromOffset(if isEnder then 8 * MC else 64 * MC, rowY)
	)
	local keyButton: TextButton? = nil
	if #accepted > 1 then
		keyButton = Ui.mcButton(
			content,
			"",
			UDim2.fromOffset(48 * MC, 20 * MC),
			UDim2.fromOffset(120 * MC, rowY)
		)
	end
	local hint = Ui.mcText(
		content,
		"",
		UDim2.fromOffset(160 * MC, 10 * MC),
		UDim2.fromOffset(8 * MC, 189 * MC),
		7 * MC
	)
	hint.TextXAlignment = Enum.TextXAlignment.Left

	open.Activated:Connect(function()
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
	local function refresh()
		for _, view in ipairs(views) do
			local stack = stackAt(view.address)
			local icon = if stack then Config.iconFor(stack.id, stack.level) else nil
			local tile = if stack and not icon then BlockColors.of(stack.id) else nil
			view.icon.Image, view.icon.Visible = icon or "", icon ~= nil or tile ~= nil
			view.icon.BackgroundColor3 = tile or Color3.new()
			view.icon.BackgroundTransparency = if tile then 0 else 1
			view.name.Text = if stack then Strings.itemName(stack.id, stack.level, locale) else ""
			view.name.Visible = false -- no text on items (the tile or picture identifies them)
			view.count.Text = if stack and stack.coins
				then Strings.money(stack.coins) .. "$"
				elseif stack and stack.count > 1 then tostring(stack.count)
				else ""
			local glint = view.icon:FindFirstChild("Glint")
			if glint and glint:IsA("ImageLabel") then
				local enchanted = stack ~= nil
					and icon ~= nil
					and Config.isEnchanted(stack.id, stack.level)
				glint.Image, glint.Visible = icon or "", enchanted
			end
		end
		if isEnder then
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
		Ui.setMcButtonActive(open, available and have > 0)
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
