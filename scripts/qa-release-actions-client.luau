--!nocheck
-- Disposable StudioTestService client; install with matching server, args release-actions-v1.
-- Uses normal remotes. Optional VirtualInput clicks are mouse QA, never a touch-acceptance claim.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-actions-v1"
then
	return
end
local player = game.Players.LocalPlayer
assert(player.UserId < 0, "Refuse real account fixture")
local folder = game.ReplicatedStorage:WaitForChild("QAReleaseActions")
local rpc = folder:WaitForChild("RPC")
local remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local action = remotes:WaitForChild("PlayerAction")
local debugApi = player:WaitForChild("ClientDebug")
local function find(name)
	return player.PlayerGui:FindFirstChild(name, true)
end
local function untilTrue(fn, seconds)
	local deadline = os.clock() + (seconds or 5)
	repeat
		local value = fn()
		if value then
			return value
		end
		task.wait(0.05)
	until os.clock() > deadline
	return nil
end
local function measure(win)
	local rows = {}
	for _, object in win:GetDescendants() do
		if object:IsA("GuiButton") and (object.Name:match("^Action") or object.Name == "Close") then
			table.insert(rows, {
				name = object.Name,
				w = object.AbsoluteSize.X,
				h = object.AbsoluteSize.Y,
				scaled = object:IsA("TextButton") and object.TextScaled,
				textSize = object:IsA("TextButton") and object.TextSize,
			})
		end
	end
	return { w = win.AbsoluteSize.X, h = win.AbsoluteSize.Y, rows = rows }
end
local function layoutFixture(profile)
	local client = player.PlayerScripts:WaitForChild("Client")
	local Ui, Layout, Actions =
		require(client.Ui), require(client.ReleaseLayout), require(client.ActionsWindow)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.Enabled, gui.Parent =
		"QAReleaseLayout", true, false, player.PlayerGui
	local results = {}
	for _, size in { Vector2.new(390, 844), Vector2.new(844, 390) } do
		local holder = Instance.new("Frame")
		holder.Size, holder.Parent = UDim2.fromOffset(size.X, size.Y), gui
		local win = Actions.build(holder, profile, "en", function() end, Ui.window)
		local w, h = Layout.window("Window_Actions", size.X, size.Y, 58)
		win.Size, win.AnchorPoint, win.Position =
			UDim2.fromOffset(w, h), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		task.wait(0.15)
		local result = measure(win)
		result.viewport = { x = size.X, y = size.Y }
		result.formHeight = win:FindFirstChild("ActionForm", true).AbsoluteSize.Y
		table.insert(results, result)
		holder:Destroy()
	end
	gui:Destroy()
	return results
