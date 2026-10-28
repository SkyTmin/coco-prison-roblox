--!strict
-- Our NPCs in the player's block body [владелец 26.10: «нужны тогда модельки и для нпс наших»]. The map scripts
-- (scripts/build-npcs.luau, scripts/locations/kit.luau and the location builds) place anchored R15 rigs; at server
-- start each one whose name has a costume is rebuilt in our body: the R15 limbs and the old hats go, the body parts of
-- Shared.Models.player take their place standing on the same ground and facing the same way, painted in the costume
-- of Shared.Models.npcs (assets/models/npc/npc.py) with its extra boxes (caps, helmets, robes, the halo). The
-- HumanoidRootPart stays, so its tags (SellPoint, ItemShop, TrainerNpc…), the name sign and the prompts work as before.
-- Skin follows the rig's head colour, hair and eyes are picked from the NPC's position (the same on every server),
-- the block buyers keep their location's shirt and trousers. A model attribute Costume overrides the name table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockBody = require(script.Parent.BlockBody)
local Npcs = require(Shared.Models.npcs) :: any

local NpcBodyService = {}
local started = false

local Body = BlockBody.Body
local PX = BlockBody.PX
local vec = BlockBody.vec

-- model name → costume (QuarryBuyer is the miner; any other name with Buyer in it is a block buyer)
local COSTUMES: { [string]: string } = {
	Buyer = "buyer",
	Buyer2 = "buyer",
	BasementBuyer = "buyer",
	BasementOreBuyer = "buyer",
	QuarryBuyer = "miner",
	ItemShop = "miner",
	FoodShop = "cook",
	StarExchange = "star",
	ShardExchange = "shard",
	Trainer = "trainer",
	QuestGiver = "clerk",
	Guard = "guard",
	CanteenCook = "cook", -- the Столовая (DailyService)
	DailyRewards = "clerk", -- «Ежедневные награды» on the spawn (DailyService)
	Gatekeeper = "gatekeeper",
	Cultist = "cultist",
	-- the people of the locations (scripts/locations/market/30-bazaar.luau)
	Trader = "buyer",
	Shopkeeper = "buyer",
	TavernKeeper = "buyer",
	Smith = "buyer",
	Cook = "cook",
	Lookout = "shard",
	Smuggler = "shard",
	Prisoner = "prisoner",
}

local function colourOf(model: Model, name: string): Color3?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.Color else nil
end

local function costumeOf(model: Model): string?
	local attribute = model:GetAttribute("Costume")
	if typeof(attribute) == "string" and Npcs.costumes[attribute] then
		return attribute
	end
	if model.Name == "CardPlayer" then
		-- the card players: a prisoner in orange or a smuggler
		local torso = colourOf(model, "UpperTorso")
		return if torso
				and torso.R > 0.7
				and torso.R > torso.G
				and torso.G > torso.B
			then "prisoner"
			else "shard"
	end
	if COSTUMES[model.Name] then
		return COSTUMES[model.Name]
	end
	-- every other block buyer (Buyer_<faction>, SnowBuyer, SeaBuyer, EndBuyer…)
	return if string.find(model.Name, "Buyer", 1, true) then "buyer" else nil
end

