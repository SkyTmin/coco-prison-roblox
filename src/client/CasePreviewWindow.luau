--!strict
-- «Подробнее» at a case [владелец 28.10: «ниже «Открыть кейс» кнопку «Подробнее». Пусть там открывается сундук с
-- предметами, которые могут выпасть с данного сундука … оттуда нельзя забирать предметы, только читать»; «сделай
-- красивыми, ты уже инвентарь наш делал чёткий»]: every possible drop (Shared/CasePreview) in the dark inventory
-- style — read-only slots with a rarity strip, a legend of the rarities, hover (or tap) for the item tooltip with
-- its rarity, a money bag adds its range. The nickname case lists its nicknames on cards instead. The server puts a
-- second prompt «Подробнее» (CaseInfo, key R) under «Открыть кейс»; the client opens this window itself.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CasePreview = require(Shared.CasePreview)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Strings = require(Shared.Strings)
local ItemTooltip = require(script.Parent.ItemTooltip)
local SlotView = require(script.Parent.SlotView)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local CasePreviewWindow = {}

local SLOT, GAP, PAD, COLS = 44, 4, 16, 9
local MAX_ROWS = 6
local GRID_W = COLS * SLOT + (COLS - 1) * GAP
local INNER_W = GRID_W + 2 * PAD
local TITLES = {
	ordinaryCase = "case_contents_title",
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
}
local RARITIES = { "common", "rare", "legendary" }

-- the case whose window opens next (set by the prompt)
CasePreviewWindow.caseId = "ordinaryCase"

-- the «Подробнее» prompts: open the window for that case
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
	createWindow: CreateWindow
): Frame
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local id = CasePreviewWindow.caseId
	local entries, nicknames = CasePreview.of(id)
	local nickCols = 3
	local nickW, nickH = (GRID_W - (nickCols - 1) * GAP) / nickCols, 30
	local rows = if nicknames
		then math.clamp(math.ceil(#nicknames / nickCols), 1, 8)
		else math.clamp(math.ceil(#entries / COLS), 1, MAX_ROWS)
	local gridH = if nicknames
		then rows * nickH + (rows - 1) * GAP
		else rows * SLOT + (rows - 1) * GAP
	local gridTop = 30
	local height = gridTop + gridH + (if nicknames then 14 else 44)
	local title = t(TITLES[id] or "ordinary_case")
	local win, content =
		createWindow(parent, title, UDim2.fromOffset(INNER_W + 12, height + 46), onClose)
	win.Name = "Window_CasePreview"
	win.BackgroundTransparency = 0
	local hint = Ui.label(
		content,
		t("case_preview_hint"),
		UDim2.fromOffset(GRID_W, 18),
		UDim2.fromOffset(PAD, 4),
		12
	)
	hint.TextColor3 = Ui.colors.muted
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(GRID_W, gridH)
	grid.Position = UDim2.fromOffset(PAD, gridTop)
	grid.Parent = content

	if nicknames then
		-- three columns of nickname cards
		for i, name in ipairs(nicknames) do
			if i > rows * nickCols then
				break
			end
			local column, row = (i - 1) % nickCols, (i - 1) // nickCols
			local plate = Ui.card(
				grid,
				UDim2.fromOffset(nickW, nickH),
				UDim2.fromOffset(column * (nickW + GAP), row * (nickH + GAP))
			)
			local label = Ui.label(plate, name, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 14)
			label.Font = Enum.Font.SourceSansBold
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextTruncate = Enum.TextTruncate.AtEnd
		end
		return win
	end

	-- the item slots: read only — hover / tap shows the tooltip
	local frames: { [Frame]: CasePreview.Entry } = {}
	local hover: Frame? = nil
	local focus: Frame? = nil
	for i, entry in ipairs(entries) do
		if i > rows * COLS then
			break
		end
		local column, row = (i - 1) % COLS, (i - 1) // COLS
		local frame, name, count, image = Ui.invSlot(grid, SLOT)
		frame.Position = UDim2.fromOffset(column * (SLOT + GAP), row * (SLOT + GAP))
		SlotView.render(name, count, image, entry.stack)
		count.Text = if entry.money then "$" else ""
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

	-- the legend: which strip colour is which rarity
	local legend =
		Ui.card(content, UDim2.fromOffset(GRID_W, 30), UDim2.fromOffset(PAD, gridTop + gridH + 10))
	local x = 12
	for _, rarity in ipairs(RARITIES) do
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(14, 4)
		swatch.Position = UDim2.fromOffset(x, 13)
		swatch.BackgroundColor3 = ItemInfo.RARITY_COLORS[rarity] or Ui.colors.muted
		swatch.BorderSizePixel = 0
		swatch.Parent = legend
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = swatch
		local label = Ui.label(
			legend,
			t("rarity_" .. rarity),
			UDim2.fromOffset(110, 30),
			UDim2.fromOffset(x + 20, 0),
			13
		)
		label.TextColor3 = ItemInfo.RARITY_COLORS[rarity] or Ui.colors.text
		x += 20 + math.max(70, label.TextBounds.X) + 18
	end

	local tip = RunService.RenderStepped:Connect(function()
		local at: Frame? = focus or hover
		local entry = if at then frames[at] else nil
		if not entry or not at then
			ItemTooltip.hide()
			return
		end
		local extra: { ItemInfo.Line } = {}
		-- the rarity under every item (a book already says its own)
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
	return win
end

return CasePreviewWindow
