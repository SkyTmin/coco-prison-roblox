--!strict
-- [владелец 03.11] New item/money transfers require nearby living players in this server.
-- Recovery of an already accepted durable transfer deliberately does not use this gate.
local Players = game:GetService("Players")
local Config = require(script.Parent.Config)
local TransferAccess = {}

function TransferAccess.Check(player: Player, target: Player): (boolean, string?)
	if
		player == target
		or not player.Parent
		or not target.Parent
		or Players:GetPlayerByUserId(player.UserId) ~= player
		or Players:GetPlayerByUserId(target.UserId) ~= target
	then
		return false, "release_action_recipient"
	end
	local a, b = player.Character, target.Character
	local ah = a and a:FindFirstChildOfClass("Humanoid")
	local bh = b and b:FindFirstChildOfClass("Humanoid")
	local ar = a and a:FindFirstChild("HumanoidRootPart")
	local br = b and b:FindFirstChild("HumanoidRootPart")
	if
		not ah
		or not bh
		or ah.Health <= 0
		or bh.Health <= 0
		or not ar
		or not br
		or not ar:IsA("BasePart")
		or not br:IsA("BasePart")
	then
		return false, "release_transfer_alive"
	end
	local distance = (ar.Position - br.Position).Magnitude
	local range = Config.chat.giftRangeBlocks * Config.rules.combat.blockStuds
	if distance ~= distance or distance > range then
		return false, "release_transfer_nearby"
	end
	return true, nil
end

return TransferAccess
