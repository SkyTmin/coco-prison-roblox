--!strict
-- «Пригласить друга» (docs/research/remaining-features-design.md, этап 10): Roblox's own invite window
-- (SocialService:PromptGameInvite). A friend who joins through it carries ReferredByPlayerId; ReferralService gives
-- the gifts. Used by the main menu tile and the level screen button.
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Invite = {}

local busy = false

-- Opens the invite window; onUnavailable() when Roblox says this player cannot send invites (age / policy, Studio).
function Invite.prompt(onUnavailable: () -> ())
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			local shown = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			if not shown then
				onUnavailable()
			end
		else
			onUnavailable()
		end
		busy = false
	end)
end

-- «Приглашено друзей: N / 20» — the invited friends who reached the friend level (ReferralService)
function Invite.count(profile: any): number
	return if profile and profile.stats then profile.stats.referrals or 0 else 0
end

return Invite
