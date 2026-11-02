"""Offline artifact/config audit. This does not execute Roblox mechanics or replace Studio QA."""
import ast,hashlib,json,math,subprocess
from pathlib import Path
HERE=Path(__file__).parent;ROOT=HERE.resolve().parents[2];MODELS=ROOT/'src/shared/Models'
def read(p):return json.loads(p.read_text(encoding='utf8'))
stats={};modules=[]
for name in ['the_lovers','lover_spirit','lover_arrow','lover_spear','lover_star','lover_sickle']:
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
old=json.loads(subprocess.check_output(['git','show','95e3852:scripts/design-decisions.json'],cwd=ROOT).decode('utf8'))
now=read(ROOT/'scripts/design-decisions.json')
oldcard=old['bosses'].pop('the_lovers');card=now['bosses'].pop('the_lovers')
assert old==now,'Unrelated decision changed'
oldfight=oldcard.pop('fight');fight=card.pop('fight');assert oldcard==card,'HP/rewards/progression changed'
allowed={'model','texture','glowBrightness','deathDuration','_abilities','lovers'}
assert {k:v for k,v in oldfight.items() if k not in allowed}=={k:v for k,v in fight.items() if k not in allowed},'Unintended fight setting changed'
cfg=fight['lovers'];main=stats['the_lovers']['clips']
assert main['death']==fight['deathDuration']==5.2 and main['spawn']==cfg['spawnDuration']
for name in ['drawcut','reversecut','triplecut','sweep','thrust','dashcut','skycut','stars','sickle','spears','arrowcall']:
 c=cfg[name];assert abs(c['duration']-main[name])<.0001 and 0<c['release']<c['duration']
 if 'contacts' in c:assert all(b-a>.5 for a,b in zip(c['contacts'],c['contacts'][1:]))
 if 'moveAt' in c:assert c['moveAt']<c['release']
assert cfg['phase3At']==.25 and fight['phase2At']==.5
assert main['phase2']==cfg['phase2Duration'] and main['phase3']==cfg['phase3Duration']
assert fight['walkSpeed']/4<=read(MODELS/'the_lovers.json')['runSpeed']
spirit=cfg['spirit'];clips=stats['lover_spirit']['clips']
assert spirit['spawnDuration']==clips['spawn'] and spirit['deathDuration']==clips['death']
assert spirit['speed']/4<=read(MODELS/'lover_spirit.json')['walkSpeed']
for name in ['bowshot','fan','rain','spear']:
 c=spirit[name];assert abs(c['duration']-clips[name])<.0001 and 0<c['release']<c['duration']
# Existing detached props have no child joints: subtree grounding is identical for them.
leaf_regression=[]
for folder,name in [('raven_knight','raven_knight'),('raven_knight','crow_reaper'),('royal_knight','royal_knight'),('piglin_king','piglin_king'),('forest_spirit','forest_spirit'),('illusionist','illusionist'),('poseidon','poseidon'),('undead_king','undead_king')]:
 tree=ast.parse((ROOT/'assets/models'/folder/(name+'.py')).read_text(encoding='utf8'))
 expr=next(n.value for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name)and t.id=='GROUND_DETACHED'for t in n.targets))
 detached=ast.literal_eval(expr);d=read(MODELS/(name+'.json'))
 for groups in detached.values():
  for joint in groups:assert not any(j['parent']==joint for j in d['joints']), (name,joint)
 leaf_regression.append(name)
ast.parse((ROOT/'assets/models/blockmob.py').read_text(encoding='utf8'))
assert len(modules)==len(set(modules)), 'Companion/model-clip filename collision'
for name in stats:
 d=read(MODELS/(name+'.json'))
 for chunk in d.get('clipFiles',[]):assert 'joints' not in read(MODELS/(chunk+'.json'))
 report=read(HERE/('motion-validation.json' if name=='the_lovers' else name+'-validation.json'))
 assert report['maxLocalPositionErrorStuds']<.025 and report['maxLocalRotationErrorDegrees']<.8
 assert report['maxWalkStanceErrorStuds']<.08
 assert all(abs(v)<.08 for v in report['deathBodyFloor'])
 assert all(abs(v)<.08 for limits in report['floorByClip'].values() for v in limits)
 manifest=read(HERE/('render-frames' if name=='the_lovers' else 'render-frames-'+name)/'manifest.json')
 assert set(r['clip']for r in manifest)==set(stats[name]['clips'])
 for r in manifest:assert Path(r['file']).is_file()
sha=hashlib.sha256((HERE/'noise.png').read_bytes()).hexdigest();assert sha=='c96ee737af82b491e29978f5415e662c98684f38e64dad0804d7bc3799b84d7d'
for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
report={'status':'PASS','scope':'offline geometry/curves/config only; Studio not run','baseline':'95e3852',
 'existingDetachedLeafRigs':leaf_regression,'models':stats,'moduleCount':len(modules),'largestModuleCharacters':max(len(p.read_text(encoding='utf8')) for p in modules),
 'noiseSha256':sha,'studioStatus':'PENDING evening QA per owner'}
(HERE/'offline-validation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print('PASS: six original rigs, '+str(sum(len(v['clips']) for v in stats.values()))+' clips, '+str(len(modules))+' modules, target-only config; Studio pending')
