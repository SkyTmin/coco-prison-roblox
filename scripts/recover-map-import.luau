--!nocheck
-- Append-only recovery into the verified partial authoring map. No cloud save/publish.
-- Deserialized objects stay detached until every root and native byte hash is checked.
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
	if type(a) ~= type(b) then
		return false
	end
	if type(a) == "number" then
		if a == b then
			return true
		end
		-- JSON's decimal representation may round a binary float by its last ULP.
		-- Counts/integers and all string digests still require exact equality.
		if a % 1 == 0 and b % 1 == 0 then
			return false
		end
		if a ~= a or b ~= b or math.abs(a) == math.huge or math.abs(b) == math.huge then
			return false
		end
		return math.abs(a - b) <= 1e-12 * math.max(1, math.abs(a), math.abs(b))
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if rawget(b, key) == nil or not equal(value, b[key]) then
			return false
		end
	end
	for key in b do
		if rawget(a, key) == nil then
			return false
		end
	end
	return true
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
assert(game.PlaceId == PLACE_ID and game.PlaceVersion == 433, "Wrong target place/version")
assert(
	not _G.RecoveryMapImportActive and not Storage:GetAttribute("MapRecoveryActive"),
	"Recovery already active/stale guard"
)
local expected, originals = {}, {}
for _, name in ROOT_NAMES do
	if name ~= "Prison" then
		expected[name] = true
	end
end
local ALLOWED =
	{ Prison = "Folder", Terrain = "Terrain", Camera = "Camera", QAReleaseStaging = "Model" }
