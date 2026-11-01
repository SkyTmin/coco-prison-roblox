"""Specialize the existing exported-track review tooling for this original rig."""
from pathlib import Path
here=Path(__file__).parent
s=(here.parent/'poseidon/render_motion.py').read_text(encoding='utf8')
s=s.replace('poseidon','illusionist').replace("['Joint_trident']","['Joint_dagger','Joint_cards','Joint_hat']")
s=s.replace("(1.2,1.152,.6) if clip=='walk' else (1.2,1.98,.55)","(1.6,1.248,.6) if clip=='walk' else (.8,.99,.55)")
s=s.replace("['idle_sitting','awaken','kneel','death']","['notactive','active','death']")
s=s.replace("if clip=='death' and t>=3:","if clip=='death' and t>=3.5:")
s=s.replace("'motion-validation.json'),'w')", "'motion-validation.json'),'w',newline='\\n')")
(here/'render_motion.py').write_bytes(('\n'.join(line.rstrip() for line in s.splitlines()).rstrip()+'\n').encode())
s=(here.parent/'poseidon/assemble_motion.py').read_text(encoding='utf8').replace('poseidon','illusionist')
s=s.replace("[('swing',.48),('wave_clash',.66),('epicenter',1.02),('torpedo',.5),('walk',.3),('death',4.7)]", "[('attackdagger',.71),('attackcards',1.02),('summonrabbits',2.15),('regeneration',2.6),('walk',.4),('death',7.9)]")
s=s.replace('ПОСЕЙДОН','ИЛЛЮЗИОНИСТ').replace('521 деталь · 35 суставов · 18 клипов','359 деталей · 34 сустава · 16 клипов')
s=s.replace('[.3,1.3,2.7,4.7]','[.3,1.5,3.1,7.9]')
s=s.replace("[('idle',1),('death',4.7),('swing',.48),('wave_clash',.66),('epicenter',1.02),('torpedo',.5)]", "[('idle',1),('death',7.9),('attackdagger',.71),('attackcards',1.02),('summonrabbits',2.15),('regeneration',2.6)]")
(here/'assemble_motion.py').write_bytes(('\n'.join(line.rstrip() for line in s.splitlines()).rstrip()+'\n').encode())
