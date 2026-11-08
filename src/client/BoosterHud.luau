--!strict
-- The running boosters in the top-left HUD [владелец 27.10: «когда бустер работает сверху слева плашку … если кто-то
-- активировал бустер для всех, там его ник … плашка как загрузка, только в обратную сторону»].
-- [владелец 08.11: «бар бустеров сделать понятным, он обрезан и стиль ужасен»] One card per KIND (blocks, money,
-- mobs) instead of a line per booster: the bottle, the kind and its TOTAL multiplier in large type (the boosters add
-- up, Shared/Boosters.multiplier), one coloured pill per running source (blue local, orange faction, red global,
-- green gang, the Дворы point) with its own multiplier, the time left of the source that ends first and a thin bar
-- that drains with it. The nickname of whoever started a shared booster stays in its pill. Nothing is truncated: the
-- pills wrap onto a second line and the card grows. A click opens the storage. Refreshed five times a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local BoosterHud = {}

local CARD_W = 220
local ICON = 34
local PILL_H = 16
local POINT_COLOR = Color3.fromRGB(255, 214, 90)

type Card = {
	button: TextButton,
	icon: ImageLabel,
	title: TextLabel,
	mult: TextLabel,
	time: TextLabel,
	pills: Frame,
	fill: Frame,
	pillPool: { TextLabel },
}

local function fmtMult(m: number): string
	if math.abs(m - math.round(m)) < 0.001 then
		return "x" .. tostring(math.round(m))
	end
	return "x" .. string.format("%.1f", m)
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%d:%02d:%02d", sec // 3600, (sec // 60) % 60, sec % 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function newCard(parent: Instance, order: number, onClick: () -> ()): Card
	local button = Instance.new("TextButton")
	button.Name = "BoosterCard_" .. order
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(CARD_W, 0)
	button.AutomaticSize = Enum.AutomaticSize.Y
	button.BackgroundColor3 = Ui.colors.panel
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.LayoutOrder = order
	button.Visible = false
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 1
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.Position = UDim2.fromOffset(0, 0)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = button

	-- top line: «Блоки» on the left, the total «x6» after it, the time on the right
	local title = Ui.label(
		button,
		"",
		UDim2.fromOffset(80, 18),
		UDim2.fromOffset(ICON + 6, 0),
		13,
		Ui.colors.white
	)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.AutomaticSize = Enum.AutomaticSize.X
	local mult = Ui.label(
		button,
		"",
		UDim2.fromOffset(40, 18),
		UDim2.fromOffset(ICON + 6, 0),
		16,
		Ui.colors.green
	)
	mult.TextXAlignment = Enum.TextXAlignment.Left
	mult.AutomaticSize = Enum.AutomaticSize.X
	local time =
		Ui.label(button, "", UDim2.fromOffset(56, 18), UDim2.new(1, -56, 0, 0), 13, Ui.colors.white)
	time.TextXAlignment = Enum.TextXAlignment.Right

	-- the sources as pills that wrap
	local pills = Instance.new("Frame")
	pills.Name = "Pills"
	pills.BackgroundTransparency = 1
	pills.Position = UDim2.fromOffset(ICON + 6, 20)
	pills.Size = UDim2.new(1, -(ICON + 6), 0, PILL_H)
	pills.AutomaticSize = Enum.AutomaticSize.Y
	pills.Parent = button
	local flow = Instance.new("UIListLayout")
	flow.FillDirection = Enum.FillDirection.Horizontal
	flow.Wraps = true
	flow.Padding = UDim.new(0, 3)
	flow.SortOrder = Enum.SortOrder.LayoutOrder
	flow.Parent = pills

	-- the drain bar along the bottom edge
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 10, 0, 3)
	track.Position = UDim2.new(0, -4, 1, 5)
	track.BackgroundColor3 = Color3.new(0, 0, 0)
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.Parent = button
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track

	button.Activated:Connect(onClick)
	return {
		button = button,
		icon = icon,
		title = title,
		mult = mult,
		time = time,
		pills = pills,
		fill = fill,
		pillPool = {},
	}
