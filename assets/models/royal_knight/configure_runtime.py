"""Patch only this boss's decisions; never reformat the full configuration."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';text=p.read_text(encoding='utf8')
start=text.index('    "knight": {',text.index('"bosses":'))+len('    "knight": ')
card,length=json.JSONDecoder().raw_decode(text[start:]);f=card['fight']
f.update(model='royal_knight',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=3.85,
 _abilities='[клиент] knight: audited names/durations in RESOURCEPACK-BOSSES. [владелец 02.11] no blocks or immunity. [решение] original model, motion, contact times, geometry, numbers: assets/models/royal_knight/README.md')
f['knight']={'recovery':1.4,'spawnDuration':1.5,
 'melee':[{'name':n,'duration':d,'release':r,'damage':10,'radius':8,'halfAngle':a} for n,d,r,a in [('c1',.65,.3,65),('c2',.65,.31,65),('c3',.65,.33,28),('c4',.95,.5,45),('c5',1,.56,60)]],
 'berserkerleap':{'duration':2,'release':1.35,'moveAt':.57,'range':14,'radius':4.5,'damage':20},
 'strikeoffury1':{'duration':2.9,'release':1.1,'contacts':[1.1,2],'damage':16,'radius':9,'halfAngle':65},
 'strikeoffury2':{'duration':2.75,'release':1.3,'contacts':[1.3,2],'damage':16,'radius':9,'halfAngle':60},
 'relentlesswhirlwindspin':{'duration':2.5,'release':.8,'contacts':[.8,1.4,2],'damage':12,'radius':8.5,'halfAngle':180,'pierceDuration':.6977,'pierceAt':.32,'pierceDamage':8},
 'bloodboundbarrier':{'duration':2.3,'release':1.33,'guardDuration':.8,'bashDuration':1.5,'damage':10,'radius':7,'halfAngle':55},
 'dash':{'duration':.65,'backDuration':.8,'moveAt':.18,'moveEnd':.46,'range':7,'flinchDuration':2.5},
 'viciousstrike':{'duration':4.75,'release':2.85,'range':15,'radius':5,'damage':20}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((text[:start]+encoded+text[start+length:]).encode())
print('Knight decisions applied; HP/rewards/respawn unchanged')
