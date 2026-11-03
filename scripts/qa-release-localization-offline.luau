--!nocheck
-- Actual Strings/ItemInfo/config audit; no Roblox runtime, profiles, input, or network.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local prefix = fs.readFile("scripts/qa-economy-audit-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local p = fresh()", 1, true)) - 1)
local M = assert(loadstring(prefix .. "return modules"))()
local all, loaded, origins, issues, warnings = {}, {}, {}, {}, {}
local locales = { "ru", "en", "es", "fr" }
local count = {
	entries = 0,
	translations = 0,
	formats = 0,
	literalReferences = 0,
	itemTooltips = 0,
	contentNames = 0,
}
local function issue(kind, key, detail)
	table.insert(issues, { kind = kind, key = key, detail = detail })
end
local function part(name)
	if not loaded[name] then
		local data = assert(loadstring(fs.readFile("src/shared/Strings/" .. name .. ".luau")))()
		loaded[name] = data
		for key, entry in data do
			if all[key] then
				table.insert(warnings, "override " .. key .. ": " .. origins[key] .. " -> " .. name)
			end
			all[key], origins[key] = entry, name
		end
	end
	return loaded[name]
end
local names = setmetatable({ Parent = { Config = "Config" } }, {
	__index = function(_, k)
		return k
	end,
})
local source = fs.readFile("src/shared/Strings/init.luau")
local fn = assert(
	loadstring(
		source:gsub(
			"return Strings%s*$",
			"return {api=Strings, world=WORLD, blocks=BLOCKS, counters=COUNTERS, locations=LOCATIONS}"
		)
	)
)
setfenv(
	fn,
	setmetatable({
		script = names,
		require = function(id)
			return if id == "Config" then M.Config else part(id)
		end,
	}, { __index = getfenv() })
)
local strings = fn()
M.Strings = strings.api
local function loadShared(name)
	local f = assert(loadstring(fs.readFile("src/shared/" .. name .. ".luau")))
	setfenv(
		f,
		setmetatable({
			script = { Parent = names },
			require = function(id)
				return assert(M[id], id)
			end,
			Color3 = rb.Color3,
			Enum = rb.Enum,
		}, { __index = getfenv() })
	)
	M[name] = f()
	return M[name]
end
loadShared("Effects")
loadShared("Potions")
local ItemInfo = loadShared("ItemInfo")
local function formats(text)
	local list, at = {}, 1
	while true do
		local p = text:find("%", at, true)
		if not p then
			break
		end
		local suffix = text:sub(p + 1)
		if suffix:sub(1, 1) == "%" then
			at = p + 2
		elseif text:sub(1, p - 1):match("%d%s*$") then
			at = p + 1 -- literal percentages in no-argument labels
		else
			local token = suffix:match("^[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs]")
			if token then
				table.insert(list, token:sub(-1))
				at = p + #token + 1
			else
				at = p + 1
			end
		end
	end
	return list
end
local function cyrillic(text)
	for _, cp in utf8.codes(text) do
		if cp >= 0x400 and cp <= 0x4ff then
			return true
		end
	end
	return false
end
for key, entry in all do
	count.entries += 1
	local reference = formats(entry.ru or "")
	for _, locale in locales do
		local text = entry[locale]
		if typeof(text) ~= "string" or text == "" then
			issue("missing-locale", key, locale)
			continue
		end
		count.translations += 1
		local types = formats(text)
		if table.concat(types, ",") ~= table.concat(reference, ",") then
			issue(
				"format-mismatch",
				key,
				locale
					.. ": "
					.. table.concat(types, ",")
					.. " vs ru "
					.. table.concat(reference, ",")
			)
		end
		if #types > 0 then
			local args = {}
			for _, kind in types do
				table.insert(args, if kind == "s" or kind == "q" then "QA" else 2)
			end
			local ok, err = pcall(M.Strings.t, key, locale, table.unpack(args))
			count.formats += 1
			if not ok then
				issue("format-error", key, locale .. ": " .. tostring(err))
			end
		end
		if locale ~= "ru" and cyrillic(text) then
			issue("cyrillic-in-locale", key, locale .. ": " .. text)
		end
	end
end
for _, missing in ItemInfo.audit() do
	issue("item-info-audit", missing)
end
for _, id in ItemInfo.knownIds() do
	for _, locale in locales do
		local ok, result = pcall(
			ItemInfo.lines,
			{ id = id, count = 1, level = if M.Config.tools[id] then 1 else nil },
			locale
		)
		count.itemTooltips += 1
		if not ok then
			issue("tooltip-error", id, locale .. ": " .. tostring(result))
		end
	end
end
for id, card in M.Config.books.catalog do
	if typeof(card) == "table" then
		for _, locale in locales do
			for level = 1, #(M.Config.books.effects[id] or { 1 }) do
				local ok, result = pcall(
					ItemInfo.lines,
					{ id = "ancient_book", count = 1, books = { { id = id, level = level } } },
					locale
				)
				count.itemTooltips += 1
				if not ok then
					issue("book-tooltip-error", id, locale .. ": " .. tostring(result))
				end
			end
		end
	end
