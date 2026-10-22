--!nocheck
-- Dresses the place for a location preview photo and undoes it [владелец 22.10: «превью — вид с высоты под
-- углом, как будто человек стоит в воздухе и смотрит; без чужих объектов»]. Run via studio-loader in Edit:
--   ServerStorage.PreviewMode (StringValue) = "fraction_base" | "quarry" | "prison" → hides the other locations (parked in
--   ServerStorage), fills the empty mine pits with their main block, hides the quarry cave roof, clears the
--   haze and points the camera; then take the screen_capture;
--   PreviewMode = "restore" (or no value) → puts everything back (always run it before saving the place).
local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config:Clone())
local modeValue = game.ServerStorage:FindFirstChild("PreviewMode")
local mode = if modeValue and modeValue.Value ~= "" then modeValue.Value else "restore"
local FOLDERS = { prison = "Prison", quarry = "Quarry", fraction_base = "FactionBase" }
-- camera: position, look-at (an elevated three-quarter view of the whole location)
local SHOTS = {
	prison = { Vector3.new(0, 190, 250), Vector3.new(0, 0, 20) },
	quarry = { Vector3.new(751, 190, 250), Vector3.new(751, 0, 10) },
	fraction_base = { Vector3.new(-700, 380, 520), Vector3.new(-700, 0, 40) },
}

local function restore()
	local park = game.ServerStorage:FindFirstChild("__Parked")
	if park then
		for _, c in ipairs(park:GetChildren()) do
			c.Parent = workspace
		end
		park:Destroy()
	end
	local quarry = workspace:FindFirstChild("Quarry")
	for _, p in ipairs(quarry and quarry:GetDescendants() or {}) do
		if p:IsA("BasePart") and p:GetAttribute("__T") ~= nil then
			p.Transparency = p:GetAttribute("__T")
			p:SetAttribute("__T", nil)
		end
	end
	local atm = game.Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and atm:GetAttribute("__D") then
		atm.Density = atm:GetAttribute("__D")
		atm:SetAttribute("__D", nil)
	end
	local fill = workspace:FindFirstChild("__PreviewFill")
	if fill then
		fill:Destroy()
	end
end

restore()
if mode == "restore" then
	return "[preview-shot] restored"
end
local shot = SHOTS[mode]
if not shot then
	return "[preview-shot] unknown location " .. tostring(mode)
end
local fill = Instance.new("Folder")
fill.Name = "__PreviewFill"
fill.Parent = workspace
for _, a in ipairs(CS:GetTagged("MineAnchor")) do
	if a:GetAttribute("LocationId") == mode and a:IsDescendantOf(workspace) then
		local loc = Config.location(mode)
		local shares = loc and loc.mine.shares
		local override = loc and loc.mines and loc.mines[a:GetAttribute("MineId")]
		if override and override.shares then
			shares = override.shares
		end
		local best, bestShare = nil, -1
		for id, share in pairs(shares or {}) do
			if share > bestShare and id ~= "air" then
				best, bestShare = id, share
			end
		end
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(a.Size.X, 1, a.Size.Z)
		p.CFrame = a.CFrame * CFrame.new(0, a.Size.Y / 2 - 0.5, 0)
		p.Material = Enum.Material.Plastic
		if best and MS:FindFirstChild("px_" .. best) then
			p.MaterialVariant = "px_" .. best
			p.Color = Color3.new(1, 1, 1)
		end
		p.Parent = fill
	end
end
if mode == "quarry" then -- the roof off, the walls stay
	for _, p in ipairs(workspace.Quarry.Cave:GetDescendants()) do
		if
			p:IsA("BasePart")
			and (
				p.Name:match("^Stalactite")
				or p.Name == "Chain"
				or p.Name == "HangingLantern"
				or (p.Name == "CaveVault" and p.Position.Y - p.Size.Y / 2 >= 1)
			)
		then
			p:SetAttribute("__T", p.Transparency)
			p.Transparency = 1
		end
	end
end
local atm = game.Lighting:FindFirstChildOfClass("Atmosphere")
if atm then
	atm:SetAttribute("__D", atm.Density)
	atm.Density = 0.05
end
local park = Instance.new("Folder")
park.Name = "__Parked"
park.Parent = game.ServerStorage
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("Folder") and c.Name ~= FOLDERS[mode] and c.Name ~= "__PreviewFill" then
		c.Parent = park
	end
end
workspace.CurrentCamera.CFrame = CFrame.lookAt(shot[1], shot[2])
return "[preview-shot] ready: " .. mode
