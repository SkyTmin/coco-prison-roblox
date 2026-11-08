--!strict
-- Complete pre-spend disclosure. Probabilities are joint per draw; bonuses per opening.
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Books = require(Shared.Books)
local CasePreview = require(Shared.CasePreview)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Strings = require(Shared.Strings)
local CommerceUi = require(script.Parent.CommerceUi)
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
end

function CasePreviewWindow.build(
	parent: Instance,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow,
	requestedId: string?,
	getProfile: (() -> any)?,
	requestedKey: string?
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
	return win
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
	details = CasePreviewWindow.build(parent, locale, close, createWindow, caseId, getProfile, key)
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
