--!strict
-- The PRIS+ perks that live on this screen (этап 8; Shared/PrisPlus; switched in PrisWindow — profile.settings):
--   * autoDig(part) — the auto-dig [клиент prison_plus.mining.*: «навсегда избавитесь от зажатия ЛКМ», only in a mine
--     zone; сеть R2: eating while it digs]: the dig loop of init.client keeps digging a mine block under the crosshair as
--     if the button were held. The server times and checks every block as always (DigService).
--   * sync(profile) — the night [клиент «Включение ночи»] through IndoorLighting.SetNight.
--   * appleSkin(meter, profile, health, maxHealth) — AppleSkin [клиент «AppleSkin»]: a line over the hunger row with
--     what the food in the hand gives (PrisPlus.appleSkin).
-- Own PRIS+ = the PrisPlus attribute the server keeps on the player (it follows the end of the term within a second).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PrisPlus = require(Shared.PrisPlus)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local IndoorLighting = require(script.Parent.IndoorLighting)
local Ui = require(script.Parent.Ui)

local PrisPerks = {}
local player = Players.LocalPlayer
local current: Types.Profile? = nil
local appleLabel: TextLabel? = nil

function PrisPerks.active(): boolean
	return PrisPlus.of(player)
end

local function setting(key: string): boolean
	local settings = current and current.settings :: any
	return settings ~= nil and settings[key] == true
end

function PrisPerks.sync(p: Types.Profile?)
	current = p
	IndoorLighting.SetNight(PrisPerks.active() and setting("night"))
end

player:GetAttributeChangedSignal(PrisPlus.ATTRIBUTE):Connect(function()
	PrisPerks.sync(current)
end)

-- may the dig loop dig this block by itself
function PrisPerks.autoDig(part: BasePart?): boolean
	return part ~= nil
		and PrisPerks.active()
		and setting("autoDig")
		and typeof(part:GetAttribute("MineId")) == "string"
end

function PrisPerks.appleSkin(meter: Frame, p: Types.Profile?, health: number, maxHealth: number)
	local survival = Config.rules.survival
	local stack = if p then p.inventory[p.selectedSlot] else nil
	local food = stack and survival.food[stack.id]
	local show = p ~= nil
		and typeof(food) == "number"
		and PrisPerks.active()
		and not (p.settings and p.settings.appleSkinOff)
	if not show then
		if appleLabel then
			appleLabel.Visible = false
		end
		return
	end
	local profile = p :: Types.Profile
	local label = appleLabel
	if not label or label.Parent ~= meter then
		if label then
			label:Destroy()
		end
		local made = Ui.label(meter, "", UDim2.fromOffset(240, 18), UDim2.new(1, -240, 0, -20), 13)
		made.Name = "AppleSkin"
		made.TextXAlignment = Enum.TextXAlignment.Right
		made.TextColor3 = Color3.fromRGB(255, 205, 120)
		made.TextStrokeTransparency = 0.4
		label = made
		appleLabel = made
	end
	local saturation = survival.saturation[(stack :: Types.ItemStack).id]
	local hunger, sat, hp = PrisPlus.appleSkin(
		profile.hunger,
		profile.saturation or 0,
		food :: number,
		if typeof(saturation) == "number" then saturation else 0,
		maxHealth - health
	)
	local locale = profile.locale or Config.defaultLocale
	local l = label :: TextLabel
	l.Text = Strings.t(
		"appleskin_line",
		locale,
		hunger,
		(string.format("%.1f", sat):gsub("%.0$", "")),
		hp
	)
	l.Visible = true
end

return PrisPerks
