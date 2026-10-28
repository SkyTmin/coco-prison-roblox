--!strict
-- The windows of the База банды NPCs [клиент npc.gang.librarian / blacksmith; docs/research/remaining-features-design.md
-- §1.5] in the dark inventory style (Ui.card, Ui.invSlot, SlotView):
--   * «Библиотекарь» [владелец 28.10]: «Предметов: N», the bar a / 4000 of the gang (GangState.library) with
--     «Забрать награду», every ancient book of the bag with its points (rarity × level) and «Сдать»;
--   * «Кузнец» [владелец 28.10]: two book slots «+» → «?», the books of the bag to pick from, the button «Выберите две
--     книги одного типа» until the pair is valid, then the chance and the star price (the pair goes to the server).
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
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local GangNpcWindow = {}

local W, H = 560, 480
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
	local itemsLabel = Ui.label(
		content,
		"",
		UDim2.fromOffset(200, 18),
		UDim2.fromOffset(48, 0),
		14,
		Ui.colors.header
	)
	local hint = Ui.label(
		content,
		T(if isForge then "gang_forge_hint" else "gang_library_text"),
		UDim2.new(1, -56, 0, 30),
		UDim2.fromOffset(48, 18),
		12,
		Ui.colors.muted
	)
	hint.TextWrapped = true
	-- the top block: the library bar or the two forge slots
	local TOP = if isForge then 150 else 104
	local top = Ui.card(content, UDim2.new(1, -8, 0, TOP - 58), UDim2.fromOffset(4, 52))
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -8, 1, -(TOP + 4))
	list.Position = UDim2.fromOffset(4, TOP)
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

	local gang: any = nil -- the last GangState (the library bar)
	local pair: { number } = {} -- forge: the chosen bag slots
	local refresh: (Types.Profile?) -> ()

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

	local function clear(frame: Instance)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- «Библиотекарь»: the bar a / 4000 and «Забрать награду» [владелец 28.10]
	local function drawLibraryTop()
		clear(top)
		local goal = base.library.goal
		local have = if typeof(gang) == "table" then gang.library or 0 else 0
		local bar =
			Kit.bar(top, UDim2.new(1, -20, 0, 14), UDim2.fromOffset(10, 8), Ui.colors.purple)
		bar.set(have / goal)
		local text = Ui.label(
			top,
			string.format("%s / %s", Strings.big(have), Strings.big(goal)),
			UDim2.new(1, -20, 0, 14),
			UDim2.fromOffset(10, 8),
			12,
			Ui.colors.white
		)
		text.TextXAlignment = Enum.TextXAlignment.Center
		local full = have >= goal
		local claim = Ui.button(
			top,
			T("gang_library_claim", base.library.reward.points),
			UDim2.new(1, -20, 0, 18),
			UDim2.fromOffset(10, 26),
			if full then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		claim.Name = "Claim"
		claim.TextSize = 13
		claim.Activated:Connect(function()
			if full then
				Remotes.event("GangNpc"):FireServer("libraryClaim")
			end
		end)
	end

	-- «Кузнец»: two book slots «+», the result «?», the button
	local function drawForgeTop(p: Types.Profile)
		clear(top)
		local function slotAt(
			x: number,
			stack: Types.ItemStack?,
			mark: string,
			onClick: (() -> ())?
		)
			local slot, name, count, icon = Ui.invSlot(top, 56)
			slot.Position = UDim2.fromOffset(x, 8)
			if stack then
				SlotView.render(name, count, icon, stack)
			end
			if not stack or mark == "?" then
				local l =
					Ui.label(slot, mark, UDim2.fromScale(1, 1), UDim2.new(), 26, Ui.colors.muted)
				l.TextXAlignment = Enum.TextXAlignment.Center
				l.Font = Kit.BOLD
			end
			if onClick then
				local hit = Instance.new("TextButton")
				hit.Text = ""
				hit.BackgroundTransparency = 1
				hit.Size = UDim2.fromScale(1, 1)
				hit.Parent = slot
				hit.Activated:Connect(onClick)
			end
		end
		local a, b = p.inventory[pair[1] or 0], p.inventory[pair[2] or 0]
		local cx = (W - 8) / 2
		slotAt(cx - 150, a, "+", function()
			table.remove(pair, 1)
			refresh(profile)
		end)
		local plus = Ui.label(
			top,
			"+",
			UDim2.fromOffset(30, 56),
			UDim2.fromOffset(cx - 90, 8),
			22,
			Ui.colors.muted
		)
		plus.TextXAlignment = Enum.TextXAlignment.Center
		slotAt(cx - 56, b, "+", function()
			table.remove(pair, 2)
			refresh(profile)
		end)
		local arrow = Ui.label(
			top,
			"→",
			UDim2.fromOffset(40, 56),
			UDim2.fromOffset(cx + 6, 8),
			22,
			Ui.colors.muted
		)
		arrow.TextXAlignment = Enum.TextXAlignment.Center
		slotAt(cx + 50, a, "?")
		local ea, la = bookOf(a)
		local eb, lb = bookOf(b)
		local chance, price = nil, nil
		if ea and la and ea == eb and la == lb then
			chance, price = forgeOffer(ea, la)
		end
		local stars = starCount(p)
		local ok = chance ~= nil and price ~= nil and stars >= price
		local text = if not a
				or not b
				or not chance
			then T("gang_forge_pick")
			else T("gang_forge_button") .. " · " .. T(
				"gang_forge_chance",
				math.floor(chance * 100 + 0.5)
			) .. " · " .. T("gang_forge_cost", price :: number)
		local go = Ui.button(
			top,
			text,
			UDim2.new(1, -20, 0, 18),
			UDim2.fromOffset(10, 70),
			if ok then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		go.Name = "Forge"
		go.TextSize = 13
		go.Activated:Connect(function()
			if ok then
				Remotes.event("GangNpc"):FireServer("forge", pair[1], pair[2])
				pair = {}
			end
		end)
	end

	refresh = function(p: Types.Profile?)
		profile = p
		clear(list)
		if not p then
			return
		end
		local slots: { number } = {}
		for slot = 1, 36 do
			if bookOf(p.inventory[slot]) then
				table.insert(slots, slot)
			end
		end
		itemsLabel.Text = T("gang_npc_items", #slots)
		for i = #pair, 1, -1 do
			if not bookOf(p.inventory[pair[i]]) then
				table.remove(pair, i) -- the book left this slot
			end
		end
		if isForge then
			drawForgeTop(p)
		else
			drawLibraryTop()
		end
		if #slots == 0 then
			empty()
			return
		end
		for i, slot in ipairs(slots) do
			local stack = p.inventory[slot] :: Types.ItemStack
			local effect, level = bookOf(stack)
			if not effect or not level then
				continue
			end
			local rarity = stack.rarity or "common"
			if not isForge then
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
			else
				local chosen = table.find(pair, slot) ~= nil
				local card = row(
					i,
					stack,
					ItemInfo.bookName(effect, level, locale),
					"",
					ItemInfo.RARITY_COLORS[rarity]
				)
				actionButton(
					card,
					if chosen then "✔" else "+",
					not chosen and #pair < 2,
					function()
						if not chosen and #pair < 2 then
							table.insert(pair, slot)
							refresh(profile)
						end
					end
				)
			end
		end
	end
	if not isForge then
		local connection = Remotes.event("GangState").OnClientEvent:Connect(function(view: any)
			gang = view
			refresh(profile)
		end)
		win.Destroying:Once(function()
			connection:Disconnect()
		end)
		Remotes.event("GangAction"):FireServer("state")
	end
	refresh(profile)
	return win, refresh
end

return GangNpcWindow
