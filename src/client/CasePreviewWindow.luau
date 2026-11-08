--!strict
-- Complete pre-spend disclosure. Probabilities are joint per draw; bonuses per opening.
-- [владелец 08.11: «раньше были значки предметов, а теперь текст… убери их в отдельную кнопку i»] the window opens
-- on the item icons (read-only slots with a rarity strip, hover / tap for the tooltip; the nickname case: its names);
-- the round «i» left of the close cross switches to the full odds list below and back.
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Books = require(Shared.Books)
local CasePreview = require(Shared.CasePreview)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Strings = require(Shared.Strings)
local Nicknames = require(Shared.Nicknames)
local UserInputService = game:GetService("UserInputService")
local CommerceUi = require(script.Parent.CommerceUi)
local ItemTooltip = require(script.Parent.ItemTooltip)
local SlotView = require(script.Parent.SlotView)
local Ui = require(script.Parent.Ui)
type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local CasePreviewWindow = {}
CasePreviewWindow.caseId = "ordinaryCase"
CasePreviewWindow.profile = nil :: (() -> any)?
local TITLES = {
	ordinaryCase = "case_contents_title",
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
}

local function percent(probability: number): string
	-- Significant digits retain tiny money outcomes. The window discloses rounding.
	return string.format("%.8g%%", probability * 100)
end
local function money(units: number): string
	return string.format("%.8g $", units / Config.moneyScale)
end

function CasePreviewWindow.listen(open: () -> ())
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local id = prompt:GetAttribute("CaseId")
		if prompt.Name == "CaseInfo" and typeof(id) == "string" and TITLES[id] then
			CasePreviewWindow.caseId = id
			open()
		end
	end)
	-- the custom-styled «Подробнее»: a small grey button under «Открыть» (smaller than the engine prompt, so it is
	-- not hit by accident); the key R still works through the engine
	local shown: { [ProximityPrompt]: BillboardGui } = {}
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if
				prompt.Name ~= "CaseInfo"
				or prompt.Style ~= Enum.ProximityPromptStyle.Custom
				or shown[prompt]
			then
				return
			end
			local board = Instance.new("BillboardGui")
			board.Name = "CaseInfoButton"
			board.AlwaysOnTop = true
			-- a tall empty canvas centred on the chest, the button at its bottom: a fixed number of screen pixels
			-- under the engine «Открыть» prompt (UIOffset −36 px, ≈ 72 px tall) at any distance
			board.Size = UDim2.fromOffset(118, 124)
			board.Adornee = prompt.Parent :: any
			board.ResetOnSpawn = false
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 0, 24)
			button.Position = UDim2.new(0, 0, 1, -24)
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
			button.BackgroundTransparency = 0.25
			button.TextColor3 = Color3.fromRGB(215, 215, 220)
			button.Font = Enum.Font.GothamMedium
			button.TextSize = 12
			button.AutoButtonColor = true
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = button
			button.Parent = board
			local function refresh()
				local key = if inputType == Enum.ProximityPromptInputType.Keyboard
					then " [R]"
					else ""
				button.Text = "ⓘ " .. prompt.ActionText .. key
			end
			task.defer(refresh) -- after PromptLocalizer has set the text
			local changed = prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh)
			button.Activated:Connect(function()
				prompt:InputHoldBegin()
				task.wait()
				prompt:InputHoldEnd()
			end)
			board.Destroying:Connect(function()
				changed:Disconnect()
			end)
			board.Parent = playerGui
			shown[prompt] = board
		end
	)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local board = shown[prompt]
		if board then
			shown[prompt] = nil
			board:Destroy()
		end
	end)
end

