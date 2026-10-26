--!strict
-- Our block body (assets/models/player/player.py -- export → Shared.Models.player): the rig and the pixel plates.
-- AvatarService dresses the players in it, NpcBodyService the NPCs (assets/models/npc/npc.py → Shared.Models.npcs).
-- The rig keeps the R15 part and joint names (Motor6D). A face's pixel details are thin plates: every rectangle list
-- given for the face is painted over the part's base role into one grid, then merged into greedy rectangles, so no
-- plates overlap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockFaces = require(Shared.BlockFaces)
local Body = require(Shared.Models.player) :: any

local BlockBody = {}

BlockBody.Body = Body
BlockBody.Faces = BlockFaces
BlockBody.PX = Body.px :: number -- studs per skin pixel
local PX: number = Body.px
local PLATE = 0.02 -- studs: the detail plates stand this far out of the faces
-- the root part as wide and deep as a Roblox one: doors, gaps and ladders were built for it
local ROOT_SIZE = Vector3.new(2, Body.root.size[2] * PX, 1)
local COLLIDE = { Head = true, UpperTorso = true, LowerTorso = true }

export type Rect = { any } -- { col, row, w, h, role }
export type Colours = { [string]: Color3 }

function BlockBody.vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
local vec = BlockBody.vec

local function abs(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

-- the face grid's width and height in pixels for a part of `size` px
local function faceDims(size: Vector3, face: string): (number, number)
	if face == "front" or face == "back" then
		return size.X, size.Y
	elseif face == "right" or face == "left" then
		return size.Z, size.Y
	end
	return size.X, size.Z
end

-- ---------------------------------------------------------------- the rig
-- A new body standing on y = 0 (its HumanoidRootPart included); centres in px are in Body.parts / Body.root.
function BlockBody.build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = Body.hipHeight * PX
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = model
	local parts: { [string]: BasePart } = {}
	local centres: { [string]: Vector3 } = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	centres.HumanoidRootPart = vec(Body.root.pos)
	root.CFrame = CFrame.new(centres.HumanoidRootPart * PX)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	root.Parent = model
	parts.HumanoidRootPart = root
	model.PrimaryPart = root
	for partName, data in pairs(Body.parts) do
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = vec(data.size) * PX
		centres[partName] = vec(data.pos)
		part.CFrame = CFrame.new(centres[partName] * PX)
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CanCollide = COLLIDE[partName] == true
		part:SetAttribute("Role", data.base)
		part.Parent = model
		parts[partName] = part
	end
	for _, joint in ipairs(Body.joints) do
		local jointName, from, to, pivot = joint[1], joint[2], joint[3], vec(joint[4])
		local motor = Instance.new("Motor6D")
		motor.Name = jointName
		motor.Part0, motor.Part1 = parts[from], parts[to]
		motor.C0 = CFrame.new((pivot - centres[from]) * PX)
		motor.C1 = CFrame.new((pivot - centres[to]) * PX)
		motor.Parent = parts[to]
	end
	model:SetAttribute("BlockBody", true)
	return model
end

-- ---------------------------------------------------------------- the plates
-- Paints `part` (size in px) in its base role and its faces' rectangle lists. Plates of a `glow` role are Neon.
-- anchored: the plates are anchored (a static NPC) instead of welded to the part (a moving character).
function BlockBody.paint(
	part: BasePart,
	sizePx: Vector3,
	base: string,
	lists: { [string]: { { Rect }? } },
	colours: Colours,
	anchored: boolean,
	glow: { [string]: boolean }?
)
	for _, child in ipairs(part:GetChildren()) do
		if child.Name == "Px" then
			child:Destroy()
		end
	end
	part.Color = colours[base] or Color3.new(1, 0, 1)
	if glow and glow[base] then
		part.Material = Enum.Material.Neon
	end
	local half = part.Size / 2
	for face, geometry in pairs(BlockFaces) do
		local faceLists = lists[face]
		if not faceLists then
			continue
		end
		local w, h = faceDims(sizePx, face)
		local grid: { { string } } = {}
		for r = 1, h do
			grid[r] = table.create(w, base)
		end
		local painted = false
		for _, rects in ipairs(faceLists) do
			for _, rect in ipairs(rects :: { Rect }) do
				local c, r, rw, rh, role = rect[1], rect[2], rect[3], rect[4], rect[5]
				for y = r + 1, r + rh do
					for x = c + 1, c + rw do
						grid[y][x] = role
					end
				end
				painted = true
			end
		end
		if not painted then
			continue
		end
		-- greedy rectangles of everything that is not the base colour
		local done: { { boolean } } = {}
		for r = 1, h do
			done[r] = table.create(w, false)
		end
		local origin = geometry.tl * half
		for r = 1, h do
			for c = 1, w do
				local role = grid[r][c]
				if done[r][c] or role == base then
					continue
				end
				local rw = 1
				while c + rw <= w and not done[r][c + rw] and grid[r][c + rw] == role do
					rw += 1
				end
				local rh = 1
				while r + rh <= h do
					local same = true
					for i = 0, rw - 1 do
						if done[r + rh][c + i] or grid[r + rh][c + i] ~= role then
							same = false
							break
						end
					end
					if not same then
						break
					end
					rh += 1
				end
				for y = r, r + rh - 1 do
					for x = c, c + rw - 1 do
						done[y][x] = true
					end
				end
				local plate = Instance.new("Part")
				plate.Name = "Px"
				plate.Size = abs(geometry.right) * rw * PX
					+ abs(geometry.down) * rh * PX
					+ abs(geometry.normal) * PLATE
				local centre = origin
					+ geometry.right * (c - 1 + rw / 2) * PX
					+ geometry.down * (r - 1 + rh / 2) * PX
					+ geometry.normal * PLATE / 2
				plate.CFrame = part.CFrame * CFrame.new(centre)
				plate.Color = colours[role] or Color3.new(1, 0, 1)
				plate.Material = if glow and glow[role]
					then Enum.Material.Neon
					else Enum.Material.SmoothPlastic
				plate.TopSurface, plate.BottomSurface =
					Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				plate.CanCollide, plate.CanQuery, plate.CanTouch = false, false, false
				plate.Massless = true
				plate.CastShadow = false
				if anchored then
					plate.Anchored = true
				else
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = part, plate
					weld.Parent = plate
				end
				plate.Parent = part
			end
		end
	end
end

return BlockBody
