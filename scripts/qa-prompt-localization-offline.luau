--!nocheck
-- Actual Strings + PromptText + PromptLocalizer; simulated deferred Roblox property/attribute signals.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local checks, queued = {}, {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function load(path, env)
	local fn = assert(loadstring(fs.readFile(path), "@" .. path))
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end
local names = setmetatable({ Parent = { Config = "Config" } }, {
	__index = function(_, key)
		return key
	end,
})
local strings = load("src/shared/Strings/init.luau", {
	script = names,
	require = function(id)
		if id == "Config" then
			return { defaultLocale = "ru", locales = { "ru", "en", "es", "fr" }, moneyScale = 100 }
		end
		return load("src/shared/Strings/" .. id .. ".luau")
	end,
})
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		local c = { connected = true }
		self.listeners[c] = fn
		function c:Disconnect()
			self.connected = false
		end
		return c
	end
	function s:Fire(...)
		local args = table.pack(...)
		for c, fn in self.listeners do
			table.insert(queued, function()
				if c.connected then
					fn(table.unpack(args, 1, args.n))
				end
			end)
		end
	end
	function s:count()
		local n = 0
		for c in self.listeners do
			if c.connected then
				n += 1
			end
		end
		return n
	end
	return s
end
local function flush()
	local n = 0
	while #queued > 0 do
		n += 1
		assert(n < 500, "recursive property feedback")
		local fn = table.remove(queued, 1)
		fn()
	end
end
local function object(initial)
	local props, attributes, changed, attrChanged = initial or {}, {}, {}, {}
	local methods = {}
	function methods:GetAttribute(k)
		return attributes[k]
	end
	function methods:SetAttribute(k, v)
		attributes[k] = v
		if attrChanged[k] then
			attrChanged[k]:Fire()
		end
	end
	function methods:GetPropertyChangedSignal(k)
		changed[k] = changed[k] or signal()
		return changed[k]
	end
	function methods:GetAttributeChangedSignal(k)
		attrChanged[k] = attrChanged[k] or signal()
		return attrChanged[k]
	end
	methods.Destroying = signal()
	return setmetatable({}, {
		__index = function(_, k)
			return methods[k] or props[k]
		end,
		__newindex = function(_, k, v)
			if props[k] ~= v then
				props[k] = v
				if changed[k] then
					changed[k]:Fire()
				end
			end
		end,
	})
end
local player = object({ Parent = true })
player:SetAttribute("Locale", "en")
local prompts = { PromptShown = signal(), PromptHidden = signal() }
local services = {
	Players = { LocalPlayer = player },
	ProximityPromptService = prompts,
	ReplicatedStorage = {
		WaitForChild = function()
			return names
		end,
	},
	HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, v)
			return serde.decode("json", v)
		end,
	},
}
local modules = { Strings = strings }
local env = {
	game = {
		GetService = function(_, id)
			return assert(services[id], id)
		end,
	},
	script = { Parent = names },
	require = function(id)
		return assert(modules[id], id)
	end,
}
modules.PromptText = load("src/shared/PromptText.luau", env)
local localizer = load("src/client/PromptLocalizer.luau", env)
localizer.Start()
localizer.Start()
check("localizer starts only one shown listener", prompts.PromptShown:count() == 1)
local p = object({ ActionText = "", ObjectText = "", Parent = true })
modules.PromptText.Set(p, "ActionText", "canteen_prompt")
modules.PromptText.Set(p, "ObjectText", "ghetto_mine_details", 3, 5)
check("server keeps Russian fallback", p.ActionText == strings.t("canteen_prompt", "ru"))
local metadata = serde.decode("json", p:GetAttribute("LocalizedObjectText"))
check("server retains typed dynamic amounts", metadata.args[1] == 3 and metadata.args[2] == 5)
prompts.PromptShown:Fire(p)
flush()
for _, locale in { "en", "es", "fr", "ru" } do
	player:SetAttribute("Locale", locale)
	flush()
	check("shown action refreshes " .. locale, p.ActionText == strings.t("canteen_prompt", locale))
	check(
		"shown dynamic amount refreshes " .. locale,
		p.ObjectText == strings.t("ghetto_mine_details", locale, 3, 5)
	)
end
player:SetAttribute("Locale", "fr")
flush()
modules.PromptText.Set(p, "ObjectText", "ghetto_mason_details", 200, "1.5", 7)
flush()
check(
	"visible server metadata update preserves all argument types",
	p.ObjectText == strings.t("ghetto_mason_details", "fr", 200, "1.5", 7)
)
check(
	"deferred property writes do not replace source with translation",
	p:GetPropertyChangedSignal("ObjectText"):count() == 1
)
prompts.PromptHidden:Fire(p)
flush()
check(
	"hidden prompt restores latest canonical source",
	p.ObjectText == strings.t("ghetto_mason_details", "ru", 200, "1.5", 7)
)
check(
	"hidden prompt disconnects property listeners",
	p:GetPropertyChangedSignal("ActionText"):count() == 0
)
player:SetAttribute("Locale", "es")
flush()
prompts.PromptShown:Fire(p)
flush()
check(
	"reshown streamed prompt uses current locale",
	p.ObjectText == strings.t("ghetto_mason_details", "es", 200, "1.5", 7)
)
p.Destroying:Fire()
flush()
check(
	"destroyed prompt disconnects metadata listeners",
	p:GetAttributeChangedSignal("LocalizedObjectText"):count() == 0
)
local raw =
	object({ ActionText = "Арена босса", ObjectText = "Player_123", Parent = true })
prompts.PromptShown:Fire(raw)
flush()
check(
	"unkeyed static map names use world fallback",
	raw.ActionText == strings.worldText("Арена босса", "es")
)
check("unkeyed opaque names remain exact", raw.ObjectText == "Player_123")
raw.ActionText = "Торговец"
flush()
check(
	"server fallback-text updates while shown localize",
	raw.ActionText == strings.worldText("Торговец", "es")
)
player:SetAttribute("Locale", "ru")
flush()
check("fallback source survives locale roundtrip", raw.ActionText == "Торговец")
raw:SetAttribute("LocalizedObjectText", "not-json")
flush()
check("malformed metadata uses safe original fallback", raw.ObjectText == "Player_123")
for _, file in
	{
		"EconomyService",
		"LocationService",
		"NeedsService",
		"CaseService",
		"DailyService",
		"GangBaseService",
		"GangHouseService",
		"GhettoService",
		"GhettoMineService",
	}
do
	local source = fs.readFile("src/server/Services/" .. file .. ".luau")
	check(
		file .. " prompt constructors use explicit metadata",
		source:find("require(Shared.PromptText).Set", 1, true) ~= nil
			and source:match("%.ActionText%s*=") == nil
			and source:match("%.ObjectText%s*=") == nil
	)
end
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualModules = true,
	deferredSignals = true,
	realStudio = false,
}, true))
