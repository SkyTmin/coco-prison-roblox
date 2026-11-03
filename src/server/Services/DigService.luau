--!strict
-- Digging, server-authoritative like Minecraft: the client sends DigStart(part, hitPoint) and the server
-- runs the timer itself; when the vanilla break time has passed and the player is still digging the
-- same block, the block breaks. DigCancel (finger/button released, target changed) stops the timer.
-- The client is told the server's time with DigAccepted(part, needed) so its progress bar and its
-- local prediction (hiding the block a few ms before the server does) match the server exactly.
--
-- Reach is Minecraft's: 4.5 blocks from the eyes to the *hit point on the block face* [ваниль], never
-- to the block centre, so a block seen from above at the pit edge is diggable even when its centre is
-- farther away or hidden behind a neighbour. Line of sight is checked to that same hit point.
-- Rewards: inventory (dropsAs + dropCount), blocksTotal (× block upgrade), upgrade counters,
-- profession xp, ordinary key roll, artifact fragments, combo (resets after idle, see rules.combo), capture points
-- on the pads of the Дворы (WarzoneService).
-- Шот-шахты (location.shot, Config.shotTime): every block breaks in one tick with the mine's tool (or any), the
-- pause after it keeps them at rules.digging.shotHitsPerSecond; rewards, books and counters as usual [решение].

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local MiningStats = require(Shared.MiningStats)
local MiningDrops = require(Shared.MiningDrops)
local Numbers = require(Shared.Numbers)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local MineService = require(script.Parent.MineService)
local BookService = require(script.Parent.BookService)
local ProfessionService = require(script.Parent.ProfessionService)
local HungerService = require(script.Parent.HungerService)
local AchievementService = require(script.Parent.AchievementService)
local ArtifactService = require(script.Parent.ArtifactService)
local GangService = require(script.Parent.GangService)
local WarzoneService = require(script.Parent.WarzoneService)

local REACH = (Config.rules.digging and Config.rules.digging.reachStuds or 18) :: number -- [ваниль] 4.5 blocks
-- The client digs at 4.5 blocks; the server accepts up to 6 like the vanilla server [ваниль]: it sees the
-- player where they were a ping ago (still standing on a block the client already broke), and a strict
-- check rejected the blocks dug ahead, which then popped back [владелец 21.10]
local REACH_SLACK = 6.0
local EYE_HEIGHT = 1.5 -- studs above the root when there is no Head

type Dig = {
	token: number,
	part: BasePart,
	hit: Vector3,
	generation: number,
	startedAt: number,
	needed: number,
	pause: number, -- what was left of the pause after the previous block
	toolId: string?,
	toolLevel: number,
}
local TICK = 0.05
type Combo = { count: number, lastAt: number }

local DigService = {}
local digs: { [Player]: Dig } = {}
local combos: { [Player]: Combo } = {}
local lastBreakAt: { [Player]: number } = {} -- Minecraft's pause after a break [ваниль]
local lastPause: { [Player]: number } = {} -- that pause: 0 after an instantly broken block
local insomniaToastAt: { [Player]: number } = {} -- holding dig must not spam the toast
local shotToastAt: { [Player]: number } = {} -- the same for the shot mine's «only this tool» toast
local random = Random.new()
local nextToken = 0
local queuedStarts: { [Player]: { part: any, hit: any } } = {}
local beginDig: (Player, any, any) -> ()

local function advanceQueued(player: Player)
	local queued = queuedStarts[player]
	queuedStarts[player] = nil
	if queued then
		beginDig(player, queued.part, queued.hit)
	end
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function eyeOf(character: Model): Vector3?
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart")
		then root.Position + Vector3.new(0, EYE_HEIGHT, 0)
		else nil
end

-- The hit point must lie on (or just outside) the block's surface.
local function onSurface(part: BasePart, hit: Vector3): boolean
	local offset = part.CFrame:PointToObjectSpace(hit)
	local half = part.Size / 2
	local tolerance = 0.25
	return math.abs(offset.X) <= half.X + tolerance
		and math.abs(offset.Y) <= half.Y + tolerance
		and math.abs(offset.Z) <= half.Z + tolerance
		and (
			math.abs(math.abs(offset.X) - half.X) <= tolerance
			or math.abs(math.abs(offset.Y) - half.Y) <= tolerance
			or math.abs(math.abs(offset.Z) - half.Z) <= tolerance
		)
