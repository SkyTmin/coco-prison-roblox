# Zombar v2 — original Blender model and articulated motion

Owner request, 2026-11-01: replace the boss, improve weight, detail and smoothness, including an articulated death. Blender runs **headlessly only**; Studio and desktop notifications must remain untouched during this task.

## Review artifacts

- `zombar-reference-v2.png`: AI concept, **not a screenshot of the model**.
- `zombar-showcase.png`: actual exported model, rendered in Blender.
- `zombar-motion.mp4`: idle, walk, melee, the existing special abilities and stun (FFmpeg encoding).
- `zombar-death.gif`, `zombar-death-poses.png`: complete collapse and contact poses.
- `giant_zombie.blend`, `giant_zombie.py`: editable source and reproducible build.
- `v2-preview-*.png`: source Blender poses. Older references, voxel inputs and unprefixed review images in this directory are historical and are not used by v2.

The source builds 416 cuboids on 23 joints [implementation]: pelvis, chest, head, jaw, upper arms, forearms, wrists, fingers/thumbs, thighs, shins, feet and two chain joints. A closed stepped back and belly replace the old front-view extrusion. Existing uploaded noise texture is reused exactly; no new Roblox asset upload is required. No commercial/source-game mesh or animation was imported.

## Facts versus our game

The recovered client reports **only one melee attack** for the original Zombar, 1.32 s, plus idle 4.16 s, walk 1.5 s and death 2 s [client: `wiki/client-audit/RESOURCEPACK-BOSSES.md`, `content-analysis/resourcepack/boss-model-animations.json`]. The wiki description is an undead mass of flesh on the faction base [menu: `wiki/in-game-wiki/BASEMENT-FACTION-BASE.md`].

Our pre-existing green vomit wave, earth slam and charge remain in place [earlier owner/project decisions]; these are **not claimed to be recovered original abilities**. HP, reward, damage, cooldown and respawn configuration stays unchanged. Melee now lasts 1.32 s [client], with contact at 0.56 s [decision]; the recovery remains inside the existing cooldown. Death lasts 3.2 s [decision for this request], extending the original duration to show the knee buckle, bracing hand, shoulder impact and inert settling.

Fourteen clips [implementation]: idle, walk, melee, blade_raise/sweep, spikes_raise/slam, charge_raise/run, compatibility charge, stunned, roar, jump and death. The charge has moving legs, rather than one frozen lean. Walking uses a stance/swing trajectory and two-bone leg solve; the game scales its phase from the authored stride speed. Chest twist leads punches, elbow and wrist follow; jaw and chain lag behind large motions. Death takes over all joints and holds its final pose until removal.

## Smooth export and integration

Blender curves use clamped handles to control overshoot ([Blender F-curve documentation](https://docs.blender.org/manual/en/4.5/editors/graph_editor/fcurves/properties.html)). Opt-in `BAKE_CURVES` samples quarter frames, then removes samples only within 0.008 stud / 0.35 degree local error [decision]. Subframe verification samples again at 60 Hz. Packed position/quaternion keys keep the model below Roblox's ModuleScript source budget without discarding the easing.

`BlockRig` supports both legacy and packed keys. Existing models retain their format and clips. `BossAnimator` blends an interrupted action from the last visible pose, blends charge preparation into its run, and aligns the vomit/slam contact keys to server `ActionRelease`. `BossService` selects the configured death clip before clearing the live boss reference; it anchors the root and retains the joints instead of rotating or physically dismantling the model. Ordinary template bosses retain their fallback behavior.

## Reproduce (PowerShell, no GUI)

```powershell
$blenderExe = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blenderExe -b -t 4 --python-exit-code 1 -P assets/models/giant_zombie/giant_zombie.py -- build
& $blenderExe -b assets/models/giant_zombie/giant_zombie.blend -t 4 --python-exit-code 1 -P assets/models/giant_zombie/giant_zombie.py -- export
& $blenderExe -b assets/models/giant_zombie/giant_zombie.blend -t 4 --python-exit-code 1 -P assets/models/giant_zombie/render_motion.py
python assets/models/giant_zombie/assemble_motion.py
node scripts/model-tools/validate-zombar.cjs
node scripts/model-tools/validate-splinter.cjs
```

`render_motion.py` reconstructs every joint from the exported Roblox quaternions and positions, checks motion against Blender between keys and checks death-floor contact, then renders those exported poses. `motion-validation.json` records measured errors. Frame folders are ignored; the final sheets/GIFs are tracked. Render FPS is 20 [decision for file size]; gameplay interpolation runs every client simulation frame.

## Evening Studio checks — not yet performed

Full source sync in **Edit**, then restart Play. The existing `fight.model = giant_zombie` selects the new export automatically; no map rebuild or `.blend` import is needed. Check faction-base lighting/scale, all four attack types against actual players, contact versus damage, moving-target pursuit and feet at normal/charge speed. Interrupt every ability with death: no delayed damage, no root topple layered over the new collapse, no standing back up, correct rewards and respawn. Verify two clients, streaming, phone FPS, and a regression pass on Splinter and the basalt guardian. Do not replace the full cloud map with a source-only Rojo build.
