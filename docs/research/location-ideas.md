# Идеи для следующих локаций (поиск в сети, 26.10.2026)

Источник для промптов концептов ([location-prompts.json](location-prompts.json)) и для самой постройки. Собрано двумя поисковыми субагентами. Planet Minecraft и Sportskeeda на прямой запрос отдают 403, их страницы видны только в выдаче поиска. Википедия, minecraft.wiki и TheCollector открывались. Названия блоков — ID Minecraft. Все текстуры у нас свои: Minecraft-блоки здесь только язык описания палитры.

**Образец стиля, выбранный владельцем:** Подножье горы и Пустотная крепость ([assets/screenshots/style-ref-mountain-foot.jpg](../../assets/screenshots/style-ref-mountain-foot.jpg), [style-ref-end-castle.jpg](../../assets/screenshots/style-ref-end-castle.jpg)). Это наши блоки с пиксельными текстурами, крупные формы, простой свет. Концепты в стиле «воксельная диорама» (мелкие кубики, свечение) владелец назвал «не наш стиль».

## Этажи с боссами

### Рынок (21) — Король нежити

- **Концепция:** пёстрый тюремный базар (Гранд-базар в Стамбуле). Ряды полосатых навесов сходятся к площади, ткань навесов — это и есть шахтная шерсть.
- **Ориентир:** посреди рынка провалилась мостовая, фонтан наполовину ушёл в провал. Лестница ведёт в сводчатый зал-склеп с троном из `bone_block` и короной из `gold_block`.
- **Детали:**
  - навесы в полоску 1/1 на `spruce_fence`;
  - бочки с `melon`/`hay_block`;
  - весы из заборов и нажимных плит;
  - флажки на цепях;
  - лаз под прилавком (открытый люк, рядом кирка);
  - куры в клетках из `iron_bars`;
  - тележки;
  - вышка надзирателя;
  - кости и черепа в трещинах;
  - котёл на костре.
- **Приёмы:**
  - мостовая с шумом из `cobblestone`, `andesite`, `gravel` и `coarse_dirt`; у провала её сменяют `cracked_stone_bricks`, затем `soul_soil`;
  - фахверковые задние стены лавок на 1 блок глубже прилавка;
  - своды склепа из перевёрнутых ступеней.
