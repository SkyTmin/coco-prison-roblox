--!strict
-- The release reset archives gameplay, but an already fulfilled Roblox receipt must
-- remain recognized. Read only the legacy receipt ids; never copy its gameplay fields.
local DataStoreService = game:GetService("DataStoreService")
local StorageNames = require(game:GetService("ReplicatedStorage").Shared.StorageNames)
local Guard = {}
local legacy: DataStore? = nil
local options = Instance.new("DataStoreGetOptions")
options.UseCache = false

-- true = durably granted before the reset; false = confirmed absent; nil = retry.
-- No negative cache: a preceding legacy save must be visible on the next callback.
-- Old-version servers still need to be stopped at cutover: a read cannot fence a
-- concurrent old writer that has not committed its receipt yet.
function Guard.WasGranted(userId: number, purchaseId: string): boolean?
	local ok, record = pcall(function()
		if not legacy then
			legacy = DataStoreService:GetDataStore(StorageNames.LegacyProfileStore)
		end
		return (legacy :: DataStore):GetAsync("User_" .. tostring(userId), options)
	end)
	if not ok then
		return nil
	end
	if record == nil then
		return false
	end
	if typeof(record) ~= "table" then
		return nil
	end
	local receipts = record.receipts
	if receipts == nil then
		return false
	end
	if typeof(receipts) ~= "table" then
		return nil
	end
	return table.find(receipts, purchaseId) ~= nil
end

return Guard
