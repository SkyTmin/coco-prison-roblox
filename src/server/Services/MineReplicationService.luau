--!strict
-- A separate fast lane alongside MotionFx: never accepts mining results from clients.
-- Coalesce one server task's ordinary/AoE digs, then send bounded buffers only to nearby players.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local MineNet = require(Shared.MineNet)

local MineReplicationService = {}
local RANGE = 250 -- same visibility radius as MotionService
local MAX_PENDING = 4096 -- excessive bursts use ordinary authoritative replication
local nextId = 0
local remote: UnreliableRemoteEvent? = nil
type Removal = { id: number, position: Vector3 }
local pending: { Removal } = {}
local scheduled = false

local function flush()
	scheduled = false
	local batch = pending
	pending = {}
	local event = remote
	if not event then
		return
	end
	local stamp = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		local ids = {}
		for _, removal in batch do
			if (root.Position - removal.position).Magnitude <= RANGE then
				table.insert(ids, removal.id)
				if #ids == MineNet.MAX_IDS then
					event:FireClient(player, MineNet.encode(ids, stamp))
					table.clear(ids)
				end
			end
		end
		if #ids > 0 then
			event:FireClient(player, MineNet.encode(ids, stamp))
		end
	end
end

function MineReplicationService.Register(part: BasePart)
	-- Never recycle an ID during this server's lifetime, including mine resets/re-registration.
	nextId += 1
	if nextId <= 4294967295 then
		part:SetAttribute(MineNet.ATTRIBUTE, nextId)
	end
end

function MineReplicationService.Removed(part: BasePart)
	local id = part:GetAttribute(MineNet.ATTRIBUTE)
	if not remote or not MineNet.validId(id) or #pending >= MAX_PENDING then
		return
	end
	table.insert(pending, { id = id, position = part.Position })
	if not scheduled then
		scheduled = true
		task.defer(flush)
	end
end

function MineReplicationService.Start()
	remote = Remotes.unreliable(MineNet.REMOTE)
end

return MineReplicationService
