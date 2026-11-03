--!nocheck
-- Actual Config + shared visual truth + UI/world renderer + HeldItem; fake Instances/signals only.
local fs, serde, rb = require("@lune/fs"), require("@lune/serde"), require("@lune/roblox")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function load(path, env, edit)
	local s = fs.readFile(path)
	if edit then
		s = edit(s)
	end
	local fn = assert(loadstring(s, "@" .. path))
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end
local Config = load("src/shared/Config/init.luau", {
	script = {
		WaitForChild = function(_, name)
			return name
		end,
	},
	require = function(name)
		return serde.decode("json", fs.readFile("src/shared/Config/" .. name .. ".json"))
	end,
})
local Truth = load("src/shared/ItemEnchantment.luau", {
	script = { Parent = { Config = "Config" } },
	require = function()
		return Config
	end,
})
for id, tool in Config.tools do
	check(id .. " level1 has no invented enchant", not Truth.active({ id = id, level = 1 }))
	for _, upgrade in tool.upgrades do
		check(
			id .. " actual level " .. upgrade.to .. " follows built-in enchants/flame",
			Truth.active({ id = id, level = upgrade.to })
				== (upgrade.enchantAfter > 0 or Config.flameForLevel(id, upgrade.to) > 0)
		)
	end
end
check(
	"ordinary block with fabricated book stays plain",
	not Truth.active({ id = "stone", books = { { id = "hammer", level = 1 } } })
)
check(
	"compatible ancient book marks otherwise plain tool",
	Truth.active({ id = "pickaxe", level = 1, books = { { id = "hammer", level = 1 } } })
)
check(
	"incompatible ancient book does not invent enchant",
	not Truth.active({ id = "bow", level = 1, books = { { id = "hammer", level = 1 } } })
)
check(
	"invalid zero ancient level stays plain",
	not Truth.active({ id = "pickaxe", level = 1, books = { { id = "hammer", level = 0 } } })
)
check(
	"unknown ancient book stays plain",
	not Truth.active({ id = "pickaxe", level = 1, books = { { id = "fabricated", level = 1 } } })
)
check("empty slot stays plain", not Truth.active(nil))
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn)
		local c = { active = true, fn = fn }
		function c:Disconnect()
			self.active = false
		end
		table.insert(self.callbacks, c)
		return c
	end
	function s:Fire(...)
		for _, c in table.clone(self.callbacks) do
			if c.active then
				c.fn(...)
			end
		end
	end
	function s:count()
		local n = 0
		for _, c in self.callbacks do
			if c.active then
				n += 1
			end
		end
		return n
	end
	return s
end
local created = {}
local function instance(class)
	local props = {
		ClassName = class,
		Name = class,
		children = {},
		Destroying = signal(),
		attributes = {},
		signals = {},
		Transparency = 0,
		ZIndex = 1,
		Color = rb.Color3.new(1, 1, 1),
		CFrame = rb.CFrame.identity,
		Position = rb.Vector3.zero,
		Size = rb.Vector3.one,
	}
	local object, methods = {}, {}
	function methods:IsA(name)
		return name == class or (name == "BasePart" and (class == "Part" or class == "MeshPart"))
	end
	function methods:GetChildren()
		return table.clone(props.children)
	end
	function methods:GetDescendants()
		local out = {}
		for _, child in props.children do
			table.insert(out, child)
			for _, sub in child:GetDescendants() do
				table.insert(out, sub)
			end
		end
		return out
	end
	function methods:FindFirstChild(name)
		for _, child in props.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:IsDescendantOf(parent)
		local cursor = self.Parent
		while cursor do
			if cursor == parent then
				return true
			end
			cursor = cursor.Parent
		end
		return false
	end
	function methods:Destroy()
		props.Destroying:Fire()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		self.Parent = nil
		props.destroyed = true
	end
	function methods:GetAttribute(key)
		return props.attributes[key]
	end
	function methods:SetAttribute(key, value)
		props.attributes[key] = value
		if props.signals[key] then
			props.signals[key]:Fire()
		end
	end
	function methods:GetAttributeChangedSignal(key)
		props.signals[key] = props.signals[key] or signal()
		return props.signals[key]
	end
	setmetatable(object, {
		__index = function(_, key)
			return methods[key] or props[key]
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				if props.Parent then
					local old = props.Parent.children
					local i = table.find(old, object)
					if i then
						table.remove(old, i)
					end
				end
				if value then
					table.insert(value.children, object)
				end
			end
			props[key] = value
		end,
	})
	table.insert(created, object)
	return object
