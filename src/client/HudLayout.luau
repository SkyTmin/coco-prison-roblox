--!strict
-- Movable HUD [владелец 22.10: «добавь в меню настройку, чтобы можно было двигать кнопки, например кнопку есть и
-- кнопку удара; чтобы можно было двигать интерфейс»]. init.client registers the movable elements; the edit mode
-- (menu «Кнопки» on a phone, key H on a computer) outlines them, lets the player drag them with a finger or the
-- mouse (kept on screen) and returns the layout: element id → {x, y}, the element's anchor point as a fraction of
-- its parent (a full-screen frame), separately for "mobile" and "desktop". The server keeps it in the profile
-- (SetHudLayout); apply() puts the saved positions over the default layout.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudLayout = {}

export type Layout = { [string]: { number } }
type Entry = {
	id: string,
	object: GuiObject,
	grip: GuiObject,
	mobile: boolean,
	desktop: boolean,
	default: UDim2, -- its place at registration: back there when the layout is reset
}

local entries: { Entry } = {}
local editing = false

-- grip: the part the player grabs (the menu button of the whole touch menu); the object moves
function HudLayout.register(
	id: string,
	object: GuiObject,
	mobile: boolean,
	desktop: boolean,
	grip: GuiObject?
)
	table.insert(entries, {
		id = id,
		object = object,
		grip = grip or object,
		mobile = mobile,
		desktop = desktop,
		default = object.Position,
	})
end

-- the default place of an element the default layout repositions itself (call before apply)
function HudLayout.setDefault(object: GuiObject)
	for _, e in ipairs(entries) do
		if e.object == object then
			e.default = object.Position
		end
	end
end

local function inMode(e: Entry, mode: string): boolean
	return if mode == "mobile" then e.mobile else e.desktop
end

local function parentOf(object: GuiObject): GuiBase2d?
	local p = object.Parent
	return if p and p:IsA("GuiBase2d") then p else nil
end

-- the saved positions over the default layout (call after the defaults are set)
function HudLayout.apply(mode: string, layout: Layout?)
	for _, e in ipairs(entries) do
		local pos = layout and layout[e.id]
		if inMode(e, mode) and pos then
			e.object.Position = UDim2.fromScale(pos[1], pos[2])
		else
			e.object.Position = e.default
		end
	end
end

function HudLayout.isEditing(): boolean
	return editing
end

-- where the object's anchor point is, as a fraction of its parent
local function fractionOf(object: GuiObject): (number, number)
	local parent = parentOf(object)
	if not parent then
		return 0, 0
	end
	local anchor = object.AbsolutePosition
		+ object.AnchorPoint * object.AbsoluteSize
		- parent.AbsolutePosition
	return anchor.X / math.max(1, parent.AbsoluteSize.X),
		anchor.Y / math.max(1, parent.AbsoluteSize.Y)
end

type Texts = { title: string, done: string, reset: string }

