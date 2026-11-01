"""Idempotently apply the skeleton's authored combat decisions, preserving other configuration text."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';text=p.read_text(encoding='utf8')
start=text.index('    "skeleton": {',text.index('"bosses":'))+len('    "skeleton": ')
card,length=json.JSONDecoder().raw_decode(text[start:]);f=card['fight']
f.update(model='skeleton_king',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=5.008,
 meleeDuration=1.25,meleeHitAt=.58,
 _abilities='[клиент] atkrswipe/atklswipe, sklrstomp/skllstomp, sklpoisonbreath, sklroar; исходные имена/длительности. [сеть] автор amonde: ловушки, яд с отталкиванием, скелеты. [решение] собственные движения, времена контакта, геометрия, количества и урон; assets/models/skeleton_king/README.md')
f['skeleton']={'recovery':1.5,
 'atkrswipe':{'duration':1.25,'release':.58,'damage':8,'radius':8,'halfAngle':70},
 'atklswipe':{'duration':1.25,'release':.58,'damage':8,'radius':8,'halfAngle':70},
 'sklrstomp':{'duration':2,'release':.9,'range':16,'radius':3.1,'lifetime':2.5,'ticks':3,'tickInterval':.65,'damage':13,'snareSeconds':.45,'phase2Count':3},
 'skllstomp':{'duration':2,'release':.9,'range':16,'radius':3.1,'lifetime':2.5,'ticks':3,'tickInterval':.65,'damage':13,'snareSeconds':.45,'phase2Count':3},
 'sklpoisonbreath':{'duration':3.5088,'release':1.45,'range':18,'radius':4.5,'lifetime':5,'ticks':6,'tickInterval':.8,'damage':16},
 'sklroar':{'duration':5,'release':2.4,'range':10,'count':2,'phase2Count':3,'maxAlive':4,'hp':22,'damage':4,'speed':5.8,'reach':4.3,'cooldown':1.8,'hitAt':.464,'spawnDuration':3,'lifetime':18}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((text[:start]+encoded+text[start+length:]).encode('utf8'))
print('Skeleton configuration applied; HP/rewards/respawn unchanged')
