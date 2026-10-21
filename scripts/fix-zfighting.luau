--!nocheck
-- Finds pairs of visible parts in workspace.Prison whose faces lie in the same plane and overlap
-- (z-fighting: fences against walls, planks on stone, …) and pulls the smaller part's face back by
-- 0.03 studs. Idempotent: a second run finds nothing. Returns a report; run via the loader (Edit).
local root = workspace:FindFirstChild("Prison")
if not root then
	return "no Prison"
end
local EPS = 0.01
local NUDGE = 0.03
local fixed, checked = 0, 0
local parts = {}
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and p.Transparency < 0.95 and not p:IsA("TrussPart") then
		table.insert(parts, p)
	end
end
-- axis-aligned only (rotated parts are skipped: their faces rarely share a plane exactly)
local function aligned(p)
	local r = p.CFrame.Rotation
	local function near(v, t)
		return math.abs(v - t) < 1e-3
	end
	return (near(math.abs(r.XVector.X), 1) or near(math.abs(r.XVector.Z), 1))
		and near(math.abs(r.YVector.Y), 1)
end
local function bounds(p)
	local half = p.Size / 2
	-- rotated by 90° about Y: swap X and Z extents
	if math.abs(p.CFrame.Rotation.XVector.Z) > 0.5 then
		half = Vector3.new(half.Z, half.Y, half.X)
	end
	return p.Position - half, p.Position + half
end
local function overlap1(a0, a1, b0, b1)
	return math.min(a1, b1) - math.max(a0, b0) > 0.05
end
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { root }
for _, a in ipairs(parts) do
	if not aligned(a) or not a.Parent then
		continue
	end
	local aMin, aMax = bounds(a)
	local near = workspace:GetPartBoundsInBox(CFrame.new(a.Position), a.Size + Vector3.new(0.1, 0.1, 0.1), params)
	for _, b in ipairs(near) do
		if b ~= a and b:IsA("BasePart") and b.Transparency < 0.95 and not b:IsA("TrussPart") and aligned(b) then
			checked += 1
			local bMin, bMax = bounds(b)
			for axis = 1, 3 do
				local names = { "X", "Y", "Z" }
				local ax = names[axis]
				local others = { X = { "Y", "Z" }, Y = { "X", "Z" }, Z = { "X", "Y" } }
				local o1, o2 = others[ax][1], others[ax][2]
				local function faceClash(aFace, bFace)
					return math.abs(aFace - bFace) < EPS
						and overlap1(aMin[o1], aMax[o1], bMin[o1], bMax[o1])
						and overlap1(aMin[o2], aMax[o2], bMin[o2], bMax[o2])
				end
				-- same-direction faces on the same plane (both tops at y, both +X sides at x, …)
				local plus = faceClash(aMax[ax], bMax[ax])
				local minus = faceClash(aMin[ax], bMin[ax])
				if plus or minus then
					-- shrink the smaller part along this axis so its face sits 0.03 inside
					local small = if a.Size[o1] * a.Size[o2] <= b.Size[o1] * b.Size[o2] then a else b
					local sign = if plus then 1 else -1
					local shrink = Vector3.new(ax == "X" and NUDGE or 0, ax == "Y" and NUDGE or 0, ax == "Z" and NUDGE or 0)
					-- the shrink must act on the world axis: for 90°-rotated parts world X is local Z
					local rotated = math.abs(small.CFrame.Rotation.XVector.Z) > 0.5
					local localShrink = if rotated then Vector3.new(shrink.Z, shrink.Y, shrink.X) else shrink
					small.Size = small.Size - localShrink
					small.Position = small.Position - Vector3.new(ax == "X" and sign * NUDGE / 2 or 0, ax == "Y" and sign * NUDGE / 2 or 0, ax == "Z" and sign * NUDGE / 2 or 0)
					fixed += 1
					aMin, aMax = bounds(a)
				end
			end
		end
	end
end
return string.format("[fix-zfighting] parts %d, pairs checked %d, faces nudged %d", #parts, checked, fixed)
