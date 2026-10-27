# Books and spawn cases: wiki vs ours (audit 2026-10-28)

Read-only audit. Abbreviations: **BS** = `wiki/client-audit/BOOKS-SYSTEM.md`, **HB** = `wiki/in-game-wiki/HANDBOOK-WIKI.md`,
**LOC** = `wiki/client-audit/decoded/ru_RU-classic.json`, **DD** = `scripts/design-decisions.json`,
**JCS** = `wiki/in-game-wiki/JOBS-CASES-SPAWN.md`, **CAFB** = `wiki/in-game-wiki/CASES-ARTIFACTS-FACTIONS-BOOSTERS.md`,
**WR** = `wiki/web-research/C-books-needs-social.md`.

## 1. Books (ancient enchantments)

### 1.1 Catalogue: every book the wiki knows (38 names in client, 31 seen in current season, 32 cards in /wiki)

"Ours" = id in `DD books.catalog` (DD:2456) + `books.effects` (DD:2409) + Strings `book_<id>`/`book_desc_<id>`
(Strings.luau:2464–2553, all 4 locales) → generated `src/shared/Config/books.json`. "—" = missing everywhere
(no catalog, no effect numbers, no strings). **No book effect is implemented in server logic**: grep of `src/server`
for every effect id (trader, archaeologist, hammer, toxic, berserk, tank, springs, vampirism, enlightened, silk_touch)
finds only CaseService/CreativeService (creating the book), never Dig/Combat/Hurt/Bow/Needs (also PROGRESS.md:321).

Wiki source per row: BS line (screenshot card), LOC line (client name key). Levels from BS; HB:259–292 differs where noted.

**Common (13 + 1 probable)**

| Client id | Name (ru) | Lv | Items | Effect (wiki) | Ours | BS / LOC |
|---|---|---|---|---|---|---|
| neat | Чистюля | I–II (HB:273 says I–III) | helmet | needs (toilet, shower, sleep) come slower | — | 46 / 652 |
| baryga | Барыга | I–III | pickaxe, axe, shovel, shears | chance of a duplicate block, works with autosell | `trader` 5/10/15 % [решение] | 47 / 654 |
| toxic | Токсичный | I–III | sword | chance to poison on hit | `toxic` 10/20/30 %, poison 3 s | 48 / 598 |
| fired | Раскалённый | I–III | leggings | when hit: chance to set attacker on fire | — | 49 / 602 |
| frost | Мороз | I–III | bow | arrow hit slows target briefly (Prison Quick 2022: −6 %/stage, 5/6/7 s, max 3/6/9 stages, WR:42) | — | 50 / 612 |
| springs | Пружины | I–III | boots | permanent jump boost | `springs` +1/+2/+3 blocks | 51 / 618 |
| thor | Громовержец | I–III | sword, bow | chance of lightning on target | — | 52 / 620 |
| boxer | Боксёр | I–III | sword, bow | chance of big extra damage + knock-up | — | 53 / 622 |
| confusion | Замешательство | I–III | sword, bow | chance of nausea on target | — | 54 / 628 |
| fire | Пожар | I–III | bow | arrow: chance of fire burst under target (PQ 2022: 5/7/9 %, r 2, 5 s, 1/1.5/2 ❤/s, WR:43) | — | 55 / 614 |
| berserk | Берсерк | I–III | sword | below 10 hearts: chance of ×2 damage | `berserk` 10/20/30 % | 56 / 640 |
| slowness | Бульдозер | I–III | boots | when hit: chance to slow attacker | — | 57 / 600 |
| fortification | Укрепление | I–III | chestplate | when hit: chance of weakness on attacker; **conflicts with Халк** (WR:29) | — | 58 / 634 |
| saving | Экономия | I–III | bow | chance to keep the arrow (PQ 2022: 25/50/75 %, WR:44). Probably the card missing from HB (HB:257 "one card between Мороз and Пружины not in frame"; client order frost→fire→saving→springs) | — | BS:146 / 616 |

