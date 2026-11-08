--!strict
-- Presentation only: requirement counts and readiness come from Shared.Tutorial.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)
local Panel = {}

export type Rect = { x: number, y: number, width: number, height: number }

function Panel.obstacles(
	gui: ScreenGui,
	panel: Frame,
	playerGui: PlayerGui,
	includePanel: boolean?
): { Rect }
	local result = {}
	local function keep(object: GuiObject)
		if object ~= panel and object:IsDescendantOf(panel) then
			return
		end
		local ancestor: Instance? = object
		while ancestor and ancestor ~= playerGui do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				return
			end
			if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
				return
			end
			ancestor = ancestor.Parent
		end
		-- AbsolutePosition includes the ScreenGui origin (often -58 for IgnoreGuiInset).
		-- Panel.Position is relative to this GUI; native touch controls need the same conversion.
		local p, size = object.AbsolutePosition - gui.AbsolutePosition, object.AbsoluteSize
		if size.X > 1 and size.Y > 1 then
			table.insert(result, { x = p.X, y = p.Y, width = size.X, height = size.Y })
		end
	end
	for _, object in gui:GetDescendants() do
		if
			object:IsA("GuiButton")
			or (
				object:IsA("GuiObject")
				and (
					object.Name == "Scoreboard"
					or object.Name == "Hotbar"
					or object.Name == "Touch_jump"
				)
			)
		then
			keep(object :: GuiObject)
		end
	end
	if includePanel then
		keep(panel)
	end
	local native = playerGui:FindFirstChild("TouchGui")
	if native then
		for _, name in { "JumpButton", "ThumbstickStart", "ThumbstickEnd" } do
			local object = native:FindFirstChild(name, true)
			if object and object:IsA("GuiObject") then
				keep(object)
			end
		end
	end
	return result
end

-- The indicated spot must be on the dig side and clear of HUD controls, even after a HUD move.
function Panel.digHintPosition(
	view: Vector2,
	top: number,
	rightHalf: number,
	obstacles: { Rect }
): Rect?
	local gap, height = 8, 74
	local left, bottom = rightHalf + gap, view.Y - gap
	local width = math.min(160, view.X - gap - left)
	if width < 116 then
		return nil
	end
	local maxX, maxY = view.X - gap - width, bottom - height
	local preferredX, preferredY = view.X * 0.77 - width / 2, view.Y * 0.48 - height / 2
	local columns, rows = { left, preferredX, maxX }, { top, preferredY, maxY }
	for _, rect in obstacles do
		table.insert(columns, rect.x - width - gap)
		table.insert(columns, rect.x + rect.width + gap)
		table.insert(rows, rect.y - height - gap)
		table.insert(rows, rect.y + rect.height + gap)
	end
	local best: Rect? = nil
	local bestScore = math.huge
	for _, x in columns do
		if x < left or x > maxX then
			continue
		end
		for _, y in rows do
			local score = math.abs(x - preferredX) + math.abs(y - preferredY)
			if y < top or y > maxY or score >= bestScore then
				continue
			end
			local clear = true
			for _, rect in obstacles do
				if
					x < rect.x + rect.width + gap
					and x + width + gap > rect.x
					and y < rect.y + rect.height + gap
					and y + height + gap > rect.y
				then
					clear = false
					break
				end
			end
			if clear then
				best, bestScore = { x = x, y = y, width = width, height = height }, score
			end
		end
	end
	return best
end

