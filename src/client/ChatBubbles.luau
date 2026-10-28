--!strict
-- Chat bubbles over the heads (docs/research/chat-ux-spec.md «Bubbles»): only the Общий (local) channel — faction,
-- gang, global and system lines never make one. Roblox's own bubble chat cannot tell the channels apart (it shows
-- every TextChannel's messages and has no way to drop one), so it is off (ChatWindow) and the bubbles are ours, in
-- the dark style of our windows: up to Config.chat.bubbleMax over a player, each for Config.chat.bubbleSeconds,
-- seen from Config.chat.bubbleDistance studs, above the nameplate (Nameplates: 2.6 studs over the head). The text is
-- what TextChatService handed this player (already filtered for him).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ChatBubbles = {}

local cfg = Config.chat
local BACK = Color3.fromRGB(18, 18, 22)
local MAX_W = 220 -- px, a longer line wraps
local FADE = TweenInfo.new(0.3)

local boards: { [Model]: BillboardGui } = {}

local function boardOf(character: Model): BillboardGui?
	local existing = boards[character]
	if existing and existing.Parent then
		return existing
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local board = Instance.new("BillboardGui")
	board.Name = "ChatBubbles"
	board.Adornee = head
	board.Size = UDim2.fromOffset(MAX_W + 20, 160)
	board.SizeOffset = Vector2.new(0, 0.5) -- grows upwards from the anchor
	board.StudsOffset = Vector3.new(0, 3.4, 0)
	board.MaxDistance = cfg.bubbleDistance
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	board.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = board
	boards[character] = board
	character.Destroying:Once(function()
		board:Destroy()
		boards[character] = nil
	end)
	head.Destroying:Once(function()
		board:Destroy()
	end)
	return board
end

local order = 0

-- text: RichText-safe (Chat.escape)
function ChatBubbles.show(who: Player, text: string)
	local character = who.Character
	if not character then
		return
	end
	local board = boardOf(character)
	if not board then
		return
	end
	local bubbles = {}
	for _, child in ipairs(board:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(bubbles, child)
		end
	end
	table.sort(bubbles, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #bubbles >= cfg.bubbleMax do
		table.remove(bubbles, 1):Destroy()
	end
	order += 1
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.BackgroundColor3 = BACK
	bubble.BackgroundTransparency = 0.15
	bubble.AutomaticSize = Enum.AutomaticSize.XY
	bubble.Size = UDim2.new()
	bubble.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(52, 54, 66)
	stroke.Transparency = 0.3
	stroke.Parent = bubble
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 5)
	pad.Parent = bubble
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.RichText = true
	label.Text = text
	label.Parent = bubble
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(MAX_W, math.huge)
	limit.Parent = label
	bubble.Parent = board
	task.delay(cfg.bubbleSeconds, function()
		if not bubble.Parent then
			return
		end
		TweenService:Create(bubble, FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, FADE, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, FADE, { Transparency = 1 }):Play()
		task.wait(0.3)
		bubble:Destroy()
	end)
end

-- every bubble away (the setting switched off, the players hidden)
function ChatBubbles.clear()
	for character, board in pairs(boards) do
		board:Destroy()
		boards[character] = nil
	end
end

return ChatBubbles
