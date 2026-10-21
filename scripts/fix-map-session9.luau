--!nocheck
-- In-place map fixes of 21.10 (owner's list; idempotent; build-prison / build-buildings carry the same):
--   * players appear by the big mine: SpawnLocation moved to the north edge of the plaza, facing it;
--   * Спальня: the middle bunk of the front row stood in the north doorway — removed;
--   * Баня, toilets: the 6-stud stall fronts left a 1-stud gap — now 1-stud pillars, doors swung open;
--   * Баня, showers: the drains are RestoreHygiene zones (washing was possible only in the pools).
local CollectionService = game:GetService("CollectionService")
local root = workspace:FindFirstChild("Prison")
if not root then
	return "no Prison folder"
end
local report = {}

local spawn = root:FindFirstChild("Spawn")
if spawn and spawn:IsA("SpawnLocation") then
	spawn.CFrame = CFrame.new(0, 0.8, -40)
	table.insert(report, "spawn moved")
end

local buildings = root:FindFirstChild("Buildings") or root
local bedroom = buildings:FindFirstChild("Bedroom", true)
local BUNK = {
	Rail = true,
	Bed = true,
	BedFrame = true,
	Blanket = true,
	BunkPost = true,
	Pillow = true,
	Rung = true,
	ChestBand = true,
	FootChest = true,
}
local removed = 0
if bedroom then
	for _, p in ipairs(bedroom:GetDescendants()) do
		if p:IsA("BasePart") and BUNK[p.Name] then
			local pos = p.Position
			if pos.X > -124 and pos.X < -116 and pos.Z > 90.5 and pos.Z < 104 then
				p:Destroy()
				removed += 1
			end
		end
	end
end
table.insert(report, "bunk parts removed " .. removed)

local bath = buildings:FindFirstChild("Bath", true)
local walls, doors, drains = 0, 0, 0
if bath then
	for _, p in ipairs(bath:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name == "StallWall" and math.abs(p.Size.Z - 6) < 0.01 and math.abs(p.Position.X + 96) < 0.1 then
				local z = p.Position.Z
				p.Size = Vector3.new(0.3, 7, 1)
				p.CFrame = CFrame.new(-96, 4.3, if math.abs(z + 99.5) < 0.1 then -97 else z + 0.5)
				walls += 1
			elseif p.Name == "StallDoor" and math.abs(p.Position.X + 96.2) < 0.2 then
				local z = p.Position.Z
				p.CFrame = CFrame.new(-97.9, 3.8, z - 1.6) * CFrame.Angles(0, math.pi / 2, 0)
				doors += 1
			elseif p.Name == "Drain" and not CollectionService:HasTag(p, "RestoreHygiene") then
				CollectionService:AddTag(p, "RestoreHygiene")
				drains += 1
			end
		end
	end
end
table.insert(report, string.format("stall walls %d, doors %d, shower drains %d", walls, doors, drains))
return table.concat(report, "; ")
