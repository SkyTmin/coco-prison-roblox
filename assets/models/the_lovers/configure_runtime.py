"""Target-only authored Samurai phases; existing HP/rewards/balance retained."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
a=s.index('    "the_lovers": {',s.index('"bosses":'))+len('    "the_lovers": ')
card,length=json.JSONDecoder().raw_decode(s[a:]);f=card['fight']
f.update(model='the_lovers',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=5.2,
 _abilities='[клиент/вики] Samurai Hanashiguro and spirit archer, three phases, sword/arrow/spear/shuriken/sickle families. [решение] original vulnerable three-phase encounter,50/25% thresholds,21 main clips plus mortal archer; no blocks. Timings/counterplay are authored, not recovered server values. assets/models/the_lovers/README.md; Studio QA pending.')
f['lovers']={'spawnDuration':2.8,'recovery':1.7,'phase3At':.25,'phase2Duration':3.6,'phase3Duration':3.3,
 'drawcut':{'duration':1.5,'release':.75,'damage':32,'radius':8,'halfAngle':70},
 'reversecut':{'duration':1.65,'release':.85,'damage':32,'radius':8,'halfAngle':70},
 'triplecut':{'duration':3.6,'release':1.1,'contacts':[1.1,1.8,2.5],'damage':43,'radius':9,'halfAngle':70},
 'sweep':{'duration':2.8,'release':1.35,'damage':43,'radius':10,'halfAngle':180},
 'thrust':{'duration':2.32,'release':1.2,'moveAt':.65,'range':12,'radius':5.5,'halfAngle':35,'damage':43},
 'dashcut':{'duration':2.48,'release':1.65,'moveAt':.8,'range':24,'radius':5.5,'halfAngle':60,'damage':54},
 'skycut':{'duration':3,'release':1.75,'moveAt':.9,'range':14,'radius':6.5,'damage':54,'omnidirectional':True},
 'stars':{'duration':3,'release':1.15,'range':34,'speed':30,'radius':.8,'damage':43,'count':5,'spread':9},
 'sickle':{'duration':3.48,'release':1.35,'range':24,'speed':26,'radius':1,'damage':43,'count':1,'returning':True},
 'spears':{'duration':2.8,'release':1.4,'range':32,'speed':26,'radius':.7,'damage':43,'count':3,'spread':7},
 'arrowcall':{'duration':3.72,'release':1.45,'damage':43},
 'spirit':{'hp':110,'speed':8,'spawnDuration':3.24,'deathDuration':4,'lifetime':60,'resummonDelay':25,'recovery':2.2,
  'bowshot':{'duration':3,'release':1.5,'range':36,'speed':29,'radius':.65,'damage':16,'count':1},
  'fan':{'duration':3.68,'release':1.68,'range':34,'speed':26,'radius':.7,'damage':18,'count':3,'spread':10},
  'rain':{'duration':4.56,'release':2.24,'range':30,'speed':24,'radius':1.0,'damage':21,'count':3},
  'spear':{'duration':2.92,'release':1.35,'range':34,'speed':27,'radius':.8,'damage':19,'count':1}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ');p.write_bytes((s[:a]+encoded+s[a+length:]).encode('utf8'))
print('Samurai configured; HP/rewards retained')
