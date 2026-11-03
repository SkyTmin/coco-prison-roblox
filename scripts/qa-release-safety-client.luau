--!nocheck
-- STS handshake only. No input injection, teleport, private service hook or readiness bypass.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-safety-v1"
then
	return
end
local player = game.Players.LocalPlayer
assert(player.UserId < 0, "Refuse real account")
local started = os.clock()
local folder = game.ReplicatedStorage:WaitForChild("QAReleaseSafety", 100)
assert(folder, "Safety QA server did not publish handshake")
local ready = folder:WaitForChild("Ready", 5)
assert(ready, "Safety QA handshake missing")
local session, acked = folder:GetAttribute("Session"), false
ready.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" and info.session == session and info.ack then
		acked = true
	end
end)
repeat
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local readyNow = player:GetAttribute("LoadingBlocked") == false
		and workspace:GetAttribute("RuntimeReady") == true
		and player:FindFirstChild("ClientDebug") ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and character:FindFirstChild("HumanoidRootPart") ~= nil
	ready:FireServer({
		session = session,
		phase = if readyNow then "ready" else "loading",
		loadingBlocked = player:GetAttribute("LoadingBlocked"),
		runtimeReady = workspace:GetAttribute("RuntimeReady"),
		physicalInput = false,
		elapsed = os.clock() - started,
	})
	task.wait(0.5)
until acked or os.clock() - started >= 110
