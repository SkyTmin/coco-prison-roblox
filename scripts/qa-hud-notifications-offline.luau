--!nocheck
-- Actual AuctionBanner module, mocked GUI bounds/signals/clock only. No Studio or real announcements.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local source = fs.readFile("src/client/AuctionBanner.luau")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function fixture(width, height, origin, inset, rightInset)
	local f = { now = 0, threads = {}, remotes = {}, opened = {}, nodes = {} }
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				local entry = { fn = fn, alive = true }
				table.insert(listeners, entry)
				return {
					Disconnect = function()
						entry.alive = false
					end,
				}
			end,
			Fire = function(_, ...)
				for _, entry in table.clone(listeners) do
					if entry.alive then
						entry.fn(...)
					end
				end
			end,
		}
	end
	local reflow, flowing = nil, false
	local function node(kind)
		local p = {
			ClassName = kind,
			Name = kind,
			children = {},
			attributes = {},
			changes = {},
			attributeChanges = {},
			Size = rb.UDim2.new(),
			Position = rb.UDim2.new(),
			AnchorPoint = rb.Vector2.zero,
			AbsolutePosition = rb.Vector2.zero,
			AbsoluteSize = rb.Vector2.zero,
			Visible = true,
			Active = true,
			TextSize = 14,
			Font = rb.Enum.Font.Code,
			Activated = signal(),
		}
		local n
		function p:GetChildren()
			return table.clone(self.children)
		end
		function p:FindFirstChild(name)
			for _, child in self.children do
				if child.Name == name then
					return child
				end
			end
		end
		function p:WaitForChild(name)
			return assert(self:FindFirstChild(name), name)
		end
		function p:GetAttribute(name)
			return self.attributes[name]
		end
		function p:SetAttribute(name, value)
			if self.attributes[name] ~= value then
				self.attributes[name] = value
				if self.attributeChanges[name] then
					self.attributeChanges[name]:Fire()
				end
			end
		end
		function p:GetAttributeChangedSignal(name)
			self.attributeChanges[name] = self.attributeChanges[name] or signal()
			return self.attributeChanges[name]
		end
		function p:GetPropertyChangedSignal(name)
			self.changes[name] = self.changes[name] or signal()
			return self.changes[name]
		end
		function p:Destroy()
			for _, child in self:GetChildren() do
				child:Destroy()
			end
			n.Parent, n.destroyed = nil, true
		end
		n = setmetatable({}, {
			__index = p,
			__newindex = function(_, key, value)
				local old = p[key]
				if key == "Parent" and old then
					local at = table.find(old.children, n)
					if at then
						table.remove(old.children, at)
					end
				end
				p[key] = value
				if key == "Parent" and value then
					table.insert(value.children, n)
				end
				if old ~= value and p.changes[key] then
					p.changes[key]:Fire()
				end
				if reflow and not flowing then
					reflow()
				end
			end,
		})
		if kind == "ScreenGui" then
			p.AbsolutePosition, p.AbsoluteSize = origin, rb.Vector2.new(width, height)
		end
		table.insert(f.nodes, n)
		return n
	end
	f.player = node("Player")
	f.playerGui = node("PlayerGui")
	f.playerGui.Parent = f.player
	f.player:SetAttribute("LoadingBlocked", false)
	f.camera = { ViewportSize = rb.Vector2.new(width, height) }
	local function flow(parent)
		for _, child in parent:GetChildren() do
			if child.ClassName ~= "ScreenGui" then
				local s, pos = child.Size, child.Position
				child.AbsoluteSize = rb.Vector2.new(
					parent.AbsoluteSize.X * s.X.Scale + s.X.Offset,
					parent.AbsoluteSize.Y * s.Y.Scale + s.Y.Offset
				)
				child.AbsolutePosition = parent.AbsolutePosition
					+ rb.Vector2.new(
						parent.AbsoluteSize.X * pos.X.Scale + pos.X.Offset,
						parent.AbsoluteSize.Y * pos.Y.Scale + pos.Y.Offset
					)
					- child.AnchorPoint * child.AbsoluteSize
			end
			flow(child)
		end
	end
	reflow = function()
		flowing = true
		flow(f.playerGui)
		flowing = false
	end
	local function make(kind, parent, text, size, pos, textSize)
		local n = node(kind)
		n.Text, n.Size, n.Position, n.TextSize = text, size, pos, textSize or 14
		n.Parent = parent
		return n
	end
	local Ui = {
		colors = setmetatable({}, {
			__index = function()
				return rb.Color3.new(1, 1, 1)
			end,
		}),
		card = function(parent, size, pos)
			return make("Frame", parent, nil, size, pos)
		end,
		label = function(parent, text, size, pos, textSize)
			return make("TextLabel", parent, text, size, pos, textSize)
		end,
		button = function(parent, text, size, pos)
			return make("TextButton", parent, text, size, pos)
		end,
	}
	local names = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	local modules = {
		Auction = {
			priceText = function(_, value)
				return "$" .. tostring(value)
			end,
		},
		Config = {
			iconFor = function()
				return "asset://isolated"
			end,
			icons = { icons = {} },
		},
		ItemInfo = {
			bookName = function(id)
				return id
			end,
		},
		Strings = {
			t = function(key, _, ...)
				return key .. table.concat({ ... }, " ")
			end,
			itemName = function(id)
				return id
			end,
		},
		Ui = Ui,
		Remotes = {
			event = function(name)
				if not f.remotes[name] then
					f.remotes[name] = { OnClientEvent = signal() }
				end
				return f.remotes[name]
			end,
		},
	}
	local function resume(thread, ...)
		local ok, err = coroutine.resume(thread, ...)
		assert(ok, tostring(err))
	end
	local fn = assert(loadstring(source, "@AuctionBanner.actual"))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, name)
					return ({
						Players = { LocalPlayer = f.player },
						ReplicatedStorage = {
							WaitForChild = function()
								return names
							end,
						},
						TextService = {
							GetTextSize = function(_, text, size)
								return rb.Vector2.new(#text * size / 2, size)
							end,
						},
						GuiService = {
							GetGuiInset = function()
								return inset, rightInset or rb.Vector2.zero
							end,
						},
					})[name]
				end,
			},
			workspace = { CurrentCamera = f.camera },
			script = { Parent = names },
			require = function(id)
				return assert(modules[id], id)
			end,
			Instance = { new = node },
			Enum = rb.Enum,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
			Color3 = rb.Color3,
			os = {
				clock = function()
					return f.now
				end,
			},
			task = {
				spawn = function(callback)
					local thread = coroutine.create(callback)
					table.insert(f.threads, thread)
					resume(thread)
					return thread
				end,
				wait = function()
					coroutine.yield()
				end,
			},
		}, { __index = getfenv() })
	)
	fn().start(function()
		return "en"
	end, function(name)
		table.insert(f.opened, name)
	end)
	f.gui = f.playerGui:FindFirstChild("AuctionBanner")
	function f:lane(x, y, w, h)
		for key, value in
			{
				HudNotificationX = x,
				HudNotificationY = y,
				HudNotificationWidth = w,
				HudNotificationHeight = h,
			}
		do
			self.player:SetAttribute(key, value)
		end
	end
	function f:send(id)
		self.remotes.AuctionAnnounced.OnClientEvent:Fire({
			item = { id = id, count = 12, books = { { id = "long enchantment name", level = 1 } } },
			price = 123456,
			seller = "long seller name",
		})
	end
	function f:advance(seconds)
		self.now += seconds
		for _, thread in table.clone(self.threads) do
			if coroutine.status(thread) ~= "dead" then
				resume(thread)
			end
		end
	end
	function f:current()
		local lane = self.gui:FindFirstChild("NotificationLane")
		return lane, lane and lane:FindFirstChild("Announce")
	end
	f.node, f.Ui, f.signal, f.env = node, Ui, signal, getfenv(fn)
	return f
