# Разбор добычи, автоматических действий и токенов Prison

Дата: 18 октября 2026. Репозиторий: PrisonTeam/Prison. Ревизия: `6914aa0a687c26a44e10d150ae5e4b17bf733b04`.

Это статический разбор выбранных исходников. Плагин и сторонние плагины не запускались. Ниже «подтверждено» означает, что соответствующая ветка найдена в коде этой ревизии; наличие ветки не доказывает, что конкретный сервер включает её настройками. Предложения для Roblox обозначены отдельно.

## 1. Подтверждённый основной путь

Обычное копание приходит в `AutoManagerBlockBreakEvents.handleBlockBreakEvent`: исключается повторный вход через собственное событие, проверяется, нужно ли игнорировать блок, затем доступ, BlockConverter triggers и валидация. MONITOR после валидации не проходит обработку добычи. [Обработчик обычного блока](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerBlockBreakEvents.java#L260-L391).

Для собственной массовой добычи используется `AutoManagerPrisonsExplosiveBlockBreakEvents`: список `ExplodedBlocks` переносится в `UnprocessedRawBlocks`; бомба может передать условную кирку, принудительную продажу и флаг учёта блоков игроку. Износ условной кирки бомбы отключается. Затем вызываются те же `validateEvent` и `processPMBBEvent`. [Обработчик массовой добычи](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L297-L380).

Валидация собирает реальные drops, резервирует блок через `setMined(true)`, проверяет массовые блоки на нахождение внутри текущей шахты, неразрушаемость, пустоту, прошлую обработку и совпадение с ожидаемым блоком. В конце объединяет drops по имени. Это важнее визуального эффекта взрыва: обрабатывается список подтверждённых блоков. [Основной блок](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L490-L529); [Массовые блоки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L617-L704); [Объединение до Fortune](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L794-L796).

В `processPMBBEvent` сначала публикуется событие расширения Bukkit. Только если оно не отменено, выполняются `doAction`, физическое удаление блоков и block events. [Общая точка обработки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L254-L310).

Практическая последовательность при включённом AutoPickup:

1. Получить drops от Bukkit или интеграции custom blocks.
2. При включённом Silk Touch заменить набор drops на сами блоки.
3. Применить `fortuneBukkitDropsMultiplier`: `q = max(1, trunc(q × multiplier))`.
4. Добавить специальные drops, в текущем разборе — кремень из гравия.
5. Применить одну выбранную модель Fortune к каждому стеку типа материала.
6. Ещё раз объединить drops.
7. AutoSmelt.
8. AutoBlock.
9. Попытаться продать каждый стек; непроданное добавить в инвентарь; отдельно обработать переполнение.
10. Посчитать XP/износ/усталость, затем удалить блоки и обработать счётчики и block events.

[Silk, multiplier, Fortune, merge, smelt, block](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L919-L1033); [Продажа, инвентарь и переполнение](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1079-L1221); [Переход к последствиям копания](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L867-L874); [XP, износ и усталость](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L1235-L1278).

Без AutoPickup работает отдельная ветка `calculateNormalDrop`, если `handleNormalDropsEvents` включён: тот же порядок Fortune → merge → smelt → block, затем сброс предметов возле исходного блока. В этой ветке немедленная продажа разрешается только флагом `ForceAutoSell` и работающим SellAll. [Обычные drops](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1261-L1417).

## 2. Включение автоматических действий и ограничения

Pickup/Smelt/Block могут включаться конфигом, lore, зачарованием или явно установленным permission. Для каждого есть ограничение «только внутри шахты». Это не три безусловно активные механики. Код использует `isPermissionSet`, поэтому операторство само по себе не включает все действия. [Условия включения](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L553-L625).

AutoPickup также фильтруется по `pickupAllBlocks`, списку имён или встроенным категориям. Проверяется исходный блок события, после чего обрабатывается весь собранный набор drops, что стоит учитывать при смешанном составе взрыва. [Фильтр AutoPickup](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2080-L2124).

AutoSmelt применяет таблицу превращений: железная/золотая/медная руда и raw material → слиток, булыжник → камень, древние обломки → незеритовый лом и другие. Для этих операций используется отношение 1:1. CustomItems и ItemsAdder пропускаются. [Ограничение custom blocks](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2365-L2395); [Таблица переплавки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2462-L2597).

AutoBlock сжимает ресурсы, обычно 9:1, отдельные материалы 4:1 (например кварц, снежки, осколки призмарина). Помощник сохраняет остаток: `target = floor(source / ratio)`, `remainder = source % ratio`. Это уменьшение занятого объёма; сама по себе компрессия не доказывает рост денежной стоимости — цену результата задаёт магазин. [Пример 9:1](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2643-L2675); [Примеры 4:1](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2751-L2784); [Формула и остаток](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/SpigotUtil.java#L452-L475).

Если включён захват содержимого инвентаря, соответствующий ресурс сначала удаляется из инвентаря и добавляется к текущему стеку drops, после чего преобразуется. Это обработка имеющихся ресурсов, а не бесплатная генерация. [Объединение с инвентарём](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/SpigotUtil.java#L384-L395).

При AutoPickup продажа включается формулой `forceAutoSell || (playerAutosellEnabled && isAutoSellPerBlockBreakEnabled)`; принудительная продажа требует включённого SellAll. Успешно проданному стеку выставляется количество 0, непродаваемый остаётся для инвентаря. Переполнение может запускать продажу инвентаря, повторную выдачу остатков, выпадение предметов и уведомление в зависимости от настроек. [Условия продажи](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1079-L1158); [Продажа при заполнении](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1642-L1717); [Выдача и выпадение остатка](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1760-L1785).

## 3. Fortune: фактические варианты

Базовый уровень берётся из TokenEnchant при включённой интеграции, затем может быть заменён RevEnchants; стандартное Bukkit-зачарование используется, если внешние источники не сработали. Верхний уровень ограничивается `fortuneMultiplierMax`, если он положительный. [Получение уровня](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L389-L510). Это получение уровня внешнего зачарования, а не собственная система покупки всех зачарований.

Внутри `calculateFortune` есть строгий приоритет: Extended Bukkit → Alt Fortune → Percent Gradient. Ветви соединены `else if`, поэтому одновременное включение нескольких не суммирует эффекты. Без положительного уровня функция не меняет стек. Значения по умолчанию в коде: общий Fortune включён, Extended Bukkit включён, Alt и Gradient выключены, общий множитель 1, лимит 0, диапазон случайного фактора 70–110%. [Порядок и входные условия](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2998-L3056); [Последняя ветка](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3209-L3235); [Значения по умолчанию](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/autofeatures/AutoFeaturesFileConfig.java#L345-L403).

### Extended Bukkit

Применяется только при `F > 3` и уже имеющемся количестве `q > 1`. Формула кода: `a = round(floor(F / 3) × U(low, high))`; при ненулевом лимите ограничивается `a`; результат `q' = trunc(q × a × global)`. Если вычисленный результат <= 0, вызывающая функция не заменяет исходное количество. Важная деталь: `fortuneLevel / 3` выполняется как целочисленное деление Java, хотя переменная результата — double. При F=4 и F=5 до случайного фактора получается 1, при F=6 — 2. [Формула Extended Bukkit](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3276-L3347); [Применение результата](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3029-L3042).

Сам Bukkit определяет исходные drops с переданной киркой. Отдельно доказывать по одному исходнику, что каждая версия Bukkit применяет Fortune одинаково, нельзя. Этот режим зависит от версии Minecraft/Bukkit и от drops, собранных интеграциями.

### Alt Fortune

Обычная группа ресурсов получает `q' = max(1, trunc(q × M × global))`. Для перечисленных руд/ресурсов (или всех при соответствующем флаге) `M` рассчитывается отдельной функцией. Специальная группа растений, glowstone/redstone и ряда материалов получает `M = nextInt(F)`, то есть целое 0…F−1, с отдельными ограничениями для glowstone/sea lantern/melon. Поэтому фактическое поведение нельзя заменить общим «Fortune всегда увеличивает всё». [Специальная группа](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3063-L3103); [Основная группа и результат](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3121-L3194).

Точные вероятности для основной группы, выведенные из `nextInt(100)` (0…99) и сравнений `<=`:

| F | Распределение M |
|---|---|
| 1 | M=2: 34%; M=1: 66% |
| 2 | M=2: 26%; M=3: 25%; M=1: 49% |
| 3 | M=2: 21%; M=3: 20%; M=4: 20%; M=1: 39% |
| 4 | M=2: 17%; M=3…5: по 16%; M=1: 35% |
| 5 | M=2: 15%; M=3…6: по 14%; M=1: 29% |

Это расчёт по коду, а не округлённые проценты из комментариев. Для F≥6: `T = 80 + min(floor(F / 10), 100)`, `r = U[0,100)`; если `r <= T`, то `M = 1 + floor(r / (T / F))`, иначе `M=1`. Код ограничивает добавку к T, но не само T: после F=200 оно может стать больше 100. [Точная функция множителя](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3432-L3566).

### Percent Gradient

Пусть `Fmax` — максимальный уровень Gradient, `Bmax` — максимум бонуса, `p` — минимальный случайный процент. При `Fmax > 0 && Bmax > 1`: `F' = min(F, Fmax)`, `u = p/100 + (1-p/100)×U[0,1)`, `bonus = trunc(round(F'/Fmax × Bmax) × u)`, `q' = 1 + bonus`. Отрицательное p превращается в 0, p>100 — в 99; p=100 остаётся 100. [Формула Gradient](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3209-L3235).

Существенное ограничение массовой добычи: исходные drops к этому моменту уже объединены по типу, но Gradient **перезаписывает количество одним `1 + bonus`**, не умножая на число добытых блоков. Например, объединённые 100 единиц одного материала заменяются результатом одного расчёта. Это подтверждённое поведение данной ветки, которое не следует переносить в Roblox как желательный баланс.

В классе также есть `getDropCount(F) = 1 + nextInt(F+1)` для F>0 и 1 для F=0. Основной просмотренный путь `calculateFortune` эту функцию не вызывает; её наличие не означает, что весь плагин использует равномерный бонус 1…F+1. [Отдельная функция getDropCount](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L335-L358).

## 4. Токены и массовая добыча

Токены Prison находятся в `PlayerCachePlayerData`, отдельно от денег SellAll и API TokenEnchant. По умолчанию `tokensEnabled=false`, `tokensBlocksPerToken=100`. [Настройки токенов](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/autofeatures/AutoFeaturesFileConfig.java#L260-L263).

При успешном учёте блока `countBlocksMined` вызывает `mine.incrementBlockMiningCount` и затем `PlayerCache.addPlayerBlocks(..., quantity=1)`, только если `ApplyToPlayersBlockCount` включён. Для исходного блока и каждого подтверждённого блока взрыва выполняется один и тот же счётчик. Повторный учёт ограничен `isCounted` и результатом mine.incrementBlockMiningCount. [Проход по блокам](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L208-L231); [Условия учёта](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L1093-L1118).

Далее `PlayerCache.addPlayerBlocks` вызывает `PlayerCachePlayerData.addBlock`. Там увеличивается `blocksTotal`, записывается тип и шахта, затем рассчитываются токены. [Вызов кеша](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCache.java#L411-L430); [Учёт блоков игрока](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCachePlayerData.java#L351-L370).

Формула при включённых токенах и `B = blocksPerToken > 0`: `delta = blocksTotal − tokensLastBlocksTotals`; `earned = floor(delta / B)`; если earned≥1, `tokensLastBlocksTotals += earned×B`, после чего токены зачисляются. Остаток прогресса сохраняется.

Это означает: 150 засчитанных блоков при B=100 дают 1 токен и остаток 50; следующие 50 дают ещё 1 токен. Размер стека после Fortune, AutoSmelt или AutoBlock в этой формуле не используется. Массовая добыча не обязана быть одним ударом для токенов — важен каждый засчитанный физический блок. [Формула токенов](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCachePlayerData.java#L496-L525).

По умолчанию событие включает `ApplyToPlayersBlockCount=true`, но бомба может заменить его своей настройкой. Если этот флаг выключен, основной просмотренный путь не добавляет эти блоки в статистику игрока и, следовательно, не создаёт за них токены этим способом. [Значение по умолчанию](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/api/PrisonMinesBlockBreakEvent.java#L180-L208); [Переопределение для бомбы](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L337-L339).

Особый переход: если `tokensLastBlocksTotals==0`, а общих блоков уже >10000, базовая отметка выставляется в `blocksTotal-currentBatch`, чтобы не начислять токены за всю прошлую добычу. Если отметка выше общего числа блоков, она зажимается к общему числу. [Переход и защита отметки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCachePlayerData.java#L503-L513).

Поиск основных путей не устанавливает, какие сторонние магазины/зачарования тратят эти токены на конкретном сервере. Собственные TokenEnchant API и токены PlayerCache нельзя автоматически считать одной валютой.

## 5. Особенности, которые стоит исправить в собственной реализации

Ниже сначала факт кода, затем предложение; это не результаты запуска:

- Включение AutoBlock и NormalBlock использует `enchantsPickup` вместо уже вычисленного `enchantsBlock`. Для Roblox должны быть отдельные права/апгрейды Pickup, Smelt и Compress. [Две проверки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L604-L621).
- `normalDropBlock` читает `includePlayerInventoryWhenSmelting`, хотя в конфиге и диагностике существует отдельная настройка Blocking. Для Roblox нужно одно явно названное поле для каждого действия. [Обе настройки](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L624-L625); [Фактически читаемое поле](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L2614-L2618).
- Gradient теряет размер объединённого стека; Extended Bukkit ступенчато делит F на 3; точные вероятности Alt расходятся с округлёнными комментариями. Для Roblox сначала выбрать одну явную формулу и применять её к подтверждённой добыче, сохраняя смысл количества.
- Добавка кремня использует `nextInt(100) <= threshold`: nominal 10/14/25 превращаются в 11/15/26%. При F=3 или F=4 код вызывает `nextInt(floor(F/5)) = nextInt(0)`, что при достижении ветки приводит к IllegalArgumentException. Это статически видимый дефект, запуск не проводился. [Добавка кремня](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L3705-L3745).
- Дубликаты drops объединяются только по `getName()`, а не по полной метаинформации. Для Roblox надо хранить ресурс по стабильному resourceId, а метаданные отдельного предмета учитывать отдельно. [Ключ объединения](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakMines.java#L927-L948).

## 6. Предлагаемая модель Roblox для первого прототипа

Это проектное предложение, не утверждение об исходном плагине:

- Сервер хранит клетку шахты: mineId, координаты, resourceId, generationId, mined.
- Запрос игрока содержит цель; сервер проверяет доступ, дистанцию, скорость ударов, инструмент, актуальное поколение шахты и наличие блока.
- Обычная кирка и массовое умение собирают один формат результата: набор уникальных подтверждённых клеток.
- Для каждой клетки отдельно считаются базовые ресурсы и Fortune; затем ресурсы суммируются.
- Переплавка и сжатие — явные таблицы рецептов с сохранением остатков; продажа использует финальный ресурс и цену магазина.
- Деньги, токены, XP и физически добытые блоки хранятся раздельно. Токены зависят от acceptedBlockCount; Fortune увеличивает ресурс, но не число клеток.
- Повторная отправка запроса на уже обработанную клетку не приносит добычу повторно; сброс шахты меняет generationId.

Так сохраняется узнаваемый цикл Prison, при этом перенос не зависит от Bukkit listeners, Minecraft item stacks и сторонних плагинов.

## 7. Сохранённые исходники

Все дополнительные исходники получены через GitHub fetch по зафиксированной ревизии и сохранены только внутри `supplemental/mining/` с исходными относительными путями. README и source-manifest не изменялись этим разбором.

| Относительный путь под supplemental/mining | Git blob SHA |
|---|---|
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java` | `0e43ba34dec39d43f811b56cb722b04c9c9ba02d` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerBlockBreakEvents.java` | `d566a96ee3865247bf8ba6554cf467f98d1812d6` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java` | `014e20770a882389d2ca7edcc70c8780c210b5e3` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java` | `06f6977ff08a80eafb0219666dbedfb2f04dd814` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakPlayerManualCore.java` | `5d5e0f5513cf8ab587d15297849ca4d9608470ff` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakMines.java` | `bacd2cfc13f786e2d04038d484684ec0a22273ee` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventListener.java` | `89b12686bfa664723aa9af280037b09b3daba0f0` |
| `prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCache.java` | `8d07958c3be90ab4a7e6e72717ea6e58e4607504` |
| `prison-core/src/main/java/tech/mcprison/prison/cache/PlayerCachePlayerData.java` | `9352102c8565c9df588dc6f0e0ec6ad482f3c297` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/SpigotUtil.java` | `15129baf5a736cca0c6e880bfd6f4309b1715e0a` |
| `prison-spigot/src/main/java/tech/mcprison/prison/spigot/api/PrisonMinesBlockBreakEvent.java` | `31380e7562ff86018b7ef1f3322137a8fbe98b66` |

Дополнительно использован уже сохранённый `reference/prison-core/src/main/java/tech/mcprison/prison/autofeatures/AutoFeaturesFileConfig.java`.