end

-- Minecraft reach and line of sight, both measured to the hit point on the face the player aims at.
local function inRange(player: Player, part: BasePart, hit: Vector3): boolean
	local character = player.Character
	local eye = if character then eyeOf(character) else nil
	if not character or not eye or not onSurface(part, hit) then
		return false
	end
	local delta = hit - eye
	-- a moving (falling) player is further along on their own screen than here: allow the distance
	-- they cover in a round trip (capped), on top of the vanilla slack
	local root = character.PrimaryPart
	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	local lag = math.min(0.5, player:GetNetworkPing() * 2 + 0.1)
	if delta.Magnitude > REACH + REACH_SLACK + math.min(speed, 80) * lag then
		return false
	end
	-- Intact mine cells block sight too. A jitter-adjacent next intent waits for its predecessor's
	-- server deadline, so that confirmed removal clears this ray without exempting an entire mine.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(eye, delta, params)
	return result == nil or result.Instance == part
end

-- Validates and returns the server-side break time, or nil (with a toast) when digging is not allowed.
local function check(player: Player, part: any, hit: any): (number?, MineService.Mine?, number?)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or typeof(hit) ~= "Vector3" then
		return nil, nil, nil
	end
	if not Numbers.finite(hit.X) or not Numbers.finite(hit.Y) or not Numbers.finite(hit.Z) then
		return nil, nil, nil
	end
	local mine, i = MineService.lookup(part)
	if not mine or not i or mine.rebuilding then
		return nil, nil, nil
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return nil, nil, nil
	end
	if mine.anchor:GetAttribute("GangMine") then
		local gang = GangService.gangOf(profile)
		if
			not gang
			or gang.id ~= mine.anchor:GetAttribute("GangMineOwner")
			or (tonumber(mine.anchor:GetAttribute("GangMineUntil")) or 0) <= os.time()
		then
			return nil, nil, nil
		end
	end
	if profile.level < mine.location.unlockLevel then
		toast(player, "level_too_low", mine.location.unlockLevel)
		return nil, nil, nil
	end
	if not inRange(player, part, hit) then
		toast(player, "too_far")
		return nil, nil, nil
	end
	local id = mine.cells[i]
	local block = if id then Config.block(id) else nil
	if not block then
		return nil, nil, nil
	end
	local toolId, toolLevel = InventoryService.heldTool(profile)
	-- creative test mode: every block breaks at once with any tool (CreativeService)
	local character = player.Character
	local haste = if character then tonumber(character:GetAttribute("Haste")) or 0 else 0
	-- a shot mine breaks every block in one hit, only its own tool where it names one (Config.shotTime)
	local shot = Config.shotTime(mine.location, toolId, toolLevel)
	if shot == false and not player:GetAttribute("Creative") then
		-- the client keeps sending DigStart while the button is held: one toast in 3 s
		if os.clock() - (shotToastAt[player] or -math.huge) <= 3 then
			return nil, nil, nil
		end
		shotToastAt[player] = os.clock()
		local tool = (mine.location.shot :: { tool: string? }).tool :: string
		local locale = Strings.localeOf(player)
		Remotes.event("Toast"):FireClient(
			player,
			Strings.t("shot_wrong_tool", locale, Strings.t("item_" .. tool, locale))
		)
		return nil, nil, nil
	end
	local needed = if player:GetAttribute("Creative")
		then Config.rules.creative.breakSeconds
		elseif shot then shot
		else Config.breakTime(block, toolId, toolLevel, haste)
	if not needed then
		if block.tool ~= "any" and toolId ~= block.tool then
			toast(player, "wrong_tool")
		else
			toast(player, "tool_too_weak")
		end
		return nil, nil, nil
	end
	if profile.needs.sleep <= 0 then
		-- insomnia: cannot dig [вики, владелец]
		local now = os.clock()
		if now - (insomniaToastAt[player] or 0) > 3 then
			insomniaToastAt[player] = now
			toast(player, "effect_insomnia_dig")
		end
		return nil, nil, nil
	end
	local dropId = if BookService.silkTouch(profile) then block.id else block.dropsAs or block.id
	if
		not InventoryService.canAutoSell(profile, dropId)
		and not InventoryService.canAdd(profile, dropId, 1)
	then
		toast(player, "bag_full")
		return nil, nil, nil
	end
	-- Nausea is visual only, as in Minecraft [ваниль, владелец 21.10]
	return needed, mine, i
