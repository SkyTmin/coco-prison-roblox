"""Target-only original encounter. Existing balance/rewards preserved; Studio deferred."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "vecna": {',s.index('"bosses":'))+len('    "vecna": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='vecna',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=4.7,
 _abilities='[клиент] pa_vecna1 attack1/attack2/flower, clock, portal, demogorgon/hound/bat families. [решение] original tendril choreography, destructible clock curse, interruptible portal; flower length is unknown in audit, death made non-looping. assets/models/vecna/README.md. Studio QA pending; no camera control, player clones or boss immunity.')
f['vecna']={'spawnDuration':2.4,'recovery':1.7,
 'melee':{'duration':.85,'release':.5,'damage':29,'radius':8,'halfAngle':70},
 'attack2':{'duration':4,'release':2.1,'damage':40,'range':25,'radius':3.1,'count':3,'phase2Count':5,'spacing':4.5},
 'flower':{'duration':5.5,'release':2.3,'damage':40,'radius':17,'speed':10,'width':2,'gapDegrees':30,'jumpHeight':4.1},
 'clockcast':{'duration':2.7,'release':1.25,'damage':50,'range':24,'radius':8,'hp':80,'lifetime':6,'spawnDuration':.7,'deathDuration':2.2,'lift':2.45,'width':1.5,'depth':.85},
 'portalcast':{'duration':3.5,'release':1.5,'interruptDamage':110,'stagger':.45,'count':2,'phase2Count':3,'maxAlive':4,
  'adds':{
   'vecna_stalker':{'hp':42,'speed':10,'reach':4.5,'damage':10,'hitAt':17/30,'cooldown':1.9,'spawnDuration':1,'deathDuration':2.6,'lifetime':22,'lift':2.5,'width':1.4,'depth':1.1},
   'vecna_hound':{'hp':30,'speed':13,'reach':3.8,'damage':9,'hitAt':.5,'cooldown':1.7,'spawnDuration':.9,'deathDuration':2.3,'lifetime':22,'lift':1.1,'width':1.4,'depth':1.8},
   'vecna_bat':{'hp':16,'speed':10,'reach':3.4,'damage':7,'hitAt':.4,'cooldown':1.5,'spawnDuration':.6,'deathDuration':1.8,'lifetime':18,'lift':.5,'width':1,'depth':1,'flying':True}}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ');p.write_bytes((s[:start]+encoded+s[start+length:]).encode())
print('Vecna configured; HP/rewards retained')