end

local function pill(card: Card, i: number): TextLabel
	local p = card.pillPool[i]
	if not p then
		p = Instance.new("TextLabel")
		p.Name = "Pill_" .. i
		p.LayoutOrder = i
		p.Size = UDim2.fromOffset(0, PILL_H)
		p.AutomaticSize = Enum.AutomaticSize.X
		p.BackgroundTransparency = 0.1
		p.BorderSizePixel = 0
		p.Font = Enum.Font.GothamBold
		p.TextSize = 11
		p.TextColor3 = Color3.new(1, 1, 1)
		p.RichText = true
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = p
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 5)
		pad.PaddingRight = UDim.new(0, 5)
		pad.Parent = p
		p.Parent = card.pills
		card.pillPool[i] = p
	end
	return p
end

function BoosterHud.start(
	gui: Instance,
	getProfile: () -> Types.Profile?,
	t: (string, ...any) -> string,
	onClick: () -> ()
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Boosters"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(CARD_W, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local cards: { [string]: Card } = {}
	for i, kind in ipairs(Boosters.kinds) do
		cards[kind] = newCard(frame, i, onClick)
	end

	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		if clock < nextAt then
			return
		end
		nextAt = clock + 0.2
		local p = getProfile()
		-- the player may hide the bar in the settings [владелец 27.10]
		frame.Visible = not (p and p.settings and p.settings.hideBoosters == true)
		local now = Boosters.now()
		local running = if p then Boosters.runningAll(p, now) else {}
		for _, kind in ipairs(Boosters.kinds) do
			local card = cards[kind]
			local list = {}
			for _, a in ipairs(running) do
				if a.kind == kind then
					table.insert(list, a)
				end
			end
			card.button.Visible = #list > 0
			if #list > 0 and p then
				-- the source that ends first drives the timer and the bar
				table.sort(list, function(a, b)
					return a.endsAt < b.endsAt
				end)
				local first = list[1]
				card.icon.Image = Boosters.icon(kind, Boosters.scopeOf(first))
				card.title.Text = t("booster_kind_" .. kind)
				card.mult.Text = fmtMult(Boosters.multiplier(p, kind, now))
				card.mult.Position = UDim2.fromOffset(ICON + 6 + card.title.TextBounds.X + 6, -1)
				card.time.Text = fmtTime(first.endsAt - now)
				card.fill.BackgroundColor3 = if first.point
					then POINT_COLOR
					else Boosters.SCOPE_COLORS[Boosters.scopeOf(first)]
				card.fill.Size = UDim2.fromScale(
					math.clamp(
						(first.endsAt - now) / math.max(1, first.endsAt - first.startsAt),
						0,
						1
					),
					1
				)
				for i, a in ipairs(list) do
					local scope = Boosters.scopeOf(a)
					local label = pill(card, i)
					label.Visible = true
					if a.point then
						label.BackgroundColor3 = Color3.fromRGB(120, 95, 20)
						label.Text = "+"
							.. string.format("%.1f", a.mult - 1)
							.. " "
							.. t("warzone_point_" .. a.point)
					else
						local waiting = Boosters.queueAfter(p, a)
						local parts = { fmtMult(a.mult), t("booster_scope_" .. scope) }
						if a.by and scope ~= "local" then
							table.insert(parts, "· " .. a.by)
						end
						if waiting > 0 then
							table.insert(parts, "+" .. waiting)
						end
						label.BackgroundColor3 = (Boosters.SCOPE_COLORS[scope] or Ui.colors.panel):Lerp(
							Color3.new(0, 0, 0),
							0.45
						)
						label.Text = table.concat(parts, " ")
					end
				end
				for i = #list + 1, #card.pillPool do
					card.pillPool[i].Visible = false
				end
			end
		end
	end)
	return frame
end

return BoosterHud