end

local function comboMultiplier(combo: Combo): number
	return math.min(
		Config.rules.combo.maxMultiplier,
		1
			+ math.floor(combo.count / Config.rules.combo.blocksPerStep)
				* Config.rules.combo.stepBonus
	)
end

local function sendCombo(player: Player, combo: Combo)
	Remotes.event("Combo")
		:FireClient(player, comboMultiplier(combo), combo.count % Config.rules.combo.blocksPerStep)
end

-- Other players' break particles/sounds: only to those within FX_RANGE (they could not hear it
-- further away), batched into one unreliable event per frame per player — with many players digging
-- this was FireAllClients for every block.
local FX_RANGE = 48 -- studs, BlockBreak.OTHERS_RANGE
local FX_PER_FRAME = 12 -- entries per batch: stays under the 1000-byte unreliable payload
local fxQueue: { [Player]: { any } } = {}
local function queueBreakFx(
	breaker: Player,
	position: Vector3,
	size: Vector3,
	color: Color3,
	id: string
)
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if
			other ~= breaker
			and root
			and root:IsA("BasePart")
			and (root.Position - position).Magnitude <= FX_RANGE
		then
			local queue = fxQueue[other] or {}
			fxQueue[other] = queue
			if #queue < FX_PER_FRAME then
				table.insert(queue, { position, size, color, id })
			end
		end
	end
end

-- Other players see the cracks grow on the block being dug, like in Minecraft [2-player test 27.10: only the
-- break burst reached them]: { userId, part | false, needed, pause } to those within FX_RANGE; their
-- BlockBreak animates the stages itself, false (or the time running out) clears them.
local CRACK_MIN = 0.25 -- s: faster digs break before a crack could be seen
local function relayCrack(digger: Player, part: BasePart?, needed: number?, pause: number?)
	local own = digger.Character and digger.Character:FindFirstChild("HumanoidRootPart")
	local at = if part
		then part.Position
		elseif own and own:IsA("BasePart") then own.Position
		else nil
	if not at then
		return
	end
	local remote = Remotes.unreliable("DigCrackFx")
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if
			other ~= digger
			and root
			and root:IsA("BasePart")
			and (root.Position - at).Magnitude <= FX_RANGE
		then
			remote:FireClient(other, { digger.UserId, part or false, needed or 0, pause or 0 })
		end
	end
end

