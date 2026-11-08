--!nocheck
-- Execute the actual inventory builder and window fitter; only Roblox GUI/character boundaries mocked.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-release-upgrade-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local fn = assert(loadstring", 1, true)) - 1)
local boundary = assert(loadstring(prefix .. "\nreturn {node=node, Ui=Ui}"))()
local src = fs.readFile("src/client/init.client.luau")
local function extract(first, last, result)
	local at = assert(src:find(first, 1, true))
	local finish = assert(src:find(last, at, true))
	return assert(loadstring(src:sub(at, finish - 1) .. "\nreturn " .. result))
end
local checks, layouts = {}, {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function signal()
	local entries = {}
	local s = {}
	function s:Connect(callback)
		local entry = { callback = callback, connected = true }
		table.insert(entries, entry)
		return {
			Disconnect = function()
				entry.connected = false
			end,
		}
	end
	s.Once = s.Connect
	function s:Fire()
		for _, entry in table.clone(entries) do
			if entry.connected then
				entry.callback()
			end
		end
	end
	return s
end
local function node(kind)
	local n = boundary.node(kind)
	n.Destroying, n.Position, n.AnchorPoint = signal(), rb.UDim2.new(), rb.Vector2.zero
	function n:ClearAllChildren()
		table.clear(self.children)
	end
	function n:GetAttribute(key)
		return self.attributes and self.attributes[key]
	end
	local destroy = n.Destroy
	function n:Destroy()
		self.Destroying:Fire()
		destroy(self)
	end
	return n
end
for _, size in { { 750, 381 }, { 844, 390 }, { 390, 844 }, { 360, 800 }, { 1280, 720 } } do
	local viewport = rb.Vector2.new(size[1], size[2])
	local viewChanged, cameraChanged, pending = signal(), signal(), {}
	local built, slots, bound = {}, {}, {}
	local ui = { colors = boundary.Ui.colors }
	local function make(kind, parent, dimensions, position)
		local n = node(kind)
		n.Parent, n.Size, n.Position = parent, dimensions, position or rb.UDim2.new()
		table.insert(built, n)
		return n
	end
	ui.card = function(parent, dimensions, position)
		return make("Frame", parent, dimensions, position)
	end
	ui.label = function(parent, text, dimensions, position, fontSize)
		local n = make("TextLabel", parent, dimensions, position)
		n.Text, n.TextSize = text, fontSize
		return n
	end
	ui.invSlot = function(parent, width)
		local n = make("Frame", parent, rb.UDim2.fromOffset(width, width))
		table.insert(slots, n)
		return n,
			make("TextLabel", n, rb.UDim2.new()),
			make("TextLabel", n, rb.UDim2.new()),
			make("ImageLabel", n, rb.UDim2.new())
	end
	local env = {
		workspace = {
			CurrentCamera = {
				ViewportSize = viewport,
				GetPropertyChangedSignal = function()
					return viewChanged
				end,
			},
			GetPropertyChangedSignal = function()
				return cameraChanged
			end,
		},
		task = {
			defer = function(fn)
				table.insert(pending, fn)
			end,
		},
		GuiService = {
			GetGuiInset = function()
				return rb.Vector2.new(0, 58)
			end,
		},
		Ui = ui,
		gui = node("ScreenGui"),
		player = { DisplayName = "QA", Character = nil },
		profile = { inventory = {}, armor = {}, level = 1 },
		INV_SLOT = 44,
		INV_GAP = 4,
		T = function(key)
			return key
		end,
		closeWindow = function() end,
		renderSlot = function() end,
		DragDrop = {
			new = function()
				return {
					Bind = function(frame, address)
						bound[frame] = address
					end,
				}
			end,
		},
		RunService = { RenderStepped = signal() },
		Combat = {
			armorPoints = function()
				return 0
			end,
			armorReduce = function()
				return 10
			end,
		},
		levelProgress = function()
			return 0
		end,
		Instance = { new = node },
		UDim2 = rb.UDim2,
		UDim = rb.UDim,
		Vector2 = rb.Vector2,
		Vector3 = rb.Vector3,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		Enum = rb.Enum,
	}
	setmetatable(env, { __index = getfenv() })
	local fit = extract("local function fitWindow(", "local function createWindow(", "fitWindow")
	setfenv(fit, env)
	fit = fit()
	local content, scale
	env.createWindow = function(parent, title, dimensions)
		local win = make(
			"Frame",
			parent,
			dimensions,
			rb.UDim2.new(0.5, -dimensions.X.Offset / 2, 0.5, -dimensions.Y.Offset / 2)
		)
		win.Name = "Window_" .. title
		content = make("Frame", win, rb.UDim2.new(1, -12, 1, -46), rb.UDim2.fromOffset(6, 40))
		scale = { Scale = 1 }
		fit(
			win,
			{ size = dimensions, position = win.Position, anchor = win.AnchorPoint, scale = scale }
		)
		return win, content
	end
	local build =
		extract("local function buildInventory(): Frame", "-- Level [U]:", "buildInventory")
	setfenv(build, env)
	build = build()
	local win = build()
	local width, height = win.Size.X.Offset, win.Size.Y.Offset
	local slotSize = win:GetAttribute("InventorySlotSize")
	local label = string.format("%dx%d", size[1], size[2])
	check(label .. " all36 inventory+4 armor slots", #slots == 40)
	check(label .. " fitter does not shrink text/slots", scale.Scale == 1)
	check(
		label .. " fits safe viewport",
		width <= viewport.X - 20 and height <= viewport.Y - 58 - 12
	)
	check(label .. " usable slot size", slotSize >= 33)
	local addresses = {}
	for _, slot in slots do
		local a = assert(bound[slot], "slot must preserve its drag address")
		local key = a.container .. ":" .. a.index
		check(label .. " unique drag address " .. key, not addresses[key])
		addresses[key] = true
		local p = slot.Position
		local x, y = p.X.Offset, p.Y.Offset
		if slot.Parent ~= content then
			x += slot.Parent.Position.X.Offset
			y += slot.Parent.Position.Y.Offset
		end
		check(
			label .. " contained slot " .. key,
			x >= 0 and y >= 0 and x + slotSize <= width - 12 and y + slotSize <= height - 46
		)
	end
	local stats
	for _, n in built do
		if n.Name == "InventoryStats" then
			stats = n
		end
	end
	for _, n in stats.children do
		if n.ClassName == "TextLabel" and n.Visible then
			check(label .. " stats font stays readable", n.TextSize >= 12)
			check(
				label .. " stats label contained",
				n.Position.Y.Offset + n.Size.Y.Offset <= stats.Size.Y.Offset
			)
		end
	end
	if viewport.X >= 600 and viewport.Y < 500 then
		check(
			label .. " short-screen sidebar selected",
			win:GetAttribute("InventoryCompact") == true and slotSize == 44
		)
	end
	table.insert(layouts, {
		viewport = label,
		width = width,
		height = height,
		slotPixels = slotSize,
		scale = scale.Scale,
	})
	env.openWindow, env.currentWindowKind = win, "inventory"
	env.workspace.CurrentCamera.ViewportSize = rb.Vector2.new(390, 844)
	viewChanged:Fire()
	viewChanged:Fire()
	check(label .. " orientation events coalesce", #pending == 1)
	table.remove(pending, 1)()
	check(
		label .. " rotation rebuilds open window",
		env.openWindow ~= win and win.Parent == nil and env.openWindow.Size.X.Offset == 364
	)
	local replacement = env.openWindow
	env.currentWindowKind = nil
	viewChanged:Fire()
	table.remove(pending, 1)()
	check(label .. " deferred resize cannot reopen closed inventory", env.openWindow == replacement)
end
check("entire client compiles", loadstring(src) ~= nil)
print(serde.encode("json", {
	passed = #checks,
	actualBuildInventory = true,
	actualFitWindow = true,
	nativeRendering = false,
	layouts = layouts,
}, true))
