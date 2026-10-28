--!strict
-- Draws a stack into a slot from Ui.invSlot / Ui.slot the way the inventory does (init.client renderSlot): the icon,
-- a block-colour tile when there is no picture, the count, the enchant glint (static here). For the windows that live
-- in their own modules (BookWindow, CasePreviewWindow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockColors = require(Shared.BlockColors)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local SlotView = {}

function SlotView.render(
	name: TextLabel,
	count: TextLabel,
	image: ImageLabel,
	stack: Types.ItemStack?
)
	local icon = if stack then Config.iconFor(stack.id, stack.level) else nil
	local tint = Color3.new(1, 1, 1)
	if stack and not icon then
		icon, tint = BlockColors.icon(stack.id)
	end
	count.Text = if stack and stack.count > 1 then tostring(stack.count) else ""
	image.Image = icon or ""
	image.ImageColor3 = tint
	local tile = if stack and not icon then BlockColors.of(stack.id) else nil
	image.Visible = icon ~= nil or tile ~= nil
	image.BackgroundColor3 = tile or Color3.new()
	image.BackgroundTransparency = if tile then 0 else 1
	local glint = image:FindFirstChild("Glint")
	if glint and glint:IsA("ImageLabel") then
		glint.Image = icon or ""
		glint.Visible = stack ~= nil
			and icon ~= nil
			and (
				Config.isEnchanted(stack.id, stack.level)
				or (stack.books ~= nil and #stack.books > 0)
			)
	end
	name.Visible = false
end

-- a thin rarity strip along the bottom of a slot (case drops, books)
function SlotView.rarityBar(frame: Frame, color: Color3)
	local bar = Instance.new("Frame")
	bar.Name = "Rarity"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -3)
	bar.Size = UDim2.new(1, -10, 0, 3)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = frame.ZIndex + 2
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = bar
	bar.Parent = frame
end

return SlotView
