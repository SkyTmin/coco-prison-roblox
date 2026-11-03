// Generates a guarded installer for one disposable LOCAL document. Does not open Studio.
// node scripts/make-isolated-tutorial-qa.mjs [--harness-only] --output place/qa-2026-11-03/tutorial-install.luau
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve, relative, sep, isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const expectedName = "Katorga-Tutorial-QA-2026-11-03.rbxl";
const backup = "place/recovery-2026-11-03/version-428/katorga-full-version-428.rbxl";
const expectedHash = "da82e4c0a83933c0b074cafac50b447ecf73ea115fbb04739377373ecd8ca4a0";
const digest = value => createHash("sha256").update(value).digest("hex");
const bytes = readFileSync(resolve(root, backup));
if (digest(bytes) !== expectedHash) throw new Error("Full native backup checksum changed; refusing installer");
const recoveryManifest = JSON.parse(readFileSync(resolve(root, "place/recovery-2026-11-03/version-428/manifest.json"), "utf8"));
const roots = [...new Set(["Prison", ...recoveryManifest.roots.map(entry => entry.name)])].sort();
if (roots.length !== 30) throw new Error("Expected the verified complete 30-root map manifest");
const quote = text => {
  let fence = "====";
  while (text.includes(`]${fence}]`)) fence += "=";
  return `[${fence}[${text}]${fence}]`;
};
const emitExisting = file => execFileSync(process.execPath, [resolve(root, file)], {
  cwd: root, encoding: "utf8", maxBuffer: 32 * 1024 * 1024,
});
const sync = emitExisting("scripts/make-studio-sync.mjs");
const ordinaryInstaller = emitExisting("scripts/make-release-tutorial-qa.mjs");
const replaceOnce = (source, from, to) => {
  if (source.split(from).length !== 2) throw new Error(`Expected exactly one instrumentation boundary: ${from}`);
  return source.replace(from, to);
};
const localStorageReport = source => replaceOnce(
  replaceOnce(source, 'status = "RUNNING",', 'status = "RUNNING",\n\tstorageMode = "SESSION_MEMORY",\n\tcloudPersistenceTested = false,'),
  'check("completed guide saved in isolated test scope", report.scopedSaveConfirmed == true)',
  'report.storageEvidence = require(game.ServerStorage.QAIsolatedTutorialStore).Evidence()\n\tcheck("completed guide checkpoint recorded in session memory; cloud persistence untested", report.scopedSaveConfirmed == true)');
