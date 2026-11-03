--!nocheck
-- Read-only structural gate. This is not a backup or a geometry-fidelity comparison.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 92594200898716, "Use the confirmed Katorga place")
assert(
	not game.ServerStorage:FindFirstChild("QAReleaseMapLease"),
	"RECOVERY_REQUIRED: legacy map lease exists; restore/verify the complete map before QA"
)
assert(
	not workspace:FindFirstChild("QAReleaseStaging"),
	"RECOVERY_REQUIRED: legacy staging exists; restore/verify the complete map before QA"
)
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
local byName, invalid, roots = {}, {}, {}
for _, child in workspace:GetChildren() do
	byName[child.Name] = (byName[child.Name] or 0) + 1
end
local sceneryInstances = 0
for _, name in expected do
	local root = workspace:FindFirstChild(name)
	if not root then
		table.insert(invalid, name .. " missing")
	elseif byName[name] ~= 1 then
		table.insert(invalid, name .. " duplicated")
	elseif not (root:IsA("Model") or root:IsA("Folder")) or not root.Archivable then
		table.insert(invalid, name .. " invalid/non-Archivable root")
	else
		local descendants = #root:GetDescendants()
		if descendants == 0 then
			table.insert(invalid, name .. " empty")
		end
		sceneryInstances += descendants + 1
		table.insert(roots, { name = name, class = root.ClassName, descendants = descendants })
	end
end
assert(#invalid == 0, "RECOVERY_REQUIRED: " .. table.concat(invalid, "; "))
return {
	mode = "FULL_MAP",
	sceneryMoved = false,
	memoryReduction = false,
	sceneryInstances = sceneryInstances,
	roots = roots,
	note = "All map roots remain parented. Full-map STS can exhaust available memory; "
		.. "do not solve that by detaching the authoring map. Use a separate verified QA copy.",
}
