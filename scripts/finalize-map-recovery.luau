--!nocheck
-- Remove only the identified obsolete QA lease/staging AFTER native recovery succeeds.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 92594200898716, "Confirmed Katorga only")
local storage = game.ServerStorage
local result = storage:FindFirstChild("RecoveryResult")
assert(result and result:IsA("StringValue"), "Native import result missing")
local report = game.HttpService:JSONDecode(result.Value)
assert(
	report.status == "COMPLETE" and report.sourceVersion == 428 and report.roots == 29,
	"Native import incomplete"
)
assert(
	report.sha256 == "4cd2545858497ff4776d5656cfdc0e98b92089550c327c346ec98f7b22172fe8",
	"Wrong native recovery backup"
)
assert(not storage:GetAttribute("MapRecoveryActive"), "Import still active")
assert(
	workspace.Quarry:GetAttribute("DesignVersion") == "2026-11-03-open-air-accepted",
	"Wrong Quarry"
)
assert(workspace.Quarry:GetAttribute("WorldBaseY") == 37500, "Wrong Quarry height")
local lease = storage:FindFirstChild("QAReleaseMapLease")
local staging = workspace:FindFirstChild("QAReleaseStaging")
assert(
	lease and lease:IsA("BindableFunction") and lease:GetAttribute("ParkedCount") == 30,
	"Unexpected legacy lease"
)
assert(
	staging and staging:IsA("Model") and staging:GetAttribute("ReleaseQaTemporary") == true,
	"Unexpected staging"
)
for _, object in staging:GetChildren() do
	assert(
		object:IsA("Part") and object.Name == "Floor" and object.Position == Vector3.new(0, 199, 0),
		"Unexpected staging content"
	)
end
-- These two objects were created solely by the retired QA harness. All restored map
-- roots remain in Workspace; current Prison, Terrain, code and settings are untouched.
staging:Destroy()
lease:Destroy()
local tutorialResult = storage:FindFirstChild("QAReleaseTutorialResult")
if tutorialResult and tutorialResult:IsA("StringValue") and tutorialResult.Value == "running" then
	tutorialResult.Value =
		game.HttpService:JSONEncode({ status = "INTERRUPTED_BEFORE_RECOVERY", successful = false })
end
return { status = "QA_RESIDUE_REMOVED", sourceVersion = 428, restoredRoots = 29, published = false }
