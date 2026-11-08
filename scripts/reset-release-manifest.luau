--!nocheck
-- Local-only: generates the cutover/archival name manifest. No Roblox services or writes.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local function names(studio)
	local fn = assert(loadstring(fs.readFile("src/shared/StorageNames.luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function()
					return {
						IsStudio = function()
							return studio
						end,
					}
				end,
			},
		}, { __index = getfenv() })
	)
	return fn()
end
local live, studio = names(false), names(true)
local result = {
	epoch = live.ProductionDataEpoch,
	legacyReceiptStore = live.LegacyProfileStore,
	legacyReceiptAccess = "GetAsync only; receipt IDs only; no gameplay import",
	resetMechanism = "Switch namespaces when new build starts; no delete or overwrite",
	oldDataStoresRetained = true,
	cloudAPIsCalled = false,
	schemasChanged = false,
	namespaces = {},
}
for kind, bases in live.catalog do
	local rows = {}
	for _, base in bases do
		table.insert(
			rows,
			{ archived = base, live = live.progress(base), studio = studio.progress(base) }
		)
	end
	result.namespaces[kind] = rows
end
local destination = "docs/research/release-reset-namespaces-2026-11-03.json"
fs.writeFile(destination, serde.encode("json", result, true) .. "\n")
print("Generated local manifest: " .. destination .. "; no Roblox calls")
