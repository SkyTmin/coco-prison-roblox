--!nocheck
-- In-place map fixes for an already built Prison (idempotent; the generators carry the same changes):
--   * mine ladders: 4 per pit, 4 blocks (16 studs) wide, centred on every wall [владелец];
--   * fountain rims / tier-2 rims: W/E pieces shortened so no two tops overlap (z-fighting);
--   * case pedestals raised above the plaza top (z-fighting under the cases).
local root = workspace:FindFirstChild("Prison")
if not root then
	return "no Prison folder"
end
local B = 4
local STONE = Color3.fromRGB(130, 130, 134)
local report = {}

-- ladders: rebuild from the mine anchors
for _, old in ipairs(root:GetChildren()) do
	if old.Name == "Ladder" and old:IsA("TrussPart") then
		old:Destroy()
	end
end
local ladders = 0
for _, anchor in ipairs(game:GetService("CollectionService"):GetTagged("MineAnchor")) do
	local size = anchor:GetAttribute("Size")
	if typeof(size) == "Vector3" then
		local w, h, d = size.X * B, size.Y * B, size.Z * B
		local cx, cz = anchor.Position.X, anchor.Position.Z
		for _, side in ipairs({
			{ cx, cz - d / 2 + 1, true },
			{ cx, cz + d / 2 - 1, true },
			{ cx - w / 2 + 1, cz, false },
			{ cx + w / 2 - 1, cz, false },
		}) do
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = if side[3] then Vector3.new(4 * B, h + 2, 2) else Vector3.new(2, h + 2, 4 * B)
			truss.CFrame = CFrame.new(side[1], -h / 2 + 1, side[2])
			truss.Anchored = true
			truss.Color = STONE
			truss.Parent = root
			ladders += 1
		end
	end
end
table.insert(report, "ladders " .. ladders)

-- fountain rims: shorten the W/E pieces (those with Size.Z > Size.X)
local rims = 0
for _, p in ipairs(root:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "FountainRim" and p.Size.Z > p.Size.X and p.Size.Z > 29.5 then
		p.Size = Vector3.new(p.Size.X, p.Size.Y, 29)
		rims += 1
	elseif p:IsA("BasePart") and p.Name == "FountainTier2" and p.Size.Z > p.Size.X and p.Size.Z > 13.7 then
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
