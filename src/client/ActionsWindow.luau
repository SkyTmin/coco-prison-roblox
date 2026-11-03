--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)
local ActionsWindow = {}

function ActionsWindow.build(
	parent: Instance,
	initial: any,
	locale: string,
	onClose: () -> (),
	createWindow: any
)
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	local win, content = createWindow(
		parent,
		t("release_actions"),
		UDim2.fromOffset(
			math.min(560, viewport.X - 24),
			math.min(680, viewport.Y - GuiService:GetGuiInset().Y - 24)
		),
		onClose
	)
	win.Name = "Window_Actions"
	require(script.Parent.ReleaseLayout).header(win, content)
	local profile, kind, recipient, selected = initial, "pay", nil :: number?, nil :: number?
	local quote: any = nil
	local waiting, alive = false, true
	local rebuild: () -> ()
	local tabs = {}
	for index, mode in ipairs({ "pay", "gift" }) do
		local button = Ui.button(
			content,
			t("release_action_" .. mode),
			UDim2.new(0.5, -3, 0, 44),
			UDim2.new((index - 1) * 0.5, (index - 1) * 3, 0, 0),
			Ui.colors.buttonGrey
		)
		button.TextSize, button.TextScaled = 14, false
		button.Name = "ActionMode_" .. mode
		button.Activated:Connect(function()
			if not waiting then
				kind, quote = mode, nil
				rebuild()
			end
		end)
		tabs[mode] = button
	end
	local hide = Ui.button(
		content,
		t("release_action_hide"),
		UDim2.new(0.5, -3, 0, 44),
		UDim2.fromOffset(0, 50),
		Ui.colors.buttonGrey
	)
	local invite = Ui.button(
		content,
		t("invite_friend"),
		UDim2.new(0.5, -3, 0, 44),
		UDim2.new(0.5, 3, 0, 50),
		Ui.colors.buttonBlue
	)
	invite.TextSize, hide.TextSize = 14, 14
	invite.TextScaled, hide.TextScaled = false, false
	invite.Name, hide.Name = "ActionInvite", "ActionHide"
	local status = Ui.label(content, "", UDim2.new(1, 0, 0, 50), UDim2.fromOffset(0, 100), 14)
	status.Name = "ActionResult"
	status.TextWrapped = true
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "ActionForm", 1, 0
	scroll.Position, scroll.Size = UDim2.fromOffset(0, 154), UDim2.new(1, 0, 1, -154)
	scroll.ScrollBarThickness, scroll.AutomaticCanvasSize = 6, Enum.AutomaticSize.Y
	scroll.CanvasSize, scroll.Parent = UDim2.new(), content
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent =
		UDim.new(0, 8), Enum.SortOrder.LayoutOrder, scroll
	local function label(text: string, height: number, order: number)
		local object = Ui.label(scroll, text, UDim2.new(1, -8, 0, height), UDim2.new(), 14)
		object.TextWrapped, object.LayoutOrder = true, order
		return object
	end
	local function button(text: string, order: number, callback: () -> (), color: Color3?)
		local object = Ui.button(
			scroll,
			text,
			UDim2.new(1, -8, 0, 44),
			UDim2.new(),
			color or Ui.colors.buttonGrey
		)
		object.TextSize, object.LayoutOrder, object.TextScaled = 14, order, false
		object.Activated:Connect(function()
			if not waiting then
				callback()
			end
		end)
		return object
	end
	local function result(answer: any)
		status.TextColor3 = if answer and answer.ok then Ui.colors.green else Ui.colors.red
		status.Text = if typeof(answer) == "table" and typeof(answer.key) == "string"
			then t(answer.key, table.unpack(answer.args or {}))
			else t("release_action_failed")
	end
	local function request(action: string, payload: any, done: (any) -> ())
		if waiting then
			return
		end
		waiting = true
		status.TextColor3, status.Text = Ui.colors.muted, t("release_action_wait")
		task.spawn(function()
			local ok, answer = pcall(function()
				return Remotes.func("PlayerAction"):InvokeServer(action, payload)
			end)
			if not alive then
				return
			end
			waiting = false
			done(if ok then answer else nil)
		end)
	end
	hide.Activated:Connect(function()
		request("hide", nil, result)
	end)
	invite.Activated:Connect(function()
		if waiting then
			return
		end
		require(script.Parent.Invite).prompt(function()
			if alive then
				result({ ok = false, key = "invite_unavailable" })
			end
		end)
	end)
	local amountText = "1"
	rebuild = function()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for mode, tab in pairs(tabs) do
			tab.BackgroundColor3 = if mode == kind
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		if quote then
			local text = if quote.kind == "pay"
				then t(
					"release_action_money_review",
					Strings.grouped(quote.amount, 2),
					quote.display,
					quote.name
				)
				else t(
					"release_action_item_review",
					Strings.itemName(quote.stack.id, quote.stack.level, locale),
					quote.count,
					quote.display,
					quote.name
				)
			label(text, 100, 1)
			local confirm = button(t("release_action_confirm"), 2, function()
				local token = quote.token
				request("confirm", token, function(answer)
					quote = nil
					result(answer)
					rebuild()
				end)
			end, Ui.colors.buttonGreen)
			confirm.Name = "ActionConfirm"
			button(t("release_action_cancel"), 3, function()
				quote = nil
				rebuild()
			end)
			return
		end
		if profile and profile.playerTransferGifts and next(profile.playerTransferGifts) then
			button(t("release_transfer_claim"), 0, function()
				request("claim", nil, function(answer)
					result(answer)
					rebuild()
				end)
			end, Ui.colors.buttonGreen).Name =
				"ActionClaim"
		end
		label(t("release_action_recipient"), 32, 1)
		local people = Instance.new("ScrollingFrame")
		people.BackgroundTransparency, people.BorderSizePixel, people.ScrollBarThickness = 1, 0, 5
		people.Size, people.LayoutOrder = UDim2.new(1, -8, 0, 116), 2
		people.CanvasSize, people.AutomaticCanvasSize, people.Parent =
			UDim2.new(), Enum.AutomaticSize.Y, scroll
		local list = Instance.new("UIListLayout")
		list.Padding, list.Parent = UDim.new(0, 4), people
		for _, other in ipairs(Players:GetPlayers()) do
			if other == Players.LocalPlayer then
				continue
			end
			local pick = Ui.button(
				people,
				other.DisplayName .. " (@" .. other.Name .. ")",
				UDim2.new(1, -6, 0, 44),
				UDim2.new(),
				if recipient == other.UserId then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			)
			pick.TextSize, pick.TextScaled = 14, false
			pick.Name = "ActionRecipient_" .. other.UserId
			pick.Activated:Connect(function()
				if not waiting then
					recipient = other.UserId
					rebuild()
				end
			end)
		end
		if kind == "gift" then
			label(t("release_action_item"), 28, 3)
			local items = Instance.new("Frame")
			items.BackgroundTransparency, items.LayoutOrder, items.Size =
				1, 4, UDim2.new(1, -8, 0, 0)
			items.AutomaticSize, items.Parent = Enum.AutomaticSize.Y, scroll
			local grid = Instance.new("UIGridLayout")
			grid.CellSize, grid.CellPadding, grid.Parent =
				UDim2.fromOffset(48, 48), UDim2.fromOffset(4, 4), items
			local count = 0
			for slot = 1, 36 do
				local stack = profile and profile.inventory[slot]
				if
					not stack
					or Config.block(stack.id)
					or table.find(Config.chat.giftForbidden, stack.id)
				then
					continue
				end
				count += 1
				local cell, name, quantity, icon = Ui.invSlot(items, 48)
				name.Visible, quantity.Text = false, tostring(stack.count)
				icon.Image, icon.Visible = Config.iconFor(stack.id, stack.level) or "", true
				require(script.Parent.EnchantmentVisual).slot(icon, stack)
				local pick = Ui.button(
					cell,
					if selected == slot then "✓" else "",
					UDim2.fromScale(1, 1),
					UDim2.new(),
					Ui.colors.buttonBlue
				)
				pick.BackgroundTransparency = if selected == slot then 0.6 else 1
				pick.Name = "ActionItem_" .. slot
				pick.Activated:Connect(function()
					if not waiting then
						selected, amountText = slot, tostring(stack.count)
						rebuild()
					end
				end)
			end
			if count == 0 then
				label(t("release_action_empty"), 40, 5)
			end
			local chosen = profile and selected and profile.inventory[selected]
			if chosen then
				label(Strings.itemName(chosen.id, chosen.level, locale), 36, 5)
			end
		end
		label(t(if kind == "pay" then "release_action_amount" else "release_action_count"), 24, 6)
		local input = Instance.new("TextBox")
		input.Name = "ActionAmount"
		input.Size, input.LayoutOrder, input.Text = UDim2.new(1, -8, 0, 44), 7, amountText
		input.BackgroundColor3, input.TextColor3, input.TextSize =
			Ui.colors.inset, Ui.colors.text, 16
		input.ClearTextOnFocus, input.Parent = false, scroll
		input:GetPropertyChangedSignal("Text"):Connect(function()
			amountText = input.Text
		end)
		local review = button(t("release_action_review"), 8, function()
			local amount = tonumber((amountText:gsub(",", ".")))
			request("quote", {
				kind = kind,
				recipient = recipient,
				slot = selected,
				count = amount,
				amount = amount,
			}, function(answer)
				if answer and answer.ok and answer.token then
					quote = answer
					status.Text = ""
					scroll.CanvasPosition = Vector2.zero
					rebuild()
				else
					result(answer)
				end
			end)
		end, Ui.colors.buttonBlue)
		review.Name = "ActionReview"
	end
	local join = Players.PlayerAdded:Connect(function()
		task.defer(function()
			if alive and not quote and not waiting then
				rebuild()
			end
		end)
	end)
	local leave = Players.PlayerRemoving:Connect(function(other)
		if recipient == other.UserId then
			recipient = nil
		end
		task.defer(function()
			if alive and not quote and not waiting then
				rebuild()
			end
		end)
	end)
	win.Destroying:Connect(function()
		alive = false
		join:Disconnect()
		leave:Disconnect()
	end)
	rebuild()
	return win,
		function(nextProfile: any)
			local hadGifts = profile
				and profile.playerTransferGifts
				and next(profile.playerTransferGifts) ~= nil
			profile = nextProfile
			local hasGifts = profile
				and profile.playerTransferGifts
				and next(profile.playerTransferGifts) ~= nil
			if hadGifts ~= hasGifts and alive and not quote and not waiting then
				rebuild()
			end
		end
end

return ActionsWindow
