--!strict
-- MANUAL ROOT-ONLY READ-ONLY PREFLIGHT. Does not acquire profiles, write any store, reset or publish.
-- Standalone: may run in the OLD Play before stopping/syncing. Names are checked by reset-release-offline.
local RunService = game:GetService("RunService")
assert(
	RunService:IsStudio() and game.PlaceId == 92594200898716 and game.GameId == 10772144679,
	"Confirmed Katorga Studio only"
)
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local EPOCH = "release1_20261103"
local LIVE_PREFIX = "K_L_" .. EPOCH .. "_"
local CATALOG = {
	dataStores = {
		"PlayerProfiles_v3",
		"PlayerTransfers_v1",
		"AuctionLots_v1",
		"Gangs_v1",
		"GangTags_v1",
		"GangChest_v1",
		"FactionStorage_v1",
		"Referrals_v1",
		"TopNames_v1",
	},
	orderedDataStores = {
		"Top_ratsClean_v1",
		"Top_money_v1",
		"Top_level_v1",
		"Top_blocksClean_v1",
		"Top_deaths_v1",
	},
}
local report: any = {
	epoch = EPOCH,
	livePrefix = LIVE_PREFIX,
	activeEnvironment = "Studio; source may still be pre-cutover",
	checkedEnvironment = "live",
	dataStoreWrites = 0,
	legacyRecordsTouched = false,
	stores = {},
	livePersistentNamespacesEmpty = true,
}
for _, kind in { "dataStores", "orderedDataStores" } do
	for _, base in CATALOG[kind] do
		local name = LIVE_PREFIX .. base
		local ok, result = pcall(function()
			local pages = if kind == "orderedDataStores"
				then DataStoreService:GetOrderedDataStore(name):GetSortedAsync(false, 1)
				else DataStoreService:GetDataStore(name):ListKeysAsync("", 1)
			return { countOnFirstPage = #pages:GetCurrentPage(), finished = pages.IsFinished }
		end)
		local empty = ok and result.countOnFirstPage == 0 and result.finished
		table.insert(
			report.stores,
			{ kind = kind, name = name, readOk = ok, empty = empty, evidence = result }
		)
		report.livePersistentNamespacesEmpty = report.livePersistentNamespacesEmpty and empty
	end
end
local ownerOk, owner = pcall(function()
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	return DataStoreService:GetDataStore(LIVE_PREFIX .. "PlayerProfiles_v3")
		:GetAsync("User_6182034556", options)
end)
report.ownerProfileReadOk, report.ownerProfileEmpty = ownerOk, ownerOk and owner == nil
report.livePersistentNamespacesEmpty = report.livePersistentNamespacesEmpty
	and report.ownerProfileEmpty
report.status = if report.livePersistentNamespacesEmpty
	then "LIVE_PERSISTENT_NAMESPACES_EMPTY"
	else "REVIEW_REQUIRED"
report.memoryStoreContentsEnumerated = false
local value = game:GetService("ServerStorage"):FindFirstChild("ReleaseResetPreflight")
if not value then
	value = Instance.new("StringValue")
	value.Name, value.Parent = "ReleaseResetPreflight", game:GetService("ServerStorage")
end
(value :: StringValue).Value = HttpService:JSONEncode(report)
print(report.status)
return report
