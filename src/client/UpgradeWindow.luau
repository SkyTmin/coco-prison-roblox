--!strict
-- "Улучшение предмета" window of the original (owner's screenshots: pickaxe/shovel/axe/armor menus):
-- left panel — big pixel icon of the item at the shown level, orange name, "Уровень N", "Стоимость N $"
-- and the blue "Улучшить" button; right panel — "⬆ Улучшения N" list ("Деревянная лопата 1 → 2",
-- "Эффективность 0 → 1" / "Защита 0 → 1") and "✓ Требования n/m" with counters "Гравий 1.16K / 20 ✓";
-- bottom bar "‹ Уровень 1 → 2 ›" pages through every future level (view only — buying is possible only
-- for the item's current level). A row of owned tools/armour on top selects the item — one button
-- per item (two shovels are two entries, each with its own level), the held tool first; the
-- requirement counters are the player's.
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
	local tool = Config.tools[itemId]
	local key = if tool and tool.enchant
		then "enchant_" .. tool.enchant
		elseif ARMOR[itemId] then "enchant_protection"
		else "enchant_efficiency"
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
	local selectedKey: string? = nil
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

	-- Every owned tool / armor piece is its own entry [владелец 21.10]: two shovels are two items, each
	-- with its own level. Keys: "inv:<slot>" or "armor:<part>".
	type Entry = { key: string, stack: Types.ItemStack, target: number | string }
	local function entries(p: Types.Profile?): { Entry }
		local list: { Entry } = {}
		if not p then
			return list
		end
		for slot = 1, 36 do
			local stack = p.inventory[slot]
			if stack and Config.tools[stack.id] then
				table.insert(list, { key = "inv:" .. slot, stack = stack, target = slot })
			end
		end
		for _, part in ipairs({ "helmet", "chestplate", "leggings", "boots" }) do
			local piece = p.armor[part]
			if piece then
				table.insert(list, { key = "armor:" .. part, stack = piece, target = part })
			end
		end
		return list
	end
	local function entryFor(key: string?): Entry?
		for _, entry in ipairs(entries(profile)) do
			if entry.key == key then
				return entry
			end
		end
		return nil
	end

	local function refresh(p: Types.Profile?)
		profile = p
		balance.Text = string.format(
			'<font color="%s">$ %s</font>',
			Ui.hex(Ui.colors.money),
			if p then Strings.money(p.coins) else "0"
		)
		-- owned items, one button each
		local owned = entries(p)
		local alive: { [string]: boolean } = {}
		for index, entry in ipairs(owned) do
			alive[entry.key] = true
			local view = itemButtons[entry.key]
			if not view then
				local frame, _, _, icon = Ui.slot(itemsRow, 48)
				local hit = Instance.new("TextButton")
				hit.Size, hit.BackgroundTransparency, hit.Text = UDim2.fromScale(1, 1), 1, ""
				hit.Parent = frame
				local key = entry.key
				hit.Activated:Connect(function()
					local chosen = entryFor(key)
					selectedKey = key
					viewLevel = if chosen then (chosen.stack.level or 1) else 1
					refresh(profile)
				end)
				view = { frame = frame, icon = icon }
				itemButtons[entry.key] = view
			end
			view.frame.Position = UDim2.fromOffset((index - 1) * 52, 0)
			view.icon.Image = Config.iconFor(entry.stack.id, entry.stack.level or 1) or ""
			view.icon.Visible = view.icon.Image ~= ""
			local stroke = view.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				local selected = entry.key == selectedKey
				stroke.Color = if selected then Ui.colors.slotSelected else Ui.colors.border
				stroke.Thickness = if selected then 2 else 1
			end
		end
		for key, view in pairs(itemButtons) do
			if not alive[key] then
				view.frame:Destroy()
				itemButtons[key] = nil
			end
		end
		local chosen = entryFor(selectedKey)
		if not chosen then
			-- default: the tool in hand, else the first owned item
			local heldKey = if p then "inv:" .. p.selectedSlot else nil
			chosen = entryFor(heldKey) or owned[1]
			selectedKey = if chosen then chosen.key else nil
			viewLevel = if chosen then (chosen.stack.level or 1) else 1
		end
		local entry = chosen
		left.Visible, right.Visible, pager.Visible, prev.Visible, nextB.Visible =
			entry ~= nil, entry ~= nil, entry ~= nil, entry ~= nil, entry ~= nil
		if not entry then
			return
		end
		local id = entry.stack.id
		local current = entry.stack.level or 1
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
			local flameBefore = Config.flameForLevel(id, viewLevel)
			if (up.flameAfter or flameBefore) ~= flameBefore then
				table.insert(
					lines,
					string.format(
						'<font color="%s">%s</font>  %d → <font color="%s">%d</font>',
						Ui.hex(Ui.colors.level),
						Strings.t("enchant_flame", locale),
						flameBefore,
						Ui.hex(Ui.colors.money),
						up.flameAfter :: number
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
				local have = if p then Config.requirementHave(p, counter) else 0
				local ok = have >= needed
				if ok then
					met += 1
				end
				if reqLines[i] then
					reqLines[i].Text = string.format(
						'%s  <font color="%s">%s</font> / <font color="%s">%s</font>%s',
						Strings.counterName(counter, locale),
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
		local entry = entryFor(selectedKey)
		if buy.Interactable and entry then
			Remotes.event("UpgradeItem"):FireServer(entry.target)
		end
	end)
	refresh(profile)
	return win, refresh
end

return UpgradeWindow
