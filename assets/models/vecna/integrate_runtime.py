"""Guarded one-time dispatcher integration; no Studio calls."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local VecnaAbilities' not in s
s=s.replace('local RavenKnightAbilities = require(script.Parent.RavenKnightAbilities)','local RavenKnightAbilities = require(script.Parent.RavenKnightAbilities)\nlocal VecnaAbilities = require(script.Parent.VecnaAbilities)')
s=s.replace('\travenKnight: any?,','\travenKnight: any?,\n\tvecna: any?,')
# Two unconditional cleanup sites; the Raven-only leash branch gets a separate Vecna condition.
for indent in ['\t','\t\t']:
 old=indent+'RavenKnightAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)'
 assert old in s;s=s.replace(old,indent+'RavenKnightAbilities.Clear(boss)\n'+indent+'VecnaAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.ravenKnight then\n\t\tRavenKnightAbilities.Spawn(boss, { act = act })','\telseif boss.fight.ravenKnight then\n\t\tRavenKnightAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.vecna then\n\t\tVecnaAbilities.Spawn(boss, { act = act })')
for indent,kind,args in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent;old=t+'elseif boss.fight.ravenKnight then\n'+t+'\tRavenKnightAbilities.'+kind+'('+args+', {\n'+''.join(t+'\t\t'+k+' = '+v+',\n'for k,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('ravenKnight','vecna').replace('RavenKnightAbilities','VecnaAbilities'))
s=s.replace('or boss.fight.ravenKnight\n','or boss.fight.ravenKnight\n\t\t\t\t\t\tor boss.fight.vecna\n')
old='\t\tif boss.fight.ravenKnight and os.clock() - boss.lastTargetAt > boss.fight.leashSeconds then\n\t\t\tRavenKnightAbilities.Clear(boss)\n\t\tend'
assert old in s;s=s.replace(old,old+'\n'+old.replace('ravenKnight','vecna').replace('RavenKnightAbilities','VecnaAbilities'))
p.write_bytes(s.encode())
