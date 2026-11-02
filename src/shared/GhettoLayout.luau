--!strict
-- Small idempotent repair shared by the full builder and the cloud-map patch.
local CollectionService = game:GetService("CollectionService")
local GhettoLayout = {}
-- Five scattered street encounters, wander radius 8 studs [решение].
local BATS = {
	Vector3.new(66, 0.8, -95),
	Vector3.new(-66, 0.8, -95),
	Vector3.new(120, 0.8, 66),
	Vector3.new(-120, 0.8, 66),
	Vector3.new(0, 0.8, -175),
}

function GhettoLayout.apply(
	root: Instance,
	origin: Vector3?
): { arrivals: number, batsCreated: number }
	local arrivals = 0
	local rooms = root:FindFirstChild("GangMineRooms")
	if rooms then
		for _, room in ipairs(rooms:GetChildren()) do
			local arrival = room:FindFirstChild("Arrival")
			if arrival and arrival:IsA("BasePart") then
				arrival:SetAttribute("LocationId", "ghetto")
				arrival:SetAttribute("PrivateArrival", true)
				CollectionService:AddTag(arrival, "LocationSpawn")
				arrivals += 1
			end
		end
	end
	-- The 440-stud district's public arrival is 206 studs south of its centre, 0.6 above ground.
	local public = root:FindFirstChild("LocationSpawn_ghetto", true)
	local centre = origin
		or (
			if public and public:IsA("BasePart")
				then public.Position - Vector3.new(0, 0.6, 206)
				else nil
		)
	if not centre then
		return { arrivals = arrivals, batsCreated = 0 }
	end
	local spawns = root:FindFirstChild("MobSpawns")
	if not spawns then
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "MobSpawns", root
		spawns = folder
	end
	local created = 0
	for index, offset in ipairs(BATS) do
		local name = "MobSpawn_bat_" .. index
		local existing = spawns:FindFirstChild(name)
		if not existing then
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.new(2, 1, 2)
			part.CFrame = CFrame.new(centre + offset)
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			part:SetAttribute("MobId", "bat")
			part:SetAttribute("LocationId", "ghetto")
			part:SetAttribute("Wander", 8)
			part.Parent = spawns
			CollectionService:AddTag(part, "MobSpawn")
			created += 1
		end
	end
	return { arrivals = arrivals, batsCreated = created }
end

return GhettoLayout
