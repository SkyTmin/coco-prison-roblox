"""Guarded one-time Forest Spirit dispatcher integration."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local ForestSpiritAbilities' not in s
s=s.replace('local UndeadKingAbilities = require(script.Parent.UndeadKingAbilities)','local UndeadKingAbilities = require(script.Parent.UndeadKingAbilities)\nlocal ForestSpiritAbilities = require(script.Parent.ForestSpiritAbilities)')
s=s.replace('\tundeadKing: any?,','\tundeadKing: any?,\n\tforestSpirit: any?,')
s=s.replace('UndeadKingAbilities.Clear(boss)','UndeadKingAbilities.Clear(boss)\n\tForestSpiritAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.undeadKing then\n\t\tUndeadKingAbilities.Spawn(boss, { act = act })','\telseif boss.fight.undeadKing then\n\t\tUndeadKingAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.forestSpirit then\n\t\tForestSpiritAbilities.Spawn(boss, { act = act })')
for indent,kind,args in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent;old=t+'elseif boss.fight.undeadKing then\n'+t+'\tUndeadKingAbilities.'+kind+'('+args+', {\n'+''.join(t+'\t\t'+k+' = '+v+',\n'for k,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('undeadKing','forestSpirit').replace('UndeadKingAbilities','ForestSpiritAbilities'))
s=s.replace('if boss.fight.piglin or boss.fight.knight','if boss.fight.piglin or boss.fight.knight or boss.fight.forestSpirit')
p.write_bytes(s.encode())
