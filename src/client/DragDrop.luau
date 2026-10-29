--!strict
-- Slot gestures copied from Minecraft; only intents leave this module, the server owns every stack.
--
-- Mouse (Java Edition):
--   left click          pick up the whole stack / put it down (empty → move, same item → merge,
--                       other item → swap, the slot it came from → cancel)
--   right click         pick up half of a stack / put down one item of the held stack
--   shift + click       quick move to the other container (or hotbar ↔ bag)
--   drag with the left button held over several free slots → the held stack is spread evenly
-- Touch (Bedrock Edition, Pocket UI):
--   tap                 select the stack (it sticks to the finger) / tap a slot to put it there
--   drag                carry the stack with the finger and drop it on a slot
--   hold (0.35 s)       split: a green bar appears, slide the finger up or down to choose how many
--                       to take, lift the finger — that part is now selected
--   double tap          quick move to the other container
-- Item info (Minecraft tooltip, ItemTooltip): mouse — while hovering a slot with nothing on the cursor;
-- touch — only while a slot is long-pressed (also during the split bar), gone when the finger lifts.
-- Both: drag a stack out of the window and let go → it is thrown on the ground (throw, when given).
-- A move is sent as move(from, to, count?) — count nil means "the whole stack".
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BlockColors = require(ReplicatedStorage.Shared.BlockColors)
local Ui = require(script.Parent.Ui)
local ItemTooltip = require(script.Parent.ItemTooltip)

export type Address = { container: "case" | "inv" | "armor", index: number }
type Binding = { frame: Frame, address: Address }
type Held = { from: Address, count: number? } -- count nil = whole stack

local DragDrop = {}

local HOLD_SPLIT = 0.35 -- s of touch hold before the split bar appears
local DRAG_SLOP = 7 -- px before a press becomes a drag
local DOUBLE_TAP = 0.32 -- s

-- GetMouseLocation is screen-relative; GUI hit tests / AbsolutePosition and touch input exclude the top inset.
local function mousePosition(): Vector2
	local inset = GuiService:GetGuiInset()
	return UserInputService:GetMouseLocation() - inset
end

local function same(a: Address?, b: Address?): boolean
	return a ~= nil and b ~= nil and a.container == b.container and a.index == b.index
end