end
local function uiPay(payload)
	local ok, input = pcall(function()
		return game.UserInputService:CreateVirtualInput()
	end)
	if not ok or not input then
		return { skipped = true, reason = tostring(input), touchTested = false }
	end
	debugApi:Invoke("open", "actions")
	assert(
		untilTrue(function()
			return find("Window_Actions")
		end),
		"Actions window missing"
	)
	local clicks = {}
	local Ui = require(player.PlayerScripts.Client.Ui)
	local Strings = require(game.ReplicatedStorage.Shared.Strings)
	local function resultState()
		local status = find("ActionResult")
		return {
			text = status and status.Text,
			ok = status ~= nil and status.TextColor3 == Ui.colors.green,
		}
	end
	local function click(name, successor)
		local object = assert(
			untilTrue(function()
				return find(name)
			end),
			name .. " missing"
		)
		local ancestor = object.Parent
		while ancestor and not ancestor:IsA("ScreenGui") do
			if ancestor:IsA("ScrollingFrame") then
				-- Reveal the target through every nested viewport, inner first. Keep an already
				-- visible target stable instead of scrolling its center outside another clip.
				local top = object.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
				local bottom = top + object.AbsoluteSize.Y
				local height = ancestor.AbsoluteWindowSize.Y
				local delta = if top < 0 then top elseif bottom > height then bottom - height else 0
				ancestor.CanvasPosition = Vector2.new(
					ancestor.CanvasPosition.X,
					math.clamp(
						ancestor.CanvasPosition.Y + delta,
						0,
						math.max(0, ancestor.AbsoluteCanvasSize.Y - height)
					)
				)
				task.wait(0.1)
			end
			ancestor = ancestor.Parent
		end
		local view = workspace.CurrentCamera.ViewportSize
		local left, top =
			math.max(0, object.AbsolutePosition.X), math.max(0, object.AbsolutePosition.Y)
		local right = math.min(view.X, object.AbsolutePosition.X + object.AbsoluteSize.X)
		local bottom = math.min(view.Y, object.AbsolutePosition.Y + object.AbsoluteSize.Y)
		local trace =
			{ name = name, inputEvents = {}, clips = {}, hits = {}, activatedObserved = false }
		table.insert(clicks, trace)
		ancestor = object
		while ancestor do
			if ancestor:IsA("GuiObject") then
				assert(ancestor.Visible, name .. " has hidden ancestor " .. ancestor.Name)
				if
					ancestor ~= object
					and (ancestor.ClipsDescendants or ancestor:IsA("ScrollingFrame"))
				then
					local size = if ancestor:IsA("ScrollingFrame")
						then ancestor.AbsoluteWindowSize
						else ancestor.AbsoluteSize
					local p = ancestor.AbsolutePosition
					left, top = math.max(left, p.X), math.max(top, p.Y)
					right, bottom = math.min(right, p.X + size.X), math.min(bottom, p.Y + size.Y)
					table.insert(
						trace.clips,
						{ name = ancestor.Name, x = p.X, y = p.Y, w = size.X, h = size.Y }
					)
				end
			elseif ancestor:IsA("ScreenGui") then
				assert(ancestor.Enabled, name .. " has disabled ScreenGui")
			end
			ancestor = ancestor.Parent
		end
		trace.visibleRect = { left = left, top = top, right = right, bottom = bottom }
		assert(right > left and bottom > top, name .. " is fully clipped")
		assert(object.Interactable, name .. " is not interactable")
		local position = Vector2.new((left + right) / 2, (top + bottom) / 2)
		trace.x, trace.y = position.X, position.Y
		-- Live STS evidence: sending GUI y=278 delivered UIS y=220, exactly minus
		-- GetGuiInset().Y=58. VirtualInput consumes window coordinates; GUI bounds/hit tests
		-- and the observed InputObject.Position use the content coordinates above.
		local inset = game.GuiService:GetGuiInset()
		local inputPosition = position + inset
		trace.inputX, trace.inputY, trace.insetX, trace.insetY =
			inputPosition.X, inputPosition.Y, inset.X, inset.Y
		for index, hit in player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
			if index > 8 then
				break
			end
			table.insert(trace.hits, { path = hit:GetFullName(), active = hit.Active })
		end
		local connections = {}
		local function listen(signal, eventName)
			table.insert(
				connections,
				signal:Connect(function(event, processed)
					if event.UserInputType == Enum.UserInputType.MouseButton1 then
						table.insert(trace.inputEvents, {
							event = eventName,
							processed = processed == true,
							x = event.Position.X,
							y = event.Position.Y,
						})
					end
				end)
			)
		end
		listen(game.UserInputService.InputBegan, "UIS.InputBegan")
		listen(game.UserInputService.InputEnded, "UIS.InputEnded")
		listen(object.InputBegan, "target.InputBegan")
		listen(object.InputEnded, "target.InputEnded")
		table.insert(
			connections,
			object.Activated:Connect(function()
				trace.activatedObserved = true -- diagnostic only: rebuild may destroy this listener first
			end)
		)
		local sent, sendError = pcall(function()
			input:SendMousePosition(inputPosition)
			input:SendMouseButton(inputPosition, Enum.UserInputType.MouseButton1, true, 0)
			task.wait(0.1)
			input:SendMouseButton(inputPosition, Enum.UserInputType.MouseButton1, false, 0)
			trace.successor = untilTrue(function()
				return successor(object)
			end, 8)
		end)
		for _, connection in connections do
			connection:Disconnect()
		end
		if not sent then
			pcall(function()
				input:SendMouseButton(inputPosition, Enum.UserInputType.MouseButton1, false, 0)
			end)
		end
		trace.originalDestroyed = object.Parent == nil
		trace.result = resultState()
		assert(sent, tostring(sendError))
		assert(trace.successor, name .. " did not reach its successor UI state via VirtualInput")
		task.wait(0.15)
	end
	local worked, err = xpcall(function()
		local recipientName = "ActionRecipient_" .. payload.recipient
		click(recipientName, function(original)
			local selected = find(recipientName)
			if
				selected
				and selected ~= original
				and selected.BackgroundColor3 == Ui.colors.buttonBlue
			then
				return { recipientSelected = true, buttonReplaced = true }
			end
			return nil
		end)
		-- Programmatic text entry isolates click/remote behavior; native keyboard is separate acceptance.
		find("ActionAmount").Text = tostring(payload.amount)
		click("ActionReview", function()
			return if find("ActionConfirm") then { confirmationVisible = true } else nil
		end)
		click("ActionConfirm", function()
			local state = resultState()
			local waiting = Strings.t("release_action_wait", player:GetAttribute("Locale") or "ru")
			return if not find("ActionConfirm")
					and state.text
					and state.text ~= ""
					and state.text ~= waiting
				then { confirmationGone = true, result = state }
				else nil
		end)
		assert(
			resultState().ok,
			"Confirmation returned a rejected result: " .. tostring(resultState().text)
		)
	end, debug.traceback)
	local status = find("ActionResult")
	local result = {
		ok = worked,
		error = if worked then nil else tostring(err),
		clicks = clicks,
		text = status and status.Text,
		touchTested = false,
		nativeKeyboardTested = false,
	}
	debugApi:Invoke("close")
	return result
