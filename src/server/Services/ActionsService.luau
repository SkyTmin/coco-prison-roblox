--!strict
-- Review/confirm envelope only; actual transfers reuse ChatCommandService's authoritative checks.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Numbers = require(Shared.Numbers)
local Persistence = require(Shared.Persistence)
local Remotes = require(Shared.Remotes)
local TransferAccess = require(Shared.TransferAccess)
local Commands = require(script.Parent.ChatCommandService)
local Profile = require(script.Parent.ProfileService)
local ActionsService = {}
local quotes: { [Player]: any } = {}
local lastQuote: { [Player]: number } = {}
local started = false

local function failure(key: string): any
	return { ok = false, key = key, args = {} }
end

function ActionsService.Request(player: Player, action: any, payload: any): any
	if not Profile.IsReal(player) then
		return failure("chat_not_ready")
	end
	if action == "hide" then
		return Commands.ExecuteAction(player, "hide", {})
	end
	if action == "claim" then
		local moved = require(script.Parent.PlayerTransferService).Claim(player)
		return {
			ok = moved > 0,
			key = if moved > 0 then "release_transfer_received" else "release_transfer_space",
			args = {},
		}
	end
	if action == "confirm" then
		local quote = quotes[player]
		if not quote or quote.token ~= payload or quote.expires < os.clock() then
			return failure("release_action_expired")
		end
		quotes[player] = nil -- consume before validation/outcome; replay never sends another transfer
		local target = Players:GetPlayerByUserId(quote.recipient)
		if not target or target == player then
			return failure("release_action_recipient")
		end
		local nearby, reason = TransferAccess.Check(player, target)
		if not nearby then
			return failure(reason :: string)
		end
		local args = if quote.kind == "pay"
			then { target.Name, tostring(quote.amount) }
			else { target.Name, tostring(quote.slot), tostring(quote.count) }
		return Commands.ExecuteAction(player, quote.kind, args, quote.stack)
	end
	if action ~= "quote" or typeof(payload) ~= "table" then
		return failure("release_action_failed")
	end
	if os.clock() - (lastQuote[player] or -math.huge) < 0.2 then
		return failure("chat_wait")
	end
	lastQuote[player] = os.clock()
	quotes[player] = nil
	-- Studio's simulated players have negative IDs; resolving an actual connected Player remains required.
	if not Numbers.integer(payload.recipient, -9007199254740991) or payload.recipient == 0 then
		return failure("release_action_recipient")
	end
	local target = Players:GetPlayerByUserId(payload.recipient)
	if not target or target == player then
		return failure("release_action_recipient")
	end
	local nearby, reason = TransferAccess.Check(player, target)
	if not nearby then
		return failure(reason :: string)
	end
	local quote: any = {
		kind = payload.kind,
		recipient = target.UserId,
		name = target.Name,
		display = target.DisplayName,
		token = HttpService:GenerateGUID(false),
		expires = os.clock() + 30,
	}
	if quote.kind == "pay" then
		local amount = payload.amount
		if not Numbers.finite(amount) or amount < Config.chat.payMin or amount > 1e12 then
			return failure("chat_pay_usage")
		end
		quote.amount = math.floor(amount * 100 + 1e-6) / 100
	elseif quote.kind == "gift" then
		if
			not Numbers.integer(payload.slot, 1)
			or payload.slot > 36
			or not Numbers.integer(payload.count, 1)
		then
			return failure("release_action_changed")
		end
		local profile = Profile.Get(player)
		local stack = profile and profile.inventory[payload.slot]
		if not stack or payload.count > stack.count then
			return failure("release_action_changed")
		end
		quote.slot, quote.count, quote.stack = payload.slot, payload.count, Persistence.copy(stack)
	else
		return failure("release_action_failed")
	end
	quotes[player] = quote
	local reply = Persistence.copy(quote)
	reply.ok = true
	return reply
end

function ActionsService.Start()
	if started then
		return
	end
	started = true
	Remotes.func("PlayerAction").OnServerInvoke = ActionsService.Request
	Players.PlayerRemoving:Connect(function(player)
		quotes[player], lastQuote[player] = nil, nil
	end)
end

return ActionsService
