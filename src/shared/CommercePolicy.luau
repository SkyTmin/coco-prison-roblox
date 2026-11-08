--!strict
-- Shared presentation/purchase classification, not permission authority.
-- Currency itself and deterministic goods remain available; random generators
-- independently guard consumption on the server, including earned copies.
local Config = require(script.Parent.Config)
local CommercePolicy = {}
local RANDOM_INPUTS: { [string]: boolean } = {
	improved_ancient_key = true,
	ancient_key = true,
	nickname_key = true,
	ordinary_key = true,
	ancient_star = true,
	ancient_powder = true,
	ancient_book = true,
}

function CommercePolicy.IsRandomInput(id: any): boolean
	return typeof(id) == "string" and RANDOM_INPUTS[id] == true
end

function CommercePolicy.RequiresRandomPurchase(id: any): boolean
	local item = if typeof(id) == "string" then Config.donate.items[id] else nil
	return item ~= nil and CommercePolicy.IsRandomInput(item.give)
end

return CommercePolicy