end
rpc.OnClientInvoke = function(op, a, b)
	if op == "action" then
		return action:InvokeServer(a, b)
	elseif op == "command" then
		local Strings = require(game.ReplicatedStorage.Shared.Strings)
		local expected = Strings.t("release_transfer_nearby", player:GetAttribute("Locale") or "ru")
		local answer
		local listener = remotes
			:WaitForChild("ChatSystem").OnClientEvent
			:Connect(function(text, kind)
				if text == expected and kind == "error" then
					answer = { refused = true, text = text }
				end
			end)
		remotes:WaitForChild("ChatCommand"):FireServer(a, b)
		untilTrue(function()
			return answer
		end, 5)
		listener:Disconnect()
		return answer or { refused = false }
	elseif op == "roster" then
		if not find("Window_Actions") then
			debugApi:Invoke("open", "actions")
		end
		local observed = untilTrue(function()
			local win = find("Window_Actions")
			if not win then
				return nil
			end
			local present = win:FindFirstChild("ActionRecipient_" .. tostring(a), true) ~= nil
			return if present == b then { present = present, matched = true } else nil
		end, 5)
		return observed or { matched = false }
	elseif op == "close" then
		debugApi:Invoke("close")
		return true
	elseif op == "pose" then
		player.Character:PivotTo(a)
		return true
	elseif op == "layout" then
		return layoutFixture(a)
	elseif op == "uiPay" then
		return uiPay(a)
	elseif op == "resetDenied" then
		return remotes:WaitForChild("CreativeReset"):InvokeServer("prepare")
	elseif op == "guide" then
		debugApi:Invoke("close")
		task.wait(0.7)
		local panel, marker = find("FirstSteps"), find("TutorialWorldMarker")
		return {
			visible = panel and panel.Visible,
			marker = marker and marker.Enabled,
			target = marker and marker.Adornee and marker.Adornee.Name,
		}
	end
	return nil
end
repeat
	if player:GetAttribute("LoadingBlocked") == false then
		folder.Ready:FireServer()
	end
	task.wait(0.5)
until folder:GetAttribute("Ready_" .. tostring(player.UserId)) == true