**Rare (10)**

| Client id | Name | Lv | Items | Effect | Ours | BS / LOC |
|---|---|---|---|---|---|---|
| wither | Иссушение | I–III | leggings | when hit: chance of wither on attacker | — | 63 / 632 |
| vortex | Вихрь | I–III | sword, bow | "wave of blows" disorients (mechanic unknown) | — | 64 / 606 |
| blindness | Слепота | I–III | sword, bow | chance of blindness on hit | — | 65 / 596 |
| hulk | Халк | I only | chestplate | permanent Resistance I + Slowness I; conflicts with Укрепление | — | 66 / 610 |
| tank | Танк | I–III | all armor | permanent extra hearts | `tank` +1/+2/+3 hearts | 67 / 638 |
| glutton | Обжора | I–III (HB:279 "no levels") | helmet | restores hunger during fights | — | 68 / 630 |
| ninja | Ниндзя | I–III | boots | on hit: chance of Speed for self | — | 69 / 608 |
| snitch | Стукач | I only | helmet | attacker glows, visible to all for a few s | — | 70 / 656 |
| shnyr | Шныр | I–II (HB:284 says I–III) | boots | chance to dodge a player's hit | — | 71 / 658 |
| curse | Проклятие | I–III | sword, bow | hit: target cannot heal for some s (blocks Вампиризм/Просвещённый), then 5 s immunity | — | 72 / 650 |

**Legendary (8)**

| Client id | Name | Lv | Items | Effect | Ours | BS / LOC |
|---|---|---|---|---|---|---|
| rage | Ярость | I–III | sword, bow | each hit raises later damage vs that target | — | 77 / 604 |
| archeologist | Археолог | I–III | pickaxe, axe, shovel, shears | dig: chance of Haste | `archaeologist` 3/6/9 %, Haste II 5 s | 78 / 626 |
| sacred | Просвещённый | I–III | all armor | when hit: chance to heal | `enlightened` 5/10/15 %, +2 ❤ | 79 / 594 |
| plastolom | Пластолом | I–III | pickaxe | small chance to clear the whole mine layer under the player; half the layer (≤ 200) to stats. Owner 26.10: 0.3/0.6/0.9 % per block (GAME-DESIGN §10, not in configs) | — | 80 / 648 |
| hammer | Молот | I–III | pickaxe, axe, shovel, shears | dig: chance to break random blocks in a radius | `hammer` 2/4/6 %, 3×3 | 81 / 624 |
| prospector | Старатель | I–III | sword, bow | more boss stars by damage share; < 35 % → none | — | 82 / 662 |
| obshak | Общак | I–III | sword, bow | bigger share of boss bank by damage share; < 35 % → none | — | 83 / 660 |
| vampirism | Вампиризм | I–III | sword, bow | heal from damage dealt, scales with damage+level | `vampirism` 5/10/15 % of damage | 84 / 592 |

**Legacy names in the client, not seen this season** (BS:146): tornado Торнадо (when hit: shuffles attacker's
inventory, LOC:636), lifestiller Гнев (hit: chance to steal health, LOC:642), mason Муляр, digger Землекоп,
lumberjack Дровосек, hunter Охотник (LOC:644–647, names only, no lore). Treat as out of scope unless the owner asks.

**Ours only:** `silk_touch` (DD catalog, rare, tools) — vanilla Silk Touch preset on the "rare wooden pickaxe" from the
Ordinary case (CaseService.luau:493–510). It is not in `books.effects`, so the Ancient case never drops it (correct),
but DigService has no silk-touch drop logic either.

**Count:** wiki 31 current (+1 probable Экономия) vs ours 9 ancient books → **22 missing** (23 with Экономия).
Icons: one shared `ancient_book` icon (icons.json:87, Blender pipeline `assets/models/items/grids.json`); no per-book
or per-rarity icon exists in the wiki either, so nothing missing there. Rarity strings `rarity_*` exist (Strings:2455).

