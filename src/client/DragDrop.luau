--!strict
-- Shared mouse/touch slot gestures. Only intents leave this module; the server owns stacks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)

export type Address = { container: "case" | "inv", index: number }
type Binding = { frame: Frame, address: Address }

local DragDrop = {}

local function same(a: Address?, b: Address?): boolean
	return a ~= nil and b ~= nil and a.container == b.container and a.index == b.index
end

function DragDrop.new(
	owner: Frame,
	getStack: (Address) -> Types.ItemStack?,
	move: (Address, Address) -> (),
	quick: (Address) -> ()
)
	local bindings: { Binding } = {}
	local connections: { RBXScriptConnection } = {}
	local picked: Address? = nil
	local active: InputObject? = nil
	local source: Address? = nil
	local origin = Vector2.zero
	local moved = false
	local lastTap: Address? = nil
	local lastTime = 0
	local layer = Instance.new("ScreenGui")
	layer.Name = "SlotDrag"
	layer.IgnoreGuiInset = true
	layer.ResetOnSpawn = false
	layer.DisplayOrder = 100
	layer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local ghost, ghostName, ghostCount, ghostIcon = Ui.slot(layer, 44)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.BackgroundTransparency = 0.3
	ghost.Visible = false
	local function setPicked(address: Address?)
		picked = address
		for _, binding in ipairs(bindings) do
			local stroke = binding.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if same(picked, binding.address)
					then Ui.colors.slotSelected
					else Ui.colors.border
			end
		end
	end
	local function cancel()
		active, source = nil, nil
		lastTap = nil
		ghost.Visible = false
		setPicked(nil)
	end
	local function position(input: InputObject): Vector2
		return if input.UserInputType == Enum.UserInputType.Touch
			then Vector2.new(input.Position.X, input.Position.Y)
			else UserInputService:GetMouseLocation()
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
	local function update(input: InputObject)
		if not active then
			return
		end
		if active.UserInputType == Enum.UserInputType.Touch and input ~= active then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseMovement
		then
			return
		end
		local point = position(input)
		moved = moved or (point - origin).Magnitude >= 7
		local stack = if source then getStack(source) else nil
		ghost.Visible = moved and stack ~= nil
		ghost.Position = UDim2.fromOffset(point.X, point.Y)
		if stack then
			local icon = Config.iconFor(stack.id, stack.level)
			ghostIcon.Image, ghostIcon.Visible = icon or "", icon ~= nil
			ghostName.Text =
				Strings.itemName(stack.id, stack.level, Strings.localeOf(Players.LocalPlayer))
			ghostName.Visible = icon == nil
			ghostCount.Text = if stack.count > 1 then tostring(stack.count) else ""
		end
	end
	table.insert(connections, UserInputService.InputChanged:Connect(update))
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if
				not active
				or (input ~= active and input.UserInputType ~= Enum.UserInputType.MouseButton1)
			then
				return
			end
			if active.UserInputType == Enum.UserInputType.Touch and input ~= active then
				return
			end
			if input.UserInputState == Enum.UserInputState.Cancel then
				cancel()
				return
			end
			local destination = slotUnder(position(input))
			local from = source
			active, source = nil, nil
			ghost.Visible = false
			if not from then
				return
			end
			if moved then
				if destination and not same(from, destination) and getStack(from) then
					move(from, destination)
				end
				setPicked(nil)
				lastTap = nil
			elseif same(from, destination) then
				local now = os.clock()
				if same(lastTap, from) and now - lastTime <= 0.32 and getStack(from) then
					setPicked(nil)
					lastTap = nil
					quick(from)
				elseif picked and not same(picked, from) then
					local previous = picked
					setPicked(nil)
					lastTap = nil
					move(previous, from)
				else
					setPicked(if getStack(from) then from else nil)
					lastTap, lastTime = from, now
				end
			else
				setPicked(nil)
			end
		end)
	)
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(cancel))
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
			button.InputBegan:Connect(function(input)
				if
					active
					or (
						input.UserInputType ~= Enum.UserInputType.Touch
						and input.UserInputType ~= Enum.UserInputType.MouseButton1
					)
				then
					return
				end
				if
					UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				then
					setPicked(nil)
					if getStack(address) then
						quick(address)
					end
					return
				end
				active, source, origin, moved = input, address, position(input), false
			end)
		)
	end
	function controller.Selected(): Address?
		return picked
	end
	controller.Clear = cancel
	owner.Destroying:Once(function()
		cancel()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		layer:Destroy()
	end)
	return controller
end

return DragDrop
