--!nocheck
-- One normal DigStart integration check in Creative at prison. No profile fixture/replacement.
-- After the target appears, the client fires DigStart(target, target.Position + top-face offset).
assert(game.RunService:IsStudio() and game.RunService:IsServer())
local S = game.ServerScriptService.Server.Services
local P = require(S.ProfileService)
local Mine = require(S.MineService)
local Config = require(game.ReplicatedStorage.Shared.Config)
local p = game.Players:GetPlayers()[1]
local before = P.Get(p)
assert(p:GetAttribute("Creative") and before.location == "prison")
local mine = Mine.get("prison")
local part, key
for i, candidate in mine.parts do
	local x, y, z = Mine.coords(mine, i)
	local block = Config.block(mine.cells[i])
	if y == 1 and x >= 5 and x <= 8 and z >= 5 and z <= 8 and block.upgradeCounter then
		part, key = candidate, block.upgradeCounter
		break
	end
end
assert(part, "No exposed fixture cell")
local start = {
	orange = before.blocksTotal,
	clean = before.stats.blocksClean or 0,
	counter = Config.requirementHave(before, key),
}
local original = p.Character:GetPivot()
p.Character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 6, 0)))
p:RequestStreamAroundAsync(part.Position)
local target = Instance.new("ObjectValue")
target.Name, target.Value, target.Parent = "QAMiningDigTarget", part, game.ReplicatedStorage
local untilAt = os.clock() + 20
repeat
	task.wait(0.1)
until not part.Parent or os.clock() >= untilAt
task.wait(0.2)
local after = P.Get(p)
local orange = after.blocksTotal - start.orange
local clean = (after.stats.blocksClean or 0) - start.clean
local counter = Config.requirementHave(after, key) - start.counter
local report = {
	status = if not part.Parent
			and clean == 1
			and orange >= 1
			and math.abs(orange - counter) < 0.000001
		then "PASS"
		else "FAIL",
	blockCounter = key,
	orangeDelta = orange,
	cleanDelta = clean,
	upgradeCounterDelta = counter,
	orangeAfter = after.blocksTotal,
	cleanAfter = after.stats.blocksClean,
	limits = "One ordinary live DigStart. This legitimately mines one cell and keeps its normal rewards; no upgrade purchase was made.",
}
target:Destroy()
p.Character:PivotTo(original)
p.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
local output = Instance.new("StringValue")
output.Name, output.Value, output.Parent =
	"QAMiningLiveResult", game.HttpService:JSONEncode(report), game.ServerStorage
script:Destroy()
