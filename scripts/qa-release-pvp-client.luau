--!nocheck
-- Disposable StudioTestService client. No owner accounts or real stores.
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "release-pvp-v1" then
	return
end
local player = game.Players.LocalPlayer
local R = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local folder = game.ReplicatedStorage:WaitForChild("QAReleasePvp")
local rpc = folder:WaitForChild("RPC")
local events, beforePosition = {}, nil
local function log(kind, data)
	table.insert(events, { kind = kind, at = os.clock(), data = data })
end
player:WaitForChild("ClientDebug")
local client = player.PlayerScripts:WaitForChild("Client")
local feedbackModule = client:FindFirstChild("HurtFeedback")
if feedbackModule then
	local feedback = require(feedbackModule)
	feedback.Impact:Connect(function(packet)
		local h = player.Character.Humanoid
		local shown = feedback.Health(h)
		local velocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
		log(
			"applied",
			{ id = packet.id, health = shown, vx = velocity.X, vy = velocity.Y, vz = velocity.Z }
		)
	end)
end
local Sfx = require(game.ReplicatedStorage.Shared.Sfx)
local originalPlay = Sfx.play
Sfx.play = function(name, ...)
	if name == "player_hurt" then
		log("localHurtSound", name)
	end
	return originalPlay(name, ...)
end
R.event("HitConfirm").OnClientEvent:Connect(function(_, amount, critical, result)
	log("hit", { amount = amount, critical = critical, result = result })
end)
R.event("Knockback").OnClientEvent:Connect(function(v)
	log("push", { x = v.X, y = v.Y, z = v.Z })
end)
R.event("Sfx").OnClientEvent:Connect(function(name)
	log("sound", name)
end)
local impact = game.ReplicatedStorage.Remotes:FindFirstChild("HurtImpact")
if impact then
	impact.OnClientEvent:Connect(function(packet)
		log("impact", {
			id = packet.id,
			health = packet.health,
			damage = packet.damage,
			absorbed = packet.absorbed,
		})
	end)
end
local function watch(character)
	character:WaitForChild("Humanoid").HealthChanged:Connect(function(h)
		log("health", h)
	end)
end
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
rpc.OnClientInvoke = function(op, a, b)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if op == "reset" then
		game.RunService:UnbindFromRenderStep("QAReleaseMove")
		game.RunService:UnbindFromRenderStep("QAReleaseAim")
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		events = {}
		beforePosition = root.Position
		humanoid:Move(Vector3.zero)
		R.event("Sprint"):FireServer(false)
		return true
	elseif op == "pose" then
		character:PivotTo(a)
		root.AssemblyLinearVelocity = Vector3.zero
		humanoid:Move(Vector3.zero)
		return true
	elseif op == "move" then
		R.event("Sprint"):FireServer(a.sprint == true)
		humanoid:Move(a.direction)
		game.RunService:BindToRenderStep("QAReleaseMove", Enum.RenderPriority.Last.Value, function()
			humanoid:Move(a.direction)
		end)
		if a.jump then
			humanoid.Jump = true
		end
		return true
	elseif op == "fall" then
		character:PivotTo(a)
		root.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		return true
	elseif op == "nativeAttack" then
		local debugApi = player.ClientDebug
		debugApi:Invoke("close")
		if not debugApi:Invoke("state").firstPerson then
			debugApi:Invoke("toggleCamera")
		end
		local target = game.Players:GetPlayerByUserId(a).Character
		local camera = workspace.CurrentCamera
		game.RunService:BindToRenderStep("QAReleaseAim", Enum.RenderPriority.Last.Value, function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(character.Head.Position, target.Head.Position)
		end)
		task.wait(0.25)
		local input = game.UserInputService:CreateVirtualInput()
		local point = camera.ViewportSize / 2
		local before = debugApi:Invoke("attackState").lastAt
		input:SendMousePosition(point)
		input:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
		task.wait(0.06)
		input:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
		local advanced = debugApi:Invoke("attackState").lastAt > before
		log(
			"nativeMouse",
			{ advanced = advanced, firstPerson = debugApi:Invoke("state").firstPerson }
		)
		return advanced
	elseif op == "attack" or op == "jumpAttack" then
		if op == "jumpAttack" then
			humanoid.Jump = true
			local untilAt = os.clock() + 2
			repeat
				game.RunService.Heartbeat:Wait()
			until root.AssemblyLinearVelocity.Y > 0.5 or os.clock() > untilAt
			humanoid.Jump = false
			repeat
				game.RunService.Heartbeat:Wait()
			until root.AssemblyLinearVelocity.Y < -0.5 or os.clock() > untilAt
			assert(os.clock() <= untilAt, "real jump did not enter descent")
		end
		local target = game.Players:GetPlayerByUserId(a).Character
		log("intent", {
			falling = root.AssemblyLinearVelocity.Y < -0.5,
			vy = root.AssemblyLinearVelocity.Y,
			y = root.Position.Y,
			state = humanoid:GetState().Name,
		})
		R.event("Attack"):FireServer(
			(target.HumanoidRootPart.Position - character.Head.Position).Unit,
			root.AssemblyLinearVelocity.Y < -0.5,
			target,
			workspace:GetServerTimeNow()
		)
		return true
	elseif op == "state" then
		return {
			events = events,
			health = humanoid.Health,
			x = root.Position.X,
			y = root.Position.Y,
			z = root.Position.Z,
			displacement = beforePosition and (root.Position - beforePosition).Magnitude or 0,
			vx = root.AssemblyLinearVelocity.X,
			vy = root.AssemblyLinearVelocity.Y,
			vz = root.AssemblyLinearVelocity.Z,
		}
	end
end
while player:GetAttribute("LoadingBlocked") ~= false do
	task.wait(0.1)
end
repeat
	folder.Ready:FireServer()
	task.wait(0.5)
until folder:GetAttribute("Ready_" .. tostring(player.UserId)) == true
