--!strict
-- Movable HUD [владелец 22.10: «добавь в меню настройку, чтобы можно было двигать кнопки, например кнопку есть и
-- кнопку удара; чтобы можно было двигать интерфейс»]. init.client registers the movable elements; the edit mode
-- (menu «Кнопки» on a phone, key H on a computer) outlines them, lets the player drag them with a finger or the
-- mouse (kept on screen) and returns the layout: element id → {x, y}, the element's anchor point as a fraction of
-- its parent (a full-screen frame), separately for "mobile" and "desktop". The server keeps it in the profile
-- (SetHudLayout); apply() puts the saved positions over the default layout. Optional elements (the attack button
-- [владелец 27.10]) carry a third number: 1 shown, 0 removed; the editor gives them «Убрать» / «Добавить».
-- The fourth number is the player's size for the element [владелец 27.10: «в редакторе … увеличивать или
-- уменьшать кнопки»]: 0.5–2, set with «−» / «+» by the element picked last; it multiplies the element's base
-- scale (setBaseScale — e.g. the smaller stats panel on a phone) through its UIScale.

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
	optional: boolean,
	shownByDefault: boolean,
	base: number, -- the layout's own scale for the element (setBaseScale), before the player's size
}

local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 2, 0.1

local entries: { Entry } = {}
local editing = false
local moved: { [string]: boolean } = {} -- elements the applied layout puts at the player's own place

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
		optional = false,
		shownByDefault = true,
		base = 1,
	})
end

-- the player may remove the element (or add it back) in the editor; shownByDefault = its state with no layout
function HudLayout.setOptional(id: string, shownByDefault: boolean)
	for _, e in ipairs(entries) do
		if e.id == id then
			e.optional, e.shownByDefault = true, shownByDefault
		end
	end
end

-- whether an optional element is on the screen under this layout
local function shownIn(e: Entry, layout: Layout?): boolean
	local pos = layout and layout[e.id]
	if pos and pos[3] ~= nil then
		return pos[3] == 1
	end
	return e.shownByDefault
end

-- the default place of an element the default layout repositions itself (call before apply)
function HudLayout.setDefault(object: GuiObject)
	for _, e in ipairs(entries) do
		if e.object == object then
			e.default = object.Position
		end
	end
end

-- the element's own scale under the default layout (its UIScale gets base × the player's size)
function HudLayout.setBaseScale(object: GuiObject, base: number)
	for _, e in ipairs(entries) do
		if e.object == object then
			e.base = base
		end
	end
end

local function uiScale(object: GuiObject): UIScale
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local created = Instance.new("UIScale")
	created.Parent = object
	return created
end

local function sizeIn(pos: { number }?): number
	local n = pos and pos[4]
	return if typeof(n) == "number" then math.clamp(n, MIN_SCALE, MAX_SCALE) else 1
end

-- the player's size for an element under this layout (1 when unchanged)
function HudLayout.sizeOf(id: string, layout: Layout?): number
	return sizeIn(layout and layout[id])
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
		moved[e.id] = inMode(e, mode) and pos ~= nil
		if inMode(e, mode) and pos then
			e.object.Position = UDim2.fromScale(pos[1], pos[2])
		else
			e.object.Position = e.default
		end
		local size = if inMode(e, mode) then sizeIn(pos) else 1
		if size ~= 1 or e.base ~= 1 or e.object:FindFirstChildOfClass("UIScale") then
			uiScale(e.object).Scale = e.base * size
		end
		if e.optional then
			e.object.Visible = shownIn(e, if inMode(e, mode) then layout else nil)
		end
	end
end

function HudLayout.moved(id: string): boolean
	return moved[id] == true
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

type Texts = { title: string, done: string, reset: string, hide: string, show: string }

local function sizeButton(text: string): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(32, 28)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	b.Font = Enum.Font.Code
	b.TextSize = 20
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.ZIndex = 55
	Instance.new("UICorner").Parent = b
	return b
end

