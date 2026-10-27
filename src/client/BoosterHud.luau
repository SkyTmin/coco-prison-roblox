--!strict
-- The running local boosters in the top-left HUD, like the original's «$ x1.1 Локальный» [вики 26.10]: a row per
-- kind with its bottle, the multiplier, «Локальный» and the time left (queued boosters of the kind included);
-- a click opens the storage. Refreshed twice a second from the profile the client holds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local BoosterHud = {}

local SYMBOL = { money = "$ " } -- other kinds: the bottle icon says which

function BoosterHud.start(
	gui: Instance,
	getProfile: () -> Types.Profile?,
	t: (string, ...any) -> string,
	onClick: () -> ()
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Boosters"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(230, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local rows: { [string]: { button: TextButton, text: TextLabel } } = {}
	for i, kind in ipairs(Boosters.kinds) do
		local button = Instance.new("TextButton")
		button.Name = "Booster_" .. kind
		button.Text = ""
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(0, 26)
		button.AutomaticSize = Enum.AutomaticSize.X
		button.BackgroundColor3 = Ui.colors.panel
		button.BackgroundTransparency = 0.35
		button.BorderSizePixel = 0
		button.LayoutOrder = i
		button.Visible = false
		button.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = button
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(22, 22)
		icon.Position = UDim2.fromOffset(0, 2)
		icon.BackgroundTransparency = 1
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.icons.icons["booster_" .. kind] or ""
		icon.Parent = button
		local text = Ui.rich(button, "", UDim2.fromOffset(0, 26), UDim2.fromOffset(26, 0), 14)
		text.AutomaticSize = Enum.AutomaticSize.X
		button.Activated:Connect(onClick)
		rows[kind] = { button = button, text = text }
	end

	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		if clock < nextAt then
			return
		end
		nextAt = clock + 0.5
		local p = getProfile()
		local now = Boosters.now()
		for kind, row in pairs(rows) do
			local running = if p then Boosters.running(p, kind, now) else nil
			row.button.Visible = running ~= nil
			if running and p then
				local left = math.floor(Boosters.remaining(p, kind, now))
				row.text.Text = string.format(
					'<font color="%s">%sx%s</font> <font color="%s">%s</font> %d:%02d',
					Ui.hex(Ui.colors.green),
					SYMBOL[kind] or "",
					tostring(running.mult),
					Ui.hex(Ui.colors.yellow),
					t("booster_local"),
					left // 60,
					left % 60
				)
			end
		end
	end)
	return frame
end

return BoosterHud
