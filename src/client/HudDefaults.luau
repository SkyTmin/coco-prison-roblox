--!strict
-- Gameplay HUD geometry only. Window layouts and saved player customizations are separate.
local Defaults = {}
export type Rect = { x: number, y: number, width: number, height: number }
local function rect(x: number, y: number, width: number, height: number): Rect
	return { x = x, y = y, width = width, height = height }
end
function Defaults.phone(width: number, height: number, inset: number)
	-- Owner reference: docs/research/owner-hud-layout-2026-11-03.json (750x381).
	local portrait = width < height
	local slot = if portrait
		then math.max(24, math.floor((width - 40) / 9) - 2)
		else math.clamp(math.floor((width - 352) / 9), if width < 640 then 28 else 32, 36)
	local barWidth, barHeight = 9 * slot + 28, slot + 12
	local bar = rect(
		(width - barWidth) / 2 + (if width < 640 and not portrait then 10 else 0),
		height - barHeight,
		barWidth,
		barHeight
	)
	local left = math.min(25, math.max(10, width * 0.0326))
	local menuY = inset + 12
	local stats = rect(width - 190, 0, 190, 116)
	local requirements = rect(left + 0.5, menuY + 47, 210, 126)
	local effectScale, requirementScale = 0.7, 0.6
	local effects = rect(width - 161, stats.y + stats.height + 6, 132, 44)
	local laneX = math.min(width * 0.4099, stats.x - 176)
	local lane = rect(
		math.max(left + 158, laneX),
		height * 0.0148,
		math.max(170, math.min(296, stats.x - math.max(left + 158, laneX) - 6)),
		52
	)
	return {
		slot = slot,
		columns = 9,
		gap = 2,
		hotbar = bar,
		view = rect(bar.x - 50, height - 44, 44, 44),
		inventory = rect(bar.x + bar.width + 6, height - 44, 44, 44),
		jump = rect(width - 100, height - 116, 70, 70),
		eat = rect(math.min(width - 44, math.max(0, width - 236)), height - 166, 44, 44),
		menu = rect(left, menuY, 44, 44),
		boosters = rect(left + 51, menuY, 100, 44),
		attack = rect(3, height - 44, 44, 44),
		sprint = rect(60, height - 44, 44, 44),
		stats = stats,
		requirements = requirements,
		effects = effects,
		notification = lane,
		requirementsScale = requirementScale,
		effectsScale = effectScale,
		meters = rect(bar.x + 6, bar.y - 60, bar.width - 12, 56),
	}
end
function Defaults.place(object: GuiObject, area: Rect)
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(area.x, area.y)
	object.Size = UDim2.fromOffset(area.width, area.height)
end
function Defaults.stats(frame: Frame, labels: { [string]: TextLabel }, area: Rect?)
	local compact = area ~= nil
	local rowHeight = if compact then 15 else 20
	frame.Size = if area
		then UDim2.fromOffset(area.width, area.height)
		else UDim2.fromOffset(214, 160)
	labels.sbTitle.Visible = true
	labels.sbTitle.Size = UDim2.new(1, -12, 0, if compact then 17 else 22)
	labels.sbTitle.TextSize = if compact then 12 else 14
	local divider = frame:FindFirstChild("Divider")
	if divider and divider:IsA("GuiObject") then
		divider.Visible = not compact
	end
	for index, key in
		{ "statLevel", "statMoney", "statBlocks", "statFaction", "statRats", "statKD" }
	do
		local y = if compact
			then 21 + (index - 1) * rowHeight
			else 28 + (index - 1) * 20 + (if index >= 4 then 8 else 0)
		local label, value = labels[key .. "Label"], labels[key]
		label.Visible = true
		label.Position = UDim2.fromOffset(if compact then 21 else 28, y)
		label.Size = UDim2.fromOffset(if compact then 68 else 100, rowHeight)
		label.TextSize = if compact then 11 else 14
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		value.Position = UDim2.fromOffset(if compact then 92 else 28, y)
		value.Size = UDim2.new(1, if compact then -98 else -36, 0, rowHeight)
		value.TextSize = if compact then 11 else 14
		value.TextWrapped = false
		value.TextTruncate = Enum.TextTruncate.AtEnd
		local icon = frame:FindFirstChild("StatIcon_" .. index)
		if icon and icon:IsA("GuiObject") then
			local iconSize = if compact then 12 else 14
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position =
				UDim2.fromOffset(if compact then 4 else 8, y + (rowHeight - iconSize) / 2)
		end
	end
end
function Defaults.bounds(object: GuiObject, viewport: Vector2): Rect
	local scale = object:FindFirstChildOfClass("UIScale")
	local factor = if scale then scale.Scale else 1
	local size, position, anchor = object.Size, object.Position, object.AnchorPoint
	local width = (size.X.Scale * viewport.X + size.X.Offset) * factor
	local height = (size.Y.Scale * viewport.Y + size.Y.Offset) * factor
	return rect(
		position.X.Scale * viewport.X + position.X.Offset - anchor.X * width,
		position.Y.Scale * viewport.Y + position.Y.Offset - anchor.Y * height,
		width,
		height
	)
end
function Defaults.clamp(object: GuiObject, viewport: Vector2): Rect
	local area = Defaults.bounds(object, viewport)
	local x, y =
		math.clamp(area.x, 0, math.max(0, viewport.X - area.width)),
		math.clamp(area.y, 0, math.max(0, viewport.Y - area.height))
	if x ~= area.x or y ~= area.y then
		object.Position = UDim2.fromOffset(
			x + object.AnchorPoint.X * area.width,
			y + object.AnchorPoint.Y * area.height
		)
	end
	return rect(x, y, area.width, area.height)
end
function Defaults.clearStats(effects: GuiObject, stats: GuiObject, viewport: Vector2)
	local a, b = Defaults.bounds(effects, viewport), Defaults.bounds(stats, viewport)
	if
		a.x < b.x + b.width
		and a.x + a.width > b.x
		and a.y < b.y + b.height
		and a.y + a.height > b.y
	then
		effects.Position = UDim2.fromOffset(
			a.x + effects.AnchorPoint.X * a.width,
			b.y + b.height + 6 + effects.AnchorPoint.Y * a.height
		)
	end
	Defaults.clamp(effects, viewport)
end
function Defaults.dockNearBottom(object: GuiObject, viewport: Vector2)
	local area = Defaults.bounds(object, viewport)
	local gap = viewport.Y - area.y - area.height
	if gap >= 0 and gap <= 24 then
		local p = object.Position
		object.Position = UDim2.new(
			p.X.Scale,
			p.X.Offset,
			0,
			viewport.Y - area.height + object.AnchorPoint.Y * area.height
		)
	end
end
function Defaults.menuGrid(menu: GuiObject, grid: GuiObject, viewport: Vector2)
	local area = Defaults.bounds(menu, viewport)
	local scale = menu:FindFirstChildOfClass("UIScale")
	local factor = if scale then scale.Scale else 1
	local width, height = grid.Size.X.Offset * factor, grid.Size.Y.Offset * factor
	local x = if area.x + area.width + 6 + width <= viewport.X
		then area.x + area.width + 6
		else area.x - width - 6
	x = math.clamp(x, 0, math.max(0, viewport.X - width))
	local y = math.clamp(area.y, 0, math.max(0, viewport.Y - height))
	grid.Position = UDim2.fromOffset((x - area.x) / factor, (y - area.y) / factor)
end
return Defaults
