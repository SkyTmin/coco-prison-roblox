--!strict
-- UI kit in the style of the original (reference screenshots, wiki/in-game-wiki/JOBS-CASES-SPAWN.md
-- "Стиль интерфейса"): two looks live side by side, exactly like in the original game:
--   * "dark" — the server's custom menus: dark translucent panels with a thin grey border, pixel font,
--     orange headers, green money, blue/green buttons, close cross (shops, buyer, trainer, artifacts);
--   * "mc"   — vanilla Minecraft container GUIs (chests/cases, inventory): light grey bevelled panel,
--     bevelled slots, dark grey text. One Minecraft pixel = Ui.MC px.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ui = {}

Ui.font = Enum.Font.Code
Ui.colors = {
	panel = Color3.fromRGB(18, 18, 22),
	panelTransparency = 0.15,
	border = Color3.fromRGB(70, 70, 78),
	inset = Color3.fromRGB(12, 12, 15),
	text = Color3.fromRGB(225, 225, 225),
	muted = Color3.fromRGB(150, 150, 158),
	header = Color3.fromRGB(255, 170, 40),
	money = Color3.fromRGB(90, 220, 90),
	level = Color3.fromRGB(80, 170, 255),
	buttonBlue = Color3.fromRGB(40, 110, 220),
	buttonGreen = Color3.fromRGB(40, 160, 70),
	buttonGrey = Color3.fromRGB(60, 60, 68),
	close = Color3.fromRGB(200, 50, 50),
	slot = Color3.fromRGB(30, 30, 36),
	slotSelected = Color3.fromRGB(255, 200, 80),
	-- name colours of the original (Minecraft chat colours) [меню]
	yellow = Color3.fromRGB(255, 255, 85),
	gray = Color3.fromRGB(170, 170, 170),
	white = Color3.fromRGB(255, 255, 255),
	orange = Color3.fromRGB(255, 170, 0),
	green = Color3.fromRGB(85, 255, 85),
	red = Color3.fromRGB(255, 85, 85),
	magenta = Color3.fromRGB(255, 85, 255),
	cyan = Color3.fromRGB(85, 255, 255),
	blue = Color3.fromRGB(85, 85, 255),
	purple = Color3.fromRGB(170, 85, 255),
	-- vanilla Minecraft GUI palette
	mcPanel = Color3.fromRGB(198, 198, 198),
	mcLight = Color3.fromRGB(255, 255, 255),
	mcDark = Color3.fromRGB(85, 85, 85),
	mcSlot = Color3.fromRGB(139, 139, 139),
	mcSlotDark = Color3.fromRGB(55, 55, 55),
	mcText = Color3.fromRGB(64, 64, 64),
	mcButton = Color3.fromRGB(120, 120, 120),
	mcButtonLight = Color3.fromRGB(175, 175, 175),
	mcButtonDark = Color3.fromRGB(70, 70, 70),
}
Ui.MC = 2 -- screen px per Minecraft GUI px (the original runs its GUI at scale 2)
Ui.MC_SLOT = 18 * Ui.MC

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

