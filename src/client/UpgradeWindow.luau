--!strict
-- "Улучшение предмета" window of the original (owner's screenshots: pickaxe/shovel/axe/armor menus):
-- left panel — big pixel icon of the item at the shown level, orange name, "Уровень N", "Стоимость N $"
-- and the blue "Улучшить" button; right panel — "⬆ Улучшения N" list ("Деревянная лопата 1 → 2",
-- "Эффективность 0 → 1" / "Защита 0 → 1") and "✓ Требования n/m" with counters "Гравий 1.16K / 20 ✓";
-- bottom bar "‹ Уровень 1 → 2 ›" pages through every future level (view only — buying is possible only
-- for the item's current level). A row of owned tools/armour on top selects the item.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local UpgradeWindow = {}

local W, H = 700, 480
local ARMOR = { helmet = true, chestplate = true, leggings = true, boots = true }

local function maxLevel(itemId: string): number
	local tool = Config.tools[itemId]
	local top = 1
	if tool then
		for _, up in ipairs(tool.upgrades) do
			top = math.max(top, up.to)
		end
	end
	return top
end

local function enchantName(itemId: string, locale: string): string
	local key = if ARMOR[itemId] then "enchant_protection" else "enchant_efficiency"
	return Strings.t(key, locale)
end

function UpgradeWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(parent, t("upgrade"), UDim2.fromOffset(W, H), onClose)
	local balance = Ui.rich(win, "", UDim2.fromOffset(160, 28), UDim2.new(1, -204, 0, 6), 14)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	-- owned items row
	local itemsRow = Instance.new("Frame")
	itemsRow.Size, itemsRow.BackgroundTransparency = UDim2.new(1, 0, 0, 52), 1
	itemsRow.Parent = content
	local selectedId: string? = nil
	local viewLevel = 1
	local itemButtons: { [string]: { frame: Frame, icon: ImageLabel } } = {}
	-- left card
	local left = Ui.panel(content, UDim2.fromOffset(240, H - 150), UDim2.fromOffset(0, 58))
	local bigIcon = Instance.new("ImageLabel")
	bigIcon.AnchorPoint = Vector2.new(0.5, 0)
	bigIcon.Position = UDim2.new(0.5, 0, 0, 16)
	bigIcon.Size = UDim2.fromOffset(128, 128)
	bigIcon.BackgroundTransparency = 1
	bigIcon.ScaleType = Enum.ScaleType.Fit
	bigIcon.ResampleMode = Enum.ResamplerMode.Pixelated
	bigIcon.Parent = left
	local glint = bigIcon:Clone()
	glint.ImageColor3 = Color3.fromRGB(190, 110, 255)
	glint.ImageTransparency = 0.6
	glint.Parent = bigIcon
	glint.Position, glint.Size = UDim2.new(), UDim2.fromScale(1, 1)
	local itemName =
		Ui.label(left, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 152), 15, Ui.colors.header)
	itemName.TextXAlignment = Enum.TextXAlignment.Center
	local itemLevel =
		Ui.label(left, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 174), 13, Ui.colors.text)
	itemLevel.TextXAlignment = Enum.TextXAlignment.Center
	local costLabel = Ui.rich(left, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 210), 14)
	local buy =
		Ui.button(left, t("upgrade_button"), UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 1, -44))
	-- right card
	local right = Ui.panel(content, UDim2.new(1, -250, 0, H - 150), UDim2.fromOffset(250, 58))
	local upsHeader =
		Ui.label(right, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), 13, Ui.colors.muted)
	local upsCount =
		Ui.label(right, "", UDim2.fromOffset(60, 22), UDim2.new(1, -68, 0, 6), 13, Ui.colors.text)
	upsCount.TextXAlignment = Enum.TextXAlignment.Right
	local upsBox = Ui.inset(right, UDim2.new(1, -16, 0, 62), UDim2.fromOffset(8, 30))
	local upsLines = {
		Ui.rich(upsBox, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 6), 13),
		Ui.rich(upsBox, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 32), 13),
	}
	local reqHeader =
		Ui.label(right, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 100), 13, Ui.colors.muted)
	local reqCount =
		Ui.label(right, "", UDim2.fromOffset(60, 22), UDim2.new(1, -68, 0, 100), 13, Ui.colors.text)
	reqCount.TextXAlignment = Enum.TextXAlignment.Right
	local reqBox = Ui.inset(right, UDim2.new(1, -16, 1, -132), UDim2.fromOffset(8, 124))
	local reqLines: { TextLabel } = {}
	for i = 1, 4 do
		reqLines[i] =
			Ui.rich(reqBox, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 6 + (i - 1) * 26), 13)
	end
	-- bottom pager
	local prev = Ui.button(
		content,
		"‹",
		UDim2.fromOffset(36, 32),
		UDim2.new(0, 0, 1, -34),
		Ui.colors.buttonGrey
	)
	local nextB = Ui.button(
		content,
		"›",
		UDim2.fromOffset(36, 32),
		UDim2.new(1, -36, 1, -34),
		Ui.colors.buttonGrey
	)
	local pager = Ui.inset(content, UDim2.new(1, -84, 0, 32), UDim2.new(0, 42, 1, -34))
	local pagerText = Ui.rich(pager, "", UDim2.new(1, -8, 1, 0), UDim2.fromOffset(4, 0), 14)
	pagerText.TextXAlignment = Enum.TextXAlignment.Center

	local function ownedLevel(id: string): number
		if not profile then
			return 1
		end
		if ARMOR[id] then
			local piece = profile.armor[id]
			if piece then
				return piece.level or 1
			end
		end
		for _, stack in pairs(profile.inventory) do
			if stack.id == id then
				return stack.level or 1
			end
		end
		return 1
	end

	local function refresh(p: Types.Profile?)
		profile = p
		balance.Text = string.format(
			'<font color="%s">$ %s</font>',
			Ui.hex(Ui.colors.money),
			if p then Strings.money(p.coins) else "0"
		)
		-- owned items
		local owned: { string } = {}
		if p then
			local seen: { [string]: boolean } = {}
			for _, stack in pairs(p.inventory) do
				if Config.tools[stack.id] and not seen[stack.id] then
					seen[stack.id] = true
					table.insert(owned, stack.id)
				end
			end
			for id in pairs(p.armor) do
				if not seen[id] then
					seen[id] = true
					table.insert(owned, id)
				end
			end
		end
		table.sort(owned)
		for id, view in pairs(itemButtons) do
			if not table.find(owned, id) then
				view.frame:Destroy()
				itemButtons[id] = nil
			end
		end
		for index, id in ipairs(owned) do
			local view = itemButtons[id]
			if not view then
				local frame, _, _, icon = Ui.slot(itemsRow, 48)
				local hit = Instance.new("TextButton")
				hit.Size, hit.BackgroundTransparency, hit.Text = UDim2.fromScale(1, 1), 1, ""
				hit.Parent = frame
				hit.Activated:Connect(function()
					selectedId = id
					viewLevel = ownedLevel(id)
					refresh(profile)
				end)
				view = { frame = frame, icon = icon }
				itemButtons[id] = view
			end
			view.frame.Position = UDim2.fromOffset((index - 1) * 52, 0)
			view.icon.Image = Config.iconFor(id, ownedLevel(id)) or ""
			view.icon.Visible = view.icon.Image ~= ""
			local stroke = view.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if id == selectedId then Ui.colors.slotSelected else Ui.colors.border
				stroke.Thickness = if id == selectedId then 2 else 1
			end
		end
		if not selectedId or not table.find(owned, selectedId) then
			selectedId = owned[1]
			viewLevel = if selectedId then ownedLevel(selectedId) else 1
		end
		local id = selectedId
		left.Visible, right.Visible, pager.Visible, prev.Visible, nextB.Visible =
			id ~= nil, id ~= nil, id ~= nil, id ~= nil, id ~= nil
		if not id then
			return
		end
		local current = ownedLevel(id)
		local top = maxLevel(id)
		viewLevel = math.clamp(viewLevel, 1, top)
		local up = Config.upgrade(id, viewLevel)
		local shownLevel = viewLevel
		local icon = Config.iconFor(id, shownLevel) or ""
		bigIcon.Image, glint.Image = icon, icon
		glint.Visible = Config.isEnchanted(id, shownLevel)
		itemName.Text = Strings.itemName(id, shownLevel, locale)
		itemLevel.Text = string.format("%s %d", t("level"), shownLevel)
		if up then
			costLabel.Text = string.format(
				'%s  <font color="%s">%s $</font>',
				t("cost"),
				Ui.hex(Ui.colors.money),
				Strings.big(up.cost)
			)
			upsHeader.Text = "⬆ " .. t("upgrades")
			local enchantBefore = Config.enchantForLevel(id, viewLevel)
			local enchantAfter = up.enchantAfter
			local lines = {
				string.format(
					'<font color="%s">%s</font>  %d → <font color="%s">%d</font>',
					Ui.hex(Ui.colors.header),
					Strings.itemName(id, viewLevel, locale),
					viewLevel,
					Ui.hex(Ui.colors.money),
					up.to
				),
			}
			if enchantAfter ~= enchantBefore then
				table.insert(
					lines,
					string.format(
						'<font color="%s">%s</font>  %d → <font color="%s">%d</font>',
						Ui.hex(Ui.colors.level),
						enchantName(id, locale),
						enchantBefore,
						Ui.hex(Ui.colors.money),
						enchantAfter
					)
				)
			end
			upsCount.Text = tostring(#lines)
			for i, label in ipairs(upsLines) do
				label.Text = lines[i] or ""
			end
			local met, total = 0, 0
			local i = 0
			for counter, needed in pairs(up.requirements) do
				i += 1
				total += 1
				local have = if p then (p.counters[counter] or 0) else 0
				local ok = have >= needed
				if ok then
					met += 1
				end
				if reqLines[i] then
					reqLines[i].Text = string.format(
						'%s  <font color="%s">%s</font> / <font color="%s">%s</font>%s',
						counter,
						Ui.hex(if ok then Ui.colors.money else Ui.colors.red),
						Strings.big(have),
						Ui.hex(Ui.colors.money),
						Strings.big(needed),
						if ok then " ✓" else ""
					)
				end
			end
			for j = i + 1, #reqLines do
				reqLines[j].Text = ""
			end
			reqHeader.Text = "✓ " .. t("requirements")
			reqCount.Text = string.format("%d / %d", met, total)
			local affordable = p ~= nil and p.coins >= up.cost * Config.moneyScale
			local purchasable = viewLevel == current and met == total and affordable
			buy.Text = if viewLevel ~= current then t("upgrade_preview") else t("upgrade_button")
			buy.BackgroundColor3 = if purchasable
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
			buy.Interactable = purchasable
			pagerText.Text = string.format(
				'%s %d → <font color="%s">%d</font>',
				t("level"),
				viewLevel,
				Ui.hex(Ui.colors.money),
				up.to
			)
		else
			costLabel.Text = ""
			upsHeader.Text = "⬆ " .. t("upgrades")
			upsCount.Text = "0"
			upsLines[1].Text = t("upgrade_max")
			upsLines[2].Text = ""
			reqHeader.Text = "✓ " .. t("requirements")
			reqCount.Text = "0 / 0"
			for _, label in ipairs(reqLines) do
				label.Text = ""
			end
			buy.Text = t("upgrade_max")
			buy.BackgroundColor3 = Ui.colors.buttonGrey
			buy.Interactable = false
			pagerText.Text = string.format("%s %d", t("level"), viewLevel)
		end
		prev.Interactable, nextB.Interactable = viewLevel > 1, viewLevel < top
		prev.BackgroundColor3 = if viewLevel > 1 then Ui.colors.buttonGrey else Ui.colors.inset
		nextB.BackgroundColor3 = if viewLevel < top then Ui.colors.buttonGrey else Ui.colors.inset
	end
	prev.Activated:Connect(function()
		viewLevel = math.max(1, viewLevel - 1)
		refresh(profile)
	end)
	nextB.Activated:Connect(function()
		viewLevel += 1
		refresh(profile)
	end)
	buy.Activated:Connect(function()
		if buy.Interactable and selectedId then
			Remotes.event("UpgradeItem"):FireServer(selectedId)
		end
	end)
	refresh(profile)
	return win, refresh
end

return UpgradeWindow
