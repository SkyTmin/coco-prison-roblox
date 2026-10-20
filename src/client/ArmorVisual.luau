--!strict
-- Cosmetic armor follows each R15 limb; the server owns the Armor attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

type Style = { color: Color3, material: Enum.Material, reflectance: number }
type Rig = { character: Model, connections: { RBXScriptConnection }, visual: Model? }

local ArmorVisual = {}
local rigs: { [Player]: Rig } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local started = false
local PADDING = 0.25
local THICKNESS = 0.125
local TRIM = 0.1
local STYLES: { [string]: Style } = {
	wood = { color = Color3.fromRGB(120, 80, 50), material = Enum.Material.Fabric, reflectance = 0 },
	stone = {
		color = Color3.fromRGB(120, 120, 125),
		material = Enum.Material.Slate,
		reflectance = 0,
	},
	iron = {
		color = Color3.fromRGB(210, 210, 215),
		material = Enum.Material.Metal,
		reflectance = 0,
	},
	diamond = {
		color = Color3.fromRGB(90, 220, 220),
		material = Enum.Material.SmoothPlastic,
		reflectance = 0.2,
	},
}
local LIMBS: { [string]: { string } } = {
	helmet = { "Head" },
	chestplate = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm" },
	leggings = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" },
	boots = { "LeftFoot", "RightFoot" },
}
local limbNames: { [string]: boolean } = {}
for _, names in pairs(LIMBS) do
	for _, name in ipairs(names) do
		limbNames[name] = true
	end
end

local function part(
	parent: Model,
	limb: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	style: Style,
	trim: boolean
)
	local visual = Instance.new("Part")
	visual.Name = name
	visual.Size = size
	visual.Color = if trim then style.color:Lerp(Color3.new(0, 0, 0), 0.3) else style.color
	visual.Material = style.material
	visual.Reflectance = style.reflectance
	visual.Transparency = 0
	visual.Massless = true
	visual.CanCollide, visual.CanTouch, visual.CanQuery = false, false, false
	visual.CastShadow = true
	visual.TopSurface, visual.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	visual.CFrame = limb.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "ArmorWeld"
	weld.Part0, weld.Part1 = limb, visual
	weld.C0 = offset
	weld.Parent = visual
	visual.Parent = parent
end

-- Plates face local -Z. Four darker strips frame the exposed face without decals.
local function plate(
	parent: Model,
	limb: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	style: Style
)
	part(parent, limb, name, size, offset, style, false)
	local z = -size.Z / 2 - 0.005
	for _, sign in ipairs({ -1, 1 }) do
		part(
			parent,
			limb,
			name .. "Trim",
			Vector3.new(size.X, TRIM, 0.02),
			offset * CFrame.new(0, sign * (size.Y - TRIM) / 2, z),
			style,
			true
		)
		part(
			parent,
			limb,
			name .. "Trim",
			Vector3.new(TRIM, size.Y, 0.02),
			offset * CFrame.new(sign * (size.X - TRIM) / 2, 0, z),
			style,
			true
		)
	end
end

local function sleeve(parent: Model, limb: BasePart, style: Style, size: Vector3, offset: CFrame)
	for _, sign in ipairs({ -1, 1 }) do
		plate(
			parent,
			limb,
			"FrontBack",
			Vector3.new(size.X, size.Y, THICKNESS),
			offset
				* CFrame.new(0, 0, sign * (size.Z - THICKNESS) / 2)
				* CFrame.Angles(0, if sign == 1 then math.pi else 0, 0),
			style
		)
		plate(
			parent,
			limb,
			"Side",
			Vector3.new(size.Z, size.Y, THICKNESS),
			offset
				* CFrame.new(sign * (size.X - THICKNESS) / 2, 0, 0)
				* CFrame.Angles(0, -sign * math.pi / 2, 0),
			style
		)
	end
end