- **Источники:** [Market Town 2](https://www.planetminecraft.com/project/market-town-2-massive-medieval-city-build/), [Underground tomb cathedral](https://www.planetminecraft.com/project/underground-tombcathedral/), [Гранд-базар](https://theistanbulinsider.com/the-grand-bazaar-of-istanbul-worlds-oldest-and-biggest-covered-market/).

### Лепреконовая долина (23) — Лесной дух

- **Концепция:** зелёная чаша холмов с ирландским фейри-фортом (кольцевой вал). По поверьям, лепреконы стерегут золото именно в таких фортах. Радуга из 7 цветов concrete powder падает в котёл золота.
- **Ориентир:** кривой боярышник (дерево фейри) в центре вала, в его корнях тотем Лесного духа.
- **Детали:**
  - клевер из `moss_carpet`;
  - менгиры из `mossy_cobblestone`;
  - стоянка культистов (шатры из зелёной шерсти, костры, баннеры);
  - дома из грибов;
  - грибное кольцо;
  - шляпы лепреконов на стойках;
  - `raw_gold_block` в ручье;
  - светлячки из `glow_lichen`.
- **Приёмы:**
  - трава с шумом из `grass_block`, `moss_block` и `green_wool`;
  - двойной вал фейри-форта с рвом;
  - тотем из `stripped_oak_log` с «лицами» и рогами из заборов.
- **Источники:** [Fairy fort](https://en.wikipedia.org/wiki/Fairy_fort), [Pot of gold](https://sportskeeda.com/minecraft/news-minecraft-redditor-builds-pot-gold), [Druid temple](https://www.planetminecraft.com/project/druid-temple/).

### Замок (25) — Вороний рыцарь

- **Концепция:** белый готический замок из кварца, испорченный вороньими гнёздами и копотью. Контраст белого и чёрного читается издалека.
- **Ориентир:** донжон «Белая башня» с вороньим гнездом на шпиле, по легенде Тауэра: улетят вороны — падёт замок. Арена — двор под донжоном со статуями рыцарей.
- **Детали:**
  - зубцы из `quartz_slab`;
  - бойницы с чёрным стеклом;
  - гнёзда из `dark_oak_fence` и чёрной шерсти;
  - клетки для воронов;
  - подъёмный мост на цепях;
  - доспехи на стойках;
  - коридор с `soul_lantern` через каждые 6 блоков;
  - рваные чёрные баннеры;
  - плющ.
- **Приёмы:**
  - градиент стен снизу вверх `deepslate_bricks` → `polished_andesite` → `quartz_bricks` → `quartz_block`;
  - контрфорсы через каждые 4 блока;
  - `quartz_pillar` на углах.
- **Источники:** [Вороны Тауэра](https://en.wikipedia.org/wiki/Ravens_of_the_Tower_of_London), [Gothic pale castle](https://www.planetminecraft.com/project/gothic-pale-castle-schematic/), [Big dark castle](https://www.planetminecraft.com/project/big-dark-castle/).

### Изнанка (27) — Векна

- **Концепция:** мёртвая копия пригорода Хокинса. Лозы на домах, куски улиц парят в красном небе, в воздухе пепел.
- **Ориентир:** викторианский особняк (дом Крила) на парящем острове, над крыльцом дедушкины часы. Арена — островки в красной пустоте.
- **Детали:**
  - перевёрнутые машины и столбы;
  - лозы из `dark_oak_leaves` и `twisting_vines`;
  - «ворота» из `crimson_hyphae` и `shroomlight`;
  - куски дороги из `black_concrete` с разметкой;
  - пепел;
  - гирлянда лампочек с алфавитом;
  - коконы из `nether_wart_block`;
  - красные молнии;
  - велосипед.
- **Приёмы:**
  - шум «порчи» (30 % листвы, 10 % `sculk`);
  - острова в виде перевёрнутых конусов с `hanging_roots`;
  - свет красный снизу и синий сверху, туман.
- **Источники:** [Upside Down](https://en.wikipedia.org/wiki/Upside_Down_(Stranger_Things)), [Vale of Shadows](https://www.planetminecraft.com/mod/stranger-things-inspired-the-vale-of-shadows-mod-survival-horror-experience/), [Chris Trujillo](https://www.motionpictures.org/2026/01/the-architect-of-the-upside-down-inside-stranger-things-production-designer-chris-trujillos-epic-season-5-builds/).

### Киото (29) — Самурай

- **Концепция:** храм на склоне как Киёмидзу-дэра. Деревянная сцена на сваях нависает над сакуровой долиной, к ней ведёт тоннель торий как в Фусими-Инари.
- **Ориентир:** сцена на сетке столбов и пагода рядом, под сценой водопад в три струи. Арена — сама сцена, призрак жены появляется у пруда.
- **Детали:**
  - 20+ торий вплотную;
  - каменные фонари;
  - кои-пруд с мостом;
  - бамбук;
  - лепестки `pink_carpet`;
  - сухой сад из `smooth_quartz_slab`;
  - бумажные фонари;
  - статуи кицунэ.
- **Приёмы:**
  - крона сакуры: ядро из `pink_wool`, края из `cherry_leaves`;
  - крыши из ступеней и плит с поднятыми на 1 блок концами;
  - сваи с перекрёстными балками через каждые 4 блока.
- **Источники:** [Kiyomizu-dera](https://en.wikipedia.org/wiki/Kiyomizu-dera), [Torii water gate](https://www.planetminecraft.com/project/japanese-torii-water-gate/), [Arches of Inari](https://www.planetminecraft.com/texture-pack/arches-of-inari-torii-gates-improved/).

### Ферма (31) — Грут

- **Концепция:** идеальная лоскутная ферма с полосами грядок через каждые 5 блоков, вид с холма. В центре мельница, на краю древнее дерево-энт (спящий Грут).
- **Детали:**
  - вода под люками;
  - бахча;
  - мельница с парусами из белой шерсти;
  - кирпичный силос;
  - пугало;
  - ульи;
  - колодец;
  - стога;
  - тыквенная тележка;
  - лавка с урожаем.
- **Приёмы:**
  - тропы из `dirt_path` с краями из `coarse_dirt`;
  - мельница на каменном основании с деревянным верхом.
- **Источники:** [Windmill + wheat field](https://www.planetminecraft.com/project/medieval-windmill-w-wheat-field-barn/), [Ultimate mega farm](https://www.planetminecraft.com/project/ultimate-realistic-mega-farm-full-interiors-vehicles-barns-windmill-all-animals-amp-more-java-bedrock/).

### Амбар (33) — Древесный хранитель

- **Концепция:** та же ферма много лет спустя, тёмный хэллоуин-вариант.
- **Ориентир:** красный амбар с провалившейся крышей, сквозь дыру растёт дерево, внутри светятся тыквы.
- **Детали:**
  - светильники Джека в бурьяне;
  - ржавый трактор;
  - мельница без крыльев;
  - кривой забор;
  - пугало с горящей тыквой;
  - мусорные кучи;
  - паутина в окнах;
  - разбитый силос;
  - ворон;
  - свечи на стогах.
- **Приёмы:**
  - выцветшие стены из `red_terracotta`, `brown_terracotta` и `stripped_dark_oak_log` вперемешку;
  - зарастание лозами, травой и мхом.
- **Источники:** [Abandoned farm](https://www.planetminecraft.com/project/fantasyrustic-an-ol-abandoned-farm-by-chingom-on-conquest-reforged/), [Barn](https://www.planetminecraft.com/project/barn-6836564/), [Halloween builds](https://www.pcgamesn.com/minecraft/halloween-builds).

### Врата края (35) — Жнец

- **Концепция:** острова из эндерняка над пустотой. Плантации хоруса рядами как виноградник, шпили от `black_stained_glass` у основания к `magenta_concrete` у вершины.
- **Ориентир:** обсидиановая арка 20+ блоков с колоннами из `purpur_pillar`. Арена — круглая платформа перед ней.
- **Детали:**
  - `end_rod` вместо факелов;
  - баннеры;
  - шалкеры;
  - голова дракона;
  - кольцо из 10 обсидиановых столбов;
  - воткнутые косы;
  - сталактиты из пурпура под островами.
- **Источники:** [End City](https://minecraft.wiki/w/End_City), [End obsidian towers](https://www.planetminecraft.com/project/end-obsidian-towers/), [End temple](https://www.planetminecraft.com/project/end-temple-3647023/).

## Небесные шахты — один путь наверх

Подъём идёт по трём шкалам сразу:

- **свет:** утро → полдень → золотой час → белое сияние;
- **насыщенность:** земные тона внизу → белый с золотом вверху;
- **силуэт:**
  - Древо — ствол;
  - Церковь — шпиль;
  - Чистилище — спиральная гора;
  - Эдем — плоский сад;
  - Херувимы — кольца;
  - Врата — арка на оси;
  - Рай — роза-амфитеатр.

Облака под островами из `white_wool`, `white_concrete_powder` и `snow_block`; чем выше уровень, тем их больше.

- **Древо (37):** комок земли в корнях, ствол 9–13 блоков со спиральной лестницей внутри, корни свисают на 30–40 блоков под остров (блоки → ступени → заборы → `hanging_roots`). Кора — смесь древесины 60/30/10, крона пятнами из 3–4 видов листвы. Шахта из белого цемента — «застывший небесный сок» между корнями. [Mega tree](https://www.planetminecraft.com/project/mega-enormous-tree/), [Yggdrasil biome](https://feedback.minecraft.net/hc/en-us/community/posts/43575646779277-The-Yggdrasil-Forest-Biome).
- **Церковь (39):** белая готическая базилика на утёсе. Неф без стен как в Сент-Шапель: витражи от пола до свода. Стены из `calcite` и `diorite`, рёбра свода из `quartz_pillar`. Шахта из глины в проломе пола нефа. [Celestia Numina](https://www.planetminecraft.com/project/celestia-numina/), [Sainte-Chapelle](https://sun.iwu.edu/~callahan/stechapelle-haute-e.html).
- **Чистилище (41):** гора из 7 террас (Данте). Градиент `red_sandstone` → `sandstone` → `smooth_sandstone`, очереди полупрозрачных душ, песочные часы, зигзаг-лестница с фонтанами (Бом-Жезуш), полоса огня на последней террасе. [Dante's Purgatory](https://www.thecollector.com/dante-purgatory/), [Bom Jesus do Monte](https://en.wikipedia.org/wiki/Sanctuary_of_Bom_Jesus_do_Monte).
- **Эдем (43):** плоский сад, две реки делят его на 4 сектора, в центре розовое Древо жизни (`cherry_leaves` и `pink_wool`), на стволе змей из зелёной терракоты, у корней луг гигантских грибов (шахта). Это первый по-настоящему цветной уровень. [Cherry builds](https://diamondlobby.com/minecraft/5-cherry-blossom-minecraft-builds/).
- **Херувимы (45):** наклонённые золотые кольца («колесо в колесе», Иезекииль). Купол-ротонда с шестикрылыми херувимами (Святая София). Золото — смесь `gold_block`, `raw_gold_block`, `yellow_concrete` и `honeycomb_block`. Шахта из снега — «облачная пашня» внутри колец. [Angels of Hagia Sophia](https://www.thecollector.com/angels-hagia-sophia/), [Ophanim](https://www.christianity.com/wiki/angels-and-demons/angels-wheel-with-eyes-ophanim.html).
- **Врата (47):** строгая симметрия, дамба над морем облаков. Жемчужные створки из `white_glazed_terracotta`, `calcite` и `pearlescent_froglight` в стене из «яшмы» (призмарин), «золото как стекло» на дороге, пилоны уменьшаются к вратам (форсированная перспектива), за вратами луч маяка. Шахта — плац перед вратами. [Pearly gates](https://en.wikipedia.org/wiki/Pearly_gates), [Откровение 21](https://www.esv.org/verses/Revelation+21:9-27/).
- **Рай (49):** белая роза-амфитеатр (Эмпирей, Доре), почти монохром, свет спрятан под плитами, радиальная симметрия на 8–12 лучей. Шахта из красных грибов — алое сердце розы, единственное насыщенное пятно. [Doré Empyrean](https://thesefantasticworlds.com/gustave-dore-illustration-empyrean/).
- **Нефтезавод (12, по желанию):** ржавый завод, разорванный изнутри. Ректификационная колонна 40+ блоков, переломленная пополам, рядом факел; ржавчина из медных блоков разной окисленности; из трещин из `crying_obsidian`, аметиста и фиолетового стекла сочится «нечто». [Refinery build](https://www.planetminecraft.com/project/lapiz-points-refinery-ac/), [Off-sites](https://britannica.com/technology/petroleum-refining/Off-sites).
