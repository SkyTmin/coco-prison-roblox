"""Audited Moth action names, original mechanics, preserve HP and rewards."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "mole": {',s.index('"bosses":'))+len('    "mole": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='moth',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=2,
 _abilities='[клиент] moon_glow: attack1/3/4, shadowlight, moonssight, meteorrain, midnight, startshoot/descendshot/descendend, stun, death. [решение] original model and server mechanics; assets/models/moth/README.md. [владелец] no boss blocks.')
f['moth']={'recovery':1.5,'spawnDuration':1.8,
 'melee':[{'name':n,'duration':d,'release':t,'damage':18,'radius':8,'halfAngle':65}for n,d,t in [('attack1',.8611,.43),('attack3',.75,.37),('attack4',.75,.4)]],
 'shadowlight':{'duration':1.5417,'release':.91,'damage':28,'range':34,'speed':26,'radius':1.3,'count':3,'phase2Count':5,'spread':12},
 'moonssight':{'duration':1.5833,'release':.98,'damage':28,'range':28,'width':4},
 'meteorrain':{'duration':1.9167,'release':1.15,'damage':36,'range':26,'radius':3.8,'height':12,'flight':.75,'count':3,'phase2Count':5},
 'midnight':{'duration':2.125,'release':1.18,'damage':28,'radius':16,'speed':10,'width':2,'gapDegrees':30,'jumpHeight':4.1},
 'startshoot':{'duration':2.5417,'release':.55,'height':4,'shotDuration':1.2083,'shotRelease':.56,'landDuration':.4583,'count':1,'phase2Count':2,
  'damage':36,'range':26,'radius':3.8,'flight':.65,'interruptDamage':60,'stunDuration':.75}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((s[:start]+encoded+s[start+length:]).encode());print('Moth configured; HP/rewards retained')
