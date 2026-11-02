"""Guarded one-time BossService integration; no edits to other encounters."""
from pathlib import Path
p=Path(__file__).resolve().parents[3]/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local MothAbilities' not in s
s=s.replace('local IllusionistAbilities = require(script.Parent.IllusionistAbilities)','local IllusionistAbilities = require(script.Parent.IllusionistAbilities)\nlocal MothAbilities = require(script.Parent.MothAbilities)')
s=s.replace('\tillusionist: any?,','\tillusionist: any?,\n\tmoth: any?,')
s=s.replace('IllusionistAbilities.Clear(boss)','IllusionistAbilities.Clear(boss)\n\tMothAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.illusionist then\n\t\tIllusionistAbilities.Spawn(boss, { act = act })','\telseif boss.fight.illusionist then\n\t\tIllusionistAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.moth then\n\t\tMothAbilities.Spawn(boss, { act = act })')
old='\t\telseif boss.fight.illusionist then\n\t\t\tIllusionistAbilities.Cast(boss, boss.nextAbility, target.root.Position, phase2, {\n\t\t\t\tact = act,\n\t\t\t\thurt = hurt,\n\t\t\t\tfighters = fighters,\n\t\t\t\ttelegraph = telegraphPart,\n\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('illusionist','moth').replace('IllusionistAbilities','MothAbilities'))
old='\t\t\telseif boss.fight.illusionist then\n\t\t\t\tIllusionistAbilities.Melee(boss, target.root.Position, {\n\t\t\t\t\tact = act,\n\t\t\t\t\thurt = hurt,\n\t\t\t\t\tfighters = fighters,\n\t\t\t\t\ttelegraph = telegraphPart,\n\t\t\t\t})'
assert old in s;s=s.replace(old,old+old.replace('illusionist','moth').replace('IllusionistAbilities','MothAbilities'))
s=s.replace('elseif boss.fight.illusionist then 6','elseif boss.fight.illusionist then 6\n\t\t\t\t\telseif boss.fight.moth then 5')
p.write_bytes(s.encode())
