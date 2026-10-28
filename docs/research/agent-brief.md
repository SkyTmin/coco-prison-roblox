# Brief for implementation agents (remaining features, 28.10.2026)

You implement one stage of `docs/research/remaining-features-design.md` (the spec; facts with sources:
`docs/research/remaining-features-facts.md`). The owner is away until the evening and asked for everything to be
done in code without them; numbers not in the facts are our decisions — tag them `[решение]`.

Read first: `CLAUDE.md` (binding rules and the Studio loop), the stage's section of the design doc, and only the
code you touch (grep, read in ranges). Match the surrounding code: comment density, naming, idiom.

Rules that bite:
- Server decides everything; clients send intents. Profile changes only via `ProfileService.Mutate`; new profile
  fields go into `Types.Profile` and the defaults/load fix in `ProfileService`.
- Numbers live in `scripts/design-decisions.json` → `node scripts/build-configs.mjs` (never hand-edit
  `src/shared/Config/*.json`); add the block to build-configs output if needed.
- Every player-facing string in `src/shared/Strings.luau` in ru/en/es/fr. A literal `%` in a string with args is `%%`.
  New items need `item_<id>` (+ `desc_<id>`).
- Player-typed text (names, descriptions) must be filtered with `TextService:FilterStringAsync` +
  `GetNonChatStringForBroadcastAsync` before it is stored or shown to others.
- Cross-server data: DataStore `UpdateAsync` (atomic), MemoryStore for short-lived state, MessagingService to tell
  other servers to refresh. Batch writes (budget). Wrap every DataStore/MemoryStore/Messaging call in pcall.
- New windows: dark inventory style (`Ui.card`, `Ui.invSlot`, `SlotView`, `src/client/WindowKit.luau` like
  `SkillWindow.luau` / `PotionWindow.luau`); register in `init.client.luau` `windowBuilders` + `menuKeys` +
  `MenuWindow.ENTRIES` + a hotkey if the spec gives one; `init.client.luau` is at the 200 top-level locals limit —
  put new code in modules and `do … end` blocks, never new top-level locals.
- Remotes: `Remotes.event(name)`, document each in the header of `src/shared/Remotes.luau`.
- QA hook for Studio in `ServerStorage` (BindableFunction) for the new service.
- Maps: Edit-mode build scripts `scripts/build-<id>.luau` (idempotent, build at y 0 then lift the folder to the
  location's height, invisible edge walls, `LocationSpawn` + `LocationId` tags, StreamingEnabled-safe); copy the
  structure of an existing one (e.g. `scripts/build-fraction-base.luau`). Locations are declared in config the
  way `fraction_base` is (see facts file, last section).
- Icons (owner rule): Codex sheet (`mcp__codex__codex_image`, reference `assets/icons/codex/potions-sheet.png`,
  1536x1024, reasoning_effort low, magenta #FF00FF background, no text) → `node scripts/split-codex-sheet.mjs` →
  `node scripts/sprite-grids.mjs … --cell 21.33 --write` → Blender `assets/models/items/items.py -- icons
  <ABSOLUTE dir via cygpath -m> ids` (+ `-- export ids` for held items). Purple/pink parts near #FF00FF get keyed
  out — avoid them in the prompt. Uploading needs Studio (`mcp__Roblox_Studio__upload_image`, files served from
  the already-running http server on 127.0.0.1:8771 = `assets/icons/items3d`; never start another on 8771). If
  Studio is not connected (`list_roblox_studios` returns []), do not try to start it: add the ids to
  `assets/icons/pending-upload.txt` and make the code fall back gracefully (missing icon → existing icon or text).
- Studio: if a studio is listed, you may test (sync with `node scripts/make-studio-sync.mjs > sync-part.luau`,
  loader per CLAUDE.md, mute all Sounds on the client after each Play start, never save or publish the place,
  delete `sync-part.luau` after). If none is listed, verification is static: careful read-through, types, edge cases.
- Before finishing: `export PATH="$HOME/.rokit/bin:$PATH"; stylua src && selene src && rojo build -o "$TEMP/test.rbxl"`
  must pass. Update `docs/GAME-DESIGN.md` (a section for the system, with source tags), add a `docs/PROGRESS.md`
  entry right after `## Журнал` (Russian, what was done, what is untested), append a section to
  `docs/research/floors-evening-checklist.md` (what the owner should check in Studio tonight, step by step,
  including which build scripts to run in Edit mode). Do NOT commit — the lead agent reviews and commits.
- Never print secrets, never save/publish the place, never copy Cristalix assets (textures, models, sounds).

Report back (≤ 250 words): files added/changed, what works, what is untested or stubbed, decisions you made beyond
the spec, anything the lead must do (icon uploads, build scripts to run).
