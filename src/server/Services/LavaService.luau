--!strict
-- Lava as in Minecraft [ваниль]: 4 damage (half-hearts) every 0.5 s while touching it, then the player burns
-- for a while after leaving it, 1 damage a second. Lava parts are tagged Lava (scripts/build-underworld.luau:
-- the lava sea, the river, the pools, the lavafalls). The check is a box at the feet against the tagged parts
-- only; a Fire on the root shows the burning to everyone. Creative players do not burn. Lava deaths are not
-- player/mob/boss deaths (LastHitBy cleared, stats untouched). Огнестойкость (a potion) protects like Creative.
-- The void net: parts tagged VoidCatch (attribute LocationId) lie under floating locations (Пустотная крепость:
-- scripts/build-end-castle.luau); a player who falls into one is put back on that location's arrival point with
-- VOID_DAMAGE [решение] instead of falling for kilometres.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(ReplicatedStorage:WaitForChild("Shared").Effects)
local HurtService = require(script.Parent.HurtService)

local LAVA_DAMAGE = 4 -- [ваниль] per 0.5 s in lava
local LAVA_PERIOD = 0.5
local BURN_DAMAGE = 1 -- [ваниль] fire: 1 per second
local BURN_SECONDS = 8 -- [решение] vanilla burns 15 s after lava; shorter here, there is no water to jump into
local FEET = Vector3.new(2, 2.5, 2)
local VOID_DAMAGE = 4 -- [решение] a fall into the void costs two hearts
local BODY = Vector3.new(3, 5, 3)

local LavaService = {}
local started = false
local burnUntil: { [Player]: number } = {}

local function setFire(root: BasePart, on: boolean)
	local fire = root:FindFirstChild("LavaFire")
	if on and not fire then
		local f = Instance.new("Fire")
		f.Name = "LavaFire"
		f.Size = 4
		f.Heat = 8
		f.Parent = root
	elseif not on and fire then
		fire:Destroy()
	end
end

local function inLava(root: BasePart, params: OverlapParams): boolean
	local feet = root.CFrame * CFrame.new(0, -2.6, 0)
	return #workspace:GetPartBoundsInBox(CFrame.new(feet.Position), FEET, params) > 0
end

function LavaService.Start()
	if started then
		return
	end
	started = true
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local function refresh()
		params.FilterDescendantsInstances = CollectionService:GetTagged("Lava")
	end
	refresh()
	CollectionService:GetInstanceAddedSignal("Lava"):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal("Lava"):Connect(refresh)
	local voidParams = OverlapParams.new()
	voidParams.FilterType = Enum.RaycastFilterType.Include
	local function refreshVoid()
		voidParams.FilterDescendantsInstances = CollectionService:GetTagged("VoidCatch")
	end
	refreshVoid()
	CollectionService:GetInstanceAddedSignal("VoidCatch"):Connect(refreshVoid)
	CollectionService:GetInstanceRemovedSignal("VoidCatch"):Connect(refreshVoid)
	local rescuing: { [Player]: boolean } = {}
	local function rescue(player: Player, root: BasePart, humanoid: Humanoid, net: BasePart)
		if rescuing[player] then
			return
		end
		local locationId = net:GetAttribute("LocationId")
		local spawn: BasePart? = nil
		for _, p in ipairs(CollectionService:GetTagged("LocationSpawn")) do
			if
				p:IsA("BasePart")
				and p:GetAttribute("LocationId") == locationId
				and p:GetAttribute("Spot") == nil
			then
				spawn = p
				break
			end
		end
		if not spawn then
			return
		end
		rescuing[player] = true
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync((spawn :: BasePart).Position)
			end)
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = (spawn :: BasePart).CFrame + Vector3.new(0, 4, 0)
				humanoid:SetAttribute("LastHitBy", nil)
				HurtService.Damage(humanoid, VOID_DAMAGE)
			end
			rescuing[player] = nil
		end)
	end
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local hits = workspace:GetPartBoundsInBox(root.CFrame, BODY, voidParams)
				if #hits > 0 and hits[1]:IsA("BasePart") then
					rescue(player, root, humanoid, hits[1] :: BasePart)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		burnUntil[player] = nil
	end)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(LAVA_PERIOD)
			tick += 1
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
					burnUntil[player] = nil
					continue
				end
				-- Огнестойкость (a potion): lava and fire do nothing [ваниль]
				if
					player:GetAttribute("Creative") == true
					or Effects.level(character, "FireResistance") > 0
				then
					burnUntil[player] = nil
					setFire(root, false)
					continue
				end
				if inLava(root, params) then
					burnUntil[player] = now + BURN_SECONDS
					humanoid:SetAttribute("LastHitBy", nil)
					HurtService.Damage(humanoid, LAVA_DAMAGE)
					setFire(root, true)
				elseif burnUntil[player] then
					if now >= (burnUntil[player] :: number) then
						burnUntil[player] = nil
						setFire(root, false)
					elseif tick % 2 == 0 then
						humanoid:SetAttribute("LastHitBy", nil)
						HurtService.Damage(humanoid, BURN_DAMAGE)
					end
				end
			end
		end
	end)
end

return LavaService
