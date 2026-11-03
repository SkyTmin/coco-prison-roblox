// Emit only; never controls Studio. Retain actual Prison+Quarry using the existing map lease.
// node scripts/make-release-safety-qa.mjs [--cleanup] > <temporary installer.luau>
// ExecuteMultiplayerTestAsync(1,"release-safety-v1"); 120s overall deadline.
import { readFileSync } from "node:fs";
const entries = [
  ["game.ServerScriptService", "QAReleaseSafetyServer", "Script", "scripts/qa-release-safety-server.luau"],
  ["game.StarterPlayer.StarterPlayerScripts", "QAReleaseSafetyClient", "LocalScript", "scripts/qa-release-safety-client.luau"],
];
const quote = (source) => {
  let eq = "====";
  while (source.includes(`]${eq}]`)) eq += "=";
  return `[${eq}[${source}]${eq}]`;
};
console.log('assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")');
for (const [parent, name, kind, path] of entries) {
  console.log(`do local old=${parent}:FindFirstChild("${name}"); if old then old:Destroy() end end`);
  if (!process.argv.includes("--cleanup")) {
    const source = readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
    console.log(`do local v=Instance.new("${kind}"); v.Name="${name}"; v.Source=${quote(source)}; v.Parent=${parent} end`);
  }
}
console.log(`print("release-safety-v1 ${process.argv.includes("--cleanup") ? "removed" : "installed; retain Prison+Quarry; 1 negative actor; physicalInput=false"}")`);
