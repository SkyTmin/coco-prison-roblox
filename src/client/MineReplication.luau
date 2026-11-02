--!strict
-- Remove a streamed block as soon as the server confirms it, without waiting for Instance deletion.
-- A missed packet simply falls back to normal replication. A fresh reset block has a different ID.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local MineNet = require(Shared.MineNet)

local MineReplication = {}
local TAG = "MineBlock"
local MAX_REMEMBERED = 8192
local parts: { [number]: BasePart } = {}
local partIds: { [BasePart]: number } = {}
local waiting: { [BasePart]: RBXScriptConnection } = {}
local removed: { [number]: number } = {}
type Expiry = { id: number, untilAt: number }
local expiries: { Expiry } = {}
local head = 1
local started = false

local function forget(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local id = partIds[instance]
	if id and parts[id] == instance then
		parts[id] = nil
	end
	partIds[instance] = nil
	local connection = waiting[instance]
	if connection then
		connection:Disconnect()
		waiting[instance] = nil
	end
end

local function discard(part: BasePart)
	forget(part)
	-- This is a confirmed removal, not prediction: children, collisions and ray targets go together.
	-- Existing local dig prediction sees Parent=nil and clears its pending state without restoring it.
	part:Destroy()
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local id = instance:GetAttribute(MineNet.ATTRIBUTE)
	if not MineNet.validId(id) then
		-- Streaming may deliver the tag before the identity attribute.
		if not waiting[instance] then
			waiting[instance] = instance
				:GetAttributeChangedSignal(MineNet.ATTRIBUTE)
				:Connect(function()
					track(instance)
				end)
		end
		return
	end
	forget(instance)
	if (removed[id] or 0) > os.clock() then
		-- Tag callbacks can run inside the engine's Parent assignment during streaming.
		-- Finish that assignment before destroying the newly arrived, already-removed instance.
		task.defer(discard, instance)
	else
		parts[id], partIds[instance] = instance, id
	end
end

local function prune(now: number)
	while head <= #expiries do
		local entry = expiries[head]
		if entry.untilAt > now and #expiries - head + 1 <= MAX_REMEMBERED then
			break
		end
		if removed[entry.id] == entry.untilAt then
			removed[entry.id] = nil
		end
		head += 1
	end
	if head > 1024 then
		local kept = {}
		table.move(expiries, head, #expiries, 1, kept)
		expiries, head = kept, 1
	end
end

local function receive(packet: any)
	local ids = MineNet.decode(packet, workspace:GetServerTimeNow())
	if not ids then
		return
	end
	prune(os.clock())
	local untilAt = os.clock() + MineNet.MAX_AGE
	for _, id in ids do
		if not removed[id] then
			removed[id] = untilAt
			table.insert(expiries, { id = id, untilAt = untilAt })
		end
		local part = parts[id]
		if part then
			discard(part)
		end
	end
	prune(os.clock())
end

function MineReplication.Start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(forget)
	for _, part in CollectionService:GetTagged(TAG) do
		track(part)
	end
	Remotes.unreliable(MineNet.REMOTE).OnClientEvent:Connect(receive)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			prune(os.clock())
		end
	end)
end

return MineReplication
