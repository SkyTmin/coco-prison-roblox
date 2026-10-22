---
name: blender-block-mob
description: Make a blocky mob or boss for coco-prison-roblox "точь в точь" from a Codex reference sheet — Codex draws a 4-view reference, Blender (headless, Python) builds the model and its animation clips, the export goes to src/shared/Models/<id>.json, BlockRig rigs it in the game and MobAnimator / BossAnimator play the clips. Use whenever the owner asks for a new mob, boss or creature model, or to remake one "по фото / как на референсе".
---

# Blocky mob / boss from a Codex reference (Blender pipeline)

The rat (`assets/models/rat`) and the Базальтовый страж (`assets/models/basalt_guardian`) were made this way and
the owner accepted both [владелец 22.10: «с крысой практически точь в точь, результатом я доволен»]. Reuse the
code; never start from scratch.

Files:
- `assets/models/blockmob.py` — the shared Blender pipeline: `build` / `export` / `compare`, noise texture, glow
  parts, Roblox-space JSON. A mob file only holds data and ends with `run(globals())`.
- `assets/models/<id>/<id>.py` — the mob: `NAME`, `HERE`, `JOINTS`, `PARTS`, `actions()`, `PREVIEWS`,
  `PREVIEW_CAMERA`, `COMPARE`, optional `TILE_STUDS`, `NOISE()`, `GAME_LIFT`, `GLOW_STRENGTH`, `NOISE_FILE`.
- `scripts/model-tools/` — `gridref.cjs` (crop + labelled grid for measuring), `sample.cjs` (average colours of
  areas), `bbox.cjs` (silhouette boxes of the 4 panels: do the views agree?), `cmp.cjs` (reference | render | 50/50
  mix per view), `grid.cjs` (tile previews), `voxelize-front.cjs` (front-view voxeliser for voxel sculptures).
- `assets/models/voxelsculpt.py` — experimental 2–3 view visual hull (not used by the accepted models; AI sheets
  disagree between views, the hull goes boxy — see "Lessons").
- Game: `src/shared/BlockRig.luau` (build the rig, sample clips), `src/server/Services/MobService.luau`
  (`buildRat`), `src/server/Services/BossService.luau` (`buildBlock` when `bosses.<id>.fight.model` is set),
  `src/client/MobAnimator.luau` (mobs), `src/client/BossAnimator.luau` (`animateBlock` for bosses).

Blender: `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"` (5.x: layered actions — the pipeline
stores keyframe frames in `act["frames"]`, assigns the action slot, sets `use_fake_user`). sharp for the node
tools lives in the old scratchpad (path inside the scripts; `SHARP_PATH` overrides).

## 1. The reference (Codex)

`mcp__codex__codex_image`, size `1536x1024`, `reasoning_effort: low`, `reference_images`: an accepted sheet
(`assets/models/rat/rat-reference.png`) for the style. Ask for a 2×2 sheet on plain light grey, no text:
side view facing LEFT (top-left), front (top-right), top view head LEFT (bottom-left), three-quarter from the
front-left (bottom-right); boxes only, flat 16×16-pixel-look textures; give proportions and hex colours in the
prompt. For a boss, also ask for strict orthographic views with the same ground and height lines in side and
front, and the body depth ≈ 55–60 % of the width. Check with `bbox.cjs`: side and front heights must match;
Codex top views are usually drawn at another scale — fit them separately or ignore them.

## 2. Measure