function Panel.newDigHint(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name, frame.BackgroundTransparency, frame.ZIndex = "TutorialDigHint", 1, 8
	frame.Active, frame.Visible, frame.Parent = false, false, gui
	local icon = Instance.new("Frame")
	icon.Name, icon.BackgroundTransparency = "HoldFinger", 1
	icon.AnchorPoint, icon.Position, icon.Size =
		Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 5), UDim2.fromOffset(26, 32)
	icon.Parent = frame
	local circle = Instance.new("Frame")
	circle.AnchorPoint, circle.Position, circle.BackgroundTransparency =
		Vector2.new(0.5, 0.5), UDim2.fromOffset(9, 3), 1
	circle.Parent = icon
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius, rounded.Parent = UDim.new(1, 0), circle
	local ring = Instance.new("UIStroke")
	ring.Color, ring.Thickness, ring.Parent = Ui.colors.yellow, 2, circle
	-- Pixel silhouette matches the HUD and stays readable without a font glyph or remote asset.
	local pixels = {
		"...###.......",
		"..#+++#......",
		"..#+++#......",
		"..#+++#......",
		"..#+++####...",
		"..#++++++##..",
		".##++++++++#.",
		"#++#+++++++#.",
		"#++++++++++#.",
		".#+++++++++#.",
		"..#+++++++#..",
		"...#++++++#..",
		"...#+++++#...",
		"...#+++++#...",
		"...#######...",
	}
	local outline, fill = Color3.fromRGB(26, 24, 22), Color3.fromRGB(255, 247, 221)
	for y, row in pixels do
		for pattern, color in { ["()(#+)"] = outline, ["()(%++)"] = fill } do
			for x, run in string.gmatch(row, pattern) do
				local pixel = Instance.new("Frame")
				pixel.Size, pixel.Position =
					UDim2.fromOffset(#run * 2, 2), UDim2.fromOffset((x - 1) * 2, (y - 1) * 2)
				pixel.BorderSizePixel, pixel.BackgroundColor3, pixel.Parent = 0, color, icon
			end
		end
	end
	local caption = Ui.label(frame, "", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 38), 14)
	caption.Name, caption.TextXAlignment, caption.TextWrapped =
		"HoldCaption", Enum.TextXAlignment.Center, true
	caption.TextStrokeTransparency = 0
	return {
		frame = frame,
		Show = function(rect: Rect?, locale: string)
			if rect then
				frame.Position, frame.Size =
					UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.width, rect.height)
				caption.Text = Strings.t("tutorial_first_dig_hold", locale)
			end
			frame.Visible = rect ~= nil
		end,
		Animate = function(pulse: number)
			local size = 13 + 12 * pulse
			circle.Size, ring.Transparency = UDim2.fromOffset(size, size), 0.18 + pulse * 0.66
		end,
	}
end

-- Prefer the left edge, then the nearest clear column. A short viewport scrolls the
-- card's contents instead of shrinking text or covering a player-moved control.
function Panel.place(
	view: Vector2,
	inset: number,
	height: number,
	obstacles: { Rect },
	requestedWidth: number?
): Rect
	local width = math.min(requestedWidth or 250, view.X - 24)
	local top, bottom, gap = inset + 8, view.Y - 8, 8
	local columns = { 10 }
	for _, obstacle in obstacles do
		table.insert(columns, obstacle.x + obstacle.width + gap)
	end
	local best: Rect? = nil
	local bestScore = math.huge
	for _, x in columns do
		if x < 8 or x > view.X / 2 or x + width > view.X - 8 then
			continue
		end
		local spans = {}
		for _, obstacle in obstacles do
			if x < obstacle.x + obstacle.width + gap and x + width + gap > obstacle.x then
				table.insert(
					spans,
					{ math.max(top, obstacle.y - gap), obstacle.y + obstacle.height + gap }
				)
			end
		end
		table.sort(spans, function(a, b)
			return a[1] < b[1]
		end)
		table.insert(spans, { bottom, bottom })
		local y = top
		for _, span in spans do
			local available = math.min(height, span[1] - y, bottom - y)
			if available >= math.min(90, height) then
				local score = (height - available) * 100 + math.abs(x - 10) * 2 + y - top
				if score < bestScore then
					bestScore, best = score, { x = x, y = y, width = width, height = available }
				end
			end
			y = math.max(y, span[2])
		end
	end
	return best or { x = 10, y = top, width = width, height = 0 }
end

-- Manual placement owns its position. Only keep it on-screen after orientation/size changes;
-- transient controls must never send a pinned card back through automatic placement.
function Panel.relocate(view: Vector2, inset: number, wanted: Rect): Rect
	local width = math.min(wanted.width, view.X - 24)
	local height = math.min(wanted.height, view.Y - inset - 16)
	local rect = {
		x = math.clamp(wanted.x, 8, math.max(8, view.X - width - 8)),
		y = math.clamp(wanted.y, inset + 8, math.max(inset + 8, view.Y - height - 8)),
		width = width,
		height = height,
	}
	return rect
end

