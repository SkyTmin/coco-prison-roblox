"""Audited spell families, original vulnerable forest encounter. Retain HP/rewards."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "forest_spirit": {',s.index('"bosses":'))+len('    "forest_spirit": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='forest_spirit',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=6.2,
 _abilities='[клиент] forest_spirit attack1-8, totem, roots/spikes/storm/arrows/lightning, shaman/explorer/flying skull. [решение] original model and mechanics, source long lifecycle/ritual clips condensed; assets/models/forest_spirit/README.md. [владелец] no boss blocks or summon immunity.')
f['forestSpirit']={'recovery':1.7,'spawnDuration':3.2,'cancelDuration':1.2,
 'melee':{'name':'attack7','duration':1.9,'release':.93,'damage':23,'radius':8,'halfAngle':65},
 'attack1':{'duration':4.3,'release':2.2,'damage':34,'range':26,'radius':3.2,'count':2,'phase2Count':3,'slowLevel':1,'slowSeconds':1.2},
 'attack2':{'duration':4.95,'release':2.5,'damage':34,'range':26,'radius':3.2,'count':2,'phase2Count':3,'stagger':.3},
 'attack3':{'duration':2.5,'release':1.35,'damage':34,'range':34,'speed':25,'radius':1.1,'count':3,'phase2Count':5,'spread':11},
 'attack4':{'duration':4.75,'release':2.5,'secondRelease':3.8,'damage':34,'range':26,'radius':3.3,'height':12,'count':1,'phase2Count':2},
 'attack5':{'duration':3.25,'release':1.8,'damage':34,'radius':16,'speed':11,'width':2,'gapDegrees':25,'jumpHeight':4.1},
 'attack6':{'duration':11.45,'release':2.7,'waves':[2.7,5.3,7.9],'warning':1,'damage':42,'range':26,'radius':3.7,'height':12,'count':2,'phase2Count':3,'interruptDamage':100},
 'attack8':{'duration':8.4,'release':1.6,'blastAt':7.2,'warning':1.3,'damage':42,'range':7,'radius':10,'totemHp':60,'count':3,'phase2Count':4,'maxAlive':4,
  'adds':{
   'forest_shaman':{'hp':24,'speed':9,'spawnDuration':1.2,'lifetime':18,'reach':18,'damage':9,'cooldown':2.7,'hitAt':.7,'radius':2.6,'deathDuration':2.24,'kind':'ranged'},
   'forest_explorer':{'hp':28,'speed':11,'spawnDuration':1.2,'lifetime':18,'reach':4,'damage':8,'cooldown':1.9,'hitAt':.85,'deathDuration':2.24,'kind':'melee'},
   'forest_skull':{'hp':12,'speed':8,'spawnDuration':.52,'lifetime':16,'reach':3.8,'damage':7,'cooldown':1.5,'hitAt':.45,'deathDuration':2,'kind':'flying'}}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ');p.write_bytes((s[:start]+encoded+s[start+length:]).encode())
print('Forest Spirit configured; HP/rewards retained')