`node scripts/model-tools/gridref.cjs <sheet> <out.png> <left> <top> <w> <h> 20 <scale>` and read the picture:
pick px-per-stud from a known height (rat ≈ 2 studs tall at 140 px/stud; bosses ≈ 9.5–10 studs), the centre
line and the ground line. Blender space: X lateral (+X = the mob's right hand, named …L in the mirror helper),
Y forward, Z up; X = (centreX − x) / S, Z = (groundY − y) / S on the front view; Y = (centreX − x) / S on the
side view (facing left). Colours: `sample.cjs` on lit faces; stone/fur noise is ±20 % around them.

## 3. Build the model — three ways (C is the default for anything with limbs)

**A. Hand boxes (creatures: rat, small mobs).** `box(name, joint, (x0, x1), (y0, y1), (z0, z1), colour, top,
mirror=True)`, `turned(...)` for slightly rotated groups, rotated parts via the 7th tuple element. Every box from
the measurements; many small boxes (steps, plates, ears made of three boxes) — big flat boxes read as "слишком
квадратный". Top faces may take their own colour (`top`). Pixel grain: `NOISE()` tile, `TILE_STUDS`.

**B. Front-view voxels (voxel-sculpture bosses).** `assets/models/<id>/voxelize.json` + `voxelize-front.cjs`:
every 10×10 px cell of the front view becomes a box of its colour (stone tones by luminance, lava tones
deep/warm/bright/hot by brightness, `glow`), extruded over its body region's depth `y` and rounded towards the
silhouette (`bevel`); regions (sheet px rects → joints, first match wins) split the body into joints; then the
boxes are merged. Extras: `side` regions give a joint its depth from the side view per height (`voxel: true`
also colours its outer sides from the side view — used for the sword), `lavaBias` keeps thin molten cores,
`stoneByJoint` (obsidian blade), region splits for a hump. The mob file loads `voxels.json` into `PARTS`. The
owner liked this for the guardian: the front matches pixel for pixel. Keep depths moderate (body ≈ ±1.5–3).

**C. Part by part (Зомбарь; the owner's method — «делай по частям: руки, ноги и т. д., смотри каждую часть с
нужной стороны, потом соедини»).** `assets/models/<id>/parts.json` + `scripts/model-tools/parts.cjs`: every part
(head, body, each arm, each leg) gets its own rects on the front, side and (if it shows there) top view. Its X/Z
box comes from the front, its Y from the side; the side and top silhouettes are stretched to the part's own box,
so views drawn at different scales still agree per part. A voxel stays when it is inside every silhouette AND
inside a rounded cross-section (`round`: superellipse exponent 2.2–3.2; `axis` "z" for upright parts, "y" for
limbs pointing forward) — round bellies and backs, tube-like arms stepping thinner at the ends, never flat
extrusions. Faces take the colour of the view they face (front / top / side; the back from the side view, never
glowing), inner voxels the part's main colour. `priority` decides overlaps; give the body rects that cover the
head and the arms so nothing is hollow behind them. `neonOnly: "hot"` keeps only the brightest glow Neon.
Render "back" and "back34" cameras too: the owner checks the back («пустота в спине», «спина плоская»).

## 4. Compare until it matches (the step that made the rat "точь в точь")

`blender -b <id>.blend -P <id>.py -- compare` renders `compare-<view>.png` with the reference panels' cameras:
ortho side/front/top with `(right, up, centre, 768 / S)` — centre so the object lands where it is in the panel
(panel centre 384, 256) — and a perspective `"34"` `(location, target, lens)`. Then
`node scripts/model-tools/cmp.cjs assets/models/<id> <sheet> <out.png> side,front,34 0.5` and look at the 50/50
column: fix sizes, positions, colours (sample our render vs the sheet), iterate. Send the owner the sheet
(`compare-views.png`) — they judge by eye and will point at the view that is off.

## 5. Animations

`actions()` returns `{clip: (keys, loop)}`, keys = `(frame, {joint: (rx, ry, rz°, offset)})` at 30 fps. Signs in
Blender: +X on a limb swings it forward, on the head tilts up, on the body leans back. Mobs: idle, walk, bite
(MobWindup), hurt, death. Bosses: idle, walk, melee, blade_raise + blade_sweep (held raise, sweep in the last
0.9 s), spikes_raise + spikes_slam (slam in the last 0.6 s), charge (held), stunned (loop), roar, jump — the names
BossAnimator maps from the server's Action attribute. `PREVIEWS` renders key frames to check poses.

## 6. Export and the game

1. `-- export` → `src/shared/Models/<id>.json` (big models use format 2 — joint and palette indexes, 2 decimals: a
   ModuleScript holds at most 200 000 characters; ~3000 parts fit) + `noise.png` + previews.
2. Upload the noise tile (serve `assets/` PNGs on 127.0.0.1:8767, `upload_image`) → id into
   `assets/models/<id>/ids.json` and `scripts/design-decisions.json`: mobs → `mobs.<id>.furTexture` (+ `model`);
   bosses → `bosses.<id>.fight.model` + `fight.texture`; `node scripts/build-configs.mjs`. Re-upload after any
   noise change.
3. `GAME_LIFT` compensates Roblox light: low-saturation fur under the cool sky turned grey → saturate 1.6; the
   guardian's purple-grey stone under the orange arena turned pink → saturate 0.6. Lava/glow parts are Neon and
   never lifted.
4. Sync (`make-studio-sync.mjs <files>`), Play, check: parts on the ground, joints count, the clips (set the
   model's Action / ActionAt / ActionLen from the server to hold a pose for a screenshot), the look in the real
   lighting. Restore a minimised Studio window before `screen_capture` (white captures).
5. PROGRESS line, CLAUDE.md if a path changed, commit + push.

## Lessons

- The owner prefers a convincing 3D shape over a pixel-exact copy of every view («может, не надо точь в точь»):
  match the front, keep the side close, and make every part round from all sides.
- AI sheets are not consistent 3D: the views disagree in depth and scale. A visual hull of two or three views
  goes boxy or loses parts. Match the front exactly and take depth carefully from the side; ask Codex for a
  consistent turnaround if the owner wants every view exact.
- Front colours extruded through the depth streak along the sides; give long parts side colours (`voxel: true`)
  or a one-tone body (`capDepth`/`bodyTone` in voxelize-front).
- Blender 5: no `action.fcurves`; unassigned actions vanish on save without `use_fake_user`; set the image
  colorspace before filling pixels; Workbench/AgX darken flat colours — the renders use Eevee + Standard.
- Never change a block model's parts at runtime (Color, Transparency, Material, joints, physics, a ForceField
  in the model): one change rebuilds the render of all ~3000 boxes on every client — a ~0.6 s frozen frame.
  Show states with a Highlight or separate effect parts; move the model only through its joints and root CFrame;
  the death is one piece (BossService.died: topple + puff), never per-box physics or fades.