function Panel.new(
	gui: ScreenGui,
	openMenu: (string) -> (),
	onHide: (() -> ())?,
	onEdit: (() -> ())?
)
	local panel = Ui.card(gui, UDim2.fromOffset(250, 220), UDim2.new())
	panel.Name, panel.ZIndex = "FirstSteps", 6
	local grip = Instance.new("Frame")
	grip.Name, grip.BackgroundTransparency, grip.Size, grip.Parent =
		"RequirementsDragHeader", 1, UDim2.new(1, 0, 0, 44), panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "TaskContents", 1, 0
	scroll.Size, scroll.ScrollBarThickness, scroll.ScrollingDirection =
		UDim2.fromScale(1, 1), 3, Enum.ScrollingDirection.Y
	scroll.Parent = panel
	local title =
		Ui.label(scroll, "", UDim2.new(1, -96, 0, 28), UDim2.fromOffset(8, 4), 13, Ui.colors.header)
	title.Name, title.TextWrapped = "TaskGoal", true
	local close = Ui.button(
		panel,
		"×",
		UDim2.fromOffset(44, 44),
		UDim2.new(1, -44, 0, -8),
		Ui.colors.buttonGrey
	)
	close.Name, close.TextSize, close.ZIndex = "HideRequirements", 20, 10
	close.Activated:Connect(function()
		if onHide then
			onHide()
		end
	end)
	local edit = Ui.button(
		panel,
		"",
		UDim2.fromOffset(44, 44),
		UDim2.new(1, -88, 0, -8),
		Ui.colors.buttonGrey
	)
	edit.Name, edit.TextSize, edit.ZIndex = "EditRequirementsLayout", 13, 10
	for _, button in { edit, close } do
		button.BackgroundTransparency = 1
		local edge = button:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Transparency = 1
		end
	end
	local editIcon = Instance.new("ImageLabel")
	editIcon.BackgroundTransparency, editIcon.Size, editIcon.Position =
		1, UDim2.fromOffset(22, 22), UDim2.fromOffset(11, 11)
	editIcon.Image, editIcon.ScaleType, editIcon.Parent =
		Config.icons.icons.menu_settings_controls or "", Enum.ScaleType.Fit, edit
	local editTip = Ui.label(panel, "", UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 36), 12)
	editTip.Name, editTip.Visible, editTip.ZIndex = "RequirementsLayoutTooltip", false, 20
	editTip.BackgroundTransparency, editTip.BackgroundColor3, editTip.TextWrapped =
		0.05, Ui.colors.panel, true
	edit.MouseEnter:Connect(function()
		editTip.Visible = true
	end)
	edit.MouseLeave:Connect(function()
		editTip.Visible = false
	end)
	edit.SelectionGained:Connect(function()
		editTip.Visible = true
	end)
	edit.SelectionLost:Connect(function()
		editTip.Visible = false
	end)
	edit.Activated:Connect(function()
		editTip.Visible = false
		if onEdit then
			onEdit()
		end
	end)
	local header =
		Ui.label(scroll, "", UDim2.new(1, -76, 0, 18), UDim2.fromOffset(8, 36), 13, Ui.colors.muted)
	header.Name = "RequirementsTitle"
	local count = Ui.label(
		scroll,
		"",
		UDim2.fromOffset(64, 18),
		UDim2.new(1, -72, 0, 36),
		13,
		Ui.colors.money
	)
	count.Name, count.TextXAlignment = "RequirementsCount", Enum.TextXAlignment.Right
	local rows: { any } = {}
	local function row(index: number): any
		if rows[index] then
			return rows[index]
		end
		local frame = Ui.inset(scroll, UDim2.new(1, -16, 0, 28), UDim2.new())
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.BackgroundTransparency = "Icon", 1
		icon.Size, icon.Position = UDim2.fromOffset(22, 22), UDim2.fromOffset(4, 3)
		icon.ScaleType, icon.ResampleMode, icon.Parent =
			Enum.ScaleType.Fit, Enum.ResamplerMode.Pixelated, frame
		local name = Ui.label(frame, "", UDim2.new(1, -118, 1, 0), UDim2.fromOffset(30, 0), 13)
		name.Name, name.TextWrapped = "ResourceName", true
		local value = Ui.label(
			frame,
			"",
			UDim2.fromOffset(86, 28),
			UDim2.new(1, -92, 0, 0),
			13,
			Ui.colors.money
		)
		value.Name, value.TextXAlignment = "Progress", Enum.TextXAlignment.Right
		rows[index] = { frame = frame, icon = icon, name = name, value = value }
		return rows[index]
	end
	local hint = Ui.label(scroll, "", UDim2.new(1, -16, 0, 24), UDim2.new(), 12, Ui.colors.muted)
	hint.Name, hint.TextWrapped = "TaskHint", true
	local shortcut =
		Ui.button(scroll, "", UDim2.new(1, -16, 0, 44), UDim2.new(), Ui.colors.buttonBlue)
	shortcut.Name, shortcut.TextSize = "TutorialUpgradeShortcut", 14
	shortcut.Activated:Connect(function()
		openMenu("menu")
	end)
	local api = {
		frame = panel,
		shortcut = shortcut,
		grip = grip,
		manual = false,
		preservePosition = false,
		editing = false,
		layoutReady = true,
		dense = false,
		defaultRect = nil :: Rect?,
	}
	local automatic: Rect? = nil
	local automaticView: Vector2? = nil
	local automaticInset = -1
	local wasManual = false
	function api.Update(
		step: number,
		locale: string,
		goal: any,
		phase: string,
		view: Vector2,
		inset: number,
		obstacles: { Rect }
	)
		local compact = view.Y < 500
		local dense = api.dense
		local baseWidth = if api.defaultRect
			then api.defaultRect.width
			elseif dense then 210
			elseif api.manual or view.X < 900 then 220
			else 250
		local rowHeight, gap =
			if dense then 20 elseif compact or api.manual then 24 else 26,
			if compact or api.manual then 2 else 3
		local requirements = {}
		if goal and step == 3 then
			for _, requirement in goal.requirements do
				table.insert(requirements, requirement)
			end
			-- Same quantities as the upgrade window; larger requirement first, stable ties.
			table.sort(requirements, function(a, b)
				return if a.needed == b.needed then a.counter < b.counter else a.needed > b.needed
			end)
		elseif goal and step == 4 then
			table.insert(
				requirements,
				{ counter = false, have = goal.blocks, needed = goal.neededBlocks }
			)
		end
		title.Text = if not goal
			then Strings.t("tutorial_task_title", locale, math.clamp(step - 2, 1, 2))
			elseif step == 3 then Strings.t(
				"tutorial_upgrade_goal",
				locale,
				Strings.itemFullName(goal.itemId, goal.level, locale),
				goal.to
			)
			else Strings.t(
				if api.manual then "tracker_level_goal" else "tutorial_level_goal",
				locale,
				goal.level
			)
		header.Text = Strings.t("requirements", locale)
		local showHeader = not api.manual and not dense
		header.Visible, count.Visible = showHeader, showHeader
		title.TextSize = if dense then 12 else 13
		title.Size = UDim2.new(1, -96, 0, if dense then 24 else 28)
		title.Position = UDim2.fromOffset(8, if dense then 2 else 4)
		local met, y = 0, if dense then 30 elseif api.manual then 36 else 56
		for index, requirement in requirements do
			local entry = row(index)
			local complete = requirement.have >= requirement.needed
			if complete then
				met += 1
			end
			entry.frame.Name, entry.frame.Visible = "Requirement_" .. index, true
			entry.frame.Position, entry.frame.Size =
				UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, rowHeight)
			entry.icon.Image = if requirement.counter
				then Config.counterIcon(requirement.counter) or ""
				else Config.icons.icons.hud_blocks or ""
			entry.icon.Size = UDim2.fromOffset(if dense then 18 else 22, if dense then 18 else 22)
			entry.icon.Position = UDim2.fromOffset(4, (rowHeight - entry.icon.Size.Y.Offset) / 2)
			entry.name.Text = if requirement.counter
				then Strings.counterName(requirement.counter, locale)
				else Strings.t("tutorial_panel_blocks", locale)
			entry.name.Size = UDim2.new(1, if dense then -100 else -118, 1, 0)
			entry.name.Position = UDim2.fromOffset(if dense then 26 else 30, 0)
			entry.name.TextSize, entry.value.TextSize =
				if dense then 12 else 13, if dense then 12 else 13
			entry.name.Visible = true
			entry.value.Size = UDim2.fromOffset(if dense then 70 else 86, rowHeight)
			entry.value.Position = UDim2.new(1, if dense then -74 else -92, 0, 0)
			entry.value.TextColor3 = if complete then Ui.colors.money else Ui.colors.text
			entry.value.Text = Strings.big(requirement.have)
				.. " / "
				.. Strings.big(requirement.needed)
				.. (if complete then " ✓" else "")
			entry.frame:SetAttribute("RequirementCounter", requirement.counter or "blocks")
			entry.frame:SetAttribute("RequirementComplete", complete)
			y += rowHeight + gap
		end
		count.Text = string.format("%d / %d", met, #requirements)
		count.TextColor3 = if #requirements > 0 and met == #requirements
			then Ui.colors.money
			else Ui.colors.text
		local money = row(#requirements + 1)
		money.frame.Name, money.frame.Visible = "MoneyRequirement", goal ~= nil
		money.frame.Position, money.frame.Size =
			UDim2.fromOffset(8, y + 3), UDim2.new(1, -16, 0, rowHeight)
		money.icon.Image, money.icon.Position =
			Config.icons.icons.hud_money or "", UDim2.fromOffset(4, (rowHeight - 22) / 2)
		money.icon.Size = UDim2.fromOffset(if dense then 18 else 22, if dense then 18 else 22)
		money.value.TextSize = if dense then 12 else 13
		money.name.Text = Strings.t("tutorial_panel_money", locale)
		money.name.Visible = baseWidth > 220
		money.value.Size = UDim2.fromOffset(136, rowHeight)
		money.value.Position = UDim2.new(1, -142, 0, 0)
		money.name.Size = UDim2.new(1, -168, 1, 0)
		money.value.TextColor3 = if goal and goal.coins >= goal.cost
			then Ui.colors.money
			else Ui.colors.text
		money.value.Text = if goal
			then "$" .. Strings.money(goal.coins) .. " / $" .. Strings.money(goal.cost) .. (if goal.coins
					>= goal.cost
				then " ✓"
				else "")
			else ""
		for index = #requirements + 2, #rows do
			rows[index].frame.Visible = false
		end
		y += rowHeight + (if dense then 6 else 8)
		local shortPhase = if phase == "tutorial_collect_upgrade"
			then "tutorial_panel_mine"
			elseif phase == "tutorial_collect_level" then "tutorial_panel_level_mine"
			elseif phase == "tutorial_sell_blocks" then "tutorial_panel_sell"
			else phase
		hint.Text = if goal
				and (phase == "tutorial_collect_upgrade" or phase == "tutorial_collect_level" or phase == "tutorial_earn_upgrade")
				and goal.coins < goal.cost
				and (goal.estimatedSale or 0) > 0
				and not goal.saleReady
			then Strings.t(
				"tutorial_panel_after_sale",
				locale,
				Strings.money(goal.coins + goal.estimatedSale),
				Strings.money(goal.cost)
			)
			else Strings.t(shortPhase, locale)
		if api.manual then
			hint.Text = Strings.t(
				if goal and goal.ready then "tracker_ready" else "tracker_collect",
				locale
			)
		end
		hint.Visible = not api.manual
		hint.Position = UDim2.fromOffset(8, y)
		if hint.Visible then
			y += 28
		end
		shortcut.Visible, shortcut.Text =
			not api.manual and goal ~= nil and goal.ready, Strings.t("tutorial_open_menu", locale)
		shortcut.Position = UDim2.fromOffset(8, y)
		if shortcut.Visible then
			y += 48
		end
		local scale = panel:FindFirstChildOfClass("UIScale")
		local factor = if scale then scale.Scale else 1
		editTip.Text = Strings.t("tracker_layout", locale)
		edit:SetAttribute("Tooltip", editTip.Text)
		local height = y + (if dense then 4 else 6)
		local rect: Rect
		if api.preservePosition then
			local area, p = gui.AbsoluteSize, panel.Position
			local wanted = {
				x = p.X.Scale * area.X + p.X.Offset,
				y = p.Y.Scale * area.Y + p.Y.Offset,
				width = baseWidth * factor,
				height = height * factor,
			}
			rect = if api.editing then wanted else Panel.relocate(view, inset, wanted)
			panel.Size = UDim2.fromOffset(rect.width / factor, rect.height / factor)
		elseif api.defaultRect then
			local area = api.defaultRect
			rect = {
				x = area.x,
				y = area.y,
				width = area.width,
				height = math.min(height, area.height),
			}
			panel.Size = UDim2.fromOffset(rect.width, rect.height)
		else
			if
				not automatic
				or automaticView ~= view
				or automaticInset ~= inset
				or automatic.width ~= math.min(baseWidth, view.X - 24)
				or wasManual
			then
				automatic = Panel.place(view, inset, height, obstacles, baseWidth)
				-- Reserve a stable clear column, so changes in counts/ready state only scroll it.
				local room = view.Y - automatic.y - 8
				for _, obstacle in obstacles do
					if
						automatic.x < obstacle.x + obstacle.width + 8
						and automatic.x + automatic.width + 8 > obstacle.x
						and obstacle.y >= automatic.y
					then
						room = math.min(room, obstacle.y - automatic.y - 8)
					end
				end
				if automatic.height > 0 then
					automatic.height = math.max(0, room)
				end
				automaticView, automaticInset = if api.layoutReady then view else nil, inset
			end
			local placed = automatic :: Rect
			rect = {
				x = placed.x,
				y = placed.y,
				width = placed.width,
				height = math.min(height, placed.height),
			}
			panel.Size = UDim2.fromOffset(rect.width, rect.height)
		end
		panel.Position = UDim2.fromOffset(rect.x, rect.y)
		wasManual = api.preservePosition
		scroll.CanvasSize = UDim2.fromOffset(0, y + 6)
		panel:SetAttribute("LayoutFits", rect.height > 0)
	end
	return api
end

return Panel
