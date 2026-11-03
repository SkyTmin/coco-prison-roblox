--!nocheck
-- Lune, repository root. Actual BlockBody factory/JSON and actual melee keys, without Roblox services.
-- Geometry regression only; native contact/ladder/jump QA is separate.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local body = serde.decode("json", fs.readFile("src/shared/Models/player.json"))
local modules = { player = body, BlockFaces = {} }
local shared = { Models = { player = "player" }, BlockFaces = "BlockFaces" }
local environment = {
	game = {
		GetService = function()
			return {
				WaitForChild = function()
					return shared
				end,
			}
		end,
	},
	require = function(key)
		return assert(modules[key], key)
	end,
	Instance = rb.Instance,
	Vector3 = rb.Vector3,
	CFrame = rb.CFrame,
	Color3 = rb.Color3,
	Enum = rb.Enum,
}
setmetatable(environment, { __index = getfenv() })
local function load(path)
	local chunk = assert(loadstring(fs.readFile(path), "@" .. path))
	setfenv(chunk, environment)
	return chunk()
end
local BlockBody = load("src/server/Services/BlockBody.luau")
local Swings = load("src/shared/SwingAnimations.luau")
local checks, evidence = {}, {}
local function check(name, condition)
	assert(condition, name)
	table.insert(checks, name)
end
local character = BlockBody.build("QACharacter", true)
local root = character:FindFirstChild("HumanoidRootPart")
local rootCF = root.CFrame
local function pose(animation, progress)
	local frames = { HumanoidRootPart = rootCF }
	for _, joint in body.joints do
		local name, from, to = joint[1], joint[2], joint[3]
		local motor = character:FindFirstChild(to):FindFirstChild(name)
		frames[to] = frames[from]
			* motor.C0
			* (Swings.sample(animation, name, progress) or rb.CFrame.identity)
			* motor.C1:Inverse()
	end
	return frames
end
local function forward(cf, size)
	local half = size / 2
	return cf.Position.Z
		- math.abs(cf.RightVector.Z) * half.X
		- math.abs(cf.UpVector.Z) * half.Y
		- math.abs(cf.LookVector.Z) * half.Z
end
local head = character:FindFirstChild("Head")
local idleForward = forward(head.CFrame, head.Size)
for name, animation in Swings.animations do
	local maximum = 0
	for i = 0, 100 do
		maximum = math.max(maximum, idleForward - forward(pose(animation, i / 100).Head, head.Size))
	end
	evidence[name] = { animatedHeadForwardExcursionStuds = maximum }
end
check(
	"original mining head penetrates wall by over half a stud",
	evidence.slam.animatedHeadForwardExcursionStuds > 0.5
)
local proxy = character:FindFirstChild("HeadCollision")
if proxy then
	check(
		"collision proxy preserves head bounds",
		proxy.Size == head.Size and proxy.CFrame == head.CFrame
	)
	check(
		"rigid proxy remains collidable",
		proxy.CanCollide and proxy.Transparency == 1 and proxy.Massless
	)
	check(
		"head collision is directly root welded",
		proxy:FindFirstChildOfClass("WeldConstraint").Part0 == root
	)
	check(
		"animated head and torso do not collide",
		not head.CanCollide
			and not character.UpperTorso.CanCollide
			and not character.LowerTorso.CanCollide
	)
	check(
		"root keeps original size and movement envelope",
		(root.Size - rb.Vector3.new(2, body.root.size[2] * body.px, 1)).Magnitude < 1e-4
	)
	check("visual/hit rig keeps normal querying", head.CanQuery and character.UpperTorso.CanQuery)
	local npc = BlockBody.build("QANpc")
	check(
		"NPC default keeps its original colliders",
		npc.Head.CanCollide
			and npc.UpperTorso.CanCollide
			and npc.LowerTorso.CanCollide
			and npc:FindFirstChild("HeadCollision") == nil
	)
	npc:Destroy()
else
	evidence.fixNotApplied = true
end
local registered, collisionPairs = { Default = true }, {}
local physics = {
	IsCollisionGroupRegistered = function(_, name)
		return registered[name] == true
	end,
	RegisterCollisionGroup = function(_, name)
		registered[name] = true
	end,
	CollisionGroupSetCollidable = function(_, a, b, collides)
		check("registered group pair " .. a .. "/" .. b, registered[a] and registered[b])
		collisionPairs[a .. "/" .. b], collisionPairs[b .. "/" .. a] = collides, collides
	end,
}
environment.game = {
	GetService = function(_, name)
		return if name == "PhysicsService" then physics else {}
	end,
}
local Groups = load("src/server/Services/CollisionGroups.luau")
local added
local wrapper = {
	GetDescendants = function()
		return character:GetDescendants()
	end,
	DescendantAdded = {
		Connect = function(_, callback)
			added = callback
		end,
	},
}
Groups.player(wrapper)
check("visual head is collision-filtered", head.CollisionGroup == "PlayerVisuals")
check(
	"solid root and proxy retain player group",
	root.CollisionGroup == "Players" and proxy.CollisionGroup == "Players"
)
check(
	"world cannot collide with animated torso after Humanoid restores CanCollide",
	collisionPairs[character.UpperTorso.CollisionGroup .. "/Default"] == false
)
check("player-mob pass-through retained", collisionPairs["Players/Mobs"] == false)
check("player world collision retained", collisionPairs["Players/Default"] ~= false)
local addedVisual = rb.Instance.new("Part")
addedVisual:SetAttribute("BlockBodyVisual", true)
added(addedVisual)
check("later visual parts keep no-contact group", addedVisual.CollisionGroup == "PlayerVisuals")
addedVisual:Destroy()
character:Destroy()
print(serde.encode("json", { passed = #checks, checks = checks, evidence = evidence }, true))
