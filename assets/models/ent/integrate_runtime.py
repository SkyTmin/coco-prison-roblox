"""Guarded one-time dispatcher integration; no Studio calls."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local EntAbilities' not in s
s=s.replace('local LoversAbilities = require(script.Parent.LoversAbilities)','local LoversAbilities = require(script.Parent.LoversAbilities)\nlocal EntAbilities = require(script.Parent.EntAbilities)')
s=s.replace('\tlovers: any?,','\tlovers: any?,\n\tent: any?,')
# Two unconditional cleanup sites; the Ent also gets its own leash condition.
for indent in ['\t','\t\t']:
 old=indent+'LoversAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)'
 assert old in s;s=s.replace(old,indent+'LoversAbilities.Clear(boss)\n'+indent+'EntAbilities.Clear(boss)\n'+indent+'SpiderQueenAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.lovers then\n\t\tLoversAbilities.Spawn(boss, { act = act })','\telseif boss.fight.lovers then\n\t\tLoversAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.ent then\n\t\tEntAbilities.Spawn(boss, { act = act })')
for indent,kind,args in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent;old=t+'elseif boss.fight.lovers then\n'+t+'\tLoversAbilities.'+kind+'('+args+', {\n'+''.join(t+'\t\t'+k+' = '+v+',\n'for k,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('lovers','ent').replace('LoversAbilities','EntAbilities'))
s=s.replace('or boss.fight.vecna\n','or boss.fight.vecna\n\t\t\t\t\t\tor boss.fight.ent\n')
old='\t\tif boss.fight.lovers and os.clock() - boss.lastTargetAt > boss.fight.leashSeconds then\n\t\t\tLoversAbilities.Clear(boss)\n\t\tend'
assert old in s;s=s.replace(old,old+'\n'+old.replace('lovers','ent').replace('LoversAbilities','EntAbilities'))
p.write_bytes(s.encode())