-- Opens the edit mode over gui; onDone(layout) with every movable element's position, or onDone(nil) for
-- «Сбросить» (back to the defaults).
function HudLayout.edit(
	gui: ScreenGui,
	mode: string,
	layout: Layout?,
	texts: Texts,
	onDone: (Layout?) -> ()
)
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
	-- optional elements: shown while editing, the toggle says whether they stay
	local toggles: { [Frame]: TextButton } = {}
	local shown: { [Entry]: boolean } = {}
	local sizes: { [Entry]: number } = {}
	local selected: Entry? = nil
	-- «−  100%  +» by the element picked last
	local sizer = Instance.new("Frame")
	sizer.Name = "Sizer"
	sizer.Size = UDim2.fromOffset(124, 32)
	sizer.AnchorPoint = Vector2.new(0.5, 0)
	sizer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	sizer.BackgroundTransparency = 0.1
	sizer.Visible = false
	sizer.ZIndex = 54
	sizer.Parent = overlay
	Instance.new("UICorner").Parent = sizer
	local minus, plus = sizeButton("−"), sizeButton("+")
	minus.Name, plus.Name = "Smaller", "Bigger"
	minus.Position, plus.Position = UDim2.fromOffset(2, 2), UDim2.new(1, -34, 0, 2)
	minus.Parent, plus.Parent = sizer, sizer
	local percent = Instance.new("TextLabel")
	percent.Size = UDim2.new(1, -72, 1, 0)
	percent.Position = UDim2.fromOffset(36, 0)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.Code
	percent.TextSize = 14
	percent.TextColor3 = Color3.new(1, 1, 1)
	percent.ZIndex = 55
	percent.Parent = sizer
	local function showPercent(e: Entry)
		percent.Text = string.format("%d%%", math.floor((sizes[e] or 1) * 100 + 0.5))
	end
	local function resize(e: Entry, size: number)
		sizes[e] = math.clamp(math.floor(size * 10 + 0.5) / 10, MIN_SCALE, MAX_SCALE)
		uiScale(e.object).Scale = e.base * sizes[e]
		showPercent(e)
	end
	local function choose(e: Entry)
		selected = e
		sizer.Visible = true
		showPercent(e)
	end
	minus.Activated:Connect(function()
		if selected then
			resize(selected, (sizes[selected] or 1) - SCALE_STEP)
		end
	end)
	plus.Activated:Connect(function()
		if selected then
			resize(selected, (sizes[selected] or 1) + SCALE_STEP)
		end
	end)
	local function paint(h: Frame, e: Entry)
		local on = shown[e] ~= false
		local colour = if on then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(150, 150, 150)
		h.BackgroundColor3 = colour
		h.BackgroundTransparency = if on then 0.8 else 0.35
		local stroke = h:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = colour
		end
		local t = toggles[h]
		if t then
			t.Text = if on then texts.hide else texts.show
			t.BackgroundColor3 = if on
				then Color3.fromRGB(170, 50, 50)
				else Color3.fromRGB(40, 150, 70)
		end
	end
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
			sizes[e] = sizeIn(layout and layout[e.id])
			if e.optional then
				shown[e] = shownIn(e, layout)
				e.object.Visible = true
				local t = Instance.new("TextButton")
				t.Name = "Toggle_" .. e.id
				t.Size = UDim2.fromOffset(84, 28)
				t.AnchorPoint = Vector2.new(0.5, 1)
				t.Font = Enum.Font.Code
				t.TextSize = 14
				t.TextColor3 = Color3.new(1, 1, 1)
				t.ZIndex = 54
				t.Parent = overlay
				Instance.new("UICorner").Parent = t
				toggles[h] = t
				t.Activated:Connect(function()
					shown[e] = not shown[e]
					paint(h, e)
				end)
			end
			paint(h, e)
		end
	end
	local function sync()
		local origin = overlay.AbsolutePosition
		local pick = selected
		if pick then -- under the element, or above it when it sits at the bottom
			local g = pick.grip
			local below = g.AbsolutePosition.Y + g.AbsoluteSize.Y - origin.Y + 40
				< overlay.AbsoluteSize.Y
			sizer.AnchorPoint = Vector2.new(0.5, if below then 0 else 1)
			sizer.Position = UDim2.fromOffset(
				math.clamp(
					g.AbsolutePosition.X - origin.X + g.AbsoluteSize.X / 2,
					64,
					math.max(64, overlay.AbsoluteSize.X - 64)
				),
				if below
					then g.AbsolutePosition.Y - origin.Y + g.AbsoluteSize.Y + 4
					else g.AbsolutePosition.Y - origin.Y - 4
			)
		end
		for h, e in pairs(handles) do
			local g = e.grip
			h.Position =
				UDim2.fromOffset(g.AbsolutePosition.X - origin.X, g.AbsolutePosition.Y - origin.Y)
			h.Size =
				UDim2.fromOffset(math.max(24, g.AbsoluteSize.X), math.max(24, g.AbsoluteSize.Y))
			local t = toggles[h]
			if t then -- above the element, or below it when it sits at the top
				local above = g.AbsolutePosition.Y - origin.Y > 36
				t.AnchorPoint = Vector2.new(0.5, if above then 1 else 0)
				t.Position = UDim2.fromOffset(
					g.AbsolutePosition.X - origin.X + g.AbsoluteSize.X / 2,
					if above
						then g.AbsolutePosition.Y - origin.Y - 4
						else g.AbsolutePosition.Y - origin.Y + g.AbsoluteSize.Y + 4
				)
			end
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
					choose(e)
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
		local result: Layout = {}
		for _, e in pairs(handles) do
			local x, y = fractionOf(e.object)
			-- {x, y, shown (1 for elements that cannot be removed), size}
			result[e.id] = {
				math.clamp(x, 0, 1),
				math.clamp(y, 0, 1),
				if not e.optional or shown[e] then 1 else 0,
				sizes[e] or 1,
			}
		end
		close(result)
	end)
	resetButton.Activated:Connect(function()
		close(nil)
	end)
	sync()
end

return HudLayout
