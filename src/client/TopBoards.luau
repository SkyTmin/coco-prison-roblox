--!strict
-- The spawn top boards [владелец 22.10, скриншоты Prison Classic]: on every part tagged "TopBoard" (attribute
-- Board = rats / money / level / blocks / deaths; scripts/build-tops.luau) a SurfaceGui in PlayerGui draws the table
-- from ReplicatedStorage.Tops.<board> (LeaderboardService): a title bar, the header «# · Игрок · <value>»,
-- then the rows — places 1–3 with a gold / light-blue / orange crown, the name in its faction's colour with
-- the nickname after it in white, the value in green with its icon; 10 rows show, the rest scroll.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)

local TopBoards = {}
local started = false

local W, H = 900, 630 -- canvas (the board face is 15 × 10.5 studs)
local ROW, GAP = 44, 5
local CELL = Color3.fromRGB(34, 34, 36)
local BACK = Color3.fromRGB(56, 40, 32)
local GREEN = Color3.fromRGB(110, 230, 80)
local RED = Color3.fromRGB(255, 85, 85) -- the deaths board: red numbers [вики MENUS-SOCIAL]
local GOLD = Color3.fromRGB(255, 170, 0) -- with boosts, like the sidebar (Ui.colors.orange, Minecraft gold)
local GRAY = Color3.fromRGB(170, 170, 170) -- clean
local CROWNS =
	{ Color3.fromRGB(255, 196, 40), Color3.fromRGB(150, 210, 255), Color3.fromRGB(255, 150, 50) }
local FONT = Enum.Font.Code

local BOARDS = {
	rats = { title = "top_rats", value = "top_value_rats", icon = "hud_rat", total = true },
	money = { title = "top_money", value = "top_value_money", icon = "hud_money" },
	level = { title = "top_level", value = "top_value_level", dot = true },
	blocks = { title = "top_blocks", value = "top_value_blocks", icon = "hud_blocks", total = true },
	deaths = { title = "top_deaths", value = "top_value_deaths", dot = true, color = RED },
}

local localeOf: () -> string = function()
	return Config.defaultLocale
end
local guis: { [BasePart]: SurfaceGui } = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function cell(parent: Instance, x: number, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, 0)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = CELL
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = f
	f.Parent = parent
	return f
end

