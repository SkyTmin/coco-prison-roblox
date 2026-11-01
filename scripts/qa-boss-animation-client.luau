--!nocheck
-- Play/Client: exercises the real BossAnimator on local rigs, without rewards or live boss state.
-- Leaves a local gallery for screenshots. Destroy workspace.QABossGallery after inspection.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsClient(), "Play/Client only")
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Config = require(Shared.Config)
local CS = game:GetService("CollectionService")
assert(not workspace:FindFirstChild("QABossGallery"), "Remove previous gallery first")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QABossGallery", workspace
local floor = Instance.new("Part")
floor.Name, floor.Size, floor.CFrame = "Floor", Vector3.new(100, 1, 40), CFrame.new(0, 299.5, 0)
floor.Anchored, floor.Color, floor.Material, floor.Parent =
	true, Color3.fromRGB(83, 89, 98), Enum.Material.Slate, folder
local actions = {
	giant_zombie = { "melee", "blade", "spikes", "charge", "stunned", "jump", "roar" },
	basalt_guardian = {
		"melee",
		"sword_slash",
		"sword_smash",
		"sword_spike",
		"stunned",
		"jump",
		"roar",
	},
	splinter = { "melee", "swoop", "potion", "shoot", "summon", "stunned", "jump", "roar" },
	minotaur = {
		"melee",
		"impact",
		"double_attack",
		"throws_the_ground",
		"minotaur_rush",
		"stun",
		"awakening",
		"jump",
		"roar",
	},
}
local rows, checks = {}, {}
_G.QAAnimatedBosses = rows
local result = Instance.new("StringValue")
result.Name, result.Value, result.Parent =
	"QABossAnimationResult", "running", game.Players.LocalPlayer
local function check(name, pass, detail)
	table.insert(checks, { name = name, pass = pass, detail = detail })
	assert(pass, name .. ": " .. tostring(detail))
end
local ok, err = pcall(function()
	for i, id in { "giant_zombie", "basalt_guardian", "splinter", "minotaur" } do
		local definition = require(Shared.Models[id])
		local prepared = BlockRig.prepare(definition)
		local model = Instance.new("Model")
		model.Name = id
		local root = Instance.new("Part")
		root.Name, root.Size, root.CFrame =
			"HumanoidRootPart", Vector3.new(4, 5, 3), CFrame.new((i - 2.5) * 21, 304.5, 0)
		root.Anchored, root.Transparency, root.CanCollide, root.Parent = true, 1, false, model
		local fight
		for _, card in Config.bosses.bosses do
			if card.id == id then
				fight = card.fight
			end
		end
		BlockRig.build(definition, model, root, root.CFrame * CFrame.new(0, -4.5, 0), fight.texture)
		model.PrimaryPart = root
		model:SetAttribute("BlockModel", id)
		local motors = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") then
				motors[d.Name] = d
			end
		end
		model.Parent = folder
		CS:AddTag(model, "Boss")
		rows[id] = { model = model, prepared = prepared, motors = motors }
		task.wait(0.2)
		local count = 0
		for _ in motors do
			count += 1
		end
		check(id .. " joints load", count == #prepared.joints, count)
		for _, action in actions[id] do
			local length = if prepared.clips[action] then prepared.clips[action].length else 2
			model:SetAttribute("Action", action)
			model:SetAttribute("ActionLen", length)
			model:SetAttribute("ActionAt", workspace:GetServerTimeNow() - length * 0.42)
			task.wait(0.06)
			local moved = 0
			for _, m in motors do
				local _, angle = m.Transform:ToAxisAngle()
				if m.Transform.Position.Magnitude > 0.001 or math.abs(angle) > 0.001 then
					moved += 1
				end
			end
			check(id .. " " .. action .. " poses joints", moved >= 3, moved)
		end
		local death = prepared.clips.death
		model:SetAttribute("Action", "death")
		model:SetAttribute("ActionLen", death.length)
		model:SetAttribute("ActionAt", workspace:GetServerTimeNow() - death.length - 1)
		task.wait(0.1)
		local worst = 0
		for name, m in motors do
			local delta = BlockRig.sample(death, name, death.length):ToObjectSpace(m.Transform)
			local _, angle = delta:ToAxisAngle()
			worst = math.max(worst, delta.Position.Magnitude, math.abs(angle))
		end
		check(id .. " death holds exported final pose", worst < 0.001, worst)
		model:SetAttribute("Action", nil)
	end
end)
result.Value = game:GetService("HttpService")
	:JSONEncode({ ok = ok, error = if ok then nil else tostring(err), checks = checks })
return result.Value
