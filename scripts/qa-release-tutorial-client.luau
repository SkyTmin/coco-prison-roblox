--!nocheck
-- Real client UI/remotes only; no calls to Tutorial.dug/sold/upgraded or TutorialService hooks.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-tutorial-v1"
then
	return
end
local player = game.Players.LocalPlayer
assert(player.UserId < 0, "Refuse real account")
local Run, startedAt = game.RunService, os.clock()
local folder, ready, rpc, session, acked
local currentRpcId
local function progress(phase, detail)
	player:SetAttribute("QAReleaseTutorialPhase", phase)
	local info = {
		session = session,
		phase = phase,
		rpcId = currentRpcId,
		error = detail,
		elapsed = os.clock() - startedAt,
	}
	if ready then
		ready:FireServer(info)
	end
	if detail then
		warn("[QAReleaseTutorial] " .. game.HttpService:JSONEncode(info))
	end
end
local function need(parent, name)
	progress("waiting_" .. name)
	local found = parent:WaitForChild(name, math.max(0.05, 55 - (os.clock() - startedAt)))
	if not found then
		progress("failed", "startup_timeout: " .. name)
		error("Missing " .. name)
	end
	return found
end
task.delay(55, function()
	if not acked then
		progress("failed", "startup_timeout: client bootstrap/Ready ACK")
	end
end)
folder = need(game.ReplicatedStorage, "QAReleaseTutorial")
rpc, ready = need(folder, "RPC"), need(folder, "Ready")
session = assert(folder:GetAttribute("Session"))
ready.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" and info.session == session and info.ack then
		acked = true
	end
end)
assert(folder:GetAttribute("ListenerReady"), "Server listener not published")
local R = require(need(need(game.ReplicatedStorage, "Shared"), "Remotes"))
local debugHook = need(player, "ClientDebug")
local virtual, virtualError
do
	local ok, value = pcall(function()
		return game.UserInputService:CreateVirtualInput()
	end)
	if ok then
		virtual = value
	else
		virtualError = tostring(value)
	end
end
local frames = 0
local renderConnection = Run.RenderStepped:Connect(function()
	frames += 1
end)
local savedCamera
local function waitFor(fn, seconds)
	local deadline = os.clock() + seconds
	repeat
		if fn() then
			return true
		end
		Run.Heartbeat:Wait()
	until os.clock() >= deadline
	return fn() and true or false
end
local function vector(v)
	return { x = v.X, y = v.Y, z = v.Z }
end
local function visible(object)
	local current = object
	while current and current ~= player.PlayerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return object ~= nil and current == player.PlayerGui
end
local function find(name)
	return player.PlayerGui:FindFirstChild(name, true)
