--!strict
-- The Minecraft item tooltip box: near-black background with the purple gradient border, one line per
-- ItemInfo line (name first). One tooltip for the whole client, drawn above every window.
-- Mouse: shown while hovering a slot, beside the cursor like Java. Touch: shown for the selected /
-- long-pressed stack, above its slot like Bedrock's Pocket UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemInfo = require(Shared.ItemInfo)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local MAX_WIDTH = 300
local PAD = 7
local TEXT = 15
local SMALL = 12

local ItemTooltip = {}

local box: Frame? = nil

local function ensure(): Frame
	if box and box.Parent then
		return box
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ItemTooltip"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(16, 0, 16)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Active = false
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(80, 0, 255), Color3.fromRGB(40, 0, 127))
	gradient.Parent = stroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = frame
	box = frame
	return frame
end

local builtKey: string? = nil -- the stack (and locale) the labels were built for
local builtSize = Vector2.zero

local function keyOf(stack: Types.ItemStack, locale: string): string
	local books = {}
	for _, book in ipairs(stack.books or {}) do
		table.insert(books, book.id .. book.level)
	end
	return table.concat({
		locale,
		stack.id,
		tostring(stack.count),
		tostring(stack.level),
		tostring(stack.rarity),
		tostring(stack.applyChance),
		tostring(stack.coins),
		table.concat(books, ","),
	}, "|")
end

-- Shows the tooltip for `stack`. `anchor` is a screen point (mouse) or the slot frame (touch).
-- Cheap to call every frame: the lines are rebuilt only when the stack or the language changes.
function ItemTooltip.show(stack: Types.ItemStack, anchor: Vector2 | GuiObject)
	local frame = ensure()
	local locale = Strings.localeOf(Players.LocalPlayer)
	local key = keyOf(stack, locale)
	if key ~= builtKey then
		builtKey = key
		builtSize = ItemTooltip._build(frame, stack, locale)
	end
	ItemTooltip._place(frame, builtSize, anchor)
end

function ItemTooltip._build(frame: Frame, stack: Types.ItemStack, locale: string): Vector2
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local y = PAD
	local width = 0
	for index, line in ipairs(ItemInfo.lines(stack, locale)) do
		local size = if line.small then SMALL else TEXT
		local text = if line.text == "" then " " else line.text
		local bounds = TextService:GetTextSize(text, size, Ui.font, Vector2.new(MAX_WIDTH, 1000))
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Ui.font
		label.TextSize = size
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0.65
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Text = text
		local height = if line.text == "" then math.floor(size * 0.6) else bounds.Y
		label.Size = UDim2.fromOffset(MAX_WIDTH, height)
		label.Position = UDim2.fromOffset(PAD, y)
		label.Parent = frame
		y += height + (if index == 1 then 3 else 1)
		width = math.max(width, bounds.X)
	end
	width = math.min(MAX_WIDTH, width)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child.Size = UDim2.fromOffset(width + 2, child.Size.Y.Offset)
		end
	end
	local size = Vector2.new(width + PAD * 2 + 2, y + PAD - 1)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	return size
end

function ItemTooltip._place(frame: Frame, size: Vector2, anchor: Vector2 | GuiObject)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
	local inset = game:GetService("GuiService"):GetGuiInset().Y
	local position: Vector2
	if typeof(anchor) == "Vector2" then
		-- Java: to the right of and above the cursor; flipped when it would leave the screen
		position = anchor + Vector2.new(14, -size.Y - 6)
		if position.X + size.X > viewport.X - 4 then
			position = Vector2.new(anchor.X - size.X - 14, position.Y)
		end
	else
		-- Bedrock: centred above the slot, or below it when there is no room
		local slot = anchor :: GuiObject
		-- AbsolutePosition starts below the top bar; this layer ignores the inset (screen coordinates)
		local top = slot.AbsolutePosition + Vector2.new(0, inset)
		position = Vector2.new(top.X + slot.AbsoluteSize.X / 2 - size.X / 2, top.Y - size.Y - 8)
		if position.Y < inset + 4 then
			position = Vector2.new(position.X, top.Y + slot.AbsoluteSize.Y + 8)
		end
	end
	position = Vector2.new(
		math.clamp(position.X, 4, math.max(4, viewport.X - size.X - 4)),
		math.clamp(position.Y, inset + 4, math.max(inset + 4, viewport.Y - size.Y - 4))
	)
	frame.Position = UDim2.fromOffset(position.X, position.Y)
	frame.Visible = true
end

function ItemTooltip.hide()
	if box then
		box.Visible = false
	end
end

function ItemTooltip.visible(): boolean
	return box ~= nil and box.Visible
end

return ItemTooltip
