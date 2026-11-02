"""Guarded one-time BossService integration; no edits to other encounters."""
from pathlib import Path
p=Path(__file__).resolve().parents[3]/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local SpiderQueenAbilities' not in s
s=s.replace('local IllusionistAbilities = require(script.Parent.IllusionistAbilities)','local IllusionistAbilities = require(script.Parent.IllusionistAbilities)\nlocal SpiderQueenAbilities = require(script.Parent.SpiderQueenAbilities)')
s=s.replace('\tillusionist: any?,','\tillusionist: any?,\n\tspiderQueen: any?,')
s=s.replace('IllusionistAbilities.Clear(boss)','IllusionistAbilities.Clear(boss)\n\tSpiderQueenAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.illusionist then\n\t\tIllusionistAbilities.Spawn(boss, { act = act })','\telseif boss.fight.illusionist then\n\t\tIllusionistAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.spiderQueen then\n\t\tSpiderQueenAbilities.Spawn(boss, { act = act })')
old='\t\telseif boss.fight.illusionist then\n\t\t\tIllusionistAbilities.Cast(boss, boss.nextAbility, target.root.Position, phase2, {\n\t\t\t\tact = act,\n\t\t\t\thurt = hurt,\n\t\t\t\tfighters = fighters,\n\t\t\t\ttelegraph = telegraphPart,\n\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('illusionist','spiderQueen').replace('IllusionistAbilities','SpiderQueenAbilities'))
old='\t\t\telseif boss.fight.illusionist then\n\t\t\t\tIllusionistAbilities.Melee(boss, target.root.Position, {\n\t\t\t\t\tact = act,\n\t\t\t\t\thurt = hurt,\n\t\t\t\t\tfighters = fighters,\n\t\t\t\t\ttelegraph = telegraphPart,\n\t\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('illusionist','spiderQueen').replace('IllusionistAbilities','SpiderQueenAbilities'))
p.write_bytes(s.encode())