end
local function inspect(args)
	if args.close or args.marker == "mine" or args.marker == "sell" or args.marker == "case" then
		progress("inspect_close_window")
		debugHook:Invoke("close")
	end
	if args.menu then
		progress("inspect_open_menu")
		debugHook:Invoke("open", "menu")
	end
	progress("inspect_wait_guide")
	local settled = waitFor(function()
		local marker, panel = find("TutorialWorldMarker"), find("FirstSteps")
		if not marker or not panel then
			return false
		end
		local target = marker.Adornee
		if args.phase and marker.Parent:GetAttribute("TutorialPhase") ~= args.phase then
			return false
		end
		if args.control == "menu" then
			local name = marker.Parent:GetAttribute("TutorialTargetControl")
			return name == "MenuButton" or name == "Touch_menu" or name == "TutorialUpgradeShortcut"
		end
		if args.marker == "mine" then
			return marker.Enabled and target and target:GetAttribute("MineId") == "prison"
		end
		if args.marker == "sell" then
			return marker.Enabled and target and game.CollectionService:HasTag(target, "SellPoint")
		end
		if args.marker == "case" then
			return marker.Enabled
				and target
				and game.CollectionService:HasTag(target, "OrdinaryCase")
		end
		if args.menu then
			local tile = find(if args.level then "Tile_level" else "Tile_upgrade")
			return tile and tile:FindFirstChild("TutorialGuideStroke") ~= nil
		end
		return args.marker ~= "none" or not marker.Enabled
	end, 6)
	if not settled then
		local marker = find("TutorialWorldMarker")
		local detail = string.format(
			"expected=%s; phase=%s; target=%s",
			tostring(args.phase or args.control or args.marker or "any"),
			tostring(marker and marker.Parent:GetAttribute("TutorialPhase")),
			tostring(marker and marker.Adornee)
		)
		progress("inspect_guide_timeout", detail)
		error("inspect_guide_timeout: " .. detail)
	end
	progress("inspect_guide_ready")
	task.wait(0.6) -- the real guide observes profile/window state every 0.5 s
	local marker, panel, highlight =
		find("TutorialWorldMarker"), find("FirstSteps"), find("TutorialBlock")
	local target = marker and marker.Adornee
	local camera = workspace.CurrentCamera
	if args.frame and target and camera then
		progress("inspect_frame_target")
		if not savedCamera then
			savedCamera = { type = camera.CameraType, cf = camera.CFrame, focus = camera.Focus }
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(
			target.Position + Vector3.new(12, 18, 24),
			target.Position + Vector3.new(0, 4, 0)
		)
		camera.Focus = CFrame.new(target.Position)
	end
	local framesBefore = frames
	progress("inspect_wait_render")
	local rendered = waitFor(function()
		return frames - framesBefore >= 2
	end, 3)
	assert(rendered, "inspect_render_timeout: fewer than 2 rendered frames")
	progress("inspect_collect_ui")
	local onScreen, projected = false, nil
	if target and camera then
		local point, inside =
			camera:WorldToViewportPoint(target.Position + marker.StudsOffsetWorldSpace)
		onScreen, projected = inside and point.Z > 0, vector(point)
	end
	local strokes, menuHighlighted, levelHighlighted = 0, false, false
	for _, object in player.PlayerGui:GetDescendants() do
		if object.Name == "TutorialGuideStroke" then
			strokes += 1
			if object.Parent.Name == "Tile_upgrade" and visible(object.Parent) then
				menuHighlighted = true
			end
			if object.Parent.Name == "Tile_level" and visible(object.Parent) then
				levelHighlighted = true
			end
		end
	end
	local labels = {}
	if panel then
		for _, object in panel:GetDescendants() do
			if object:IsA("TextLabel") then
				table.insert(labels, object.Text)
			end
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local beam = root and root:FindFirstChild("TutorialPath")
	local pathArrows = workspace:FindFirstChild("TutorialDirectionArrows")
	local mineFacing
	if root and camera then
		for _, anchor in game.CollectionService:GetTagged("MineAnchor") do
			if anchor:GetAttribute("MineId") == "prison" then
				local delta = (anchor.Position - root.Position) * Vector3.new(1, 0, 1)
				if delta.Magnitude > 0.1 then
					mineFacing = camera.CFrame.LookVector:Dot(delta.Unit)
				end
			end
		end
	end
	local uiArrow = find("TutorialUiArrow")
	local caption = marker and marker:FindFirstChildWhichIsA("TextLabel", true)
	return {
		step = marker and marker.Parent:GetAttribute("TutorialStep"),
		phase = marker and marker.Parent:GetAttribute("TutorialPhase"),
		targetControl = marker and marker.Parent:GetAttribute("TutorialTargetControl"),
		uiArrowVisible = uiArrow ~= nil and visible(uiArrow),
		mineFacing = mineFacing,
		beamTexture = beam and beam.Texture,
		groundArrows = pathArrows and pathArrows:GetAttribute("VisibleArrows") or 0,
		groundArrowParts = pathArrows and #pathArrows:GetChildren() or 0,
		requirementsReady = marker and marker.Parent:GetAttribute("TutorialRequirementsReady"),
		pathConnected = player.Character ~= nil and player.Character:FindFirstChild(
			"HumanoidRootPart"
		) ~= nil and player.Character.HumanoidRootPart:FindFirstChild("TutorialPath") ~= nil,
		settled = settled,
		panelExists = panel ~= nil,
		panelVisible = panel ~= nil and visible(panel),
		labels = labels,
		renderedFrames = frames - framesBefore,
		viewport = if camera
			then vector(Vector3.new(camera.ViewportSize.X, camera.ViewportSize.Y, 0))
			else nil,
		guideStrokes = strokes,
		menuUpgradeHighlighted = menuHighlighted,
		menuLevelHighlighted = levelHighlighted,
		marker = {
			caption = caption and caption.Text,
			enabled = marker ~= nil and marker.Enabled and visible(marker),
			path = target and target:GetFullName(),
			inWorkspace = target ~= nil and target:IsDescendantOf(workspace),
			mine = target and target:GetAttribute("MineId"),
			index = target and target:GetAttribute("Index"),
			name = target and target.Name,
			position = target and vector(target.Position),
			sellPoint = target ~= nil and game.CollectionService:HasTag(target, "SellPoint"),
			ordinaryCase = target ~= nil and game.CollectionService:HasTag(target, "OrdinaryCase"),
			onScreen = onScreen,
			projected = projected,
		},
		highlight = {
			enabled = highlight ~= nil and highlight.Enabled,
			sameTarget = highlight ~= nil
				and highlight.Enabled
				and target ~= nil
				and highlight.Adornee == target,
		},
	}
