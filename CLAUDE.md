# CLAUDE.md — coco-prison-roblox

Roblox prison RPG (Luau + Rojo) recreating Cristalix **Prison Classic**. Owner: SkyTmin. Agents (Claude Code, Codex) do the work; this repo is the single source of truth. Replies to the owner in Russian; agent-facing docs in English; commit messages short, in Russian (`feat(mine): …`, `wiki: …`, `docs: …`).

## Start of a session — read in this order, nothing more

1. `docs/PROGRESS.md` — state, open questions, next step (≈ 1 screen).
2. The section of `docs/GAME-DESIGN.md` for the system you touch (search by heading, do not read whole).
3. `docs/INDEX.md` only when you need a specific research fact — it maps every wiki file in one line.

Do not read `wiki/` wholesale (≈ 60 MB, 500 files). Grep, then read the matching section.

## Layout

- `src/shared/Config/*.json` — **generated**. Edit `scripts/design-decisions.json` (our choices) or the wiki JSON (confirmed data), then `node scripts/build-configs.mjs`. Never hand-edit the output.
- `src/shared/` — `Config.luau` (typed access), `Strings.luau` (ru/en/es/fr, ru default), `Remotes.luau`, `Types.luau`.
- `src/server/Services/` — `ProfileService` (DataStore `PlayerProfiles_v2`, key `User_{UserId}`), `WorkService` (dig validation), `EconomyService` (sell, level-up).
- `src/client/init.client.luau` — one "Harvest" action (mouse / touch / gamepad), highlight, HUD.
- World markup: CollectionService tags + attributes (`WorkNode`: `Resource`, `Generation`, `Depleted`; `SellPoint`).
- `scripts/simulate-economy.mjs [maxLevel]` — minutes-to-level from configs; run after any balance change.
- `wiki/in-game-wiki/` — confirmed in-game data (md + json). `wiki/client-audit/` — recovered menus, localization. `wiki/web-research/` — web findings. `docs/GAME-DESIGN.md` cites all of them with source tags.

## Rules

1. Server owns every outcome. Clients send intents (`Harvest(node, generation)`, `LevelUp()`), never amounts. Validate type, tag, generation, distance, tool tier, level, rate limit (see `WorkService.onHarvest`).
2. Profile mutations only via `ProfileService.Mutate`; a failed load sets `loadFailed` and is never saved.
3. Every number in docs carries a source tag: `[вики]` `[меню]` `[клиент]` `[сеть]` `[ваниль]` `[владелец]` `[решение]`. New owner screenshots → `wiki/in-game-wiki/*.md` + json → regenerate configs → update `GAME-DESIGN.md`. Never invent a number without `[решение]`.
4. Vanilla Minecraft formulas for dig time, sword damage, armor, enchant effects (confirmed by owner). Block textures and names must be our own.
5. Every player-facing string in `Strings.luau` in all four locales.
6. `--!strict`; `selene src` and `stylua --check src` before commit. `rojo build` must pass.
7. Follow `docs/PLAN.md` stage order; a stage is done only after the owner accepts it.
8. Commit and push after each finished piece; append a line to `docs/PROGRESS.md` at session end.

## Context economy (binding)

- Open only the files the task needs; read big files in ranges. Tail command output.
- Research questions → one subagent per topic with a precise brief and a file to write; keep the conclusion, not the transcript.
- Screenshots from the owner: crop/tile before viewing, view each once, write findings immediately.
- Codex (`codex` MCP) costs the owner's ChatGPT quota: use for image assets and second opinions only, with a written spec.
- Roblox Studio MCP (`Roblox_Studio`): `list_roblox_studios` first; `execute_luau` builds/inspects; keep code in `src/` via Rojo, never paste logic into the place.

## Tooling

See `docs/SETUP.md`. Rokit: rojo 7.7.1, wally, selene, stylua. MCP servers registered at user scope: `Roblox_Studio` (Studio's built-in server) and `codex` (aikazu/claude-codex-mcp).
