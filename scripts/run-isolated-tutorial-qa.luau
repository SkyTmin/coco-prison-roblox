--!nocheck
-- Only this disposable local file may use reduced scenery/session-memory profile storage.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 0 and game.GameId == 0, "Refuse a linked/cloud DataModel")
assert(game.Name == "Katorga-Tutorial-QA-2026-11-03.rbxl", "Wrong local QA document")
assert(#game.Players:GetPlayers() == 0, "Refuse an occupied DataModel")
assert(not game.ServerStorage:FindFirstChild("QAReleaseMapLease"), "Refuse legacy lease")
local marker =
	assert(game.ServerStorage:FindFirstChild("QAIsolatedTutorial"), "Install local QA first")
assert(
	marker:GetAttribute("Mode") == "DISPOSABLE_LOCAL_TUTORIAL"
		and marker:GetAttribute("State") == "READY",
	"Local QA installation incomplete"
)
assert(
	marker:GetAttribute("BackupSHA256")
		== "da82e4c0a83933c0b074cafac50b447ecf73ea115fbb04739377373ecd8ca4a0",
	"Unexpected local backup"
)
local prison = assert(workspace:FindFirstChild("Prison"), "Real Prison missing")
assert(
	#prison:GetDescendants() == marker:GetAttribute("PrisonDescendants"),
	"Retained Prison changed"
)
for _, child in workspace:GetChildren() do
	assert(
		child == prison or child:IsA("Terrain") or child:IsA("Camera"),
		"Unexpected local scenery: " .. child.Name
	)
end
assert(
	game.ServerScriptService:FindFirstChild("QAReleaseTutorialServer"),
	"Tutorial server not installed"
)
assert(
	game.StarterPlayer.StarterPlayerScripts:FindFirstChild("QAReleaseTutorialClient"),
	"Tutorial client not installed"
)
local report = game.ServerStorage:FindFirstChild("QAIsolatedTutorialResult")
	or Instance.new("StringValue")
assert(report.Value ~= "running", "Previous isolated test is running/interrupted; inspect first")
report.Name, report.Value, report.Parent = "QAIsolatedTutorialResult", "running", game.ServerStorage
task.spawn(function()
	local ok, result = xpcall(function()
		return game.StudioTestService:ExecuteMultiplayerTestAsync(1, "release-tutorial-v1")
	end, debug.traceback)
	local decoded
	if ok and typeof(result) == "string" then
		local parsed, value = pcall(game.HttpService.JSONDecode, game.HttpService, result)
		if parsed then
			decoded = value
		end
	end
	local intact = prison.Parent == workspace
		and #prison:GetDescendants() == marker:GetAttribute("PrisonDescendants")
	local passed = ok
		and intact
		and decoded
		and decoded.status == "PASS"
		and decoded.storageMode == "SESSION_MEMORY"
		and decoded.cloudPersistenceTested == false
		and decoded.storageEvidence
		and decoded.storageEvidence.mode == "SESSION_MEMORY"
	report.Value = game.HttpService:JSONEncode({
		status = if passed then "PASS" else "FAIL",
		fixture = "DISPOSABLE_LOCAL_TUTORIAL",
		storageMode = "SESSION_MEMORY",
		cloudPersistenceTested = false,
		physicalPhoneTested = false,
		mainCloudMapTouched = false,
		retainedPrisonIntact = intact,
		ok = ok,
		result = decoded or result,
		sourceSHA256 = marker:GetAttribute("SourceSHA256"),
	})
end)
return "One negative-ID tutorial client starting in disposable local QA only; read ServerStorage.QAIsolatedTutorialResult. Do not save/publish this file."
