--!nocheck
-- Actual FavoriteCard source, isolated UI/clock/menu/prompt/remotes. No real favorite prompt.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-critical-hud-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local player, gui =", 1, true)) - 1)
local boundary = assert(loadstring(prefix .. "\nreturn {node=node, signal=signal}"))()
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function fixture()
	local f = { now = 0, threads = {}, remotes = {}, prompts = 0 }
	local function node(kind)
		local n = boundary.node(kind)
		n.ZIndex, n.Activated = 0, boundary.signal()
		function n:GetDescendants()
			local out = {}
			for _, child in self:GetChildren() do
				table.insert(out, child)
				for _, desc in child:GetDescendants() do
					table.insert(out, desc)
				end
			end
			return out
		end
		function n:IsA(id)
			return id == kind or id == "GuiObject"
		end
		function n:Destroy()
			self.Destroying:Fire()
			self.Parent, self.destroyed = nil, true
		end
		return n
	end
	local function make(kind, parent, text, size, pos)
		local n = node(kind)
		n.Parent, n.Text, n.Size, n.Position = parent, text, size, pos
		return n
	end
	local heartbeat = boundary.signal()
	local player, gui = node("Player"), node("ScreenGui")
	f.player, f.gui = player, gui
	local response = boundary.signal()
	f.response = response
	local profile = { level = 5, stats = { playSeconds = 60 } }
	f.profile = profile
	local modules = {
		Config = {
			referrals = { favorite = { level = 5, playMinutes = 1 } },
			icons = { icons = {} },
		},
		Remotes = {
			event = function()
				return {
					FireServer = function(_, choice)
						table.insert(f.remotes, choice)
					end,
				}
			end,
		},
		Strings = {
			t = function(key)
				return key
			end,
		},
		Ui = {
			colors = { text = rb.Color3.new() },
			card = function(parent, size, pos)
				return make("Frame", parent, nil, size, pos)
			end,
		},
		WindowKit = {
			text = function(parent, text, size, pos)
				return make("TextLabel", parent, text, size, pos)
			end,
			fit = function() end,
			actionButton = function(parent, size, pos)
				local button = make("TextButton", parent, nil, size, pos)
				return button, make("TextLabel", button), make("Frame", button)
			end,
			gradient = function() end,
			pressable = function() end,
		},
	}
	local shared = { Config = "Config", Remotes = "Remotes", Strings = "Strings" }
	local services = {
		Players = { LocalPlayer = player },
		RunService = { Heartbeat = heartbeat },
		ReplicatedStorage = {
			WaitForChild = function()
				return shared
			end,
		},
		AvatarEditorService = {
			PromptSetFavoriteCompleted = response,
			PromptSetFavorite = function()
				f.prompts += 1
				if f.promptError then
					error("isolated prompt unavailable")
				end
			end,
		},
		TweenService = {
			Create = function(_, object, _, properties)
				local completed = boundary.signal()
				return {
					Completed = completed,
					Play = function()
						for key, value in properties do
							object[key] = value
						end
						completed:Fire()
					end,
				}
			end,
		},
	}
	local function resume(thread)
		local ok, seconds = coroutine.resume(thread)
		assert(ok, seconds)
		if coroutine.status(thread) ~= "dead" then
			f.threads[thread] = f.now + seconds
		else
			f.threads[thread] = nil
		end
	end
	local fn = assert(loadstring(fs.readFile("src/client/FavoriteCard.luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				PlaceId = 1,
				GetService = function(_, id)
					return assert(services[id], id)
				end,
			},
			script = { Parent = { Ui = "Ui", WindowKit = "WindowKit" } },
			require = function(id)
				return assert(modules[id], id)
			end,
			Enum = rb.Enum,
			Color3 = rb.Color3,
			Vector2 = rb.Vector2,
			UDim2 = rb.UDim2,
			TweenInfo = { new = function() end },
			workspace = {
				GetServerTimeNow = function()
					return f.now
				end,
			},
			task = {
				wait = coroutine.yield,
				spawn = function(callback)
					resume(coroutine.create(callback))
				end,
			},
		}, { __index = getfenv() })
	)
	fn().start(gui, function()
		return profile
	end, function()
		return "en"
	end)
	function f:advance(dt)
		self.now += dt
		heartbeat:Fire(dt)
		for thread, due in table.clone(self.threads) do
			if due <= self.now then
				resume(thread)
			end
		end
	end
	function f:card()
		for _, child in gui:GetChildren() do
			if child.Name == "FavoriteCard" and not child.destroyed then
				return child
			end
		end
	end
	function f:button(key)
		for _, child in self:card():GetChildren() do
			if child.ClassName == "TextButton" and child:GetChildren()[1].Text == key then
				return child
			end
		end
		error(key)
	end
	return f