end
local heartbeat, tweens = signal(), {}
local world = instance("Workspace")
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
function names:WaitForChild(name)
	return name
end
local modules = {
	Config = Config,
	ItemEnchantment = Truth,
	Combat = { SWING_SECONDS = 0.3 },
	CharacterAnimator = {},
	BowState = {
		ModelId = function()
			return "bow"
		end,
	},
}
local services = {
	RunService = { Heartbeat = heartbeat },
	TweenService = {
		Create = function(_, _, _, goal)
			local t = { goal = goal }
			function t:Play()
				self.played = true
			end
			function t:Cancel()
				self.cancelled = true
			end
			table.insert(tweens, t)
			return t
		end,
	},
	ReplicatedStorage = {
		Shared = names,
		WaitForChild = function()
			return names
		end,
	},
	CollectionService = {},
	MaterialService = {
		FindFirstChild = function()
			return nil
		end,
	},
	Players = {},
}
local env = {
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	script = { Parent = names },
	require = function(name)
		return assert(modules[name], name)
	end,
	Instance = { new = instance },
	Enum = rb.Enum,
	Color3 = rb.Color3,
	Vector2 = rb.Vector2,
	Vector3 = rb.Vector3,
	CFrame = rb.CFrame,
	UDim2 = rb.UDim2,
	ColorSequence = rb.ColorSequence,
	NumberSequence = rb.NumberSequence,
	NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
	TweenInfo = {
		new = function()
			return {}
		end,
	},
	workspace = world,
	os = {
		clock = function()
			return 2
		end,
	},
}
local Visual = load("src/client/EnchantmentVisual.luau", env)
modules.EnchantmentVisual = Visual
local image = instance("ImageLabel")
image.Image = "rbxassetid://fixture"
image.ScaleType = rb.Enum.ScaleType.Fit
image.ResampleMode = rb.Enum.ResamplerMode.Pixelated
Visual.slot(image, { id = "pickaxe", level = 1 })
check("plain UI creates no overlay/tween", #image:GetChildren() == 0 and #tweens == 0)
local stack = { id = "pickaxe", level = 4, count = 1, books = {} }
local before = serde.encode("json", stack)
Visual.slot(image, stack)
Visual.slot(image, stack)
check(
	"enchanted UI has one alpha-matched overlay and one rune",
	#image:GetChildren() == 2
		and image:FindFirstChild("EnchantGlint").Image == image.Image
		and image:FindFirstChild("EnchantRune") ~= nil
		and #tweens == 1
)
check("slot rendering does not alter item metadata", serde.encode("json", stack) == before)
image.Image = "rbxassetid://upgraded"
Visual.slot(image, stack)
check(
	"existing glint follows changed icon without duplicate animation",
	image:FindFirstChild("EnchantGlint").Image == image.Image and #tweens == 1
)
Visual.slot(image, nil)
check(
	"empty slot removes visuals and cancels tween",
	#image:GetChildren() == 0 and tweens[1].cancelled
)
Visual.slot(image, stack)
image:Destroy()
check("destroyed UI cancels looping tween", tweens[2].cancelled)
local function model()
	local m = instance("Model")
	local root = instance("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Parent = m
	m.PrimaryPart = root
	local p = instance("Part")
	p.Name = "Px"
	p.Material = rb.Enum.Material.SmoothPlastic
	p.Color = rb.Color3.fromRGB(100, 90, 80)
	p.Parent = m
	return m, root, p
end
local m, root, pixel = model()
local base = pixel.Color
m.Parent = world
Visual.held(m, root)
Visual.held(m, root)
local runeCount = 0
for _, child in m:GetDescendants() do
	if child:IsA("SurfaceGui") then
		runeCount += 1
		check(
			"world rune receives scene lighting and respects occlusion " .. runeCount,
			child.LightInfluence == 1 and child.AlwaysOnTop == false
		)
	end
end
check(
	"held model has only two runes and a single shared heartbeat",
	runeCount == 2 and heartbeat:count() == 1
)
heartbeat:Fire(0.1)
check(
	"visible matte pixels receive bounded colour pulse without material change",
	pixel.Color ~= base
		and pixel.Material == rb.Enum.Material.SmoothPlastic
		and pixel.Transparency == 0
)
local first = pixel.Color
m.Parent = nil
heartbeat:Fire(0.1)
check("detached first-person models stop per-frame visual writes", pixel.Color == first)
m:Destroy()
check("last destroyed model disconnects global heartbeat", heartbeat:count() == 0)
modules.ItemModels = {
	get = function()
		local item, r = model()
		return item
	end,
}
local Held = load("src/client/HeldItem.luau", env, function(s)
	return (s:gsub("return HeldItem%s*$", "return {api=HeldItem,render=render}"))
end)
local character = instance("Model")
character.Parent = world
local hand = instance("Part")
hand.Name = "RightHand"
hand.Parent = character
character:SetAttribute("HeldItem", "pickaxe:1")
character:SetAttribute("HeldEnchanted", false)
local rig = { character = character }
Held.render(rig)
local function heldCount()
	local n = 0
	for _, c in character:GetChildren() do
		if c.Name == "HeldItemVisual" then
			n += 1
		end
	end
	return n
end
local plainHasRune = false
for _, child in rig.visual:GetDescendants() do
	if child:IsA("SurfaceGui") then
		plainHasRune = true
	end
end
check("plain held level1 has no world rune", heldCount() == 1 and not plainHasRune)
character:SetAttribute("HeldEnchanted", true)
Held.render(rig)
local firstVisual = rig.visual
local foundRune = false
for _, c in rig.visual:GetDescendants() do
	if c:IsA("SurfaceGui") then
		foundRune = true
	end
end
check("server ancient-book flag decorates same-level held model", heldCount() == 1 and foundRune)
character:SetAttribute("HeldEnchanted", false)
Held.render(rig)
check(
	"removing ancient enchant destroys old visual without duplicate model",
	firstVisual.destroyed and heldCount() == 1 and heartbeat:count() == 0
)
character:SetAttribute("HeldItem", "pickaxe:4")
Held.render(rig)
check(
	"built-in EfficiencyIII is visible without ancient flag",
	heldCount() == 1 and heartbeat:count() == 1
)
character:SetAttribute("HeldItem", "")
Held.render(rig)
check("empty hand destroys decoration and animation", heldCount() == 0 and heartbeat:count() == 0)
for _, object in created do
	check(
		"no emissive/glow object " .. object.ClassName,
		object.ClassName ~= "PointLight"
			and object.ClassName ~= "SurfaceLight"
			and object.ClassName ~= "Highlight"
			and object.ClassName ~= "BloomEffect"
			and object.Material ~= rb.Enum.Material.Neon
	)
end
for _, path in
	{
		"src/client/FirstPersonHand.luau",
		"src/client/SlotView.luau",
		"src/client/ActionsWindow.luau",
		"src/client/init.client.luau",
		"src/server/Services/ProfileService.luau",
	}
do
	check(path .. " compiles", loadstring(fs.readFile(path)) ~= nil)
end
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, actualModules = true, nativeVisualAcceptance = false },
		true
	)
)
