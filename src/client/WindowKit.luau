--!strict
-- The look of the "designer" windows (LevelWindow, TrainerWindow, JobsWindow) [владелец 27.10: «Включай дизайнерскую
-- мощь»; «к навыкам, там тоже нужна интерактивность и в меню Работы тоже»]: dark cards that light up under the mouse,
-- bars that slide, buttons that sink when pressed and glow when they can be pressed, pops, flashes and «+1» that
-- floats up. Everything is updated in place: a window built once stays alive while the profile changes.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Ui = require(script.Parent.Ui)

local Kit = {}

Kit.GOOD = Color3.fromRGB(90, 220, 110)
Kit.BAD = Color3.fromRGB(255, 95, 95)
Kit.CARD = Color3.fromRGB(24, 26, 34)
Kit.CARD_HOVER = Color3.fromRGB(34, 37, 48)
Kit.EDGE = Color3.fromRGB(52, 54, 66)
Kit.TRACK = Color3.fromRGB(10, 10, 14)
Kit.GREY = Color3.fromRGB(58, 60, 72)
Kit.SLIDE = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Kit.BOLD = Enum.Font.GothamBold
Kit.TEXT = Enum.Font.GothamMedium

function Kit.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function Kit.stroke(
	parent: Instance,
	color: Color3,
	thickness: number,
	transparency: number?
): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Kit.frame(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size, f.Position = size, position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Kit.text(
	parent: Instance,
	value: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size, l.Position = size, position
	l.Font = font or Kit.TEXT
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = true
	l.Text = value
	l.Parent = parent
	return l
end

function Kit.image(parent: Instance, image: string?, size: UDim2, position: UDim2): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Size, i.Position = size, position
	i.Image = image or ""
	i.ScaleType = Enum.ScaleType.Fit
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.Parent = parent
	return i
end

function Kit.colored(value: string, color: Color3): string
	return '<font color="' .. Ui.hex(color) .. '">' .. value .. "</font>"
end

function Kit.gradient(parent: Instance, a: Color3, b: Color3, rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation
	g.Parent = parent
	return g
end

-- a progress bar: the dark track and its fill (0..1, slid by set)
export type Bar = { track: Frame, fill: Frame, set: (number) -> () }
function Kit.bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): Bar
	local track = Kit.frame(parent, size, position, Kit.TRACK)
	Kit.corner(track, 5)
	Kit.stroke(track, Kit.EDGE, 1, 0.3)
	local fill = Kit.frame(track, UDim2.fromScale(0, 1), UDim2.new(), color)
	Kit.corner(fill, 5)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	shine.Rotation = 90
	shine.Parent = fill
	local shown = -1
	return {
		track = track,
		fill = fill,
		set = function(k: number)
			k = math.clamp(k, 0, 1)
			if math.abs(k - shown) < 1e-4 then
				return
			end
			shown = k
			TweenService:Create(fill, Kit.SLIDE, { Size = UDim2.fromScale(k, 1) }):Play()
		end,
	}
end

-- a card that lights up under the mouse
function Kit.hoverable(f: GuiObject, base: Color3?, hover: Color3?)
	local a, b = base or Kit.CARD, hover or Kit.CARD_HOVER
	f.MouseEnter:Connect(function()
		TweenService:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = b }):Play()
	end)
	f.MouseLeave:Connect(function()
		TweenService:Create(f, TweenInfo.new(0.2), { BackgroundColor3 = a }):Play()
	end)
end

local function scaleOf(g: GuiObject): UIScale
	local s = g:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = g
	end
	return s :: UIScale
end

-- the button sinks a little under the finger / mouse and springs back
function Kit.pressable(button: GuiButton)
	local s = scaleOf(button)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			TweenService:Create(s, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
		end
	end)
	button.InputEnded:Connect(function()
		TweenService:Create(
			s,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)
end

-- a big coloured button: the TextButton itself is clear, its colour is a child `back` (put the gradient there) and its
-- text a child `label` above it — a UIGradient on a TextButton would tint the text too and make it unreadable
function Kit.actionButton(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	textSize: number
): (TextButton, TextLabel, Frame)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size, button.Position = size, position
	button.Parent = parent
	Kit.corner(button, 10)
	local back = Kit.frame(button, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1))
	Kit.corner(back, 10)
	local label = Kit.text(
		button,
		"",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		textSize,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 2
	local edge = Instance.new("UIStroke")
	edge.Thickness = 1.5
	edge.Transparency = 0.45
	edge.Parent = label
	return button, label, back
end

-- the text shrinks to its box when it would not fit (long names, other languages, two-digit numbers), never grows
-- above its own size
function Kit.fit(label: TextLabel)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = label.TextSize
	limit.MinTextSize = 8
	limit.Parent = label
	label.TextScaled = true
end

-- a short bounce: bigger, then back
function Kit.pop(g: GuiObject, size: number?)
	local s = scaleOf(g)
	s.Scale = size or 1.25
	TweenService
		:Create(
			s,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		:Play()
end

-- a glowing edge that breathes while `on`; returns the switch
function Kit.glow(g: GuiObject, color: Color3): (boolean) -> ()
	local edge = Kit.stroke(g, color, 2.5, 1)
	local tween: Tween? = nil
	local lit = false
	return function(on: boolean)
		if on == lit then
			return
		end
		lit = on
		if tween then
			tween:Cancel()
			tween = nil
		end
		if on then
			edge.Transparency = 0.7
			local t = TweenService:Create(
				edge,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0 }
			)
			t:Play()
			tween = t
		else
			edge.Transparency = 1
		end
	end
end

-- a white sheet over a card that fades out
function Kit.flash(card: GuiObject, color: Color3?)
	local sheet = Kit.frame(card, UDim2.fromScale(1, 1), UDim2.new(), color or Color3.new(1, 1, 1))
	sheet.BackgroundTransparency = 0.55
	sheet.ZIndex = 20
	local c = card:FindFirstChildOfClass("UICorner")
	if c then
		Kit.corner(sheet, c.CornerRadius.Offset)
	end
	local t = TweenService:Create(sheet, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	t.Completed:Once(function()
		sheet:Destroy()
	end)
	t:Play()
end

-- «+1» (any text) that rises from a point of a card and fades
function Kit.floatText(parent: GuiObject, value: string, color: Color3, at: UDim2)
	local l = Kit.text(parent, value, UDim2.fromOffset(160, 30), at, 24, color, Kit.BOLD)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.ZIndex = 21
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Transparency = 0.3
	edge.Parent = l
	local t = TweenService:Create(
		l,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = at - UDim2.fromOffset(0, 40), TextTransparency = 1 }
	)
	TweenService:Create(edge, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	t.Completed:Once(function()
		l:Destroy()
	end)
	t:Play()
end

-- a picture that floats up and down slowly while it lives
function Kit.bob(g: GuiObject, amplitude: number, period: number?)
	local base = g.Position
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		if not g.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local k = math.sin((os.clock() - started) * 2 * math.pi / (period or 2.6))
		g.Position = base + UDim2.fromOffset(0, k * amplitude)
	end)
end

return Kit
