# Prison Classic: кирка, уровни 1–16

19 октября 2026 года. Восстановлено вручную из 16 присланных снимков предпросмотра улучшений. Это реальные значения интерфейса показанного сервера, а не извлечённый серверный код. Вариант Normal/Quick не установлен.

**Прочитаны все 15 показанных переходов 1 → 16: цена, требования и изменение «Эффективности».** Отдельно сохранён конечный экран 16-го уровня. Данные остальных инструментов и брони из этих снимков не следуют.

## Таблица улучшений

Требования — числа **справа** от `/`. Слева находятся текущие показатели игрока; они не скопированы в баланс. `—` означает, что строки требования на данном экране нет. `K` сохранено дословно: это сокращённая точность интерфейса.

| Переход | Деньги | Камень | Каменный уголь | Железная руда | Золотая руда | Эффективность / изменение | Источник |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 1 → 2 | 25 | 145 | 5 | — | — | 0 → I | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-01.png) |
| 2 → 3 | 37 | 285 | 15 | — | — | I → II | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-02.png) |
| 3 → 4 | 47 | 520 | 75 | — | — | II → III | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-03.png) |
| 4 → 5 | 90 | 1.05K | 150 | — | — | Смена материала; строка отсутствует | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-04.png) |
| 5 → 6 | 180 | 1.5K | 250 | 10 | — | 0 → I | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-05.png) |
| 6 → 7 | 270 | 2K | 350 | 25 | — | I → II | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-06.png) |
| 7 → 8 | 540 | 3.25K | 500 | 60 | — | II → III | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-07.png) |
| 8 → 9 | 830 | 7.8K | — | 165 | — | Смена материала; строка отсутствует | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-08.png) |
| 9 → 10 | 1,330 | 10.7K | — | 335 | 165 | 0 → I | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-09.png) |
| 10 → 11 | 3,000 | 15.8K | — | 680 | 375 | I → II | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-10.png) |
| 11 → 12 | 6,000 | 23.2K | — | 1.01K | 560 | II → III | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-11.png) |
| 12 → 13 | 7,500 | 33.8K | — | — | 1.12K | Смена материала; строка отсутствует | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-12.png) |
| 13 → 14 | 9,000 | 49.7K | — | — | 1.8K | 0 → I | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-13.png) |
| 14 → 15 | 11,200 | 67.2K | — | — | 2.7K | I → II | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-14.png) |
| 15 → 16 | 14,900 | 93.1K | — | — | 4.75K | II → III | [снимок](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-15.png) |

Сумма пятнадцати показанных денежных цен: **54,949**. Это арифметическая сумма цен 1 → 16, без начальной покупки и без непоказанных модификаторов. Складывать таким же образом требования по камню/рудам нельзя: ещё не установлено, являются ли они накопительными счётчиками и списываются ли при покупке.

## Материал и зачарование

Последовательность соседних предпросмотров согласуется с четырьмя ступенями:

| Интерпретация ступени | Уровни | Цикл Эффективности |
| --- | --- | --- |
| Деревянная | 1–4 | 0 → I → II → III |
| Каменная | 5–8 | 0 → I → II → III |
| Железная | 9–12 | 0 → I → II → III |
| Алмазная | 13–16 | 0 → I → II → III |

Это интерпретация последовательности интерфейса. На переходах **4 → 5, 8 → 9, 12 → 13** слева уже стоит подпись следующего материала, но номер уровня остаётся исходным, а справа сохраняется старое название. Например, 4 → 5: слева «Каменная кирка, уровень 4», справа «Деревянная кирка, 4 → 5». Сырые подписи обеих сторон сохранены в JSON; несогласованность интерфейса не скрыта.

На этих трёх переходах строка Эффективности отсутствует. Следующий экран показывает исходную Эффективность 0 и переход к I. Время разрушения блоков, точная скорость кирок и применение стандартной Minecraft-формулы этими снимками не доказаны.

## Экран 16-го уровня

На [последнем снимке](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-menu-evidence/pickaxe-16.png) нижняя подпись — **«Уровень 16»**, справа написано **16 → 16**. Слева повторяются цена 14,900 и требования 93.1K камня / 4.75K золотой руды с предыдущего перехода.

Это **не улучшение 16 → 17**. Повторная цена не добавлена к общей сумме. Предпросмотр в присланной серии заканчивается на 16; абсолютный максимум всех кирок на сервере не установлен.

## Что это сообщает о добыче

Для улучшения кирки проверяются четыре названных ресурса: камень, каменный уголь, железная руда и золотая руда. Они появляются в требованиях на разных этапах. Однако это не устанавливает состав, цены и распределение этих ресурсов по конкретным шахтам. Предметный уровень кирки также не равен уровню персонажа и порогу открытия локации.

## Проверяемые данные

- [Таблица, исходные подписи и ссылки на снимки](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/pickaxe-upgrades-recovery.json).
- [Восстановленные уровни шахт](C:/Users/user/Documents/roblox-prison-research/client-audit/MINE-RECOVERY.md).

Сохранены только игровые меню без чата и других окон рабочего стола. Для каждого фрагмента записаны SHA-256 оригинала и сохранённого изображения.