function Ui.panel(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = Ui.colors.panel
	f.BackgroundTransparency = Ui.colors.panelTransparency
	f.BorderSizePixel = 0
	corner(f, 4)
	stroke(f, Ui.colors.border, 1)
	f.Parent = parent
	return f
end

-- Dark inset box (price lines, requirement boxes of the original).
function Ui.inset(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Ui.panel(parent, size, position)
	f.BackgroundColor3 = Ui.colors.inset
	f.BackgroundTransparency = 0.1
	return f
end

function Ui.label(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number?,
	color: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Ui.font
	l.TextSize = textSize or 16
	l.TextColor3 = color or Ui.colors.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

-- Label with rich text, e.g. "Цена <font color=\"#888\">»</font> <font color=\"#5ADC5A\">0.03$</font>".
function Ui.rich(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number?
): TextLabel
	local l = Ui.label(parent, "", size, position, textSize)
	l.RichText = true
	l.Text = text
	return l
end

function Ui.hex(color: Color3): string
	return "#" .. color:ToHex()
end

function Ui.button(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3?
): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color or Ui.colors.buttonBlue
	b.BorderSizePixel = 0
	b.Font = Ui.font
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	corner(b, 3)
	-- the original's buttons have a lighter 1px edge
	local s = stroke(b, Color3.new(1, 1, 1), 1)
	s.Transparency = 0.75
	b.Parent = parent
	return b
end

-- Window with a title strip and a close cross; returns the content frame.
function Ui.window(parent: Instance, title: string, size: UDim2, onClose: () -> ()): (Frame, Frame)
	local win = Ui.panel(parent, size, UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2))
	win.Name = "Window_" .. title
	win.Active = true -- touches on the window never reach the camera / thumbstick
	local titleBar = Ui.panel(win, UDim2.new(1, -44, 0, 28), UDim2.fromOffset(6, 6))
	titleBar.Name = "TitleBar"
	Ui.label(titleBar, title, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(8, 0), 16, Ui.colors.text)
	-- [владелец 28.10: «нарисуй крестик, чтобы меню закрывать, а то там красный квадрат»] the ✕ glyph is missing from
	-- the font; our pixel cross (Codex → Blender, icon ui_close) grows a little under the mouse
	local close = Instance.new("ImageButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(28, 28)
	close.Position = UDim2.new(1, -34, 0, 6)
	close.BackgroundTransparency = 1
	close.Image = Config.icons.icons.ui_close or ""
	close.ScaleType = Enum.ScaleType.Fit
	close.ResampleMode = Enum.ResamplerMode.Pixelated
	close.Parent = win
	local grow = Instance.new("UIScale")
	grow.Parent = close
	close.MouseEnter:Connect(function()
		TweenService:Create(grow, TweenInfo.new(0.1), { Scale = 1.15 }):Play()
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(grow, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
	close.Activated:Connect(onClose)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -12, 1, -46)
	content.Position = UDim2.fromOffset(6, 40)
	content.BackgroundTransparency = 1
	content.Parent = win
	return win, content
end

-- Window of the original "shop" kind: orange title text in the strip.
function Ui.titleColor(win: Frame, color: Color3)
	local bar = win:FindFirstChild("TitleBar")
	local label = if bar then bar:FindFirstChildOfClass("TextLabel") else nil
	if label then
		label.TextColor3 = color
	end
end

local function slotLabels(
	f: Frame,
	image: ImageLabel,
	textSize: number,
	shadow: boolean
): (TextLabel, TextLabel)
	local name =
		Ui.label(f, "", UDim2.new(1, -4, 1, -14), UDim2.fromOffset(2, 2), 11, Ui.colors.text)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.TextWrapped = true
	local count = Ui.label(
		f,
		"",
		UDim2.new(1, -4, 0, textSize + 2),
		UDim2.new(0, 2, 1, -textSize - 4),
		textSize,
		Ui.colors.white
	)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextStrokeTransparency = if shadow then 0 else 0.4
	count.TextStrokeColor3 = Color3.fromRGB(63, 63, 63)
	count.ZIndex = image.ZIndex + 2
	return name, count
end

local function slotImage(f: Frame, scale: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromScale(scale, scale)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.ScaleType = Enum.ScaleType.Fit
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	local glint = Instance.new("ImageLabel")
	glint.Name = "Glint"
	glint.Size = UDim2.fromScale(1, 1)
	glint.ScaleType = Enum.ScaleType.Fit
	glint.ResampleMode = Enum.ResamplerMode.Pixelated
	glint.BackgroundTransparency = 1
	glint.ImageColor3 = Color3.fromRGB(190, 110, 255)
	glint.ImageTransparency = 0.55
	glint.Visible = false
	glint.ZIndex = image.ZIndex + 1
	glint.Parent = image
	image.BackgroundTransparency = 1
	image.Visible = false
	image.Parent = f
	return image
end

function Ui.slot(parent: Instance, size: number): (Frame, TextLabel, TextLabel, ImageLabel)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = Ui.colors.slot
	f.BorderSizePixel = 0
	corner(f, 3)
	stroke(f, Ui.colors.border, 1)
	f.Parent = parent
	local image = slotImage(f, 0.76)
	local name, count = slotLabels(f, image, 11, false)
	return f, name, count, image
end

-- Inventory slot in our own dark style [владелец 27.10: the vanilla grey inventory looked unprofessional]: a rounded
-- inset lit softly from the top, lighter under the mouse (DragDrop recolours the stroke for the picked-up stack)
local INV_SLOT = Color3.fromRGB(38, 40, 50)
local INV_SLOT_HOVER = Color3.fromRGB(58, 62, 80)
function Ui.invSlot(parent: Instance, size: number): (Frame, TextLabel, TextLabel, ImageLabel)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = INV_SLOT
	f.BorderSizePixel = 0
	corner(f, 5)
	stroke(f, Ui.colors.border, 1)
	local light = Instance.new("UIGradient")
	light.Rotation = 90
	light.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 180))
	light.Parent = f
	f.Parent = parent
	local image = slotImage(f, 0.78)
	local name, count = slotLabels(f, image, 13, true)
	f.MouseEnter:Connect(function()
		f.BackgroundColor3 = INV_SLOT_HOVER
	end)
	f.MouseLeave:Connect(function()
		f.BackgroundColor3 = INV_SLOT
	end)
	return f, name, count, image
end

-- A card inside a window: a slightly lighter rounded block that groups related things.
function Ui.card(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Ui.panel(parent, size, position)
	f.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
	f.BackgroundTransparency = 0
	local c = f:FindFirstChildOfClass("UICorner")
	if c then
		c.CornerRadius = UDim.new(0, 6)
	end
	local s = f:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(52, 54, 66)
	end
	return f
end

-- ---------------------------------------------------------------- vanilla Minecraft GUI look
local function bevel(parent: Instance, thickness: number, light: Color3, dark: Color3)
	local function edge(name: string, size: UDim2, position: UDim2, color: Color3)
		local e = Instance.new("Frame")
		e.Name = name
		e.Size = size
		e.Position = position
		e.BackgroundColor3 = color
		e.BorderSizePixel = 0
		e.ZIndex = parent:IsA("GuiObject") and parent.ZIndex or 1
		e.Parent = parent
	end
	edge("Top", UDim2.new(1, 0, 0, thickness), UDim2.new(), light)
	edge("Left", UDim2.new(0, thickness, 1, 0), UDim2.new(), light)
	edge("Bottom", UDim2.new(1, 0, 0, thickness), UDim2.new(0, 0, 1, -thickness), dark)
	edge("Right", UDim2.new(0, thickness, 1, 0), UDim2.new(1, -thickness, 0, 0), dark)
end

Ui.bevel = bevel

-- Turns a dark window from Ui.window into a vanilla Minecraft container panel (keeps the close
-- button and the viewport scaling of the caller); returns the content frame covering the panel.
function Ui.toMc(win: Frame, content: Frame): Frame
	win.BackgroundColor3 = Ui.colors.mcPanel
	win.BackgroundTransparency = 0
	local s = win:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(30, 30, 30)
	end
	local c = win:FindFirstChildOfClass("UICorner")
	if c then
		c.CornerRadius = UDim.new(0, Ui.MC)
	end
	local bar = win:FindFirstChild("TitleBar")
	if bar then
		bar.Visible = false
	end
	local close = win:FindFirstChild("Close")
	if close and close:IsA("GuiObject") then
		close.Size = UDim2.fromOffset(11 * Ui.MC, 11 * Ui.MC)
		close.Position = UDim2.new(1, -14 * Ui.MC, 0, 3 * Ui.MC)
		close.ZIndex = 5
	end
	bevel(win, Ui.MC * 2, Ui.colors.mcLight, Ui.colors.mcDark)
	content.Position = UDim2.new()
	content.Size = UDim2.fromScale(1, 1)
	return content
end

-- Light grey container panel with the 3D edge of Minecraft GUIs.
function Ui.mcPanel(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = Ui.colors.mcPanel
	f.BorderSizePixel = 0
	corner(f, Ui.MC)
	stroke(f, Color3.fromRGB(30, 30, 30), 1)
	f.Parent = parent
	bevel(f, Ui.MC * 2, Ui.colors.mcLight, Ui.colors.mcDark)
	return f
end

-- Minecraft inventory slot (18×18 GUI px): dark top-left, white bottom-right.
function Ui.mcSlot(parent: Instance, size: number?): (Frame, TextLabel, TextLabel, ImageLabel)
	local px = size or Ui.MC_SLOT
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = Ui.colors.mcSlot
	f.BorderSizePixel = 0
	f.Parent = parent
	bevel(f, Ui.MC, Ui.colors.mcSlotDark, Ui.colors.mcLight)
	-- selection highlight for drag/drop (DragDrop recolours the UIStroke)
	local s = stroke(f, Ui.colors.border, 1)
	s.Transparency = 1
	f:SetAttribute("StrokeHidden", true)
	local image = slotImage(f, 16 / 18)
	local name, count = slotLabels(f, image, 14, true)
	name.TextColor3 = Ui.colors.mcText
	return f, name, count, image
end

function Ui.mcText(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number?
): TextLabel
	return Ui.label(parent, text, size, position, textSize or 8 * Ui.MC, Ui.colors.mcText)
end

-- Minecraft button: grey bevelled, white text with shadow, blue-ish tint on hover.
function Ui.mcButton(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Ui.colors.mcButton
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = Ui.font
	b.TextSize = 8 * Ui.MC
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = Color3.fromRGB(63, 63, 63)
	b.Text = text
	stroke(b, Color3.fromRGB(0, 0, 0), 1)
	b.Parent = parent
	bevel(b, Ui.MC, Ui.colors.mcButtonLight, Ui.colors.mcButtonDark)
	b.MouseEnter:Connect(function()
		if b.Active then
			b.BackgroundColor3 = Color3.fromRGB(126, 136, 191)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = if b.Active then Ui.colors.mcButton else Ui.colors.mcDark
	end)
	return b
end

function Ui.setMcButtonActive(b: TextButton, active: boolean)
	b.Active = active
	b.BackgroundColor3 = if active then Ui.colors.mcButton else Ui.colors.mcDark
	b.TextColor3 = if active then Color3.new(1, 1, 1) else Ui.colors.gray
end

return Ui
