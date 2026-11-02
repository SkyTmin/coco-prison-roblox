"""Offline artifact/config audit. This does not execute Roblox mechanics or replace Studio QA."""
import ast,hashlib,json,math,subprocess
from pathlib import Path
HERE=Path(__file__).parent;ROOT=HERE.resolve().parents[2];MODELS=ROOT/'src/shared/Models'
def read(p):return json.loads(p.read_text(encoding='utf8'))
stats={};modules=[]
for name in ['raven_knight','crow_reaper','raven','crow_axe']:
 p=MODELS/(name+'.json');d=read(p);modules.append(p)
 for n in d.get('clipFiles',[]):
  p=MODELS/(n+'.json');modules.append(p);chunk=read(p)
  assert not set(d['clips'])&set(chunk['clips']);d['clips'].update(chunk['clips'])
 names={j['name'] for j in d['joints']};seen=set()
 for j in d['joints']:
  assert j['parent'] is None or j['parent'] in seen;seen.add(j['name'])
 for part in d['parts']:
  if isinstance(part,dict):assert not part.get('glow') and part['joint'] in names
  else:assert part[8]==0 and 0<=part[0]<len(names)
 for clip in d['clips'].values():
  assert 0<clip['length']<20
  for joint,track in clip['tracks'].items():
   assert joint in names
   times=[k[0] for k in track];assert times==sorted(times) and times[0]>=0 and times[-1]<=clip['length']+.0001
   for k in track:assert all(math.isfinite(v) for v in k) and abs(sum(v*v for v in k[4:8])-1)<.001
 stats[name]={'parts':len(d['parts']),'joints':len(names),'clips':{n:c['length'] for n,c in d['clips'].items()}}
for p in modules:assert len(p.read_text(encoding='utf8'))<180000
old=json.loads(subprocess.check_output(['git','show','c9ab15e:scripts/design-decisions.json'],cwd=ROOT).decode('utf8'))
now=read(ROOT/'scripts/design-decisions.json')
oldcard=old['bosses'].pop('raven_knight');card=now['bosses'].pop('raven_knight')
assert old==now,'Unrelated decision changed'
oldfight=oldcard.pop('fight');fight=card.pop('fight');assert oldcard==card,'HP/rewards/progression changed'
allowed={'model','texture','glowBrightness','deathDuration','_abilities','ravenKnight'}
assert {k:v for k,v in oldfight.items() if k not in allowed}=={k:v for k,v in fight.items() if k not in allowed},'Unintended fight setting changed'
cfg=fight['ravenKnight'];main=stats['raven_knight']['clips'];ret=stats['crow_reaper']['clips']
assert cfg['melee']['contacts'][1]-cfg['melee']['contacts'][0]>now['combat']['hurtImmunitySeconds']+.05
assert main['death']==fight['deathDuration']==5.2 and main['spawn']==cfg['spawnDuration']
assert main['simplecombo']==main['simplecombo2']==cfg['melee']['duration']
for name in ['fastcombo','comboflyattack','explosion','ravencall']:
 c=cfg[name];assert abs(c['duration']-main[name])<.0001 and 0<c['release']<c['duration']
 assert all(0<t<c['duration'] for t in c.get('contacts',[]))
for name in ['basicattack','chargeattack','fogcombo','summonaxe','spikesattack']:
 c=cfg['retainer'][name];assert abs(c['duration']-ret[name])<.0001 and 0<c['release']<c['duration']
 assert all(0<t<c['duration'] for t in c.get('contacts',[]))
assert cfg['retainer']['cooldown']>cfg['retainer']['lifetime']+cfg['retainer']['deathDuration']
sha=hashlib.sha256((HERE/'noise.png').read_bytes()).hexdigest();assert sha=='c96ee737af82b491e29978f5415e662c98684f38e64dad0804d7bc3799b84d7d'
for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
report={'status':'PASS','scope':'offline geometry/curves/config only; Studio not run','baseline':'c9ab15e',
 'models':stats,'moduleCount':len(modules),'largestModuleCharacters':max(len(p.read_text(encoding='utf8')) for p in modules),
 'noiseSha256':sha,'studioStatus':'PENDING evening QA per owner'}
(HERE/'offline-validation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('PASS: four original rigs, '+str(sum(len(v['clips']) for v in stats.values()))+' clips, '+str(len(modules))+' modules, target-only config; Studio pending')