local function complete(player: Player, token: number)
	local dig = digs[player]
	if not dig or dig.token ~= token then
		return -- cancelled or replaced by another dig
	end
	local remaining = dig.startedAt + (dig.needed + dig.pause) - os.clock()
	if remaining > 0 then
		task.delay(remaining, complete, player, token)
		return
	end
	digs[player] = nil
	local part = dig.part
	local needed, mine, i = check(player, part, dig.hit)
	if not needed or not mine or not i or mine.generation ~= dig.generation then
		Remotes.event("DigRejected"):FireClient(player, part)
		advanceQueued(player)
		return
	end
	local profileNow = ProfileService.Get(player) :: Types.Profile
	local toolNow, levelNow = InventoryService.heldTool(profileNow)
	if toolNow ~= dig.toolId or levelNow ~= dig.toolLevel then
		Remotes.event("DigRejected"):FireClient(player, part) -- tool changed mid-dig: start over
		advanceQueued(player)
		return
	end
	local brokenCFrame, brokenSize, brokenColor = part.CFrame, part.Size, part.Color
	local blockId = MineService.breakBlock(mine, i)
	lastBreakAt[player] = os.clock()
	lastPause[player] = Config.pauseAfter(mine.location, dig.needed) -- shot mines: 8 blocks a second at most
	if not blockId then
		Remotes.event("DigRejected"):FireClient(player, part)
		advanceQueued(player)
		return
	end
	queueBreakFx(player, brokenCFrame.Position, brokenSize, brokenColor, blockId)
	if player.Character then
		player.Character:SetAttribute("AttackResetAt", workspace:GetServerTimeNow())
	end
	local block = Config.block(blockId) :: Config.Block
	-- Шёлковое касание: the block drops itself
	local dropId, dropCount = MiningDrops.resolve(block, BookService.silkTouch(profileNow), random)

	-- combo: every block extends it; it resets after rules.combo.breakAfterIdleSeconds without digging
	local now = os.clock()
	local combo = combos[player] or { count = 0, lastAt = now }
	if now - combo.lastAt > Config.rules.combo.breakAfterIdleSeconds then
		combo.count = 0
	end
	combo.count += 1
	combo.lastAt = now
	combos[player] = combo
	local comboMult = comboMultiplier(combo)

	local keyFound = false
	local artifactNotices: { ArtifactService.Notice } = {}
	local keyFull = false
	local overflow = 0
	local sold, soldItems = 0, 0
	ProfileService.Mutate(player, function(p)
		-- the gang perk Фарт: the block drops one more item [решение: +1 % за уровень]
		dropCount += if math.random() < GangService.perk(p, "luck") then 1 else 0
		-- the auto-sell [владелец 28.10: «когда игрок копает, предмет сразу продаётся … по центру экрана сумма»;
		-- вики: «+0,057 $» = цена скупщика с множителями]: the drop goes straight to the buyer's price, the same
		-- rounding as InventoryService.sellAll; anything the buyer does not take still goes to the bag
		sold, soldItems =
			InventoryService.autoSell(p, dropId, dropCount, ProfessionService.moneyMultiplier(p))
		if soldItems == 0 then
			overflow = InventoryService.add(p, dropId, dropCount)
		end
		local blockMult = (1 + p.professions.upgrades.blocks * Config.professions.upgrades.blocks)
			* Boosters.multiplier(p, "blocks")
		-- the gang perk Конверсия: the block counts twice in the stats [решение: +1 % за уровень]
		local counted = if math.random() < GangService.perk(p, "conversion") then 2 else 1
		MiningStats.credit(p, blockId, 1, blockMult * comboMult * counted)
		local toolId = InventoryService.heldTool(p)
		if toolId == "pickaxe" then
			ProfessionService.addXp(p, "mason", 1)
		elseif toolId == "shovel" then
			ProfessionService.addXp(p, "surveyor", 1)
		end
		-- Счастливчик raises the key chance [меню 26.10; +20 % за уровень — решение]
		local chance = Config.keys.ordinaryKeyChancePerBlock * Skills.keyChanceMultiplier(p)
		p.counters["_keyPity"] = (p.counters["_keyPity"] or 0) + 1
		if math.random() < chance or p.counters["_keyPity"] >= Config.keys.ordinaryKeyPity then
			if InventoryService.canAdd(p, "ordinary_key", 1) then
				p.counters["_keyPity"] = 0
				InventoryService.add(p, "ordinary_key", 1)
				keyFound = true
			else
				p.counters["_keyPity"] = Config.keys.ordinaryKeyPity
				keyFull = true
			end
		end
		artifactNotices = ArtifactService.RollDig(p)
	end)
	HungerService.OnBlockDug(player)
	require(script.Parent.TutorialService).OnDug(
		player,
		mine.id,
		dropId,
		math.max(0, dropCount - overflow),
		soldItems
	)
	GangService.progress(player, "dig", 1) -- gang quests: blocks
	GangService.progress(player, "sellItems", soldItems) -- gang quests: the auto-sell is selling too [решение]
	AchievementService.OnDug(player, blockId)
	WarzoneService.OnDug(player, mine.id) -- the Дворы: a block of a point's pad is a capture point
	ArtifactService.Notify(player, artifactNotices)
	if overflow > 0 or keyFull then
		toast(player, "bag_full")
	end
	if keyFound then
		toast(player, "key_found")
	end
	if sold > 0 then
		Remotes.event("AutoSold"):FireClient(player, sold)
	end
	sendCombo(player, combo)
	-- the tool's ancient books: Барыга, Археолог, Молот, Пластолом
	BookService.onDug(
		player,
		mine,
		i,
		dig.hit - brokenCFrame.Position,
		dropId,
		dropCount,
		comboMult
	)
	advanceQueued(player)
end

