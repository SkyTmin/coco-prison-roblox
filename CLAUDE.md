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
- `src/server/Services/` — Profile (DataStore `PlayerProfiles_v3`), Inventory, Mine, Dig, Economy, Profession, Needs, Hunger, Death (PvP drops), Achievement, Case (cases + ender chest), Location (teleport channel + spots), Combat (lock), Texture.
- `src/client/init.client.luau` — HUD, windows, dig input (mouse/touch/first person), mobile layout; modules `Ui`, `ChestWindow` + `DragDrop` (cases, ender chest, inventory), `HeldItem` (attribute `HeldItem`), `ArmorVisual` (attribute `Armor`).
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
- Roblox Studio MCP (`Roblox_Studio`): `list_roblox_studios` first; `execute_luau` builds/inspects; keep code in `src/`, never paste logic into the place.

## Studio loop without the Rojo plugin (agent sessions)

1. `rojo build -o place/coco-prison.rbxl` and open it in Studio (or keep the open one).
2. After editing code: `node scripts/make-studio-sync.mjs [init.client,Strings,...] > sync-part.luau`
   (the comma list limits it to changed files). Keep `node scripts/serve-repo.mjs` running (serves the
   repo on 127.0.0.1:8766), then run `scripts/studio-loader.luau` via `execute_luau` (Edit) with FILE =
   the file to run — Studio fetches and runs it itself (HttpService in `task.spawn`; a GetAsync on the
   execute_luau thread hangs). Read `ServerStorage.SyncResult` ~2 s later. The loader also runs any
   build script, so no script text ever goes through the MCP call.
3. Map, in this order (all idempotent, Edit mode, via the loader): `scripts/build-textures.luau`
   (MaterialVariants px_*), `scripts/build-prison.luau` (ground, walls, paths, plaza, pits),
   `scripts/build-buildings.luau` (Рынок/Столовая/Спальня/Баня/Задания/Тренер with interiors and the
   Restore* tags), `scripts/build-npcs.luau` (R15 NPC rigs tagged on HumanoidRootPart, chest model for
   OrdinaryCase), `scripts/decorate-prison.luau` (outdoor props). Keep-out rectangles for the random
   props live at the top of decorate-prison; update them when a building footprint changes.
   `scripts/build-showcase.luau` builds the owner's showcase north of the wall (mannequins with every
   armor set and tool, icon wall); mannequins render through the `ArmorMannequin` / `HeldMannequin` tags.
   Asset pipeline: `scripts/prepare-voxelibre.ps1` (icons ×8 nearest-neighbour, armor faces from the
   Minecraft layer layout) → upload via `upload_image` → ids in `assets/icons/ids.json`,
   `assets/armor/ids.json` → `node scripts/build-configs.mjs`; `scripts/tools-to-voxels.ps1` + node
   greedy-rectangle merge → `assets/icons/voxels.json` (3D extruded item sprites, `ItemModels.luau`).
   Sounds: ALL from one VoxeLibre atlas [владелец 21.10]: `scripts/build-sounds.mjs` → `assets/sounds/build/atlas.ogg`
   + segments in `assets/sounds/ids.json` (`files[name]`, `materials[type].hit/break/step`, `blockMaterial`); the OWNER
   uploads it once (`scripts/upload-audio.mjs`, Open Cloud key; unverified accounts get 10 audio uploads a month) →
   `atlasId` → `build-configs`. Play with `src/shared/Sfx.luau` (server: `Sfx.broadcast` / `Sfx.toPlayer` → client plays
   the segment); footsteps `src/client/Footsteps.luau`; attribution `assets/thirdparty/voxelibre/ATTRIBUTION.md`.
   Block breaking (`src/client/BlockBreak.luau`): crack stages `assets/cracks/ids.json`; sounds like
   Minecraft (hit = step sound every 0.2 s at pitch 0.5, break = dig sound at 0.8; a 2-voice pool per
   material, no piling up): `scripts/build-sounds.mjs` concatenates the VoxeLibre mcl_sounds variants
   into `assets/sounds/build/*.ogg` + `manifest.json`; the OWNER uploads them with
   `scripts/upload-audio.mjs` (Open Cloud API key) → ids in `assets/sounds/ids.json` → `build-configs`.
   Until then `files[*].fallback` (trimmed Roblox-library clips) plays. Own pixel icons (keys, trainer
   badges, touch menu) come from `scripts/draw-icons.mjs` → `upload_image`. Artifact pictures:
   `assets/artifacts/artifact-*.png` → `upload_image` (serve PNGs over a local http server; serve-repo
   only serves .luau/.json) → `assets/artifacts/ids.json` (picture name → id) → `build-configs`.
   Windows: `fitWindow` keeps every window below Roblox's top bar (`GuiService:GetGuiInset()`).
   Status effects: `src/shared/Effects.luau` lists them; the server sets character attributes
   `<Effect>` = level and `<Effect>Until` = server time (nil = until the need is restored) plus the
   `EffectParticles` emitter; `src/client/EffectsHud.luau` draws the icons and the camera effects.
   Item info (Minecraft tooltip): `src/shared/ItemInfo.luau` derives every line from the configs
   (tools/armor vanilla stats, enchants, ancient books via `books.catalog`, blocks, food, keys, needs
   consumables); `src/client/ItemTooltip.luau` draws it, `DragDrop` shows it (mouse hover; touch: tap-
   selected or long-pressed slot). A new item needs `item_<id>` (+ optional `desc_<id>`) in Strings in
   all 4 locales; a new book needs `books.catalog` + `effects` + `book_<id>` / `book_desc_<id>`. The
   server warns `[ItemInfo] missing translations` in Studio when something is missing.
   Creative test mode: `CreativeService` (player attributes `CreativeAllowed` / `Creative`; Studio, place creator,
   `creative.admins`) + `src/client/CreativeWindow.luau` (menu button, key K); Dig/Hunger/Needs read `Creative`.
   Avatars are rigged with AnimationConstraints (no Motor6D C0): pose joints via `Transform` in PreSimulation.
   Phone layout in Studio: the emulator may report a keyboard — set workspace attribute
   `ForceMobile = true` (Studio-only) to force it; remove it afterwards.
   Digging is server-authoritative (`DigService`): DigStart(part, hitPoint) starts a server timer,
   DigAccepted(needed) syncs the client bar, the client hides the block when its bar ends and the server
   removes it right after; DigCancel on release; reach = 4.5 blocks eye → hit point, LoS to the hit
   point. Mines keep four 4-wide ladder shafts free forever (`MineService.ladderShaft`).
   Map fixes applied in place after a build: `scripts/fix-map-ladders-zfight.luau`.
   Cases: `CaseService` refuses to open without the matching key (toast names the key), prompts work
   from any side (no line of sight), nickname case grants names from `keys.nicknameCase.nicknames`. Per-mine
   composition: `scripts/design-decisions.json` → `mines.<locationId>_<mineId>.shares` →
   `locations.json` → `mines` → MineService.
