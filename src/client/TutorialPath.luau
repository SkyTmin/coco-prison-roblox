--!strict
-- Local, asset-free ground arrows. A bounded pool and 5 Hz updates avoid per-frame
-- raycasts/instance churn; every arrow has a shaft and two directional wings.
local Path = {}
Path.MAX_ARROWS = 12
Path.UPDATE_SECONDS = 0.2

function Path.points(start: Vector3, finish: Vector3, elapsed: number): ({ Vector3 }, Vector3)
	local delta = finish - start
	local flat = delta * Vector3.new(1, 0, 1)
	if flat.Magnitude <= 3 then
		return {}, Vector3.zAxis
	end
	local direction = flat.Unit
	local usable = math.max(0, flat.Magnitude - 3)
	local count = math.clamp(math.floor(flat.Magnitude / 4), 1, Path.MAX_ARROWS)
	local spacing = usable / count
	local points = {}
	for index = 1, count do
		local distance = 1.5 + ((index - 1) * spacing + elapsed * 1.6) % usable
		table.insert(points, start:Lerp(finish, distance / flat.Magnitude))
	end
	return points, direction
end

function Path.new(color: Color3, name: string?)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = name or "TutorialDirectionArrows", workspace
	local parts: { BasePart } = {}
	local nextUpdate = 0
	local api = { folder = folder }
	local function segment(index: number, a: Vector3, b: Vector3, lift: number, name: string)
		local part = parts[index]
		if not part then
			part = Instance.new("Part")
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.CastShadow, part.Material, part.Color = false, Enum.Material.SmoothPlastic, color
			part.Name, part.Parent = name, folder
			parts[index] = part
		end
		local offset = Vector3.new(0, lift, 0)
		part.Size = Vector3.new(0.18, 0.07, (b - a).Magnitude)
		part.CFrame, part.Transparency = CFrame.lookAt((a + b) / 2 + offset, b + offset), 0.05
	end
	function api.Update(start: Vector3, finish: Vector3, character: Model?, now: number?)
		local clock = now or os.clock()
		if clock < nextUpdate then
			return
		end
		nextUpdate = clock + Path.UPDATE_SECONDS
		local points, direction = Path.points(start, finish, clock)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if character then { folder, character } else { folder }
		params.RespectCanCollide = true
		local right = Vector3.new(-direction.Z, 0, direction.X)
		for index, point in points do
			local hit =
				workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
			if hit then
				point = hit.Position
			end
			local tip = point + direction * 0.9
			local base = point + direction * 0.12
			-- Slight height offsets prevent coplanar z-fighting where the strokes join.
			segment(index * 3 - 2, point - direction * 0.9, tip, 0.1, "Shaft")
			segment(index * 3 - 1, base - right * 0.65, tip, 0.12, "LeftWing")
			segment(index * 3, base + right * 0.65, tip, 0.14, "RightWing")
		end
		for index = #points * 3 + 1, #parts do
			parts[index].Transparency = 1
		end
		folder:SetAttribute("VisibleArrows", #points)
	end
	function api.Destroy()
		folder:Destroy()
		table.clear(parts)
	end
	return api
end

return Path
