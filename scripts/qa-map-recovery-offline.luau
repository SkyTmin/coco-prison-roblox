--!nocheck
-- Actual recovery scripts; fake local transport/native codec boundary, synthetic instances only.
-- Does not open Studio, touch backups, or claim to test Roblox's native codec.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local sources = {
	export = fs.readFile("scripts/recover-map-export.luau"),
	import = fs.readFile("scripts/recover-map-import.luau"),
}
local names = {
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
local checks = {}
local function check(label, value)
	assert(value, label)
	table.insert(checks, label)
end
local function new(class, name, parent)
	local item = rb.Instance.new(class)
	item.Name, item.Parent = name, parent
	return item
end
local function fixture(full)
	local model = rb.Instance.new("DataModel")
	local workspace, storage = model:GetService("Workspace"), model:GetService("ServerStorage")
	for _, name in names do
		if full or name == "Prison" then
			local root = new("Folder", name, workspace)
			root:SetAttribute("GeometrySentinel", name)
			local m = new("Model", "NPC", root)
			m.WorldPivot = rb.CFrame.new(3, 4, 5)
			local part = new("Part", "Root", m)
			part.CFrame, part.Size = rb.CFrame.new(10, 20, 30), rb.Vector3.new(4, 4, 4)
			part:SetAttribute("LocationId", name)
			m.PrimaryPart = part
			new("Humanoid", "Humanoid", m)
			local value = new("ObjectValue", "Target", root)
			value.Value = part
		end
	end
	if full then
		workspace.Quarry:SetAttribute("WorldBaseY", 37500)
		workspace.Quarry:SetAttribute("Revision", "2026-11-03-open-air-accepted")
		local large = new("Model", "LargeStructure", workspace.Basement)
		large.WorldPivot = rb.CFrame.new(13, 14, 15)
		large.PrimaryPart = new("Part", "PivotPart", large)
		for i = 1, 1010 do
			new("Folder", "Batch" .. i, large)
		end
	else
		new("Model", "QAReleaseStaging", workspace)
		new("Terrain", "Terrain", workspace)
		new("Camera", "Camera", workspace)
		new("BindableFunction", "QAReleaseMapLease", storage)
	end
	local code = new("Folder", "CurrentCodeSentinel", storage)
	return { model = model, workspace = workspace, storage = storage, code = code }
end
local function hash(body)
	return serde.hash("sha256", body)
end
local function hashBuffer(body)
	local hex, bytes = hash(body), buffer.create(32)
	for i = 0, 31 do
		buffer.writeu8(bytes, i, tonumber(hex:sub(i * 2 + 1, i * 2 + 2), 16))
	end
	return bytes
end
local backup, sourceRoots = {}, {}
local function execute(kind, f, options)
	options = options or {}
	local state = { requests = 0, yields = 0 }
	local globals = {}
	local services = {
		RunService = {
			IsStudio = function()
				return not options.notStudio
			end,
			IsRunning = function()
				return options.running == true
			end,
		},
		ServerStorage = f.storage,
		CollectionService = {
			GetTags = function()
				return {}
			end,
		},
		EncodingService = {
			ComputeBufferHash = function(_, bytes)
				return hashBuffer(buffer.tostring(bytes))
			end,
		},
	}
	services.HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, v)
			return serde.decode("json", v)
		end,
		GenerateGUID = function()
			return "isolated-test-token"
		end,
		RequestAsync = function(_, request)
			state.requests += 1
			check("transport is loopback 8778", request.Url:sub(1, 21) == "http://127.0.0.1:8778")
			local route = request.Url:match("8778(.+)")
			if request.Method == "POST" then
				backup[route] = request.Body
				return {
					Success = true,
					Body = serde.encode(
						"json",
						{ saved = true, bytes = #request.Body, sha256 = hash(request.Body) }
					),
				}
			end
			local body = assert(backup[route], route)
			if options.corruptBytes and route == "/map.rbxm" then
				body ..= "x"
			end
			if options.corruptManifest and route == "/manifest.json" then
				local decoded = serde.decode("json", body)
				decoded.roots[1].name = "Prison"
				body = serde.encode("json", decoded)
			end
			return { Success = true, Body = body }
		end,
	}
	services.SerializationService = {
		SerializeInstancesAsync = function(_, roots)
			sourceRoots = roots
			return buffer.fromstring("synthetic native-codec boundary")
		end,
		DeserializeInstancesAsync = function()
			local roots = {}
			for _, root in sourceRoots do
				table.insert(roots, root:Clone())
			end
			state.decoded = roots
			if options.decodedMismatch then
				roots[1]:SetAttribute("GeometrySentinel", "tampered")
			end
			return roots
		end,
	}
	local env = setmetatable({
		game = {
			Name = options.wrongName and "Wrong" or "Place1 (Version 428)",
			PlaceId = options.placeId or (kind == "export" and 0 or 92594200898716),
			PlaceVersion = options.version or (kind == "export" and 0 or 433),
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		workspace = f.workspace,
		Instance = rb.Instance,
		_G = globals,
		Enum = { HashAlgorithm = { Sha256 = "Sha256" } },
		task = {
			wait = function()
				state.yields += 1
				if options.clearModelRefs then
					local report = f.storage:FindFirstChild("RecoveryResult")
					if report and serde.decode("json", report.Value).status == "MOUNT" then
						options.clearModelRefs = false
						state.simulatedClears = 0
						for _, root in state.decoded do
							for _, child in root:GetDescendants() do
								if child:IsA("Model") and child.Name == "LargeStructure" then
									-- Lune cannot assign nil to a Ref; invalidate with a foreign reference.
									child.PrimaryPart = f.workspace.Prison.NPC.Root
									child.WorldPivot = rb.CFrame.new()
									state.simulatedClears += 1
								end
							end
						end
					end
				end
				if options.failMount then
					local report = f.storage:FindFirstChild("RecoveryResult")
					if report and serde.decode("json", report.Value).status == "MOUNT" then
						options.failMount = false
						error("injected mount interruption")
					end
				end
			end,
		},
	}, { __index = getfenv() })
	local executable = sources[kind]
	if kind == "import" then
		-- Observe the actual native parenting boundary without replacing the planner.
		local before = "entry.object.Parent = entry.parent"
		local at = assert(executable:find(before, 1, true))
		executable = executable:sub(1, at - 1)
			.. "__observeMount(entry.object,entry.parent,entry.weight)\n"
			.. executable:sub(at)
		env.__observeMount = function(object, _, weight)
			check("parented subtree remains bounded", weight <= 1000)
			check("Humanoid is never individually parented", not object:IsA("Humanoid"))
			local candidates = { object }
			for _, child in object:GetDescendants() do
				table.insert(candidates, child)
			end
			for _, child in candidates do
				if child:IsA("Humanoid") then
					local rig = child.Parent
					check(
						"rig enters workspace complete",
						#rig:GetDescendants() == 2 and rig.PrimaryPart == rig.Root
					)
					state.atomicRigs = (state.atomicRigs or 0) + 1
				end
			end
		end
	end
	local fn = assert(loadstring(executable))
	setfenv(fn, env)
	local ok, result = pcall(fn)
	state.globals = globals
	return ok, result, state
end
local function untouched(f, count)
	return #f.workspace:GetChildren() == count
		and f.code.Parent == f.storage
		and f.workspace.Prison.NPC.PrimaryPart == f.workspace.Prison.NPC.Root
end
for name, source in sources do
	check(name .. " compiles", loadstring(source) ~= nil)
end
local markerStart = "-- BEGIN SHARED RECOVERY CHECKS"
local markerEnd = "-- END SHARED RECOVERY CHECKS"
local function common(source)
	local section = source:sub(
		assert(source:find(markerStart, 1, true)),
		assert(source:find(markerEnd, 1, true))
	)
	-- Export signatures stay byte-identical; importer only compares decoded decimal numbers
	-- semantically to accommodate the engine JSON parser's last-ULP rounding.
	local start = assert(section:find("local function equal", 1, true))
	local finish = assert(section:find("local function attrs", start, true))
	return section:sub(1, start - 1) .. section:sub(finish)
end
check(
	"both scripts use identical manifest algorithm",
	common(sources.export) == common(sources.import)
)
do
	local start = assert(sources.import:find("local function equal", 1, true))
	local finish = assert(sources.import:find("local function attrs", start, true))
	local equal = assert(loadstring(sources.import:sub(start, finish - 1) .. "\nreturn equal"))()
	check(
		"JSON last ULP difference accepted",
		equal({ size = { 0.20000000298023224 } }, { size = { 0.20000000298023225 } })
	)
	check(
		"0.001 stud geometry change rejected",
		not equal({ position = 37500.001 }, { position = 37500.002 })
	)
	check("integer counts stay exact", not equal({ count = 334755 }, { count = 334756 }))
	check("missing dictionary key rejected", not equal({ a = 1, b = 2 }, { a = 1 }))
	check("extra dictionary key rejected", not equal({ a = 1 }, { a = 1, b = 2 }))
	check("digest changes rejected", not equal({ sha256 = "abc" }, { sha256 = "abd" }))
	check("array length difference rejected", not equal({ 1, 2 }, { 1, 2, 3 }))
	check("numeric string does not coerce", not equal({ value = 1 }, { value = "1" }))
	check("false value remains a present key", equal({ value = false }, { value = false }))
end
do
	local start = assert(sources.export:find("local function ignoredEngineStatus", 1, true))
	local finish = assert(sources.export:find("local function describe", start, true))
	local fn =
		assert(loadstring(sources.export:sub(start, finish - 1) .. "\nreturn ignoredEngineStatus"))
	local tags = {}
	setfenv(
		fn,
		setmetatable(
			{ Collection = {
				GetTags = function()
					return tags
				end,
			} },
			{ __index = getfenv() }
		)
	)
	local ignored = fn()
	local attributes, children = {}, {}
	local status = {
		Archivable = false,
		ClassName = "Status",
		Name = "Status",
		Parent = {
			IsA = function(_, class)
				return class == "Humanoid"
			end,
		},
		GetChildren = function()
			return children
		end,
		GetAttributes = function()
			return attributes
		end,
	}
	check("only empty engine-generated Status may be excluded", ignored(status))
	status.Archivable = true
	check("authored archivable Status is not ignored", not ignored(status))
	status.Archivable = false
	status.ClassName = "Folder"
	check("other nonarchivable classes are not ignored", not ignored(status))
	status.ClassName = "Status"
	status.Name = "Different"
	check("differently named Status is not ignored", not ignored(status))
	status.Name = "Status"
	attributes.Important = true
	check("Status with data is not ignored", not ignored(status))
	attributes = {}
	children = { true }
	check("Status with children is not ignored", not ignored(status))
	children = {}
	tags = { "Important" }
	check("tagged Status is not ignored", not ignored(status))
	tags = {}
	status.Parent = {
		IsA = function()
			return false
		end,
	}
	check("Status under other parent is not ignored", not ignored(status))
end
do
	local f = fixture(true)
	local ok, result, state = execute("export", f)
	assert(ok, result)
	check("valid full source exports 29 roots", result.status == "EXPORTED" and result.roots == 29)
	check("source unchanged after export", untouched(f, 30))
	check("export yields for large source", state.yields > 0)
	check("export guard released", not state.globals.RecoveryMapExportActive)
end
for _, case in { "wrongplace", "wrongname", "running", "missing", "lease", "nonarchivable" } do
	local f = fixture(true)
	local options = {}
	if case == "wrongplace" then
		options.placeId = 123
	elseif case == "wrongname" then
		options.wrongName = true
	elseif case == "running" then
		options.running = true
	elseif case == "missing" then
		f.workspace.Quarry:Destroy()
	elseif case == "lease" then
		new("BindableFunction", "QAReleaseMapLease", f.storage)
	elseif case == "nonarchivable" then
		f.workspace.Quarry.NPC.Root.Archivable = false
	end
	local before = #f.workspace:GetDescendants()
	local ok, _, state = execute("export", f, options)
	check("export refuses " .. case, not ok and state.requests == 0)
	check("failed export keeps source " .. case, #f.workspace:GetDescendants() == before)
end
for _, case in
	{
		"wrongplace",
		"wrongversion",
		"running",
		"existing",
		"active",
		"corruptBytes",
		"corruptManifest",
		"decodedMismatch",
	}
do
	local f = fixture(false)
	local options = {}
	if case == "wrongplace" then
		options.placeId = 123
	elseif case == "wrongversion" then
		options.version = 434
	elseif case == "running" then
		options.running = true
	elseif case == "existing" then
		new("Folder", "Quarry", f.workspace)
	elseif case == "active" then
		f.storage:SetAttribute("MapRecoveryActive", "other")
	else
		options[case] = true
	end
	local count = #f.workspace:GetChildren()
	local ok, _, state = execute("import", f, options)
	check("import refuses " .. case, not ok)
	check("failed import retains originals " .. case, untouched(f, count))
	if
		case == "wrongplace"
		or case == "wrongversion"
		or case == "running"
		or case == "existing"
		or case == "active"
	then
		check("early refusal does not contact transport " .. case, state.requests == 0)
	else
		check(
			"failed import clears guard " .. case,
			not f.storage:GetAttribute("MapRecoveryActive")
				and not state.globals.RecoveryMapImportActive
		)
	end
end
do
	local f = fixture(false)
	local ok, result, state = execute("import", f, { clearModelRefs = true })
	assert(ok, result)
	check(
		"simulated Roblox PrimaryPart/WorldPivot invalidation exercised",
		state.simulatedClears and state.simulatedClears > 0
	)
	check("successful import complete", result.status == "COMPLETE" and result.roots == 29)
	check("bounded mount yields", state.yields > 3)
	check("all NPCs parented atomically", state.atomicRigs == 29)
	check(
		"split model PrimaryPart restored",
		f.workspace.Basement.LargeStructure.PrimaryPart
			== f.workspace.Basement.LargeStructure.PivotPart
	)
	check(
		"split model WorldPivot restored",
		f.workspace.Basement.LargeStructure.WorldPivot == rb.CFrame.new(13, 14, 15)
	)
	check("all 30 map roots mounted", #f.workspace:GetChildren() == 33)
	check(
		"original current code and Prison remain",
		f.code.Parent == f.storage
			and f.workspace.Prison.NPC.PrimaryPart == f.workspace.Prison.NPC.Root
	)
	check(
		"legacy lease remains for owner cleanup",
		f.storage:FindFirstChild("QAReleaseMapLease") ~= nil
	)
	for _, name in names do
		local root = f.workspace[name]
		check("PrimaryPart preserved " .. name, root.NPC.PrimaryPart == root.NPC.Root)
		check("ObjectValue reference preserved " .. name, root.Target.Value == root.NPC.Root)
		check("WorldPivot preserved " .. name, root.NPC.WorldPivot == rb.CFrame.new(3, 4, 5))
	end
	check(
		"completed guard released",
		not f.storage:GetAttribute("MapRecoveryActive")
			and not state.globals.RecoveryMapImportActive
	)
	local again, _, second = execute("import", f)
	check(
		"second import cannot overwrite",
		not again and second.requests == 0 and #f.workspace:GetChildren() == 33
	)
end
do
	local f = fixture(false)
	local ok, err, state = execute("import", f, { failMount = true })
	check(
		"mid-mount interruption fails",
		not ok and tostring(err):find("injected mount interruption", 1, true)
	)
	check("rollback restores partial target only", untouched(f, 4))
	check(
		"rollback releases active guard",
		not f.storage:GetAttribute("MapRecoveryActive")
			and not state.globals.RecoveryMapImportActive
	)
	check(
		"rollback reported",
		serde.decode("json", f.storage.RecoveryResult.Value).status == "ROLLED_BACK"
	)
	for _, root in state.decoded do
		check("rollback destroys each new root", root.Parent == nil)
	end
end
do
	local oldBackup, oldRoots = backup, sourceRoots
	backup = {}
	local source = fixture(true)
	for index = 1, 1000 do
		new("Folder", "Oversized" .. index, source.workspace.Basement.NPC)
	end
	local exported, message = execute("export", source)
	assert(exported, message)
	local target = fixture(false)
	local ok, failure, state = execute("import", target)
	check(
		"oversized rig is never split",
		not ok and tostring(failure):find("Oversized Humanoid rig", 1, true)
	)
	check(
		"oversized rig fails before mount",
		serde.decode("json", target.storage.RecoveryResult.Value).imported == 0
	)
	check("oversized rig refusal preserves originals", untouched(target, 4))
	check(
		"oversized rig refusal clears guard",
		not target.storage:GetAttribute("MapRecoveryActive")
			and not state.globals.RecoveryMapImportActive
	)
	backup, sourceRoots = oldBackup, oldRoots
end
print(serde.encode("json", {
	status = "PASS",
	checks = #checks,
	scope = "actual scripts with synthetic instances and mocked native codec/HTTP; no Studio",
}))
