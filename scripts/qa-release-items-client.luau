--!nocheck
-- Disposable STS client. VirtualInput is preferred; a source-identical clone is a reported fallback.
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "release-items-v1" then
	return
end
local player = game.Players.LocalPlayer
assert(player.UserId < 0, "Refuse real account")
local Run = game.RunService
local Input = game.UserInputService
local startedAt, startupSeconds = os.clock(), 55
local folder, rpc, ready, session, acked
local function progress(phase, detail)
	player:SetAttribute("QAReleaseItemsClientPhase", phase) -- local-console evidence if server never starts
	if detail then
		player:SetAttribute("QAReleaseItemsClientError", detail)
	end
	local info =
		{ session = session, phase = phase, elapsed = os.clock() - startedAt, error = detail }
	if ready then
		ready:FireServer(info)
	end
	if detail then
		warn("[QAReleaseItems startup] " .. game.HttpService:JSONEncode(info))
	end
end
local function need(parent, name)
	progress("waiting_" .. name)
	local found =
		parent:WaitForChild(name, math.max(0.05, startupSeconds - (os.clock() - startedAt)))
	if not found then
		progress("failed", "startup_timeout: " .. parent:GetFullName() .. "." .. name)
		error("QAReleaseItems client startup timeout: " .. name)
	end
	return found
end
task.delay(startupSeconds, function()
	if not acked then
		progress(
			"failed",
			"startup_timeout: client bootstrap/Ready ACK did not finish in 55 seconds"
		)
	end
end)
folder = need(game.ReplicatedStorage, "QAReleaseItems")
rpc = need(folder, "RPC")
ready = need(folder, "Ready")
session = assert(folder:GetAttribute("Session"), "QA session missing")
ready.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" and info.session == session and info.ack == true then
		acked = true
	end
end)
assert(folder:GetAttribute("ListenerReady"), "QA server listener not published")
local function loadModule(module)
	progress("requiring_" .. module.Name)
	local succeeded, value = pcall(require, module)
	if not succeeded then
		progress("failed", "module_error: " .. module.Name .. ": " .. tostring(value))
		error(value)
	end
	return value
end
local R = loadModule(need(need(game.ReplicatedStorage, "Shared"), "Remotes"))
local debugHook = need(player, "ClientDebug")
local client = need(player.PlayerScripts, "Client")
local Sprint = loadModule(need(client, "Sprint"))
local fallback = loadModule(need(player.PlayerScripts, "QAReleaseItemsSpring"))
local virtual, inputError
local ok, result = pcall(function()
	local v = Input:CreateVirtualInput()
	v:SendKey(false, Enum.KeyCode.Space, false)
	return v
end)
if ok then
	virtual = result
else
	inputError = tostring(result)
end
local jumpEvents = 0
Input.JumpRequest:Connect(function()
	jumpEvents += 1
end)
local function state()
	local c = player.Character
	local h, root = c.Humanoid, c.HumanoidRootPart
	local v = root.AssemblyLinearVelocity
	return {
		x = root.Position.X,
		y = root.Position.Y,
		z = root.Position.Z,
		vx = v.X,
		vy = v.Y,
		vz = v.Z,
		horizontal = Vector2.new(v.X, v.Z).Magnitude,
		sprint = c:GetAttribute("Sprinting") == true,
		state = h:GetState().Name,
		floor = h.FloorMaterial.Name,
		height = h.JumpHeight,
		springs = c:GetAttribute("SpringsJumpHeight"),
		speed = h.WalkSpeed,
	}
end
local function release()
	if virtual then
		for _, key in { Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.LeftShift } do
			pcall(function()
				virtual:SendKey(false, key, false)
			end)
		end
	end
	Run:UnbindFromRenderStep("QAReleaseItemsMove")
	if Sprint.isOn() then
		Sprint.toggle()
	end
	if player.Character then
		player.Character.Humanoid:Move(Vector3.zero)
	end
end
local function pose(cf)
	release()
	player.Character:PivotTo(cf)
	player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.6)
