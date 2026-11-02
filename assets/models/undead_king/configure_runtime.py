"""Audited unking action names, original timing; preserve the existing HP and loot tables."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'scripts/design-decisions.json';s=p.read_text(encoding='utf8')
start=s.index('    "un_king": {',s.index('"bosses":'))+len('    "un_king": ')
card,length=json.JSONDecoder().raw_decode(s[start:]);f=card['fight']
f.update(model='undead_king',texture='rbxassetid://93131048217957',glowBrightness=0,deathDuration=3,
 _abilities='[клиент] unking: attack .7, skill1 2.5, skill2 2, skill3 .7, death 3; ghoul/skull/undead_king_sword. [вики] dark missiles, exploding skulls, ghost sword, ghouls and meteors. [решение] original models and readable server mechanics; assets/models/undead_king/README.md. [владелец] no boss blocks, including summon protection.')
f['undeadKing']={'recovery':1.7,'spawnDuration':1.8,
 'melee':[{'name':n,'duration':d,'release':t,'damage':20,'radius':8,'halfAngle':65}for n,d,t in [('attack',.7,.35),('attack2',.75,.38)]],
 'skill3':{'duration':.7,'release':.36,'damage':31,'range':34,'speed':22,'radius':1.1,'count':1,'phase2Count':3,'spread':12},
 'skill2':{'duration':2,'release':1.05,'damage':31,'range':7,'radius':4.5,'count':2,'phase2Count':3,'maxAlive':4,'hp':8,'speed':7,'lifetime':8,'trigger':4,'fuse':.9},
 'swordcall':{'duration':2,'release':1.15,'damage':38,'range':27,'radius':4.5,'count':1,'phase2Count':2,'impactAt':4,'lifetime':8,'clearance':12.5},
 'skill1':{'duration':2.5,'release':1.57,'damage':38,'range':26,'radius':3.8,'height':12,'flight':.75,'count':2,'phase2Count':3,
  'ghoul':{'count':3,'phase2Count':4,'maxAlive':4,'range':6,'hp':20,'speed':11,'spawnDuration':.7,'lifetime':18,'reach':4,'damage':7,'cooldown':1.5,'hitAt':.25}}}
encoded=json.dumps(card,ensure_ascii=False,indent=2).replace('\n','\n    ')
p.write_bytes((s[:start]+encoded+s[start+length:]).encode());print('Undead King configured; HP and loot retained')
