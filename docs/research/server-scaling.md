# Масштабирование сервера и сеть: как это делают другие Roblox-игры

Исследование для coco-prison-roblox (шахты по ~12 000 Part-блоков, серверное копание до 20 блоков/с на игрока).
Дата: 2026-10-21. Номера в квадратных скобках — ссылки на раздел «Источники».

## Кратко: что важнее всего для нашей игры

- **Главный риск для трафика — полный профиль на клиент.** Документация Roblox прямо говорит: шлите только изменённое, а не весь инвентарь при каждой покупке [3]. При 10 отправках/с полный профиль даже в 2–5 КБ даёт 20–50 КБ/с на игрока. Это больше, чем всё остальное вместе. Нужны дельты.
- **Цена разрушения блоков растёт как O(N²).** Каждый удалённый Part реплицируется всем клиентам, у которых он загружен. 30 игроков × 20 блоков/с = 600 удалений/с, и каждое уходит 30 клиентам. Помогает StreamingEnabled (сервер синхронизирует меньше изменений [5]) и/или компактный пакет «индекс клетки + тип» вместо репликации Instance.
- **Сброс шахты (12 000 перетипирований за кадр) — это всплеск трафика и нагрузки.** Документация советует распределять создание/изменение больших деревьев по кадрам [3]. Ещё лучше рассылать клиентам компактную раскладку шахты (около 12 КБ буфера) и строить её на клиенте.
- **Опытные разработчики хранят на сервере данные, а не визуал.** Клиенты рендерят сами [10][11][12]. В шахтах создают только «видимые» блоки, у которых открыт хотя бы один сосед [8][9].
- **Лимиты Roblox:** около 500 запросов/с на клиента, общие для всех RemoteEvent [1]; UnreliableRemoteEvent не больше 1000 байт [2]; память сервера 6,25 ГиБ + 100 МиБ × пик игроков [6]. Наши 20 DigStart/с укладываются в лимит с большим запасом.
- **Эффекты (частицы, звук ломания) — только на клиенте**, через UnreliableRemoteEvent или вообще без сети: клиент сам видит, что блок исчез [2][3].
- **Античит:** token bucket на сервере [13], проверка «не быстрее теоретического минимума» с допуском, как BreakSpeedLimiter в Minecraft-античитах [16][17]. Line of sight проверять только по статичной геометрии и с допуском на пинг [13]. Сначала нейтрализовать (откатить блок), банить только по накопленному счёту подозрений [14].
- **Размер сервера.** Публично доступно до 200 игроков; 700 — только закрытая программа [7]. Для «тяжёлой» копательной игры разумно начать с 20–30 и масштабировать числом серверов. Межсерверные функции — через MessagingService/MemoryStore [19][20].

---

## 1. Лимиты платформы Roblox

| Что | Значение | Источник |
|---|---|---|
| Rate limit клиент→сервер | ~500 запросов/с на клиента; лимит **общий** для всех RemoteEvent (и отдельно для всех Unreliable) | [1] |
| Переполнение очереди | RemoteEvent: лишнее обрабатывается позже, порядок сохраняется. Unreliable: лишнее отбрасывается. При полной очереди — «Remote event invocation error» | [4] |
| Payload UnreliableRemoteEvent | >1000 байт — отбрасывается; buffer сжимается движком, поэтому размер заранее не всегда известен | [2] |
| «50 КБ/с на игрока» | Официально **не задокументировано** (было в старой статье Dev Hub, потом удалено). Это фольклор, используйте как ориентир, а не жёсткий лимит | [21] |
| Накладные расходы пустого RemoteEvent | ~9 байт по замерам сообщества; число в Luau — 8 байт (double) | [22] |
| Память сервера | 6,25 ГиБ + 100 МиБ × (пик подключённых игроков); при превышении сервер падает | [6] |
| Бюджет кадра | 60 FPS → 16,67 мс; код на 100 мс каждый кадр = 10 FPS. Тяжёлую работу дробить по ~5 мс на кадр | [23] |
| Heartbeat | «Вызывайте код на событиях RunService экономно»; тяжёлое — через task.wait, Parallel Luau, native codegen | [3] |
| Макс. игроков на сервер | Публично до 200; 700 — закрытая opt-in программа, сейчас недоступна | [7] |
| EditableMesh | ≤60 000 вершин и ≤20 000 треугольников на меш; на клиенте строгий бюджет памяти; коллизия обновляется только через CreateMeshPartAsync | [24] |

