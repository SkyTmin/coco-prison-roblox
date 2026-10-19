# Престиж и сохранение: второй проход

Проверено 18 октября 2026 года. Статический разбор ревизии `6914aa0a687c26a44e10d150ae5e4b17bf733b04`.

## Порядок force-sellall

При обычной команде prestige сначала проверяется достаточный баланс, затем запрашивается подтверждение. Только после этого управление передаётся в rankUpPrivate. Если денег до продажи не хватает, этот вход в команду не продаст сумку для оплаты престижа автоматически. [prestigeCmd](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-ranks/src/main/java/tech/mcprison/prison/ranks/commands/RankUpCommand.java#L363)

В rankUpPrivate проверяется последний основной ранг, затем при включённой prestige.force-sellall вызывается platform.sellall. Продажа происходит до оплаты целевого престижа и до дальнейшего сброса. [rankUpPrivate](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-ranks/src/main/java/tech/mcprison/prison/ranks/commands/RankUpCommand.java#L550)

SpigotPlatform.sellall выполняет встроенный SellAll лишь при включённом модуле и наличии игрока онлайн. Локальный результат success используется для диагностики; он не возвращается вызывающему коду, поскольку метод void. Поэтому этот вызов не является гарантированной очисткой всех предметов: могут остаться непродаваемые предметы, неподдерживаемые контейнеры и содержимое при неработающей продаже. [SpigotPlatform](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-spigot/src/main/java/tech/mcprison/prison/spigot/SpigotPlatform.java#L3375)

После успешного rankup вызывается prestigePlayer. Возврат на первый основной ранг зависит от resetDefaultLadder, обнуление стандартного баланса — от resetMoney и успешности возврата. resetMoney вызывает setBalance(0), поэтому нельзя без отдельной проверки обобщать его на все пользовательские валюты. [prestigePlayer](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-ranks/src/main/java/tech/mcprison/prison/ranks/commands/RankUpCommand.java#L653)

## Что можно заключить о сбоях сохранения

RankUtil списывает деньги, присваивает новый ранг и вызывает savePlayerRank. В savePlayerRank результат PlayerManager.savePlayer игнорируется: функция выставляет собственный success=true после вызова и записывает успешное событие. [RankUtil.savePlayerRank](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-ranks/src/main/java/tech/mcprison/prison/ranks/RankUtil.java#L713)

PlayerManager.savePlayer может вернуть false при IOException после записи ошибки в лог. Фактическое сохранение вызывается через collection.save. [PlayerManager](https://github.com/PrisonTeam/Prison/blob/6914aa0a687c26a44e10d150ae5e4b17bf733b04/prison-ranks/src/main/java/tech/mcprison/prison/ranks/managers/PlayerManager.java#L158)

Подтверждённый вывод: флаг успеха в этом пути RankUtil не доказывает, что запись на диск завершилась. Это не воспроизведённая потеря данных; модель ошибок конкретного хранилища и восстановление после аварии здесь не проверены. Все деньги, ранги и контейнеры не показаны как одна атомарная транзакция.

## Решение для самостоятельной версии Roblox

- Престиж применяет одной операцией к профилю: оплату, очистку руды, сброс ранга/кирки/сумки и постоянный бонус.
- Отдельно задаётся, какие валюты и улучшения сохраняются. В предлагаемом прототипе сохраняются токены и их улучшение удачи.
- Перед престижем сумка просто очищается после явного подтверждения. Продажей нельзя финансировать престиж скрыто; игрок сначала продаёт ресурсы сам.
- В процессе сохранения операции профиля упорядочиваются; ошибка загрузки запрещает запись начальных данных.
- UpdateAsync и session locking выполняют разные задачи. Требования и официальные ссылки: ROBLOX-TECH-NOTES.md.

Это проектные решения, не описание уже написанной игры.

