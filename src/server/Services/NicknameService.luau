--!strict
-- Клички (этап 9; docs/research/remaining-features-design.md, facts §9). The nickname case (CaseService) adds a name to
-- p.nicknames and makes it active; «Ваши клички» (/names, /titles, /nickname, the menu tile; src/client/NicknameWindow
-- .luau) [клиент ranks.*: «Нажмите, чтобы применить / снять», «Выбран / Не выбран», «Недоступен»] sends
-- NicknameSet(name) — an owned name from Shared/Nicknames becomes p.nickname — or NicknameSet("") to take it off. Shown
-- in the chat, the TAB list, over the head and on the top boards [вики ORIGINAL-VS-OURS]: they all read p.nickname or
-- the player attribute Nick (NameplateService publishes it every second; set here at once so the change is instant).
-- QA (Studio): ServerStorage.NicknameDebug:Invoke(op, userId, name) — ("grant", id, name | "all") adds owned names;
-- ("set", id, name | "") applies like the window (ownership checked) → true / error key; ("reset", id) clears both;
-- ("state", id) → JSON {nickname, nicknames, attribute, displayName}.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nicknames = require(Shared.Nicknames)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local NicknameService = {}
local started = false
local THROTTLE = 0.4 -- [решение] s between two NicknameSet of one player
local lastSet: { [Player]: number } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- the shown name: the Nick attribute at once and the humanoid's display name «[Кличка] Ник» (nothing reads the
-- humanoid name over the head — Nameplates draws its own — but other Roblox UI may)
function NicknameService.apply(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local nick = if typeof(profile.nickname) == "string" and profile.nickname ~= ""
		then profile.nickname
		else nil
	player:SetAttribute("Nick", nick)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.DisplayName = if nick
			then "[" .. nick .. "] " .. player.DisplayName
			else player.DisplayName
	end
end

-- choose (an owned name) or take off ("" / nil); → nil on success or the Strings key of the refusal
function NicknameService.set(player: Player, name: string?): string?
	local profile = ProfileService.Get(player)
	if not profile then
		return "chat_not_ready"
	end
	local wanted = if name == "" then nil else name
	if wanted ~= nil and (not Nicknames.tier(wanted) or not Nicknames.owns(profile, wanted)) then
		return "nickname_not_owned"
	end
	if profile.nickname == wanted then
		return nil
	end
	ProfileService.Mutate(player, function(p)
		p.nickname = wanted
	end)
	NicknameService.apply(player)
	return nil
end

local function onSet(player: Player, raw: any)
	if raw ~= nil and (typeof(raw) ~= "string" or #raw > 64) then
		return
	end
	if os.clock() - (lastSet[player] or -math.huge) < THROTTLE then
		return
	end
	lastSet[player] = os.clock()
	local err = NicknameService.set(player, raw)
	if err then
		toast(player, err)
	elseif raw == nil or raw == "" then
		toast(player, "nickname_cleared")
	else
		toast(player, "nickname_applied", raw)
	end
end

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "NicknameDebug"
	hook.OnInvoke = function(op: string, userId: number, name: any): any
		local player = Players:GetPlayerByUserId(userId)
		if not player or not ProfileService.Get(player) then
			return false
		end
		if op == "grant" then
			ProfileService.Mutate(player, function(p)
				local owned = p.nicknames or {}
				for _, n in ipairs(Nicknames.list) do
					if (name == "all" or name == n) and not table.find(owned, n) then
						table.insert(owned, n)
					end
				end
				p.nicknames = owned
			end)
			return true
		elseif op == "set" then
			return NicknameService.set(player, if typeof(name) == "string" then name else nil)
				or true
		elseif op == "reset" then
			ProfileService.Mutate(player, function(p)
				p.nicknames = {}
				p.nickname = nil
			end)
			NicknameService.apply(player)
			return true
		elseif op == "state" then
			local p = ProfileService.Get(player) :: any
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			return HttpService:JSONEncode({
				nickname = p.nickname,
				nicknames = p.nicknames,
				attribute = player:GetAttribute("Nick"),
				displayName = humanoid and humanoid.DisplayName,
			})
		end
		return false
	end
	hook.Parent = ServerStorage
end

function NicknameService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("NicknameSet").OnServerEvent:Connect(onSet)
	ProfileService.OnLoaded(NicknameService.apply)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(NicknameService.apply, player) -- the humanoid is there by now
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSet[player] = nil
	end)
	debugHook()
end

return NicknameService
