--!strict
-- The auto-sell's income at the crosshair [владелец 28.10: «по центру экрана сумма, как на скриншоте»; вики
-- MENUS-SOCIAL: green «+0,057 $» next to the crosshair for each sold block, «Частицы у прицела при автопродаже»]:
-- AutoSold floats income near the crosshair; area-book sales are red and stay 0.5 s longer.
-- [владелец 28.10: «пусть появляется в разных местах, то справа, то слева»] each one on the other side of the
-- crosshair from the last, a little higher or lower at random. Hidden by settings.autosellTextOff.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local AutoSellFx = {}

local LIFE = 1.1 -- s on screen
local RISE = 34 -- px it floats up
local MAX = 4
local SPREAD = 22 -- px up / down at random

function AutoSellFx.start(gui: Instance, getProfile: () -> Types.Profile?, locale: () -> string)
	local layer = Instance.new("Frame")
	layer.Name = "AutoSellFx"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 5
	layer.Parent = gui
	local live: { { label: TextLabel, untilAt: number, area: boolean } } = {}
	local right = true
	local random = Random.new()

	Remotes.event("AutoSold").OnClientEvent:Connect(function(units: number, area: boolean?)
		local p = getProfile()
		if typeof(units) ~= "number" or (p and p.settings and p.settings.autosellTextOff) then
			return
		end
		local now = os.clock()
		local isArea = area == true
		local life = LIFE + (if isArea then 0.5 else 0)
		for i = #live, 1, -1 do
			if now > live[i].untilAt or not live[i].label.Parent then
				table.remove(live, i)
			end
		end
		if #live >= MAX then
			local oldest = nil
			for i, entry in ipairs(live) do
				if not entry.area then
					oldest = i
					break
				end
			end
			-- Ordinary sales cannot cut short the longer area-sale notification.
			if not oldest and not isArea then
				return
			end
			local removeAt = oldest or 1
			live[removeAt].label:Destroy()
			table.remove(live, removeAt)
		end
		local text = "+" .. Strings.money(units) .. " $"
		if locale() == "ru" or locale() == "es" or locale() == "fr" then
			text = (text:gsub("%.", ","))
		end
		local label = Ui.label(
			layer,
			text,
			UDim2.fromOffset(120, 20),
			UDim2.new(
				0.5,
				if right then 14 else -134,
				0.5,
				-10 + random:NextInteger(-SPREAD, SPREAD)
			),
			17,
			if isArea then Color3.fromRGB(255, 75, 75) else Ui.colors.green
		)
		label.TextXAlignment = if right then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		right = not right
		label.TextStrokeTransparency = 0.35
		label.ZIndex = 5
		label:SetAttribute("AreaSale", isArea)
		table.insert(live, { label = label, untilAt = now + life, area = isArea })
		local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, info, {
			Position = label.Position - UDim2.fromOffset(0, RISE),
		}):Play()
		TweenService:Create(
			label,
			TweenInfo.new(
				LIFE * 0.5,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.In,
				0,
				false,
				life - LIFE * 0.5
			),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
		task.delay(life, function()
			label:Destroy()
		end)
	end)
end

return AutoSellFx
