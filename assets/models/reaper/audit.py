"""Offline artifact/config audit. This does not execute Roblox mechanics or replace Studio QA."""
import ast,hashlib,json,math,subprocess
from pathlib import Path
HERE=Path(__file__).parent;ROOT=HERE.resolve().parents[2];MODELS=ROOT/'src/shared/Models'
def read(p):return json.loads(p.read_text(encoding='utf8'))
stats={};modules=[]
for name in ['reaper','reaper_circle','reaper_soul']:
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
old=json.loads(subprocess.check_output(['git','show','d51e07c:scripts/design-decisions.json'],cwd=ROOT).decode('utf8'))
now=read(ROOT/'scripts/design-decisions.json')
oldcard=old['bosses'].pop('reaper');card=now['bosses'].pop('reaper')
assert old==now,'Unrelated decision changed'
oldfight=oldcard.pop('fight');fight=card.pop('fight');assert oldcard==card,'HP/rewards/progression changed'
allowed={'model','texture','glowBrightness','deathDuration','_abilities','reaper'}
assert {k:v for k,v in oldfight.items() if k not in allowed}=={k:v for k,v in fight.items() if k not in allowed},'Unintended fight setting changed'
cfg=fight['reaper'];main=stats['reaper']['clips']
assert main['death']==fight['deathDuration']==4.28 and main['spawn']==cfg['spawnDuration']
for name in ['attack1','attack2','circleattack','groundattack','soul1','explosion']:
 c=cfg[name];assert abs(c['duration']-main[name])<.0001 and 0<c['release']<c['duration']
assert fight['walkSpeed']/4<=read(MODELS/'reaper.json')['walkSpeed']
assert cfg['soul1']['release']+(cfg['soul1']['phase2Count']-1)*cfg['soul1']['interval']<cfg['soul1']['duration']
assert cfg['soul1']['interval']>.5 and cfg['soul1']['phase2Count']==5
assert cfg['groundattack']['release']+(cfg['groundattack']['range']/cfg['groundattack']['spacing']-1)*cfg['groundattack']['interval']<cfg['groundattack']['duration']
c=cfg['teleport']
assert abs(c['intoDuration']-main['teleportinto'])<.0001 and abs(c['outDuration']-main['teleportout'])<.0001
assert abs(c['duration']-c['intoDuration']-c['outDuration'])<.0001
assert all(abs(v)<.08 for v in read(HERE/'motion-validation.json')['detachedWeaponFloor'])
assert len(modules)==len(set(modules)), 'Companion/model-clip filename collision'
for name in stats:
 d=read(MODELS/(name+'.json'))
 for chunk in d.get('clipFiles',[]):assert 'joints' not in read(MODELS/(chunk+'.json'))
 report=read(HERE/('motion-validation.json' if name=='reaper' else name+'-validation.json'))
 assert report['maxLocalPositionErrorStuds']<.025 and report['maxLocalRotationErrorDegrees']<.8
 assert report['maxWalkStanceErrorStuds']<.08
 assert all(abs(v)<.08 for v in report['deathBodyFloor'])
 assert all(abs(v)<.08 for limits in report['floorByClip'].values() for v in limits)
 manifest=read(HERE/('render-frames' if name=='reaper' else 'render-frames-'+name)/'manifest.json')
 assert set(r['clip']for r in manifest)==set(stats[name]['clips'])
 for r in manifest:assert Path(r['file']).is_file()
unchanged=read(HERE/'unchanged-clips-validation.json');assert unchanged['status']=='PASS'
for name,digest in unchanged['modules'].items():assert hashlib.sha256((MODELS/name).read_bytes()).hexdigest()==digest
sha=hashlib.sha256((HERE/'noise.png').read_bytes()).hexdigest();assert sha=='c96ee737af82b491e29978f5415e662c98684f38e64dad0804d7bc3799b84d7d'
for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
report={'status':'PASS','scope':'offline geometry/curves/config only; Studio not run','baseline':'d51e07c',
 'models':stats,'moduleCount':len(modules),'largestModuleCharacters':max(len(p.read_text(encoding='utf8')) for p in modules),
 'noiseSha256':sha,'studioStatus':'PENDING evening QA per owner'}
(HERE/'offline-validation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('PASS: three original rigs, '+str(sum(len(v['clips']) for v in stats.values()))+' clips, '+str(len(modules))+' modules, target-only config; Studio pending')
