--!strict
-- Presentation only. Servers independently enforce the same account policies.
local Players = game:GetService("Players")
local CommercePolicy = require(game:GetService("ReplicatedStorage").Shared.CommercePolicy)
local CommerceUi = {}

function CommerceUi.reason(kind: string, itemId: string?): string?
	if kind == "purchase" and not CommercePolicy.RequiresRandomPurchase(itemId or "") then
		return nil
	end
	if kind == "item" and not CommercePolicy.IsRandomInput(itemId) then
		return nil
	end
	local player = Players.LocalPlayer
	if player:GetAttribute("PolicyState") ~= "ready" then
		return "policy_loading"
	end
	local attribute = if kind == "trade" then "PaidTradeAllowed" else "PaidRandomAllowed"
	if player:GetAttribute(attribute) ~= true then
		return if kind == "trade" then "policy_trade_unavailable" else "policy_random_unavailable"
	end
	return nil
end

function CommerceUi.watch(window: Instance, refresh: () -> ())
	local connections = {}
	for _, attribute in { "PolicyState", "PaidRandomAllowed", "PaidTradeAllowed" } do
		table.insert(
			connections,
			Players.LocalPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
		)
	end
	window.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
end

return CommerceUi
