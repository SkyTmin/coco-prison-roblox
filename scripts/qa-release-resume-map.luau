--!nocheck
-- First Edit-only check after an interrupted STS session. Never save a leased/partial map.
-- This may restore the existing in-memory lease; it never rebuilds or replaces missing scenery.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 92594200898716, "Use the confirmed Katorga place")
local expected = {
	"Prison",
	"InsideOut",
	"Barn",
	"Quarry",
	"EdgeGate",
	"Tree",
	"Church",
	"Purgatory",
	"Eden",
	"Cherubim",
	"Gate",
	"Basement",
	"Warzone",
	"Ghetto",
	"Showcase",
	"FactionBase",
	"Paradise",
	"SunkenLighthouse",
	"RoyalGarden",
	"Pyramid",
	"Underworld",
	"MountainFoot",
	"EndCastle",
	"SnowyHand",
	"SpiderLair",
	"Market",
	"LeprechaunValley",
	"Castle",
	"Farm",
	"Kyoto",
}
local report = { status = "CHECKING", missing = {}, restored = false, rebuildingAttempted = false }
local lease = game.ServerStorage:FindFirstChild("QAReleaseMapLease")
if lease then
	-- A serialized BindableFunction cannot retain its Lua closure after Studio exits.
	-- Bound this call so a saved stale lease cannot freeze the recovery check forever.
	local done, ok, value = false, false, nil
	task.spawn(function()
		ok, value = pcall(function()
			return lease:Invoke("restore")
		end)
		done = true
	end)
	local deadline = os.clock() + 10
	repeat
		task.wait(0.05)
	until done or os.clock() >= deadline
	report.restored = done and ok and game.ServerStorage:FindFirstChild("QAReleaseMapLease") == nil
	report.restoreDetail = if done
		then tostring(value)
		else "No live restore callback completed; do not save"
end
for _, name in expected do
	if not workspace:FindFirstChild(name) then
		table.insert(report.missing, name)
	end
end
report.activeLease = game.ServerStorage:FindFirstChild("QAReleaseMapLease") ~= nil
local quarry = workspace:FindFirstChild("Quarry")
report.quarryVersion = quarry and quarry:GetAttribute("DesignVersion")
report.quarryBaseY = quarry and quarry:GetAttribute("WorldBaseY")
report.status = if #report.missing == 0 and not report.activeLease
	then "MAP_PRESENT"
	else "RECOVERY_REQUIRED"
report.note =
	"Presence check only. Review geometry and source versions before resuming QA; never publish here."
local out = game.ServerStorage:FindFirstChild("QAReleaseResumeMap") or Instance.new("StringValue")
out.Name, out.Value, out.Parent =
	"QAReleaseResumeMap", game.HttpService:JSONEncode(report), game.ServerStorage
return report
