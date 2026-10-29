--!strict
-- Remove the obsolete spawn quest NPC and notice board without rebuilding the map (Edit mode).
-- build-npcs.luau / decorate-prison.luau no longer create them.

local prison = assert(workspace:FindFirstChild("Prison"), "Prison is missing")
local removed = 0
local npcs = prison:FindFirstChild("Npcs")
local quest = if npcs then npcs:FindFirstChild("QuestGiver") else nil
if quest then
	quest:Destroy()
	removed += 1
end

local boardParts = { NoticeBoard = true, NoticePost = true, NoticeRoof = true, Notice = true }
local decor = prison:FindFirstChild("Decor")
if decor then
	for _, child in ipairs(decor:GetChildren()) do
		if boardParts[child.Name] then
			child:Destroy()
			removed += 1
		end
	end
end

return string.format("Removed %d spawn quest objects", removed)
