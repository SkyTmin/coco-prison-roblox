--!nocheck
-- Same-facing, coplanar opaque faces with overlapping area. Read-only structural diagnostic.
local q = assert(workspace:FindFirstChild("Quarry"))
local buckets = {}
local axes = { "X", "Y", "Z" }
for _, p in q:GetDescendants() do
	if not p:IsA("BasePart") or p.Transparency > 0.01 then
		continue
	end
	local cf = p.CFrame
	local axisAligned = true
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then
			axisAligned = false
		end
	end
	if not axisAligned then
		continue
	end
	local h = p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local e = Vector3.new(
		math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
		math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
		math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
	)
	local low, high = p.Position - e, p.Position + e
	for i, axis in axes do
		local a, b = axes[i % 3 + 1], axes[(i + 1) % 3 + 1]
		for _, sign in { -1, 1 } do
			local plane = if sign < 0 then low[axis] else high[axis]
			local key = axis .. sign .. ":" .. string.format("%.2f", plane)
			local bucket = buckets[key] or {}
			buckets[key] = bucket
			table.insert(
				bucket,
				{
					p = p,
					a0 = low[a],
					a1 = high[a],
					b0 = low[b],
					b1 = high[b],
					plane = plane,
					axis = axis,
				}
			)
		end
	end
end
local result = { count = 0, groups = {}, examples = {} }
for _, faces in buckets do
	for i = 1, #faces do
		for j = i + 1, #faces do
			local a, b = faces[i], faces[j]
			if a.p == b.p or math.abs(a.plane - b.plane) > 0.012 then
				continue
			end
			local w = math.min(a.a1, b.a1) - math.max(a.a0, b.a0)
			local h = math.min(a.b1, b.b1) - math.max(a.b0, b.b0)
			if w > 0.04 and h > 0.04 then
				local names = { a.p.Name, b.p.Name }
				table.sort(names)
				local key = table.concat(names, " / ")
				result.groups[key] = (result.groups[key] or 0) + 1
				result.count += 1
				if #result.examples < 60 then
					table.insert(result.examples, {
						names = key,
						axis = a.axis,
						plane = a.plane,
						area = w * h,
						a = tostring(a.p.Position),
						b = tostring(b.p.Position),
					})
				end
			end
		end
	end
end
local v = game.ServerStorage:FindFirstChild("QAQuarryCoplanar") or Instance.new("StringValue")
v.Name, v.Value, v.Parent =
	"QAQuarryCoplanar", game.HttpService:JSONEncode(result), game.ServerStorage
return result
