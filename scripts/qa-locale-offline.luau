--!nocheck
-- Actual early Locale, ProfileService handlers/replication/save/reload, Strings and client rebuild prefix.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local coreLocale = "en-us"
local player = { LocaleId = "es-mx", attributes = {} }
function player:GetAttribute(k)
	return self.attributes[k]
end
function player:SetAttribute(k, v)
	self.attributes[k] = v
end
local fn = assert(loadstring(fs.readFile("src/first/Locale.luau")))
setfenv(
	fn,
	setmetatable({
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return { LocalPlayer = player }
				end
				assert(name == "LocalizationService", "early Locale may not wait on Shared")
				return { RobloxLocaleId = coreLocale }
			end,
		},
	}, { __index = getfenv() })
)
local Locale = fn()
for raw, expected in
	{
		["ru-ru"] = "ru",
		["EN-us"] = "en",
		["es-MX"] = "es",
		["fr-fr"] = "fr",
		["fr_CA"] = "fr",
		["de-de"] = "en",
		["zh-cn"] = "en",
		["uk-ua"] = "en",
		[""] = "en",
	}
do
	check("normalize " .. raw, Locale.normalize(raw) == expected)
end
check("invalid normalization", Locale.normalize({}) == "en" and Locale.normalize(nil) == "en")
check("account primary over core locale", Locale.detect(player) == "es")
player.LocaleId = "de-de"
coreLocale = "fr-fr"
check("unsupported account language goes English", Locale.detect(player) == "en")
player.LocaleId = ""
check("missing account property uses core locale", Locale.detect(player) == "fr")
player.LocaleId = "es-mx"
player:SetAttribute("LocaleManual", false)
player:SetAttribute("Locale", "en")
check(
	"early provisional server English does not override device",
	Locale.resolve(nil, player) == "es"
)
for _, manual in { "ru", "en", "es", "fr" } do
	check("saved manual wins " .. manual, Locale.resolve(manual, player) == manual)
end
player:SetAttribute("LocaleManual", true)
player:SetAttribute("Locale", "ru")
check(
	"replicated manual choice usable before profile snapshot",
	Locale.resolve(nil, player) == "ru"
)
player:SetAttribute("LocaleManual", false)

