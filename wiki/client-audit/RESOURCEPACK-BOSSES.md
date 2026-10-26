# Ресурс-пак сервера Prison: боссы, их приёмы, миньоны, звуки

26 октября 2026 года. Источник: ресурс-пак, который сервер Prison Classic присылает клиенту, — `%USERPROFILE%\.cristalix\updates\Minigames\server-resource-packs\8926c86d…` (45 МБ, 1 081 файл, версия от 19.10.2026; предыдущая f730ac0c… почти такая же). Распакован и разобран только для чтения. Машинные выгрузки:

- [content-analysis/resourcepack/boss-model-animations.json](content-analysis/resourcepack/boss-model-animations.json) — каждая модель: анимации, длительности, размеры;
- [content-analysis/resourcepack/sound-events.json](content-analysis/resourcepack/sound-events.json) — звуковые события.

**Модели, текстуры и звуки пака — собственность Cristalix и авторов паков. В игру их не копировать** (правило как для анимаций Better Combat). Здесь записаны только названия и длительности как описание механик.

## Главное

1. **Боссы Prison — это MythicMobs + ModelEngine.**
   - В анимациях есть события с префиксом `mm:` (`mm:pg_walk`, `mm:Warrior_WAKE_SFX_1`), звуки Короля нежити называются `healong.undeadking.*`.
   - Многие боссы — готовые платные паки с маркетплейсов:
     - **Скелетон** — «Skeleton Boss» (amonde, MCModels): правый и левый взмах, топот с ловушками, ядовитое облако, рёв с призывом скелетов;
     - **Грут** — «Ent King» из «Ent Pack» (MCModels), там же Ent Guardian, Ent Warrior, Ent Sorcerer, Ent Minion;
     - **Самурай** — «[MCGarage] The Lovers — Samurai Boss»: 3 фазы, 14 моделей, около 40 атак. Описание Cristalix «Самурай Ханасигуро и дух его возлюбленной» — пересказ описания пака;
     - **Король Пиглинов** — «The Piglin Glutton»: более 15 анимаций, свои звуки;
     - **Король нежити** — пак Undead King (миньоны-гули, черепа, призрачный меч).
2. **HP, урон, перезарядки, проценты книг и тренера в файлах клиента НЕТ.**
   - У MythicMobs это YAML-конфиг на сервере Cristalix (`Health:`, `Damage:`, `Skills:`); клиенту он не отправляется никогда.
   - Клиент получает только событие «моб получил урон» и полосу босса. Языковой файл Prison (2 500 строк, не менялся с 19.10) везде подставляет числа сервером через `%s`: шанс книги «Шанс зачарования предмета » %s», уровень тренера «Ур. %d / %d».
   - Логи клиента зашифрованы. В трёх дополнениях (wada 4.18.8, gama, socials, обновлены после 21.10) кода Prison нет.
3. Зато из моделей **точно видны набор приёмов каждого босса, длительность каждого приёма (время замаха и удара), снаряды, миньоны, фазы и звуки**. Это можно повторить своими силами.

## Как получить числа, которых нет в файлах

- **HP босса** — по чату. При соло-убийстве «Топ по урону» = всё здоровье. Уже снято: Король Пиглинов 252,65 и 283,62; Базальтовый страж 282,81 ([BOSS-CARDS.md](../in-game-wiki/BOSS-CARDS.md)). Это сходится со словами владельца «у слабого ≈ 280». Для остальных нужен соло-бой или сумма урона всех участников. Чат показывает только топ-3, поэтому нужен бой втроём или меньше.
- **Урон босса** — сколько сердец снимает каждый приём при известной броне. Снимать видео боя и считать сердца по HUD.
- **Книги** — у каждой книги в подсказке «Шанс зачарования предмета » N %». Шанс срабатывания не показан. Измеряется только счётом: например, 100 ударов с Токсичным I — сколько раз было отравление.
- **Тренер** — меню показывает требования и «Ур. N / макс». Силу эффекта можно измерить: урон по крысе до и после уровня Силы, число уклонений из 100 ударов при Ловкости.
- В сети 2025–2026 этих чисел нет ([web-research/B-combat-bosses-podval.md](../web-research/B-combat-bosses-podval.md)). Есть таблицы 2022 года (550 HP у первого босса, 17 000 у последнего) и Prison Quick 2022 (Сила тренера максимум +45 %, Мороз 6 % за стадию, Пожар 5 / 7 / 9 %, Экономия 25 / 50 / 75 %) — это другие сезоны и режим.