local function renderLimb(parent: Model, limb: BasePart, id: string, style: Style)
	local size = limb.Size + Vector3.new(PADDING, PADDING, PADDING)
	if id == "helmet" then
		-- Minecraft-style open-face helmet: a box 1.3× the head, raised so it covers the hair line,
		-- closed on top/back/sides, with a brow band across the forehead and a neck guard.
		local width = limb.Size.X * 1.3
		local height = limb.Size.Y + 0.55
		local depth = limb.Size.Z + PADDING
		local lift = 0.2 -- the box sits a little higher than the head centre
		plate(
			parent,
			limb,
			"HelmetTop",
			Vector3.new(width, depth, THICKNESS),
			CFrame.new(0, lift + (height - THICKNESS) / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0),
			style
		)
		plate(
			parent,
			limb,
			"HelmetBack",
			Vector3.new(width, height, THICKNESS),
			CFrame.new(0, lift, (depth - THICKNESS) / 2) * CFrame.Angles(0, math.pi, 0),
			style
		)
		for _, sign in ipairs({ -1, 1 }) do
			plate(
				parent,
				limb,
				"HelmetSide",
				Vector3.new(depth, height, THICKNESS),
				CFrame.new(sign * (width - THICKNESS) / 2, lift, 0)
					* CFrame.Angles(0, -sign * math.pi / 2, 0),
				style
			)
		end
		-- brow band (upper third of the face stays covered, eyes open)
		plate(
			parent,
			limb,
			"HelmetBrow",
			Vector3.new(width, height * 0.36, THICKNESS),
			CFrame.new(0, lift + height / 2 - height * 0.18, -(depth - THICKNESS) / 2),
			style
		)
		-- neck guard below the back plate
		plate(
			parent,
			limb,
			"HelmetNeck",
			Vector3.new(width, 0.3, THICKNESS),
			CFrame.new(0, lift - height / 2 - 0.1, (depth - THICKNESS) / 2 + 0.05)
				* CFrame.Angles(0, math.pi, 0),
			style
		)
	elseif id == "chestplate" and string.find(limb.Name, "Arm") then
		-- Upper-arm pads never attach to the hand or alter the held-item grip.
		local pad = Vector3.new(size.X, limb.Size.Y * 0.4 + PADDING, size.Z)
		local offset = CFrame.new(0, (limb.Size.Y - pad.Y) / 2 + PADDING / 2, 0)
		sleeve(parent, limb, style, pad, offset)
		plate(
			parent,
			limb,
			"ShoulderTop",
			Vector3.new(pad.X, pad.Z, THICKNESS),
			offset * CFrame.new(0, (pad.Y - THICKNESS) / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0),
			style
		)
	elseif id == "chestplate" then
		for _, sign in ipairs({ -1, 1 }) do
			plate(
				parent,
				limb,
				"TorsoPlate",
				Vector3.new(size.X, size.Y, THICKNESS),
				CFrame.new(0, 0, sign * (size.Z - THICKNESS) / 2)
					* CFrame.Angles(0, if sign == 1 then math.pi else 0, 0),
				style
			)
		end
	else
		sleeve(parent, limb, style, size, CFrame.identity)
		if id == "boots" then
			-- Close the sleeves into foot-sized boxes, leaving ankle motion independent.
			for _, sign in ipairs({ -1, 1 }) do
				plate(
					parent,
					limb,
					"BootCap",
					Vector3.new(size.X, size.Z, THICKNESS),
					CFrame.new(0, sign * (size.Y - THICKNESS) / 2, 0)
						* CFrame.Angles(sign * math.pi / 2, 0, 0),
					style
				)
			end
		end
	end
end

-- Hair pokes through a helmet; Minecraft hides it under the helmet texture, we hide the accessory.
local function setHairHidden(character: Model, hidden: boolean)
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local isHair = accessory.AccessoryType == Enum.AccessoryType.Hair
				or string.find(string.lower(accessory.Name), "hair") ~= nil
			local handle = accessory:FindFirstChild("Handle")
			if isHair and handle and handle:IsA("BasePart") then
				handle.LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

local function render(rig: Rig)
	if rig.visual then
		rig.visual:Destroy()
		rig.visual = nil
	end
	local attribute = rig.character:GetAttribute("Armor")
	if typeof(attribute) ~= "string" or attribute == "" then
		setHairHidden(rig.character, false)
		return
	end
	local visual = Instance.new("Model")
	visual.Name = "ArmorVisual"
	local rendered: { [string]: boolean } = {}
	for entry in string.gmatch(attribute, "[^,]+") do
		local id, rawLevel = string.match(entry, "^([^:]+):(%d+)$")
		local level = tonumber(rawLevel)
		local names = if id then LIMBS[id] else nil
		if not id or not names or not level or level < 1 or rendered[id] then
			continue
		end
		rendered[id] = true
		local style = STYLES[Config.materialForLevel(level)] or STYLES.wood
		for _, name in ipairs(names) do
			local limb = rig.character:FindFirstChild(name)
			if limb and limb:IsA("BasePart") then
				renderLimb(visual, limb, id, style)
			end
		end
	end
	visual.Parent = rig.character
	rig.visual = visual
	setHairHidden(rig.character, rendered.helmet == true)
end

local function clear(player: Player)
	local rig = rigs[player]
	if not rig then
		return
	end
	for _, connection in ipairs(rig.connections) do
		connection:Disconnect()
	end
	if rig.visual then
		rig.visual:Destroy()
	end
	rigs[player] = nil
end

local function characterAdded(player: Player, character: Model)
	clear(player)
	local rig: Rig = { character = character, connections = {}, visual = nil }
	rigs[player] = rig
	table.insert(
		rig.connections,
		character:GetAttributeChangedSignal("Armor"):Connect(function()
			render(rig)
		end)
	)
	local function limbChanged(child: Instance)
		if (child:IsA("BasePart") and limbNames[child.Name]) or child:IsA("Accessory") then
			task.defer(function()
				if rig.character.Parent then
					render(rig)
				end
			end)
		end
	end
	table.insert(rig.connections, character.ChildAdded:Connect(limbChanged))
	table.insert(rig.connections, character.ChildRemoved:Connect(limbChanged))
	render(rig)
end

local function watch(player: Player)
	playerConnections[player] = {
		player.CharacterAdded:Connect(function(character)
			characterAdded(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			clear(player)
		end),
	}
	if player.Character then
		characterAdded(player, player.Character)
	end
end

function ArmorVisual.Start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		for _, connection in ipairs(playerConnections[player] or {}) do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return ArmorVisual