end
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
local function jumpTrial(args)
	pose(args.pose)
	debugHook:Invoke("close")
	local c = player.Character
	local h = c.Humanoid
	local timeline, startedAt, mode =
		{}, os.clock(), if virtual then "VirtualInput" else "source-clone"
	if not virtual then
		fallback.qaBind(c)
	end
	local last = 0
	local sampling = Run.PostSimulation:Connect(function()
		if os.clock() - last >= 0.025 then
			last = os.clock()
			local s = state()
			s.at = os.clock() - startedAt
			table.insert(timeline, s)
		end
	end)
	Run:BindToRenderStep("QAReleaseItemsMove", Enum.RenderPriority.Last.Value, function()
		h:Move(Vector3.xAxis)
	end)
	if virtual then
		virtual:SendKey(true, Enum.KeyCode.LeftShift, false)
	else
		if not Sprint.isOn() then
			Sprint.toggle()
		end
	end
	waitFor(function()
		return state().horizontal > 10 and state().sprint
	end, 2)
	local before = state()
	local eventsBefore = jumpEvents
	local function press()
		if virtual then
			virtual:SendKey(true, Enum.KeyCode.Space, false)
		else
			fallback.qaPress()
		end
	end
	local function up()
		if virtual then
			virtual:SendKey(false, Enum.KeyCode.Space, false)
		else
			fallback.qaRelease()
		end
	end
	press()
	if not virtual then
		h.Jump = true
	end
	local airborne = waitFor(function()
		return h.FloorMaterial == Enum.Material.Air and state().vy > 1
	end, 0.3)
	up()
	if not airborne and virtual then
		-- API existence does not prove delivery. Retry the whole trial using the actual-source boundary.
		inputError = "VirtualInput Space did not produce an airborne humanoid; JumpRequest delta="
			.. (jumpEvents - eventsBefore)
		release()
		sampling:Disconnect()
		virtual = nil
		return jumpTrial(args)
	end
	local takeoff = state()
	local beforeSecond, afterSecond, beforeThird, afterThird
	if args.extra then
		task.wait(0.18)
		beforeSecond = state()
		press()
		Run.PostSimulation:Wait()
		afterSecond = state()
		up()
		if args.third then
			task.wait(0.12)
			beforeThird = state()
			-- A grounded press starts a legitimate new jump; never call that an extra-jump rejection.
			if beforeThird.floor == "Air" then
				press()
				Run.PostSimulation:Wait()
				afterThird = state()
				up()
			end
		end
	end
	local landed = waitFor(function()
		return h.FloorMaterial ~= Enum.Material.Air
	end, 3)
	local finish = state()
	release()
	sampling:Disconnect()
	local apex = before.y
	for _, s in timeline do
		apex = math.max(apex, s.y)
	end
	return {
		mode = mode,
		inputError = inputError,
		jumpRequestEvents = jumpEvents - eventsBefore,
		before = before,
		takeoff = takeoff,
		beforeSecond = beforeSecond,
		afterSecond = afterSecond,
		beforeThird = beforeThird,
		afterThird = afterThird,
		finish = finish,
		landed = landed,
		rise = apex - before.y,
		timeline = timeline,
	}
end
local function guiState()
	local buy = player.PlayerGui:FindFirstChild("TutorialUpgrade", true)
	local row = player.PlayerGui:FindFirstChild("UpgradeItems", true)
	if not buy or not row then
		return { exists = false }
	end
	local v = workspace.CurrentCamera.ViewportSize
	local p, size = buy.AbsolutePosition, buy.AbsoluteSize
	local selected
	for _, frame in row:GetChildren() do
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke and stroke.Thickness == 2 then
			selected = math.floor(frame.Position.X.Offset / 52) + 1
		end
	end
	return {
		exists = true,
		visible = buy.Visible,
		enabled = buy.Interactable,
		text = buy.Text,
		scroll = row.CanvasPosition.X,
		selected = selected,
		canvas = row.AbsoluteCanvasSize.X,
		inside = p.X >= 0 and p.Y >= 0 and p.X + size.X <= v.X and p.Y + size.Y <= v.Y,
	}
