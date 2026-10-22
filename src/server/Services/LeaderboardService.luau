--!strict
-- Spawn top boards [владелец 22.10, скриншоты; клиент prison.classic.board.top.*]: Топ по крысам (чистые),
-- по деньгам, по уровню, по блокам (чистые). One OrderedDataStore per board for the whole game: each player's
-- values are written every WRITE_EVERY seconds when they changed, and when they leave; the top TOP_N of each
-- board is read every READ_EVERY seconds. Names (display name, nickname, faction) live in TopNames_v1, written
-- when they change. Every PUBLISH_EVERY seconds the stored top, overlaid with the live values of the players
-- on this server, goes to ReplicatedStorage.Tops.<board> (a JSON StringValue) for src/client/TopBoards.luau.
-- Without DataStore access (Studio without API access) the boards show the players on this server.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(script.Parent.ProfileService)
local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)

local LeaderboardService = {}
local started = false

local TOP_N = 20
local WRITE_EVERY = 120
local READ_EVERY = 90
local PUBLISH_EVERY = 10

type Board = { id: string, store: string, value: (Types.Profile) -> number }
local BOARDS: { Board } = {
	{
		id = "rats",
		store = "Top_ratsClean_v1",
		value = function(p)
			return p.stats.rats or 0
		end,
	},
	{
		id = "money",
		store = "Top_money_v1",
		value = function(p)
			return p.coins -- integer units (1/moneyScale); the client divides
		end,
	},
	{
		id = "level",
		store = "Top_level_v1",
		value = function(p)
			return p.level
		end,
	},
	{
		id = "blocks",
		store = "Top_blocksClean_v1",
		value = function(p)
			return p.stats.blocksClean or 0
		end,
	},
}

type Meta = { n: string, k: string?, f: string? }
type Row = { id: number, v: number }

local stores: { [string]: OrderedDataStore } = {}
local namesStore: DataStore? = nil
local stored: { [string]: { Row } } = {} -- last read of each board
local names: { [number]: Meta } = {} -- cache, refreshed from TopNames_v1
local namesAt: { [number]: number } = {}
local written: { [Player]: { [string]: number } } = {}
local metaWritten: { [Player]: string } = {}
local folder: Folder

local function metaOf(player: Player, p: Types.Profile): Meta
	return {
		n = player.DisplayName,
		k = if typeof(p.nickname) == "string" and p.nickname ~= "" then p.nickname else nil,
		f = p.faction,
	}
end

-- creative testers and failed loads stay out of the global tops (the boards still show them live)
local function counts(player: Player): boolean
	return ProfileService.IsReal(player) and player:GetAttribute("Creative") ~= true
end

local function writePlayer(player: Player)
	local p = ProfileService.Get(player)
	if not p or not counts(player) then
		return
	end
	local last = written[player] or {}
	written[player] = last
	local key = tostring(player.UserId)
	for _, board in ipairs(BOARDS) do
		local v = math.floor(board.value(p))
		local store = stores[board.id]
		if store and last[board.id] ~= v then
			local ok = pcall(function()
				store:SetAsync(key, v)
			end)
			if ok then
				last[board.id] = v
			end
		end
	end
	local meta = metaOf(player, p)
	names[player.UserId], namesAt[player.UserId] = meta, os.clock()
	local encoded = HttpService:JSONEncode(meta)
	if namesStore and metaWritten[player] ~= encoded then
		local ok = pcall(function()
			(namesStore :: DataStore):SetAsync(key, meta)
		end)
		if ok then
			metaWritten[player] = encoded
		end
	end
end

local function readBoards()
	for _, board in ipairs(BOARDS) do
		local store = stores[board.id]
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, TOP_N)
			end)
			if ok and page then
				local rows: { Row } = {}
				for _, entry in ipairs((page :: DataStorePages):GetCurrentPage()) do
					local id = tonumber(entry.key)
					if id then
						table.insert(rows, { id = id, v = entry.value })
					end
				end
				stored[board.id] = rows
			end
		end
	end
	-- names of the people in the tops (a few lookups per pass; the cache keeps them 10 minutes)
	local lookups = 0
	for _, rows in pairs(stored) do
		for _, row in ipairs(rows) do
			local fresh = namesAt[row.id] and os.clock() - namesAt[row.id] < 600
			if not fresh and lookups < 20 then
				lookups += 1
				local meta: Meta? = nil
				if namesStore then
					local ok, data = pcall(function()
						return (namesStore :: DataStore):GetAsync(tostring(row.id))
					end)
					if ok and typeof(data) == "table" and typeof(data.n) == "string" then
						meta = data :: any
					end
				end
				if not meta then
					local ok, name = pcall(function()
						return Players:GetNameFromUserIdAsync(row.id)
					end)
					meta = { n = if ok then name else "#" .. row.id }
				end
				names[row.id], namesAt[row.id] = meta :: Meta, os.clock()
			end
		end
	end
end

local function publish()
	local live: { [number]: Types.Profile } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local p = ProfileService.Get(player)
		if p then
			live[player.UserId] = p
			names[player.UserId], namesAt[player.UserId] = metaOf(player, p), os.clock()
		end
	end
	for _, board in ipairs(BOARDS) do
		local byId: { [number]: number } = {}
		for _, row in ipairs(stored[board.id] or {}) do
			byId[row.id] = row.v
		end
		for id, p in pairs(live) do
			byId[id] = math.floor(board.value(p))
		end
		local rows = {}
		for id, v in pairs(byId) do
			if v > 0 then
				table.insert(rows, { id = id, v = v })
			end
		end
		table.sort(rows, function(a, b)
			return if a.v ~= b.v then a.v > b.v else a.id < b.id
		end)
		local out = {}
		for i = 1, math.min(TOP_N, #rows) do
			local meta = names[rows[i].id] or { n = "#" .. rows[i].id }
			table.insert(out, { v = rows[i].v, n = meta.n, k = meta.k, f = meta.f })
		end
		local value = folder:FindFirstChild(board.id) :: StringValue
		local json = HttpService:JSONEncode(out)
		if value.Value ~= json then
			value.Value = json
		end
	end
end

function LeaderboardService.Start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "Tops"
	for _, board in ipairs(BOARDS) do
		local v = Instance.new("StringValue")
		v.Name = board.id
		v.Value = "[]"
		v.Parent = folder
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.store)
		end)
		if ok then
			stores[board.id] = store
		end
	end
	folder.Parent = ReplicatedStorage
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("TopNames_v1")
	end)
	if ok then
		namesStore = store
	end
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(function()
			writePlayer(player)
			written[player], metaWritten[player] = nil, nil
		end)
	end)
	task.spawn(function()
		task.wait(5)
		readBoards()
		local lastRead, lastWrite = os.clock(), os.clock()
		while true do
			publish()
			task.wait(PUBLISH_EVERY)
			if os.clock() - lastWrite >= WRITE_EVERY then
				lastWrite = os.clock()
				for _, player in ipairs(Players:GetPlayers()) do
					writePlayer(player)
				end
			end
			if os.clock() - lastRead >= READ_EVERY then
				lastRead = os.clock()
				readBoards()
			end
		end
	end)
end

return LeaderboardService