end
local function buttonState(name)
	local button = find(name)
	local camera = workspace.CurrentCamera
	if not button then
		return { exists = false }
	end
	local at, size = button.AbsolutePosition, button.AbsoluteSize
	local view = camera.ViewportSize
	return {
		exists = true,
		visible = visible(button),
		interactable = button.Interactable,
		inside = at.X >= 0 and at.Y >= 0 and at.X + size.X <= view.X and at.Y + size.Y <= view.Y,
		highlighted = button:FindFirstChild("TutorialGuideStroke") ~= nil,
		text = button.Text,
		position = { x = at.X, y = at.Y },
		size = { x = size.X, y = size.Y },
	}
end
local function handleRpc(op, args)
	if op == "inspect" then
		return inspect(args or {})
	elseif op == "select" then
		R.event("SelectSlot"):FireServer(args.slot)
		return { remote = "SelectSlot", slot = args.slot, nativeClickClaimed = false }
	elseif op == "pose" then
		local c = player.Character
		c.Humanoid:Move(Vector3.zero)
		c:PivotTo(args)
		c.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		waitFor(function()
			return c.Humanoid.FloorMaterial ~= Enum.Material.Air
				and c.HumanoidRootPart.AssemblyLinearVelocity.Magnitude < 1
		end, 3)
		task.wait(0.05)
		return {
			position = vector(c.HumanoidRootPart.Position),
			speed = c.HumanoidRootPart.AssemblyLinearVelocity.Magnitude,
			grounded = c.Humanoid.FloorMaterial ~= Enum.Material.Air,
			floor = c.Humanoid.FloorMaterial.Name,
		}
	elseif op == "dig" then
		local part, seconds, rejected
		local found = waitFor(function()
			local mine = workspace:FindFirstChild("Mine_" .. args.mine)
			if mine then
				for _, candidate in mine:GetChildren() do
					if candidate:GetAttribute("Index") == args.index then
						part = candidate
						return true
					end
				end
			end
			return false
		end, 5)
		if not found then
			return { accepted = false, error = "target_stream_timeout" }
		end
		local began = os.clock()
		local accepted = R.event("DigAccepted").OnClientEvent:Connect(function(target, needed)
			if target == part then
				seconds = needed
			end
		end)
		local refusal = R.event("DigRejected").OnClientEvent:Connect(function(target)
			if target == part then
				rejected = true
			end
		end)
		R.event("DigStart"):FireServer(part, part.Position + Vector3.new(0, part.Size.Y / 2, 0))
		waitFor(function()
			return rejected or not part.Parent
		end, args.expectedSeconds + 4)
		R.event("DigCancel"):FireServer()
		accepted:Disconnect()
		refusal:Disconnect()
		return {
			accepted = seconds ~= nil,
			seconds = seconds,
			rejected = rejected == true,
			clientRemoved = not part.Parent,
			elapsed = os.clock() - began,
		}
	elseif op == "sell" then
		debugHook:Invoke("open", "sell")
		task.wait(0.7)
		local ui = buttonState("TutorialSell")
		assert(
			ui.visible and ui.interactable and (not args.expectHighlight or ui.highlighted),
			"Real highlighted SellAll button absent"
		)
		R.event("Sell"):FireServer() -- same ordinary event as SellWindow's SellAll callback
		debugHook:Invoke("close")
		return { mode = "ordinary_remote", remote = "Sell", ui = ui, nativeClickClaimed = false }
	elseif op == "upgrade" then
		debugHook:Invoke("open", "upgrade")
		waitFor(function()
			return buttonState("TutorialUpgrade").interactable
		end, 3)
		task.wait(0.7)
		local item
		for _, candidate in player.PlayerGui:GetDescendants() do
			if
				candidate.Name == "TutorialUpgradeItem"
				and candidate:GetAttribute("TutorialItemTarget")
					== "inv:" .. tostring(args.slot)
			then
				item = candidate
				break
			end
		end
		assert(
			item and item:FindFirstChild("TutorialGuideStroke"),
			"Guide did not point at actual shovel selector"
		)
		assert(virtual, "Native item selection unavailable: " .. tostring(virtualError))
		local marker = find("TutorialWorldMarker")
		local attempts = {}
		for _, inset in { game.GuiService:GetGuiInset(), Vector2.zero } do
			local logicalPoint = item.AbsolutePosition + item.AbsoluteSize / 2
			local point = logicalPoint + inset
			local inputs, activated = 0, 0
			local a = item.InputBegan:Connect(function()
				inputs += 1
			end)
			local b = item.Activated:Connect(function()
				activated += 1
			end)
			local ok, err = pcall(function()
				virtual:SendMousePosition(point)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
				task.wait(0.1)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
			end)
			local selected = waitFor(function()
				return marker.Parent:GetAttribute("TutorialPhase") == "tutorial_buy_upgrade"
			end, 1)
			a:Disconnect()
			b:Disconnect()
			table.insert(attempts, {
				x = point.X,
				y = point.Y,
				logicalX = logicalPoint.X,
				logicalY = logicalPoint.Y,
				insetY = inset.Y,
				inputs = inputs,
				activated = activated,
				success = selected,
				error = if ok then nil else tostring(err),
			})
			if selected then
				break
			end
		end
		local ui = buttonState("TutorialUpgrade")
		assert(
			ui.visible and ui.interactable and ui.highlighted,
			"Real highlighted upgrade button absent"
		)
		R.event("UpgradeItem"):FireServer(args.slot)
		return {
			mode = "ordinary_remote",
			remote = "UpgradeItem",
			slot = args.slot,
			ui = ui,
			itemSelection = attempts,
			nativeClickClaimed = false,
		}
	elseif op == "level" then
		debugHook:Invoke("open", "level")
		assert(
			waitFor(function()
				return buttonState("LevelUp").highlighted
			end, 3),
			"Real LevelUp guide missing"
		)
		local ui = buttonState("LevelUp")
		assert(ui.visible and ui.interactable, "Real LevelUp button unavailable")
		R.event("LevelUp"):FireServer()
		return { mode = "ordinary_remote", remote = "LevelUp", ui = ui, nativeClickClaimed = false }
	elseif op == "stop" then
		debugHook:Invoke("close")
		if savedCamera and workspace.CurrentCamera then
			workspace.CurrentCamera.CameraType = savedCamera.type
			workspace.CurrentCamera.CFrame, workspace.CurrentCamera.Focus =
				savedCamera.cf, savedCamera.focus
		end
		renderConnection:Disconnect()
		return true
	end
	error("unsupported_rpc: " .. tostring(op))
end
rpc.OnClientInvoke = function(op, args, id)
	currentRpcId = id
	progress("rpc_" .. op)
	local ok, result = xpcall(function()
		return handleRpc(op, args)
	end, debug.traceback)
	progress(
		if ok then "rpc_done_" .. op else "rpc_failed_" .. op,
		if ok then nil else tostring(result)
	)
	if not ok then
		error(result, 0)
	end
	return result
end
task.spawn(function()
	progress("waiting_LoadingBlocked")
	if
		not waitFor(function()
			return player:GetAttribute("LoadingBlocked") == false
		end, math.max(0, 55 - (os.clock() - startedAt)))
	then
		progress("failed", "startup_timeout: LoadingBlocked never cleared")
		return
	end
	local attempts = 0
	repeat
		attempts += 1
		ready:FireServer({
			session = session,
			phase = "ready",
			attempt = attempts,
			elapsed = os.clock() - startedAt,
		})
		if not acked then
			task.wait(0.5)
		end
	until acked or os.clock() - startedAt >= 55
	if not acked then
		progress("failed", "startup_timeout: no Ready ACK after " .. attempts .. " attempts")
	end
end)