end

for _, case in
	{
		{ "owner top edge device safe", 750, 381, 0, -58, 0, 58, 307, -52.4, 240 },
		{ "A06 shared raw Y8 producer origin minus58", 705, 338, 0, -58, 0, 58, 236, 8, 210 },
		{ "A06 shared raw Y8 consumer origin zero", 705, 338, 0, 0, 0, 58, 236, 8, 210 },
		{ "small portrait", 320, 568, 0, 58, 0, 58, 8, 66, 304 },
		{ "portrait", 390, 844, 0, 58, 0, 58, 8, 66, 374 },
		{ "narrow landscape", 568, 320, 0, -58, 0, 58, 235, 66, 190 },
		{ "landscape cutout", 812, 375, 44, 58, 44, 58, 260, 66, 260 },
		{ "desktop", 1920, 1080, 0, 58, 0, 58, 700, 66, 520 },
	}
do
	local name, w, h, gx, gy, ix, iy, x, y, width = table.unpack(case)
	local f = fixture(w, h, rb.Vector2.new(gx, gy), rb.Vector2.new(ix, iy))
	check(
		name .. " announcement uses device safe area",
		f.gui.ScreenInsets == rb.Enum.ScreenInsets.DeviceSafeInsets
	)
	check(
		name .. " offer keeps core safe area",
		f.playerGui:FindFirstChild("AuctionOffer").ScreenInsets
			== rb.Enum.ScreenInsets.CoreUISafeInsets
	)
	f:lane(x, y, width, 52)
	f:send("very long item name")
	local lane, card = f:current()
	local pos, size = lane.AbsolutePosition, lane.AbsoluteSize
	check(
		name .. " inside shared raw rectangle without second inset",
		lane.Visible
			and pos.X >= x
			and math.abs(pos.Y - math.max(y, gy)) < 1 -- UDim offsets use whole pixels
			and pos.X + size.X <= x + width + 0.01
			and size.Y == 52
	)
	local close, open = card:FindFirstChild("Close"), card:FindFirstChild("Open")
	check(
		name .. " separate 44px close target fits",
		close.AbsoluteSize == rb.Vector2.new(44, 44)
			and close.AbsolutePosition.X + 44 <= pos.X + size.X + 0.01
			and close.AbsolutePosition.Y + 44 <= pos.Y + size.Y + 0.01
	)
	check(
		name .. " open target ends before close",
		open.AbsolutePosition.X + open.AbsoluteSize.X <= close.AbsolutePosition.X + 0.01
	)
	for _, child in card:GetChildren() do
		if child.ClassName == "TextLabel" and child.Visible then
			check(
				name .. " readable bounded text " .. child.Text,
				child.TextSize >= 12
					and child.AbsoluteSize.X >= 0
					and child.AbsolutePosition.X >= pos.X
					and child.AbsolutePosition.X + child.AbsoluteSize.X
						<= close.AbsolutePosition.X + 0.01
			)
		end
	end
