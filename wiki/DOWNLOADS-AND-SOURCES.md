# Где скачать Prison: результат поиска

Проверено 18 октября 2026 года. Основной ориентир — старый Cristalix.

**Подтверждённой публичной сборки или исходников серверного Prison именно Cristalix пока не найдено.** Найдены и скачаны три разных материала. Их назначение проверено по содержимому, а не только по названию.

## 1. Ресурспак Cristalix Prison Classic

- [Страница на официальном форуме](https://forum.cristalix.gg/threads/29045/).
- [Публичная ссылка загрузки](https://drive.usercontent.google.com/download?id=1DR1kO6eiw0usdKNEdkDw10WgeEfK-7PL&export=download).
- Локально: [Cristalix-Prison-Classic-official-resourcepack.zip](downloads/Cristalix-Prison-Classic-official-resourcepack.zip), 5 396 482 байта, 354 записи ZIP.

Внутри действительно есть модели крысы, зомби и гиганта-зомби; текстуры мыла, туалетной бумаги, спальника, вакцины и четырёх ключей. Например:

| Файл в архиве | Что подтверждает |
| --- | --- |
| assets/minecraft/bedrock/rat/rat.model | Модель крысы |
| assets/minecraft/bedrock/giant/giant_zombie.model | Модель гиганта-зомби |
| assets/minecraft/bedrock/zombie/zombie2.model | Модель зомби |
| assets/minecraft/mcpatcher/cit/disease/soap.properties | Предмет мыла с NBT disease=soap |
| assets/minecraft/mcpatcher/cit/disease/toilet_paper.properties | Предмет туалетной бумаги с NBT disease=toilet |
| assets/minecraft/mcpatcher/cit/disease/sleeping_bag.properties | Предмет спальника с NBT disease=sleep |
| assets/minecraft/mcpatcher/cit/lootbox/keys/normal_key.properties | Обычный ключ с NBT case=default |
| assets/minecraft/mcpatcher/cit/lootbox/keys/mythic_key.properties | Мифический ключ с NBT case=mythic |
| assets/minecraft/mcpatcher/cit/lootbox/keys/rank_key.properties | Ключ ранга с NBT case=rank |
| assets/minecraft/mcpatcher/cit/lootbox/keys/upgraded_mythic_key.properties | Улучшенный мифический ключ |

В проверенном паке предметы ключей и бытовые расходники используют базовый материал **clay_ball** с разными NBT и текстурами. Это относится к скачанной версии: воспоминание о слезе гаста в старом сезоне остаётся непроверенным.

Пакет позволяет изучить внешний вид предметов и набор представленных сущностей. Он не содержит правила выбора стороны, выпадения ключей, поведения мобов, дебаффов, экономики или сохранений. Дата публикации темы 2019 года не является датой этой версии пакета: сообщение обновлялось, Classic добавлен в список в 2026 году.

## 2. Публичный клиентский мод Cristalix Prison

- [Репозиторий func-solutions/cristalix-mods](https://github.com/func-solutions/cristalix-mods).
- [Скачать зафиксированную версию](https://codeload.github.com/func-solutions/cristalix-mods/zip/0330a035ff963e028773bdf434bbc4fe3a807a37).
- Локально: [Cristalix-client-mods-0330a03-source.zip](downloads/Cristalix-client-mods-0330a03-source.zip), 195 850 байт.
- Проверенная ревизия: 0330a035ff963e028773bdf434bbc4fe3a807a37, последний коммит 14 декабря 2021 года.
- Главный файл: mod-prison/src/main/kotlin/ru/cristalix/mods/prison/PrisonMod.kt.

Мод принимает от сервера сообщение prison:addinfos: уровень, процент прогресса, предметы, подписи, текущие и требуемые количества, перечень улучшений уровня. Создаёт элементы панели с предметами и подписями. Реализация выглядит частичной: часть принятых значений не используется при отрисовке.

Это полезный образец интерфейса требований уровня. Сервер, который рассчитывает эти требования, в модуле отсутствует. Не найдены и реализации потребностей, фракций, боссов или таблиц наград. Репозиторий содержит коллекцию клиентских модов, поэтому общий ZIP включает другие модули. Публичных GitHub Releases на момент проверки нет.

## 3. PrisonEvo для RedLine: серверный код другого проекта

- [Репозиторий see1234/PrisonEvo](https://github.com/see1234/PrisonEvo).
- [Файл, устанавливающий принадлежность проекта](https://github.com/see1234/PrisonEvo/blob/62466165a901dc5db66f378d664f3c0fcad223a5/src/main/resources/plugin.yml).
- [Скачать зафиксированную версию](https://codeload.github.com/see1234/PrisonEvo/zip/62466165a901dc5db66f378d664f3c0fcad223a5).
- Локально: [RedLine-PrisonEvo-6246616-source.zip](downloads/RedLine-PrisonEvo-6246616-source.zip), 478 921 байт.
- Проверенная ревизия: 62466165a901dc5db66f378d664f3c0fcad223a5.

В plugin.yml указаны автор Konus и описание «Плагин PrisonEvo для RedLine.». Отождествлять его с Cristalix PrisonEvo нельзя.

В исходниках есть предметный код для изучения:
- боссы и обычные мобы: каталог boss/;
- добыча и дополнительные эффекты: listener/BlockBreakListener.java;
- артефакты и их обработка: api/Artifacts.java, listener/ArtifactsListener.java;
- банды и клановые войны: gangs/;
- питомцы: pets/;
- задания, тренер и lucky blocks: quest/, questbyalim/, trainer/, luckyblocks/.

Это наиболее содержательная найденная серверная реализация RPG Prison, но архив не является готовой сборкой сервера:
- build.gradle ожидает внешние JAR в libs/; этих зависимостей в архиве нет;
- часть классов использует внутренний API Minecraft v1_12_R1;
- в ресурсах есть plugin.yml, quest.yml и META-INF/MANIFEST.MF; основные конфиги уровней, шахт, боссов, предметов и других систем не приложены;
- готового игрового plugin JAR и публичных GitHub Releases не найдено;
- отдельную реализацию душа, туалета, болезней и выбора расы при просмотре структуры и поиске по соответствующим словам не обнаружил.

Сборку не запускал: для поставленной задачи полезнее разбирать отдельные правила, чем восстанавливать старый сервер с отсутствующими конфигами.

## Что ещё проверено

- [TheSwell/PrisonEvo](https://github.com/TheSwell/PrisonEvo): небольшой каркас проекта RedLine; не полный исходник Cristalix.
- [ZnZq/PrisonEvo-Wiki](https://github.com/ZnZq/PrisonEvo-Wiki): сайт вики и данные, не серверный плагин.
- [StickMixNeeds](https://forum-minecraft.ru/resources/stickmixneeds-sozdat-potrebnosti-na-servere.1269/): сторонняя карточка плагина потребностей с описанием душа, сна и туалета. Первичный репозиторий и связь с Cristalix не подтверждены; файл не скачан.
- [PrisonTeam/Prison](https://github.com/PrisonTeam/Prison): ранее разобранный открытый плагин шахт и рангов. Полный русский RPG Prison он не заменяет.
- Публичные SDK/API клиента Cristalix описывают платформу модов, а не предоставляют серверный режим.

## Что это даёт для Roblox

После установки клиента получены дополнительные материалы непосредственно из локального кэша: 1837 строк Classic и описания 42 правил. Разбор и снимки файлов перечислены в [CLASSIC-CLIENT-FINDINGS.md](client-audit/CLASSIC-CLIENT-FINDINGS.md). Это отдельный источник, не серверный исходник Cristalix.

Материалы уже позволяют сверять внешний набор предметов, устройство интерфейса уровня и отдельные реализации боёвки/прогрессии. Полностью восстановить старый Cristalix только из них нельзя: не хватает серверного кода и конфигов нужного сезона.

Для собственной игры нужны реализации на Luau и собственные ассеты. Разрешение на перенос чужого кода и графики из факта публичной загрузки не следует; файлов лицензии в двух проверенных репозиториях не обнаружено.

## Проверка загрузок

Архивы сохранены, исходники распакованы после проверки путей. Все 201 файл RedLine и 88 файлов коллекции клиентских модов совпали с Git blob SHA зафиксированных ревизий. Это проверка целостности загрузки, а не аудит безопасности кода. Скачанные скрипты и JAR не запускались.

Размеры, SHA-256, ссылки, ревизии и ограничения сохранены в [downloads-manifest.json](downloads-manifest.json). Снимки деревьев Git находятся рядом с архивами в downloads/.