-- the palette index nearest to a colour (the rig's skin → our skin tone with its shade and lips)
local function nearest(list: { string }, colour: Color3): number
	local best, bestDistance = 1, math.huge
	for i, value in ipairs(list) do
		local c = Color3.fromHex(value)
		local d = (c.R - colour.R) ^ 2 + (c.G - colour.G) ^ 2 + (c.B - colour.B) ^ 2
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

local function darker(c: Color3): Color3
	return Color3.new(c.R * 0.78, c.G * 0.78, c.B * 0.78)
end

local function coloursOf(model: Model, costume: any, origin: Vector3): BlockBody.Colours
	local colours: BlockBody.Colours = {}
	for role, value in pairs(costume.colours) do
		colours[role] = Color3.fromHex(value)
	end
	local palettes = Body.palettes
	local random = Random.new(math.floor(origin.X) * 73856093 + math.floor(origin.Z) * 19349663)
	local skin = nearest(palettes.skin, colourOf(model, "Head") or Color3.fromHex(palettes.skin[2]))
	colours.skin = Color3.fromHex(palettes.skin[skin])
	colours.skin_dark = Color3.fromHex(palettes.skin_dark[skin])
	colours.mouth = Color3.fromHex(palettes.mouth[skin])
	colours.iris = Color3.fromHex(palettes.iris[random:NextInteger(1, #palettes.iris)])
	if not colours.hair then
		local hair = random:NextInteger(1, #palettes.hair)
		colours.hair = Color3.fromHex(palettes.hair[hair])
		colours.hair_dark = Color3.fromHex(palettes.hair_dark[hair])
		colours.brow = colours.hair_dark
	end
	colours.brow = colours.brow or colours.hair_dark
	-- the block buyers keep their location's shirt and trousers, the smugglers their vest
	local from = { shirt = "UpperTorso", vest = "UpperTorso", pants = "LeftUpperLeg" }
	for _, role in ipairs(costume.vary) do
		local colour = from[role] and colourOf(model, from[role])
		if colour then
			colours[role] = colour
			colours[role .. "_dark"] = darker(colour)
		end
	end
	return colours
end

local function lists(faces: any): { [string]: { { BlockBody.Rect }? } }
	local out = {}
	for face, rects in pairs(faces or {}) do
		out[face] = { rects }
	end
	return out
end

local function dress(model: Model)
	if model:GetAttribute("BlockBody") == true or Players:GetPlayerFromCharacter(model) then
		return
	end
	local id = costumeOf(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not id or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local costume = Npcs.costumes[id]
	-- the feet stay on the same ground, the body faces the same way
	local ground = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local frame = CFrame.new(root.Position.X, ground, root.Position.Z) * root.CFrame.Rotation
	local colours = coloursOf(model, costume, root.Position)
	local glow: { [string]: boolean } = {}
	for _, role in ipairs(costume.glow) do
		glow[role] = true
	end
	for _, child in ipairs(model:GetChildren()) do
		if
			(child:IsA("BasePart") and child ~= root)
			or child:IsA("Accessory")
			or child:IsA("BodyColors")
			or child:IsA("Clothing")
			or child:IsA("ShirtGraphic")
		then
			child:Destroy()
		end
	end
	local rig = BlockBody.build(model.Name)
	local parts: { [string]: BasePart } = {}
	for name, data in pairs(Body.parts) do
		local part = rig:FindFirstChild(name) :: BasePart
		part.CFrame = frame * CFrame.new(vec(data.pos) * PX)
		part.Anchored = true
		parts[name] = part
	end
	for name, part in pairs(parts) do
		local motor = part:FindFirstChildOfClass("Motor6D")
		if motor and motor.Part0 and motor.Part0.Name == "HumanoidRootPart" then
			motor.Part0 = root
			motor.C0 = root.CFrame:ToObjectSpace(part.CFrame * motor.C1)
		end
		local look = costume.parts[name]
		BlockBody.paint(
			part,
			vec(Body.parts[name].size),
			look.base,
			lists(look.faces),
			colours,
			true,
			glow
		)
		part.Parent = model
	end
	rig:Destroy()
	local top = ground + Body.parts.Head.pos[2] * PX + Body.parts.Head.size[2] * PX / 2
	for _, extra in ipairs(costume.extras) do
		local carrier = parts[extra.part]
		local box = Instance.new("Part")
		box.Name = extra.name
		box.Size = vec(extra.size) * PX
		box.CFrame = carrier.CFrame * CFrame.new(vec(extra.pos) * PX)
		box.Anchored = true
		box.CanCollide, box.CanQuery, box.CanTouch = false, false, false
		box.Material = Enum.Material.SmoothPlastic
		box.TopSurface, box.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		BlockBody.paint(box, vec(extra.size), extra.base, lists(extra.faces), colours, true, glow)
		if glow[extra.base] then
			box.CastShadow = false
		end
		if extra.name == "HelmetLamp" then
			local light = Instance.new("SpotLight")
			light.Range = 20
			light.Angle = 60
			light.Face = Enum.NormalId.Front
			light.Parent = box
		end
		box.Parent = model
		top = math.max(top, box.Position.Y + box.Size.Y / 2)
	end
	-- the name sign above the tallest hat
	for _, gui in ipairs(root:GetChildren()) do
		if gui:IsA("BillboardGui") then
			local need = top - root.Position.Y + 0.8
			if gui.StudsOffset.Y < need then
				gui.StudsOffset = Vector3.new(gui.StudsOffset.X, need, gui.StudsOffset.Z)
			end
		end
	end
	model:SetAttribute("BlockBody", true)
	model:SetAttribute("Costume", id)
end

local function consider(humanoid: Instance)
	local model = humanoid.Parent
	if humanoid:IsA("Humanoid") and model and model:IsA("Model") then
		local ok, err = pcall(dress, model)
		if not ok then
			warn("[NpcBodyService]", model:GetFullName(), err)
		end
	end
end

function NpcBodyService.Start()
	if started then
		return
	end
	started = true
	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Humanoid") then
			task.defer(consider, instance)
		end
	end)
	task.spawn(function()
		local count = 0
		for _, instance in ipairs(workspace:GetDescendants()) do
			if instance:IsA("Humanoid") then
				consider(instance)
				count += 1
				if count % 8 == 0 then
					task.wait()
				end
			end
		end
	end)
end

return NpcBodyService
