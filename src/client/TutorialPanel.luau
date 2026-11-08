--!strict
-- Presentation only: requirement counts and readiness come from Shared.Tutorial.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)
local Panel = {}

export type Rect = { x: number, y: number, width: number, height: number }

function Panel.obstacles(gui: ScreenGui, panel: Frame, playerGui: PlayerGui): { Rect }
	local result = {}
	local function keep(object: GuiObject)
		if object:IsDescendantOf(panel) then
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
	local native = playerGui:FindFirstChild("TouchGui")
	if native then
		for _, name in { "JumpButton", "DynamicThumbstickFrame", "ThumbstickFrame" } do
			local object = native:FindFirstChild(name, true)
			if object and object:IsA("GuiObject") then
				keep(object)
			end
		end
	end
	return result
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

-- A saved layout from a larger phone must never cover the current touch controls.
-- Keep the player's position whenever it fits; otherwise use the same safe placement.
function Panel.relocate(view: Vector2, inset: number, wanted: Rect, obstacles: { Rect }): Rect
	local width = math.min(wanted.width, view.X - 24)
	local height = math.min(wanted.height, view.Y - inset - 16)
	local rect = {
		x = math.clamp(wanted.x, 8, math.max(8, view.X - width - 8)),
		y = math.clamp(wanted.y, inset + 8, math.max(inset + 8, view.Y - height - 8)),
		width = width,
		height = height,
	}
	for _, obstacle in obstacles do
		if
			rect.x < obstacle.x + obstacle.width
			and rect.x + rect.width > obstacle.x
			and rect.y < obstacle.y + obstacle.height
			and rect.y + rect.height > obstacle.y
		then
			return Panel.place(view, inset, height, obstacles, width)
		end
	end
	return rect
end

function Panel.new(gui: ScreenGui, openMenu: (string) -> (), onHide: (() -> ())?)
	local panel = Ui.card(gui, UDim2.fromOffset(250, 220), UDim2.new())
	panel.Name, panel.ZIndex = "FirstSteps", 6
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "TaskContents", 1, 0
	scroll.Size, scroll.ScrollBarThickness, scroll.ScrollingDirection =
		UDim2.fromScale(1, 1), 3, Enum.ScrollingDirection.Y
	scroll.Parent = panel
	local title =
		Ui.label(scroll, "", UDim2.new(1, -45, 0, 28), UDim2.fromOffset(8, 6), 14, Ui.colors.header)
	title.Name, title.TextWrapped = "TaskGoal", true
	local close = Ui.button(
		panel,
		"×",
		UDim2.fromOffset(28, 28),
		UDim2.new(1, -30, 0, 2),
		Ui.colors.buttonGrey
	)
	close.Name, close.TextSize, close.ZIndex = "HideRequirements", 20, 10
	close.Activated:Connect(function()
		if onHide then
			onHide()
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
	local api = { frame = panel, shortcut = shortcut, manual = false, preservePosition = false }
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
		local rowHeight, gap = if compact then 24 else 26, if compact then 2 else 3
		local requirements = {}
		if goal and step == 3 then
			for _, requirement in goal.requirements do
				table.insert(requirements, requirement)
			end
			-- Same quantities as the upgrade window; larger requirement first, stable ties.
			table.sort(requirements, function(a, b)
				return if a.needed == b.needed then a.counter < b.counter else a.needed > b.needed
			end)
		elseif goal and goal.neededBlocks then
			table.insert(
				requirements,
				{ counter = false, have = goal.blocks, needed = goal.neededBlocks }
			)
		end
		title.Text = if not goal
			then Strings.t("tutorial_task_title", locale, math.clamp(step - 2, 1, 2))
			elseif goal.title then Strings.t(goal.title, locale)
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
		local met, y = 0, 56
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
			entry.icon.Position = UDim2.fromOffset(4, (rowHeight - 22) / 2)
			entry.name.Text = if requirement.counter
				then Strings.counterName(requirement.counter, locale)
				else Strings.t("tutorial_panel_blocks", locale)
			entry.name.Size = UDim2.new(1, -118, 1, 0)
			entry.value.Size = UDim2.fromOffset(86, rowHeight)
			entry.value.Position = UDim2.new(1, -92, 0, 0)
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
		money.frame.Name, money.frame.Visible = "MoneyRequirement", goal ~= nil and goal.cost ~= nil
		money.frame.Position, money.frame.Size =
			UDim2.fromOffset(8, y + 3), UDim2.new(1, -16, 0, rowHeight)
		money.icon.Image, money.icon.Position =
			Config.icons.icons.hud_money or "", UDim2.fromOffset(4, (rowHeight - 22) / 2)
		money.name.Text = Strings.t("tutorial_panel_money", locale)
		money.value.Size = UDim2.fromOffset(136, rowHeight)
		money.value.Position = UDim2.new(1, -142, 0, 0)
		money.name.Size = UDim2.new(1, -168, 1, 0)
		money.value.TextColor3 = if goal
				and goal.cost
				and goal.coins >= goal.cost
			then Ui.colors.money
			else Ui.colors.text
		money.value.Text = if goal and goal.cost
			then "$" .. Strings.money(goal.coins) .. " / $" .. Strings.money(goal.cost) .. (if goal.coins
					>= goal.cost
				then " ✓"
				else "")
			else ""
		for index = #requirements + 2, #rows do
			rows[index].frame.Visible = false
		end
		y += rowHeight + 8
		local shortPhase = if phase == "tutorial_collect_upgrade"
			then "tutorial_panel_mine"
			elseif phase == "tutorial_collect_level" then "tutorial_panel_level_mine"
			elseif phase == "tutorial_sell_blocks" then "tutorial_panel_sell"
			else phase
		hint.Text = if goal
				and goal.cost
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
		hint.Position = UDim2.fromOffset(8, y)
		y += 28
		shortcut.Visible, shortcut.Text =
			goal ~= nil and goal.ready and not goal.title, Strings.t("tutorial_open_menu", locale)
		shortcut.Position = UDim2.fromOffset(8, y)
		if shortcut.Visible then
			y += 48
		end
		local rect = Panel.place(view, inset, y + 6, obstacles)
		if not api.preservePosition then
			panel.Position = UDim2.fromOffset(rect.x, rect.y)
		end
		panel.Size = UDim2.fromOffset(
			rect.width,
			if api.preservePosition then math.min(y + 6, view.Y - inset - 16) else rect.height
		)
		scroll.CanvasSize = UDim2.fromOffset(0, y + 6)
		panel:SetAttribute("LayoutFits", rect.height > 0)
	end
	return api
end

return Panel
