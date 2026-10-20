--!strict
-- Client: digging input (hold on PC / touch button / gamepad), target highlight with progress,
-- HUD (right stats panel, hotkeys), hotbar, inventory [E], shop/sell/food windows (prompts),
-- upgrade [J], level [U], jobs [O]. Everything is confirmed by the server via ProfileUpdated/Toast.

local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Ui)

local player = Players.LocalPlayer
local locale = Strings.localeOf(player)
local camera = workspace.CurrentCamera
local T = function(key: string, ...: any)
	return Strings.t(key, locale, ...)
end

local profile: Types.Profile? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "PrisonHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------- HUD: stats panel (right), hints, toast, combo
local stats = Ui.panel(gui, UDim2.fromOffset(190, 96), UDim2.new(1, -200, 0.42, 0))
Ui.label(stats, "PRISON", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 2), 13, Ui.colors.header)
local statLevel = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 20), 14)
local statMoney = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 38), 14)
local statBlocks = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 56), 14)
local statRats = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 74), 14)

local hints = Ui.label(
	gui,
	T("keys_hint"),
	UDim2.fromOffset(520, 18),
	UDim2.new(1, -530, 1, -120),
	13,
	Ui.colors.muted
)
hints.TextXAlignment = Enum.TextXAlignment.Right

local toast = Ui.panel(gui, UDim2.fromOffset(360, 34), UDim2.new(1, -370, 0, 12))
local toastText =
	Ui.label(toast, "", UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 14, Ui.colors.header)