## Боссы по моделям

Длительности — в секундах, как в файле анимации. «Приёмы» — анимации атак и умений, без idle/walk/hurt.

| Босс (наш id) | Модель | Приёмы | Миньоны, снаряды, эффекты |
| --- | --- | --- | --- |
| **Базальтовый страж** (basalt_guardian) | `basalt_guardian` | attack_1 1,5 · sword_slash 1,8 · sword_smash 3,5 · sword_spike 4,0; death 4 | — |
| **Зомбарь** (giant_zombie) | `giant_zombie` | **только attack 1,32**; idle 4,16, walk 1,5, death 2,0 | — (звуки только idle и death) |
| **Сплинтер** (splinter) | `splinter` | attack 1,0 · swoop 1,1 · potion 1,55 · shoot 2,25 · summon 4,0; death 4 | `splinter_bottle` (брошенная склянка), `splinter_spider` (призванные пауки: projectile 0,85, «tapping»), `strike_of_fury` 3,6 |
| **Король Пиглинов** (piglin) | `piglin_glutton` | verticalatk 3,0 · horizontalatk 3,0 · footstomp 2,5 · spinslam 5,0 · bodyslam 5,0 · upchuck 6,0 · healing 7,1 · summoningchant 4,0 · charge 10,0; spawn 5,7, death 5 | `piglin_glutten_minion` (атаки 0,67 и 0,75) |
| **Минотавр** (minotaur) | `minotaur`, `sleeping_minotaur` | спит на цепях: awakening 9,8 · attack_horns 1,1 · impact 1,2 · double_attack 1,7 · throws_the_ground 3,6 · minotaur_rush 4,1 · **stun 3,8** (оглушение после удара в стену, звук stun_wall); death 13 | `ground_with_roots` (брошенный ком земли, полёт 3,96) |
| **Скелетон** (skeleton) | `skeleton` | atkrswipe и atklswipe 1,25 · sklrstomp и skllstomp 2,0 · sklpoisonbreath 3,5 · sklroar 5,0 | `trap` (ловушки от топота), `poison` (облако), `skeleton_minion` |
| **Рыцарь** (knight) | `knight` | startcombat 1,5 · комбо c1–c5 0,65–1,0 · dash вперёд, влево, вправо, назад · berserkerleap 2,0 · relentlesswhirlwind spin и pierce · bloodboundbarrier 0,8 · bulwarkinstinct 1,5 · strikeoffury1 и 2 ≈ 2,8 · viciousstrike 4,75 · flinch 2,5 | `vfx_explosion` (small, medium, big, huge fire explosion); звуки ult_stomp, wheel_spin |
| **Иллюзионист** (illusionist) | `illusionist` | attack 1,0 · attack2 1,0 · attackdagger 1,34 · attackcards 2,0 · attackbox 2,2 · summonrabbits 3,35 · phasecards 1,0 · **regeneration 5,9** · active/notactive (фазы); death 8 | `rabbit` (кролики взрываются: explosion 3,5), `dagger`; звуки magical_ray, cards_fell |
| **Паучья матка** (spider_queen) | `spider` | fangattack 1,45 · webattack 1,85; death 6,25 | `spider_web` (паутина на земле, появление 0,7), `hunstman_spider` (паук-миньон) |
| **Векна** (vecna) | `pa_vecna1` (Stranger Things) | attack1 0,5 · attack2 4,0 · flower; death 4,7 | демогоргон, демопёс, демолетучка, `pa_clock` (часы Векны, звук vecna.clock.time — отсчёт проклятия), `pa_portal` |
| **Грут** (ent) | `ent` (Ent King) | rightpunch и leftpunch 1,5 · stomp 2,3 · shout 1,9 · rise 2,4; death 3,3. Умения пака: Twisted Branch, Branch Wave, Leaf Storm, Tree Minions | `ent_branch` и `ent_branch_upwards` (ветви из земли), `ent_minion`, `ent_warrior`, `ent_sorcerer` (Leaf Tornado), `ent_guardian` (Guardian's Bash, Root Pierce, Shockwave, Branch Blow) |
| **Древесный хранитель** (forest_guardian) | `tree_forest_guardian` | attack 2,0 · big_punch 1,1 · summon 3,0; death 2 | `magic_creature_minion` — «пока его создания живы, никакое оружие не способно ранить хранителя» |
| **Лесной дух** (forest_spirit) | `forest_spirit` и тотемы | attack1–attack8 (от 1,9 до **28,9** — длинная особая фаза), spawn 14,7, death 25,4, **spawn_cancelled 13,2** (появление прервано) | тотем (`forest_spirit_totem`, `activated_totem`, `base`), `storm`, `roots`, `spike`, 6 снарядов, `spirit_lightning_bolt`, `spirit_arrow`; культисты: `shaman` (8 атак, корни), `lost_explorer` (с фонарём), `flying_skull` |
| **Моль** (mole) | `moon_glow` | attack1, 3, 4 · startshoot и descendshot (стрельба с неба) · shadowlight · moonssight · meteorrain · midnight («полночь») · stun 0,75 · strafe · **talking / rightitem / wrongitem / simpleleave** — диалог, в котором игрок отдаёт правильный или неправильный предмет | `vfx_soul_meteor`, `vfx_soul_rain`, `vfx_soul_explosion`, `vfx_soul_impact` |
| **Жнец** (reaper) | `reaper` | attack1 0,73 · attack2 0,7 · circleattack 1,05 · groundattack 1,7 · teleportinto и out · soul1 4,9 (забор души) · circlespin 10 · explosion 2,1; spawn 5,6 | `circle` (круг на земле) |
| **Самурай** (the_lovers) | `the_lovers_phase_1/2/3`, `the_lovers_ghost` | 3 фазы по 10–11 атак плюс призрак возлюбленной с 8 атаками; смена фазы — spawn 10–19 с; death 26,9 | `big_arrow`, `rain_arrow` (дождь стрел), `ghost_spear`, `kusarigama`, `shuriken`, три вида разрезов, `samurai_armor_dequip` (сброс доспеха между фазами) |
| **Посейдон** (poseidon) | `mso_poseidon` | swing и swing_2 1,0 · stab 1,3 · wave_clash 1,3 · epicenter 1,7 · torpedo 1,0 · swim_attack · kneel | звуки, вероятно, `boss.nikolay.*` (attack1–3, pierce, runhit) |
| **Вороний рыцарь** (raven_knight) | `thecrowknight`, `crowreaper` | рыцарь: simplecombo, simplecombo2, fastcombo 4,35, comboflyattack 4,25, explosion 6. Вторая форма «жнец-ворон»: basicattack, chargeattack, fogcombo, summonaxe, spikesattack | `crowaxe`, `crowfog`, `crowspike`, `reaperspikes`, `crowswarm` (стая ворон) |
| **Король нежити** (undead_king) | `undead_king` | attack 0,7 · skill1 2,5 · skill2 2,0 · skill3 0,7 | `ghoul` (гули), `skull` (взрывающиеся черепа), `undead_king_sword` (призрачный меч, 8 с); звуки dark_missile, skull_summon, onplayerkill |

Полосы здоровья: у каждого из 19 боссов своя рамка, медальон и «осколок» (`textures/prison_bossbar/<boss>_frame | medallion | shard.png`) плюс общие `crack` и `glow`. Полоса трескается по мере потери здоровья.

## Мобы и NPC

- **Крыса** `rat`: idle 3, walk 0,48, **attack 0,62**, death 2.
- **Зомби** `zombie2` и `zombie3`: attack ≈ 0,6, death 1,25–1,45.
- **Охранник** `fabric/security` (вероятно, Нефтезавод): атаки 0,69, две анимации смерти.
- **NPC-заключённые** `prison_npc/inmate_*`: 120 моделей. Варианты по темам локаций (desert, eerie, end, heaven, japan …) и инструменту в руках — у каждой локации свои рабочие.
- NPC Спавна: `jobs` (Работы), `librarian` (библиотекарь банды), `npc_top` (у табло топов), `wiki` (справочник). Тренажёры зала Тренера `gym/*`: штанга, жим лёжа, велотренажёр, тяга, груша, стойка для приседа, беговая дорожка.

## Прочее из пака

- **Визуальные эффекты книг:** `enchant/rage` (Ярость), `enchant/slowness` (Бульдозер), `enchant/vortex` (Вихрь).
- **Звуки локаций** (`prison.ambient.*`):
  - шахты — castle, cave, desert, eerie, end, farm, forest, heaven, japan, market, nether, quarry, sea, snow;
  - зоны Спавна — canteen, dorm, gate, gym, kitchen, library, market, showers, yard;
  - одна общая музыка боссов `prison.music.boss`.
- **Предметы (CIT):**
  - 9 бустеров (local, fraction, global × blocks, money, mobs);
  - ключи: обычный (`default`), древний (`mythic`), улучшенный древний (`upgraded_mythic`), кличек (`rank`), артефактов;
  - мыло, бумага, спальник, вакцина; древняя книга, порошок, развеиватель; пропуск в подвал; деньги-чек;
  - шарды: огненный осколок, лунная сталь, вулканический камень, лунное лезвие (топор `moon_axe`);
  - свиток забвения.
- **Карьеры:** металлы STONE, IRON, DIAMOND, TITAN, SCULK; пропуска STONE, TITAN, DIAMOND, SYNTHETIC; `mine_pass`.
- **Чары, которых нет в справочнике `/wiki`:** в языке клиента есть ещё Экономия (лук: шанс сохранить стрелу — вероятно, та карточка между Морозом и Пружинами, что не попала в кадр), Торнадо («перемешать вещи в инвентаре противника»), Гнев («украсть здоровье»), а также Муляр, Землекоп, Дровосек и Охотник без описаний — старые или отключённые.

## Сравнение с нашими боссами

- **Набор приёмов.** У нас у всех боссов одна схема из `BossService`: удар плюс три приёма лавового клинка, шипов и рывка (`lavaBlade`, `earthSpikes`, `charge`); у новых локаций — «набор приёмов Минотавра». У оригинала у каждого босса свой набор (таблица выше). Совпадает по духу только Базальтовый страж: sword_slash / sword_spike / sword_smash ≈ наши клинок / шипы / удар.
- **Зомбарь ⚠️.** У оригинала одна атака ближнего боя и никаких умений. У нас у Зомбаря три приёма.
- **Минотавр ⚠️.** У оригинала он спит на цепях и просыпается (awakening 9,8 с), бьёт рогами, кидает землю, таранит и **оглушается сам** после рывка в стену. У нас рывок и колонны Pillar с оглушением — это близко по смыслу.
- **Механики боссов, которых у нас нет ❌:**
  - лечение Пиглина и Иллюзиониста;
  - миньоны у Пиглина, Скелетона, Сплинтера, Грута, Хранителя, Лесного духа, Короля нежити, Векны, Паучьей матки;
  - неуязвимость Хранителя, пока живы миньоны;
  - фазы Самурая;
  - тотем Лесного духа;
  - паутина-ловушка Матки;
  - яд и ловушки Скелетона;
  - метеоры Моли;
  - телепорт Жнеца.
- **Длительности приёмов** можно брать как ориентир для наших замахов. Например, у Стража шипы — 4 с (наша `earthSpikes` проверяется по `abilityCooldown`).
