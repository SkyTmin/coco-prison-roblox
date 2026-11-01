--!nocheck
-- Studio Server: isolated tall target and synthetic confirmations, no real combat/rewards/profile changes.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local player = game.Players:GetPlayers()[1]
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local model = Instance.new("Model")
model.Name = "QACombatTallTarget"
local root = Instance.new("Part")
root.Name, root.Size = "HumanoidRootPart", Vector3.new(4, 24, 4)
root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
root.Position = player.Character.Head.Position + Vector3.new(0, 40, 6)
root.Parent, model.PrimaryPart = model, root
local humanoid = Instance.new("Humanoid")
humanoid.MaxHealth, humanoid.Health, humanoid.Parent = 100, 100, model
model.Parent = workspace
game:GetService("CollectionService"):AddTag(model, "Mob")
local hurt = require(game.ServerScriptService.Server.Services.HurtService)
task.spawn(function()
	for i = 1, 20 do
		local mode = (i - 1) % 5
		if mode == 0 then
			hurt.Damage(humanoid, 1)
		end
		local status = ({ "hit", "blocked", "hit", "ally", "nopvp" })[mode + 1]
		Remotes.event("HitConfirm")
			:FireClient(player, model, if status == "hit" then 7.5 else 0, mode == 2, status)
		task.wait(0.3)
	end
	-- High fan-out must still be bounded, and a streamed-out target must not hide its numeric verdict.
	for _ = 1, 20 do
		Remotes.event("HitConfirm"):FireClient(player, model, 1, true, "hit")
	end
	Remotes.event("HitConfirm"):FireClient(player, nil, 9, false, "hit")
	task.wait(1)
	model:Destroy()
end)
return model:GetFullName()
