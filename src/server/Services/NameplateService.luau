--!strict
-- The name over a player [владелец 22.10: «ник персонажа: lvl (уровень, цвет фракции) Никнейм»; сеть 2019:
-- «цвет [9 УР] обозначает фракцию; если фракция не выбрана, цвет белый»]. The server only publishes the facts as
-- Player attributes (Level, Nick; Faction comes from FactionService), refreshed once a second; every client draws the plates itself
-- (src/client/Nameplates.luau). A server-made BillboardGui in the character missed text updates on the clients
-- with streaming on [2-player test 27.10: lvl 30 on the server, lvl 1 on both clients].

local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)

local NameplateService = {}
local started = false

local function publish(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	-- SetAttribute with the same value sends nothing; Faction is FactionService's
	player:SetAttribute("Level", profile.level)
	player:SetAttribute(
		"Nick",
		if typeof(profile.nickname) == "string" and profile.nickname ~= ""
			then profile.nickname
			else nil
	)
end

function NameplateService.Start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				publish(player)
			end
			task.wait(1)
		end
	end)
end

return NameplateService