-- Opens the edit mode over gui; onDone(layout) with every movable element's position, or onDone(nil) for
-- «Сбросить» (back to the defaults).
function HudLayout.edit(gui: ScreenGui, mode: string, texts: Texts, onDone: (Layout?) -> ())
	if editing then
		return
	end
	editing = true
	local overlay = Instance.new("Frame")
	overlay.Name = "HudLayoutEditor"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.75
	overlay.ZIndex = 50
	overlay.Parent = gui
	-- the bar at the top: what to do, Готово, Сбросить
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(460, 44)
	bar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	bar.BackgroundTransparency = 0.1
	bar.ZIndex = 52
	bar.Parent = overlay
	local fit = Instance.new("UIScale")
	local viewport = gui.AbsoluteSize
	fit.Scale = math.min(1, (viewport.X - 16) / 460)
	fit.Parent = bar
	Instance.new("UICorner").Parent = bar
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -200, 1, 0)
	title.Position = UDim2.fromOffset(10, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 14
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Text = texts.title
	title.ZIndex = 53
	title.Parent = bar
	local function button(text: string, colour: Color3, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(88, 32)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, x, 0.5, 0)
		b.BackgroundColor3 = colour
		b.Font = Enum.Font.Code
		b.TextSize = 14
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = text
		b.ZIndex = 53
		b.Parent = bar
		Instance.new("UICorner").Parent = b
		return b
	end
	local doneButton = button(texts.done, Color3.fromRGB(40, 160, 70), -8)
	local resetButton = button(texts.reset, Color3.fromRGB(70, 70, 78), -102)
	-- a handle over every movable element of this mode
	local handles: { [Frame]: Entry } = {}
	for _, e in ipairs(entries) do
		if inMode(e, mode) and parentOf(e.object) then
			local h = Instance.new("Frame")
			h.Name = "Handle_" .. e.id
			h.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
			h.BackgroundTransparency = 0.8
			h.ZIndex = 51
			h.Active = true
			h.Parent = overlay
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 220, 80)
			stroke.Thickness = 2
			stroke.Parent = h
			handles[h] = e
		end
	end
	local function sync()
		local origin = overlay.AbsolutePosition
		for h, e in pairs(handles) do
			local g = e.grip
			h.Position =
				UDim2.fromOffset(g.AbsolutePosition.X - origin.X, g.AbsolutePosition.Y - origin.Y)
			h.Size =
				UDim2.fromOffset(math.max(24, g.AbsoluteSize.X), math.max(24, g.AbsoluteSize.Y))
		end
	end
	local syncConnection = RunService.RenderStepped:Connect(sync)
	-- dragging: one element at a time, by the touch or the mouse that grabbed it
	local drag: { entry: Entry, input: InputObject, start: Vector2, from: Vector2 }? = nil
	local connections: { RBXScriptConnection } = { syncConnection }
	for h, e in pairs(handles) do
		table.insert(
			connections,
			h.InputBegan:Connect(function(input)
				if
					drag == nil
					and (
						input.UserInputType == Enum.UserInputType.Touch
						or input.UserInputType == Enum.UserInputType.MouseButton1
					)
				then
					local parent = parentOf(e.object) :: GuiBase2d
					local anchor = e.object.AbsolutePosition
						+ e.object.AnchorPoint * e.object.AbsoluteSize
						- parent.AbsolutePosition
					drag = {
						entry = e,
						input = input,
						start = Vector2.new(input.Position.X, input.Position.Y),
						from = anchor,
					}
				end
			end)
		)
	end
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			local d = drag
			if not d then
				return
			end
			local same = if d.input.UserInputType == Enum.UserInputType.Touch
				then input == d.input
				else input.UserInputType == Enum.UserInputType.MouseMovement
			if not same then
				return
			end
			local object = d.entry.object
			local parent = parentOf(object)
			if not parent then
				return
			end
			local size, anchor, area = object.AbsoluteSize, object.AnchorPoint, parent.AbsoluteSize
			local at = d.from + Vector2.new(input.Position.X, input.Position.Y) - d.start
			-- the whole element stays on the screen
			local x = math.clamp(
				at.X,
				anchor.X * size.X,
				math.max(anchor.X * size.X, area.X - (1 - anchor.X) * size.X)
			)
			local y = math.clamp(
				at.Y,
				anchor.Y * size.Y,
				math.max(anchor.Y * size.Y, area.Y - (1 - anchor.Y) * size.Y)
			)
			object.Position = UDim2.fromScale(x / math.max(1, area.X), y / math.max(1, area.Y))
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			local d = drag
			if
				d
				and (
					input == d.input
					or (
						d.input.UserInputType == Enum.UserInputType.MouseButton1
						and input.UserInputType == Enum.UserInputType.MouseButton1
					)
				)
			then
				drag = nil
			end
		end)
	)
	local function close(result: Layout?)
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		overlay:Destroy()
		editing = false
		onDone(result)
	end
	doneButton.Activated:Connect(function()
		local layout: Layout = {}
		for _, e in pairs(handles) do
			local x, y = fractionOf(e.object)
			layout[e.id] = { math.clamp(x, 0, 1), math.clamp(y, 0, 1) }
		end
		close(layout)
	end)
	resetButton.Activated:Connect(function()
		close(nil)
	end)
	sync()
end

return HudLayout
