# Prison Classic: пропущенные кадры Аукциона, добычи и фракции

20 октября 2026 года. Сохранены ещё 50 ранее пропущенных игровых кадров: 46 Аукциона, 2 добычи и 2 фракций. 35 кадров книг разобраны в [отдельной системе](C:/Users/user/Documents/roblox-prison-research/client-audit/BOOKS-SYSTEM.md); оставшиеся наблюдения приведены здесь.

## Аукцион

Есть вкладки «Аукцион / Личные товары», фильтр валюты **Деньги / Рубины**, тип предметов, цена/уровень от–до, поиск, сортировки по уровню/времени/цене, страницы и кнопка «Продать». Снимок 85 — обзор, без выбранной подсказки. [coverage_85](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/085.png).

| Предмет | Цена игрока | Валюта | Источник |
| --- | ---: | --- | --- |
| Редкая деревянная кирка | 350 | игровые деньги | [coverage_86](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/086.png), [coverage_127](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/127.png) |
| Пропуск в подвал | 100 | игровые деньги | [coverage_87](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/087.png) |
| Ключ от Обычного кейса | 90 | игровые деньги | [coverage_88](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/088.png) |
| Древняя звезда | 1459 | игровые деньги | [coverage_89](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/089.png) |
| Гнилая плоть | 1000 | игровые деньги | [coverage_90](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/090.png) |
| Древний порошок | 999 | игровые деньги | [coverage_91](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/091.png) |
| Питьевое зелье | 200 | игровые деньги | [coverage_128](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/128.png) |
| Древняя звезда | 3670 | игровые деньги | [coverage_129](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/129.png) |
| Туалетная бумага | 3000 | игровые деньги | [coverage_130](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/auction/130.png) |

Кирка явно подписана **Редкая деревянная кирка**, **Шёлковое касание I**, уровень **1**; она повторно наведена через фильтр инструментов. Подсказка ключа указывает Обычный кейс на Спавне. Подсказка звезды говорит о возможном получении от босса или Обычного кейса и обмене на ключи на Рынке. Цена лота не является ценой одной штуки, если количество не установлено отдельно.

У питьевого зелья показаны **Регенерация (0:34)**, отметка изготовления игроком и строка **«При применении: +3 Урон»**. Необычная строка сохранена буквально; рецепт и фактический эффект не выдуманы. Туалетная бумага по подсказке позволяет удовлетворить нужду в любом месте.

## Фракции

На снимке игрок состоит в «Славянах», показаны четыре точки: **Деньги, Блоки, Мобы, Спешка**, счётчик захваченных **0/4**. В момент кадра первые две и Спешка отмечены за «Афро», Мобы — за «Латиносами». Это состояние захвата, не постоянная принадлежность. Числовых бонусов на кадре нет. [coverage_83](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/faction/083.png).

Диалог спрашивает, хочет ли игрок **покинуть фракцию за 2500 $**. Эта цена не объявлена ценой вступления или смены; подтверждение выхода не выполнялось. [coverage_84](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/faction/084.png).

## Добыча и комбо

Два кадра показывают всплывающие **+0.012 $**, панель **Комбо ×1** и **22/1000 → 27/1000**. Это показанный прогресс комбо, а не прочность инструмента. Из отдельных кадров не установлено соответствие конкретного типа блока выплате, базовая цена, коэффициенты бонусов, время сохранения комбо или его формула. [coverage_81](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/mining/081.png), [coverage_82](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-evidence/mining/082.png).

[Машинные данные](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/auction-and-scenes-recovery.json) · [Источники](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/missed-menu-sources.json)
