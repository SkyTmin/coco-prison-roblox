--!strict
-- The running boosters in the top-left HUD, like the original's «$ x1.1 Локальный» [вики 26.10; владелец 27.10:
-- «когда бустер работает сверху слева плашку … если кто-то активировал бустер для всех, там его ник … плашка как
-- загрузка, только в обратную сторону»]: a row per running booster — its bottle, the multiplier, the scope (and who
-- started a faction / global one), the time left — over a bar in the scope's colour that drains as the booster runs
-- out; «+N в очереди» when more of that line wait. A click opens the storage. Refreshed a few times a second.
-- [владелец 28.10: «бар с бустером надо как-то сделать компактнее»] one slim line per booster (26 px, was 42): the
-- bottle, «x2 Глобальный · nick +1», the time; the bar is a thin strip under it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local BoosterHud = {}

local ROW_W, ROW_H = 200, 26
local MAX_ROWS = 6
local SYMBOL = { money = "$ " } -- other kinds: the bottle says which

type Row = {
	button: TextButton,
	icon: ImageLabel,
	text: TextLabel,
	time: TextLabel,
	fill: Frame,
}

function BoosterHud.start(
	gui: Instance,
	getProfile: () -> Types.Profile?,
	t: (string, ...any) -> string,
	onClick: () -> ()
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Boosters"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(ROW_W, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local rows: { Row } = {}
	for i = 1, MAX_ROWS do
		local button = Instance.new("TextButton")
		button.Name = "Booster_" .. i
		button.Text = ""
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(ROW_W, ROW_H)
		button.BackgroundColor3 = Ui.colors.panel
		button.BackgroundTransparency = 0.3
		button.BorderSizePixel = 0
		button.LayoutOrder = i
		button.Visible = false
		button.ClipsDescendants = true
		button.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Position = UDim2.fromOffset(3, 2)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = button
		local text = Ui.rich(button, "", UDim2.new(1, -72, 0, 22), UDim2.fromOffset(26, 1), 12)
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local time = Ui.label(
			button,
			"",
			UDim2.fromOffset(42, 22),
			UDim2.new(1, -45, 0, 1),
			12,
			Ui.colors.white
		)
		time.TextXAlignment = Enum.TextXAlignment.Right
		-- the bar: full when the booster starts, empty when it ends (a loading bar run backwards)
		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, 0, 0, 3)
		track.Position = UDim2.new(0, 0, 1, -3)
		track.BackgroundColor3 = Color3.new(0, 0, 0)
		track.BackgroundTransparency = 0.4
		track.BorderSizePixel = 0
		track.Parent = button
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
		button.Activated:Connect(onClick)
		rows[i] = { button = button, icon = icon, text = text, time = time, fill = fill }
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
		for i, row in ipairs(rows) do
			local a = running[i]
			row.button.Visible = a ~= nil
			if a and p then
				local scope = Boosters.scopeOf(a)
				local color = Boosters.SCOPE_COLORS[scope]
				local left = math.max(0, math.floor(a.endsAt - now))
				local waiting = Boosters.queueAfter(p, a)
				row.icon.Image = Boosters.icon(a.kind, scope)
				-- after the scope: who started a faction / global one, then the queue
				local parts = {}
				if a.by and scope ~= "local" then
					table.insert(
						parts,
						string.format('<font color="%s">%s</font>', Ui.hex(Ui.colors.white), a.by)
					)
				end
				if waiting > 0 then
					table.insert(
						parts,
						string.format(
							'<font color="%s">%s</font>',
							Ui.hex(Ui.colors.muted),
							"+" .. waiting
						)
					)
				end
				row.text.Text = string.format(
					'<font color="%s">%sx%s</font> <font color="%s">%s</font> %s',
					Ui.hex(Ui.colors.green),
					SYMBOL[a.kind] or "",
					tostring(a.mult),
					Ui.hex(color),
					t("booster_scope_" .. scope),
					table.concat(parts, " ")
				)
				row.time.Text = string.format("%d:%02d", left // 60, left % 60)
				row.fill.BackgroundColor3 = color
				row.fill.Size = UDim2.fromScale(
					math.clamp((a.endsAt - now) / math.max(1, a.endsAt - a.startsAt), 0, 1),
					1
				)
			end
		end
	end)
	return frame
end

return BoosterHud
