--!strict
-- Compact health / hunger bars [владелец 01.11]. Armor keeps its Minecraft icon row.
local Ui = require(script.Parent.Ui)
local SurvivalBars = {}

local function make(parent: Frame, name: string, right: boolean, color: Color3)
	local group = Instance.new("Frame")
	group.Name = name
	group.Size = UDim2.new(0.5, -22, 0, 20)
	group.AnchorPoint = Vector2.new(if right then 1 else 0, 0)
	group.Position = UDim2.fromScale(if right then 1 else 0, 0)
	group.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	group.BorderSizePixel = 0
	group.Parent = parent
	local border = Instance.new("UIStroke")
	border.Color, border.Thickness, border.Parent = Color3.fromRGB(10, 11, 13), 1, group
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position, track.Size = UDim2.fromOffset(2, 2), UDim2.new(1, -4, 1, -4)
	track.BackgroundColor3, track.BorderSizePixel, track.Parent =
		color:Lerp(Color3.new(), 0.75), 0, group
	local fill = Instance.new("Frame")
	fill.Name, fill.Size = "Fill", UDim2.fromScale(1, 1)
	fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = color, 0, track
	local shield = Instance.new("Frame")
	shield.Name = "Absorption"
	shield.Position, shield.AnchorPoint = UDim2.fromScale(0, 1), Vector2.new(0, 1)
	shield.Size = UDim2.fromOffset(0, 3)
	shield.BackgroundColor3 = Color3.fromRGB(255, 205, 40)
	shield.BorderSizePixel, shield.Visible, shield.ZIndex, shield.Parent = 0, false, 2, track
	local label = Ui.label(group, "", UDim2.fromScale(1, 1), UDim2.new(), 14, Color3.new(1, 1, 1))
	label.Name = "Value"
	label.TextXAlignment, label.TextStrokeTransparency, label.ZIndex =
		Enum.TextXAlignment.Center, 0, 3
	label.TextStrokeColor3 = Color3.new()
	local tooltip = Ui.label(group, "", UDim2.fromOffset(220, 22), UDim2.new(0.5, -110, 0, -26), 12)
	tooltip.Name = "Tooltip"
	tooltip.TextXAlignment, tooltip.BackgroundColor3 = Enum.TextXAlignment.Center, Ui.colors.panel
	tooltip.BackgroundTransparency, tooltip.Visible, tooltip.ZIndex = 0.15, false, 8
	group.MouseEnter:Connect(function()
		tooltip.Visible = true
	end)
	group.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
	local previousHealth: number? = nil
	local previousMaximum: number? = nil
	local flashVersion = 0
	return {
		group = group,
		tooltip = tooltip,
		update = function(value: number, maximum: number, absorbed: number?)
			maximum = math.max(1, maximum)
			value = math.clamp(value, 0, maximum)
			if
				name == "HealthBar"
				and previousHealth
				and previousMaximum == maximum
				and value < previousHealth - 0.01
			then
				-- Minecraft's white hurt outline, adapted to the compact bar [владелец 01.11].
				flashVersion += 1
				local version = flashVersion
				task.spawn(function()
					for i = 1, 6 do
						if not group.Parent or version ~= flashVersion then
							return
						end
						border.Color = if i % 2 == 1
							then Color3.new(1, 1, 1)
							else Color3.fromRGB(10, 11, 13)
						task.wait(0.1)
					end
				end)
			end
			previousHealth, previousMaximum = value, maximum
			fill.Size = UDim2.fromScale(value / maximum, 1)
			local extra = math.max(0, absorbed or 0)
			shield.Visible = extra > 0
			shield.Size = UDim2.new(math.min(1, extra / maximum), 0, 0, 3)
			label.Text = string.format("%d / %d", math.ceil(value), math.ceil(maximum))
				.. (if extra > 0 then "  +" .. math.ceil(extra) else "")
		end,
	}
end

function SurvivalBars.new(parent: Frame)
	return {
		health = make(parent, "HealthBar", false, Color3.fromRGB(183, 48, 53)),
		hunger = make(parent, "HungerBar", true, Color3.fromRGB(177, 115, 43)),
	}
end

return SurvivalBars