toast.Visible = false
local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toast.Visible = true
	task.delay(3, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local combo =
	Ui.label(gui, "", UDim2.fromOffset(200, 18), UDim2.new(0.5, 120, 1, -112), 13, Ui.colors.muted)

-- ---------------------------------------------------------------- hotbar
local SLOT = 44
local hotbar = Ui.panel(
	gui,
	UDim2.fromOffset(9 * (SLOT + 4) + 8, SLOT + 12),
	UDim2.new(0.5, -(9 * (SLOT + 4) + 8) / 2, 1, -SLOT - 20)
)
local hotbarSlots: { Frame } = {}
local hotbarNames: { TextLabel } = {}
local hotbarCounts: { TextLabel } = {}
for i = 1, 9 do
	local f, name, count = Ui.slot(hotbar, SLOT)
	f.Position = UDim2.fromOffset(6 + (i - 1) * (SLOT + 4), 6)
	hotbarSlots[i], hotbarNames[i], hotbarCounts[i] = f, name, count
end

local function stackLabel(stack: Types.ItemStack?): (string, string)
	if not stack then
		return "", ""
	end
	local name = Strings.itemName(stack.id, stack.level, locale)
	if stack.level then
		name ..= " " .. tostring(stack.level)
	end
	return name, if stack.count > 1 then tostring(stack.count) else ""
end

local function renderHotbar()
	if not profile then
		return
	end
	for i = 1, 9 do
		local n, c = stackLabel(profile.inventory[i])
		hotbarNames[i].Text = n
		hotbarCounts[i].Text = c
		local s = hotbarSlots[i]:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = if profile.selectedSlot == i then Ui.colors.slotSelected else Ui.colors.border
			s.Thickness = if profile.selectedSlot == i then 2 else 1
		end
	end
end

local function selectSlot(n: number)
	if profile and profile.selectedSlot ~= n then
		profile.selectedSlot = n
		renderHotbar()
		Remotes.event("SelectSlot"):FireServer(n)
	end
end

-- ---------------------------------------------------------------- windows
local openWindow: Frame? = nil
local function closeWindow()
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
end

-- Inventory [E]: 27 slots + hotbar row + armor; click-to-move.
local picked: number? = nil
local function buildInventory(): Frame
	local win, content = Ui.window(
		gui,
		T("inventory"),
		UDim2.fromOffset(9 * (SLOT + 4) + 160, 5 * (SLOT + 4) + 70),
		closeWindow
	)
	local function slotAt(index: number, x: number, y: number)
		local f, name, count = Ui.slot(content, SLOT)
		f.Position = UDim2.fromOffset(x, y)
		local n, c = stackLabel(if profile then profile.inventory[index] else nil)
		name.Text, count.Text = n, c
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromScale(1, 1)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Parent = f
		btn.Activated:Connect(function()
			if picked == nil then
				if profile and profile.inventory[index] then
					picked = index
					local s = f:FindFirstChildOfClass("UIStroke")
					if s then
						s.Color = Ui.colors.slotSelected
					end
				end
			else
				Remotes.event("InventoryMove"):FireServer(picked, index)
				picked = nil
			end
		end)
	end
	for r = 0, 2 do
		for c = 0, 8 do
			slotAt(10 + r * 9 + c, c * (SLOT + 4), r * (SLOT + 4))
		end
	end
	for c = 0, 8 do
		slotAt(c + 1, c * (SLOT + 4), 3 * (SLOT + 4) + 10)
	end
	local y = 0
	for _, part in ipairs({ "helmet", "chestplate", "leggings", "boots" }) do
		local f, name = Ui.slot(content, SLOT)
		f.Position = UDim2.fromOffset(9 * (SLOT + 4) + 12, y)
		local armor = if profile then profile.armor[part] else nil
		name.Text = if armor
			then Strings.itemName(part, armor.level, locale)
			else T("item_" .. part)
		name.TextColor3 = if armor then Ui.colors.text else Ui.colors.muted
		y += SLOT + 4
	end
	local equip = Ui.button(
		content,
		"⤒",
		UDim2.fromOffset(SLOT, 24),
		UDim2.fromOffset(9 * (SLOT + 4) + 12, y + 4),
		Ui.colors.buttonGrey
	)
	equip.Activated:Connect(function()
		if picked then
			Remotes.event("EquipArmor"):FireServer(picked)
			picked = nil
		end
	end)
	return win
end

-- Sell window: list of blocks in bag with prices, "sell all".
local function buildSell(): Frame
	local win, content = Ui.window(gui, T("sell_prompt"), UDim2.fromOffset(360, 320), closeWindow)
	local y = 0
	local totals: { [string]: number } = {}
	if profile then
		for _, stack in pairs(profile.inventory) do
			if Config.block(stack.id) then
				totals[stack.id] = (totals[stack.id] or 0) + stack.count
			end
		end
	end
	local mult = if profile
		then 1 + profile.professions.upgrades.money * Config.professions.upgrades.money
		else 1
	local sum = 0
	for id, n in pairs(totals) do
		local block = Config.block(id) :: Config.Block
		local value = math.floor(block.basePrice * Config.moneyScale * mult * n + 0.5)
		sum += value
		Ui.label(
			content,
			string.format("%s ×%d", block.name, n),
			UDim2.new(0.6, 0, 0, 20),
			UDim2.fromOffset(4, y),
			14
		)
		Ui.label(
			content,
			Strings.money(value) .. " $",
			UDim2.new(0.4, -8, 0, 20),
			UDim2.new(0.6, 0, 0, y),
			14,
			Ui.colors.money
		)
		y += 20
	end
	Ui.label(
		content,
		string.format("×%.2f", mult),
		UDim2.new(1, 0, 0, 20),
		UDim2.new(0, 4, 1, -56),
		13,
		Ui.colors.muted
	)
	local btn = Ui.button(
		content,
		T("sell_all") .. "  " .. Strings.money(sum) .. " $",
		UDim2.new(1, -8, 0, 30),
		UDim2.new(0, 4, 1, -32),
		Ui.colors.buttonGreen
	)
	btn.Activated:Connect(function()
		Remotes.event("Sell"):FireServer()
		closeWindow()
	end)
	return win
end

local function buildShop(kind: string): Frame
	type ShopItem = { id: string, price: number }
	local items: { ShopItem } = if kind == "food"
		then {
			{ id = "apple", price = 0.03 },
			{ id = "bread", price = 0.25 },
			{ id = "cooked_chicken", price = 0.5 },
		}
		else {
			{ id = "axe", price = 4 },
			{ id = "pickaxe", price = 22.5 },
			{ id = "shears", price = 4000 },
			{ id = "shovel", price = 4 },
		}
	local win, content = Ui.window(
		gui,
		T(if kind == "food" then "food_prompt" else "shop_prompt"),
		UDim2.fromOffset(#items * 120 + 40, 180),
		closeWindow
	)
	for i, item in ipairs(items) do
		local card =
			Ui.panel(content, UDim2.fromOffset(110, 120), UDim2.fromOffset((i - 1) * 120 + 4, 4))
		local name = Ui.label(
			card,
			Strings.itemName(item.id, 1, locale),
			UDim2.new(1, -8, 0, 40),
			UDim2.fromOffset(4, 4),
			13
		)
		name.TextWrapped = true
		Ui.label(
			card,
			Strings.money(item.price * Config.moneyScale) .. " $",
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(4, 60),
			14,
			Ui.colors.money
		)
		local btn = Ui.button(
			card,
			T("buy"),
			UDim2.new(1, -8, 0, 26),
			UDim2.new(0, 4, 1, -30),
			Ui.colors.buttonGreen
		)
		btn.Activated:Connect(function()
			Remotes.event("BuyItem"):FireServer(item.id)
		end)
	end
	return win
end

-- Upgrade [J]: every owned tool/armor with next upgrade cost and requirements.
local function buildUpgrade(): Frame
	local win, content = Ui.window(gui, T("upgrade"), UDim2.fromOffset(520, 360), closeWindow)
	local y = 0
	if profile then
		local owned: { { id: string, level: number } } = {}
		local seen: { [string]: boolean } = {}
		for _, stack in pairs(profile.inventory) do
			if Config.tools[stack.id] and not seen[stack.id] then
				seen[stack.id] = true
				table.insert(owned, { id = stack.id, level = stack.level or 1 })
			end
		end
		for id, stack in pairs(profile.armor) do
			if not seen[id] then
				table.insert(owned, { id = id, level = stack.level or 1 })
			end
		end
		for _, item in ipairs(owned) do
			local up = Config.upgrade(item.id, item.level)
			Ui.label(
				content,
				Strings.itemName(item.id, item.level, locale) .. "  " .. tostring(item.level),
				UDim2.new(0.45, 0, 0, 24),
				UDim2.fromOffset(4, y),
				14
			)
			if up then
				local req = {}
				for counter, needed in pairs(up.requirements) do
					table.insert(
						req,
						string.format(
							"%s %s/%s",
							counter,
							Strings.big(profile.counters[counter] or 0),
							Strings.big(needed)
						)
					)
				end
				Ui.label(
					content,
					string.format(
						"→ %d: %s $  %s",
						up.to,
						Strings.big(up.cost),
						table.concat(req, " ")
					),
					UDim2.new(0.45, 0, 0, 24),
					UDim2.new(0.45, 0, 0, y),
					12,
					Ui.colors.muted
				)
				local btn =
					Ui.button(content, "↑", UDim2.fromOffset(40, 22), UDim2.new(1, -44, 0, y + 1))
				local id = item.id
				btn.Activated:Connect(function()
					Remotes.event("UpgradeItem"):FireServer(id)
				end)
			else
				Ui.label(
					content,
					T("upgrade_max"),
					UDim2.new(0.5, 0, 0, 24),
					UDim2.new(0.45, 0, 0, y),
					12,
					Ui.colors.muted
				)
			end
			y += 28
		end
	end
	return win
end

-- Level [U]
local function buildLevel(): Frame
	local win, content = Ui.window(gui, T("level_up"), UDim2.fromOffset(360, 180), closeWindow)
	if profile then
		local rule = Config.levelRule(profile.level + 1)
		Ui.label(
			content,
			T("level")
				.. " "
				.. tostring(profile.level)
				.. (if rule then " → " .. tostring(rule.level) else ""),
			UDim2.new(1, -8, 0, 24),
			UDim2.fromOffset(4, 0),
			16,
			Ui.colors.level
		)
		if rule then
			Ui.label(
				content,
				T("level_need_blocks", Strings.big(profile.blocksTotal), Strings.big(rule.blocks)),
				UDim2.new(1, -8, 0, 22),
				UDim2.fromOffset(4, 30),
				14,
				if profile.blocksTotal >= rule.blocks then Ui.colors.money else Ui.colors.text
			)
			Ui.label(
				content,
				T("level_need_money", Strings.money(profile.coins), Strings.big(rule.money)),
				UDim2.new(1, -8, 0, 22),
				UDim2.fromOffset(4, 54),
				14,
				if profile.coins >= rule.money * Config.moneyScale
					then Ui.colors.money
					else Ui.colors.text
			)
			local btn =
				Ui.button(content, T("level_up"), UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 1, -32))
			btn.Activated:Connect(function()
				Remotes.event("LevelUp"):FireServer()
			end)
		else
			Ui.label(content, T("level_max"), UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 30), 14)
		end
	end
	return win
