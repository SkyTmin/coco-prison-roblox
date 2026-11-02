"""Audited spider action names, original mechanics, existing HP/loot preserved."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "spider_queen": {',s.index('"bosses":'))+len('    "spider_queen": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='spider_queen',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=6.25,
 _abilities='[клиент] spider: fangattack1.45, webattack1.85, death6.25, spider_web spawn/despawn.7, hunstman_spider add. [решение] original rig, gait, mechanics/timings; assets/models/spider_queen/README.md. [владелец] no blocks/immunity.')
f['spiderQueen']={'recovery':1.5,'spawnDuration':1.8,
 'melee':[{'name':'bite','duration':1,'release':.5,'damage':16,'radius':8,'halfAngle':65},{'name':'bite_2','duration':1,'release':.53,'damage':16,'radius':8,'halfAngle':65}],
 'fangattack':{'duration':1.45,'release':.83,'damage':32,'radius':10,'halfAngle':50},
 'webattack':{'duration':1.85,'release':1.05,'damage':25,'range':26,'radius':4,'flight':.7,'arc':7,'grow':.7,'fade':.7,'lifetime':6,'phase2Count':2,'maxZones':3,'slowLevel':3,'slowSeconds':.65},
 'broodcall':{'duration':2.6,'release':1.65,'range':9,'count':3,'phase2Count':4,'maxAlive':6,'hp':12,'speed':10,'lifetime':18,'damage':6,'reach':3.8,'cooldown':1.4,'hitAt':.302,'spawnDuration':.7}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((s[:start]+encoded+s[start+length:]).encode());print('Spider Queen configured; HP/rewards retained')
