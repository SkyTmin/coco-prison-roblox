// Emit an Edit-only installer/cleanup; never starts Studio or touches production profiles.
// node scripts/make-release-actions-qa.mjs [--cleanup] > <temporary-file.luau>
// StudioTestService:ExecuteMultiplayerTestAsync(2, "release-actions-v1").
import { readFileSync } from "node:fs";
const entries = [
  ["game.ServerScriptService", "QAReleaseActionsServer", "Script", "server"],
  ["game.StarterPlayer.StarterPlayerScripts", "QAReleaseActionsClient", "LocalScript", "client"],
];
const quote = (source) => {
  let eq = "====";
  while (source.includes(`]${eq}]`)) eq += "=";
  return `[${eq}[${source}]${eq}]`;
};
console.log('assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit-mode only")');
for (const [parent, name] of entries) {
  console.log(`do local old=${parent}:FindFirstChild("${name}"); if old then old:Destroy() end end`);
}
if (!process.argv.includes("--cleanup")) {
  for (const [parent, name, kind, suffix] of entries) {
    const source = readFileSync(new URL(`./qa-release-actions-${suffix}.luau`, import.meta.url), "utf8");
    console.log(`do local v=Instance.new("${kind}"); v.Name="${name}"; v.Source=${quote(source)}; v.Parent=${parent} end`);
  }
}
console.log(`print("release-actions-v1 ${process.argv.includes("--cleanup") ? "removed" : "installed; two scoped negative actors only"}")`);
