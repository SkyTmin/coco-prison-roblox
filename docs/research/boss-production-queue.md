# Boss production queue

Owner request: finish every boss sequentially (2026-11-02). Each checkpoint includes original Blender geometry and motion, source-backed skill names, authored server mechanics, exported-curve/render review, Studio QA, and a commit. Existing HP/rewards remain governed by the 2026-11-01 balance audit. Never publish the game or launch Blender's GUI.

Completed: Basalt Guardian, Giant Zombie, Splinter, Minotaur, Piglin King, Skeleton, Knight, Poseidon, Illusionist, Spider Queen (10/19).

Remaining route (source: boss location unlock levels; not difficulty ranking):

- [x] Knight — Royal Garden; 156 server assertions / 22 client animation checks, original Blender model and videos.
- [x] Poseidon — 68 server / 15 client checks; 90-second live encounter and coincident-position regression; original Blender model, 18 clips and videos.
- [x] Illusionist — original 359-part/34-joint model, 16 clips, articulated rabbit; 92 server / 14 client / 43 no-block checks, two 90-second live encounters. Videos in assets/models/illusionist.
- [x] Spider Queen — 863-part/38-joint model, 12 clips, articulated huntsman; 101 server / 11 client / 43 no-block checks and a 90-second live fight. Videos in assets/models/spider_queen.
- [ ] Moth (Моль, config id `mole`) — next.
- [ ] Undead King.
- [ ] Forest Spirit.
- [ ] Raven Knight.
- [ ] Vecna.
- [ ] The Lovers.
- [ ] Ent.
- [ ] Forest Guardian.
- [ ] Reaper.

QA limitations carried forward: real 4–6-player and phone/load combat remain untested. Skeleton's cold-start timed damage suite missed three totals; warm rerun passed 61 checks. Cause remains unestablished; investigate before treating startup timing as validated.
