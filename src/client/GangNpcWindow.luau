--!strict
-- The windows of the База банды NPCs [клиент npc.gang.librarian / blacksmith; docs/research/remaining-features-design.md
-- §1.5] in the dark inventory style (Ui.card, Ui.invSlot, SlotView):
--   * «Библиотекарь»: every ancient book of the bag with the gang points it gives (rarity × level) and «Сдать»;
--   * «Кузнец»: the books grouped by effect and level; a group of two or more shows the chance, the star price and
--     «Выковать» (two books of the group go to the server).
-- The server decides (GangBaseService, GangNpc remote). Also: the gang location check of the locations menu
-- (`locationRefusal`) and the treasure chest capture broken by damage (`listen`: TreasureReset lets the prompt go).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local SlotView = require(script.Parent.SlotView)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local GangNpcWindow = {}

local W, H = 560, 440
local ROW = 60
local base = Config.gangs.base
local listening = false

-- База банды / Гетто in the locations menu: the gang and its upgrade as GangService mirrors them (player attributes
-- GangId, GangUp_<id>); returns the refusal key or nil
function GangNpcWindow.locationRefusal(location: Config.Location): string?
	if not location.requiresGang then
		return nil
	end
	local player = Players.LocalPlayer
	if player:GetAttribute("GangId") == nil then
		return "gang_location_need_gang"
	end
	local upgrade = location.requiresGangUpgrade
	if upgrade then
		local level = player:GetAttribute("GangUp_" .. upgrade)
		if typeof(level) ~= "number" or level < 1 then
			return "gang_location_need_" .. upgrade
		end
	end
	return nil
end

-- damage broke the treasure chest capture: let the held prompt go (the server already ignores this hold)
function GangNpcWindow.listen()
	if listening then
		return
	end
	listening = true
	Remotes.event("TreasureReset").OnClientEvent:Connect(function()
		for _, chest in ipairs(workspace:GetChildren()) do
			if chest.Name == "TreasureChest" then
				local prompt = chest:FindFirstChild("TreasurePrompt", true)
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt:InputHoldEnd()
				end
			end
		end
	end)
end

local function bookOf(stack: Types.ItemStack?): (string?, number?)
	if not stack or stack.id ~= "ancient_book" or not stack.books or not stack.books[1] then
		return nil, nil
	end
	return stack.books[1].id, stack.books[1].level
end

-- the same numbers as GangBaseService (the server decides, this only shows them)
local function libraryPoints(stack: Types.ItemStack): number
	local effect, level = bookOf(stack)
	if not effect or not level then
		return 0
	end
	local entry = Config.books.catalog[effect]
	local rarity = stack.rarity or (entry and entry.rarity) or "common"
	local points = base.library.rarityPoints[rarity] or base.library.rarityPoints.common
	return math.floor(points * level)
end

