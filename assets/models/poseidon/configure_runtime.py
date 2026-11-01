"""Authored Poseidon mechanics; preserve HP, loot and respawn."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';text=p.read_text(encoding='utf8')
start=text.index('    "poseidon": {',text.index('"bosses":'))+len('    "poseidon": ')
card,length=json.JSONDecoder().raw_decode(text[start:]);f=card['fight']
f.update(model='poseidon',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=4.8,
 _abilities='[клиент] mso_poseidon names/durations: swing, swing_2, stab, wave_clash, epicenter, swim/torpedo. [вики] lightning and waves. [владелец] no immunity. [решение] original model, motion, geometry, contact times and death; assets/models/poseidon/README.md')
f['poseidon']={'recovery':1.5,'spawnDuration':3.2,
 'melee':[{'name':'swing','duration':1,'release':.48,'damage':12,'radius':9,'halfAngle':65},{'name':'swing_2','duration':1,'release':.51,'damage':12,'radius':9,'halfAngle':65}],
 'wave_clash':{'duration':1.3,'release':.66,'range':26,'speed':24,'width':8,'damage':19},
 'epicenter':{'duration':1.7,'release':1.02,'range':18,'radius':3.5,'damage':19,'phase2Count':2},
 'torpedo':{'duration':2.65,'release':.65,'travelDuration':1,'attackDuration':1,'attackAt':.55,'range':18,'radius':3.5,'damage':24},
 'stab':{'duration':1.3,'release':.68,'radius':11,'halfAngle':25,'damage':19}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((text[:start]+encoded+text[start+length:]).encode());print('Poseidon configured; HP/rewards/respawn unchanged')
