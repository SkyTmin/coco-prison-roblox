--!strict
-- The Дворы points on screen [клиент fraction.warzone.gui.*]: a board over every beacon (tag WarzonePoint, attribute
-- Point) — the point's name and bonus, «Доступна для захвата» / «Захвачена фракцией «%s»» + «Будет доступна через
-- %s», the capture race as a bar in the leader's colour — and, standing at a free point, a line at the top of the
-- screen: «Вскопайте блоки возле маяка» with your faction's capture points. Reads ReplicatedStorage.Warzone
-- (Shared/Warzone), so it works whatever part of the location is streamed in.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Warzone = require(Shared.Warzone)
local Ui = require(script.Parent.Ui)

local WarzoneHud = {}
local NEAR = 36 -- covers the full pad with its beacon beside it
local FREE = Color3.fromRGB(120, 230, 120)

type Board = { title: TextLabel, status: TextLabel, fill: Frame, back: Frame, point: string }

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function label(parent: Instance, size: UDim2, position: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	return l
end

function WarzoneHud.Start(gui: ScreenGui)
	local player = Players.LocalPlayer
	local function t(key: string, ...: any): string
		return Strings.t(key, Strings.localeOf(player), ...)
	end

	local hint = Ui.rich(gui, "", UDim2.new(0.9, 0, 0, 50), UDim2.new(0.05, 0, 0, 54), 14)
	hint.Name = "WarzoneHint"
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextWrapped = true
	hint.TextStrokeTransparency = 0.4
	hint.Visible = false

	local boards: { [BasePart]: Board } = {}
	local mineSigns: { [BasePart]: TextLabel } = {}
	local function attach(part: Instance)
		local id = part:GetAttribute("Point")
		if not part:IsA("BasePart") or boards[part] or not Warzone.point(id) then
			return
		end
		local gui3d = Instance.new("BillboardGui")
		gui3d.Name = "WarzoneBoard"
		gui3d.Size = UDim2.fromOffset(260, 100)
		gui3d.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		gui3d.MaxDistance = 160
		gui3d.LightInfluence = 0
		gui3d.Parent = part
		local title =
			label(gui3d, UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(255, 200, 70))
		title.TextWrapped = true
		local status = label(gui3d, UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 44), FREE)
		status.TextWrapped = true
		local back = Instance.new("Frame")
		back.Size = UDim2.new(0.8, 0, 0, 10)
		back.Position = UDim2.new(0.1, 0, 0, 84)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
		back.BorderSizePixel = 0
		back.Parent = gui3d
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = back
		boards[part] =
			{ title = title, status = status, fill = fill, back = back, point = id :: string }
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) then
				boards[part] = nil
			end
		end)
	end
	for _, part in ipairs(CollectionService:GetTagged(Warzone.POINT_TAG)) do
		attach(part)
	end
	CollectionService:GetInstanceAddedSignal(Warzone.POINT_TAG):Connect(attach)

	local function attachMineSign(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("MineHint") then
			return
		end
		local board = Instance.new("BillboardGui")
		board.Name, board.Size, board.MaxDistance = "MineHint", UDim2.fromOffset(148, 28), 55
		board.LightInfluence = 0
		board.Parent = part
		local text = label(board, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(245, 205, 85))
		mineSigns[part] = text
		part.Destroying:Connect(function()
			mineSigns[part] = nil
		end)
	end
	for _, part in ipairs(CollectionService:GetTagged("WarzoneMineSign")) do
		attachMineSign(part)
	end
	CollectionService:GetInstanceAddedSignal("WarzoneMineSign"):Connect(attachMineSign)

	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local clockNow = os.clock()
		if clockNow < nextAt then
			return
		end
		nextAt = clockNow + 0.25
		local now = workspace:GetServerTimeNow()
		local mine = player:GetAttribute("Faction")
		local faction = if typeof(mine) == "string" and Config.faction(mine) then mine else nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local nearState: Warzone.State? = nil
		for part, text in mineSigns do
			local state = Warzone.state(part:GetAttribute("Point") :: string, now)
			text.Text = if state.active and not state.owner
				then "⛏ " .. t("warzone_mine_hint")
				else t("warzone_inactive")
			local sign = text.Parent :: BillboardGui
			sign.Enabled = state.active and not state.owner
		end
		for part, board in pairs(boards) do
			local state = Warzone.state(board.point, now)
			board.title.Text = t("warzone_point_title", t("warzone_point_" .. board.point))
				.. "\n"
				.. t("warzone_direction_" .. board.point)
			if not state.active then
				board.status.Text = t("warzone_inactive")
				board.status.TextColor3 = Ui.colors.muted
				board.back.Visible = false
			elseif state.owner then
				board.status.Text = t("warzone_held_by", t("faction_" .. state.owner))
					.. "  "
					.. t("warzone_next_hint", clock(state.untilAt - now))
				board.status.TextColor3 = Config.factionColor(state.owner)
				board.back.Visible = false
			else
				board.status.Text = t("warzone_free")
				board.status.TextColor3 = FREE
				board.back.Visible = state.lead > 0
				if state.leader then
					board.fill.BackgroundColor3 = Config.factionColor(state.leader)
					board.fill.Size = UDim2.fromScale(math.clamp(state.lead / state.need, 0, 1), 1)
				end
			end
			if
				root
				and root:IsA("BasePart")
				and math.abs(root.Position.Y - part.Position.Y) <= 24
				and ((root.Position - part.Position) * Vector3.new(1, 0, 1)).Magnitude <= NEAR
			then
				nearState = state
			end
		end
		local near = nearState
		if near and near.active and not near.owner and faction then
			hint.Visible = true
			local others = 0
			for f, score in pairs(near.scores) do
				if f ~= faction then
					others = math.max(others, score)
				end
			end
			hint.Text = string.format(
				'%s  <font color="%s">%d/%d</font>%s',
				t("warzone_dig_hint"),
				Ui.hex(Config.factionColor(faction)),
				near.scores[faction] or 0,
				near.need,
				if others > 0
					then string.format(
						'  <font color="%s">%s %d</font>',
						Ui.hex(Ui.colors.red),
						t("warzone_rivals"),
						others
					)
					else ""
			)
		elseif near and near.active and not near.owner then
			hint.Visible = true
			hint.Text = t("warzone_join_hint")
		else
			hint.Visible = false
		end
	end)
end

return WarzoneHud