Что ещё говорит документация по производительности [3]:
- Не реплицировать каждый кадр то, что не изменилось. Троттлить ввод и слать **только изменения**.
- Создание и удаление больших деревьев Instance в рантайме «может сильно нагружать сеть». Делить на чанки и грузить по кадрам.
- Визуальные эффекты держать на клиенте. Tween на сервере реплицирует свойство каждый кадр, поэтому tween делать на клиенте.
- Следить за LuaHeap и InstanceCount; отключать connection'ы; чистить таблицы ушедших игроков.

## 2. Воксельные / блочные миры на Roblox

**Как хранят блоки:**
- **Только видимые блоки.** Полностью окружённые блоки не создаются; при копании проверяются 6 соседей, и открытые блоки создаются. Соседей ищут через 3D-таблицу, а не raycast. Автор совета пишет, что это «сработало отлично» [8]. Тот же подход у Infinite Mining Kit (по мотивам Azure Mines от berezaa): блоки генерируются по мере копания [9].
- **Сервер = данные, клиент = визуал.** RTS-разработчики держат на сервере только позиции и HP, клиент создаёт модели и эффекты. Так тянут 800+ юнитов; приём из поста «reduced bandwidth usage by 60x» [10]. Mineverse (Minecraft-клон) рендерит все Part на клиенте [11].
- **Voxel destruction.** Перенос создания частей на клиент «полностью убрал сетевую нагрузку». Сервер шлёт исходные данные и seed, клиенты детерминированно строят результат; части кладут под Camera, чтобы они не реплицировались [12].
- **Greedy meshing** (склейка одинаковых соседних блоков в один Part): в одной сцене 15 931 instance → 508 [25]. Хорошо для однородных стен, хуже для пёстрой руды и для частого копания (кусок приходится пересобирать).
- **EditableMesh** — вариант для клиентского рендера чанков (лимиты см. выше [24]). Для серверной коллизии неудобен: коллизия обновляется только пересозданием MeshPart.
- **Удаление пачками.** Массовые `:Destroy()` в одном кадре давали GC-фризы сервера. Решение: сразу `Parent = nil`, а `Destroy` — из очереди, не больше 15 штук на Heartbeat. По словам автора, это «полностью убрало фризы». Пулинг частей — ещё один вариант [26].
- **StreamingEnabled.** Сервер тратит меньше времени и трафика на синхронизацию, клиент обновляет меньше лишних instance. Значения по умолчанию: MinRadius 64, TargetRadius 1024 [5]. **Важно для нашего предсказания:** локальные изменения клиента (скрытый блок) теряются, если instance выгрузился и загрузился снова [5]. Это безопасно, потому что сервер к тому моменту уже удалил блок или вернул его.
- **Occlusion culling** в движке есть и расширяется [27]. При десятках тысяч мелких частей узким местом может стать сам culling (VisibleQuery), поэтому меньше Part на клиенте — лучше.

**Как реплицируют изменения блоков:**
- Компактно: массивы вместо словарей, int16 через `buffer` (2 байта вместо 8), обновления пачкой в одном `FireAllClients` раз в N кадров [10].
- Альтернатива: клиент сам выполняет разрушение, сервер рассылает только итог [12].

## 3. Сетевые паттерны

