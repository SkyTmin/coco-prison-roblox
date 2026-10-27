# Донат: как включить покупки за Robux (для владельца)

В магазине 31 товар за Robux: 5 наборов кристаллов и 26 предметов по 1 штуке (от 7 R$). Каждому нужен свой
Developer Product в вашей игре. Создавать их по одному руками не нужно: это делает скрипт
`scripts/create-dev-products.mjs`. Он берёт названия, цены и иконки из конфига и сам вписывает id товаров обратно в
конфиг.

## 1. Создать API-ключ (один раз, ~2 минуты)

1. Откройте https://create.roblox.com/dashboard/credentials (Creator Dashboard → **Open Cloud** → **API Keys**).
2. Нажмите **Create API Key**.
3. **Name:** `coco dev products`.
4. **Access Permissions** → **Select API System** → выберите **Developer Products**.
5. В появившейся строке выберите опыт **coco prison** (place 92594200898716) и отметьте операции **read** и
   **write**.
6. **Security** → **Accepted IP Addresses** → добавьте `0.0.0.0/0` (или свой IP).
7. **Expiration** — по желанию (можно 1 день: ключ нужен только для этого запуска).
8. Нажмите **Save & Generate Key** и скопируйте ключ. **Не присылайте его в чат** и никуда не сохраняйте в проект.

## 2. Запустить скрипт (в PowerShell, в папке проекта)

```powershell
cd C:\Users\user\Documents\coco-prison-roblox
node scripts/create-dev-products.mjs --dry
```

`--dry` только показывает, что будет создано (29 строк «would create»), и ничего не меняет. Потом сам запуск:

```powershell
$env:ROBLOX_API_KEY = "сюда вставьте ключ"
node scripts/create-dev-products.mjs
```

В конце должно быть: `done: 29 created, 0 repriced, 0 unchanged`. Скрипт:

- создаёт товары с названием, описанием, ценой и нашей иконкой из Blender;
- записывает их id в `scripts/design-decisions.json` (`donate.packs[].productId`, `donate.items.<id>.productId`);
- пересобирает конфиги.

Запускать повторно безопасно: существующие товары он находит по названию и только исправляет цену.

## 3. Дальше

1. Напишите мне «товары созданы» — я закоммичу id, залью код в Studio и проверю тестовую покупку. В Studio
   Roblox показывает окно покупки как тест: Robux не списываются.
2. Опубликуйте игру (**File → Publish to Roblox**) — только после этого покупки заработают у игроков.

## Обновление 28.10: перезапустить скрипт

Наборы кристаллов теперь стоят ровно как пакеты Robux (80 / 400 / 800 / 1700 / 4500 R$): окно Roblox «Buy Robux and
item» продаёт наименьший пакет, покрывающий цену, и при совпадении игрок платит ровно столько, сколько видит.
Добавились «Авто-продажа» и «Инъекция «Без нужд»». Запустите скрипт ещё раз (шаг 2, с ключом) — он переименует и
переоценит 5 наборов (по их id) и создаст 2 новых товара: `done: 2 created, 5 repriced, 24 unchanged`.

## Если что-то пошло не так

- `HTTP 401` / `403` — у ключа нет **Developer Products** (read + write) для этой игры или не добавлен IP.
- `HTTP 429` — слишком часто. Подождите минуту и запустите снова: уже созданные товары он не создаст повторно.
- Удалять Developer Products Roblox не даёт. Лишний товар можно переименовать или снять с продажи в Dashboard
  (**Monetization → Developer Products**).
- Цены меняются в `scripts/design-decisions.json` (`donate.items.<id>.robux`, `donate.packs[].robux`). Потом снова
  запустите скрипт — он обновит цены в Roblox.

## Вручную (если скрипт не подходит)

Creator Dashboard → ваша игра → **Monetization → Developer Products → Create a Developer Product**: название и цена из
таблицы ниже (`node scripts/create-dev-products.mjs --dry` выводит её целиком). Id каждого созданного товара пришлите
мне — я впишу их в конфиг.
