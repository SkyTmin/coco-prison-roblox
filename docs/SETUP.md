# Установка и запуск: Roblox Prison

Проверено 20 октября 2026 года на Windows 10. Все команды — для PowerShell, копировать по одной.

## 1. Что нужно и зачем

| Инструмент | Зачем | Как ставится |
| --- | --- | --- |
| Roblox Studio | Редактор карты, запуск игры, тест на 2 клиента и телефоне | Установщик с официального сайта Roblox |
| Встроенный MCP-сервер Studio | Claude Code видит и правит открытый place: скрипты, дерево объектов, запуск, консоль, скриншоты | Включается в настройках Studio |
| Rokit | Менеджер инструментов Roblox (ставит Rojo, Wally, Selene, StyLua) | Скрипт установки |
| Rojo | Синхронизирует папку `src/` с открытым place: код живёт в git, а не внутри .rbxl | `rokit add rojo-rbx/rojo` + плагин в Studio |
| Wally | Пакеты Luau (пока не используются) | `rokit add UpliftGames/wally` |
| Selene, StyLua | Линтер и форматтер Luau | `rokit add …` |
| VS Code + расширения Rojo, Luau LSP, Selene, StyLua | Редактирование кода с подсказками типов | winget + расширения |
| Blender 5.x | Модели (ключ-капля, крыса, зомби, инструменты) → FBX → Studio | winget |
| Git + GitHub CLI | Репозиторий `SkyTmin/coco-prison-roblox` | Уже установлены |

## 2. Roblox Studio

Установщик: https://setup.rbxcdn.com/RobloxStudioInstaller.exe (запасной адрес: https://create.roblox.com/ → «Начать творить»). Нужен аккаунт Roblox; вход делает владелец сам.

После установки Studio лежит в `%LOCALAPPDATA%\Roblox\Versions\version-…\RobloxStudioBeta.exe`.

