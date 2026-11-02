"""Guarded one-time boss dispatcher integration; no Studio changes."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local RavenKnightAbilities' not in s
s=s.replace('local ForestSpiritAbilities = require(script.Parent.ForestSpiritAbilities)','local ForestSpiritAbilities = require(script.Parent.ForestSpiritAbilities)\nlocal RavenKnightAbilities = require(script.Parent.RavenKnightAbilities)')
s=s.replace('\tforestSpirit: any?,','\tforestSpirit: any?,\n\travenKnight: any?,')
s=s.replace('ForestSpiritAbilities.Clear(boss)','ForestSpiritAbilities.Clear(boss)\n\tRavenKnightAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.forestSpirit then\n\t\tForestSpiritAbilities.Spawn(boss, { act = act })','\telseif boss.fight.forestSpirit then\n\t\tForestSpiritAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.ravenKnight then\n\t\tRavenKnightAbilities.Spawn(boss, { act = act })')
for indent,kind,args in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent;old=t+'elseif boss.fight.forestSpirit then\n'+t+'\tForestSpiritAbilities.'+kind+'('+args+', {\n'+''.join(t+'\t\t'+k+' = '+v+',\n'for k,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('forestSpirit','ravenKnight').replace('ForestSpiritAbilities','RavenKnightAbilities'))
s=s.replace('or boss.fight.undeadKing\n','or boss.fight.undeadKing\n\t\t\t\t\t\tor boss.fight.ravenKnight\n')
s=s.replace('\tif #list == 0 then\n\t\tif boss.model', '\tif #list == 0 then\n\t\tif boss.fight.ravenKnight and os.clock() - boss.lastTargetAt > boss.fight.leashSeconds then\n\t\t\tRavenKnightAbilities.Clear(boss)\n\t\tend\n\t\tif boss.model')
p.write_bytes(s.encode())
