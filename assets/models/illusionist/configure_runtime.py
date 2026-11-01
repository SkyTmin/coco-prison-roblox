"""Original server interpretation of audited action names; keep the existing balance/loot."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "illusionist": {',s.index('"bosses":'))+len('    "illusionist": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='illusionist',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=8,
 _abilities='[клиент] illusionist: dagger, cards, box, rabbits, phasecards, regeneration and death8. [владелец] no blocks/immunity. [решение] original mechanics, movement, ranges and timings; assets/models/illusionist/README.md')
f['illusionist']={'recovery':1.5,'spawnDuration':1.8,
 'melee':[{'name':'attack','duration':1,'release':.46,'damage':14,'radius':8,'halfAngle':60},{'name':'attack2','duration':1,'release':.5,'damage':14,'radius':8,'halfAngle':60}],
 'attackdagger':{'duration':1.34,'release':.71,'damage':22,'range':34,'speed':24,'radius':1.1},
 'attackcards':{'duration':2.006,'release':1.02,'damage':22,'range':30,'speed':20,'radius':1.2,'count':3,'phase2Count':5,'spreadDegrees':12},
 'attackbox':{'duration':2.2,'release':1.21,'damage':28,'range':22,'radius':4.2},
 'summonrabbits':{'duration':3.35,'release':2.15,'range':7,'count':3,'phase2Count':4,'maxAlive':4,'hp':10,'speed':10,'lifetime':14,'triggerRadius':4,'radius':4.5,'damage':14,'fuse':2.5,'explosionDuration':3.5},
 'phasecards':{'duration':1,'release':.45,'moveEnd':.8,'range':6},
 'regeneration':{'duration':5.9,'release':1.3,'ticks':4,'interval':.8,'healFraction':.02,'interruptDamage':40}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((s[:start]+encoded+s[start+length:]).encode());print('Illusionist configured; balance/loot retained')
