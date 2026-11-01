"""One-time guarded integration, avoiding changes to other authored encounters."""
from pathlib import Path
p=Path(__file__).resolve().parents[3]/'src/server/Services/BossService.luau'
s=p.read_text(encoding='utf8')
assert 'local IllusionistAbilities' not in s
s=s.replace('local PoseidonAbilities = require(script.Parent.PoseidonAbilities)','local PoseidonAbilities = require(script.Parent.PoseidonAbilities)\nlocal IllusionistAbilities = require(script.Parent.IllusionistAbilities)')
s=s.replace('\tposeidon: any?,','\tposeidon: any?,\n\tillusionist: any?,')
s=s.replace('PoseidonAbilities.Clear(boss)','PoseidonAbilities.Clear(boss)\n\tIllusionistAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.poseidon then\n\t\tPoseidonAbilities.Spawn(boss, { act = act })','\telseif boss.fight.poseidon then\n\t\tPoseidonAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.illusionist then\n\t\tIllusionistAbilities.Spawn(boss, { act = act })')
s=s.replace('\t\t\t\t\tthen 7\n','\t\t\t\t\tthen 7\n\t\t\t\t\telseif boss.fight.illusionist then 6\n')
old='\t\telseif boss.fight.poseidon then\n\t\t\tPoseidonAbilities.Cast(boss, boss.nextAbility, target.root.Position, phase2, {\n\t\t\t\tact = act,\n\t\t\t\thurt = hurt,\n\t\t\t\tfighters = fighters,\n\t\t\t\ttelegraph = telegraphPart,\n\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('poseidon','illusionist').replace('PoseidonAbilities','IllusionistAbilities'))
old='\t\t\telseif boss.fight.knight then\n\t\t\t\tKnightAbilities.Melee(boss, target.root.Position, {\n\t\t\t\t\tact = act,\n\t\t\t\t\thurt = hurt,\n\t\t\t\t\tfighters = fighters,\n\t\t\t\t\ttelegraph = telegraphPart,\n\t\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('knight','illusionist').replace('KnightAbilities','IllusionistAbilities'))
p.write_bytes(s.encode())
