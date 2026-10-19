# CLAUDE.md — coco-prison-roblox

Agent-facing notes for this repository (`SkyTmin/coco-prison-roblox`). Git conventions follow
the owner's other repos: short Russian commit messages (`feat(work): …`, `docs: …`), agent-facing
docs in English, player-facing text and user replies in Russian.

## What this is

A Roblox prison RPG (Luau, Rojo project) inspired by Prison Classic on the Cristalix
Minecraft server. Design source of truth: `wiki/PROTOTYPE-SPEC.md` (chapter 1, v0.2) and
`wiki/MECHANICS-CATALOG.md` (64 target mechanics). `wiki/` is the research corpus
(recovered game data, audits, evidence screenshots) — read it, don't rewrite history in it.

## Layout

- `default.project.json` — Rojo tree. Workspace is NOT synced: the map lives in the place
  file, built by `scripts/build-yard.luau` (re-runnable, replaces `Workspace.Yard`).
- `src/shared/Config/rpg-systems.json` — balance; mirror of `wiki/rpg-systems-config.json`.
  Change both together. Rojo exposes it as `ReplicatedStorage.Shared.Config["rpg-systems"]`.
- `src/shared/` — `Config.luau` (typed accessors), `Strings.luau` (t(key, locale, …), four
  locales ru/en/es/fr, ru default), `Remotes.luau`, `Types.luau` (Profile v2).
- `src/server/Services/` — `ProfileService` (in-memory profiles, DataStore
  `PlayerProfiles_v2`, key `User_{UserId}`), `WorkService` (harvest validation),
  `EconomyService` (sell, level-up).
- `src/client/init.client.luau` — one "Harvest" action (mouse / touch button / gamepad),
  target highlight, HUD.
- World markup via CollectionService tags + attributes: `WorkNode` parts carry
  `Resource`, `Generation`, `Depleted`; `SellPoint` parts get a ProximityPrompt.

## Rules that must hold

1. The server owns every outcome. Clients send intents (`Harvest(node, generation)`,
   `LevelUp()`), never amounts, balances or results. Validate type, tag, generation,
   distance, tool, level and rate limit before mutating (see `WorkService.onHarvest`).
2. Profile mutations only through `ProfileService.Mutate`. A failed load sets
   `loadFailed` and the session is never saved — keep it that way.
3. Every player-facing string goes into `Strings.luau` in all four locales in the same change.
4. Money is stored as integer hundredths (`Config.moneyScale`). Display via `Strings.money`.
5. `--!strict` in every module. Run `selene src` and `stylua --check src` before committing.
6. Follow the implementation order in `wiki/PROTOTYPE-SPEC.md` §15; don't declare the
   chapter done without the end-to-end test in §16.

## Open TODOs (before any public test)

- Session locking, per-key save queue, bounded retries with jitter (`ProfileService`).
- Needs (hygiene/rest/bladder), consumables and quests (step 2).
- Sword, armor, rat, zombie, combat rewards (step 3). Factions, cell, boss (step 4).
- Key items, chest, effect book, operationId idempotency (step 5).

## Tooling

See `docs/SETUP.md`. Rokit manages `rojo`, `wally`, `selene`, `stylua` (`rokit install`).
Studio's built-in MCP server (Assistant → Manage MCP Servers → Enable Studio as MCP server,
Quick connect → Claude Code) lets an agent run Luau in the open place, play-test, read the
console and take screenshots. Use it to build/inspect the map; keep code in `src/` via Rojo.

## Git

Branch `main`, local checkout `C:\Users\user\Documents\coco-prison-roblox`. Commit and push
finished steps directly; there is no deploy pipeline — the place is published from Studio.
Place files (`*.rbxl`) are git-ignored: the map is rebuilt by `scripts/build-yard.luau`.
