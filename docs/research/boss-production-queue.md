# Boss production queue

Owner request: finish every boss sequentially (2026-11-02). Each checkpoint includes original Blender geometry and motion, source-backed skill names, authored server mechanics, exported-curve/render review, Studio QA, and a commit. Existing HP/rewards remain governed by the 2026-11-01 balance audit. Never publish the game or launch Blender's GUI.

Current owner steering: code/models only; Studio QA is deferred until evening. Offline checkpoints remain unchecked until their real in-game suites pass.

Completed: Basalt Guardian, Giant Zombie, Splinter, Minotaur, Piglin King, Skeleton, Knight, Poseidon, Illusionist, Spider Queen, Moth, Undead King, Forest Spirit (13/19).

Remaining route (source: boss location unlock levels; not difficulty ranking):

- [x] Knight — Royal Garden; 156 server assertions / 22 client animation checks, original Blender model and videos.
- [x] Poseidon — 68 server / 15 client checks; 90-second live encounter and coincident-position regression; original Blender model, 18 clips and videos.
- [x] Illusionist — original 359-part/34-joint model, 16 clips, articulated rabbit; 92 server / 14 client / 43 no-block checks, two 90-second live encounters. Videos in assets/models/illusionist.
- [x] Spider Queen — 863-part/38-joint model, 12 clips, articulated huntsman; 101 server / 11 client / 43 no-block checks and a 90-second live fight. Videos in assets/models/spider_queen.
- [x] Moth (Моль, config id `mole`) — 693 parts/39 joints/19 clips; 150 server/15 client/43 no-block checks and a 90-second live fight. Videos in assets/models/moth.
- [x] Undead King — 382 parts/38 joints/13 clips plus ghoul, skull and sword rigs; 169 server/17 client/43 no-block checks, 90-second live fight. Videos in assets/models/undead_king.
- [x] Forest Spirit — 752 parts/47 joints/17 clips plus four original summon rigs;234 server/22 client/43 no-block assertions,90-second moving-target live fight and actual arena view. Videos in assets/models/forest_spirit.
- [ ] Raven Knight — code/model checkpoint prepared:721 parts/40 joints/14 clips, retainer671/40/10, raven48/11/3 and axe20/2/2. Offline curves/build pass; server/client/live Studio QA **PENDING evening**. assets/models/raven_knight/README.md.
- [ ] Vecna — next code/model production.
- [ ] The Lovers.
- [ ] Ent.
- [ ] Forest Guardian.
- [ ] Reaper.

QA limitations carried forward: real 4–6-player and phone/load combat remain untested. Skeleton's cold-start timed damage suite missed three totals; warm rerun passed 61 checks. Cause remains unestablished; investigate before treating startup timing as validated.
