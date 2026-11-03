--!nocheck
-- Retired after an interrupted test saved the live cloud map without its detached roots.
-- A Lua closure, nil parent, or non-Archivable folder is not a durable scene backup.
-- Keep this entry point fail-closed so old installers cannot remove scenery again.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
error(
	"UNSAFE_SCENE_LEASE_DISABLED: the authoring map must stay intact. "
		.. "Use a run-release-*-qa helper for full-map STS, or prepare a separate QA file "
		.. "from a verified complete local backup. This script changed no instances.",
	0
)
