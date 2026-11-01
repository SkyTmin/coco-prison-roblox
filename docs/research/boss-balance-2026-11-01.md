# Boss progression and reward audit — 01 November 2026

Owner constraints [владелец]: Quarry's weakest boss 280 HP; strongest final boss 3500 HP; Basement's Splinter in the middle; later bosses dangerous, without a full-health instant kill; last fights intended for **4–6 appropriately equipped players**. Numbers between endpoints, attack damage, combat regeneration and protective limits below are project decisions, not recovered Cristalix server values.

## Current configuration [решение]

Damage columns are raw before armor/books. Area/charge columns are generic family values; bespoke abilities use their own explicit contacts, including Minotaur's two 4-damage blows and Piglin's 5 + 10 spin. Player damage uses the Java rules in the [combat report](java-combat-2026-11-01.md).

| Boss id | HP | Melee | Area | Charge | Active combat regen HP/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| basalt_guardian | 280 | 2 | 4 | 5 | 0 |
| giant_zombie | 340 | 3 | 5 | 6 | 0 |
| minotaur | 430 | 4 | 7 | 9 | 0 |
| piglin | 580 | 6 | 10 | 12 | 0 |
| skeleton | 740 | 8 | 13 | 16 | 0 |
| knight | 920 | 10 | 16 | 20 | 0 |
| poseidon | 1120 | 12 | 19 | 24 | 0 |
| illusionist | 1340 | 14 | 22 | 28 | 0 |
| spider_queen | 1570 | 16 | 25 | 32 | 0 |
| splinter | 1800 | 18 | 28 | 34 | 0 |
| mole | 1820 | 18 | 28 | 35 | 0 |
| un_king | 2070 | 20 | 31 | 38 | 0 |
| forest_spirit | 2320 | 23 | 34 | 42 | 0 |
| raven_knight | 2550 | 26 | 37 | 46 | 4 |
| vecna | 2770 | 29 | 40 | 50 | 6 |
| the_lovers | 2970 | 32 | 43 | 54 | 7 |
| ent | 3160 | 35 | 46 | 58 | 8 |
| forest_guardian | 3340 | 38 | 49 | 61 | 10 |
| reaper | 3500 | 40 | 52 | 64 | 12 |

Splinter is exactly the median of 19 by HP. Main-location progression is strictly increasing in HP and normal/area damage. Boss cards now show actual melee damage; previously many late bosses still dealt 2 despite larger card values. Respawn periods and unlock levels are unchanged.

Late regeneration runs only in an active encounter with fighters and recorded damage, including skill windups. No idle regeneration and no resurrection. This discourages safe solo attrition; it is not a hard player-count gate or a proof that an exceptional fully buffed solo build can never win.

`BossDamage` limits damage from bosses/summons within a rolling 0.75 s to 65% of the victim's maximum health **after armor/books** [decision]. It prevents overlapping attacks from deleting a full-health player, while subsequent attacks can kill an already wounded player. Ordinary hurt immunity also applies. Death/character replacement clears the relevance of old Humanoid state. Camera knockback is unchanged by balance.

## Group model, not a live group playtest

`node scripts/simulate-boss-balance.mjs` assumes a diamond sword with Sharpness VIII (7 + 4.5 damage), 1.6 charged attacks/s, 45% effective attack uptime, no ancient books/potions/professions [decision]. Effective DPS per player is 8.28. Against Reaper's 12 HP/s regeneration, one ordinary attacker does not outheal it; estimated kill times are **166 s for four, 93 s for six**. Dodging, deaths, skill invulnerability, special builds and coordination alter the real result. A real 4–6-player session is still required.

Example level-35 player: 54 HP, full diamond armor with Protection II per piece [existing progression]. Reaper melee 40 becomes 16.32 HP; area 52 becomes 25.4592 HP; charge is limited to 35.1 HP by the burst cap [calculation using actual shared armor formula]. Strong attacks are substantial but do not one-shot a full-health player.

## Rewards: evidence and limits

Sources: [handbook](../../wiki/in-game-wiki/HANDBOOK-WIKI.md), [boss cards](../../wiki/in-game-wiki/BOSS-CARDS.md), [recovered menu](../../wiki/client-audit/BOSS-MENU-RECOVERY.md), `wiki/client-audit/content-analysis/boss-menu-recovery.json`. All money/star ranges and powder labels are checked against the recovered entries by the simulator. Money remains proportional to eligible damage with the existing last-hit rules.

- `BossLoot.Roll` now holds the actual server item roll; minimum qualifying share remains 5% [decision]. Stars use the recovered count range for qualifying participants; this is our rule, not a claim of the older top-three system.
- Splinter's powder was a bare string although the roller expected an object, preventing its roll. It is now normalized to the same 1–5% label shape as other bosses.
- Confirmed composition/last-hit additions: moon steel for Forest Spirit/Ent; fire shard for Lovers/Forest Guardian/Reaper. Forest Guardian and Reaper were missing their fire shard. Count one, guaranteed for the eligible last hitter, is our explicit decision; the retrieved current wiki does not establish exact server probability/count.
- Powder labels such as 1–5% are preserved. **The current recovered data explicitly leaves their interpretation/probability unresolved.** An older season's description is insufficient to prove today's algorithm. Our existing share-linear probability between min/max remains a documented decision; no claim of a verified Cristalix roll formula.
- Public boss result chat remains **participant damage, share and actual dollars only**, including zero-dollar participants. Item rewards are private inventory/toast feedback, never added to the boss chat announcement.

## Validation

Correct Studio place 92594200898716, full source sync, Play: `qa-boss-balance.luau` **103 PASS**, including all 19 bosses, actual armor/cap boundaries, reward eligibility/last-hit restrictions, star endpoints, late items and deterministic 10,000-roll powder sampling. Disposable fixtures only; no real boss killed and no saved profile mutation.

`simulate-boss-balance.mjs` passes endpoint/order/median/card parity/reward-source checks and reports the group estimate. Economy simulator also run through level 50. Model validators for Basalt, Minotaur and Piglin accept the new actual values. Piglin-specific runtime suite: 63 PASS; Java combat suite: 24 PASS. Final static checks and Rojo build are recorded in the progress journal. No game publication.