end

-- Jobs [O]: three professions + three boosters, spend points.
local function buildJobs(): Frame
	local win, content = Ui.window(gui, T("jobs"), UDim2.fromOffset(560, 300), closeWindow)
	if profile then
		local pro = profile.professions
		local jobs = { "mason", "surveyor", "blademaster" }
		for i, job in ipairs(jobs) do
			local card = Ui.panel(
				content,
				UDim2.fromOffset(176, 110),
				UDim2.fromOffset((i - 1) * 184 + 4, 4)
			)
			Ui.label(
				card,
				T("job_" .. job),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 4),
				14,
				Ui.colors.header
			)
			Ui.label(
				card,
				T("level")
					.. " "
					.. tostring(pro.level[job] or 0)
					.. " / "
					.. tostring(Config.professions.levels),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 28),
				13
			)
			local base = Config.professions.xpThresholds.base[job] or 100
			local need = math.floor(base * 1.6 ^ (pro.level[job] or 0))
			Ui.label(
				card,
				string.format("XP %s / %s", Strings.big(pro.xp[job] or 0), Strings.big(need)),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 50),
				13,
				Ui.colors.money
			)
		end
		Ui.label(
			content,
			T("claim_points", pro.points),
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(4, 124),
			14,
			Ui.colors.level
		)
		local kinds = { "blocks", "money", "mobs" }
		for i, kind in ipairs(kinds) do
			local card = Ui.panel(
				content,
				UDim2.fromOffset(176, 96),
				UDim2.fromOffset((i - 1) * 184 + 4, 150)
			)
			Ui.label(
				card,
				T("booster_" .. kind),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 4),
				14,
				Ui.colors.header
			)
			local lvl = (pro.upgrades :: any)[kind] :: number
			Ui.label(
				card,
				string.format(
					"%d / %d   ×%.2f",
					lvl,
					Config.professions.upgrades.maxLevel,
					1 + lvl * 0.01
				),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 28),
				13
			)
			local btn = Ui.button(
				card,
				"+1",
				UDim2.new(1, -8, 0, 26),
				UDim2.new(0, 4, 1, -30),
				if pro.points > 0 then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			)
			btn.Activated:Connect(function()
				Remotes.event("SpendPoint"):FireServer(kind)
			end)
		end
	end
	return win
