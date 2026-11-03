--!nocheck
-- Execute the real asset-free arrow renderer; mock only Instances/raycast boundary.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local made, rays = 0, 0
local function node(kind)
	made += 1
	local properties = { ClassName = kind, children = {}, attributes = {} }
	local object
	object = setmetatable({}, {
		__index = properties,
		__newindex = function(_, key, value)
			if key == "Parent" then
				if properties.Parent then
					local at = table.find(properties.Parent.children, object)
					if at then
						table.remove(properties.Parent.children, at)
					end
				end
				if value then
					table.insert(value.children, object)
				end
			end
			properties[key] = value
		end,
	})
	function properties:GetChildren()
		return table.clone(self.children)
	end
	function properties:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function properties:GetAttribute(key)
		return self.attributes[key]
	end
	function properties:Destroy()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		self.Parent = nil
		self.Destroyed = true
	end
	return object
end
local world = node("Workspace")
function world:Raycast(origin, _direction, params)
	rays += 1
	assert(params.RespectCanCollide == true)
	return { Position = rb.Vector3.new(origin.X, 0, origin.Z) }
end
local source = fs.readFile("src/client/TutorialPath.luau")
local fn = assert(loadstring(source))
setfenv(
	fn,
	setmetatable({
		workspace = world,
		Instance = { new = node },
		Vector3 = rb.Vector3,
		CFrame = rb.CFrame,
		Enum = rb.Enum,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
	}, { __index = getfenv() })
)
local Path = fn()
local checks = {}
local function check(name, passed)
	assert(passed, name)
	table.insert(checks, name)
end
check(
	"renderer has no asset dependency",
	not source:find("rbxasset", 1, true) and not source:find("Texture", 1, true)
)
for _, distance in { 0, 1, 3, 3.00001, 8, 48, 240, 10000 } do
	local points, direction = Path.points(rb.Vector3.zero, rb.Vector3.new(distance, 0, 0), 23)
	check(
		tostring(distance) .. " bounded point count",
		#points <= 12 and (#points == 0) == (distance <= 3)
	)
	for _, point in points do
		check(
			tostring(distance) .. " finite point between endpoints",
			point.X == point.X
				and point.X > 0
				and point.X < distance
				and direction:Dot(rb.Vector3.xAxis) > 0.99
		)
	end
end
local path = Path.new(rb.Color3.fromRGB(255, 215, 65))
path.Update(rb.Vector3.new(0, 3, 0), rb.Vector3.new(240, 3, 0), nil, 10)
check(
	"long route makes only36parts",
	#path.folder:GetChildren() == 36 and path.folder:GetAttribute("VisibleArrows") == 12
)
check("ground projection uses at most12rays", rays == 12)
local counts = {}
for _, part in path.folder:GetChildren() do
	counts[part.Name] = (counts[part.Name] or 0) + 1
	check(
		part.Name .. " is passive client geometry",
		part.Anchored
			and not part.CanCollide
			and not part.CanTouch
			and not part.CanQuery
			and not part.CastShadow
	)
	check(
		part.Name .. " lies just above real ground",
		part.CFrame.Position.Y >= 0.09 and part.CFrame.Position.Y <= 0.15
	)
end
check(
	"every arrow has shaft and both wings",
	counts.Shaft == 12 and counts.LeftWing == 12 and counts.RightWing == 12
)
local initialMade, initialRays = made, rays
path.Update(rb.Vector3.new(1, 3, 0), rb.Vector3.new(240, 3, 0), nil, 10.05)
check(
	"5Hz gate skips extra transforms raycasts and allocations",
	made == initialMade and rays == initialRays
)
path.Update(rb.Vector3.new(1, 3, 0), rb.Vector3.new(25, 3, 0), nil, 11)
check(
	"shorter path reuses pool",
	made == initialMade and path.folder:GetAttribute("VisibleArrows") == 6
)
local visible = 0
for _, part in path.folder:GetChildren() do
	if part.Transparency < 1 then
		visible += 1
	end
end
check("unused arrows hidden after shortening path", visible == 18)
path.Update(rb.Vector3.zero, rb.Vector3.new(0, 40, 0), nil, 12)
check(
	"vertical or close target hides all ground arrows",
	path.folder:GetAttribute("VisibleArrows") == 0
)
path.Destroy()
check(
	"cleanup removes every arrow and its container",
	#world:GetChildren() == 0 and path.folder.Destroyed
)
print(
	serde.encode(
		"json",
		{ status = "PASS", count = #checks, checks = checks, nativeRendering = false },
		true
	)
)
