--!strict
-- «Урна» (/rubbish) [клиент garbage.*: предметы пропадают при закрытии]: a tap on a stack of the bag puts it into the
-- bin (3×9), a tap in the bin gives it back; nothing leaves the profile while the window is open. When the window
-- goes (the close button, Esc, another window, a rebuild) the client sends Rubbish({ {slot, id, count} }) and the
-- server destroys the stacks that still match (ChatCommandService). A stack that changed meanwhile drops out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)
local SlotView = require(script.Parent.SlotView)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
type View = { frame: Frame, name: TextLabel, count: TextLabel, image: ImageLabel, hit: TextButton }

local RubbishWindow = {}

local SLOT, GAP, COLS, PAD = 44, 4, 9, 14
local BIN_ROWS = 3
local GRID_W = COLS * SLOT + (COLS - 1) * GAP
local W = GRID_W + 2 * PAD + 12
-- the bag as the inventory shows it: the three rows (10…36), then the hotbar (1…9)
local BAG_ORDER: { number } = {}
for slot = 10, 36 do
	table.insert(BAG_ORDER, slot)
end
for slot = 1, 9 do
	table.insert(BAG_ORDER, slot)
end

function RubbishWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local hintH = 48
	local binTop = hintH + 24
	local bagTop = binTop + BIN_ROWS * (SLOT + GAP) + 30
	local height = bagTop + 4 * (SLOT + GAP) + GAP + 8
	local win, content =
		createWindow(parent, T("rubbish_title"), UDim2.fromOffset(W, height + 52), onClose)
	win.Name = "Window_Rubbish"
	Ui.titleColor(win, Ui.colors.header)

	local hint = Kit.text(
		content,
		T("rubbish_hint"),
		UDim2.new(1, -2 * PAD, 0, hintH),
		UDim2.fromOffset(PAD, 2),
		13,
		Ui.colors.muted
	)
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top
	Kit.text(
		content,
		T("rubbish_title"),
		UDim2.fromOffset(GRID_W, 20),
		UDim2.fromOffset(PAD, binTop - 22),
		14,
		Kit.BAD,
		Kit.BOLD
	)
	Kit.text(
		content,
		T("rubbish_bag"),
		UDim2.fromOffset(GRID_W, 20),
		UDim2.fromOffset(PAD, bagTop - 22),
		14,
		Ui.colors.text,
		Kit.BOLD
	)

	local current = profile
	local staged: { number } = {} -- bag slots in the bin, in the order they went in
	local kept: { [number]: Types.ItemStack } = {} -- the stack each staged slot held when it went in

	local function slotView(x: number, y: number): View
		local frame, name, count, image = Ui.invSlot(content, SLOT)
		frame.Position = UDim2.fromOffset(x, y)
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = frame.ZIndex + 5
		hit.Parent = frame
		return { frame = frame, name = name, count = count, image = image, hit = hit }
	end
	local bin: { View } = {}
	for i = 1, BIN_ROWS * COLS do
		local view = slotView(
			PAD + ((i - 1) % COLS) * (SLOT + GAP),
			binTop + math.floor((i - 1) / COLS) * (SLOT + GAP)
		)
		local stroke = view.frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(120, 50, 50)
		end
		bin[i] = view
	end
	local bag: { View } = {}
	for i, _ in ipairs(BAG_ORDER) do
		local row = math.floor((i - 1) / COLS)
		bag[i] = slotView(
			PAD + ((i - 1) % COLS) * (SLOT + GAP),
			bagTop + row * (SLOT + GAP) + (if row == 3 then GAP * 2 else 0) -- the hotbar row a little apart
		)
	end

	local function render()
		local inventory = if current then current.inventory else {}
		for i, slot in ipairs(BAG_ORDER) do
			local view = bag[i]
			local stack = if table.find(staged, slot) then nil else inventory[slot]
			SlotView.render(view.name, view.count, view.image, stack)
		end
		for i, view in ipairs(bin) do
			local slot = staged[i]
			SlotView.render(view.name, view.count, view.image, if slot then kept[slot] else nil)
		end
	end
	for i, slot in ipairs(BAG_ORDER) do
		bag[i].hit.Activated:Connect(function()
			local stack = current and current.inventory[slot]
			if stack and not table.find(staged, slot) and #staged < #bin then
				table.insert(staged, slot)
				kept[slot] = stack
				render()
			end
		end)
	end
	for i, view in ipairs(bin) do
		view.hit.Activated:Connect(function()
			local slot = staged[i]
			if slot then
				table.remove(staged, i)
				kept[slot] = nil
				render()
			end
		end)
	end

	-- the bin empties when the window goes, however it goes
	win.Destroying:Once(function()
		local list = {}
		for _, slot in ipairs(staged) do
			local stack = kept[slot]
			table.insert(list, { slot, stack.id, stack.count })
		end
		if #list > 0 then
			Remotes.event("Rubbish"):FireServer(list)
		end
	end)

	render()
	return win,
		function(nextProfile: Types.Profile?)
			current = nextProfile
			-- a stack that moved or changed while it lay in the bin is given back
			local inventory = if current then current.inventory else {}
			for i = #staged, 1, -1 do
				local slot = staged[i]
				local now, before = inventory[slot], kept[slot]
				if not now or now.id ~= before.id or now.count ~= before.count then
					table.remove(staged, i)
					kept[slot] = nil
				end
			end
			render()
		end
end

return RubbishWindow
