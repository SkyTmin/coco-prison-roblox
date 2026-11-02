# Vecna — evidence and plan

02 November 2026. Owner: code/model work only, Studio QA in the evening; no desktop control, GUI or notifications. Headless Blender only.

[wiki/menu] `HANDBOOK-WIKI.md`85/107/127: Inside Out/Изнанка, respawn4h, bank$0–6400, stars7–12, Ancient Powder label1–25%; brown humanoid. Existing2770HP, damage29/40/50 and active-combat regen6HP/s remain [decision: boss-balance-2026-11-01]. No loot in public boss result chat [owner].

[client] `boss-model-animations.json`, `strangerthings/pa_vecna1.model`: idle4, walk1.25, attack1=0.5, attack2=4, death4.7 marked loop=true; flower is loop=true but length=null. Do not invent a recovered duration or loop the final death. Clock spawn.7/idle3; clock_vecna look3=2.4; portal idle15; demobat attack.5/walk5, demogorgon attack4=.5/walk1.25/run1/idle4, demodog attack1=.5/walk1.25/idle4. Names and durations establish visual families, not server mechanics or damage rules.

Public search02.11 did not identify a verified original commercial source for this exact `pa_` pack. Do not confuse D&D Vecna or unrelated 3D-print/fan models with the recovered Stranger Things family. No external assets downloaded. Original geometry/choreography is authored here, guided by a new built-in image_gen concept.

[decision, implemented offline; Studio pending] Vulnerable tendril humanoid with a quick claw, four-second sweeping tendril cast, outward flower/tendril burst, destructible clock curse and interruptible portal summons. Clear geometric warnings and grounded/collidable counterplay; never lock the player's camera, globally highlight mobs, or create player copies. Three original capped minion rigs; every actor/effect has bounded life and encounter cleanup. Clock can be destroyed before expiry; portal interrupt is visible and never shields the boss. Authored damage/timing is documented in README.md. Keep source-only claims separate.