local function partial()
	editOnly()
	assert(game.PlaceId == PLACE_ID and game.PlaceVersion == 433, "Target identity changed")
	for _, name in ROOT_NAMES do
		local count = countNamed(workspace, name)
		assert(
			count == (if name == "Prison" then 1 else 0),
			"Target has missing/duplicate/already-present root: " .. name
		)
	end
	for _, child in workspace:GetChildren() do
		assert(ALLOWED[child.Name] == child.ClassName, "Unexpected target child: " .. child.Name)
		assert(
			not originals[child.Name] or originals[child.Name] == child,
			"Target original replaced"
		)
	end
	for name, class in ALLOWED do
		local count, child = countNamed(workspace, name)
		assert(count == 1 and child.ClassName == class, "Required target original absent: " .. name)
		if not originals[name] then
			originals[name] = child
		end
	end
	assert(#originals.Prison:GetChildren() > 0, "Prison is empty")
end
partial()
local statusObject = Storage:FindFirstChild("RecoveryResult")
assert(not statusObject or statusObject:IsA("StringValue"), "RecoveryResult name occupied")
if not statusObject then
	statusObject = Instance.new("StringValue")
	statusObject.Name = "RecoveryResult"
	statusObject.Parent = Storage
end
local token = Http:GenerateGUID(false)
_G.RecoveryMapImportActive = token
Storage:SetAttribute("MapRecoveryActive", token)
local created, entries, imported = {}, {}, 0
local preservedReferences, preservedPivots = {}, {}
local report = { schema = 1, sourceVersion = SOURCE_VERSION, status = "PREFLIGHT", imported = 0 }
local function status(phase)
	report.status, report.imported = phase, imported
	statusObject.Value = Http:JSONEncode(report)
end
local function unchangedOriginals()
	editOnly()
	assert(
		_G.RecoveryMapImportActive == token and Storage:GetAttribute("MapRecoveryActive") == token,
		"Recovery guard changed"
	)
	assert(game.PlaceId == PLACE_ID and game.PlaceVersion == 433, "Target identity changed")
	for name, original in originals do
		local count, found = countNamed(workspace, name)
		assert(count == 1 and found == original, "Existing world changed: " .. name)
	end
end
local ok, err = xpcall(function()
	status("DOWNLOAD")
	local manifest = Http:JSONDecode(request("GET", "/manifest.json"))
	assert(
		manifest.schema == 1
			and manifest.sourceVersion == SOURCE_VERSION
			and manifest.sourcePlaceId == PLACE_ID,
		"Wrong source manifest"
	)
	assert(
		type(manifest.roots) == "table" and #manifest.roots == 29,
		"Manifest must contain exactly29 roots"
	)
	local seen = {}
	for _, entry in manifest.roots do
		assert(
			type(entry.name) == "string" and expected[entry.name] and not seen[entry.name],
			"Unexpected/duplicate manifest root"
		)
		assert(entry.class == "Folder" and entry.descendants > 0, "Invalid manifest root")
		seen[entry.name] = true
	end
	local body = request("GET", "/map.rbxm")
	local bytes = buffer.fromstring(body)
	body = nil
	assert(
		buffer.len(bytes) == manifest.bytes and sha256(bytes) == manifest.sha256,
		"Native backup length/hash mismatch"
	)
	report.bytes, report.sha256 = manifest.bytes, manifest.sha256
	partial()
	status("DESERIALIZE")
	created = Codec:DeserializeInstancesAsync(bytes)
	bytes = nil
	assert(#created == 29, "Native data must decode to29 roots")
	local byName = {}
	for _, root in created do
		assert(
			root.Parent == nil and expected[root.Name] and not byName[root.Name],
			"Unexpected/attached/duplicate decoded root"
		)
		byName[root.Name] = root
	end
	status("VERIFY_DETACHED")
	for _, wanted in manifest.roots do
		local root = assert(byName[wanted.name], "Decoded root missing")
		local actual = describe(root)
		if not equal(actual, wanted) then
			local fields, keys = {}, {}
			for key in actual do
				keys[key] = true
			end
			for key in wanted do
				keys[key] = true
			end
			for key in keys do
				if not equal(actual[key], wanted[key]) then
					fields[key] = { actual = actual[key], wanted = wanted[key] }
				end
			end
			report.mismatch = { root = wanted.name, fields = fields }
			status("VERIFY_DETACHED_MISMATCH")
			error("Decoded manifest mismatch: " .. wanted.name)
		end
	end
	partial()
	-- Partition in linear time. Small subtrees remain intact, especially Humanoid rigs:
	-- temporarily exposing an incomplete rig makes Roblox auto-create repair joints.
	local BATCH_SIZE = 1000
	local planned = 0
	status("PLAN_SUBTREES")
	for _, wanted in manifest.roots do
		local root = byName[wanted.name]
		local queue, sizes, protectedRigs, head = { root }, { [root] = 1 }, {}, 1
		while head <= #queue do
			local object = queue[head]
			head += 1
			if object:IsA("Humanoid") then
				local ancestor = object.Parent
				while ancestor and not ancestor:IsA("Model") do
					ancestor = ancestor.Parent
				end
				assert(ancestor, "Humanoid without a containing Model")
				protectedRigs[ancestor] = true
			end
			for _, child in object:GetChildren() do
				if ignoredEngineStatus(child) then
					continue
				end
				table.insert(queue, child)
				sizes[child] = 1
			end
			if head % BATCH_SIZE == 0 then
				task.wait()
				unchangedOriginals()
			end
		end
		for index = #queue, 2, -1 do
			local object = queue[index]
			sizes[object.Parent] += sizes[object]
			if index % BATCH_SIZE == 0 then
				task.wait()
				unchangedOriginals()
			end
		end
		local function partition(object, parent)
			planned += 1
			if planned % BATCH_SIZE == 0 then
				task.wait()
				unchangedOriginals()
			end
			if sizes[object] <= BATCH_SIZE then
				table.insert(entries, { object = object, parent = parent, weight = sizes[object] })
				return
			end
			assert(
				not protectedRigs[object],
				"Oversized Humanoid rig; refusing to split: " .. object:GetFullName()
			)
			assert(
				object:IsA("Folder") or object:IsA("Model"),
				"Oversized indivisible subtree: " .. object:GetFullName()
			)
			table.insert(entries, { object = object, parent = parent, weight = 1 })
			local refs = references(object)
			if next(refs) then
				table.insert(preservedReferences, { object = object, properties = refs })
			end
			if object:IsA("Model") then
				table.insert(preservedPivots, { object = object, worldPivot = object.WorldPivot })
			end
			for _, child in object:GetChildren() do
				if not ignoredEngineStatus(child) then
					partition(child, object)
				end
			end
		end
		partition(root, workspace)
	end
	report.subtrees = #entries
	status("DETACH_SUBTREES")
	for index = #entries, 1, -1 do
		entries[index].object.Parent = nil
		if index % 1000 == 0 then
			task.wait()
			unchangedOriginals()
		end
	end
	status("MOUNT")
	local batchWeight = 0
	for _, entry in entries do
		if batchWeight + entry.weight > BATCH_SIZE then
			status("MOUNT")
			task.wait()
			batchWeight = 0
		end
		if batchWeight == 0 or entry.parent == workspace then
			unchangedOriginals()
		end
		assert(
			entry.parent ~= workspace or not workspace:FindFirstChild(entry.object.Name),
			"Append-only root collision"
		)
		entry.object.Parent = entry.parent
		imported += entry.weight
		batchWeight += entry.weight
	end
	unchangedOriginals()
	status("RESTORE_REFERENCES")
	for index, saved in preservedPivots do
		saved.object.WorldPivot = saved.worldPivot
		if index % 1000 == 0 then
			task.wait()
			unchangedOriginals()
		end
	end
	for index, saved in preservedReferences do
		for property, target in saved.properties do
			if saved.object[property] ~= target then
				saved.object[property] = target
			end
		end
		if index % 1000 == 0 then
			task.wait()
			unchangedOriginals()
		end
	end
	status("VERIFY_MOUNTED")
	for _, wanted in manifest.roots do
		local count, root = countNamed(workspace, wanted.name)
		local actual = if root then describe(root) else {}
		if count ~= 1 or root ~= byName[wanted.name] or not equal(actual, wanted) then
			local fields, keys = {}, {}
			for key in actual do
				keys[key] = true
			end
			for key in wanted do
				keys[key] = true
			end
			for key in keys do
				if not equal(actual[key], wanted[key]) then
					fields[key] = { actual = actual[key], wanted = wanted[key] }
				end
			end
			report.mismatch = {
				phase = "MOUNTED",
				root = wanted.name,
				fields = fields,
				count = count,
				identityMatches = root == byName[wanted.name],
			}
			status("VERIFY_MOUNTED_MISMATCH")
			error("Mounted root mismatch: " .. wanted.name)
		end
	end
	unchangedOriginals()
	for _, name in ROOT_NAMES do
		assert(countNamed(workspace, name) == 1, "Full map validation failed: " .. name)
	end
	report.roots = #created
	status("COMPLETE")
end, debug.traceback)
if not ok then
	-- Only instances returned by THIS deserialize are eligible for rollback.
	-- Some children may be detached, so destroy entries as well as their new roots.
	for index = #entries, 1, -1 do
		pcall(function()
			entries[index].object:Destroy()
		end)
		if index % 1000 == 0 then
			pcall(task.wait)
		end
	end
	for _, root in created do
		pcall(function()
			root:Destroy()
		end)
	end
	report.error = tostring(err)
	status("ROLLED_BACK")
end
_G.RecoveryMapImportActive = nil
Storage:SetAttribute("MapRecoveryActive", nil)
assert(ok, tostring(err))
return report
