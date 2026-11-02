"""Offline artifact/config audit. This does not execute Roblox mechanics or replace Studio QA."""
import ast,hashlib,json,math,subprocess
from pathlib import Path
HERE=Path(__file__).parent;ROOT=HERE.resolve().parents[2];MODELS=ROOT/'src/shared/Models'
def read(p):return json.loads(p.read_text(encoding='utf8'))
stats={};modules=[]
for name in ['ent','ent_minion','ent_branch','ent_leaves']:
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
old=json.loads(subprocess.check_output(['git','show','450a60c:scripts/design-decisions.json'],cwd=ROOT).decode('utf8'))
now=read(ROOT/'scripts/design-decisions.json')
oldcard=old['bosses'].pop('ent');card=now['bosses'].pop('ent')
assert old==now,'Unrelated decision changed'
oldfight=oldcard.pop('fight');fight=card.pop('fight');assert oldcard==card,'HP/rewards/progression changed'
allowed={'model','texture','glowBrightness','deathDuration','_abilities','ent'}
assert {k:v for k,v in oldfight.items() if k not in allowed}=={k:v for k,v in fight.items() if k not in allowed},'Unintended fight setting changed'
cfg=fight['ent'];main=stats['ent']['clips']
assert main['death']==fight['deathDuration']==4.4 and main['spawn']==cfg['spawnDuration']
for name in ['rightpunch','leftpunch','rise','stomp','leafstorm','shout']:
 c=cfg[name];assert abs(c['duration']-main[name])<.0001 and 0<c['release']<c['duration']
assert fight['walkSpeed']/4<=read(MODELS/'ent.json')['walkSpeed']
assert cfg['leafstorm']['release']+(cfg['leafstorm']['pulses']-1)*cfg['leafstorm']['interval']<cfg['leafstorm']['duration']
assert cfg['leafstorm']['interval']>.5 and cfg['shout']['maxAlive']==4
c=cfg['shout']['minion'];clips=stats['ent_minion']['clips']
assert abs(c['spawnDuration']-clips['spawn'])<.0001 and abs(c['deathDuration']-clips['death'])<.0001
assert 0<c['hitAt']<clips['bite']<c['cooldown']
assert c['speed']/4<=read(MODELS/'ent_minion.json')['walkSpeed']
assert len(modules)==len(set(modules)), 'Companion/model-clip filename collision'
for name in stats:
 d=read(MODELS/(name+'.json'))
 for chunk in d.get('clipFiles',[]):assert 'joints' not in read(MODELS/(chunk+'.json'))
 report=read(HERE/('motion-validation.json' if name=='ent' else name+'-validation.json'))
 assert report['maxLocalPositionErrorStuds']<.025 and report['maxLocalRotationErrorDegrees']<.8
 assert report['maxWalkStanceErrorStuds']<.08
 assert all(abs(v)<.08 for v in report['deathBodyFloor'])
 assert all(abs(v)<.08 for limits in report['floorByClip'].values() for v in limits)
 manifest=read(HERE/('render-frames' if name=='ent' else 'render-frames-'+name)/'manifest.json')
 assert set(r['clip']for r in manifest)==set(stats[name]['clips'])
 for r in manifest:assert Path(r['file']).is_file()
sha=hashlib.sha256((HERE/'noise.png').read_bytes()).hexdigest();assert sha=='c96ee737af82b491e29978f5415e662c98684f38e64dad0804d7bc3799b84d7d'
for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
report={'status':'PASS','scope':'offline geometry/curves/config only; Studio not run','baseline':'450a60c',
 'models':stats,'moduleCount':len(modules),'largestModuleCharacters':max(len(p.read_text(encoding='utf8')) for p in modules),
 'noiseSha256':sha,'studioStatus':'PENDING evening QA per owner'}
(HERE/'offline-validation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('PASS: four original rigs, '+str(sum(len(v['clips']) for v in stats.values()))+' clips, '+str(len(modules))+' modules, target-only config; Studio pending')
