# coco-prison-roblox

Тюремная RPG для Roblox по мотивам Prison Classic на Cristalix: разные работы, быт, бой, фракции, боссы, ключи и сундуки. Спецификация первой главы — [wiki/PROTOTYPE-SPEC.md](wiki/PROTOTYPE-SPEC.md), каталог механик — [wiki/MECHANICS-CATALOG.md](wiki/MECHANICS-CATALOG.md), всё исследование — [wiki/README.md](wiki/README.md).

## Состояние

Создано 20 октября 2026 года. Сделан каркас шага 1 из порядка реализации (§15 спецификации): профиль игрока, три инструмента, узлы работы (дерево, земля, глина, камень, уголь, железо), продажа, проверка условий уровня. Карта двора — заглушка из цветных блоков (`scripts/build-yard.luau`). Боёвка, быт, фракции, босс, ключи-предметы и сундук ещё не начаты.

## Структура

| Путь | Что это |
| --- | --- |
| `default.project.json` | Проект Rojo: `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client |
| `src/shared/Config/rpg-systems.json` | Баланс первой главы (копия `wiki/rpg-systems-config.json`); Rojo отдаёт его как ModuleScript |
| `src/shared/` | `Config` (типизированный доступ к JSON), `Strings` (ru/en/es/fr), `Remotes`, `Types` (профиль v2) |
| `src/server/Services/` | `ProfileService` (профили и DataStore), `WorkService` (проверка и выдача добычи), `EconomyService` (продажа, уровни) |
| `src/client/` | Действие «Копать» для мыши, тач-кнопки и геймпада, подсветка цели, HUD |
| `scripts/build-yard.luau` | Строит двор-заглушку в открытом place |
| `docs/SETUP.md` | Установка Studio, MCP, Rokit/Rojo, VS Code, Blender; рабочий цикл |
| `wiki/` | Исследование Cristalix Prison: восстановленные данные, аудиты, спецификации, скриншоты-доказательства |
| `CLAUDE.md` | Правила для агентов, работающих в этой папке |

## Быстрый старт

См. [docs/SETUP.md](docs/SETUP.md). Коротко: `rokit install` → `rojo serve` → в Studio Rojo Connect → Command Bar с `scripts/build-yard.luau` → Play.