end
rpc.OnClientInvoke = function(op, args)
	if op == "jump" then
		return jumpTrial(args)
	elseif op == "pose" then
		pose(args)
		return state()
	elseif op == "eat" then
		R.event("EatStart"):FireServer(1)
		return true
	elseif op == "dig" then
		-- Resolve the streamed target by stable mine/index identity; a RemoteFunction Instance
		-- argument may arrive nil when this distant cell has not replicated to the client yet.
		local part, seconds, rejected, acceptedAt
		local toasts, rejectedState = {}, nil
		local available = waitFor(function()
			local mineFolder = workspace:FindFirstChild("Mine_" .. args.mine)
			if mineFolder then
				for _, candidate in mineFolder:GetChildren() do
					if candidate:GetAttribute("Index") == args.index then
						part = candidate
						return true
					end
				end
			end
			return false
		end, 5)
		if not available then
			return {
				accepted = false,
				error = "target_stream_timeout",
				mine = args.mine,
				index = args.index,
			}
		end
		local started = os.clock()
		local connection = R.event("DigAccepted").OnClientEvent
			:Connect(function(acceptedPart, needed)
				if acceptedPart == part then
					seconds = needed
					acceptedAt = os.clock() - started
				end
			end)
		local refusal = R.event("DigRejected").OnClientEvent:Connect(function(rejectedPart)
			if rejectedPart == part then
				rejected = true
				rejectedState = state()
			end
		end)
		local toast = R.event("Toast").OnClientEvent:Connect(function(message)
			table.insert(toasts, tostring(message))
		end)
		R.event("DigStart"):FireServer(part, part.Position + Vector3.new(0, part.Size.Y / 2, 0))
		waitFor(function()
			return rejected or not part.Parent
		end, args.expectedSeconds + 4)
		R.event("DigCancel"):FireServer()
		connection:Disconnect()
		refusal:Disconnect()
		toast:Disconnect()
		return {
			accepted = seconds ~= nil,
			seconds = seconds,
			acceptedAt = acceptedAt,
			elapsed = os.clock() - started,
			rejected = rejected == true,
			clientRemoved = not part.Parent,
			toasts = toasts,
			rejectedState = rejectedState,
		}
	elseif op == "upgradeOpen" then
		debugHook:Invoke("open", "upgrade")
		task.wait(0.6) -- allow the normal tutorial-guide window observer and layout to settle
		local row = player.PlayerGui:FindFirstChild("UpgradeItems", true)
		assert(row, "Upgrade row absent")
		row.CanvasPosition = Vector2.new(320, 0)
		Run.RenderStepped:Wait()
		return guiState()
	elseif op == "upgradeBuy" then
		local buy = player.PlayerGui:FindFirstChild("TutorialUpgrade", true)
		assert(buy and buy.Visible and buy.Interactable, "Primary upgrade action unavailable")
		if virtual then
			local logicalPoint = buy.AbsolutePosition + buy.AbsoluteSize / 2
			local inset = game.GuiService:GetGuiInset()
			local mode = args and args.offset or "inset"
			local point = logicalPoint + (if mode == "inset" then inset else Vector2.zero)
			local trace = {
				mode = "VirtualInput",
				offset = mode,
				point = { x = point.X, y = point.Y },
				logicalPoint = { x = logicalPoint.X, y = logicalPoint.Y },
				inset = { x = inset.X, y = inset.Y },
				hits = {},
				inputEvents = {},
				activated = false,
			}
			for index, hit in
				player.PlayerGui:GetGuiObjectsAtPosition(logicalPoint.X, logicalPoint.Y)
			do
				if index > 8 then
					break
				end
				table.insert(trace.hits, { path = hit:GetFullName(), active = hit.Active })
			end
			local listeners = {}
			local function listen(signal, name)
				table.insert(
					listeners,
					signal:Connect(function(event, processed)
						if event.UserInputType == Enum.UserInputType.MouseButton1 then
							table.insert(trace.inputEvents, {
								name = name,
								processed = processed == true,
								x = event.Position.X,
								y = event.Position.Y,
							})
						end
					end)
				)
			end
			listen(Input.InputBegan, "UIS.InputBegan")
			listen(Input.InputEnded, "UIS.InputEnded")
			listen(buy.InputBegan, "target.InputBegan")
			listen(buy.InputEnded, "target.InputEnded")
			table.insert(
				listeners,
				buy.Activated:Connect(function()
					trace.activated = true
				end)
			)
			local succeeded, err = pcall(function()
				virtual:SendMousePosition(point)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
				task.wait(0.1)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
				task.wait(0.3)
			end)
			for _, connection in listeners do
				connection:Disconnect()
			end
			trace.error = if not succeeded then tostring(err) else nil
			return trace
		end
		R.event("UpgradeItem"):FireServer(12)
		return {
			mode = "remote-fallback",
			limitation = "GUI selection/click not driven; remote target12 explicit",
		}
	elseif op == "upgradeState" then
		return guiState()
	elseif op == "stop" then
		release()
		debugHook:Invoke("close")
		return true
	end
end
-- QA_READY_CLIENT_BEGIN: exercised verbatim by qa-release-items-harness-offline.luau.
local function announceReady()
	local attempts = 0
	repeat
		attempts += 1
		ready:FireServer({
			session = session,
			phase = "ready",
			attempt = attempts,
			elapsed = os.clock() - startedAt,
			virtualInput = virtual ~= nil,
			inputError = inputError,
		})
		if not acked then
			task.wait(0.5)
		end
	until acked or os.clock() - startedAt >= startupSeconds
	if not acked then
		progress("failed", "startup_timeout: no Ready ACK after " .. attempts .. " attempts")
		return false
	end
	return true
end
-- QA_READY_CLIENT_END
task.spawn(function()
	progress("waiting_LoadingBlocked")
	if
		not waitFor(function()
			return player:GetAttribute("LoadingBlocked") == false
		end, math.max(0, startupSeconds - (os.clock() - startedAt)))
	then
		progress("failed", "startup_timeout: LoadingBlocked never cleared")
		return
	end
	announceReady()
end)
