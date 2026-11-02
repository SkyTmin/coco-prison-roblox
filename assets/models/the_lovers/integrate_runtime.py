"""Guarded one-time dispatcher integration; no Studio calls."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local LoversAbilities' not in s
s=s.replace('local VecnaAbilities = require(script.Parent.VecnaAbilities)','local VecnaAbilities = require(script.Parent.VecnaAbilities)\nlocal LoversAbilities = require(script.Parent.LoversAbilities)')
s=s.replace('\tvecna: any?,','\tvecna: any?,\n\tlovers: any?,')
# Two unconditional cleanup sites; the Samurai also gets its own leash condition.
for indent in ['\t','\t\t']:
 old=indent+'VecnaAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)'
 assert old in s;s=s.replace(old,indent+'VecnaAbilities.Clear(boss)\n'+indent+'LoversAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.vecna then\n\t\tVecnaAbilities.Spawn(boss, { act = act })','\telseif boss.fight.vecna then\n\t\tVecnaAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.lovers then\n\t\tLoversAbilities.Spawn(boss, { act = act })')
for indent,kind,args in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent;old=t+'elseif boss.fight.vecna then\n'+t+'\tVecnaAbilities.'+kind+'('+args+', {\n'+''.join(t+'\t\t'+k+' = '+v+',\n'for k,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('vecna','lovers').replace('VecnaAbilities','LoversAbilities'))
old='% (if boss.fight.piglin';assert old in s
s=s.replace(old,'% (if boss.fight.lovers then 9\n\t\t\t\t\telseif boss.fight.piglin')
old='\t\tif boss.fight.vecna and os.clock() - boss.lastTargetAt > boss.fight.leashSeconds then\n\t\t\tVecnaAbilities.Clear(boss)\n\t\tend'
assert old in s;s=s.replace(old,old+'\n'+old.replace('vecna','lovers').replace('VecnaAbilities','LoversAbilities'))
p.write_bytes(s.encode())