Проверка:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Directory | Select-Object Name
```

**VPN.** Studio ходит в сеть через системный прокси Windows (Happ → `127.0.0.1:10809`). Если VPN деградирует, в логе `%LOCALAPPDATA%Robloxlogs*_Studio_*_last.log` идут `SslConnectFail` к `ecsv2.roblox.com`, `apis.roblox.com`, и Studio сама закрывается через ~75 с после запуска. Проверка (через прокси должно быть не `000`):

```bash
curl -s -o /dev/null -w "%{http_code}
" -m 10 -x http://127.0.0.1:10809 https://ecsv2.roblox.com/
```

Лечится переподключением VPN в Happ (делает владелец); агент прокси не трогает.

## 3. MCP-сервер Studio для Claude Code

С февраля 2026 года MCP-сервер встроен в Studio (отдельный `studio-rust-mcp-server` в архиве и не нужен).

1. Открыть Studio, открыть любой place (например, Baseplate).
2. Справа вверху **Assistant → … → Manage MCP Servers**.
3. Включить **Enable Studio as MCP server**.
4. В списке **Quick connect** включить **Claude Code**. Studio сама допишет сервер в конфигурацию Claude Code.
5. Перезапустить Claude Code. В Studio у подключённого клиента загорится зелёный индикатор.

Если Quick connect не предлагает Claude Code, добавить вручную:

```powershell
claude mcp add Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"
```

Что даёт сервер: чтение и правка скриптов, поиск по дереву объектов, выполнение Luau в режимах Edit/Client/Server, запуск и остановка игры, консоль, скриншоты экрана Studio, управление персонажем. Это и есть «сопровождение»: Claude строит объекты, запускает игру и смотрит результат.

## 3а. MCP для Codex: изображения и делегирование задач

Сервер [aikazu/claude-codex-mcp](https://github.com/aikazu/claude-codex-mcp) (Node, без зависимостей, Windows-first) даёт Claude инструменты `codex_image` (генерация картинок через встроенный image_gen Codex), `codex_task` (поручить задачу Codex), `codex_job`, `codex_jobs`, `codex_models`. Работает через Codex CLI и подписку ChatGPT, API-ключ не нужен.

Установлено и проверено 20 октября 2026 года: Codex CLI 0.163.0 через `npm i -g @openai/codex` (десктоп-приложение Codex уже стояло и залогинено через ChatGPT, вход общий через `~/.codex/auth.json`), сервер склонирован в `C:\Users\user\tools\claude-codex-mcp` и зарегистрирован в Claude Code на уровне пользователя (`~/.claude.json`):

```powershell
claude mcp add-json codex -s user '{"type":"stdio","command":"node","args":["C:\\Users\\user\\tools\\claude-codex-mcp\\src\\cli.mjs"],"env":{"CODEX_MCP_ASSET_DIR":"C:\\Users\\user\\Pictures\\codex-assets","CODEX_BIN":"C:\\Users\\user\\AppData\\Roaming\\npm\\node_modules\\@openai\\codex\\bin\\codex.js"}}'
```

`CODEX_BIN` указывает на `codex.js` из npm, а не на `.cmd`-шим: шимы на Windows сервер запустить не может. Проверка:

```powershell
claude mcp list
```

```powershell
node C:\Users\user\tools\claude-codex-mcp\src\cli.mjs --check
```

Тест прошёл: `codex_image` за 42 секунды сделал [assets/concepts/pixel-art-icon-of-a-glowing-teardrop-sha.png](../assets/concepts/pixel-art-icon-of-a-glowing-teardrop-sha.png) — первый концепт ключа-капли. Картинки складываются в `C:\Users\user\Pictures\codex-assets` и копируются в папку проекта, которую указывает Claude (`out_dir`). Для Roblox: иконки предметов, текстуры, концепты крысы, зомби, инструментов; затем Studio **Asset Manager → Import**. Если сервер пишет `Not logged in`, владелец аккаунта запускает `codex login`.

## 4. Rokit, Rojo и остальные инструменты

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

Закрыть и открыть PowerShell заново (Rokit добавляет `%USERPROFILE%\.rokit\bin` в PATH). Затем в папке проекта:

```powershell
cd C:\Users\user\Documents\coco-prison-roblox
```

```powershell
rokit install
```

Плагин Rojo в Studio (один раз):

```powershell
rojo plugin install
```

## 5. Рабочий цикл

1. Запустить сервер синхронизации в папке проекта:

```powershell
rojo serve
```

2. В Studio открыть place, вкладка **Plugins → Rojo → Connect** (адрес по умолчанию `localhost:34872`).
3. Папка `src/` появляется в place: `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`.
4. Карта строится в Studio и хранится в place (в Rojo-проект Workspace не входит). Первый двор: открыть **View → Command Bar**, вставить содержимое `scripts/build-yard.luau`, Enter. Или попросить Claude выполнить его через MCP.
5. **Home → Play** (F5). Клик по дереву рубит его, у проводника появляется подсказка «Продать сырьё», кнопка «Повысить уровень» проверяет условия.
6. Два клиента: **Test → Clients and Servers → 2 Players → Start**. Телефон: **Test → Device**.
7. Сохранить place как `place/coco-prison.rbxl` (папка в `.gitignore`: карту восстанавливает скрипт, код — в `src/`). Публикация: **File → Publish to Roblox**.

Проверка кода перед коммитом:

```powershell
selene src; stylua --check src
```

## 6. VS Code

```powershell
winget install --id Microsoft.VisualStudioCode --exact --silent --accept-package-agreements --accept-source-agreements
```

Открыть папку `coco-prison-roblox` — VS Code предложит расширения из `.vscode/extensions.json`. Luau LSP подхватывает `.luaurc` и типы Roblox автоматически.

## 7. Blender

```powershell
winget install --id BlenderFoundation.Blender --exact --silent --accept-package-agreements --accept-source-agreements
```

Старый Blender 2.75 из Microsoft Store остаётся отдельно; новый ставится в `C:\Program Files\Blender Foundation\Blender 5.x`.

Экспорт в Roblox: **File → Export → FBX** (масштаб 0.01, применить трансформации), в Studio **Home → Import 3D**. Ограничения: до 10 000 треугольников на меш, текстуры до 1024×1024. Для ключа-капли и крысы хватит простых low-poly моделей.

## 8. Git и GitHub

Репозиторий: `SkyTmin/coco-prison-roblox`, ветка `main`, локальная копия `C:\Users\user\Documents\coco-prison-roblox`. Игра живёт отдельно от `coco-instruments` (Telegram-приложение с автодеплоем), чтобы не трогать его деплой и не смешивать проекты.

Если `gh auth status` показывает недействительный токен:

```powershell
gh auth login -h github.com -p https --web
```

```powershell
gh auth setup-git
```

Обычный цикл:

```powershell
git -C C:\Users\user\Documents\coco-prison-roblox add -A; git -C C:\Users\user\Documents\coco-prison-roblox commit -m "feat: ..."; git -C C:\Users\user\Documents\coco-prison-roblox push
```

## Источники

- https://create.roblox.com/docs/studio/mcp — встроенный MCP-сервер Studio, Quick connect, ручная конфигурация.
- https://github.com/Roblox/studio-rust-mcp-server — прежний отдельный сервер, в архиве с 3 апреля 2026 года.
- https://github.com/rojo-rbx/rokit — установка Rokit.
- https://rojo.space/docs/v7/getting-started/installation/ — Rojo, плагин Studio, расширение VS Code.
