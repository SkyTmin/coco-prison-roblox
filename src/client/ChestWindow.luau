--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local DragDrop = require(script.Parent.DragDrop)

type Address = DragDrop.Address
type SlotView = { address: Address, name: TextLabel, count: TextLabel, icon: ImageLabel }
local ChestWindow = {}

function ChestWindow.build(
	parent: Instance,
	id: string,
	getProfile: () -> Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
): (Frame, () -> ())
	local function t(key: string): string
		return Strings.t(key, locale)
	end
	local isEnder = id == "enderChest"
	local win, content = createWindow(
		parent,
		t(
			if isEnder
				then "ender_chest"
				elseif id == "ancientCase" then "ancient_case"
				else "ordinary_case"
		),
		UDim2.fromOffset(452, 478),
		onClose
	)
	local views: { SlotView } = {}
	for _, child in ipairs(win:GetChildren()) do
		if child:IsA("Frame") and child ~= content then
			local title = child:FindFirstChildOfClass("TextLabel")
			if title then
				title.TextColor3 = Ui.colors.header
			end
		end
	end
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
	local function move(from: Address, to: Address)
		Remotes.event("CaseMove"):FireServer(id, from, to)
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
	local drag = DragDrop.new(win, stackAt, move, quick)
	local function grid(container: "case" | "inv", first: number, rows: number, y: number)
		for row = 0, rows - 1 do
			for column = 0, 8 do
				local frame, name, count, icon = Ui.slot(content, 44)
				frame.Position = UDim2.fromOffset(4 + column * 48, y + row * 48)
				local address: Address = { container = container, index = first + row * 9 + column }
				table.insert(views, { address = address, name = name, count = count, icon = icon })
				drag.Bind(frame, address)
			end
		end
	end
	grid("case", 1, 3, 0)
	Ui.label(
		content,
		t("inventory"),
		UDim2.fromOffset(430, 20),
		UDim2.fromOffset(4, 148),
		14,
		Ui.colors.header
	)
	grid("inv", 10, 3, 172)
	grid("inv", 1, 1, 324)
	local open =
		Ui.button(content, t("case_open"), UDim2.fromOffset(142, 30), UDim2.fromOffset(4, 380))
	open.Visible = not isEnder
	local take = Ui.button(
		content,
		t("case_take_all"),
		UDim2.fromOffset(142, 30),
		UDim2.fromOffset(152, 380),
		Ui.colors.buttonGreen
	)
	if isEnder then
		take.Position = UDim2.fromOffset(4, 380)
	end
	local hint = Ui.label(
		content,
		"",
		UDim2.fromOffset(136, 38),
		UDim2.fromOffset(300, 376),
		12,
		Ui.colors.muted
	)
	hint.TextWrapped = true
	open.Activated:Connect(function()
		if open.Active then
			Remotes.event("CaseOpen"):FireServer(id)
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
	local function refresh()
		for _, view in ipairs(views) do
			local stack = stackAt(view.address)
			local icon = if stack then Config.iconFor(stack.id, stack.level) else nil
			view.icon.Image, view.icon.Visible = icon or "", icon ~= nil
			view.name.Text = if stack then Strings.itemName(stack.id, stack.level, locale) else ""
			view.name.Visible = icon == nil
			view.count.Text = if stack and stack.count > 1 then tostring(stack.count) else ""
		end
		if isEnder then
			return
		end
		local config = Config.keys[id]
		local rewards = if typeof(config) == "table" then config.rewards or config else {}
		local available = typeof(rewards) == "table" and #rewards > 0
		local key = if id == "ancientCase" then "ancient_key" else "ordinary_key"
		local hasKey = false
		local profile = getProfile()
		if profile then
			for _, stack in pairs(profile.inventory) do
				if stack.id == key and stack.count > 0 then
					hasKey = true
					break
				end
			end
		end
		open.Active, open.AutoButtonColor = available and hasKey, available and hasKey
		open.BackgroundColor3 = if open.Active then Ui.colors.buttonBlue else Ui.colors.buttonGrey
		hint.Text = if not available
			then t("case_locked")
			elseif not hasKey then t("case_no_key")
			else ""
	end
	refresh()
	return win, refresh
end

return ChestWindow
