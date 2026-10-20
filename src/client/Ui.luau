--!strict
-- UI kit in the style of the original: dark translucent panels with a thin grey border, pixel-style
-- monospace font, orange headers, green money, blue/green buttons, red close square.
-- (Reference: wiki/in-game-wiki/JOBS-CASES-SPAWN.md, "Стиль интерфейса".)

local Ui = {}

Ui.font = Enum.Font.Code
Ui.colors = {
	panel = Color3.fromRGB(18, 18, 22),
	panelTransparency = 0.15,
	border = Color3.fromRGB(70, 70, 78),
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
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
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
	b.Parent = parent
	return b
end

-- Window with a title strip and a red close square; returns the content frame.
function Ui.window(parent: Instance, title: string, size: UDim2, onClose: () -> ()): (Frame, Frame)
	local win = Ui.panel(parent, size, UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2))
	win.Name = "Window_" .. title
	local titleBar = Ui.panel(win, UDim2.new(1, -44, 0, 28), UDim2.fromOffset(6, 6))
	Ui.label(titleBar, title, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(8, 0), 16, Ui.colors.text)
	local close =
		Ui.button(win, "✕", UDim2.fromOffset(28, 28), UDim2.new(1, -34, 0, 6), Ui.colors.close)
	close.Activated:Connect(onClose)
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -12, 1, -46)
	content.Position = UDim2.fromOffset(6, 40)
	content.BackgroundTransparency = 1
	content.Parent = win
	return win, content
end

function Ui.slot(parent: Instance, size: number): (Frame, TextLabel, TextLabel, ImageLabel)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = Ui.colors.slot
	f.BorderSizePixel = 0
	corner(f, 3)
	stroke(f, Ui.colors.border, 1)
	f.Parent = parent
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromScale(0.76, 0.76)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.ScaleType = Enum.ScaleType.Fit
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.BackgroundTransparency = 1
	image.Visible = false
	image.Parent = f
	local name =
		Ui.label(f, "", UDim2.new(1, -4, 1, -14), UDim2.fromOffset(2, 2), 11, Ui.colors.text)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.TextWrapped = true
	local count =
		Ui.label(f, "", UDim2.new(1, -4, 0, 12), UDim2.new(0, 2, 1, -14), 11, Ui.colors.text)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextStrokeTransparency = 0
	count.ZIndex = image.ZIndex + 1
	return f, name, count, image
end

return Ui
