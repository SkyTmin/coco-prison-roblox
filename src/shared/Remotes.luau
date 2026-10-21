--!strict
-- RemoteEvents / RemoteFunctions under ReplicatedStorage.Remotes, created lazily on the server.
--
-- Client → server events:  DigStart(part, hitPoint), DigCancel(), DigFinish(part) [legacy, ignored], Sell(), BuyItem(id), UpgradeItem(id),
--                           LevelUp(), InventoryMove(from, to, count?), SelectSlot(n), SpendPoint(kind),
--                           ClaimProfessionPoints(job), UseConsumable(slot),
--                           CaseOpen(caseId, keyId?), CaseClose(caseId),
--                           ArtifactAssemble(tier: "common"|"rare"|"epic"),
--                           CaseMove(caseId, {container = "case"|"inv", index}, destination, count?)
--                           caseId also accepts "enderChest" for personal storage; CaseOpen rejects it.
-- Server → client events:  ProfileUpdated(profile), Toast(text), MineReset(mineId, state), Combo(mult, n)
--                          CaseOpened(caseId), CaseUpdated(caseId, active)
--                          BlockBroken(userId, cframe, size, color, blockId) — for other players' effects
--                          DigAccepted(part, needed), DigRejected(part) — server-side dig timer
-- Client → server:        Exchange(kind, id, count?), TrainerUpgrade(stat), Attack(lookDirection)
-- Server → client:        Knockback(velocity) — melee knockback the victim's client applies (HurtService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local Remotes = {}

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function get(className: string, name: string): Instance
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = parent
		return created
	end
	return parent:WaitForChild(name)
end

function Remotes.event(name: string): RemoteEvent
	return get("RemoteEvent", name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return get("RemoteFunction", name) :: RemoteFunction
end

return Remotes
