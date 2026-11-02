"""Target-only authored mechanics; preserve existing HP, payouts and wiki loot."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "raven_knight": {',s.index('"bosses":'))+len('    "raven_knight": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='raven_knight',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=5.2,
 _abilities='[клиент] raven knight simplecombo1/2, fastcombo, comboflyattack, explosion; crow reaper basic/charge/fog/axe/spikes. [решение] original choreography, raven volley and phase-two killable retainer; no source-confirmed transformation. assets/models/raven_knight/README.md. Studio QA pending. [владелец] no boss blocks.')
f['ravenKnight']={'spawnDuration':2.2,'recovery':1.8,
 'melee':{'duration':1.9,'contacts':[.8,1.4],'damage':26,'radius':8,'halfAngle':65},
 'fastcombo':{'duration':4.35,'release':1.2,'contacts':[1.2,1.9,2.6,3.3],'damage':37,'radius':9,'halfAngle':70},
 'comboflyattack':{'duration':4.25,'moveAt':1.4,'release':2.5,'damage':37,'range':21,'radius':5.5},
 'explosion':{'duration':6,'release':3,'damage':46,'radius':12},
 'ravencall':{'duration':3.2,'release':1.6,'damage':37,'range':35,'speed':22,'radius':.85,'count':3,'phase2Count':5,'spread':10,'maxAlive':5},
 'retainer':{'hp':160,'speed':11,'spawnDuration':2.2,'lifetime':42,'deathDuration':5.2,'cooldown':60,'castRange':30,'recovery':1.4,
  'basicattack':{'duration':1.75,'release':.9,'contacts':[.9],'damage':14,'radius':7,'halfAngle':65},
  'chargeattack':{'duration':2.55,'moveAt':.9,'release':1.45,'damage':18,'range':13,'radius':4.5},
  'fogcombo':{'duration':3,'release':1,'contacts':[1,1.9],'damage':20,'radius':8,'halfAngle':75},
  'summonaxe':{'duration':2.04167,'release':1.1,'damage':18,'range':30,'speed':19,'radius':1},
  'spikesattack':{'duration':2.75,'release':1.6,'damage':18,'range':30,'radius':2.8}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ');p.write_bytes((s[:start]+encoded+s[start+length:]).encode())
print('Raven Knight configured; HP/rewards retained')
