--!nocheck
-- One-use bridge for restarting the pre-fix live server. Read-only; no lock bypass.
assert(
	game.RunService:IsStudio() and game.PlaceId == 92594200898716,
	"Confirmed Katorga Studio only"
)
local player = assert(game.Players:GetPlayerByUserId(6182034556))
assert(player:GetAttribute("ProfileState") == "ready", "Profile must have loaded")
local store = game:GetService("DataStoreService"):GetDataStore("PlayerProfiles_v3")
local options = Instance.new("DataStoreGetOptions")
options.UseCache = false
local key = "User_" .. player.UserId
local original = store:GetAsync(key, options)
local token =
	assert(original and original._lock and original._lock.token, "No acquired profile lock")
game:BindToClose(function()
	local deadline = os.clock() + 22
	repeat
		task.wait(1)
		local ok, data = pcall(function()
			return store:GetAsync(key, options)
		end)
		if ok and (not data or not data._lock or data._lock.token ~= token) then
			print("[QA shutdown] original profile lock released; read-only bridge complete")
			return
		end
	until os.clock() >= deadline
	warn("[QA shutdown] release not confirmed within read-only bridge deadline")
end)
script:SetAttribute("Ready", true)