- **Батчинг.** Копите события за кадр и шлите одним вызовом, упаковав в бинарную строку или buffer с однобайтовым opcode [22]. Пример из RTS: позиции всех юнитов одним `FireAllClients` в buffer [10].
- **Дельты вместо полного состояния.** Официальная рекомендация [3]. ReplicaService (loleris) построен на «мутаторах»: сервер меняет путь в таблице, и клиенты получают изменение, а не всё состояние [28].
- **UnreliableRemoteEvent** — для «эфемерных событий и эффектов, которые актуальны короткое время» и для непрерывно меняющихся данных. Не гарантирует ни доставку, ни порядок [2]. Если порядок важен, добавляйте счётчик или timestamp и отбрасывайте старое [4].
- **Пакетные библиотеки** (все цифры — заявления авторов, не независимые замеры):
  - **Zap** (IDL-компилятор): упаковывает данные в buffer «без оверхеда», «доля от трафика», валидирует входящие данные; события Reliable/Unreliable [29][30].
  - **Blink** (IDL): «в 1,6–3,7 раза быстрее Roblox», «в 1000 раз меньше трафика»; батчит. Автор сам признаёт, что замер kbps неточный [31].
  - **ByteNet** (ffrostfall): сериализация в buffer, строгая типизация; «намного быстрее не-buffer библиотек вроде BridgeNet2» [32].
  - **BridgeNet2:** репозиторий архивирован 21.02.2024 [33]. Для нового кода не брать.
  - Бенчмарк автора Packet (ByteNet 0.4.3, Zap 0.6.19, Blink 0.17): по трафику лидируют Blink и Zap; дефолтные remotes хуже всех [34].
  - Red / Warp: первоисточники в поиске не нашлись, данных нет.

## 4. Античит и задержка

- **Сервер — источник истины.** Каждый аргумент remote валидировать: тип и класс Instance, его место в DataModel, `math.isfinite` для чисел (NaN проходит проверки типов) [13].
- **Rate limit — token bucket на сервере.** Ёмкость = допустимый всплеск, пополнение = capacity/window; ведро очищать при выходе игрока. На клиентский лимит не полагаться [13].
- **Минимальное время действия.** Проверять, что клиент не завершает действие быстрее возможного [13]. Аналог из Minecraft: Intave BreakSpeedLimiter считает легитимное время ломания и отменяет более быстрые поломки. Авторы признают ложные срабатывания при скачущем пинге [16]. Stratum Block Break Guard хранит частичный прогресс и даёт grace-окно 0,5 с [17].
- **Дистанция и задержка.** «Сервер и клиент будут немного расходиться из-за задержки, нужен дополнительный допуск». Line of sight проверять **только по статичной геометрии**, чтобы не отклонять легитимные действия из-за задержки [13].
- **Наказание.** Сначала нейтрализовать (откатить или резинкой вернуть), затем копить счёт подозрений. Kick/ban — только после множества разных детекций; по клиентским детекциям не банить никогда [14].
- **Lag compensation / prediction.** У Roblox есть новая модель server authority с предсказанием и rollback на клиенте [15]. Готовой «перемотки» для хитов документация не даёт: нужна своя логика (допуски выше).

## 5. Горизонтальное масштабирование

- **Размер сервера задаётся на уровне place.** В одной игре могут быть places с разным размером; `Players.MaxPlayers` читается из скрипта [35]. Из скрипта лимит не меняется: для ивентов делают отдельный place с большим размером и телепортируют туда [36].
- **Reserved servers:** `TeleportOptions.ShouldReserveServer = true` или `ReservedServerAccessCode`; `TeleportAsync` принимает массив игроков (пати). Для reserved-серверов рекомендуются ретраи [18].
- **MessagingService:** сообщение ≤1 КБ; 600 + 240 × игроков сообщений/мин на сервер; подписок 20 + 8 × игроков; доставка best effort [19].
- **MemoryStore:** память 64 КБ + 1,2 КБ × пользователей; 1000 + 120 × CCU запросов/мин; значение ≤32 КБ. Кейсы: лидерборды (sorted map), межсерверная торговля и аукцион, матчмейкинг (queue) [20].
- **Заполнение серверов:** настройка Server Fill (Roblox optimized / Custom / None) и social slots [37].
- **Размеры серверов конкретных игр** (Mining Simulator, Pet Sim 99, Bedwars) первоисточниками подтвердить не удалось. Bee Swarm: 6 ульев на сервер, то есть фактически 6 игроков [38].

---

## Что сделать в нашей игре (по приоритету)