function DragDrop.new(
	owner: Frame,
	getStack: (Address) -> Types.ItemStack?,
	move: (Address, Address, number?) -> (),
	quick: (Address) -> (),
	throw: ((Address, number?) -> ())?
)
	local bindings: { Binding } = {}
	local connections: { RBXScriptConnection } = {}
	local held: Held? = nil -- the stack "on the cursor"
	local active: InputObject? = nil -- the press being tracked
	local pressAddress: Address? = nil
	local origin = Vector2.zero
	local moved = false
	local dragPath: { Address } = {} -- distinct free/same slots crossed while dragging with a held stack
	local lastTap: Address? = nil
	local lastTapAt = 0
	local splitting = false
	local splitCount = 0
	local hoverAddress: Address? = nil -- mouse over this slot
	local touchFocus: Address? = nil -- long-pressed slot (touch)
	local lastTouch = false -- the last slot press was a touch

	local layer = Instance.new("ScreenGui")
	layer.Name = "SlotDrag"
	layer.IgnoreGuiInset = true
	layer.ResetOnSpawn = false
	layer.DisplayOrder = 100
	layer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local ghost, ghostName, ghostCount, ghostIcon = Ui.invSlot(layer, 44)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.BackgroundTransparency = 0.3
	ghost.Visible = false
	-- Bedrock split bar: green fill shows the part being taken
	local splitBar = Ui.inset(layer, UDim2.fromOffset(160, 22), UDim2.new())
	splitBar.AnchorPoint = Vector2.new(0.5, 1)
	splitBar.Visible = false
	local splitFill = Instance.new("Frame")
	splitFill.Size = UDim2.fromScale(0, 1)
	splitFill.BackgroundColor3 = Ui.colors.money
	splitFill.BorderSizePixel = 0
	splitFill.Parent = splitBar
	local splitText =
		Ui.label(splitBar, "", UDim2.fromScale(1, 1), UDim2.new(), 13, Ui.colors.white)
	splitText.TextXAlignment = Enum.TextXAlignment.Center
	splitText.TextStrokeTransparency = 0
	splitText.ZIndex = 3

	local function frameOf(address: Address): Frame?
		for _, binding in ipairs(bindings) do
			if same(binding.address, address) then
				return binding.frame
			end
		end
		return nil
	end
	local function paintSelection()
		for _, binding in ipairs(bindings) do
			local stroke = binding.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				local selected = held ~= nil and same(held.from, binding.address)
				stroke.Color = if selected then Ui.colors.slotSelected else Ui.colors.border
				if binding.frame:GetAttribute("StrokeHidden") then
					stroke.Transparency = if selected then 0 else 1
					stroke.Thickness = 2
				end
			end
			-- the picked-up stack is drawn on the cursor, so the slot shows it dimmed
			local icon = binding.frame:FindFirstChild("Icon")
			if icon and icon:IsA("ImageLabel") then
				local dim = held ~= nil and same(held.from, binding.address)
				icon.ImageTransparency = if dim then 0.6 else 0
			end
		end
	end
	local function showGhost(point: Vector2)
		local stack = if held then getStack(held.from) else nil
		if not stack then
			ghost.Visible = false
			return
		end
		local icon = Config.iconFor(stack.id, stack.level)
		local tint = Color3.new(1, 1, 1)
		if not icon then
			icon, tint = BlockColors.icon(stack.id)
		end
		local tile = if not icon then BlockColors.of(stack.id) else nil
		ghostIcon.Image, ghostIcon.Visible = icon or "", true
		ghostIcon.ImageColor3 = tint
		ghostIcon.BackgroundColor3 = tile or Color3.new()
		ghostIcon.BackgroundTransparency = if tile then 0 else 1
		ghostName.Text =
			Strings.itemName(stack.id, stack.level, Strings.localeOf(Players.LocalPlayer))
		ghostName.Visible = false
		local count = if held and held.count then held.count else stack.count
		ghostCount.Text = if count > 1 then tostring(count) else ""
		local localPoint = point - layer.AbsolutePosition
		ghost.Position = UDim2.fromOffset(localPoint.X, localPoint.Y)
		ghost.Visible = true
	end
	local function setHeld(value: Held?)
		held = value
		if not held then
			ghost.Visible = false
		end
		paintSelection()
	end
	local function position(input: InputObject): Vector2
		return if input.UserInputType == Enum.UserInputType.Touch
			then Vector2.new(input.Position.X, input.Position.Y)
			else mousePosition()
	end
	local function slotUnder(point: Vector2): Address?
		-- GUI hit testing respects UIScale, insets, and overlapping windows.
		for _, object in
			ipairs(Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y))
		do
			if not object:IsDescendantOf(layer) then
				for _, binding in ipairs(bindings) do
					if object == binding.frame or object:IsDescendantOf(binding.frame) then
						return binding.address
					end
				end
				if object:IsA("GuiButton") then
					return nil
				end
			end
		end
		return nil
	end
	local function shiftDown(): boolean
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end

	-- Put the held stack (or `count` of it) on `target`.
	local function place(target: Address, count: number?)
		local h = held
		if not h then
			return
		end
		if same(h.from, target) then
			setHeld(nil) -- back where it came from
			return
		end
		local source = getStack(h.from)
		if not source then
			setHeld(nil)
			return
		end
		local amount = count or h.count
		local destination = getStack(target)
		if amount and destination and destination.id ~= source.id then
			return -- Minecraft: a partial stack cannot be dropped on a different item
		end
		move(h.from, target, amount)
		if amount and amount < (h.count or source.count) then
			-- some of the held stack remains on the cursor
			setHeld({ from = h.from, count = (h.count or source.count) - amount })
		else
			setHeld(nil)
		end
	end
	local function pick(address: Address, half: boolean)
		local stack = getStack(address)
		if not stack then
			return
		end
		setHeld({
			from = address,
			count = if half and stack.count > 1 then math.ceil(stack.count / 2) else nil,
		})
	end
	local function distribute(path: { Address })
		local h = held
		if not h then
			return
		end
		local stack = getStack(h.from)
		if not stack then
			setHeld(nil)
			return
		end
		local total = h.count or stack.count
		local targets: { Address } = {}
		for _, address in ipairs(path) do
			if not same(address, h.from) then
				local at = getStack(address)
				if at == nil or at.id == stack.id then
					table.insert(targets, address)
				end
			end
		end
		if #targets == 0 then
			return
		end
		if #targets == 1 then
			place(targets[1])
			return
		end
		local each = math.floor(total / #targets)
		if each == 0 then
			return
		end
		for _, target in ipairs(targets) do
			move(h.from, target, each)
		end
		setHeld(nil)
	end
	local function endSplit(point: Vector2)
		splitting = false
		splitBar.Visible = false
		local address = pressAddress
		local stack = if address then getStack(address) else nil
		if address and stack and splitCount > 0 and splitCount < stack.count then
			setHeld({ from = address, count = splitCount })
			showGhost(point)
		elseif address and stack then
			setHeld({ from = address })
			showGhost(point)
		end
	end
	local function cancel()
		active, pressAddress = nil, nil
		moved = false
		table.clear(dragPath)
		splitting = false
		splitBar.Visible = false
		lastTap = nil
		touchFocus = nil
		setHeld(nil)
	end

	local function update(input: InputObject)
		local a = active
		if not a then
			return
		end
		if a.UserInputType == Enum.UserInputType.Touch and input ~= a then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseMovement
		then
			return
		end
		local point = position(input)
		if splitting then
			-- Bedrock: slide up/down to choose the amount (bar above the finger)
			local stack = if pressAddress then getStack(pressAddress) else nil
			if stack then
				local k = math.clamp((origin.Y - point.Y) / 120 + 0.5, 0, 1)
				splitCount = math.clamp(math.floor(k * stack.count + 0.5), 1, stack.count)
				splitFill.Size = UDim2.fromScale(splitCount / stack.count, 1)
				splitText.Text = string.format("%d / %d", splitCount, stack.count)
			end
			return
		end
		if not moved and (point - origin).Magnitude >= DRAG_SLOP then
			moved = true
			if not held and pressAddress and getStack(pressAddress) then
				setHeld({ from = pressAddress }) -- dragging straight from a slot picks it up
			end
		end
		if moved and held then
			showGhost(point)
			local over = slotUnder(point)
			if over and a.UserInputType ~= Enum.UserInputType.Touch then
				local known = false
				for _, address in ipairs(dragPath) do
					if same(address, over) then
						known = true
					end
				end
				if not known then
					table.insert(dragPath, over)
				end
			end
		end
	end
	table.insert(connections, UserInputService.InputChanged:Connect(update))

	local function release(input: InputObject)
		local a = active
		if not a then
			return
		end
		if a.UserInputType == Enum.UserInputType.Touch then
			if input ~= a then
				return
			end
		elseif
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.MouseButton2
		then
			return
		end
		touchFocus = nil
		local point = position(input)
		local isTouch = a.UserInputType == Enum.UserInputType.Touch
		local rightButton = a.UserInputType == Enum.UserInputType.MouseButton2
		active = nil
		if input.UserInputState == Enum.UserInputState.Cancel then
			cancel()
			return
		end
		if splitting then
			endSplit(point)
			pressAddress = nil
			return
		end
		local target = slotUnder(point)
		local from = pressAddress
		pressAddress = nil
		if moved then
			-- drag and drop
			if held then
				if isTouch or #dragPath <= 1 then
					local pos, size = owner.AbsolutePosition, owner.AbsoluteSize
					local outside = point.X < pos.X
						or point.Y < pos.Y
						or point.X > pos.X + size.X
						or point.Y > pos.Y + size.Y
					if target then
						place(target)
					elseif throw and outside and held.from.container == "inv" then
						throw(held.from, held.count) -- Minecraft: dropped outside the window
						setHeld(nil)
					elseif from and held and same(held.from, from) and not isTouch then
						setHeld(nil)
					end
				else
					distribute(dragPath)
				end
			end
			table.clear(dragPath)
			if held and isTouch then
				ghost.Visible = false -- touch: a selected stack is shown by its slot highlight, not a ghost
			end
			return
		end
		if not from or not same(from, target) then
			return
		end
		-- tap / click on a slot
		local now = os.clock()
		if isTouch then
			if same(lastTap, from) and now - lastTapAt <= DOUBLE_TAP and getStack(from) then
				lastTap = nil
				setHeld(nil)
				quick(from)
				return
			end
			lastTap, lastTapAt = from, now
			if held then
				place(from)
			else
				pick(from, false)
			end
			return
		end
		if rightButton then
			if held then
				place(from, 1)
			else
				pick(from, true)
			end
		else
			if held then
				place(from)
			else
				pick(from, false)
			end
		end
	end
	table.insert(connections, UserInputService.InputEnded:Connect(release))
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(cancel))
	-- the ghost follows the mouse while something is held
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			if held and not active and UserInputService.MouseEnabled and not lastTouch then
				showGhost(mousePosition())
			end
			-- item info
			local tipAddress: Address? = nil
			local tipAnchor: (Vector2 | GuiObject)? = nil
			if lastTouch then
				-- only while the finger stays on a slot [владелец 28.10: «сведения должны открываться, когда держишь
				-- палец на предмете, а то текст мешает»]: a tap that selects a stack shows nothing
				tipAddress = touchFocus
				tipAnchor = if tipAddress then frameOf(tipAddress) else nil
			elseif hoverAddress and not held and not active then
				tipAddress, tipAnchor = hoverAddress, UserInputService:GetMouseLocation()
			end
			local tipStack = if tipAddress then getStack(tipAddress) else nil
			if tipStack and tipAnchor then
				ItemTooltip.show(tipStack, tipAnchor)
			else
				ItemTooltip.hide()
			end
			if splitting and active then
				local f = if pressAddress then frameOf(pressAddress) else nil
				if f then
					splitBar.Position = UDim2.fromOffset(
						f.AbsolutePosition.X + f.AbsoluteSize.X / 2 - layer.AbsolutePosition.X,
						f.AbsolutePosition.Y - 8 - layer.AbsolutePosition.Y
					)
					splitBar.Visible = true
				end
			end
		end)
	)

	local controller = {}
	function controller.Bind(frame: Frame, address: Address)
		table.insert(bindings, { frame = frame, address = address })
		local button = Instance.new("TextButton")
		button.Name = "SlotInput"
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Size = UDim2.fromScale(1, 1)
		button.ZIndex = 10
		button.Parent = frame
		table.insert(
			connections,
			button.MouseEnter:Connect(function()
				if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
					hoverAddress = address
				end
			end)
		)
		table.insert(
			connections,
			button.MouseLeave:Connect(function()
				if same(hoverAddress, address) then
					hoverAddress = nil
				end
			end)
		)
		table.insert(
			connections,
			button.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if
					active
					or (
						kind ~= Enum.UserInputType.Touch
						and kind ~= Enum.UserInputType.MouseButton1
						and kind ~= Enum.UserInputType.MouseButton2
					)
				then
					return
				end
				if kind ~= Enum.UserInputType.Touch and shiftDown() then
					setHeld(nil)
					if getStack(address) then
						quick(address)
					end
					return
				end
				active, pressAddress, origin, moved = input, address, position(input), false
				table.clear(dragPath)
				lastTouch = kind == Enum.UserInputType.Touch
				if lastTouch and getStack(address) then
					-- long press shows the item info (with or without the split bar)
					local press = input
					task.delay(HOLD_SPLIT, function()
						if active == press and not moved then
							touchFocus = address
						end
					end)
				end
				if kind == Enum.UserInputType.Touch and not held then
					local stack = getStack(address)
					if stack and stack.count > 1 then
						local press = input
						task.delay(HOLD_SPLIT, function()
							if active == press and not moved and not held then
								splitting = true
								splitCount = math.ceil(stack.count / 2)
								splitFill.Size = UDim2.fromScale(splitCount / stack.count, 1)
								splitText.Text = string.format("%d / %d", splitCount, stack.count)
							end
						end)
					end
				end
			end)
		)
	end
	-- the stack currently on the cursor / selected by a tap
	function controller.Selected(): Address?
		return if held then held.from else nil
	end
	controller.Clear = cancel
	owner.Destroying:Once(function()
		cancel()
		ItemTooltip.hide()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		layer:Destroy()
	end)
	return controller
end

return DragDrop
