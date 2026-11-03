--!nocheck
-- Compile live harness/installers and guard the real remote/no-grant boundaries.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local server = fs.readFile("scripts/qa-release-tutorial-server.luau")
local client = fs.readFile("scripts/qa-release-tutorial-client.luau")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
check("server script compiles", loadstring(server) ~= nil)
check("client script compiles", loadstring(client) ~= nil)
for _, source in { server, client } do
	for _, forbidden in
		{
			"TutorialService",
			"Tutorial.dug(",
			"Tutorial.sold(",
			"Tutorial.upgraded(",
			"ResetProgress",
			'"Reset"',
		}
	do
		-- Comments describe the prohibition; inspect executable lines only.
		for line in source:gmatch("[^\r\n]+") do
			if not line:match("^%s*%-%-") then
				assert(not line:find(forbidden, 1, true), forbidden)
			end
		end
	end
end
check("no synthetic tutorial transition or reset calls", true)
local installer = process.exec("node", { "scripts/make-release-tutorial-qa.mjs" })
check("Edit installer emits and compiles", installer.ok and loadstring(installer.stdout) ~= nil)
local count = 0
for source in installer.stdout:gmatch("%[====%[(.-)%]====%]") do
	count += 1
	check("embedded live script " .. count .. " compiles", loadstring(source) ~= nil)
end
check("only two test scripts installed", count == 2)
local cleanup = process.exec("node", { "scripts/make-release-tutorial-qa.mjs", "--cleanup" })
check("exact-name cleanup compiles", cleanup.ok and loadstring(cleanup.stdout) ~= nil)
check(
	"Ready listener precedes folder publication",
	server:find("ready.OnServerEvent:Connect", 1, true)
		< server:find("folder.Parent = game.ReplicatedStorage", 1, true)
)
check(
	"server enforces fresh scoped account rather than manufacturing tutorial state",
	server:find("assert(report.testScope", 1, true)
		and server:find('"Refuse to reset or manufacture fresh tutorial state"', 1, true)
		and not server:find("p.tutorial =", 1, true)
)
for _, name in
	{
		"P.Mutate(",
		"P.MutateDurable(",
		"profile.coins =",
		"p.coins =",
		"profile.counters[",
		"StarterReward",
		"AchievementService.OnStat",
	}
do
	check(
		"live harness never manufactures resources: " .. name,
		not server:gsub("==", "~="):find(name, 1, true)
	)
end
for _, name in { "DigStart", "DigAccepted", "Sell", "UpgradeItem", "LevelUp" } do
	check(
		"ordinary client transport " .. name,
		client:find('R.event("' .. name .. '")', 1, true) ~= nil
	)
end
check(
	"loading readiness gate precedes Ready",
	client:find('player:GetAttribute("LoadingBlocked") == false', 1, true)
		< client:find('phase = "ready"', 1, true)
)
check("twenty minute deadline recorded", server:find("task.delay(1200", 1, true) ~= nil)
check(
	"real mine natural reset clock matches server clock",
	server:find("mine.resetAt-os.clock()", 1, true) ~= nil
		or server:find("mine.resetAt - os.clock()", 1, true) ~= nil
)
check("real support block selected separately", server:find("local support", 1, true) ~= nil)
check(
	"VirtualInput drives actual shovel selection",
	client:find("CreateVirtualInput", 1, true) ~= nil
		and client:find("SendMouseButton", 1, true) ~= nil
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	realProfiles = false,
	realStores = false,
	liveExecutionClaimed = false,
}))
