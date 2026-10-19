--!strict
-- Lazily creates (server) or waits for (client) RemoteEvents under ReplicatedStorage.Remotes.
-- Client -> server: Harvest(node: BasePart, generation: number), LevelUp()
-- Server -> client: ProfileUpdated(profile), Toast(text: string)

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

function Remotes.event(name: string): RemoteEvent
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = parent
		return created
	end
	return parent:WaitForChild(name) :: RemoteEvent
end

return Remotes
