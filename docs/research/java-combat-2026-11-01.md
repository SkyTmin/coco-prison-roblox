# Minecraft Java melee rules — 01 November 2026

Owner requested normal/critical attacks, intervals and damage matching Minecraft, while keeping the previously requested immediate short visual swing on every tap. Sources: [Minecraft Wiki: Melee attack](https://minecraft.wiki/w/Melee_attack) and [Damage](https://minecraft.wiki/w/Damage), checked 01 November 2026. Java is the chosen edition, consistent with the project's existing weapon and armor formulas [decision]. This is not a claim that every Minecraft combat mechanic or all ancient books are vanilla.

## Implemented rules

- Attack recovery `T = 1 / attackSpeed`: sword 0.625 s, pickaxe about 0.8333 s, axe 1–1.25 s depending on material, empty hand 0.25 s [vanilla]. No second-long visual pause: the existing 0.22 s visual swing remains independent [owner/decision].
- `p = clamp((elapsed + 0.025) / T, 0, 1)`; ordinary base damage is multiplied by `0.2 + 0.8 p²`, enchantment damage by `p` [vanilla]. An early click resets recovery and produces a weak attack. Holding attacks at full weapon intervals while the visible hand continues short cycles [decision for the requested controls]. Network flood floor 0.1 s [decision].
- Critical requires `p > 0.9`, descending and airborne, with no sprint, climbing, swimming, riding, flying, cobweb, Blindness, Slow Falling or Levitation [vanilla]. Critical multiplies the base (including Strength/Weakness) by 1.5 before adding Sharpness. Strength is +3 per level and Weakness −4 per level [vanilla]. Ranged attacks do not inherit these melee bonuses.
- Client fall intent alone never grants a critical. The server uses validated motion history, downward velocity and a collision-respecting ground ray. It rechecks at visible contact because replicated Humanoid FloorMaterial/velocity can lag just after the jump apex [implementation]. Sweep grounding uses the same observed ground test.
- Switching held item/material and successful block breaking reset attack recovery [vanilla]. A delayed hit cannot move to another held stack or respawned character.
- Hurt window is 0.5 s. Equal/weaker raw attacks within it do nothing; a stronger hit applies only the increase over the preceding raw hit, without extending the original window [vanilla]. Armor is applied to the accepted difference. Knockback and Rage stacks are not awarded for ignored attacks.
- Full damage goes to one primary target. A charged, grounded, non-sprinting sword attack may sweep nearby secondary targets for 1 damage, without full ancient-book procs [vanilla basis; existing project targeting geometry retained]. A charged sprint attack adds knockback and stops sprinting.
- **Raid adaptation [decision]: boss hurt immunity is per attacker**, so a party's attacks do not cancel one another. Ordinary mobs and PvP retain a shared target window. The separate boss incoming-burst cap is documented in the balance report.
- A small text-free recovery bar under the crosshair shows readiness; it hides in menus/mining. Damage numbers remain by the crosshair, with existing crit feedback. No new player-facing strings.

## Validation

`scripts/qa-java-combat.luau`: **24 PASS** in the correct Studio place 92594200898716. Covers weapon periods, early/full damage, enchantment/critical order, status bonuses, critical restrictions, shared/per-attacker immunity, stronger-hit delta and non-extension; also calls the real CombatService damage path with disposable Humanoids.

Real client input → live server Attack remote, owner's current `pickaxe:16`: full ordinary strike **5 HP**, early strike about **1.339 HP**, another immediate repeat **0 additional HP**, secondary nearby target **0 HP**. Forged falling flag while grounded remains **5 HP**. A real jump and descending hit after the motion-history fix deals **7.5 HP** [measurements]. Test targets removed; inventory, money and saved progression untouched.

Existing client input regression: **6 PASS**, first and repeated taps respond immediately; eight visual cycles over 1.8 s holding, longest measured idle gap about 0.0185 s; release/menu behavior restored [measurement]. Live multiple-player PvP and real phone touch remain separate playtests. The tests above do not claim those were performed.

Files: shared `Combat`, server `CombatService`, `DamageImmunity`, `MotionService`, `BookService`, `NeedsService`, held-item reset in `ProfileService`, block reset in `DigService`, client attack input/recovery indicator. Generated settings come from `scripts/design-decisions.json`.