| # | Изменение | Ожидаемый эффект | Усилие |
|---|---|---|---|
| 1 | **Дельты профиля вместо полного профиля.** Сервер копит изменённые поля (путь → значение) и раз в 0,1–0,25 с шлёт одну пачку на игрока. Полный профиль — только при входе. | Трафик профиля падает с десятков КБ/с до сотен байт/с на игрока; меньше нагрузки на сериализацию | M |
| 2 | **Эффекты ломания — только на клиенте.** Частицы и звук для своих блоков проигрываются локально при предсказании; для чужих — по факту исчезновения Part или через один UnreliableRemoteEvent пачкой за кадр. Никаких серверных Sound/ParticleEmitter. | Минус серверные instance и их репликация; эффекты без задержки | S |
| 3 | **Сброс шахты по кадрам.** Перетипировать не больше ~500–1000 Part за Heartbeat (по бюджету ~2–4 мс), а не 12 000 сразу. Шахты без игроков рядом не трогать до прихода игрока. | Нет фриза сервера и всплеска трафика в момент сброса | S |
| 4 | **Token bucket на DigStart** (например, burst 25, пополнение 22/с) плюс проверка минимального времени ломания с grace ~0,3–0,5 с. Нарушение = откат блока и +очки подозрения, а не кик. | Защита от автокликеров и fast-break без ложных банов на лагающих игроках | S |
| 5 | **Включить StreamingEnabled** (если ещё нет) с разумным TargetRadius. Шахты другого ранга не стримятся игрокам, которые далеко. | Изменения блоков реплицируются только тем, у кого шахта загружена: O(N²) превращается примерно в O(игроков в шахте²) | M (нужен аудит WaitForChild и клиентских ссылок на Part) |
| 6 | **Пул вместо Destroy.** Сломанный блок не уничтожать, а прятать или переносить в серверный пул (`Parent = nil`) и переиспользовать при сбросе. Destroy, если нужен, — из очереди, ≤15 за кадр. | Нет GC-фризов и создания instance при сбросе | S–M |
| 7 | **Лёгкая проверка reach/LoS.** Расстояние от серверной позиции персонажа с допуском на пинг (+1–2 блока). LoS — DDA по сетке шахты (данные), а не Raycast по 12 000 Part. | Дешевле по CPU при 20 копаний/с × N игроков; меньше ложных отказов | M |
| 8 | **Пакетная сетевая библиотека (Zap или Blink)** для DigStart, дельт профиля и событий блоков. Типизированная схема, buffer, батчинг. | Меньше байт на сообщение, встроенная валидация | M |
| 9 | **Серверная модель шахты = buffer с типами (1 байт на клетку)**, клиентский рендер только видимых блоков. Изменения рассылаются пачками `{mineId, u16 index, u8 type}` раз в кадр; сброс = отправка 12-КБ раскладки или seed. Сервер валидирует по данным, без Part. | Максимальный выигрыш: тысячи Part уходят с сервера, трафик на блок ~3–4 байта, сброс почти бесплатен. Позволяет поднять размер сервера. | L |
| 10 | **Размер сервера 20–30 на старте, плюс нагрузочный тест** (боты или альт-аккаунты, Developer Console → ServerStats «Total Data KB/s», MicroProfiler → Network [39]). Увеличивать после замеров. Межсерверное (глобальный чат, лидерборд) — MessagingService/MemoryStore. | Предсказуемая нагрузка; решения по данным, а не на глаз | S |

Порядок внедрения: 1 → 2 → 3 → 4 → 6 → 5 → 7 → 8. Пункт 9 — архитектурная переделка; браться за неё, только если замеры после 1–8 упираются в Part и репликацию.

---

## Источники

