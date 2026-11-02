# Samurai / The Lovers — production evidence and plan

02 November 2026. Code/model work only; Studio QA deferred until evening. Headless Blender, no GUI/notifications. Baseline95e3852.

[wiki/menu] Kyoto unlock29, Samurai Hanashiguro and his beloved's spirit fight with blade and bow. Red/gold armor; respawn8h, bank$0–10000, stars10–16, Ancient Powder label1–50%, Fire Shard. Preserve audited2970HP, raw32/43/54 and combat regeneration7HP/s; public result chat damage/share/dollars only [owner].

[primary web] https://mcmodels.net/products/11448/the-lovers-samurai-boss (checked02.11): creator MC Garage; three phases,14 models,50+animations and40attacks; price$35 before possible VAT. Requires Minecraft ModelEngine/MythicMobs. This is a source identification, not an assertion that its purchase grants Roblox redistribution rights. No pack downloaded or imported. Authored original geometry/choreography/mechanics will use the established blade/bow/phase families; exact damage, contact and phase thresholds are our decisions.

[client] Exact local clip summaries, wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json:

- lovers/big_arrow.model: idle=1.68 loop
- lovers/ghost_spear.model: idle=0.76 loop
- lovers/ghost_spear2.model: spawn=2.04
- lovers/kusarigama.model: idle=2.04 loop
- lovers/rain_arrow.model: spawn=5.04
- lovers/samurai_armor_dequip.model: spawn=5.4
- lovers/shuriken.model: idle=0.96 loop
- lovers/the_lovers_ghost.model: idle=3.36 loop, walk=3.36 loop, attack1=3, attack2=3.68, attack3=2.92, attack4=2.32, attack5=3, attack6=6.76, attack7=2.24, attack8=4.56, spawn=3.24
- lovers/the_lovers_phase_1.model: idle=3.36 loop, walk=2.32 loop, attack1=3, attack2=3.6, attack3=4.84, attack4=2.08, attack5=3.48, attack6=4.72, attack7=2.8, attack8=2.8, attack9=1.52, attack10=2.48, taunt=3.36, damage=0.6, death=0.28, spawn=10.12
- lovers/the_lovers_phase_2.model: idle=3.36 loop, walk=2.32 loop, attack1=3, attack2=5.36, attack3=4.84, attack4=2.24, attack5=7.24, attack6=5.44, attack7=3, attack8=2.8, attack9=1.52, attack10=3.72, attack11=2.32, taunt=3.36, damage=0.6, spawn=19.28, death=6.44
- lovers/the_lovers_phase_3.model: idle=13.52 loop, walk=0.56 loop, taunt=3.36, damage=0.6, attack1=2.32, attack2=2.04, attack3=1.96, attack4=2.88, attack5=2.4, attack6=1.16, attack7=4.48, attack8=4.48, attack9=1.88, attack10=2.88, spawn=10, death=26.92
- lovers/the_lovers_slash2.model: idle=3.32 loop, spawn=0.72
- lovers/the_lovers_slash3.model: idle=2.48 loop, spawn=1.08
- lovers/the_lover_slash1.model: spawn=3.24, idle=0.8

[decision, implemented offline] One authoritative boss, three progressive combat phases and a separate original spirit archer. No defensive blocks/immunity. Telegraph sword combos, sweeping slashes, grounded rushes, thrown stars/sickle, spear and arrow/rain families with finite swept projectiles. Shared per-cast budgets, recoveries, clear counterplay, arena/support checks, complete cleanup. Phase transitions use a vulnerable stance reset and retain worn armor; no mesh fades/rebuilds, duplicate humanoids or extra boss reward targets. Original layered limb/weapon/cloth motion; final death must collapse and settle, not simply rotate the whole model. Source phase1death.28 and phase2death6.44 are transition clips, not our final26.92s literal wait. Compress authored transition/death lengths and explicitly document them.