end
do
	local f = fixture()
	f.player:SetAttribute("HudGameplayOpen", false) -- loading/editor is NOT an actual menu.
	f:advance(20)
	check("loading/editor alone never starts promotional card", f:card() == nil)
	f.player:SetAttribute("HudMenuOpen", true)
	f.player:SetAttribute("LoadingBlocked", true)
	f:advance(20)
	check("loading blocks even a stale menu flag", f:card() == nil)
	f.player:SetAttribute("LoadingBlocked", false)
	f:advance(20)
	local card = f:card()
	check("due card appears in real full menu", card and card.Visible)
	check(
		"promotion retains original360x128 dimensions",
		card.Size == rb.UDim2.fromOffset(360, 128)
	)
	f.player:SetAttribute("HudToastActive", true)
	check("menu action feedback immediately hides promotion", not card.Visible)
	f:advance(120)
	f.player:SetAttribute("HudToastActive", false)
	check(
		"feedback release resumes same promotion without aging",
		card.Visible and f:card() == card
	)
	f:advance(10)
	f.player:SetAttribute("HudMenuOpen", false)
	check("return to gameplay immediately hides card", not card.Visible)
	f:advance(120)
	check("hidden gameplay does not consume40s visible allowance", f:card() == card)
	f.player:SetAttribute("HudMenuOpen", true)
	check("menu reopening resumes same session card", card.Visible and f:card() == card)
	f:advance(29)
	check("39 visible seconds retains card", f:card() == card)
	f:advance(1)
	check("40 visible seconds dismisses without server answer", f:card() == nil and #f.remotes == 0)
	f:advance(120)
	check("ignored card remains once per session", f:card() == nil)
end
for _, choice in { "later", "success", "cancel", "error" } do
	local f = fixture()
	f.player:SetAttribute("HudMenuOpen", true)
	f:advance(20)
	if choice == "later" then
		f:button("favorite_later").Activated:Fire()
	else
		f.promptError = choice == "error"
		f:button("favorite_add").Activated:Fire()
		check(choice .. " invokes isolated prompt exactly once", f.prompts == 1)
		if choice ~= "error" then
			local card = f:card()
			check(choice .. " prompt hides card", not card.Visible)
			f.player:SetAttribute("HudMenuOpen", false)
			f.player:SetAttribute("HudMenuOpen", true)
			check(choice .. " menu toggle cannot reveal pending prompt", not card.Visible)
			f:advance(120)
			check(choice .. " hidden prompt does not expire", f:card() == card)
			f.response:Fire(
				if choice == "success"
					then rb.Enum.AvatarPromptResult.Success
					else rb.Enum.AvatarPromptResult.Failed
			)
		end
	end
	check(
		choice .. " persists one correct existing response",
		#f.remotes == 1 and f.remotes[1] == (if choice == "success" then "done" else "later")
	)
	check(choice .. " closes original card", f:card() == nil)
	f:advance(120)
	check(choice .. " never repeats within session", #f.remotes == 1 and f:card() == nil)
end
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, realPrompts = false, realStudio = false }
	)
)
