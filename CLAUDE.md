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
   badges, touch menu) come from `scripts/draw-icons.mjs` → `upload_image`. Armor icons: `scripts/armor-icons.mjs`
   (own sprites, also the held 3D item via `assets/icons/voxels.json`); tool icons and 3D models: Blender
   `assets/models/<tool>.py -- icons <dir>` / `-- export` (voxeltool.py) → `assets/icons/tools`, `itemmodels.json`. Artifact pictures:
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
   Spawn tops: `scripts/build-tops.luau` (Edit, after decorate-prison; 4 portals tagged TopBoard) + `LeaderboardService` (OrderedDataStores) + `src/client/TopBoards.luau`.
   Каменоломня: `scripts/build-quarry.luau` (Edit, after build-textures; Workspace.Quarry at X = 700, all in one cave).
   Подвал: `scripts/build-basement.luau` (Edit, after build-textures; Workspace.Basement at X = 1500, linear cellar: spawn → rats → mine `basement` + zombies → rats → mine `basement_ore` → lair of Сплинтер). Zombie mob model: assets/models/zombie; Сплинтер = rat ×3 via `scripts/model-tools/scale-model.cjs`.
   Location previews [владелец 22.10]: always an ELEVATED THREE-QUARTER photo of the built location, as if standing in the air, taken IN PLAY MODE (game lighting, real mine blocks): server anchors the character over the location and RequestStreamAroundAsync over it; client turns the ScreenGuis/CoreGui off, hides roofs locally (quarry cave), holds a Scriptable camera with BindToRenderStep; screen_capture; frame close so the location fills the shot; crop with no sky/Roblox buttons by `scripts/crop-preview.cjs` → assets/previews/topdown-<id>.png → upload_image → assets/previews/ids.json. (`scripts/preview-shot.luau` is the Edit-mode fallback.)
   New locations keep their X but each floats at its own height BY so none sees another [владелец 23.10] (X, Y): Подножье горы `scripts/build-mountain-foot.luau` (2400, 1500), Пирамида `build-pyramid` (4400, 4500), Королевский сад `build-royal-garden` (5400, 6000), Затопленный маяк `build-sunken-lighthouse` (6400, 7500; Terrain water at BY, the script clears its region); the scripts build at y 0 and lift the folder by BY at the end; invisible edge walls everywhere (no falling into the void). Пустотная крепость `build-end-castle` (7400, 9000; VoidCatch net under the islands → LavaService puts a faller back on the arrival; night via IndoorLighting ClockTime, which also turns the place ColorGradingEffect off — it whitens a night scene). Паучье логово `build-spider-lair` (8400, 10500; a 3D voxel cave — domes, overhangs, chimneys with moonlight — only the shell next to the air is built). Cobwebs are Minecraft cross sprites (`src/shared/Cobweb.luau`, Config.textures.sprites.cobweb): a mine cobweb block has no collision and holds the sprite, parts tagged `Cobweb` slow the player ×0.25 / sink slowly / no jumping (`src/client/CobwebStuck.luau`) and cancel fall damage; MineService.rescue ignores cobweb cells. Cosmetic motion: tags AmbientSpin / AmbientDangle / AmbientCrawl / AmbientSway / AmbientPulse on Atomic models → `src/client/AmbientMotion.luau`. Снежная длань `build-snowy-hand` (9400, 12000; an island shaped like a hand in a frozen sea, polar night + aurora, Terrain water only in the polynyas; ice mine blocks use Roblox Ice / Glacier via MineService.MATERIALS). Next location: X 10400, Y 13500. Преисподняя: `scripts/build-underworld.luau` (Edit, after build-textures; Workspace.Underworld at X 3400, Y 3000: closed Nether cavern, lava tagged `Lava` → `LavaService` burns [ваниль 4 / 0,5 с], red murk via IndoorLighting attributes Haze / AtmosphereColor / AtmosphereDecay; Nether textures from `scripts/derive-block-textures.mjs`). Bridges span the gap measured from the grid (gapEdges) — keep that for every new bridge.
   База фракций: `scripts/build-fraction-base.luau` (Edit, after build-textures and build-prison; Workspace.FactionBase at X = −1050: 4 valleys in mountains, trails to the Зомбарь square). Boss template: `scripts/build-boss-zombie.luau` (ServerStorage.BossTemplates.giant_zombie). New block textures: `scripts/split-faction-sheet.mjs`.
   Player body: `assets/models/player/player.py` (Blender: renders / `-- export` → src/shared/Models/player.json / `-- check` renders the JSON the way the game builds it) → `AvatarService` (StarterCharacter with R15 names and Motor6Ds, look by userId, detail plates merged per face, faction armband; character attribute `BlockBody` → rigid limbs in CharacterAnimator). The Roblox avatar is not loaded. Its armor: `assets/models/armor/armor.py` (our own Minecraft-style pixel faces drawn as shade maps, 4 materials → assets/armor/block/*.png + renders on the body) → upload → assets/armor/block/ids.json → build-configs → Config.armor.block → `ArmorVisual.BLOCK_BOXES` (Decal boxes round whole limbs, 1 px larger; VoxeLibre faces until ours are uploaded). The face basis of the body plates lives in `src/shared/BlockFaces.luau`. The rig and the plates: `src/server/Services/BlockBody.luau`. NPCs: `assets/models/npc/npc.py` (costumes on the same body → src/shared/Models/npcs.json) → `NpcBodyService` rebuilds the map's R15 NPCs at server start by model name (attribute `Costume` overrides); the HumanoidRootPart with its tags stays.
   Blender mobs and bosses: skill .claude/skills/blender-block-mob (read it first). assets/models/blockmob.py is the shared pipeline (Blender 5.2 headless: `-- build` / `-- export` → src/shared/Models/<id>.json + noise.png + previews / `-- compare` → the reference views at the same scale, scripts/model-tools/cmp.cjs); assets/models/<id>/<id>.py holds only the data. src/shared/BlockRig.luau builds the Motor6D rig (MobService rats, BossService.buildBlock when bosses.<id>.fight.model is set); src/client/MobAnimator.luau / BossAnimator.animateBlock play the clips.
   Boss looks: ServerStorage.BossTemplates.<template> (mesh golem split into Head/Torso/LeftArm/RightArm/LeftLeg/
   RightLeg; lives only in the place file) is rigged in code; `src/client/BossAnimator.luau` poses it from the
   Action attributes. Player swing = our keyframes (`src/shared/SwingAnimations.luau`) played by
   `src/client/CharacterAnimator.luau` on top of Roblox animations, relayed Swing → SwingFx; hold pose = our own
   (SwingAnimations.hold). Melee: `src/shared/Combat.luau` (weapon sets in design-decisions combat.weapons; arc hits
   to the target's bounding box after the upswing; client and server compute the same combo).
   Better Combat animations are All Rights Reserved — never copy them without a verifiable permission link.
   Bosses: `BossService` (BossSpawn part + BossId; fight numbers in design-decisions bosses.<id>.fight) and
   `src/client/BossHud.luau` (top bar, respawn board) via ReplicatedStorage.Bosses; QA `BossDebug`.
   StreamingEnabled is on (`scripts/setup-streaming.luau`, Edit): never assume a far part exists on the client;
   move players only after `RequestStreamAroundAsync`; small models that must arrive whole are Atomic.
   Mine resets are time-sliced (4 ms a frame), skip untouched mines; QA `MineDebug` ("reset" | "state", mineId).
   Ground items: `ItemDropService` (thrown items via DropItem, death loot, ClearLag sweep every 5 min, cap 400);
   the profile reaches the client once whole (ProfileUpdated), then as deltas (ProfilePatch) at most 10×/s — never
   send it per action. Cosmetic broadcasts go to nearby players only, batched, via `Remotes.unreliable`.
   Cases are temporary: contents vanish when the case closes (`CaseService.emptyCase`); the ender chest keeps them.
   Server warnings/errors reach CreativeAllowed players (`ServerLog` → creative window) — the owner has no chat.
   Creative test mode: `CreativeService` (player attributes `CreativeAllowed` / `Creative`; Studio, place creator,
   `creative.admins`) + `src/client/CreativeWindow.luau` (menu button, key K); Dig/Hunger/Needs read `Creative`.
   Roblox avatars (NPC rigs) use AnimationConstraints, our player body Motor6Ds: pose joints via `Transform` in PreSimulation.
   Phone layout in Studio: the emulator may report a keyboard — set workspace attribute
   `ForceMobile = true` (Studio-only) to force it; remove it afterwards.
   Digging is server-authoritative (`DigService`): DigStart(part, hitPoint) starts a server timer,
   DigAccepted(needed) syncs the client bar, the client hides the block when its bar ends and the server
   removes it right after; DigCancel on release; reach = 4.5 blocks eye → hit point, LoS to the hit
   point. Mines keep four 4-wide ladder shafts free forever (`MineService.ladderShaft`).
   Map fixes applied in place after a build: `scripts/fix-map-ladders-zfight.luau`.
   Runtime map fix: `SignService` cuts sign posts that run through a text board down to its bottom edge at every server start.
   Achievements: «Копатель (<блок>)» cards built by build-configs (`achievements.cards`), logic in `src/shared/Achievements.luau`; boosters: `src/shared/Boosters.luau` (storage + time queue, scopes local / faction / global) → `BoosterService` (shared ones: outbox `p.pendingBoosters` → `GlobalBoosterService`, MemoryStore `SharedBoosters_v1` mirrored to ReplicatedStorage.SharedBoosters), `BoosterWindow` [B], `BoosterHud`; bottle models `assets/models/booster/booster.py` (`-- icons <dir>` / `-- export` → models3d.json → build-configs writes itemmodels.json compact).
   Item / menu icons [владелец 27.10]: Codex sheets in the tool-icon style on #FF00FF (`assets/icons/codex/*.png`) → `node scripts/split-codex-sheet.mjs <sheet> <cols> <rows> <ids>` → `node scripts/sprite-grids.mjs <ids> --dir assets/icons/codex/cells --cell <px> --write` (clean sprites in assets/icons/items + `assets/models/items/grids.json`) → Blender `assets/models/items/items.py -- icons <dir> [ids]` (straight-on voxel render, no tilt) → `assets/icons/items3d` → upload → ids.json; `-- export [ids]` writes the held models. Bow and arrow come from `assets/models/bow/bow.py`. Do not re-run draw-icons.mjs over these ids. Owner rule [27.10]: every new item, menu tab or similar picture ALWAYS goes through this Blender pipeline (icon and held model from one voxel model).
   HUD editor: optional elements (`HudLayout.setOptional`, the attack button, off by default); the jump button follows the `Touch_jump` stand-in.
   Auction [Y]: `src/shared/Auction.luau`, `AuctionService` (DataStore `AuctionLots_v1` = truth, MemoryStore `AuctionIndex_v1` = browse index, outbox in `p.auction`; QA `ServerStorage.AuctionDebug`), `AuctionWindow`; design + anti-dupe checklist `docs/research/auction-design.md`. Any step that changes something outside the profile: note it in the profile, `ProfileService.SaveNow`, outside write, finish; settle notes in `ProfileService.OnLoaded`. Profiles hold a session lock (`_lock`). Main menu [X]: `MenuWindow`. Tinted blocks (`BlockColors.TINTED`, `BlockColors.icon`) render the same in the mine and in slots.
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
   level, `coins` userId delta, `set` userId field value) and `Player.ClientDebug` on the client
   (`toggleCamera`, `open` kind, `close`, `aim`, `holdDig` bool, `bow` true|false — draw|shoot, `state`). Prompts can be triggered
   from the client with `prompt:InputHoldBegin()/InputHoldEnd()`. Injected keyboard input does NOT
   reach our hotkeys; `screen_capture` and window layout break while the Studio viewport is 1×1
   (window minimized/hidden) — check `camera.ViewportSize` first.
   The published place (placeId 92594200898716) needs "Enable Studio Access to API Services" (File → Experience
   Settings → Security → Save) before DataStore works in Studio (ProfileService then loads real profiles).
6. If `list_roblox_studios` returns `[]`, restart Studio with the place file and wait ~1 min. Never
   start a second `mcp.bat` (probe scripts etc.): only one proxy holds the Studio connection, and the
   second one steals it. Studio follows the Windows system proxy (Happ VPN, 127.0.0.1:10809); when
   `ecsv2.roblox.com` / `apis.roblox.com` fail through it, Studio quits ~75 s after launch — see
   `docs/SETUP.md` §2, do not change the proxy yourself, wait for the VPN or ask the owner.

## Tooling

See `docs/SETUP.md`. Rokit: rojo 7.7.1, wally, selene, stylua. MCP servers registered at user scope: `Roblox_Studio` (Studio's built-in server) and `codex` (aikazu/claude-codex-mcp).