4. Test: `start_stop_play`, then `execute_luau` on the Server/Client datamodels (fire remotes from the
   Client, read ProfileUpdated), `get_console_output`, `screen_capture` (only renders when the Studio
   window is not minimized — restore it via PowerShell ShowWindow if the capture is blank).
5. `require()` inside `execute_luau` gets a separate module instance. QA hooks (Studio only):
   `ServerStorage.ProfileDebug` BindableFunction (Wire-encoded tables: `Wire.decode` what `get` returns,
   `Wire.encode` what you `set`; `get` userId → profile copy, `give` userId id count
   level, `coins` userId delta, `set` userId field value) and `PlayerGui.ClientDebug` on the client
   (`toggleCamera`, `open` kind, `close`, `aim`, `holdDig` bool, `state`). Prompts can be triggered
   from the client with `prompt:InputHoldBegin()/InputHoldEnd()`. Injected keyboard input does NOT
   reach our hotkeys; `screen_capture` and window layout break while the Studio viewport is 1×1
   (window minimized/hidden) — check `camera.ViewportSize` first.
   The published place (placeId 92594200898716) needs "Enable Studio Access to API Services" in Game
   Settings → Security before DataStore works in Studio (ProfileService then loads real profiles).
6. If `list_roblox_studios` returns `[]`, restart Studio with the place file and wait ~1 min. Never
   start a second `mcp.bat` (probe scripts etc.): only one proxy holds the Studio connection, and the
   second one steals it. Studio follows the Windows system proxy (Happ VPN, 127.0.0.1:10809); when
   `ecsv2.roblox.com` / `apis.roblox.com` fail through it, Studio quits ~75 s after launch — see
   `docs/SETUP.md` §2, do not change the proxy yourself, wait for the VPN or ask the owner.

## Tooling

See `docs/SETUP.md`. Rokit: rojo 7.7.1, wally, selene, stylua. MCP servers registered at user scope: `Roblox_Studio` (Studio's built-in server) and `codex` (aikazu/claude-codex-mcp).
