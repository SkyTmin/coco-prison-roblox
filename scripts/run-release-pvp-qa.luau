--!nocheck
-- Edit-only coordinator. Install make-release-pvp-qa output first. Never save while leased.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 92594200898716, "Use the confirmed Katorga place")
assert(
	not game.ServerStorage:FindFirstChild("QAReleaseMapLease"),
	"Restore an earlier map lease first"
)
local report = game.ServerStorage:FindFirstChild("QAReleasePvpResult")
	or Instance.new("StringValue")
assert(report.Value ~= "running", "Pvp test is already running")
report.Name, report.Value, report.Parent = "QAReleasePvpResult", "running", game.ServerStorage
task.spawn(function()
	local ok, result = xpcall(function()
		local source =
			game.HttpService:GetAsync("http://127.0.0.1:8766/scripts/qa-release-scene-session.luau")
		local makeLease = assert(loadstring(source))
		makeLease({ Prison = true })
		return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "release-pvp-v1")
	end, debug.traceback)
	local lease = game.ServerStorage:FindFirstChild("QAReleaseMapLease")
	local restored, restoreError = true, nil
	if lease then
		restored, restoreError = pcall(function()
			lease:Invoke("restore")
		end)
	end
	report.Value = game.HttpService:JSONEncode({
		ok = ok,
		result = result,
		mapRestored = restored,
		restoreError = if restored then nil else tostring(restoreError),
	})
end)
return "Pvp two-player test started; read ServerStorage.QAReleasePvpResult. Do not save until mapRestored."
