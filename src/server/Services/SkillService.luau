--!strict
-- The skill tree [меню 26.10, wiki/in-game-wiki/SKILL-TREE.md; владелец 28.10]: SkillBuy(branchId) buys the next
-- level of a branch for one point (Shared/Skills checks points and order). The oblivion scroll from the hand
-- (UseConsumable → NeedsService → SkillService.Reset) gives every point back and is used up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Skills = require(Shared.Skills)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local SkillService = {}
local lastBuy: { [Player]: number } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function onBuy(player: Player, id: any)
	if typeof(id) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < 0.2 then
		return
	end
	lastBuy[player] = now
	local profile = ProfileService.Get(player)
	local refusal = Skills.refusal(profile, id)
	if refusal then
		toast(player, refusal)
		return
	end
	local bought = 0
	ProfileService.Mutate(player, function(p)
		if Skills.refusal(p, id) then
			return
		end
		local skills = (p :: any).skills
		if typeof(skills) ~= "table" then
			skills = {}
			p.skills = skills
		end
		skills[id] = (skills[id] or 0) + 1
		bought = skills[id]
	end)
	if bought > 0 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Sfx.broadcast("xp", root, 0.8)
		end
		toast(player, "skills_bought", Strings.t("skill_" .. id, Strings.localeOf(player)), bought)
	end
end

-- The oblivion scroll in `slot`: every bought level comes back as points; the scroll is gone.
function SkillService.Reset(player: Player, slot: number)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	if Skills.spent(profile) == 0 then
		toast(player, "skills_nothing_to_reset")
		return
	end
	local points = 0
	ProfileService.Mutate(player, function(p)
		local stack = p.inventory[slot]
		if not stack or stack.id ~= "oblivion_scroll" then
			return
		end
		points = Skills.spent(p)
		if stack.count > 1 then
			stack.count -= 1
		else
			p.inventory[slot] = nil
		end
		p.skills = {}
	end)
	if points > 0 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Sfx.broadcast("xp", root, 0.6)
		end
		toast(player, "skills_reset", points)
	end
end

function SkillService.Start()
	Remotes.event("SkillBuy").OnServerEvent:Connect(onBuy)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return SkillService
