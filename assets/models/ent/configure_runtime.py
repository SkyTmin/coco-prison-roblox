"""Target-only Ent encounter settings; existing HP/rewards/balance remain."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
a=s.index('    "ent": {',s.index('"bosses":'))+len('    "ent": ')
card,length=json.JSONDecoder().raw_decode(s[a:]);f=card['fight']
f.update(model='ent',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=4.4,
 _abilities='[client/wiki/primary] Ent King: two punches, Twisted Branch, Branch Wave, Leaf Storm, Tree Minions. [decision] original rooted oak rig, vulnerable interruptible leaf storm and capped mortal summons. Original timings/counterplay; no shield. assets/models/ent/README.md; Studio pending evening.')
f['ent']={'spawnDuration':2.4,'recovery':1.8,
 'rightpunch':{'duration':1.5292,'release':.92,'damage':35,'radius':8,'halfAngle':70},
 'leftpunch':{'duration':1.5358,'release':.96,'damage':35,'radius':8,'halfAngle':70},
 'rise':{'duration':2.4173,'release':1.5,'rootHitAt':.4333,'damage':46,'radius':3.1,'range':26,'count':3,'phase2Count':5,'spacing':4.2},
 'stomp':{'duration':2.2931,'release':1.35,'rootHitAt':.4333,'damage':46,'radius':2.5,'range':24,'spacing':4,'speed':12},
 'leafstorm':{'duration':5.2,'release':2.1,'damage':58,'radius':17,'innerRadius':4,'safeHalfAngle':35,'jumpHeight':4.3,'pulses':3,'interval':1.1,'interruptDamage':140},
 'shout':{'duration':1.9355,'release':1.15,'count':2,'phase2Count':3,'stagger':.15,'maxAlive':4,
  'minion':{'hp':60,'damage':12,'speed':8,'width':1.4,'depth':1.1,'lift':1.7,'reach':4.1,'hitAt':.65,'cooldown':1.7,'spawnDuration':1.8333,'deathDuration':2.2917,'lifetime':24}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ');p.write_bytes((s[:a]+encoded+s[a+length:]).encode('utf8'))
print('Ent configured; existing HP/rewards retained')