function CasePreviewWindow.build(
	parent: Instance,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow,
	requestedId: string?,
	getProfile: (() -> any)?,
	requestedKey: string?,
	oddsOnly: boolean? -- the pre-purchase disclosure keeps the odds list in front
): Frame
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local id, key = requestedId or CasePreviewWindow.caseId, requestedKey or "ancient_key"
	local readProfile = getProfile or CasePreviewWindow.profile or function()
		return nil
	end
	local viewport = if workspace.CurrentCamera
		then workspace.CurrentCamera.ViewportSize
		else Vector2.new(750, 381)
	local top, bottom = GuiService:GetGuiInset()
	local width = math.min(620, math.max(260, viewport.X - top.X - bottom.X - 24))
	local height = math.min(520, math.max(180, viewport.Y - top.Y - bottom.Y - 24))
	local win, content = createWindow(
		parent,
		t(TITLES[id] or "commerce_odds_title"),
		UDim2.fromOffset(width, height),
		onClose
	)
	win.Name, win.BackgroundTransparency = "Window_CasePreview", 0
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "RewardOdds"
	scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 6
	scroll.Size, scroll.Position = UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4)
	scroll.CanvasSize, scroll.CanvasPosition = UDim2.new(), Vector2.zero
	scroll.Parent = content
	local expanded: { [string]: boolean } = {}
	local render: () -> ()
	local y = 0
	local function note(text: string, h: number, color: Color3?)
		local label = Ui.label(
			scroll,
			text,
			UDim2.new(1, -16, 0, h),
			UDim2.fromOffset(4, y),
			14,
			color or Ui.colors.text
		)
		label.TextWrapped, label.TextYAlignment = true, Enum.TextYAlignment.Top
		y += h + 6
		return label
	end
	local function title(node: any): string
		if node.nickname then
			return node.nickname
		end
		if node.kind == "none" then
			return t("commerce_none")
		end
		if node.kind == "artifactPool" then
			return t("commerce_bonus_odds")
		end
		if node.index then
			return t("commerce_fragment", node.index)
		end
		if node.kind == "applyChance" then
			return t("commerce_applyChance")
		end
		local stack = node.stack
		if stack then
			local book = stack.id == Books.BOOK and stack.books and stack.books[1]
			if book then
				return ItemInfo.bookName(book.id, book.level, locale)
			end
			local name = Strings.itemFullName(stack.id, stack.level, locale)
			if (stack.count or 1) > 1 and not node.range then
				name ..= " ×" .. stack.count
			end
			for _, enchant in stack.books or {} do
				name ..= " · " .. ItemInfo.bookName(enchant.id, enchant.level, locale)
			end
			return name
		end
		if node.range then
			return t("commerce_" .. node.range.field)
		end
		return Strings.itemName(
			if node.kind == "bookPool" then Books.BOOK else node.id,
			nil,
			locale
		)
	end
	local function drawNode(node: any, path: string, depth: number)
		local hasChildren = node.children and #node.children > 0
		local line = title(node) .. " · " .. percent(node.probability)
		local frame: GuiObject
		if hasChildren then
			local button = Ui.button(
				scroll,
				"",
				UDim2.new(1, -16 - depth * 10, 0, 64),
				UDim2.fromOffset(4 + depth * 10, y),
				Ui.colors.buttonGrey
			)
			button.Name = "OddsGroup_" .. path
			button.Activated:Connect(function()
				expanded[path] = not expanded[path]
				render()
			end)
			frame = button
			local label =
				Ui.label(button, line, UDim2.new(1, -16, 0, 38), UDim2.fromOffset(8, 2), 14)
			label.TextWrapped = true
			Ui.label(
				button,
				t(if expanded[path] then "commerce_collapse" else "commerce_expand"),
				UDim2.new(1, -16, 0, 22),
				UDim2.fromOffset(8, 40),
				13,
				Ui.colors.header
			)
			y += 70
		else
			frame = note(line, 44)
			frame.Name = "OddsOutcome_" .. path
		end
		frame:SetAttribute("Probability", node.probability)
		local book = node.stack and node.stack.books and node.stack.books[1]
		if node.kind == "book" and book and book.id == "trader" then
			local description = ItemInfo.bookDescription(book.id, book.level, locale)
			if description then
				note(description, 44, Ui.colors.muted)
			end
		end
		if node.range then
			local range = node.range
			local monetary = range.field == "coins"
			local lo = if monetary then money(range.min) else tostring(range.min)
			local hi = if monetary then money(range.max) else tostring(range.max)
			local step = if monetary then money(1) else "1"
			local label = note(
				t(
					"commerce_range",
					t("commerce_" .. range.field),
					lo,
					hi,
					step,
					percent(range.probabilityPerValue)
				),
				64,
				Ui.colors.muted
			)
			label.Name = "OddsRange_" .. path
			label:SetAttribute("ProbabilityPerValue", range.probabilityPerValue)
		end
		if node.duplicate then
			note(t("commerce_duplicate", node.duplicatesAfter or 0), 40, Ui.colors.muted)
		end
		if node.grantedIndices and #node.grantedIndices > 0 then
			local indices = {}
			for _, index in node.grantedIndices do
				table.insert(indices, tostring(index))
			end
			note(t("commerce_conversion", table.concat(indices, ", ")), 40, Ui.colors.muted)
		end
		if hasChildren and expanded[path] then
			for index, child in node.children do
				drawNode(child, path .. "_" .. index, depth + 1)
			end
		end
	end
	local function profileSignature(profile: any): string
		local names = table.clone(if profile and profile.nicknames then profile.nicknames else {})
		table.sort(names)
		local parts = { table.concat(names, "|") }
		local artifact = profile and profile.artifacts and profile.artifacts.common
		for index = 1, Config.artifacts.fragmentsPerArtifact do
			table.insert(
				parts,
				tostring(artifact and artifact.fragments and artifact.fragments[index] or 0)
			)
		end
		table.insert(parts, tostring(artifact and artifact.duplicates or 0))
		return table.concat(parts, ";")
	end
	local lastProfile = readProfile()
	local lastSignature = profileSignature(lastProfile)
	render = function()
		local position = scroll.CanvasPosition
		for _, child in scroll:GetChildren() do
			child:Destroy()
		end
		y = 0
		local refusal = CommerceUi.reason("random")
		if refusal then
			note(t(refusal), 58, Ui.colors.yellow)
		end
		if id == "powder" then
			note(t("commerce_powder_details", Books.POWDER_STEP), 150)
		elseif id == "forge" then
			note(t("commerce_star_details"), 150)
			local maxLevel = 1
			for _, levels in Config.books.effects do
				maxLevel = math.max(maxLevel, #levels)
			end
			for index = 1, maxLevel - 1 do
				local chances = Config.gangs.base.forge.chances
				local chance = chances[math.min(index, #chances)]
				note(
					t(
						"commerce_success_failure",
						tostring(chance * 100),
						tostring((1 - chance) * 100)
					)
						.. " · "
						.. tostring(index)
						.. " → "
						.. tostring(index + 1),
					44
				)
			end
		else
			if id == "ancientCase" then
				for index, entry in
					{
						{ "ancient_key", "commerce_normal_key" },
						{ "improved_ancient_key", "commerce_improved_key" },
					}
				do
					local button = Ui.button(
						scroll,
						t(entry[2]),
						UDim2.new(0.5, -10, 0, 44),
						UDim2.new((index - 1) * 0.5, 4, 0, y),
						if key == entry[1] then Ui.colors.buttonBlue else Ui.colors.buttonGrey
					)
					button.Name, button.TextSize, button.TextWrapped =
						"OddsKey_" .. entry[1], 13, true
					button.Activated:Connect(function()
						key = entry[1]
						table.clear(expanded)
						render()
					end)
				end
				y += 50
			end
			local plan = CasePreview.plan(id, lastProfile, key)
			local draws = {}
			for _, draw in plan.draws do
				table.insert(draws, tostring(draw.count) .. " = " .. percent(draw.probability))
			end
			note(t("commerce_draws", table.concat(draws, "; ")), 44)
			note(t("commerce_main_odds"), 58, Ui.colors.muted)
			if plan.unavailable then
				note(t("commerce_empty"), 48)
			end
			for index, node in plan.outcomes do
				drawNode(node, "main_" .. index, 0)
			end
			if #plan.bonuses > 0 then
				note(t("commerce_bonus_odds"), 30, Ui.colors.header)
				for index, node in plan.bonuses do
					drawNode(node, "bonus_" .. index, 0)
				end
			end
			note(t("commerce_rounded"), 58, Ui.colors.muted)
		end
		scroll.CanvasSize = UDim2.fromOffset(0, y)
		scroll.CanvasPosition =
			Vector2.new(0, math.min(position.Y, math.max(0, y - scroll.AbsoluteSize.Y)))
	end
	local elapsed = 0
	local updates = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local nextProfile = readProfile()
		local signature = profileSignature(nextProfile)
		if signature ~= lastSignature then
			lastProfile, lastSignature = nextProfile, signature
			render()
		else
			lastProfile = nextProfile
		end
	end)
	win.Destroying:Connect(function()
		updates:Disconnect()
	end)
	CommerceUi.watch(win, render)
	render()
	if not oddsOnly then
		CasePreviewWindow.itemsView(win, content, scroll, id, locale)
	end
	return win
end

-- the icon grid over the odds list, and the «i» button that switches between them
local SLOT, GAP = 44, 4
local RARITY_ORDER = { "common", "rare", "legendary" }
function CasePreviewWindow.itemsView(
	win: Frame,
	content: Frame,
	odds: ScrollingFrame,
	id: string,
	locale: string
)
	local entries, nicknames = CasePreview.of(id)
	if #entries == 0 and not nicknames then
		return -- powder / forge: only the odds text
	end
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local view = Instance.new("ScrollingFrame")
	view.Name = "ItemsView"
	view.BackgroundTransparency, view.BorderSizePixel, view.ScrollBarThickness = 1, 0, 6
	view.Size, view.Position = UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4)
	view.CanvasSize = UDim2.new()
	view.Parent = content
	odds.Visible = false
	local width = content.AbsoluteSize.X > 0 and content.AbsoluteSize.X - 20 or 560
	local y = 0
	local refusal = CommerceUi.reason("random")
	if refusal then
		local warn = Ui.label(
			view,
			t(refusal),
			UDim2.new(1, -16, 0, 40),
			UDim2.fromOffset(4, 0),
			13,
			Ui.colors.yellow
		)
		warn.TextWrapped = true
		y += 46
	end
	local hint =
		Ui.label(view, t("case_preview_hint"), UDim2.new(1, -16, 0, 18), UDim2.fromOffset(4, y), 12)
	hint.TextColor3 = Ui.colors.muted
	y += 24
	local frames: { [GuiObject]: any } = {}
	local hover: GuiObject? = nil
	local focus: GuiObject? = nil
	if nicknames then
		local cols = math.max(2, math.floor((width + GAP) / (130 + GAP)))
		local cardW = (width - (cols - 1) * GAP) / cols
		for i, name in ipairs(nicknames) do
			local column, row = (i - 1) % cols, (i - 1) // cols
			local plate = Ui.card(
				view,
				UDim2.fromOffset(cardW, 26),
				UDim2.fromOffset(4 + column * (cardW + GAP), y + row * 30)
			)
			local label = Ui.label(plate, name, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 14)
			label.Font = Enum.Font.SourceSansBold
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextColor3 = Nicknames.color(name)
			SlotView.rarityBar(plate, Nicknames.color(name))
		end
		y += math.ceil(#nicknames / cols) * 30
	else
		local cols = math.max(4, math.floor((width + GAP) / (SLOT + GAP)))
		for i, entry in ipairs(entries) do
			local column, row = (i - 1) % cols, (i - 1) // cols
			local frame, name, count, image = Ui.invSlot(view, SLOT)
			frame.Position = UDim2.fromOffset(4 + column * (SLOT + GAP), y + row * (SLOT + GAP))
			SlotView.render(name, count, image, entry.stack)
			count.Text = if entry.money then "$" else count.Text
			SlotView.rarityBar(frame, ItemInfo.RARITY_COLORS[entry.rarity] or Ui.colors.muted)
			frames[frame] = entry
			frame.MouseEnter:Connect(function()
				hover = frame
			end)
			frame.MouseLeave:Connect(function()
				if hover == frame then
					hover = nil
				end
			end)
			frame.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					focus = if focus == frame then nil else frame
				end
			end)
		end
		y += math.ceil(#entries / cols) * (SLOT + GAP) + 6
		-- which strip colour is which rarity
		local x = 8
		for _, rarity in ipairs(RARITY_ORDER) do
			local swatch = Instance.new("Frame")
			swatch.Size, swatch.Position = UDim2.fromOffset(14, 4), UDim2.fromOffset(x, y + 9)
			swatch.BackgroundColor3 = ItemInfo.RARITY_COLORS[rarity] or Ui.colors.muted
			swatch.BorderSizePixel = 0
			swatch.Parent = view
			local label = Ui.label(
				view,
				t("rarity_" .. rarity),
				UDim2.fromOffset(110, 22),
				UDim2.fromOffset(x + 20, y),
				13
			)
			label.TextColor3 = ItemInfo.RARITY_COLORS[rarity] or Ui.colors.text
			x += 20 + math.max(70, label.TextBounds.X) + 18
		end
		y += 28
	end
	view.CanvasSize = UDim2.fromOffset(0, y)

	-- the round «i» left of the close cross: icons ⇄ odds
	local info = Instance.new("TextButton")
	info.Name = "OddsInfo"
	info.Size = UDim2.fromOffset(26, 26)
	info.Position = UDim2.new(1, -66, 0, 7)
	info.BackgroundColor3 = Ui.colors.buttonBlue
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Font = Enum.Font.GothamBold
	info.TextSize = 16
	info.Text = "i"
	info.AutoButtonColor = true
	info.Parent = win
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = info
	info.Activated:Connect(function()
		local showOdds = not odds.Visible
		odds.Visible, view.Visible = showOdds, not showOdds
		info.Text = if showOdds then "←" else "i"
		ItemTooltip.hide()
	end)

	local tip = RunService.RenderStepped:Connect(function()
		local at: GuiObject? = if view.Visible then (focus or hover) else nil
		local entry = if at then frames[at] else nil
		if not entry or not at then
			ItemTooltip.hide()
			return
		end
		local extra: { ItemInfo.Line } = {}
		if entry.stack.id ~= "ancient_book" then
			table.insert(extra, {
				text = t("rarity_" .. entry.rarity),
				color = ItemInfo.RARITY_COLORS[entry.rarity] or Color3.new(1, 1, 1),
			})
		end
		if entry.money then
			table.insert(extra, {
				text = t(
					"case_preview_money",
					Strings.money(math.floor(entry.money[1] * Config.moneyScale + 0.5)),
					Strings.money(math.floor(entry.money[2] * Config.moneyScale + 0.5))
				),
				color = Ui.colors.green,
			})
		end
		local anchor: Vector2 | GuiObject = if focus
			then at
			else UserInputService:GetMouseLocation()
		ItemTooltip.show(entry.stack, anchor, extra)
	end)
	win.Destroying:Connect(function()
		tip:Disconnect()
		ItemTooltip.hide()
	end)
end

function CasePreviewWindow.purchase(
	owner: Frame,
	parent: Instance,
	locale: string,
	createWindow: CreateWindow,
	id: string,
	getProfile: () -> any,
	confirmPurchase: (() -> ())?,
	confirmText: string?
): Frame?
	local caseId, key = CasePreview.purchase(id)
	if not caseId then
		return nil
	end
	owner.Visible = false
	local details: Frame? = nil
	local function close()
		if details then
			details:Destroy()
			details = nil
		end
		if owner.Parent then
			owner.Visible = true
		end
	end
	details =
		CasePreviewWindow.build(parent, locale, close, createWindow, caseId, getProfile, key, true)
	if confirmPurchase then
		local scroll = details:FindFirstChild("RewardOdds", true) :: ScrollingFrame
		scroll.Size = UDim2.new(1, -8, 1, -60)
		local buy = Ui.button(
			scroll.Parent,
			confirmText or Strings.t("buy", locale),
			UDim2.new(1, -16, 0, 44),
			UDim2.new(0, 8, 1, -50),
			Ui.colors.buttonGreen
		)
		buy.Name, buy.TextSize, buy.TextWrapped = "OddsContinue", 14, true
		local function refresh()
			local reason = CommerceUi.reason("item", id)
			buy.Active, buy.AutoButtonColor = reason == nil, reason == nil
			buy.Text = if reason
				then Strings.t(reason, locale)
				else confirmText or Strings.t("buy", locale)
		end
		buy.Activated:Connect(function()
			refresh()
			if buy.Active then
				close()
				confirmPurchase()
			end
		end)
		CommerceUi.watch(details, refresh)
		refresh()
	end
	local destroyed = owner.Destroying:Connect(close)
	details.Destroying:Connect(function()
		destroyed:Disconnect()
	end)
	return details
end

return CasePreviewWindow