local function text(
	parent: Instance,
	s: string,
	size: number,
	color: Color3,
	rich: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = color
	l.RichText = rich == true
	l.Text = s
	l.Parent = parent
	return l
end

local function icon(
	parent: Instance,
	id: string,
	size: number,
	x: number,
	color: Color3?
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Size = UDim2.fromOffset(size, size)
	i.AnchorPoint = Vector2.new(0, 0.5)
	i.Position = UDim2.new(0, x, 0.5, 0)
	i.BackgroundTransparency = 1
	i.Image = (Config.icons.icons :: any)[id] or ""
	i.ImageColor3 = color or Color3.new(1, 1, 1)
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.Parent = parent
	return i
end

local function formatValue(board: string, v: number): string
	if board == "money" then
		return Strings.grouped(v / Config.moneyScale, 2)
	end
	return Strings.grouped(v, 0)
end

local COLS = { rank = { 0, 96 }, player = { 104, 440 }, value = { 552, 316 } }

-- the value header / cell: text and, after it, the board's icon (or a green dot)
local function valueContent(parent: Frame, board: string, s: string, size: number, color: Color3)
	local def = BOARDS[board]
	local l = text(parent, s, size, color, true)
	l.Size = UDim2.new(1, -46, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Right
	-- long "gold (gray)" values shrink instead of running under the icon
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = l
	if def.dot then
		local d = text(parent, "●", size, def.color or GREEN)
		d.Size = UDim2.new(0, 28, 1, 0)
		d.Position = UDim2.new(1, -34, 0, 0)
	elseif def.icon then
		icon(parent, def.icon, size + 2, parent.Size.X.Offset - 32)
	end
end

local function render(part: BasePart, gui: SurfaceGui)
	local board = part:GetAttribute("Board")
	local def = typeof(board) == "string" and BOARDS[board]
	local source = ReplicatedStorage:FindFirstChild("Tops")
	local value = source and source:FindFirstChild(board :: string)
	if not def or not value or not value:IsA("StringValue") then
		return
	end
	local locale = localeOf()
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(value.Value)
	end)
	rows = if ok and typeof(rows) == "table" then rows else {}
	gui:ClearAllChildren()
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = BACK
	bg.BorderSizePixel = 0
	bg.Parent = gui
	-- title bar
	local title = Instance.new("Frame")
	title.Position = UDim2.fromOffset(14, 12)
	title.Size = UDim2.fromOffset(W - 28, 74)
	title.BackgroundColor3 = Color3.fromRGB(26, 26, 28)
	title.BorderSizePixel = 0
	title.Parent = bg
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 6)
	tc.Parent = title
	text(title, Strings.t(def.title, locale), 54, Color3.new(1, 1, 1))
	-- header row
	local header = Instance.new("Frame")
	header.Position = UDim2.fromOffset(14, 96)
	header.Size = UDim2.fromOffset(W - 28, 36)
	header.BackgroundTransparency = 1
	header.Parent = bg
	text(cell(header, COLS.rank[1], COLS.rank[2], 36), "#", 26, Color3.fromRGB(200, 200, 200))
	text(
		cell(header, COLS.player[1], COLS.player[2], 36),
		Strings.t("top_player", locale),
		22,
		Color3.fromRGB(200, 200, 200)
	)
	valueContent(
		cell(header, COLS.value[1], COLS.value[2], 36),
		board :: string,
		Strings.t(def.value, locale),
		22,
		Color3.fromRGB(200, 200, 200)
	)
	-- rows
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(14, 142)
	list.Size = UDim2.fromOffset(W - 14, (ROW + GAP) * 10)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Color3.fromRGB(60, 130, 230)
	list.CanvasSize = UDim2.fromOffset(0, (ROW + GAP) * math.max(10, #rows))
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = bg
	if #rows == 0 then
		local empty = text(list, Strings.t("top_empty", locale), 26, Color3.fromRGB(170, 170, 170))
		empty.Size = UDim2.new(1, -14, 0, ROW * 2)
	end
	for i, row in ipairs(rows) do
		local r = Instance.new("Frame")
		r.Position = UDim2.fromOffset(0, (i - 1) * (ROW + GAP))
		r.Size = UDim2.fromOffset(W - 28, ROW)
		r.BackgroundTransparency = 1
		r.Parent = list
		local rank = cell(r, COLS.rank[1], COLS.rank[2], ROW)
		local num = text(rank, tostring(i), 28, Color3.new(1, 1, 1))
		if CROWNS[i] then
			num.Size = UDim2.new(1, -30, 1, 0)
			num.Position = UDim2.fromOffset(30, 0)
			icon(rank, "top_crown", 28, 12, CROWNS[i])
		end
		local who = cell(r, COLS.player[1], COLS.player[2], ROW)
		local color = if Config.faction(row.f)
			then Config.factionColor(row.f):Lerp(Color3.new(1, 1, 1), 0.25)
			else Color3.fromRGB(230, 230, 230)
		local name = string.format('<font color="%s">%s</font>', hex(color), tostring(row.n))
		if typeof(row.k) == "string" and row.k ~= "" then
			name ..= string.format(' <font color="#F0F0F0">%s</font>', row.k)
		end
		local nl = text(who, name, 28, Color3.new(1, 1, 1), true)
		nl.TextTruncate = Enum.TextTruncate.AtEnd
		valueContent(
			cell(r, COLS.value[1], COLS.value[2], ROW),
			board :: string,
			-- blocks / rats: the boosted count gold, the clean one (the place) gray in brackets, like the sidebar; an
			-- old record without the boosted count (the player has not played since) shows only the gray one
			if def.total
				then (if tonumber(row.t)
					then string.format(
						'<font color="%s">%s</font> ',
						hex(GOLD),
						Strings.big(tonumber(row.t) or 0)
					)
					else "") .. string.format(
					'<font color="%s">(%s)</font>',
					hex(GRAY),
					Strings.big(tonumber(row.v) or 0)
				)
				else formatValue(board :: string, tonumber(row.v) or 0),
			28,
			def.color or GREEN
		)
	end
end

local function attach(part: Instance)
	if not part:IsA("BasePart") or guis[part] then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TopBoard_" .. tostring(part:GetAttribute("Board"))
	gui.Adornee = part
	gui.Face = Enum.NormalId.Back -- build-tops turns the board's back to the fountain
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(W, H)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	guis[part] = gui
	render(part, gui)
end

local function detach(part: Instance)
	local gui = guis[part :: BasePart]
	if gui then
		gui:Destroy()
		guis[part :: BasePart] = nil
	end
end

function TopBoards.Refresh()
	for part, gui in pairs(guis) do
		render(part, gui)
	end
end

function TopBoards.Start(locale: () -> string)
	if started then
		return
	end
	started = true
	localeOf = locale
	for _, p in ipairs(CollectionService:GetTagged("TopBoard")) do
		attach(p)
	end
	CollectionService:GetInstanceAddedSignal("TopBoard"):Connect(attach)
	CollectionService:GetInstanceRemovedSignal("TopBoard"):Connect(detach)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Tops")
		for _, v in ipairs(folder:GetChildren()) do
			if v:IsA("StringValue") then
				v.Changed:Connect(function()
					for part, gui in pairs(guis) do
						if part:GetAttribute("Board") == v.Name then
							render(part, gui)
						end
					end
				end)
			end
		end
		TopBoards.Refresh()
	end)
end

return TopBoards
