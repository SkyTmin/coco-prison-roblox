// Emits an Edit-only installer/cleanup. No Studio connection and no production module clones.
// node scripts/make-release-tutorial-qa.mjs [--cleanup] > <temporary-file.luau>
// Retain real Workspace.Prison, its NPCs and main MineAnchor; never install a replacement test mine.
// ExecuteMultiplayerTestAsync(1, "release-tutorial-v1"); startup60s, overall1200s, no money/counter grants.
import { readFileSync } from "node:fs";
const quote = (source) => {
  let eq = "====";
  while (source.includes(`]${eq}]`)) eq += "=";
  return `[${eq}[${source}]${eq}]`;
};
const entries = [
  ["game.ServerScriptService", "QAReleaseTutorialServer", "Script", "server"],
  ["game.StarterPlayer.StarterPlayerScripts", "QAReleaseTutorialClient", "LocalScript", "client"],
];
console.log('assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit-mode only")');
for (const [parent, name] of entries) {
  console.log(`do local old=${parent}:FindFirstChild("${name}"); if old then old:Destroy() end end`);
}
if (!process.argv.includes("--cleanup")) {
  console.log('assert(workspace:FindFirstChild("Prison"), "Retain the actual Prison geometry before this test")');
  for (const [parent, name, kind, suffix] of entries) {
    const source = readFileSync(new URL(`./qa-release-tutorial-${suffix}.luau`, import.meta.url), "utf8");
    console.log(`do local v=Instance.new("${kind}"); v.Name="${name}"; v.Source=${quote(source)}; v.Parent=${parent} end`);
  }
}
console.log(`print("release-tutorial-v1 ${process.argv.includes("--cleanup") ? "removed" : "installed; one scoped fresh negative actor only"}")`);