end
do
	local f = fixture(705, 338, rb.Vector2.new(0, -58), rb.Vector2.new(0, 58))
	f:lane(236, 66, 210, 52)
	f.player:SetAttribute("HudToastActive", true)
	f:send("first")
	f:send("second")
	local lane = f:current()
	check(
		"toast present before arrival hides first queued announcement",
		not lane.Visible and f.player:GetAttribute("HudAuctionActive") == false
	)
	f:advance(20)
	check("hidden time cannot expire announcement", f:current() == lane)
	f.player:SetAttribute("HudToastActive", false)
	check("toast dismissal resumes same announcement immediately", lane.Visible)
	f:advance(2)
	f.player:SetAttribute("HudToastActive", true)
	check("new ordinary toast immediately hides visible announcement", not lane.Visible)
	f:advance(30)
	f.player:SetAttribute("HudToastActive", false)
	f:advance(5.9)
	check(
		"interrupted announcement keeps remaining display time",
		f:current() == lane and lane.Visible
	)
	f:advance(0.2)
	local nextLane, nextCard = f:current()
	check(
		"queue advances once after eight visible seconds",
		nextLane ~= lane and nextLane.Visible and #f.gui:GetChildren() == 1
	)
	nextCard:FindFirstChild("Open").Activated:Fire()
	check(
		"open action uses queued item's search and hides immediately",
		f.opened[1] == "second" and not nextLane.Visible
	)
	f:advance(0.1)
	check(
		"completed queue removes banner and active marker",
		f:current() == nil and f.player:GetAttribute("HudAuctionActive") == false
	)
end
do
	local f = fixture(705, 338, rb.Vector2.new(0, -58), rb.Vector2.new(0, 58))
	f:send("fallback")
	local lane, card = f:current()
	check(
		"missing contract uses own safe GUI top without doubled inset",
		lane.AbsolutePosition.Y == -54 and lane.AbsoluteSize.X == 400
	)
	f:lane(236, 66, 210, 52)
	check(
		"late lane contract moves active card",
		lane.AbsolutePosition == rb.Vector2.new(236, 66) and lane.AbsoluteSize.X == 210
	)
	f.player:SetAttribute("LoadingBlocked", true)
	f:advance(20)
	check("loading block pauses and hides auction card", not lane.Visible and f:current() == lane)
	f.player:SetAttribute("LoadingBlocked", false)
	f:lane(236, 66, 120, 52)
	check("unusable lane pauses instead of spilling over neighbors", not lane.Visible)
	f:lane(236, 66, 210, 52)
	check("usable lane resumes without dropping content", lane.Visible)
	for _, flag in { "HudBossActive", "HudWarzoneActive" } do
		f.player:SetAttribute(flag, true)
		f:advance(20)
		check(
			flag .. " pauses lower-priority auction for combat information",
			not lane.Visible and f:current() == lane
		)
		f.player:SetAttribute(flag, false)
		check(flag .. " release resumes original announcement", lane.Visible)
	end
	f.player:SetAttribute("HudGameplayOpen", false)
	f:advance(20)
	check(
		"menu or editor pauses auction without touching offer dialog",
		not lane.Visible and f:current() == lane
	)
	f.player:SetAttribute("HudGameplayOpen", true)
	check("gameplay resume restores paused auction", lane.Visible)
	f.camera.ViewportSize = rb.Vector2.new(390, 844)
	f.gui.AbsoluteSize, f.gui.AbsolutePosition = rb.Vector2.new(390, 844), rb.Vector2.new(0, 58)
	f:lane(8, 66, 374, 52)
	check(
		"rotation keeps same card in new screen lane",
		f:current() == lane
			and lane.Visible
			and lane.AbsolutePosition == rb.Vector2.new(8, 66)
			and lane.AbsoluteSize == rb.Vector2.new(374, 52)
	)
	card:FindFirstChild("Close").Activated:Fire()
	f:advance(0.1)
	check("close dismisses without opening auction", f:current() == nil and #f.opened == 0)
end
print(
	serde.encode(
		"json",
		{ actualSource = true, passed = #checks, checks = checks, realEngine = false },
		true
	)
)
