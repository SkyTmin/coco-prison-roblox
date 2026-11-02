"""One-time guarded integration; untouched encounter dispatch remains as-is."""
from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'src/server/Services/BossService.luau';s=p.read_text(encoding='utf8')
assert 'local UndeadKingAbilities' not in s
s=s.replace('local MothAbilities = require(script.Parent.MothAbilities)','local MothAbilities = require(script.Parent.MothAbilities)\nlocal UndeadKingAbilities = require(script.Parent.UndeadKingAbilities)')
s=s.replace('\tmoth: any?,','\tmoth: any?,\n\tundeadKing: any?,')
s=s.replace('MothAbilities.Clear(boss)','MothAbilities.Clear(boss)\n\tUndeadKingAbilities.Clear(boss)')
s=s.replace('\telseif boss.fight.moth then\n\t\tMothAbilities.Spawn(boss, { act = act })','\telseif boss.fight.moth then\n\t\tMothAbilities.Spawn(boss, { act = act })\n\telseif boss.fight.undeadKing then\n\t\tUndeadKingAbilities.Spawn(boss, { act = act })')
for indent,kind,arguments in [(2,'Cast','boss, boss.nextAbility, target.root.Position, phase2'),(3,'Melee','boss, target.root.Position')]:
 t='\t'*indent
 old=t+'elseif boss.fight.moth then\n'+t+'\tMothAbilities.'+kind+'('+arguments+', {\n'+''.join(t+'\t\t'+s+' = '+v+',\n'for s,v in [('act','act'),('hurt','hurt'),('fighters','fighters'),('telegraph','telegraphPart')])+t+'\t})'
 assert old in s;s=s.replace(old,old+old.replace('moth','undeadKing').replace('MothAbilities','UndeadKingAbilities'))
s=s.replace('or boss.fight.poseidon\n','or boss.fight.poseidon\n\t\t\t\t\t\tor boss.fight.undeadKing\n')
p.write_bytes(s.encode())
p=root/'src/client/BossAnimator.luau';s=p.read_text(encoding='utf8')
old='\tfor _, model in ipairs(CollectionService:GetTagged("Boss")) do\n\t\ttrack(model)\n\tend\n\tCollectionService:GetInstanceAddedSignal("Boss"):Connect(track)'
assert old in s
s=s.replace(old,'\t-- Authored encounter props animate through the same clips without becoming combat targets.\n\tfor _, tag in { "Boss", "BossProp" } do\n\t\tfor _, model in ipairs(CollectionService:GetTagged(tag)) do\n\t\t\ttrack(model)\n\t\tend\n\t\tCollectionService:GetInstanceAddedSignal(tag):Connect(track)\n\tend')
p.write_bytes(s.encode())