### 1.2 How books are applied

**Original (wiki):**
- Get: Ancient case on Spawn (key in hand, click; SHIFT+RMB opens instantly, LOC:1569/1583; confirm dialog and
  "cannot open several at once", LOC:1257–1258). Improved key → max level of that type (LOC:1126) and "higher chance
  of rare/legendary" (HB:213). Also auction, gang Library sells books for stars (HB:236).
- Apply: "take the book with the cursor in the inventory and click a compatible item" (HB:255, LOC:562).
  Each book copy has its own **apply chance** (auction shows 1–100 %, BS:106–142). Success LOC:559; failure
  "книга порвалась… не наложилось" LOC:558 (book lost; item kept — GAME-DESIGN §10 [клиент]).
- Restrictions: same enchant twice refused (LOC:557); per-item limit `%d` (LOC:556) = sword 4, bow/armor/tool 2
  (LEVELS.md:108); Укрепление × Халк exclusive (WR:29); PQ-2022: Мороз incompatible with Пожар / Volcanic stone (WR:42).
  No money cost to apply observed.
- Levels I–III = trigger chance I < II < III (HB:255).
- Powder: click powder on a book → +efficiency % to apply chance (shop powder 10 %, LOC:1134; drop powder 2 %,
  BS:88); "already max chance" LOC:664. Source: boss last hit (BOSS-CARDS.md:27), shop 17.
- Dispeller (Развеиватель): removes one enchant, book lost (LOC:335); 15 stars / shop 199.
- Gang Forge: merge two books of same type+level for stars (LOC:797, 831; numbers unknown).

**Ours today:** application is **not implemented at all**.
- Book item: `{id="ancient_book", books={{id,level}}, rarity, applyChance}` created by `CaseService.ancientBook`
  (CaseService.luau:310–342) and by CreativeService (max level, applyChance 100). Tools/armor carry `books = {}`
  (InventoryService.luau:54).
- Display only: `ItemInfo.luau` (book name/rarity/description/targets/apply chance, lines 205–229; item tooltip
  "ancient slots n/limit" via `bookLimit`, line 69). `ItemTooltip.luau` lists a tool's books.
- No remote, no DragDrop/upgrade-window handler: dropping a book on an item just swaps slots
  (InventoryService.move; ancient_book is non-stackable, line 23). No powder or dispeller use. No forge/library.
- Config is ready for it: `books.limits`, `powderPerUse 0.02`, `donatePowder 0.1`, `forge` (DD:2396–2408);
  conflicts (Халк/Укрепление) and per-type max level are not modelled.

### 1.3 Ancient case roll (ours) — side effect of the missing books

`ancientBook` rolls rarity 70/25/5 (DD:2291) then picks among books *with effects* of that rarity. Ours has
4 common, **1 rare (Танк)**, 4 legendary → **every rare roll is Tank (25 % of all books)**. Level roll 60/30/10,
capped by `#effects`; apply chance 10–100 % (improved 40–100 %) [решение].

## 2. Spawn cases

### 2.1 Chests on the map and their keys

`scripts/build-npcs.luau:364–407` builds 5 chests on Spawn, tagged and with `CaseId`; CaseService binds the same tags
(CaseService.luau:41–48); `scripts/setup-streaming.luau:45` makes them Atomic.

| Chest (tag) | Pos | Key(s) `keys.caseKeys` | Key source in our game | Wiki key source (CAFB:11–15) |
|---|---|---|---|---|
| OrdinaryCase | (−26,0,−34) | ordinary_key | dig 0.1 %/block, pity 2000 (DigService:316–320); donate | dig, shop 10, players ≈90 $ |
| AncientCase | (26,0,−34) | ancient_key, improved_ancient_key | star exchange 10 / 60 (market.json), donate | same; 149 / 349 shop |
| ArtifactCase | (36,0,14) | artifact_key | ArtifactService (9 fragments) | same |
| NicknameCase | (−36,0,−14) | nickname_key | donate only (+ artifact case) | shop 99 |
| EnderChest | (−36,0,14) | none (storage) | — | — |

