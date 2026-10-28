--!strict
-- Items on the ground drawn like Minecraft [ваниль ItemEntityRenderer, владелец 27.10: «отображение предметов на
-- земле дроп, как в майне, у нас выглядит ужасно»]: the server's ItemDrop part is only the item's invisible 0.25-block
-- box (ItemDropService); here every client puts the item itself on it — the held model (HeldItem.MakeVisual): a
-- 0.25-block cube of a block, the 0.5-block extruded sprite of an item. It spins at 1 rad/s and bobs 0.1 block
-- (sin(age / 10 + offset) · 0.1 + 0.1); a bigger stack shows more copies (2 from 2, 3 from 17, 4 from 33, 5 from
-- 49), each a little apart. Picking up (ItemPickupFx) flies a copy into the player over 3 ticks.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local HeldItem = require(script.Parent.HeldItem)

local BLOCK = Config.rules.combat.blockStuds :: number
local SHOW_DISTANCE = 120 -- studs; farther items are not moved (nor seen)
local FLY_SECONDS = 0.15 -- 3 ticks

type Copy = { container: Instance, offset: CFrame }
type Entry = { copies: { Copy }, cube: boolean, offset: number, born: number, count: number }

local GroundItems = {}
local entries: { [BasePart]: Entry } = {}
local folder: Folder? = nil

-- [ваниль ItemEntityRenderer.getRenderAmount]
local function renderAmount(count: number): number
	return if count > 48
		then 5
		elseif count > 32 then 4
		elseif count > 16 then 3
		elseif count > 1 then 2
		else 1
end

-- one copy of the item: a cube 0.25 block, a sprite 0.5 block tall
local function visual(id: string, level: number): (Instance, boolean)
	local probe = Config.block(id)
	local sprites = (Config.textures :: any).sprites
	local cube = probe ~= nil and not probe.itemOnly and not (sprites and sprites[id])
	local tool = Config.tools[id] ~= nil
	local scale = if cube then 0.25 * BLOCK / 1.2 else 0.5 * BLOCK / (if tool then 1.45 else 1.2)
	local container = HeldItem.MakeVisual(id, level, scale)
	for _, d in ipairs({ container, table.unpack(container:GetDescendants()) }) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.CastShadow = false
		end
	end
	return container, cube
end

local function place(container: Instance, cf: CFrame)
	if container:IsA("Model") then
		container:PivotTo(cf)
	elseif container:IsA("BasePart") then
		container.CFrame = cf
	end
end

local function clear(entry: Entry)
	for _, copy in ipairs(entry.copies) do
		copy.container:Destroy()
	end
	table.clear(entry.copies)
end

local function build(part: BasePart, entry: Entry)
	clear(entry)
	local id = part:GetAttribute("ItemId")
	local level = part:GetAttribute("Level")
	if typeof(id) ~= "string" then
		return
	end
	local n = renderAmount(entry.count)
	-- the copies' offsets are the same every time for this item (vanilla seeds them by the item id)
	local seeded = Random.new(#id * 977 + string.byte(id, 1))
	for i = 1, n do
		local container, cube = visual(id, if typeof(level) == "number" then level else 0)
		entry.cube = cube
		local offset = CFrame.identity
		if i > 1 then
			local j = 0.15 * BLOCK
			offset = if cube
				then CFrame.new(
					(seeded:NextNumber() * 2 - 1) * j,
					(seeded:NextNumber() * 2 - 1) * j,
					(seeded:NextNumber() * 2 - 1) * j
				)
				-- sprites stack along their thickness (x), a little off in the picture's plane
				else CFrame.new(
					0.09375 * BLOCK * 0.5 * (i - 1),
					(seeded:NextNumber() * 2 - 1) * j * 0.5,
					(seeded:NextNumber() * 2 - 1) * j * 0.5
				)
		end
		container.Parent = folder
		table.insert(entry.copies, { container = container, offset = offset })
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or entries[instance] then
		return
	end
	local part = instance
	local count = part:GetAttribute("Count")
	local entry: Entry = {
		copies = {},
		cube = false,
		offset = math.random() * math.pi * 2,
		born = os.clock(),
		count = if typeof(count) == "number" then count else 1,
	}
	entries[part] = entry
	build(part, entry)
	part:GetAttributeChangedSignal("Count"):Connect(function()
		local now = part:GetAttribute("Count")
		local c = if typeof(now) == "number" then now else 1
		if renderAmount(c) ~= renderAmount(entry.count) then
			entry.count = c
			build(part, entry)
		end
		entry.count = c
	end)
end

local function drop(instance: Instance)
	local entry = entries[instance :: BasePart]
	if entry then
		entries[instance :: BasePart] = nil
		clear(entry)
	end
end

-- the item over its box: ground + bob + a quarter of its display scale + the model's «ground» display translation
-- [ваниль: a sprite 0.125 + 2/16, a block 0.0625 + 3/16] = 0.25 block for both — the sprite's bottom just touches
-- the ground at the lowest bob, a block floats [владелец 27.10: «как будто в текстуру внизу проваливаются»]
local function frameOf(part: BasePart, entry: Entry, now: number): CFrame
	local age = now - entry.born
	local bob = math.sin(age * 2 + entry.offset) * 0.1 + 0.1
	local ground = part.Position.Y - part.Size.Y / 2
	local lift = (bob + 0.25) * BLOCK
	return CFrame.new(part.Position.X, ground + lift, part.Position.Z)
		* CFrame.Angles(0, age + entry.offset, 0)
end

local function step()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for part, entry in pairs(entries) do
		if not part.Parent then
			drop(part)
			continue
		end
		-- an item of another gang on the База банды is not shown (ItemDropService: attribute GangId)
		local gang = part:GetAttribute("GangId")
		local far = (part.Position - eye).Magnitude > SHOW_DISTANCE
			or (gang ~= nil and gang ~= Players.LocalPlayer:GetAttribute("GangId"))
		for _, copy in ipairs(entry.copies) do
			if far then
				if copy.container.Parent then
					copy.container.Parent = nil
				end
			else
				if not copy.container.Parent then
					copy.container.Parent = folder
				end
				place(copy.container, frameOf(part, entry, now) * copy.offset)
			end
		end
	end
end

-- [ваниль ItemPickupParticle] a copy of the item flies from where it lay into the player who took it
local function flyTo(userId: number, from: Vector3, id: string, level: number)
	local player = Players:GetPlayerByUserId(userId)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local container = visual(id, level)
	container.Parent = folder
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / FLY_SECONDS, 0, 1)
		if k >= 1 or not root.Parent then
			container:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end
		local target = root.Position - Vector3.new(0, 0.5, 0)
		place(container, CFrame.new(from:Lerp(target, k * k)))
	end)
end

function GroundItems.Start()
	local f = Instance.new("Folder")
	f.Name = "GroundItems"
	f.Parent = workspace
	folder = f
	for _, part in ipairs(CollectionService:GetTagged("ItemDrop")) do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("ItemDrop"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("ItemDrop"):Connect(drop)
	RunService:BindToRenderStep("GroundItems", Enum.RenderPriority.Camera.Value + 3, step)
	Remotes.unreliable("ItemPickupFx").OnClientEvent
		:Connect(function(userId: any, from: any, id: any, level: any)
			if
				typeof(userId) == "number"
				and typeof(from) == "Vector3"
				and typeof(id) == "string"
			then
				flyTo(userId, from, id, if typeof(level) == "number" then level else 0)
			end
		end)
end

return GroundItems
