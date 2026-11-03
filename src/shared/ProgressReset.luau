--!strict
-- Clear personal gameplay assets, including consumables bought with premium currency.
-- Persistent entitlements, receipts and reward/operation locks are retained by default.
local Persistence = require(script.Parent.Persistence)
local ProgressReset = {}
local CLEARED = {
	"level",
	"coins",
	"blocksTotal",
	"counters",
	"inventory",
	"caseContents",
	"enderChest",
	"artifacts",
	"armor",
	"selectedSlot",
	"professions",
	"keys",
	"needs",
	"hunger",
	"saturation",
	"achievements",
	"dug",
	"stats",
	"nicknames",
	"nickname",
	"skills",
	"trainer",
	"faction",
	"factionChanges",
	"lastPosition",
	"lastSeen",
	"location",
	"potionBrewedAt",
	"tutorial",
	"stash",
	"boosters",
	"activeBoosters",
	"playerTransferGifts",
	"casePages",
}

function ProgressReset.blocked(profile: any): boolean
	if
		profile.storageTransfer
		or profile.storageDeath
		or profile.bossRewardPending
		or profile.playerTransfer
		or profile.playerTransferIncoming
		or (profile.gang and profile.gang.id)
		or profile.announcePending
	then
		return true
	end
	for _, key in ipairs({ "gangOps", "pendingBoosters" }) do
		if typeof(profile[key]) == "table" and next(profile[key]) then
			return true
		end
	end
	local auction = profile.auction
	if typeof(auction) == "table" then
		for _, key in ipairs({ "lots", "pendingSells", "pendingBuys" }) do
			if typeof(auction[key]) == "table" and next(auction[key]) then
				return true
			end
		end
	end
	return false
end

function ProgressReset.apply(profile: any, defaults: any)
	for _, key in ipairs(CLEARED) do
		profile[key] = Persistence.copy(defaults[key])
	end
	if typeof(profile.settings) == "table" then
		local settings = table.clone(profile.settings)
		settings.trackedUpgrade, settings.hideRequirements = nil, nil
		profile.settings = settings
	end
	if typeof(profile.auction) == "table" then
		profile.auction.returns = {}
	end
	-- External old mail can arrive after this durable checkpoint. Its recipient generation
	-- must match before a grant; old packets are acknowledged without resurrecting reset assets.
	profile.playerTransferGeneration = (profile.playerTransferGeneration or 0) + 1
end

return ProgressReset