end
for id, block in M.Config.blocks do
	for _, locale in locales do
		count.contentNames += 1
		if locale ~= "ru" and M.Strings.blockName(id, block.name, locale) == block.name then
			issue("block-fallback", id, locale .. ": " .. block.name)
		end
	end
end
for _, loc in M.Config.locationsFile.locations do
	for _, locale in locales do
		count.contentNames += 1
		if locale ~= "ru" and M.Strings.locationName(loc.name, locale) == loc.name then
			issue("location-fallback", loc.id, locale .. ": " .. loc.name)
		end
	end
end
for _, tool in M.Config.tools do
	for _, up in tool.upgrades do
		for ru in up.requirements do
			for _, locale in { "en", "es", "fr" } do
				count.contentNames += 1
				if M.Strings.counterName(ru, locale) == ru then
					issue("counter-fallback", ru, locale)
				end
			end
		end
	end
end
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") and not path:find("src/shared/Strings/", 1, true) then
			local code = fs.readFile(path):gsub("%-%-[^\n]*", "")
			local function scan(pattern)
				for at, key, tail in code:gmatch(pattern) do
					if tail:sub(1, 2) == ".." then
						continue
					end
					count.literalReferences += 1
					if not all[key] then
						local _, line = code:sub(1, at):gsub("\n", "")
						issue("literal-key-missing", key, path .. ":" .. (line + 1))
					end
				end
			end
			scan('()Strings%.t%s*%(%s*"([%w_]+)"%s*(..?)')
			scan('()%f[%w][tT]%s*%(%s*"([%w_]+)"%s*(..?)')
			scan('()%f[%w]toast%s*%(%s*[%w_]+%s*,%s*"([%w_]+)"%s*(..?)')
			-- Direct refusal-key returns are subsequently localized by their callers.
			for key, tail in code:gmatch('return%s*"([%w]+_[%w_]+)"%s*(..?)') do
				if
					not path:find("src/client/", 1, true)
					and tail:sub(1, 2) ~= ".."
					and key ~= "not_ready"
					and key ~= "player_hurt"
				then
					count.literalReferences += 1
					if not all[key] then
						issue("refusal-key-missing", key, path)
					end
				end
			end
		end
	end
end
walk("src")
local worldSeen = {}
for _, file in fs.readDir("scripts") do
	if file:match("^build%-.*%.luau$") then
		local code = fs.readFile("scripts/" .. file):gsub("%-%-[^\n]*", "")
		for _, pattern in
			{
				'[Tt]ext%s*=%s*"([^"]+)"',
				'label%s*=%s*"([^"]+)"',
				'%f[%w]sign%s*%([^,\n]+,%s*"([^"]+)"',
				'%f[%w]billboard%s*%([^,\n]+,%s*"([^"]+)"',
				'%f[%w]boardText%s*%([^,\n]+,%s*"([^"]+)"',
			}
		do
			for ru in code:gmatch(pattern) do
				local decode = loadstring('return "' .. ru .. '"')
				if decode then
					ru = decode()
				end
				if not cyrillic(ru) or worldSeen[ru] then
					continue
				end
				worldSeen[ru] = true
				for _, locale in { "en", "es", "fr" } do
					count.contentNames += 1
					if M.Strings.worldText(ru, locale) == ru then
						issue("world-label-fallback", ru, locale .. ": scripts/" .. file)
					end
				end
			end
		end
	end
end
for _, card in M.Config.bosses.bosses do
	for _, locale in locales do
		count.contentNames += 1
		if not M.Strings.has("boss_name_" .. card.id, locale) then
			issue("boss-name-missing", card.id, locale)
		end
		if locale == "ru" or locale == "en" then
			local expected = if locale == "ru" then card.name else card.nameEn
			if M.Strings.bossName(card.id, card.name, locale) ~= expected then
				issue("boss-catalog-name-changed", card.id, locale)
			end
		end
	end
end
for _, test in
	{
		{ "ТЕЛЕПОРТАТОР", "en", "TELEPORTER" },
		{ "ТЕЛЕПОРТАТОР", "es", "TELETRANSPORTADOR" },
		{ "ТЕЛЕПОРТАТОР", "fr", "TÉLÉPORTEUR" },
		{ "ГАЛЕРЕЯ", "es", "GALERÍA" },
		{ "СНЕЖНАЯ ДЛАНЬ", "fr", "MAIN ENNEIGÉE" },
		{ "ТЕЛЕПОРТАТОР", "ru", "ТЕЛЕПОРТАТОР" },
		{ "Unknown Player's Board", "fr", "Unknown Player's Board" },
	}
do
	count.contentNames += 1
	local result = M.Strings.worldText(test[1], test[2])
	if result ~= test[3] then
		issue("world-case-regression", test[1], test[2] .. ": " .. result)
	end
end
for _, locale in locales do
	count.contentNames += 1
	if
		M.Strings.itemFullName("gang_mine_pass", nil, locale)
		~= M.Strings.t("item_gang_mine_pass", locale)
	then
		issue("item-only-block-name-regression", "gang_mine_pass", locale)
	end
end
local report = { counts = count, issues = issues, overrides = warnings, realProfiles = false }
print(serde.encode("json", report, true))
assert(#issues == 0, "Localization defects: " .. #issues)
