--!nocheck
-- In-place map fixes for an already built Prison (idempotent; the generators carry the same changes):
--   * mine ladders: 4 per pit, 4 blocks (16 studs) wide, centred on every wall, Minecraft look
--     (textured transparent plate on the wall side of the shaft + invisible climbable truss) [владелец];
--   * fountain rims / tier-2 rims: W/E pieces shortened so no two tops overlap (z-fighting);
--   * case pedestals raised above the plaza top (z-fighting under the cases).
local root = workspace:FindFirstChild("Prison")
if not root then
	return "no Prison folder"
end
local B = 4
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
local ladderTexture = textures.textures.ladder
local report = {}

-- ladders: rebuild from the mine anchors
for _, old in ipairs(root:GetChildren()) do
	if old.Name == "Ladder" or old.Name == "LadderFace" then
		old:Destroy()
	end
end
local ladders = 0
for _, anchor in ipairs(game:GetService("CollectionService"):GetTagged("MineAnchor")) do
	local size = anchor:GetAttribute("Size")
	if typeof(size) == "Vector3" then
		local w, h, d = size.X * B, size.Y * B, size.Z * B
		local cx, cz = anchor.Position.X, anchor.Position.Z
		local LADDER_W = 4 * B
		for _, side in ipairs({
			{ cx, cz - d / 2, Vector3.new(0, 0, 1) },
			{ cx, cz + d / 2, Vector3.new(0, 0, -1) },
			{ cx - w / 2, cz, Vector3.new(1, 0, 0) },
			{ cx + w / 2, cz, Vector3.new(-1, 0, 0) },
		}) do
			local inward = side[3]
			local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
			-- Roblox climbs only 2×2 trusses: the 4-block ladder is eight of them side by side, invisible
			for k = 0, LADDER_W / 2 - 1 do
				local offset = along * (-LADDER_W / 2 + 1 + k * 2)
				local truss = Instance.new("TrussPart")
				truss.Name = "Ladder"
				truss.Size = Vector3.new(2, h, 2) -- top flush with the ground, like a Minecraft ladder
				truss.CFrame =
					CFrame.new(Vector3.new(side[1], -h / 2, side[2]) - inward * 0.6 + offset) -- 1.6 studs sunk into the wall: only 0.4 stud protrudes, nobody can stand on the top
				truss.Anchored = true
				truss.Transparency = 1
				truss.Parent = root
			end
			local plate = Instance.new("Part")
			plate.Name = "LadderFace"
			plate.Size = Vector3.new(
				LADDER_W * along.X + 0.2 * math.abs(inward.X),
				h,
				LADDER_W * along.Z + 0.2 * math.abs(inward.Z)
			)
			plate.CFrame = CFrame.new(Vector3.new(side[1], -h / 2, side[2]) + inward * 0.15) -- flush against the pit wall, like a Minecraft ladder on its block [владелец]
			plate.Anchored = true
			plate.CanCollide = false
			plate.CanQuery = false
			plate.Transparency = 1
			plate.Parent = root
			if ladderTexture then
				local tex = Instance.new("Texture")
				tex.Texture = ladderTexture
				tex.Face = if inward.Z > 0
					then Enum.NormalId.Back
					elseif inward.Z < 0 then Enum.NormalId.Front
					elseif inward.X > 0 then Enum.NormalId.Right
					else Enum.NormalId.Left
				tex.StudsPerTileU, tex.StudsPerTileV = B, B
				tex.Parent = plate
			end
			ladders += 1
		end
	end
end
table.insert(report, "ladders " .. ladders)

-- fountain rims: shorten the W/E pieces (those with Size.Z > Size.X)
local rims = 0
for _, p in ipairs(root:GetChildren()) do
	if
		p:IsA("BasePart")
		and p.Name == "FountainRim"
		and p.Size.Z > p.Size.X
		and p.Size.Z > 29.5
	then
		p.Size = Vector3.new(p.Size.X, p.Size.Y, 29)
		rims += 1
	elseif
		p:IsA("BasePart")
		and p.Name == "FountainTier2"
		and p.Size.Z > p.Size.X
		and p.Size.Z > 13.7
	then
		p.Size = Vector3.new(p.Size.X, p.Size.Y, 13.6)
		rims += 1
	end
end
table.insert(report, "rims " .. rims)

-- pedestals under the cases: top at 1.0 instead of 0.6
local pedestals = 0
local npcs = root:FindFirstChild("Npcs")
if npcs then
	for _, model in ipairs(npcs:GetChildren()) do
		local pedestal = model:FindFirstChild("Pedestal")
		if pedestal and pedestal:IsA("BasePart") and pedestal.Size.Y < 0.9 then
			pedestal.Size = Vector3.new(pedestal.Size.X, 1, pedestal.Size.Z)
			pedestal.CFrame = pedestal.CFrame + Vector3.new(0, 0.2, 0)
			pedestals += 1
		end
	end
end
table.insert(report, "pedestals " .. pedestals)
return "[fix-map] " .. table.concat(report, ", ")
