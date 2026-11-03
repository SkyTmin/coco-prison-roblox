--!nocheck
-- Run only in the verified local copy of revision 428. Native serialization; no parents,
-- Archivable flags, cloud saves or publications are changed. Backend is write-once.
-- BEGIN SHARED RECOVERY CHECKS (kept identical in export/import)
local SOURCE_VERSION = 428
local PLACE_ID = 92594200898716
local BASE_URL = "http://127.0.0.1:8778"
local ROOT_NAMES = {
	"Basement",
	"Barn",
	"Castle",
	"Cherubim",
	"Church",
	"Eden",
	"EdgeGate",
	"EndCastle",
	"FactionBase",
	"Farm",
	"Gate",
	"Ghetto",
	"InsideOut",
	"Kyoto",
	"LeprechaunValley",
	"Market",
	"MountainFoot",
	"Paradise",
	"Prison",
	"Purgatory",
	"Pyramid",
	"Quarry",
	"RoyalGarden",
	"Showcase",
	"SnowyHand",
	"SpiderLair",
	"SunkenLighthouse",
	"Tree",
	"Underworld",
	"Warzone",
}
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Codec = game:GetService("SerializationService")
local Encoding = game:GetService("EncodingService")
local Storage = game:GetService("ServerStorage")
local Collection = game:GetService("CollectionService")
local function editOnly()
	assert(Run:IsStudio() and not Run:IsRunning(), "Recovery requires Studio Edit mode")
end
local function sha256(bytes)
	local digest = Encoding:ComputeBufferHash(bytes, Enum.HashAlgorithm.Sha256)
	assert(buffer.len(digest) == 32, "Expected SHA-256 digest")
	local out = {}
	for i = 0, 31 do
		out[i + 1] = string.format("%02x", buffer.readu8(digest, i))
	end
	return table.concat(out)
end
local function finite(n)
	assert(n == n and math.abs(n) < math.huge, "Nonfinite manifest number")
	return n
end
local function encode(value)
	local kind = typeof(value)
	if kind == "string" or kind == "boolean" then
		return value
	end
	if kind == "number" then
		return finite(value)
	end
	local data
	if kind == "Vector3" then
		data = { value.X, value.Y, value.Z }
	elseif kind == "Vector2" then
		data = { value.X, value.Y }
	elseif kind == "Color3" then
		data = { value.R, value.G, value.B }
	elseif kind == "CFrame" then
		data = { value:GetComponents() }
	elseif kind == "UDim" then
		data = { value.Scale, value.Offset }
	elseif kind == "UDim2" then
		data = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "NumberRange" then
		data = { value.Min, value.Max }
	elseif kind == "Rect" then
		data = { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }
	elseif kind == "BrickColor" then
		data = { value.Number }
	elseif kind == "NumberSequence" then
		data = {}
		for _, key in value.Keypoints do
			table.insert(data, { key.Time, key.Value, key.Envelope })
		end
	elseif kind == "ColorSequence" then
		data = {}
		for _, key in value.Keypoints do
			table.insert(data, { key.Time, key.Value.R, key.Value.G, key.Value.B })
		end
	elseif kind == "Font" then
		data = { value.Family, value.Weight.Name, value.Style.Name }
	else
		error("Unsupported manifest attribute type: " .. kind)
	end
	return { type = kind, value = data }