-- Token bucket per player [docs/research/server-scaling.md]: instant mining is 20 blocks a second, a
-- little more is allowed for retries; a flooding (or cheating) client is refused, not processed.
local DIG_RATE, DIG_BURST = 25, 10
local digTokens: { [Player]: { tokens: number, at: number } } = {}
local function takeDigToken(player: Player): boolean
	local now = os.clock()
	local bucket = digTokens[player] or { tokens = DIG_BURST, at = now }
	digTokens[player] = bucket
	bucket.tokens = math.min(DIG_BURST, bucket.tokens + (now - bucket.at) * DIG_RATE)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

beginDig = function(player: Player, part: any, hit: any)
	local previous = digs[player]
	digs[player] = nil
	local needed, mine = check(player, part, hit)
	if not needed or not mine then
		if typeof(part) == "Instance" then
			Remotes.event("DigRejected"):FireClient(player, part) -- show it again now, not after a timeout
		end
		if previous and previous.needed >= CRACK_MIN then
			relayCrack(player, nil)
		end
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local toolId, toolLevel = InventoryService.heldTool(profile)
	-- rapid taps cannot skip the pause: the timer simply includes what is left of it
	local pause =
		math.max(0, (lastPause[player] or 0) - (os.clock() - (lastBreakAt[player] or -math.huge)))
	nextToken += 1
	local token = nextToken
	digs[player] = {
		token = token,
		part = part,
		hit = hit,
		generation = mine.generation,
		startedAt = os.clock(),
		needed = needed,
		pause = pause,
		toolId = toolId,
		toolLevel = toolLevel,
	}
	Remotes.event("DigAccepted"):FireClient(player, part, needed, pause)
	if needed >= CRACK_MIN then
		relayCrack(player, part, needed, pause)
	elseif previous and previous.needed >= CRACK_MIN then
		relayCrack(player, nil)
	end
	task.delay(needed + pause, complete, player, token)
end

local function onDigStart(player: Player, part: any, hit: any)
	if not takeDigToken(player) then
		if typeof(part) == "Instance" then
			Remotes.event("DigRejected"):FireClient(player, part)
		end
		return
	end
	local previous = digs[player]
	queuedStarts[player] = nil -- at most one next intent; never accumulate a burst of free mining
	if previous then
		local remaining = previous.startedAt + (previous.needed + previous.pause) - os.clock()
		if remaining <= 0 then
			complete(player, previous.token)
		elseif previous.part == part then
			return -- retrying the same target cannot shorten or restart its deadline
		elseif remaining <= TICK then
			queuedStarts[player] = { part = part, hit = hit }
			return -- jitter tolerance queues work; complete still enforces the full timer
		end
	end
	beginDig(player, part, hit)
end

local function onDigCancel(player: Player)
	queuedStarts[player] = nil
	local dig = digs[player]
	digs[player] = nil
	if dig and dig.needed >= CRACK_MIN then
		relayCrack(player, nil)
	end
end

function DigService.Start()
	local fxRemote = Remotes.unreliable("BlockBrokenFx") -- created up front so clients can listen
	Remotes.unreliable("DigCrackFx")
	RunService.Heartbeat:Connect(function()
		for other, queue in pairs(fxQueue) do
			if other.Parent then
				fxRemote:FireClient(other, queue)
			end
		end
		table.clear(fxQueue)
	end)
	Remotes.event("DigAccepted")
	Remotes.event("DigRejected")
	Remotes.event("DigStart").OnServerEvent:Connect(onDigStart)
	Remotes.event("DigCancel").OnServerEvent:Connect(onDigCancel)
	-- Legacy name kept for older clients: the server timer decides, the message itself does nothing.
	Remotes.event("DigFinish").OnServerEvent:Connect(function() end)
	Players.PlayerRemoving:Connect(function(player)
		queuedStarts[player] = nil
		digs[player] = nil
		combos[player] = nil
		lastBreakAt[player] = nil
		lastPause[player] = nil
		digTokens[player] = nil
		fxQueue[player] = nil
		insomniaToastAt[player] = nil
		shotToastAt[player] = nil
	end)
	-- combo idle timer (wall clock, independent of frame rate): reset and tell the client
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for player, combo in pairs(combos) do
			if
				combo.count > 0
				and now - combo.lastAt > Config.rules.combo.breakAfterIdleSeconds
			then
				combo.count = 0
				sendCombo(player, combo)
			end
		end
	end)
end

return DigService
