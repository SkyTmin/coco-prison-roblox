--!strict
-- The Хранилище on the Спавн [вики DONATE-SHOP-BOOSTERS; сеть S6]: the personal ender chest (p.enderChest) grown to
-- up to 3 sections of 27 slots. Section 1 is open; the next one opens for dollars or crystals (two separate buttons),
-- strictly in order (Config.rules.survival.enderChest.unlock). Server (CaseService) and client (ChestWindow) read the
-- same rules: which sections are open, where a section's slot lives in p.enderChest, what the next one costs.
local Config = require(script.Parent.Config)

export type Price = { section: number, dollars: number, crystals: number }

local Vault = {}
local rules = Config.rules.survival.enderChest

Vault.SLOTS = rules.slots :: number -- slots in one section
Vault.MAX = (rules.sections or 1) :: number

-- open sections of a profile (1 … MAX)
function Vault.unlocked(p: any): number
	local n = if p then p.vaultSections else nil
	if typeof(n) ~= "number" or n ~= n then
		return 1
	end
	return math.clamp(math.floor(n), 1, Vault.MAX)
end

-- the p.enderChest slot behind slot `index` (1 … SLOTS) of section `section`
function Vault.slot(section: number, index: number): number
	return (section - 1) * Vault.SLOTS + index
end

-- what opening `section` costs (nil = not for sale: section 1 or beyond MAX)
function Vault.price(section: number): Price?
	for _, entry in ipairs((rules.unlock or {}) :: { Price }) do
		if entry.section == section then
			return entry
		end
	end
	return nil
end

return Vault