local function forgeOffer(effect: string, level: number): (number?, number?)
	local values = Config.books.effects[effect]
	if not values or level >= #values then
		return nil, nil
	end
	local chances = base.forge.chances
	return chances[math.min(level, #chances)], base.forge.starsPerLevel * (level + 1)
end

local function starCount(profile: Types.Profile?): number
	local n = 0
	if profile then
		for _, stack in pairs(profile.inventory) do
			if stack.id == "ancient_star" then
				n += stack.count
			end
		end
	end
	return n
end

function GangNpcWindow.build(
	parent: Instance,
	mode: string, -- "library" | "forge"
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local isForge = mode == "forge"
	local win, content = createWindow(
		parent,
		T(if isForge then "gang_forge_title" else "gang_library_title"),
		UDim2.fromOffset(W, H),
		onClose
	)
	win.Name = if isForge then "Window_GangForge" else "Window_GangLibrary"
	Ui.titleColor(win, Ui.colors.header)
	local hint = Ui.label(
		content,
		T(if isForge then "gang_forge_hint" else "gang_library_hint"),
		UDim2.new(1, -56, 0, 36),
		UDim2.fromOffset(48, 2),
		13,
		Ui.colors.muted
	)
	hint.TextWrapped = true
	-- the NPC picture (Codex → Blender, menu_librarian / menu_forge; a book / anvil until it is uploaded)
	local icons = Config.icons.icons
	local picture = Instance.new("ImageLabel")
	picture.Size = UDim2.fromOffset(36, 36)
	picture.Position = UDim2.fromOffset(6, 2)
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Image = if isForge
		then icons.menu_forge or icons.skill_anvil or ""
		else icons.menu_librarian or icons.ancient_book or ""
	picture.Parent = content
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -8, 1, -48)
	list.Position = UDim2.fromOffset(4, 44)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function row(
		order: number,
		stack: Types.ItemStack,
		title: string,
		sub: string,
		subColor: Color3?
	): Frame
		local card = Ui.card(list, UDim2.new(1, -8, 0, ROW), UDim2.new())
		card.LayoutOrder = order
		local slot, name, count, icon = Ui.invSlot(card, 48)
		slot.Position = UDim2.fromOffset(6, 6)
		SlotView.render(name, count, icon, stack)
		local t = Ui.label(card, title, UDim2.new(1, -230, 0, 24), UDim2.fromOffset(62, 6), 15)
		t.TextTruncate = Enum.TextTruncate.AtEnd
		local s = Ui.label(
			card,
			sub,
			UDim2.new(1, -230, 0, 22),
			UDim2.fromOffset(62, 32),
			13,
			subColor or Ui.colors.muted
		)
		s.TextTruncate = Enum.TextTruncate.AtEnd
		return card
	end

	local function actionButton(card: Frame, text: string, enabled: boolean, onClick: () -> ())
		local b = Ui.button(
			card,
			text,
			UDim2.fromOffset(140, 36),
			UDim2.new(1, -150, 0, 12),
			if enabled then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		b.TextSize = 15
		b.Interactable = enabled
		b.Activated:Connect(onClick)
	end

	local function empty()
		local l = Ui.label(
			list,
			T("gang_library_empty"),
			UDim2.new(1, -8, 0, 40),
			UDim2.new(),
			15,
			Ui.colors.muted
		)
		l.TextXAlignment = Enum.TextXAlignment.Center
	end

	local function refresh(p: Types.Profile?)
		profile = p
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not p then
			return
		end
		local slots: { number } = {}
		for slot = 1, 36 do
			if bookOf(p.inventory[slot]) then
				table.insert(slots, slot)
			end
		end
		if #slots == 0 then
			empty()
			return
		end
		if not isForge then
			for i, slot in ipairs(slots) do
				local stack = p.inventory[slot]
				local effect, level = bookOf(stack)
				if not effect or not level or not stack then
					continue
				end
				local rarity = stack.rarity or "common"
				local card = row(
					i,
					stack,
					ItemInfo.bookName(effect, level, locale),
					(
						if Strings.has("rarity_" .. rarity, locale)
							then T("rarity_" .. rarity) .. " · "
							else ""
					) .. T("gang_library_points", libraryPoints(stack)),
					ItemInfo.RARITY_COLORS[rarity]
				)
				actionButton(card, T("gang_library_give"), true, function()
					Remotes.event("GangNpc"):FireServer("library", slot)
				end)
			end
			return
		end
		-- the forge: one row per effect + level, the first two slots of a group are the pair
		type Group = { effect: string, level: number, slots: { number } }
		local groups: { Group } = {}
		local byKey: { [string]: Group } = {}
		for _, slot in ipairs(slots) do
			local effect, level = bookOf(p.inventory[slot])
			if effect and level then
				local key = effect .. "#" .. level
				local g = byKey[key]
				if not g then
					g = { effect = effect, level = level, slots = {} }
					byKey[key] = g
					table.insert(groups, g)
				end
				table.insert(g.slots, slot)
			end
		end
		local stars = starCount(p)
		for i, g in ipairs(groups) do
			local chance, price = forgeOffer(g.effect, g.level)
			local sub: string
			local color: Color3? = nil
			local ok = false
			if not chance or not price then
				sub = T("gang_forge_max")
			elseif #g.slots < 2 then
				sub = T("gang_forge_no_pair")
			else
				sub = T("gang_forge_chance", math.floor(chance * 100 + 0.5))
					.. " · "
					.. T("gang_forge_cost", price)
				ok = stars >= price
				color = if ok then Ui.colors.text else Ui.colors.red
			end
			local card = row(
				i,
				p.inventory[g.slots[1]] :: Types.ItemStack,
				ItemInfo.bookName(g.effect, g.level, locale) .. " ×" .. #g.slots,
				sub,
				color
			)
			if chance and #g.slots >= 2 then
				actionButton(card, T("gang_forge_button"), ok, function()
					Remotes.event("GangNpc"):FireServer("forge", g.slots[1], g.slots[2])
				end)
			end
		end
	end
	refresh(profile)
	return win, refresh
end

return GangNpcWindow