1. RemoteEvent, раздел Throttling — https://create.roblox.com/docs/reference/engine/classes/RemoteEvent.md
2. UnreliableRemoteEvent — https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent.md
3. Improve performance — https://create.roblox.com/docs/performance-optimization/improve
4. Remote events and callbacks — https://create.roblox.com/docs/scripting/events/remote
5. Instance streaming — https://create.roblox.com/docs/workspace/streaming
6. Memory (формула памяти) — https://create.roblox.com/docs/projects/performance-optimization/memory ; анонс: https://devforum.roblox.com/t/even-more-server-memory/3293192 ; уточнение единиц: https://devforum.roblox.com/t/server-memory-formula-inaccurate-on-creator-docs/3913740
7. 700-player servers больше недоступны — https://devforum.roblox.com/t/is-it-still-possible-to-opt-into-700-player-servers/4210626 ; лимит 200 — https://devforum.roblox.com/t/increase-server-size/306199
8. Mining game optimization (только видимые блоки, 3D-таблица) — https://devforum.roblox.com/t/mining-game-optomization/3784771
9. Infinite Mining Ore Generation (Azure Mines-style) — https://devforum.roblox.com/t/infinite-mining-ore-generation/562669
10. RTS с 200+ юнитами: сервер = данные, buffer, батчинг — https://devforum.roblox.com/t/how-we-are-developing-an-rts-game-with-good-performance-for-more-than-200-units/3281168
11. Voxels in Roblox? (Mineverse: рендер на клиенте) — https://devforum.roblox.com/t/voxels-in-roblox/644824
12. Voxel destruction: сетевая нагрузка — https://devforum.roblox.com/t/voxel-destruction-help-me-optimise-network-usage/4047764
13. Securing the client-server boundary — https://create.roblox.com/docs/scripting/security/client-server-boundary
14. Server-side detection and consequencing — https://create.roblox.com/docs/scripting/security/server-side-detection
15. Server authority techniques — https://create.roblox.com/docs/projects/server-authority/techniques
16. Intave BreakSpeedLimiter (Minecraft) — https://docs.intave.ac/mechanics/checks-03-breakspeedlimiter.html
17. Stratum Block Break Guard (Minecraft) — https://github.com/StratumServer/Stratum/wiki/Feature:-Block-Break-Guard
18. Teleport between places — https://create.roblox.com/docs/projects/teleport
19. MessagingService (лимиты) — https://create.roblox.com/docs/reference/engine/classes/MessagingService
20. Memory stores — https://create.roblox.com/docs/cloud-services/memory-stores
21. Про «50 КБ/с» — https://devforum.roblox.com/t/remote-event-limitations/3882204 ; https://devforum.roblox.com/t/2597139
22. Оверхед remote и батчинг — https://devforum.roblox.com/t/i-have-question/3397777 ; https://devforum.roblox.com/t/ore-one-remote-event/569721/25
23. Design for performance — https://create.roblox.com/docs/performance-optimization/design
24. EditableMesh — https://create.roblox.com/docs/reference/engine/classes/EditableMesh
25. Greedy meshing — https://devforum.roblox.com/t/-/452717
26. Массовый Destroy и фризы — https://devforum.roblox.com/t/performance-degradation-after-mass-basepartdestroy-calls-with-getpartboundsinradius-%E2%80%94-best-practices-for-high-throughput-part-removal/4730759
27. Occlusion culling (Release Notes 690) — https://devforum.roblox.com/t/release-notes-for-690/3930113
28. ReplicaService (Mad Studio) — https://devforum.roblox.com/t/894736
29. Zap — https://github.com/red-blox/zap
30. Zap events config — https://zap.redblox.dev/config/events.html
31. Blink — https://devforum.roblox.com/t/2959671
32. ByteNet — https://github.com/ffrostfall/ByteNet
33. BridgeNet2 (архив) — https://github.com/ffrostflame/BridgeNet2/releases
34. Packet: бенчмарк библиотек — https://devforum.roblox.com/t/packet-networking-library/3573907
35. Server size на place — https://devforum.roblox.com/t/howserver-size/2669652 ; https://devforum.roblox.com/t/2499388
36. Reserved server с большим размером — https://devforum.roblox.com/t/2391983
37. Server Fill — https://devforum.roblox.com/t/roblox-is-creating-1-player-servers-over-filling-existing-ones-harming-interaction/3981365
38. Bee Swarm Simulator: ульи — https://bee-swarm-simulator.fandom.com/wiki/Hive
39. MicroProfiler: network — https://create.roblox.com/docs/performance-optimization/microprofiler/network
