--!nocheck
-- Dev helper: pull the Rojo project tree from `rojo serve` (localhost:34872) into the open place
-- without the Rojo plugin UI (for agent-driven sessions). Creates/updates scripts and folders by
-- path; does not delete anything. Run via Studio MCP execute_luau in Edit mode.

local HttpService = game:GetService("HttpService")
HttpService.HttpEnabled = true

local BASE = "http://localhost:34872"
local info = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "/api/rojo"))
local rootId = info.rootInstanceId
local read = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "/api/read/" .. rootId))
local instances = read.instances

local created, updated = 0, 0

local function ensure(parent, data)
	local existing = parent:FindFirstChild(data.Name)
	if existing and existing.ClassName ~= data.ClassName then
		existing:Destroy()
		existing = nil
	end
	local inst = existing
	if not inst then
		inst = Instance.new(data.ClassName)
		inst.Name = data.Name
		inst.Parent = parent
		created += 1
	end
	local src = data.Properties and data.Properties.Source
	if src and src.String ~= nil and inst:IsA("LuaSourceContainer") then
		if inst.Source ~= src.String then
			inst.Source = src.String
			updated += 1
		end
	end
	return inst
end

local function walk(id, parent)
	local data = instances[id]
	for _, childId in ipairs(data.Children or {}) do
		local child = instances[childId]
		local target
		if parent == game then
			target = game:GetService(child.ClassName)
		else
			target = ensure(parent, child)
		end
		walk(childId, target)
	end
end

walk(rootId, game)
return string.format("rojo sync: created %d, updated %d", created, updated)
