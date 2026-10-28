--!strict
-- «Зельеварка» [вики POTIONS.md]: the Зельевар level, the modifiers in use and the stand's charge on top; the
-- «Питьевое / Взрывное» switch (splash from Зельевар III); good and bad effects with their durations (only the
-- column of the chosen kind works); «Улучшить» (×1.7, one modifier) and «Создать» (PotionBrew). Rules: Shared/Potions.
-- Built once, updated in place; the charge bar ticks every second while the window is open. While the stand charges,
-- «Перезарядить» uses a «Перезарядка стойки» from the inventory or buys one for crystals (a second tap confirms).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Effects = require(Shared.Effects)
local Potions = require(Shared.Potions)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local PotionWindow = {}

local ROMAN = { "I", "II", "III", "IV", "V" }
local W = 640
local CARD_H, CARD_GAP = 54, 6
local GOOD = Color3.fromRGB(85, 140, 255) -- Minecraft's blue line for a good effect
local BAD = Color3.fromRGB(255, 85, 85)
local CHARGE = Color3.fromRGB(255, 190, 60)
local BREW = Color3.fromRGB(120, 70, 210)
local BREW_LIGHT = Color3.fromRGB(170, 120, 255)

type Card = { button: TextButton, stroke: UIStroke, time: TextLabel, entry: Potions.Entry }

function PotionWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local icons = Config.icons.icons
	local inner = W - 12
	local colW = (inner - 16) / 2
	local listTop = 112
	local bottomY = listTop + 24 + 4 * (CARD_H + CARD_GAP) + 4
	local win, content = createWindow(
		parent,
		t("potions_title"),
		UDim2.fromOffset(W, bottomY + 64 + 26 + 46),
		onClose
	)
	Ui.titleColor(win, Ui.colors.header)

	-- header: the skill, the modifiers, the charge
	local head =
		Kit.frame(content, UDim2.fromOffset(inner - 8, 58), UDim2.fromOffset(4, 4), Kit.CARD)
	Kit.corner(head, 8)
	Kit.stroke(head, Kit.EDGE, 1)
	local standIcon =
		Kit.image(head, icons.menu_potions, UDim2.fromOffset(46, 46), UDim2.fromOffset(8, 6))
	Kit.bob(standIcon, 2, 2.6)
	local skillLabel = Kit.text(
		head,
		"",
		UDim2.fromOffset(280, 26),
		UDim2.fromOffset(62, 5),
		17,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	local modsLabel =
		Kit.text(head, "", UDim2.fromOffset(280, 22), UDim2.fromOffset(62, 30), 13, Ui.colors.muted)
	local chargeLabel = Kit.text(
		head,
		"",
		UDim2.fromOffset(210, 20),
		UDim2.new(1, -222, 0, 7),
		13,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	chargeLabel.TextXAlignment = Enum.TextXAlignment.Right
	local chargeBar = Kit.bar(head, UDim2.fromOffset(210, 14), UDim2.new(1, -222, 0, 32), CHARGE)
	-- «Перезарядка стойки» [вики: 39 кристаллов]: uses the item from the inventory, or buys one (two taps)
	local recharge = Instance.new("TextButton")
	recharge.AutoButtonColor = false
	recharge.Text = ""
	recharge.BackgroundColor3 = Color3.fromRGB(70, 52, 18)
	recharge.Size = UDim2.fromOffset(140, 34)
	recharge.Position = UDim2.new(1, -372, 0, 12)
	recharge.Parent = head
	Kit.corner(recharge, 8)
	Kit.stroke(recharge, CHARGE, 1.5, 0.2)
	Kit.pressable(recharge)
	Kit.hoverable(recharge, Color3.fromRGB(70, 52, 18), Color3.fromRGB(96, 72, 24))
	Kit.image(recharge, icons.stand_recharge, UDim2.fromOffset(26, 26), UDim2.fromOffset(6, 4)).Active =
		false
	local rechargeLabel = Kit.text(
		recharge,
		"",
		UDim2.new(1, -40, 1, 0),
		UDim2.fromOffset(36, 0),
		13,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	rechargeLabel.Active = false
	Kit.fit(rechargeLabel)
	local confirmUntil = 0

	-- the kind switch
	local kindButtons: { [string]: { button: TextButton, stroke: UIStroke, lock: ImageLabel } } = {}
	for i, kind in ipairs({ "drink", "splash" }) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = Kit.CARD
		button.Size = UDim2.fromOffset(colW, 38)
		button.Position = UDim2.fromOffset(4 + (i - 1) * (colW + 8), 68)
		button.Parent = content
		Kit.corner(button, 8)
		local stroke = Kit.stroke(button, Kit.EDGE, 1.5)
		Kit.pressable(button)
		Kit.image(
			button,
			icons[Potions.ITEMS[kind]],
			UDim2.fromOffset(28, 28),
			UDim2.fromOffset(10, 5)
		).Active =
			false
		local label = Kit.text(
			button,
			t("potions_" .. kind),
			UDim2.new(1, -90, 1, 0),
			UDim2.fromOffset(46, 0),
			15,
			Color3.new(1, 1, 1),
			Kit.BOLD
		)
		label.Active = false
		local lock =
			Kit.image(button, icons.ui_lock, UDim2.fromOffset(22, 22), UDim2.new(1, -32, 0.5, -11))
		lock.Active = false
		kindButtons[kind] = { button = button, stroke = stroke, lock = lock }
	end

	-- the effect columns
	local cards: { [string]: { Card } } = { drink = {}, splash = {} }
	local shades: { [string]: Frame } = {}
	for i, kind in ipairs({ "drink", "splash" }) do
		local x = 4 + (i - 1) * (colW + 8)
		local column = Kit.frame(
			content,
			UDim2.fromOffset(colW, 24 + 4 * (CARD_H + CARD_GAP)),
			UDim2.fromOffset(x, listTop),
			Kit.CARD
		)
		column.BackgroundTransparency = 1
		local caption = Kit.text(
			column,
			t(if kind == "drink" then "potions_positive" else "potions_negative"),
			UDim2.new(1, 0, 0, 20),
			UDim2.new(),
			13,
			if kind == "drink" then GOOD else BAD,
			Kit.BOLD
		)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		for n, entry in ipairs(Potions.list(kind :: Potions.Kind)) do
			local button = Instance.new("TextButton")
			button.AutoButtonColor = false
			button.Text = ""
			button.BackgroundColor3 = Kit.CARD
			button.Size = UDim2.new(1, 0, 0, CARD_H)
			button.Position = UDim2.fromOffset(0, 24 + (n - 1) * (CARD_H + CARD_GAP))
			button.Parent = column
			Kit.corner(button, 8)
			local stroke = Kit.stroke(button, Kit.EDGE, 1.5)
			Kit.pressable(button)
			local icon = Kit.image(
				button,
				icons["effect_" .. entry.id],
				UDim2.fromOffset(38, 38),
				UDim2.fromOffset(8, 8)
			)
			icon.Active = false
			local effect = Effects.byId(entry.id)
			local name = Kit.text(
				button,
				t("effect_" .. entry.id),
				UDim2.new(1, -120, 1, 0),
				UDim2.fromOffset(54, 0),
				15,
				if effect then effect.color:Lerp(Color3.new(1, 1, 1), 0.45) else Color3.new(1, 1, 1),
				Kit.BOLD
			)
			name.Active = false
			Kit.fit(name)
			local time = Kit.text(
				button,
				"",
				UDim2.fromOffset(56, CARD_H),
				UDim2.new(1, -64, 0, 0),
				15,
				Ui.colors.muted,
				Kit.BOLD
			)
			time.TextXAlignment = Enum.TextXAlignment.Right
			time.Active = false
			table.insert(
				cards[kind],
				{ button = button, stroke = stroke, time = time, entry = entry }
			)
		end
		local shade =
			Kit.frame(column, UDim2.new(1, 0, 1, -22), UDim2.fromOffset(0, 22), Color3.new(0, 0, 0))
		shade.BackgroundTransparency = 0.45
		shade.ZIndex = 5
		shade.Active = true
		Kit.corner(shade, 8)
		shades[kind] = shade
	end

	-- «Улучшить» and «Создать»
	local upgrade = Instance.new("TextButton")
	upgrade.AutoButtonColor = false
	upgrade.Text = ""
	upgrade.BackgroundColor3 = Kit.CARD
	upgrade.Size = UDim2.fromOffset(colW, 60)
	upgrade.Position = UDim2.fromOffset(4, bottomY)
	upgrade.Parent = content
	Kit.corner(upgrade, 8)
	local upgradeStroke = Kit.stroke(upgrade, Kit.EDGE, 1.5)
	Kit.pressable(upgrade)
	Kit.image(upgrade, icons.potion_upgrade, UDim2.fromOffset(42, 42), UDim2.fromOffset(8, 9)).Active =
		false
	Kit.text(
		upgrade,
		t("potions_upgrade"),
		UDim2.new(1, -64, 0, 24),
		UDim2.fromOffset(58, 8),
		16,
		Color3.fromRGB(255, 215, 90),
		Kit.BOLD
	).Active =
		false
	local upgradeDesc = Kit.text(
		upgrade,
		t("potions_upgrade_desc", Potions.UPGRADE_COST),
		UDim2.new(1, -64, 0, 20),
		UDim2.fromOffset(58, 32),
		12,
		Ui.colors.muted
	)
	upgradeDesc.Active = false
	Kit.fit(upgradeDesc)

	local brewCard = Kit.frame(
		content,
		UDim2.fromOffset(colW, 60),
		UDim2.fromOffset(4 + colW + 8, bottomY),
		Kit.CARD
	)
	Kit.corner(brewCard, 8)
	Kit.stroke(brewCard, Kit.EDGE, 1)
	local preview = Kit.image(brewCard, nil, UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 8))
	local create, createLabel, createBack =
		Kit.actionButton(brewCard, UDim2.new(1, -72, 0, 46), UDim2.fromOffset(62, 7), 16)
	Kit.pressable(create)
	local createGlow = Kit.glow(create, BREW_LIGHT)
	createLabel.Text = t("potions_create")

	local hint = Kit.text(
		content,
		"",
		UDim2.new(1, -16, 0, 22),
		UDim2.fromOffset(8, bottomY + 66),
		13,
		Ui.colors.muted
	)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextTruncate = Enum.TextTruncate.AtEnd

	local mode: Potions.Kind = "drink"
	local chosen: { [string]: { [string]: boolean } } = { drink = {}, splash = {} }
	local upgraded = false
	local warning: string? = nil
	local refresh: (Types.Profile?) -> ()

	local function ids(): { string }
		local out = {}
		for _, entry in ipairs(Potions.list(mode)) do
			if chosen[mode][entry.id] then
				table.insert(out, entry.id)
			end
		end
		return out
	end
	local function creative(): boolean
		return Players.LocalPlayer:GetAttribute("Creative") == true
	end

	for kind, entry in pairs(kindButtons) do
		entry.button.Activated:Connect(function()
			if kind == "splash" and Potions.modifiers(profile) < Potions.SPLASH_LEVEL then
				warning = t("potions_splash_locked")
				Kit.flash(entry.button, BAD)
			elseif mode ~= kind then
				mode = kind :: Potions.Kind
				upgraded = false
				warning = nil
			end
			refresh(profile)
		end)
	end
	for kind, list in pairs(cards) do
		for _, card in ipairs(list) do
			card.button.Activated:Connect(function()
				if kind ~= mode then
					return
				end
				local set = chosen[kind]
				if set[card.entry.id] then
					set[card.entry.id] = nil
					if #ids() == 0 then
						upgraded = false
					end
					warning = nil
				elseif Potions.cost(#ids() + 1, upgraded) > Potions.modifiers(profile) then
					warning = t(
						if Potions.modifiers(profile) < 1
							then "potions_need_skill"
							else "potions_no_modifiers"
					)
					Kit.flash(card.button, BAD)
				else
					set[card.entry.id] = true
					warning = nil
					Kit.pop(card.button, 1.04)
				end
				refresh(profile)
			end)
		end
	end
	upgrade.Activated:Connect(function()
		if upgraded then
			upgraded = false
			warning = nil
		elseif #ids() == 0 then
			warning = t("potions_pick_effect")
			Kit.flash(upgrade, BAD)
		elseif Potions.cost(#ids(), true) > Potions.modifiers(profile) then
			warning = t("potions_no_modifiers")
			Kit.flash(upgrade, BAD)
		else
			upgraded = true
			warning = nil
			Kit.pop(upgrade, 1.04)
		end
		refresh(profile)
	end)
	create.Activated:Connect(function()
		if not create.Active then
			return
		end
		Remotes.event("PotionBrew"):FireServer(mode, ids(), upgraded)
	end)
	local function rechargeSlot(): number?
		local inventory = profile and profile.inventory
		if not inventory then
			return nil
		end
		for slot, stack in pairs(inventory) do
			if stack.id == Potions.RECHARGE then
				return slot
			end
		end
		return nil
	end
	recharge.Activated:Connect(function()
		local slot = rechargeSlot()
		if slot then
			Remotes.event("UseConsumable"):FireServer(slot)
		elseif os.clock() < confirmUntil then
			confirmUntil = 0
			Remotes.event("DonateBuy"):FireServer(Potions.RECHARGE, 1)
		else
			confirmUntil = os.clock() + 3
		end
		refresh(profile)
	end)
	local result = Remotes.event("PotionResult").OnClientEvent:Connect(function(what: string)
		if what == "recharged" then
			Kit.flash(head, CHARGE)
			Kit.pop(standIcon, 1.25)
			refresh(profile)
		elseif what == "brewed" then
			chosen[mode] = {}
			upgraded = false
			warning = nil
			Kit.flash(brewCard, BREW_LIGHT)
			Kit.pop(preview, 1.3)
			refresh(profile)
		end
	end)
	win.Destroying:Connect(function()
		result:Disconnect()
	end)

	refresh = function(p: Types.Profile?)
		profile = p
		local level = Potions.modifiers(p)
		local now = workspace:GetServerTimeNow()
		if mode == "splash" and level < Potions.SPLASH_LEVEL then
			mode = "drink"
			upgraded = false
		end
		local list = ids()
		local used = Potions.cost(#list, upgraded)
		skillLabel.Text = if level > 0
			then t("potions_skill", t("skill_brewer"), ROMAN[level] or tostring(level))
			else t("potions_no_skill")
		modsLabel.Text = t("potions_modifiers", used, level)
		local free = creative()
		local charge = if free then 1 else Potions.charge(p, now)
		chargeBar.set(charge)
		recharge.Visible = charge < 1 and level > 0
		if recharge.Visible then
			local slot = rechargeSlot()
			local stack = slot and p and p.inventory[slot]
			local price = Donate.item(Potions.RECHARGE)
			rechargeLabel.Text = if stack
				then t("potions_recharge_use", stack.count)
				elseif os.clock() < confirmUntil then t(
					"potions_recharge_confirm",
					price and price.price or 0
				)
				else t("potions_recharge_buy", price and price.price or 0)
		end
		chargeLabel.Text = if charge >= 1
			then t("potions_charge", 100)
			else t(
				"potions_charge_left",
				math.floor(charge * 100),
				Potions.clock(Potions.chargeLeft(p, now))
			)
		for kind, entry in pairs(kindButtons) do
			local on = kind == mode
			entry.stroke.Color = if on then BREW_LIGHT else Kit.EDGE
			entry.stroke.Transparency = if on then 0 else 0.4
			entry.button.BackgroundColor3 = if on then Color3.fromRGB(44, 30, 78) else Kit.CARD
			entry.lock.Visible = kind == "splash" and level < Potions.SPLASH_LEVEL
		end
		for kind, column in pairs(cards) do
			shades[kind].Visible = kind ~= mode
			for _, card in ipairs(column) do
				local on = chosen[kind][card.entry.id] == true and kind == mode
				local seconds = if upgraded and kind == mode
					then math.floor(card.entry.seconds * Potions.UPGRADE + 0.5)
					else card.entry.seconds
				card.time.Text = Potions.clock(seconds)
				card.time.TextColor3 = if upgraded and kind == mode
					then Color3.fromRGB(255, 215, 90)
					else Ui.colors.muted
				card.stroke.Color = if on then (if kind == "drink" then GOOD else BAD) else Kit.EDGE
				card.stroke.Transparency = if on then 0 else 0.4
				card.button.BackgroundColor3 = if on
					then (if kind == "drink"
						then Color3.fromRGB(26, 36, 70)
						else Color3.fromRGB(70, 26, 30))
					else Kit.CARD
			end
		end
		upgradeStroke.Color = if upgraded then Color3.fromRGB(255, 215, 90) else Kit.EDGE
		upgradeStroke.Transparency = if upgraded then 0 else 0.4
		upgrade.BackgroundColor3 = if upgraded then Color3.fromRGB(62, 52, 20) else Kit.CARD
		preview.Image = icons[Potions.ITEMS[mode]] or ""
		preview.ImageTransparency = if #list > 0 then 0 else 0.6
		local refusal = Potions.refusal(p, mode, list, upgraded, now, free)
		create.Active = refusal == nil
		TweenService:Create(createBack, TweenInfo.new(0.15), {
			BackgroundColor3 = if refusal == nil then BREW else Kit.GREY,
		}):Play()
		createGlow(refusal == nil)
		if warning then
			hint.Text = warning
			hint.TextColor3 = BAD
		elseif charge < 1 then
			hint.Text = t("potions_not_charged")
			hint.TextColor3 = CHARGE
		elseif refusal and refusal ~= "potions_pick_effect" then
			hint.Text = t(refusal)
			hint.TextColor3 = if refusal == "potions_not_charged" then CHARGE else BAD
		elseif refusal then
			hint.Text = t(if mode == "drink" then "potions_hint_drink" else "potions_hint_splash")
			hint.TextColor3 = Ui.colors.muted
		else
			hint.Text = t("potions_ready")
			hint.TextColor3 = Kit.GOOD
		end
	end
	refresh(profile)
	task.spawn(function()
		while win.Parent do
			task.wait(1)
			if win.Parent then
				refresh(profile)
			end
		end
	end)
	return win, refresh
end

return PotionWindow