Every case has a matching key. Gap: **stars have almost no source** — BossService.reward (BossService.luau:948–1000)
pays only bank money; no star or powder drop although wiki boss cards give "Древняя звезда 100 %" + powder for the
last hit (BOSS-CARDS.md:27–36). Stars come only from the Ordinary case (weight 3) and donate.

### 2.2 Contents per case

**Ordinary case.** Wiki: window shows 15 items (JCS:73): apple, cooked chicken, toilet paper, arrow, leather
helmet/chestplate/leggings/boots lvl 1, golden apple, ancient star, wooden sword lvl 1, bow lvl 1, basement pass,
rare wooden pickaxe (Silk Touch), oblivion scroll; /wiki list the same (HB:211). 17 owner opens (JCS:75–97): 2–4
items each, food ≈ 80 %, money 0.37–1.37 $ in ≈ 40 %, "мясо" seen often, plus 1 artifact fragment; empty-with-money
message LOC:1250. Chances not shown anywhere.
Ours (DD:2233–2290, [решение] weights from the 17 opens; 2–4 rolls, CaseService:464; fragment 6 %, artifacts.json):

| Reward | Weight | Gives |
|---|---|---|
| food | 75 | apple / cooked_chicken / rotten_flesh ×1–3 |
| money | 40 | 0.37–1.40 $ |
| arrow | 8 | arrow |
| toilet_paper | 6 | toilet_paper |
| golden_apple | 4 | golden_apple |
| ancient_star | 3 | ancient_star |
| leather_armor_piece | 2 | helmet/chestplate/leggings/boots lvl 1 |
| wooden_sword_or_bow | 2 | sword or bow lvl 1 |
| basement_pass / rare_wooden_pickaxe_silk_touch / oblivion_scroll | 1 each | pass / pickaxe lvl 1 + silk_touch / scroll |

Matches the wiki list. Note: `docs/GAME-DESIGN.md` §9 (line 164) still describes an older table (blocks, soap,
sleeping bag, powder 3 %) — stale vs the config.

**Ancient case.** Wiki: 31 books (JCS:67–69, BS), improved key → max level. Ours: 9 books (see 1.1/1.3).

**Nickname case.** Wiki: one unique nickname, "all owned" error (LOC:1263, CAFB:14). The client holds the real list:
**46 titles** `prison.classic.titles.list.*` (LOC:508–553: Крыса, Шнырь, Шестёрка, … Задрот; some are crude).
Ours: 12 invented names (DD:2378) [решение]; key not spent when all owned (CaseService:412). Shop also lacks a
`/names` picker (LOC:1129) — we set the new nickname automatically.

**Artifact case** ("ядро на Спавне", CAFB:23). Wiki window (CAFB:38): ordinary keys, ancient stars, money bags,
**boxes (sets)**, nickname key, **powder/book**; no chances. Ours (DD:2339, 1 roll): ordinary_key 30 (×1–3),
ancient_star 25 (×1–3), money 25 (20–120 $ as `money_bag`), ancient_key 10, nickname_key 5, ancient_powder 5.
Missing vs wiki: **sets/boxes** (no item exists) and **a book**.

### 2.3 Every item that can drop from a case — does it exist?

Icon = `src/shared/Config/icons.json` (all also in the Blender pipeline `assets/models/items/grids.json`);
Strings = `item_<id>` in ru/en/es/fr (all 4 present for every id below).

