# Diamond sword Sharpness III, 2026-11-03

The owner explicitly requested the missing diamond Sharpness III tier. The omission came from data coverage: `wiki/client-audit/content-analysis/other-upgrades-recovery.json` contains fourteen real transitions, ending14→15 (SharpnessII). Its final screenshot `sword-15.png`, visually checked, shows15→15 and repeats the previous13,900 /13.8K rats / ArmorerV requirements. The recovery document explicitly says this does not prove the server's absolute maximum. `build-configs.mjs` faithfully used that partial transition list, so the generated game stopped at15.

Targeted official Cristalix searches did not locate a price or requirements for15→16. The [official announcement](https://forum.cristalix.gg/threads/303993/) describes its in-game /wiki but supplies no sword table; the web wiki domain was unavailable. These search limits are not evidence that the original tier does not exist.

The approved extension is explicitly marked **owner request / design decision**, never recovered Cristalix data:

| Transition | Money | Credited rats | Armorer | Display enchant | Effective power | Full noncritical damage |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
|12→13, recovered|5,600|9,000|—|0|7|11|
|13→14, recovered|7,600|10,900|III|I|8|11.5|
|14→15, recovered|13,900|13,800|V|II|8|11.5|
|15→16, approved extension|20,000|16,700|V|III|9|12|

The new rat threshold repeats the last+2,900 step. The money step is approximately the previous+6,300 increase; Armorer stays at its existing maximumV. All old1–15 transitions and effective powers remain unchanged. The extension lives in `scripts/design-decisions.json.toolUpgradeExtensions`; the generator validates contiguous levels and finite requirements/cost before appending it. The raw recovery JSON remains unchanged, and generated tools/rules were rebuilt rather than hand edited.

Vanilla Java Sharpness is+1 atI, then+0.5 per additional level: vanillaIII alone adds2 damage, so an ordinary Java diamond SharpIII sword deals9 total. This is visible directly in Mojang-authored vanilla [sharpness.json](https://mcasset.cloud/1.21.1/data/minecraft/enchantment/sharpness.json), mirrored by MC Assets (`base:1`, `per_level_above_first:0.5`). Minecraft's [official enchantment reference](https://help.minecraft.net/hc/en-us/articles/360058730912) confirms its damage role. Our pre-existing owner-approved22.10 rule uses a stronger, continuous hidden power curve while displaying material-localI–III; extending it8→9 prevents an unintended11.5→9 damage downgrade. No CombatService or ItemInfo production code changed: both already derive damage from the same Config formula, and the tooltip already derives enchant text from the display tier.

`scripts/qa-sword-tier16-offline.luau` passes45 checks against actual Config, Strings/ItemInfo, unchanged Combat.weapon/Economy.upgrade/Creative.give source closures and actual ProfileService migration with fake stores. It verifies each old effective power, new server damage and all four localized tooltips, max16, diamond icon reuse, exact money/rat/Armorer gates, debit exactly once, max retry, metadata preservation, Creative16/clamping and persisted inventory16. CreativeWindow enumerates the generated upgrade count; there is no sword-specific15 cap in these paths. No live profile, Studio run or purchase was used.
