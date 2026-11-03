// Emits an Edit-mode installer/cleanup snippet; never connects to Studio itself.
// node scripts/make-release-items-qa.mjs [--cleanup] > <temporary-file.luau>
// After install: StudioTestService:ExecuteMultiplayerTestAsync(1,"release-items-v1").
// 60s startup evidence deadline / 240s overall; report.silk covers 12 real quarry/prison_small cells.
// Re-run this installer after changing either harness; offline validation:
// lune run scripts/qa-release-items-harness-offline.luau
import { readFileSync } from "node:fs";
const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const quote = (source) => {
  let eq = "====";
  while (source.includes(`]${eq}]`)) eq += "=";
  return `[${eq}[${source}]${eq}]`;
};
const locations = [
  ["game.ServerScriptService", "QAReleaseItemsServer"],
  ["game.StarterPlayer.StarterPlayerScripts", "QAReleaseItemsClient"],
  ["game.StarterPlayer.StarterPlayerScripts", "QAReleaseItemsSpring"],
  ["game.ServerScriptService.Server.Services", "QAReleaseItemsAuction"],
];
console.log('assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit-mode only")');
for (const [parent, name] of locations) {
  console.log(`do local old=${parent}:FindFirstChild("${name}"); if old then old:Destroy() end end`);
}
if (!process.argv.includes("--cleanup")) {
  const springSource = read("src/client/SpringJump.luau");
  const auctionSource = read("src/server/Services/AuctionService.luau");
  if (!/return SpringJump\s*$/.test(springSource) || !/return AuctionService\s*$/.test(auctionSource)) {
    throw new Error("Module return changed: review the disposable QA exports before installing");
  }
  const spring = springSource.replace(/return SpringJump\s*$/, `
SpringJump.qaPress = request
SpringJump.qaRelease = function() pressed = false end
SpringJump.qaBind = bind
return SpringJump
`);
  const auction = auctionSource.replace(/return AuctionService\s*$/, `
-- Disposable module: no Start(), no datastore acquisition, only its isolated memory index.
ready=true; memoryIndex={}; memoryLots={}; cacheAt=os.clock()
return {query=query, add=indexSet, remove=indexRemove}
`);
  const entries = [
    [locations[0], "Script", read("scripts/qa-release-items-server.luau")],
    [locations[1], "LocalScript", read("scripts/qa-release-items-client.luau")],
    [locations[2], "ModuleScript", spring],
    [locations[3], "ModuleScript", auction],
  ];
  for (const [[parent, name], kind, source] of entries) {
    console.log(`do local v=Instance.new("${kind}"); v.Name="${name}"; v.Source=${quote(source)}; v.Parent=${parent} end`);
  }
}
console.log(`print("release-items-v1 ${process.argv.includes("--cleanup") ? "removed" : "installed; 1 negative simulated account only"}")`);