| Item | Icon | Strings | Rules | Server use | Missing |
|---|---|---|---|---|---|
| apple | ✓ | ✓ | food 4 | FoodService | — |
| cooked_chicken | ✓ | ✓ | food 6 | FoodService | — |
| rotten_flesh | ✓ | ✓ ("Гнилая плоть") | **not in `survival.food`** | none (mob drop only) | inedible junk; wiki "мясо" is probably edible meat — decide id |
| arrow | ✓ | ✓ | bow ammo | BowService | — |
| toilet_paper | ✓ | ✓ | needs.toilet.consumable | NeedsService:234 | — |
| golden_apple | ✓ | ✓ | food 4 + Regen/Absorption | FoodService, HurtService | `desc_` optional |
| ancient_star | ✓ | ✓ | star exchange | EconomyService | boss drop source |
| helmet…boots lvl 1 | ✓ (`*_wood`) | ✓ | armor | ArmorVisual/Hurt | — |
| sword / bow lvl 1 | ✓ | ✓ | tools | Combat/Bow | — |
| basement_pass | ✓ | ✓ + desc | `<loc>_pass`, basement requiresPass | LocationService:128–144 | — |
| pickaxe + silk_touch | ✓ | ✓ + book_silk_touch | tools | DigService ignores `books` | silk-touch effect; "rare pickaxe → Efficiency IV" (ORIGINAL-VS-OURS:144) |
| oblivion_scroll | ✓ | ✓ + desc | — | **none** (no skill tree service) | use logic; not in donate (wiki 129) |
| ancient_book | ✓ | ✓ | books.* | CaseService/Creative | apply logic (1.2) |
| ordinary_key | ✓ | ✓ | caseKeys | CaseService, DigService | — |
| ancient_key / improved_ancient_key | ✓ | ✓ | caseKeys, starExchange | CaseService, EconomyService | — |
| nickname_key | ✓ | ✓ | caseKeys | CaseService | — |
| ancient_powder | ✓ | ✓ + desc | books.powderPerUse | **none** | apply-to-book logic, boss drop |
| money_bag | ✓ | ✓ | not tradable | CaseService.move claim | — |
| (dispeller — shop/exchange, not a case drop) | ✓ | ✓ | — | **none** | remove-enchant logic |
| sets / boxes (artifact case) | — | — | — | — | whole item missing |

## To do (by importance)

1. **Book application**: server remote (book → compatible item, roll `applyChance`, consume book on fail, limits,
   no duplicate type, Халк×Укрепление, per-type max level) + client drag-drop of a book onto an item.
2. **Effects of the 9 existing books** in server logic: Барыга/Археолог/Молот (DigService), Токсичный/Берсерк/
   Вампиризм (CombatService/BowService), Танк/Пружины/Просвещённый (HurtService/character). Silk Touch drop.
3. **Missing rare books first** (case gives Танк for 25 % of all rolls): Иссушение, Вихрь, Слепота, Халк (I),
   Обжора, Ниндзя, Стукач (I), Шныр (I–II), Проклятие — each needs `catalog` + `effects` + `book_`/`book_desc_` ×4
   locales + new status effects (poison, wither, blindness, weakness, resistance, jump, glowing; Effects.luau has
   only nausea/insomnia/slowness/haste/speed/regeneration/strength/absorption).
4. **Missing legendary**: Пластолом (owner numbers 0.3/0.6/0.9 %, ≤ 200 to stats), Ярость, Старатель, Общак.
5. **Missing common**: Чистюля (I–II), Раскалённый, Мороз, Громовержец, Боксёр, Замешательство, Пожар, Бульдозер,
   Укрепление, probably Экономия (PQ-2022 numbers for Мороз/Пожар/Экономия in WR:39–45).
6. **Star/powder sources**: BossService should drop ancient_star (cards: 100 %) and powder for the last hit;
   then powder-on-book and dispeller logic.
7. **Case contents**: artifact case — add sets/boxes and a book; nickname case — use the 46 client titles (filter
   crude ones with the owner); decide what "мясо" is (rotten_flesh is inedible).
8. **Oblivion scroll**: no skill tree to reset — implement or drop from the case; add to donate (129) if kept.
9. Fix GAME-DESIGN.md §9 line 164 (stale Ordinary case table); powder per use 2 % vs shop 10 % is already in config.
10. Strings: optional `desc_` for keys/golden_apple/money_bag (tooltip already shows "opens …" for keys).