end

local windowBuilders: { [string]: () -> Frame } = {
	inventory = buildInventory,
	sell = buildSell,
	shop = function()
		return buildShop("shop")
	end,
	food = function()
		return buildShop("food")
	end,
	upgrade = buildUpgrade,
	level = buildLevel,
	jobs = buildJobs,
}
local currentWindowKind: string? = nil
local function open(kind: string)
	if currentWindowKind == kind then
		closeWindow()
		currentWindowKind = nil
		return
	end
	closeWindow()
	currentWindowKind = kind
	openWindow = windowBuilders[kind]()
end
local function refreshWindow()
	if currentWindowKind and openWindow then
		local kind = currentWindowKind
		openWindow:Destroy()
		openWindow = windowBuilders[kind]()
	end
end

-- ---------------------------------------------------------------- profile rendering
local function render(p: Types.Profile)
	profile = p
	statLevel.Text = string.format("%s  %d", T("level"), p.level)
	statLevel.TextColor3 = Ui.colors.level
	statMoney.Text = string.format("%s  %s $", T("coins"), Strings.money(p.coins))
	statMoney.TextColor3 = Ui.colors.money
	statBlocks.Text = string.format("%s  %s", T("blocks"), Strings.big(p.blocksTotal))
	statRats.Text = string.format("%s  %d", T("rats"), p.stats.rats or 0)
	renderHotbar()
	refreshWindow()