local prefix = fs.readFile("scripts/qa-profile-persistence-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("-- Exact acquisition ownership", 1, true)) - 1)
local fixture = assert(loadstring(prefix .. "\nreturn fixture"))()
local f = fixture()
local boundary = f:profile("locale-test")
local actor = f:player()
local session = f:session(boundary, actor, "locale-token")
local handlers = {}
local source = fs.readFile("src/server/Services/ProfileService.luau")
local first = assert(source:find('Remotes.event("SetAutoLocale").OnServerEvent:Connect', 1, true))
local last = assert(source:find("\n\tlocal ok, result = pcall", first, true))
fn = assert(loadstring(source:sub(first, last - 1)))
setfenv(
	fn,
	setmetatable({
		ProfileService = boundary.service,
		Config = { rules = { ui = { locales = { "ru", "en", "es", "fr" } } } },
		Remotes = {
			event = function(name)
				return {
					OnServerEvent = {
						Connect = function(_, callback)
							handlers[name] = callback
						end,
					},
				}
			end,
		},
	}, { __index = getfenv() })
)
fn()
check("fresh profile remains automatic", session.profile.locale == nil)
for _, bad in { false, {}, 42, "ru-ru", "de", "" } do
	handlers.SetAutoLocale(actor, bad)
end
check("bad auto packets ignored", actor:GetAttribute("AutoLocale") == nil)
local writes = f.writes
handlers.SetAutoLocale(actor, "fr")
check(
	"auto updates only session attributes",
	actor:GetAttribute("Locale") == "fr"
		and not actor:GetAttribute("LocaleManual")
		and session.profile.locale == nil
		and f.writes == writes
)
boundary.service.Replicate(actor)
check(
	"profile replication keeps automatic locale",
	actor:GetAttribute("Locale") == "fr" and session.profile.locale == nil
)
check("save automatic profile", boundary.save(actor, session, true))
local again = f:profile("locale-rejoin")
local rejoined = f:player()
local autoSession = f:session(again, rejoined, "locale-rejoin-token")
check(
	"auto locale not stored across rejoin",
	autoSession.profile.locale == nil and rejoined:GetAttribute("AutoLocale") == nil
)
-- SetLocale to the same visible auto language must still create an explicit choice.
handlers.SetLocale(actor, "fr")
check(
	"same visible language becomes manual",
	session.profile.locale == "fr" and actor:GetAttribute("LocaleManual") == true
)
handlers.SetAutoLocale(actor, "es")
check(
	"late auto packet cannot override manual",
	session.profile.locale == "fr" and actor:GetAttribute("Locale") == "fr"
)
-- The old session was released above; test manual persistence on the reacquired owner.
autoSession.profile.locale = "ru"
again.service.Replicate(rejoined)
check(
	"existing saved Russian treated manual",
	rejoined:GetAttribute("Locale") == "ru" and rejoined:GetAttribute("LocaleManual")
)
check("manual save succeeds", again.save(rejoined, autoSession, true))
local third = f:profile("locale-final")
local finalPlayer = f:player()
local finalSession = f:session(third, finalPlayer, "locale-final-token")
finalPlayer:SetAttribute("AutoLocale", "es")
third.service.Replicate(finalPlayer)
check(
	"manual selection survives device change/rejoin",
	finalSession.profile.locale == "ru" and finalPlayer:GetAttribute("Locale") == "ru"
)

local stringsPrefix = fs.readFile("scripts/qa-tutorial-panel-offline.luau")
stringsPrefix = stringsPrefix:sub(1, assert(stringsPrefix:find("local checks = {}", 1, true)) - 1)
local Strings = assert(loadstring(stringsPrefix .. "\nreturn M.Strings"))()
for _, language in { "ru", "en", "es", "fr" } do
	actor:SetAttribute("Locale", language)
	check(
		"server response locale " .. language,
		Strings.t("level", Strings.localeOf(actor)) == Strings.t("level", language)
	)
end
check("pre-handshake server fallback English", Strings.localeOf(nil) == "en")
local client = fs.readFile("src/client/init.client.luau")
first = assert(client:find("local function render(p:", 1, true))
last = assert(client:find("\n\tlanguageButton.Text =", first, true))
local render = assert(
	loadstring(client:sub(first, last - 1) .. "\n return rebuild,nextLocale\nend\nreturn render")
)
local refreshes = 0
local env = {
	player = player,
	profile = nil,
	locale = "es",
	script = {},
	game = {
		GetService = function()
			return { Loading = { Locale = "Locale", LoadingController = "Loading" } }
		end,
	},
	require = function(name)
		return if name == "Locale" then Locale else { Profile = function() end }
	end,
	localizeWorld = function()
		refreshes += 1
	end,
	TopBoards = {
		Refresh = function()
			refreshes += 1
		end,
	},
	LevelWindow = { celebrate = function() end },
}
setfenv(render, setmetatable(env, { __index = getfenv() }))
render = render()
player.LocaleId = "es-mx"
player:SetAttribute("LocaleManual", false)
local rebuild, current = render({ level = 1, location = "prison" })
check(
	"nil profile locale keeps automatic UI",
	not rebuild and current == "es" and player:GetAttribute("Locale") == "es"
)
rebuild, current = render({ level = 1, location = "prison", locale = "en" })
check(
	"manual selection rebuilds UI/world in chosen language",
	rebuild and current == "en" and refreshes == 2 and player:GetAttribute("Locale") == "en"
)
rebuild, current = render({ level = 1, location = "prison", locale = "en" })
check(
	"unchanged manual choice does not rebuild repeatedly",
	not rebuild and current == "en" and refreshes == 2
)
check("whole client compiles", loadstring(client) ~= nil)

local snapshotStart = assert(client:find("-- the profile crosses the network", 1, true))
local snapshotEnd = assert(client:find("-- then only the changes", snapshotStart, true))
local function snapshotFixture(acknowledged)
	local received, sent, renders = nil, 0, 0
	player:SetAttribute("AutoLocale", if acknowledged then "es" else nil)
	local connect = assert(loadstring(client:sub(snapshotStart, snapshotEnd - 1)))
	setfenv(
		connect,
		setmetatable({
			player = player,
			game = env.game,
			require = function(id)
				return if id == "Locale" then Locale else { SnapshotReady = function() end }
			end,
			Wire = {
				decode = function(value)
					return value
				end,
			},
			render = function()
				renders += 1
			end,
			Remotes = {
				event = function(name)
					if name == "ProfileUpdated" then
						return {
							OnClientEvent = {
								Connect = function(_, callback)
									received = callback
								end,
							},
						}
					end
					assert(name == "SetAutoLocale", "only auto-locale handshake may send")
					return {
						FireServer = function(_, language)
							assert(language == "es", "retry uses account language")
							sent += 1
						end,
					}
				end,
			},
		}, { __index = getfenv() })
	)
	connect()
	return function(loaded)
		received({}, loaded)
		return sent, renders
	end
end
local snapshot = snapshotFixture(false)
check("no retry before successful profile load", snapshot(false) == 0)
check("one auto-locale retry after loaded snapshot", snapshot(true) == 1)
check("repeated snapshots never spam auto-locale", snapshot(true) == 1)
snapshot = snapshotFixture(true)
check("server acknowledged locale needs no retry", snapshot(true) == 0)
print(serde.encode("json", {
	passed = #checks,
	actualLocale = true,
	actualServerHandlers = true,
	actualProfileSaveReload = true,
	actualClientRenderPrefix = true,
	realProfiles = false,
	nativeLocale = false,
}, true))
