--!nocheck
-- Spawn top boards [владелец 22.10, скриншоты Prison Classic: «на спавне топы игроков»]: four stone-brick
-- portals on the lawns either side of the spawn plaza, facing the fountain — Топ по крысам, по деньгам,
-- по уровню, по блокам. Each board is a part tagged "TopBoard" (attribute Board); the client draws the table
-- on it (src/client/TopBoards.luau) from ReplicatedStorage.Tops (LeaderboardService).
-- Run in Studio (Edit) after build-prison / decorate-prison. Idempotent: replaces Workspace.Prison.Tops and
-- removes the decoration props standing where the portals go (decorate-prison keeps out of Tops next time).

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")

local root = workspace:FindFirstChild("Prison")
if not root then
	error("[build-tops] run scripts/build-prison.luau first")
end
local old = root:FindFirstChild("Tops")
if old then
	old:Destroy()
end
local tops = Instance.new("Folder")
tops.Name = "Tops"
tops.Parent = root

local STONE = Color3.fromRGB(125, 125, 128)
local DARK = Color3.fromRGB(70, 70, 74)
local BOARD = Color3.fromRGB(28, 26, 26)
local LAMP = Color3.fromRGB(255, 215, 130)

local W, H = 15, 10.5 -- board face (studs)
local BOTTOM = 1.4

local function part(model, name, size, cf, color, variant)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if variant and MaterialService:FindFirstChild(variant) then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = variant
		p.Color = Color3.fromRGB(165, 165, 172) -- the warm brick texture tinted grey, like the original portals
	else
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Parent = model
	return p
end

-- frame: the portal's own space, +Z looks at the fountain
local function portal(id, frame)
	local model = Instance.new("Model")
	model.Name = "Top_" .. id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	part(model, "Step", Vector3.new(W + 6, 1, 4), at(0, 0.5, 0), STONE, "px_stone_bricks")
	for _, s in ipairs({ -1, 1 }) do
		part(model, "Pillar", Vector3.new(2, BOTTOM + H + 1, 2.4), at(s * (W / 2 + 1), (BOTTOM + H + 1) / 2 + 1, 0), STONE, "px_stone_bricks")
		part(model, "PillarCap", Vector3.new(2.6, 0.6, 3), at(s * (W / 2 + 1), BOTTOM + H + 2.3, 0), DARK, "px_smooth_stone")
		-- a lantern on each pillar
		local lamp = part(model, "Lantern", Vector3.new(0.9, 1.2, 0.9), at(s * (W / 2 + 1), BOTTOM + H + 3.2, 0.6), LAMP)
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 0.8
		light.Color = LAMP
		light.Parent = lamp
	end
	part(model, "Lintel", Vector3.new(W + 2, 2.2, 2.6), at(0, BOTTOM + H + 2.1, 0), STONE, "px_stone_bricks")
	part(model, "LintelTop", Vector3.new(W + 4, 0.6, 3.2), at(0, BOTTOM + H + 3.5, 0), DARK, "px_smooth_stone")
	part(model, "Sill", Vector3.new(W + 0.4, 0.6, 2.6), at(0, BOTTOM + 0.7, 0), DARK, "px_smooth_stone")
	local board = part(model, "Board", Vector3.new(W, H, 0.6), at(0, BOTTOM + 1 + H / 2, 0), BOARD)
	board.Material = Enum.Material.SmoothPlastic
	board:SetAttribute("Board", id)
	CollectionService:AddTag(board, "TopBoard")
	model.PrimaryPart = board
	model.Parent = tops
	return model
end

-- lawns west and east of the plaza (plaza edge x = ±45, ring road beyond), two boards each, facing x = 0
local spots = {
	{ "rats", Vector3.new(-56, 0, -23), 1 },
	{ "money", Vector3.new(-56, 0, 23), 1 },
	{ "level", Vector3.new(56, 0, -23), -1 },
	{ "blocks", Vector3.new(56, 0, 23), -1 },
}
local removed = 0
local decor = root:FindFirstChild("Decor")
for _, s in ipairs(spots) do
	local pos, dir = s[2], s[3]
	local frame = CFrame.lookAt(pos, pos + Vector3.new(dir, 0, 0)) * CFrame.Angles(0, math.pi, 0)
	-- clear the props in the footprint (plus a little room in front)
	if decor then
		local box = CFrame.new(pos + Vector3.new(dir * 2, 8, 0))
		for _, p in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(9, 16, W + 8))) do
			if p:IsDescendantOf(decor) then
				local top = p
				while top.Parent ~= decor do
					top = top.Parent
				end
				if top.Parent then
					-- loose parts of one prop (a lamp's pole, arm, head) share its x/z: take the whole prop
					if top:IsA("BasePart") then
						local at = Vector2.new(top.Position.X, top.Position.Z)
						for _, other in ipairs(decor:GetChildren()) do
							if other ~= top and other:IsA("BasePart") and (Vector2.new(other.Position.X, other.Position.Z) - at).Magnitude < 2.5 then
								other:Destroy()
							end
						end
					end
					top:Destroy()
					removed += 1
				end
			end
		end
	end
	portal(s[1], frame)
end
return ("[build-tops] 4 boards, %d props cleared"):format(removed)
