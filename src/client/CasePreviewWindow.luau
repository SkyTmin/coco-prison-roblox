--!strict
-- «Подробнее» at a case [владелец 28.10: «ниже «Открыть кейс» кнопку «Подробнее». Пусть там открывается сундук с
-- предметами, которые могут выпасть с данного сундука … оттуда нельзя забирать предметы, только читать»]: the vanilla
-- chest GUI of the case window with every possible drop (Shared/CasePreview), no inventory and no buttons; hover (or
-- tap) a slot for the item tooltip, a money bag adds its range. The nickname case lists its nicknames instead. The
-- server puts a second prompt «Подробнее» (CaseInfo, key R) under «Открыть кейс»; the client opens this window itself.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockColors = require(Shared.BlockColors)
local CasePreview = require(Shared.CasePreview)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Strings = require(Shared.Strings)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local CasePreviewWindow = {}

local MC = Ui.MC
local TITLES = {
	ordinaryCase = "case_contents_title",
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
}
local MAX_ROWS = 6

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
	local rows = if nicknames
		then math.clamp(math.ceil(#nicknames / 3), 1, MAX_ROWS)
		else math.clamp(math.ceil(#entries / 9), 1, MAX_ROWS)
	local gridH = rows * 18
	local width, height = 176 * MC, (17 + gridH + 22) * MC
	local title = t(TITLES[id] or "ordinary_case")
	local win, raw = createWindow(parent, title, UDim2.fromOffset(width, height), onClose)
	win.Name = "Window_CasePreview"
	local content = Ui.toMc(win, raw)
	Ui.mcText(content, title, UDim2.fromOffset(150 * MC, 10 * MC), UDim2.fromOffset(8 * MC, 5 * MC)).TextXAlignment =
		Enum.TextXAlignment.Left
	local hint = Ui.mcText(
		content,
		t("case_preview_hint"),
		UDim2.fromOffset(160 * MC, 10 * MC),
		UDim2.fromOffset(8 * MC, (17 + gridH + 6) * MC),
		7 * MC
	)
	hint.TextXAlignment = Enum.TextXAlignment.Left

	if nicknames then
		-- three columns of nicknames on slot-coloured plates
		for i, name in ipairs(nicknames) do
			if i > rows * 3 then
				break
			end
			local column, row = (i - 1) % 3, (i - 1) // 3
			local plate = Instance.new("Frame")
			plate.Size = UDim2.fromOffset(52 * MC, 16 * MC)
			plate.Position = UDim2.fromOffset((8 + column * 54) * MC, (17 + row * 18) * MC)
			plate.BackgroundColor3 = Ui.colors.mcSlot
			plate.BorderSizePixel = 0
			plate.Parent = content
			local label = Ui.mcText(plate, name, UDim2.fromScale(1, 1), UDim2.new(), 7 * MC)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.5
		end
		return win
	end

	-- the item slots: read only — hover / tap shows the tooltip
	local frames: { [Frame]: CasePreview.Entry } = {}
	local hover: Frame? = nil
	local focus: Frame? = nil
	for i, entry in ipairs(entries) do
		if i > rows * 9 then
			break
		end
		local column, row = (i - 1) % 9, (i - 1) // 9
		local frame, name, count, icon = Ui.mcSlot(content)
		frame.Position = UDim2.fromOffset((8 + column * 18) * MC, (17 + row * 18) * MC)
		local stack = entry.stack
		local image = Config.iconFor(stack.id, stack.level)
		local tint = Color3.new(1, 1, 1)
		if not image then
			local blockIcon, blockTint = BlockColors.icon(stack.id)
			image, tint = blockIcon, blockTint
		end
		local tile = if not image then BlockColors.of(stack.id) else nil
		icon.Image, icon.Visible = image or "", image ~= nil or tile ~= nil
		icon.ImageColor3 = tint
		icon.BackgroundColor3 = tile or Color3.new()
		icon.BackgroundTransparency = if tile then 0 else 1
		name.Visible = false
		count.Text = if entry.money then "$" else ""
		local glint = icon:FindFirstChild("Glint")
		if glint and glint:IsA("ImageLabel") then
			glint.Image = image or ""
			glint.Visible = image ~= nil
				and (
					Config.isEnchanted(stack.id, stack.level)
					or (stack.books ~= nil and #stack.books > 0)
				)
		end
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