end
Remotes.event("ProfileUpdated").OnClientEvent:Connect(render)
Remotes.event("Toast").OnClientEvent:Connect(showToast)
Remotes.event("OpenMenu").OnClientEvent:Connect(function(kind: string)
	closeWindow()
	currentWindowKind = kind
	openWindow = windowBuilders[kind]()
end)
Remotes.event("Combo").OnClientEvent:Connect(function(mult: number, n: number)
	combo.Text =
		string.format("Комбо ×%.1f   %d/%d", mult, n, Config.rules.combo.blocksPerStep)
end)

-- ---------------------------------------------------------------- digging
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.7
highlight.OutlineColor = Color3.fromRGB(255, 220, 80)
highlight.Enabled = false
highlight.Parent = gui
local progress = Ui.panel(gui, UDim2.fromOffset(160, 10), UDim2.new(0.5, -80, 0.5, 40))
local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Ui.colors.header
progressFill.BorderSizePixel = 0
progressFill.Parent = progress
progress.Visible = false

local MAX_TARGET = 14
local function targetUnderCursor(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local ray: Ray
	if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 100, params)
	if not hit or not CollectionService:HasTag(hit.Instance, "MineBlock") then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		root
		and root:IsA("BasePart")
		and (root.Position - hit.Instance.Position).Magnitude > MAX_TARGET
	then
		return nil
	end
	return hit.Instance :: BasePart
end

local digging = false
local holding = false
local digTarget: BasePart? = nil
local digStarted = 0
local digNeeded = 0

local function expectedTime(part: BasePart): number?
	if not profile then
		return nil
	end
	local id = part:GetAttribute("Block")
	local block = if typeof(id) == "string" then Config.block(id) else nil
	if not block then
		return nil
	end
	local stack = profile.inventory[profile.selectedSlot]
	local toolId = if stack and Config.tools[stack.id] then stack.id else nil
	local level = if stack and stack.level then stack.level else 0
	return Config.breakTime(block, toolId, level)
end

local function stopDig()
	digging = false
	digTarget = nil
	progress.Visible = false
end

RunService.RenderStepped:Connect(function()
	local target = targetUnderCursor()
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	if digging then
		if target ~= digTarget then
			stopDig()
			if target then
				local needed = expectedTime(target)
				if needed then
					digging, digTarget, digStarted, digNeeded = true, target, os.clock(), needed
					Remotes.event("DigStart"):FireServer(target)
				end
			end
		elseif digTarget then
			local k = math.clamp((os.clock() - digStarted) / digNeeded, 0, 1)
			progress.Visible = true
			progressFill.Size = UDim2.fromScale(k, 1)
			if k >= 1 then
				Remotes.event("DigFinish"):FireServer(digTarget)
				local t = digTarget
				stopDig()
				-- keep digging the next block under the cursor while the button is held
				task.delay(0.05, function()
					if holding and targetUnderCursor() ~= t then
						digging = true
					end
				end)
			end
		end
	end
end)

local function onDig(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		holding = true
		local target = targetUnderCursor()
		local needed = if target then expectedTime(target) else nil
		if target and needed then
			digging, digTarget, digStarted, digNeeded = true, target, os.clock(), needed
			Remotes.event("DigStart"):FireServer(target)
		elseif target then
			Remotes.event("DigStart"):FireServer(target) -- server replies with the reason
		end
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false
		stopDig()
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction(
	"Dig",
	onDig,
	true,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2
)
ContextActionService:SetTitle("Dig", "⛏")
ContextActionService:SetPosition("Dig", UDim2.fromScale(0.72, 0.55))

-- ---------------------------------------------------------------- keys
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.E then
		open("inventory")
	elseif k == Enum.KeyCode.J then
		open("upgrade")
	elseif k == Enum.KeyCode.U then
		open("level")
	elseif k == Enum.KeyCode.O then
		open("jobs")
	elseif k == Enum.KeyCode.Escape then
		closeWindow()
		currentWindowKind = nil
	elseif k.Value >= Enum.KeyCode.One.Value and k.Value <= Enum.KeyCode.Nine.Value then
		selectSlot(k.Value - Enum.KeyCode.One.Value + 1)
	end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or not profile or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	local n = profile.selectedSlot - math.sign(input.Position.Z)
	selectSlot((n - 1) % 9 + 1)
end)
for i = 1, 9 do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = hotbarSlots[i]
	btn.Activated:Connect(function()
		selectSlot(i)
	end)
end

print(string.format("[coco-prison] client ready (%s)", locale))
