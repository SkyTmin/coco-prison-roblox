# Бомбы и рюкзаки: статический аудит Prison

Дата разбора: 18.10.2026. Репозиторий: PrisonTeam/Prison. Зафиксированная ревизия: `6914aa0a687c26a44e10d150ae5e4b17bf733b04`.

Прочитаны выбранные исходники через GitHub connector. Плагин, Minecraft и сервер не запускались. Ниже «подтверждено» означает поведение прочитанного пути кода; работа конкретной серверной конфигурации и интеграций требует отдельного запуска. Исходники добавлены только в `supplemental/bombs-backpacks/` с сохранением путей репозитория. Индекс файлов и blob SHA: `supplemental/bombs-backpacks/source-index.json`. Основной README и source-manifest не менялись.

## Что входит в механику бомб

Бомба — расходуемый предмет с собственной конфигурацией геометрии, шанса удаления блока, задержки, псевдоинструмента, cooldown, списков шахт и авто-продажи. При активации код уменьшает количество предметов в руке на один, обновляет инвентарь и передаёт детонацию в анимационную задачу. Обработчик не запускает обычный TNT-взрыв: он рассчитывает набор блоков и создаёт собственное `ExplosiveBlockBreakEvent`. [PrisonUtilsMineBombs.java:L1482](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombs.java#L1482); [PrisonUtilsMineBombs.java:L1511](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombs.java#L1511); [PrisonUtilsMineBombsTasks.java:L259](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L259).

### Формы и радиус

В активном перечислении ровно девять вариантов:

| Форма | Выбор блоков |
|---|---|
| `sphere` | Заполненный шар. |
| `sphereHollow` | Оболочка шара с внутренним радиусом. |
| `disk_x`, `disk_y`, `disk_z` | Заполненный круг толщиной в один слой вдоль соответствующей фиксированной оси. |
| `ring_x`, `ring_y`, `ring_z` | Кольцо толщиной в один слой с внутренним радиусом. |
| `cube` | Кубическая область с отдельным смещением по вертикали, описанным ниже. |

Основание: [MineBombs.java:L40](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombs.java#L40); фактический выбор алгоритма: [PrisonUtilsMineBombsTasks.java:L361](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L361). Наличие `calculateCylinder` не означает готовую форму цилиндра: метод возвращает пустой список, а в перечислении цилиндра нет. [MineBombs.java:L693](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombs.java#L693).

Для шара координаты блоков удовлетворяют:

```text
dx² + dy² + dz² <= radius²
для hollow дополнительно:
dx² + dy² + dz² >= inner²
inner = radiusInner, если radiusInner != 0,
иначе inner = radius - 1
```

Расчёт идёт по целочисленным координатам блоков и включает границы. Диаметр ограничивающего куба — `2r + 1` блоков, но сам шар занимает только точки, прошедшие проверку расстояния. Для дисков/колец одна из координат остаётся равной координате центра. [MineBombs.java:L713](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombs.java#L713).

Особенность `cube`: X/Z идут от `center-r` до `center+r`, а Y — от `centerY+1` вниз до `centerY+1-2r`, с остановкой на Y=0. Это не куб, симметричный центру по всем осям. При достаточно большом Y число точек равно `(2r+1)^3`; возле нулевой высоты оно меньше. [MineBombs.java:L759](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombs.java#L759).

После геометрии для каждого кандидата вызывается случайная проверка `nextDouble()*100 <= removalChance`; воздух исключается. Поэтому радиус задаёт область кандидатов, а не гарантированное число добытых блоков. [PrisonUtilsMineBombsTasks.java:L439](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L439).

### Cooldown и ограничения доступа

- Cooldown хранится в общей статической карте по UUID игрока. Он общий для типов бомб, не привязан к отдельной шахте или предмету. Успешный `findBombByName(..., true)` запускает его до фактической детонации; повторная попытка выбрасывает `MineBombCooldownException`. [MineBombs.java:L287](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombs.java#L287); [MineBombCooldownTask.java:L15](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombCooldownTask.java#L15).
- Задача уменьшает остаток раз в один tick (`DELAY_TICKS=1`). Комментарий про «5 ticks» в этом файле устарел; исполнение использует константу 1. При нормальных 20 TPS 60 ticks соответствуют 3 секундам, но при лаге длительность в реальном времени увеличится. [MineBombCooldownTask.java:L13](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombCooldownTask.java#L13); [MineBombCooldownTask.java:L50](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombCooldownTask.java#L50); [MineBombCooldownTask.java:L67](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombCooldownTask.java#L67).
- Выдача/проверка предмета могут вызывать поиск с `enableCooldown=false`; не каждый поиск бомбы расходует cooldown. Для `give` это указано непосредственно в коде. [PrisonUtilsMineBombs.java:L912](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombs.java#L912).
- Точка активации должна быть найдена в шахте; отдельно проверяется `mine.hasMiningAccess(player)`. Затем объединяются запрет конкретной бомбы и глобальный `prison-mines.mine-bombs.prevent-usage-in-mines`. `allowedMines` отменяет запрет для указанной шахты; это исключение из запретов, а не самостоятельный строгий allowlist. [PrisonBombListener.java:L614](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonBombListener.java#L614).
- При отключённом обработчике Prison explosion активация прекращается с сообщением в лог. Обработчик события регистрируется только при включённом AutoManager и подходящем event priority. [PrisonUtilsMineBombs.java:L1321](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombs.java#L1321); [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L54](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L54).
- Геометрический генератор сам не обрезает список до границ шахты. Затем общий `validateEvent` фильтрует raw-блоки: исключает исходную координату, блоки вне текущей `mine.isInMineExact`, неразрушаемые и пустые блоки; проверяет target/matched/already-mined и собирает подтверждённые списки. Часть с `target == null` попадает в explodedBlocks без targetExplodedBlocks, поэтому сырой список не равен списку награждаемых target-блоков. [OnBlockBreakEventCore:L617](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/block/OnBlockBreakEventCore.java#L617). Это не runtime-проверка reset-race или сторонних event handlers. [PrisonUtilsMineBombsTasks.java:L352](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L352); [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L247](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L247); [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L341](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L341).

### Добыча, продажа и счётчик блоков

У бомбы свой псевдоинструмент: на него ставятся её Fortune, Unbreaking и Efficiency; если инструмент не указан/не найден, выбирается diamond pickaxe. В событие передаётся этот инструмент. Износ отключён, поэтому взрыв не должен ломать настоящую кирку игрока. Точный выход определяется общим пайплайном добычи и серверными настройками Fortune/дропов, а не формулой «один кандидат = один предмет». [PrisonUtilsMineBombsTasks.java:L285](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L285); [PrisonUtilsMineBombsTasks.java:L300](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L300); [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L311](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L311); [AutoManagerFeatures.java:L1327](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1327).

`autosell` бомбы передаётся как `forceAutoSell`. Он обходит пользовательское выключение autosell, но фактическая продажа по этому пути всё равно требует включённого SellAll. Продажная стоимость и возможность продать зависят от магазина. Непроданные предметы в ветке AutoPickup отправляются в инвентарь, затем в разрешённые рюкзаки; в обычной ветке остаётся мировой дроп. [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L328](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L328); [AutoManagerFeatures.java:L1079](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1079); [AutoManagerFeatures.java:L1127](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1127); [AutoManagerFeatures.java:L1198](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1198); [AutoManagerFeatures.java:L1382](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/AutoManagerFeatures.java#L1382).

`applyToPlayersBlockCount` определяет, учитывать ли взорванные блоки в счётчике добычи игрока; это отдельная настройка от выдачи добычи/денег. [MineBombData.java:L230](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/bombs/MineBombData.java#L230); [AutoManagerPrisonsExplosiveBlockBreakEvents.java:L337](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/autofeatures/events/AutoManagerPrisonsExplosiveBlockBreakEvents.java#L337).

Поля задержки `fuseDelayTicks` и `cooldownTicks` независимы. Задача детонации планируется с задержкой `fuseDelayTicks`; запуск идёт через анимационный callback. Здесь не измерена общая реальная задержка от клика до добычи с учётом каждого animation pattern. [PrisonUtilsMineBombsTasks.java:L459](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombsTasks.java#L459); [PrisonUtilsMineBombs.java:L1511](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/utils/PrisonUtilsMineBombs.java#L1511).

### Примеры из сохранённого mineBombsConfig.json

Это значения файла в репозитории, не доказанный баланс конкретного работающего сервера: конфигурация загружается/может обновляться и редактируется администратором.

| Бомба | Форма | r / inner | Удаление | Fortune | Fuse ticks | Cooldown ticks | Forced autosell |
|---|---|---:|---:|---:|---:|---:|---|
| smallbomb | sphere | 2 / 0 | 100% | 0 | 100 | 10 | false |
| mediumbomb | sphere | 5 / 0 | 100% | 3 | 100 | 60 | false |
| largebomb | sphereHollow | 12 / 3 | 100% | 3 | 100 | 60 | false |
| cubebomb | cube | 2 / 0 | 100% | 7 | 300 | 20 | false |
| oofbomb | sphereHollow | 21 / 3 | 100% | 13 | 260 | 60 | true |
| wimpybomb | sphere | 2 / 1 | 30% | 0 | 300 | 5 | false |

Источники: [smallbomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L909), [mediumbomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L283), [largebomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L174), [cubebomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L89), [oofbomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L469), [wimpybomb](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/module_conf/mines/mineBombsConfig.json#L1106). У `wimpybomb` inner не влияет на заполненный `sphere`.

## Старые рюкзаки: подтверждённый путь

`BackpacksUtil` — действующая реализация на Bukkit Inventory и YAML `backpacks/backpacksData.yml`. Глобальное включение читается из `backpacks`. Значение по умолчанию для размера в генераторе конфига — 54 слота; AutoPickup и режим нескольких рюкзаков в генераторе выключены, лимит для нескольких рюкзаков — 2. Пример в документации содержит другие значения (AutoPickup=true, multi=true, 4); для генерации новых настроек точнее смотреть исходник. [BackpacksUtil.java:L43](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L43); [BackpacksConfig.java:L77](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/configs/BackpacksConfig.java#L77); [prison_docs_117_setting_up_backpacks.md:L58](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/docs/prison_docs_117_setting_up_backpacks.md#L58).

Вместимость здесь измеряется слотами стаков, не общим числом ресурсов. Обычные разрешённые размеры — 9, 18, 27, 36, 45, 54. Административная команда размера и resize проверяют кратность 9 и верхний предел 54; допускается значение 0, но чтение размера заменяет его на 9. Нижняя граница отрицательных значений явно не проверена; не следует переносить такую валидацию буквально. [PrisonSpigotBackpackCommands.java:L109](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/commands/PrisonSpigotBackpackCommands.java#L109); [BackpacksUtil.java:L941](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L941); [BackpacksUtil.java:L1039](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L1039).

Увеличение размера реализовано как настройка администратора и permission `prison.backpack.size.<size>`. Метод выбирает наибольшее числовое permission, округляет вверх до кратного 9 и **возвращает его как итоговый размер**. Комментарий называет это max-ограничением, но код не берёт `min(current, permission)`. В этом пути не найдены цены апгрейдов, уровни, ресурсная стоимость или покупка вместимости игроком. Для Roblox экономику улучшений потребуется спроектировать. [BackpacksUtil.java:L1085](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L1085); [PrisonSpigotBackpackCommands.java:L109](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/commands/PrisonSpigotBackpackCommands.java#L109).

Режим нескольких рюкзаков имеет отдельные ID и лимит числа рюкзаков на игрока. Есть административные set/add/decrement лимита. Сам факт нескольких рюкзаков не означает их автоматическую покупку. [BackpacksUtil.java:L130](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L130); [BackpacksUtil.java:L152](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L152); [PrisonSpigotBackpackCommands.java:L160](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/commands/PrisonSpigotBackpackCommands.java#L160).

Путь AutoPickup:

```text
добыча -> инвентарь игрока
       -> остаток в встроенные рюкзаки (если включены AutoPickup и текущий мир)
       -> остаток в Minepacks
       -> остаток в Backpack API
       -> вернуть непоместившееся вызывающему коду
```

При multi-backpacks код перебирает ID, при одиночном — `id=null`; после заполнения каждого рюкзака сохраняет его. Встроенный рюкзак принимает только overflow после основного инвентаря. [SpigotUtil.java:L162](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/SpigotUtil.java#L162).

При ручном изменении открытого рюкзака содержимое сохраняется при закрытии окна, если оно было отмечено изменённым. При включённом `BackPack_Lose_Items_On_Death` смерть сбрасывает основной и дополнительные рюкзаки; по умолчанию настройка false. [BackpacksListeners.java:L55](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksListeners.java#L55); [BackpacksListeners.java:L72](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksListeners.java#L72); [BackpacksConfig.java:L87](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/configs/BackpacksConfig.java#L87).

## Продажа содержимого рюкзака

Основной `SellAllUtil.sellPlayerItems` сначала продаёт основной инвентарь, затем при включённом `Options.Sell_Prison_BackPack_Items` вызывает встроенный `BackpacksUtil.sellInventoryItems`. Отдельные ветки существуют для Minepacks и Backpack API. [SellAllUtil:L792](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/sellall/SellAllUtil.java#L792); [SellAllUtil:L811](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/sellall/SellAllUtil.java#L811).

Встроенный метод рюкзака жёстко выбирает `id=null`, загружает основной Bukkit Inventory, передаёт его в общий `SellAllUtil.sellInventoryItems`, затем сохраняет изменённый инвентарь. В исходнике прямо оставлен WARNING: для нескольких рюкзаков нет корректного выбора ID/согласия на продажу. Поэтому утверждение «SellAll автоматически продаёт все встроенные дополнительные рюкзаки» этим кодом не подтверждается. [BackpacksUtil.java:L1653](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/BackpacksUtil.java#L1653).

Общий метод определяет продаваемые стаки, создаёт чеки `SellAllData` и удаляет только их. Цена:

```text
quantity × shopSalePrice × playerMultiplier
```

Предмет должен присутствовать в SellAll shop; зачарованные предметы исключены, lore допускается только настройкой товара. Это расчёт и удаление содержимого; зачисление суммы выполняется внешним SellAll-вызовом, поэтому нельзя вызывать низкоуровневый метод отдельно как законченную транзакцию. [SellAllUtil:L883](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/sellall/SellAllUtil.java#L883); [SellAllUtil:L950](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/sellall/SellAllUtil.java#L950); пример внешнего зачисления: [SellAllUtil:L2473](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/sellall/SellAllUtil.java#L2473).

## Новые рюкзаки: модель не равна работающей системе

| Часть | Что подтверждено |
|---|---|
| `PlayerBackpack` | Модель стандартного inventory и silo-содержимого: inventorySize, maxSiloSlots, maxSiloSize, maxTotalSize. Поля имеют getters/setters; здесь нет реализации соблюдения лимитов или покупки улучшений. |
| `BackpackEnums` | Перечислены флаги soulbound, pickup, sellall, trade, rename, multiple и другие. Перечисление не доказывает работающую механику каждого флага. |
| `BackpackCacheFiles` | Новый путь хранения `data_storage/backpackCache`. |
| `BackpackCacheLoadPlayerTask` | Читает JSON; блок `synchronized` после чтения пустой. |
| `BackpackConverterOldPrisonBackpacks` | Получает старые рюкзаки и логирует. В прочитанном методе нет записи конвертированных данных. |
| `NewBackpacksUtil` | Тело функциональности закомментировано; активного нового аналога старого util в этом файле нет. |

Основания: [PlayerBackpack.java:L20](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/backpacks/PlayerBackpack.java#L20); [BackpackEnums.java:L5](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/backpacks/BackpackEnums.java#L5); [BackpackCacheFiles.java:L10](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/backpacks/BackpackCacheFiles.java#L10); [BackpackCacheLoadPlayerTask.java:L17](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/backpacks/BackpackCacheLoadPlayerTask.java#L17); [BackpackConverterOldPrisonBackpacks.java:L11](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-core/src/main/java/tech/mcprison/prison/backpacks/BackpackConverterOldPrisonBackpacks.java#L11); [NewBackpacksUtil.java:L6](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/backpacks/NewBackpacksUtil.java#L6). Документация этой ревизии сама сообщает о планируемом переписывании рюкзаков. [prison_docs_117_setting_up_backpacks.md:L8](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/docs/prison_docs_117_setting_up_backpacks.md#L8).

Нельзя считать silo-вместимость, торговлю целым рюкзаком, индивидуальные toggle или новый конвертер готовой системой только по этим названиям. В подтверждённом пути продажи и pickup используется старый `BackpacksUtil`.

## Что переносить в Roblox как собственный дизайн

Предложение для реализации, не описание готового Roblox-кода:

1. Сервер авторитетно принимает использование бомбы, проверяет заряд, доступ к шахте и cooldown, затем атомарно расходует заряд.
2. Геометрия даёт кандидатов; каждый кандидат ограничивается своей шахтой, текущим поколением reset и состоянием блока. Удаление/выдача добычи выполняются один раз.
3. Сила кирки и Fortune бомбы задаются отдельно. Награда определяется типом реально разрушенного блока и таблицей добычи.
4. Для рюкзака удобно использовать числовую вместимость ресурсов, а не переносить Bukkit-слоты. Цены и ступени апгрейда требуют самостоятельного баланса.
5. Продажа должна одной серверной операцией списать конкретные ресурсы и зачислить деньги; явно задать, какие рюкзаки участвуют. Forced autosell — отдельная настройка бомбы.
6. Проверить после реализации: две бомбы по одному блоку, взрыв на краю/во время reset, полный рюкзак, повторная продажа, разрыв соединения во время транзакции.

Runtime-части, которые остаются неизвестными: итоговая совместимость всех event priorities, сторонние permissions/economy/backpack-плагины, жизненный цикл каждой анимации, коллизии разных шахт, поведение при отключении сервера между удалением предмета и зачислением награды. Сам статический разбор не является проверкой запуска.

