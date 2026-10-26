--!strict
-- Who is drawing a bow and for how long [ваниль]: our own draw starts at once on this client (BowController sets
-- LocalDrawAt), the others' from the server's character attribute BowDrawAt (server time). Read by HeldItem (the
-- pull stages of the model), CharacterAnimator (the pose), FirstPersonHand and EffectsHud (the zoom).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local BOW = Config.vanilla.bow

local BowState = {}

BowState.LocalDrawAt = nil :: number? -- server time when our own draw began

-- server time the character's draw began, or nil when it is not drawing
function BowState.DrawStart(character: Model?): number?
	if not character then
		return nil
	end
	local localCharacter = Players.LocalPlayer.Character
	if character == localCharacter then
		return BowState.LocalDrawAt
	end
	local at = character:GetAttribute("BowDrawAt")
	return if typeof(at) == "number" then at else nil
end

-- seconds the character has been drawing (0 when it is not)
function BowState.Drawn(character: Model?): number
	local at = BowState.DrawStart(character)
	return if at then math.max(0, workspace:GetServerTimeNow() - at) else 0
end

-- the pull stage of the bow model like Minecraft's pulling_0/1/2 textures: from 0, 0.65 and 0.9 s; nil = not drawn
function BowState.Stage(character: Model?): number?
	if not BowState.DrawStart(character) then
		return nil
	end
	local t = BowState.Drawn(character)
	local stage = 0
	for i, from in ipairs(BOW.pullStages) do
		if t >= from then
			stage = i - 1
		end
	end
	return stage
end

-- the held model's id for the character's bow: "bow" or "bow_pulling_N"
function BowState.ModelId(character: Model?): string
	local stage = BowState.Stage(character)
	return if stage then "bow_pulling_" .. stage else "bow"
end

-- [ваниль] the draw curve: f = t / 1 s, (f² + 2f) / 3, at most 1
function BowState.Power(seconds: number): number
	local f = seconds / BOW.drawSeconds
	return math.min((f * f + 2 * f) / 3, 1)
end

return BowState