const installer = localStorageReport(ordinaryInstaller);
const localServer = localStorageReport(readFileSync(resolve(root, "scripts/qa-release-tutorial-server.luau"), "utf8"));
const harnessOnly = process.argv.includes("--harness-only");
const adapter = readFileSync(resolve(root, "scripts/qa-isolated-tutorial-store.luau"), "utf8");
const metadata = {
  schema: 1, mode: "DISPOSABLE_LOCAL_TUTORIAL", expectedName, backup, backupSHA256: expectedHash,
  sourceSHA256: digest(sync), tutorialSourceSHA256: digest(ordinaryInstaller),
  adapterSHA256: digest(adapter), sourceScripts: (sync.match(/^do local s = at\(/gm) || []).length,
  storageMode: "SESSION_MEMORY", cloudPersistenceTested: false, physicalPhoneTested: false,
};
let output = `--!nocheck
-- DISPOSABLE LOCAL COPY ONLY. Never save/publish this document or run in the cloud place.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 0 and game.GameId == 0, "Refuse a linked/cloud DataModel")
assert(game.Name == "${expectedName}", "Wrong local QA document")
assert(#game.Players:GetPlayers() == 0, "Refuse an occupied DataModel")
assert(not game.ServerStorage:FindFirstChild("QAReleaseMapLease"), "Refuse legacy lease")
assert(not workspace:FindFirstChild("QAReleaseStaging"), "Refuse legacy staging")
assert(not game.ServerStorage:FindFirstChild("QAIsolatedTutorial"), "Already installed; reopen a fresh disposable copy to reinstall")
local names = {${roots.map(name => JSON.stringify(name)).join(",")}}
local before, allowed, observed = {}, {}, {}
for _, name in names do allowed[name] = true end
for _, child in workspace:GetChildren() do
	local debugDraw = child.Name == "DebugDraw" and child:IsA("WireframeHandleAdornment")
	assert(allowed[child.Name] or child:IsA("Camera") or child:IsA("Terrain") or debugDraw, "Unexpected original local scenery: " .. child.Name)
	if allowed[child.Name] then
		assert(not observed[child.Name], "Duplicate local scenery root: " .. child.Name)
		observed[child.Name] = true
	end
end
for _, name in names do
	local instance = assert(workspace:FindFirstChild(name), "Incomplete original local map: " .. name)
	assert((instance:IsA("Model") or instance:IsA("Folder")) and #instance:GetDescendants() > 0, "Invalid local root: " .. name)
	before[name] = #instance:GetDescendants()
end
local prison = workspace.Prison
assert(prison:FindFirstChild("MineAnchor_prison", true), "Real main mine anchor missing")
assert(prison:FindFirstChildWhichIsA("SpawnLocation", true), "Real Prison spawn missing")
local sync = assert(loadstring(${quote(sync)}))
local install = assert(loadstring(${quote(installer)}))
local adapterSource = ${quote(adapter)}
assert(loadstring(adapterSource), "Storage adapter does not compile")
local metadata = game.HttpService:JSONDecode(${quote(JSON.stringify(metadata))})
local marker = Instance.new("StringValue")
marker.Name, marker.Value = "QAIsolatedTutorial", game.HttpService:JSONEncode(metadata)
marker:SetAttribute("Mode", "DISPOSABLE_LOCAL_TUTORIAL")
marker:SetAttribute("BackupSHA256", "${expectedHash}")
marker:SetAttribute("SourceSHA256", "${metadata.sourceSHA256}")
marker:SetAttribute("State", "INSTALLING")
marker.Parent = game.ServerStorage
local synced = sync()
assert(synced == "synced " .. metadata.sourceScripts .. " scripts", "Incomplete source sync")
local store = Instance.new("ModuleScript")
store.Name, store.Source, store.Parent = "QAIsolatedTutorialStore", adapterSource, game.ServerStorage
-- Only the storage dependency changes in this local copy; profile/gameplay code is otherwise exact src/.
for _, name in { "ProfileService", "PlayerTransferService" } do
	local module = game.ServerScriptService.Server.Services[name]
	local needle = 'local DataStoreService = game:GetService("DataStoreService")'
	local start, finish = module.Source:find(needle, 1, true)
	assert(start and not module.Source:find(needle, finish + 1, true), "Unexpected storage boundary: " .. name)
	module.Source = module.Source:sub(1, start - 1)
		.. 'local DataStoreService = require(game.ServerStorage.QAIsolatedTutorialStore)'
		.. module.Source:sub(finish + 1)
end
install()
-- Destruction is permitted only in this guarded disposable DataModel, never in the native backup file.
local removed = 0
for _, name in names do
	if name ~= "Prison" then
		workspace[name]:Destroy()
		removed += 1
		task.wait()
	end
end
local debugDraw = workspace:FindFirstChild("DebugDraw")
local removedDebugDraw = debugDraw and debugDraw:IsA("WireframeHandleAdornment") or false
if removedDebugDraw then debugDraw:Destroy() end
assert(#prison:GetDescendants() == before.Prison, "Prison geometry changed")
metadata.originalRootDescendants, metadata.removedRoots = before, removed
metadata.removedDebugDraw = removedDebugDraw
metadata.retainedPrisonDescendants = before.Prison
marker.Value = game.HttpService:JSONEncode(metadata)
marker:SetAttribute("PrisonDescendants", before.Prison)
marker:SetAttribute("State", "READY")
return { status = "READY", localDocument = game.Name, sourceScripts = metadata.sourceScripts,
	removedRoots = removed, prisonDescendants = before.Prison, storageMode = "SESSION_MEMORY",
	cloudPersistenceTested = false, backupFileChanged = false }
`;
if (harnessOnly) output = `--!nocheck
-- Refresh ONLY the temporary tutorial server harness in the already prepared local copy.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(game.PlaceId == 0 and game.GameId == 0, "Refuse a linked/cloud DataModel")
assert(game.Name == "${expectedName}", "Wrong local QA document")
assert(#game.Players:GetPlayers() == 0, "Refuse an occupied DataModel")
assert(not game.ServerStorage:FindFirstChild("QAReleaseMapLease"), "Refuse legacy lease")
local marker = assert(game.ServerStorage:FindFirstChild("QAIsolatedTutorial"), "Install local QA first")
assert(marker:GetAttribute("Mode") == "DISPOSABLE_LOCAL_TUTORIAL" and marker:GetAttribute("State") == "READY", "Local QA installation incomplete")
assert(marker:GetAttribute("BackupSHA256") == "${expectedHash}", "Unexpected local backup")
assert(marker:GetAttribute("SourceSHA256") == "${metadata.sourceSHA256}", "Gameplay source changed; full fresh local install required")
local prison = assert(workspace:FindFirstChild("Prison"), "Real Prison missing")
local count = #prison:GetDescendants()
assert(count == marker:GetAttribute("PrisonDescendants"), "Retained Prison changed")
local server = assert(game.ServerScriptService:FindFirstChild("QAReleaseTutorialServer"), "Tutorial server missing")
assert(server:IsA("Script"), "Unexpected tutorial server class")
local source = ${quote(localServer)}
assert(loadstring(source), "Updated tutorial server does not compile")
server.Source = source
local metadata = game.HttpService:JSONDecode(marker.Value)
metadata.tutorialSourceSHA256 = "${metadata.tutorialSourceSHA256}"
metadata.tutorialServerSHA256 = "${digest(localServer)}"
marker.Value = game.HttpService:JSONEncode(metadata)
marker:SetAttribute("TutorialServerSHA256", "${digest(localServer)}")
assert(#prison:GetDescendants() == count, "Prison changed during harness refresh")
return { status = "HARNESS_REFRESHED", scriptsChanged = 1, mapPruned = false,
	gameplaySourceChanged = false, clientHarnessChanged = false, storageMode = "SESSION_MEMORY",
	tutorialServerSHA256 = "${digest(localServer)}", cloudPersistenceTested = false }
`;
const outputIndex = process.argv.indexOf("--output");
if (outputIndex >= 0) {
  if (!process.argv[outputIndex + 1]) throw new Error("--output requires a .luau destination");
  const target = resolve(root, process.argv[outputIndex + 1]);
  const outputRoot = resolve(root, "place/qa-2026-11-03");
  const rel = relative(outputRoot, target);
  if (!rel || isAbsolute(rel) || rel.startsWith(`..${sep}`) || rel === ".." || resolve(outputRoot, rel) !== target || !target.endsWith(".luau")) {
    throw new Error("Output must be a .luau file under place/qa-2026-11-03; never overwrite backup/place files");
  }
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, output, "utf8");
  console.log(JSON.stringify({ ...metadata, harnessOnly, output: target, installerSHA256: digest(output), bytes: Buffer.byteLength(output) }));
} else {
  process.stdout.write(output);
}