end
-- Object keys are sorted; array indices retain order. No timestamps/random fields enter digests.
local function canonical(value)
	local kind = type(value)
	if kind ~= "table" then
		return Http:JSONEncode(value)
	end
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in keys do
		table.insert(parts, Http:JSONEncode(tostring(key)) .. ":" .. canonical(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function equal(a, b)
	return canonical(a) == canonical(b)
end
local function attrs(object)
	local result = {}
	for key, value in object:GetAttributes() do
		result[key] = encode(value)
	end
	return result
end
local function sortedTags(object)
	local tags = Collection:GetTags(object)
	table.sort(tags)
	return tags
end
local function referencePath(object)
	if object == nil then
		return false
	end
	local path, cursor = {}, object
	while cursor do
		table.insert(path, 1, { name = cursor.Name, class = cursor.ClassName })
		if table.find(ROOT_NAMES, cursor.Name) and cursor:IsA("Folder") then
			return path
		end
		cursor = cursor.Parent
	end
	return { external = path }
end
-- Parenting can clear Model.PrimaryPart. Capture these native reference properties and
-- restore only their original instance identities after rebuilding the new hierarchy.
local function references(object)
	local result = {}
	local function add(property)
		result[property] = object[property]
	end
	if object:IsA("Model") then
		add("PrimaryPart")
	end
	if object:IsA("ObjectValue") then
		add("Value")
	end
	if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
		add("Part0")
		add("Part1")
	end
	if object:IsA("Constraint") or object:IsA("Beam") or object:IsA("Trail") then
		add("Attachment0")
		add("Attachment1")
	end
	if
		object:IsA("BillboardGui")
		or object:IsA("SurfaceGui")
		or object:IsA("Highlight")
		or object:IsA("SelectionBox")
		or object:IsA("SelectionSphere")
		or object:IsA("Handles")
		or object:IsA("ArcHandles")
	then
		add("Adornee")
	end
	return result
end
local function ignoredEngineStatus(object)
	-- Roblox creates this unarchivable implementation child; it is not authored map data.
	-- Keep it attached to its Humanoid and exclude it from serialized-data signatures.
	return not object.Archivable
		and object.ClassName == "Status"
		and object.Name == "Status"
		and object.Parent ~= nil
		and object.Parent:IsA("Humanoid")
		and #object:GetChildren() == 0
		and next(object:GetAttributes()) == nil
		and #Collection:GetTags(object) == 0
end
local function describe(root)
	local descendants = root:GetDescendants()
	local counts, anchors, attributes, refs, pivots = {}, {}, {}, {}, {}
	local included = 0
	for index, object in descendants do
		if ignoredEngineStatus(object) then
			continue
		end
		included += 1
		counts[object.ClassName] = (counts[object.ClassName] or 0) + 1
		assert(object.Archivable, "Nonarchivable recovery descendant: " .. object:GetFullName())
		local attribute = attrs(object)
		local tags = sortedTags(object)
		local path = object:GetFullName():sub(#root:GetFullName() + 2)
		local ref = {}
		for property, target in references(object) do
			ref[property] = referencePath(target)
		end
		if next(ref) then
			table.insert(
				refs,
				canonical({ path = path, class = object.ClassName, properties = ref })
			)
		end
		if object:IsA("Model") then
			table.insert(pivots, canonical({ path = path, worldPivot = encode(object.WorldPivot) }))
		end
		if next(attribute) or #tags > 0 then
			table.insert(
				attributes,
				canonical({
					path = path,
					class = object.ClassName,
					attributes = attribute,
					tags = tags,
				})
			)
		end
		local anchor = object:IsA("BasePart")
			and (
				object:GetAttribute("MineId") ~= nil
				or object:GetAttribute("LocationId") ~= nil
				or object:GetAttribute("BossId") ~= nil
				or object:IsA("SpawnLocation")
				or table.find(tags, "MineAnchor") ~= nil
				or table.find(tags, "LocationSpawn") ~= nil
				or table.find(tags, "BossSpawn") ~= nil
			)
		if anchor then
			table.insert(anchors, {
				path = path,
				class = object.ClassName,
				attributes = attribute,
				tags = tags,
				cframe = encode(object.CFrame),
				size = encode(object.Size),
			})
		end
		if index % 1000 == 0 then
			task.wait()
		end
	end
	table.sort(attributes)
	table.sort(refs)
	table.sort(pivots)
	table.sort(anchors, function(a, b)
		return canonical(a) < canonical(b)
	end)
	return {
		name = root.Name,
		class = root.ClassName,
		descendants = included,
		classes = counts,
		attributes = attrs(root),
		tags = sortedTags(root),
		anchors = anchors,
		attributedDescendants = #attributes,
		attributeDigest = sha256(buffer.fromstring(canonical(attributes))),
		referenceCount = #refs,
		referenceDigest = sha256(buffer.fromstring(canonical(refs))),
		pivotCount = #pivots,
		pivotDigest = sha256(buffer.fromstring(canonical(pivots))),
	}
end
local function countNamed(parent, name)
	local count, found = 0, nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			count += 1
			found = child
		end
	end
	return count, found
end
local function request(method, route, body, contentType)
	local response = Http:RequestAsync({
		Url = BASE_URL .. route,
		Method = method,
		Body = body,
		Headers = if body then { ["Content-Type"] = contentType } else nil,
	})
	assert(response.Success, route .. " HTTP " .. tostring(response.StatusCode))
	return response.Body
end
-- END SHARED RECOVERY CHECKS

editOnly()
assert(game.PlaceId == 0, "Export only from an opened LOCAL revision copy")
assert(game.Name == "Place1 (Version 428)", "Export only from the verified CLI revision 428")
assert(
	game.PlaceVersion == 0 or game.PlaceVersion == SOURCE_VERSION,
	"Unexpected revision metadata"
)
assert(not Storage:FindFirstChild("QAReleaseMapLease"), "Refuse scene lease")
assert(not workspace:FindFirstChild("QAReleaseStaging"), "Refuse staging authoring map")
assert(not _G.RecoveryMapExportActive, "Export already active")
_G.RecoveryMapExportActive = true
local ok, result = xpcall(function()
	local roots, manifest =
		{}, { schema = 1, sourceVersion = SOURCE_VERSION, sourcePlaceId = PLACE_ID, roots = {} }
	for _, name in ROOT_NAMES do
		local count, root = countNamed(workspace, name)
		assert(
			count == 1 and root:IsA("Folder") and #root:GetChildren() > 0,
			"Missing/duplicate/empty source root: " .. name
		)
		assert(root.Archivable, "Nonarchivable source root: " .. name)
		if name ~= "Prison" then
			table.insert(roots, root)
		end
	end
	assert(#roots == 29, "Expected exactly29 exported roots")
	local quarry = workspace:FindFirstChild("Quarry")
	assert(quarry:GetAttribute("WorldBaseY") == 37500, "Unexpected Quarry height")
	local quarryAttributes = quarry:GetAttributes()
	local accepted = false
	for _, value in quarryAttributes do
		if value == "2026-11-03-open-air-accepted" then
			accepted = true
		end
	end
	assert(accepted, "Source lacks accepted open-air Quarry marker")
	for _, root in roots do
		table.insert(manifest.roots, describe(root))
	end
	editOnly()
	print("[recovery export] preflight29 roots complete; native serialize")
	local bytes = Codec:SerializeInstancesAsync(roots)
	manifest.bytes, manifest.sha256 = buffer.len(bytes), sha256(bytes)
	assert(manifest.bytes > 0, "Empty native serialization")
	-- Recheck after native yield; no detached-source or nonarchivable trick is used.
	for index, root in roots do
		assert(
			root.Parent == workspace and equal(describe(root), manifest.roots[index]),
			"Source changed during serialization: " .. root.Name
		)
	end
	editOnly()
	local saved = Http:JSONDecode(
		request("POST", "/map.rbxm", buffer.tostring(bytes), "application/octet-stream")
	)
	assert(
		saved.saved and saved.bytes == manifest.bytes and saved.sha256 == manifest.sha256,
		"Backend binary receipt mismatch"
	)
	local json = Http:JSONEncode(manifest)
	local manifestSaved =
		Http:JSONDecode(request("POST", "/manifest.json", json, "application/json"))
	assert(
		manifestSaved.saved
			and manifestSaved.bytes == #json
			and manifestSaved.sha256 == sha256(buffer.fromstring(json)),
		"Backend manifest receipt mismatch"
	)
	print("[recovery export] COMPLETE", manifest.bytes, manifest.sha256)
	return {
		status = "EXPORTED",
		sourceVersion = SOURCE_VERSION,
		roots = #roots,
		bytes = manifest.bytes,
		sha256 = manifest.sha256,
	}
end, debug.traceback)
_G.RecoveryMapExportActive = nil
assert(ok, tostring(result))
return result
