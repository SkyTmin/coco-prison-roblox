# Что не попало в wiki из локальной папки исследования

Оригинал: `C:\Users\user\Documents\roblox-prison-research` (1 ГБ, 30 563 файла). Сюда скопированы документы, данные и скрипты анализа (496 файлов, 59 МБ). Исключено:

| Путь или маска | Почему |
| --- | --- |
| `client-audit/tools/` (207 МБ) | Временный JRE, декомпилятор и python-библиотеки; ставятся заново |
| `client-audit/code-analysis/` (484 МБ) | SQLite-индекс кода и карта исходников: производные, больше лимита GitHub 100 МБ |
| `client-audit/full-decompilation/`, `decompiled/`, `decompiler-input/`, `decoded/source-excerpts/`, `*.jar`, `CLIENT-DECOMPILED-SOURCES.zip` | Декомпилированный клиент Minecraft и защищённый клиент Cristalix: чужой код, публиковать нельзя |
| `client-audit/snapshot/` | Кэш клиента после входа в Classic |
| `downloads/*.zip`, распакованные `Cristalix-client-source/`, `RedLine-source/` | Ресурспак и чужие репозитории; ссылки, размеры и SHA-256 — в `downloads-manifest.json` |
| `*.bin`, `*.log`, `*.pyc`, `__pycache__/` | Бинарные и временные файлы |

Ссылки в отчётах на эти пути работают только в локальной копии. Выводы из декомпиляции сохранены в текстах аудитов (`CLIENT-LOGIC-AUDIT.md`, `TALENT-TREE-AUDIT.md`, `FULL-DECOMPILATION-REPORT.md` и других).
