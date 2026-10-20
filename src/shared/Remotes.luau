--!strict
-- RemoteEvents / RemoteFunctions under ReplicatedStorage.Remotes, created lazily on the server.
--
-- Client → server events:  DigStart(part), DigFinish(part), Sell(), BuyItem(id), UpgradeItem(id),
--                           LevelUp(), InventoryMove(from, to), SelectSlot(n), SpendPoint(kind),
--                           ClaimProfessionPoints(job), UseConsumable(slot),
--                           CaseOpen(caseId), CaseClose(caseId),
--                           CaseMove(caseId, {container = "case"|"inv", index}, destination)
-- Server → client events:  ProfileUpdated(profile), Toast(text), MineReset(mineId, state), Combo(mult, n)
--                          CaseOpened(caseId), CaseUpdated(caseId, active)

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
