--!nocheck
-- Edit-only full-map coordinator. Install make-release-tutorial-qa output first.
-- Never detaches scenery, creates a map lease, or changes Archivable to reduce memory.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 92594200898716, "Use the confirmed Katorga place")
local report = game.ServerStorage:FindFirstChild("QAReleaseTutorialResult")
	or Instance.new("StringValue")
assert(
	report.Value ~= "running",
	"Previous tutorial run is still running or was interrupted; inspect it first"
)
report.Name, report.Value, report.Parent = "QAReleaseTutorialResult", "running", game.ServerStorage
task.spawn(function()
	local preflight, before
	local ok, result = xpcall(function()
		local source = game.HttpService:GetAsync(
			"http://127.0.0.1:8766/scripts/qa-release-full-map-preflight.luau"
		)
		preflight = assert(loadstring(source))
		before = preflight()
		return game:GetService("StudioTestService")
			:ExecuteMultiplayerTestAsync(1, "release-tutorial-v1")
	end, debug.traceback)
	local checked, after = false, nil
	if before then
		checked, after = pcall(preflight)
	end
	local mapIntact = checked and before.sceneryInstances == after.sceneryInstances
	if mapIntact then
		for index, root in before.roots do
			local current = after.roots[index]
			if
				not current
				or current.name ~= root.name
				or current.class ~= root.class
				or current.descendants ~= root.descendants
			then
				mapIntact = false
				break
			end
		end
	end
	report.Value = game.HttpService:JSONEncode({
		ok = ok,
		result = result,
		mode = "FULL_MAP",
		sceneryMoved = false,
		memoryReduction = false,
		mapIntact = mapIntact,
		before = before,
		after = if checked then after else nil,
		mapCheckError = if not checked
			then tostring(after or "Preflight did not complete")
			elseif not mapIntact then "Map root structure changed during the test"
			else nil,
	})
end)
return "Tutorial 1-client FULL_MAP test started; read ServerStorage.QAReleaseTutorialResult. "
	.. "Scenery stays in Workspace; full-map memory usage is not reduced."
