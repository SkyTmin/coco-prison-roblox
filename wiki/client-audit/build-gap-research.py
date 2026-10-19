"""Record findings from a focused independent public/local research pass."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
index = json.loads((OUT/'classic-content-index.json').read_text(encoding='utf-8'))
indexed = {r['key']: r for r in index['records']}
public = json.loads((OUT/'public-gap-sources/public-source-index.json').read_text(encoding='utf-8'))
posts = {int(p['id'].split('/')[-1]):p for p in public['posts']}
cache = json.loads((OUT/'current-cache/cache-reaudit.json').read_text(encoding='utf-8'))
top = json.loads((OUT/'public-gap-sources/top-prison-field-metadata.json').read_text(encoding='utf-8'))
findings = []

def local(fid, claim, keys, tokens=(), unknowns=()):
    selected = [indexed[k] for k in keys]
    combined = '\n'.join(r['text'] for r in selected)
    for token in tokens:
        assert token in combined, (fid, token)
    sources = [dict(path=index['source'], sha256=index['sourceSha256'],
                    key=r['key'],line=r['sourceLine'],text=r['text']) for r in selected]
    findings.append(dict(id=fid,claim=claim,status='client_description_not_runtime_test',
        sources=sources,remainingUnknowns=list(unknowns)))

def post(fid, number, claim, tokens=(), unknowns=()):
    p = posts[number]
    for token in tokens:
        assert token in p['text'], (fid, token)
    findings.append(dict(id=fid,claim=claim,status='dated_classic_patch_note_not_current_runtime_test',
        publishedAt=p['date'],sources=[dict(url=p['url'],path=p['sourcePage'],sha256=p['sourceSha256'])],
        remainingUnknowns=['Later seasons may change this rule.']+list(unknowns)))

local('FILES-BLACKSMITH', 'Кузница объединяет две книги; проверяются совпадение типа и уровня, оплата указана в звёздах.', [
    'prison.classic.gang.upgrades.blacksmith_description',
    'prison.classic.gang.blacksmith.choice_similar_books',
    'prison.classic.gang.blacksmith.type_and_level_incompatible',
    'prison.classic.gang.blacksmith.chance',
    'prison.classic.gang.blacksmith.merge_for'], tokens=('две','уровень','звёзд'),
    unknowns=('Exact price, success formula, resulting application chance and failure outcome.',))
local('FILES-AUCTION-REFRESH','Локальная подсказка задаёт автообновление Аукциона раз в 30 секунд.',
    ['prison.classic.auction.gui.refresh_tooltip_auto'],tokens=('30',),
    unknowns=('Whether this is only listing refresh and how it behaves in the current UI.',))
local('FILES-GROUND-CLEANUP','Совет описывает удаление предметов, лежащих на полу более 5 минут.',
    ['prison.classic.advice.50'],tokens=('5-ти минут',),
    unknowns=('Protected item exceptions and actual cleanup scheduling.',))
local('FILES-BOOSTER','Шаблон донатного бустера описывает увеличение соответствующего множителя на 100%; область действия и минуты подставляются.',
    ['prison.classic.donate.list.booster.description'],tokens=('100%','%d минут'),
    unknowns=('Exact per-offer duration, booster stacking and which multiplier the template refers to.',))
local('FILES-DEATH','Есть сообщение потери денег после смерти и предупреждение о выпадении некоторых предметов в PvP-шахте.',
    ['prison.classic.combat.target_message','prison.classic.location.pvp_tooltip'],tokens=('%d','Некоторые вещи'),
    unknowns=('Amount or fraction of money lost, protected slots/items and anti-logout behavior.',))
post('PATCH-GHETTO-TEAM-DAMAGE',10,'Патч разрешает наносить урон игрокам той же фракции на Гетто.',('На Гетто','одной фракции'))
post('PATCH-RETURN-LOCATION',14,'Патч описывает возвращение в прежнюю локацию при входе; сохранение места сбрасывается через 20 минут после выхода.',('20 минут','перед выходом'))
post('PATCH-NEEDS-DEATH',15,'Исправлено обнуление нужд после смерти: описанное исправление означает сохранение нужд при смерти.',('потребности сбрасывались после смерти',),
     ('Need accumulation timers, penalties and treatment duration.',))
post('PATCH-FORTIFICATION',15,'В декабрьском патче сила эффекта слабости Укрепления понижена с 3 до 2.',('Укрепление','3 -> 2'),
     ('Not a full mapping of book I/II/III to effect strength; later February patch weakens it again without values.',))
post('PATCH-PROCESSING-TRADE',24,'Патч разрешает выставлять щебень на Аукцион и продавать полученную переработкой пыль.',('Щебень','Пыль после переработки'))
post('PATCH-GANG-LEVEL',25,'Вступление в банду и создание своей банды ограничено минимум 5-м уровнем игрока.',('ниже 5-го уровня','создавать'))
post('PATCH-BLOCK-ACCESS',25,'Для блоков из значительно более высоких шахт ограничены поднятие, выбрасывание и продажа; передача блоков через /gift запрещена.',('значительно выше','поднимать, скидывать и продавать','/gift'),
     ('Allowed level gap is not specified; items other than blocks are not covered by this sentence.',))
post('PATCH-APPLES',25,'SHIFT при покупке яблок на Рынке позволяет покупать сразу 64.',('64 яблока','SHIFT'))

mode = top['prisonModeMetadata']['modes'][0]
keys = {f['key'] for f in mode['fields']}
assert {'blocks','blocks_clean','rats','rats_clean'} <= keys
findings.append(dict(id='TOP-SEPARATE-COUNTERS',
    claim='Официальный сайт статистики различает blocks/blocks_clean и rats/rats_clean; это отдельные поля.',
    status='public_site_metadata_not_game_formula',
    sources=[dict(url=top['source'],path=top['sourcePath'],sha256=top['sourceSha256'])],
    remainingUnknowns=['Exact clean/dirty counting rules, realm variant and level requirements.']))

excluded = [
 dict(url='https://forum.cristalix.gg/threads/298521/',reason='Prison OldSchool: numeric rank/relic tables belong to a different mode.'),
 dict(url='https://forum.cristalix.gg/threads/273126/',reason='PrisonEvo: scroll effects are not Classic ancient-book coefficients.'),
 dict(url='https://forum.cristalix.gg/threads/307724/',reason='SkyBlock OLD: its blacksmith and item destruction rules do not establish Classic rules.'),
 dict(url='https://forum.vimeworld.com/topic/1379712-новый-сезон-prison-classic/',reason='VimeWorld Classic: deletion of its Plastolom is not deletion in Cristalix.'),
 dict(url='https://t.me/prison_classic/40',reason='Following the explicit Quick announcement in post 39; do not apply its 50-level/strength/price changes automatically to current Classic.'),
 dict(url='https://forum.cristalix.gg/threads/3961/',reason='Historical April 2018 guide; old tool prices and early mine levels not adopted as current values.')]
gaps = [
 dict(system='Книги',result='Частично: установлены совпадение типа/уровня и оплата Кузницы звёздами.',
      missing='Сумма и формула объединения, лимит зачарований, генерация шанса книги, вероятности выпадения, коэффициенты и задержки эффектов.',
      nextEvidence='Текущий ответ меню /wiki или Кузницы; фактическое применение и серия наблюдений.',findings=['FILES-BLACKSMITH']),
 dict(system='Способности и тренер',result='Повторно проверены RU/EN: в найденных строках ключевые числа остаются подстановками.',
      missing='Полные ступени, требования и числовые эффекты.',
      nextEvidence='Серверные данные меню; показанные UI-цены из клиента не вычисляются.',findings=[]),
 dict(system='Уровни персонажа',result='Сайт статистики публикует текущие показатели, а не таблицу требований.',
      missing='Переходы помимо снятого 8 → 9 и абсолютный предел текущего варианта.',
      nextEvidence='Меню /level или явно соответствующая сезону таблица.',findings=['TOP-SEPARATE-COUNTERS']),
 dict(system='Шахты и экономика',result='Найдены ограничения передачи блоков; подтверждены раздельные счётчики.',
      missing='Текущие цены блоков, доли, размеры, таймеры, формула комбо и разрешённая разница уровней для блоков.',
      nextEvidence='Данные продажи/шахт и измерения; октябрьский патч менял цены.',findings=['PATCH-BLOCK-ACCESS','TOP-SEPARATE-COUNTERS']),
 dict(system='Оставшиеся инструменты',result='Новой достоверной таблицы Classic для лука, ножниц, мотыги и особых инструментов не найдено.',
      missing='Цены, стадии, характеристики и требования.',
      nextEvidence='Серверное меню /upgrade; чужие режимы не подставлены.',findings=[]),
 dict(system='Бой, смерть и боссы',result='Дополнены Гетто, смерть/нужды, денежная потеря и исторический патч Укрепления.',
      missing='HP, урон, фазы, распределение наград и точные потери при смерти.',
      nextEvidence='Текущая справка и игровые наблюдения; коэффициенты сервером не получены.',
      findings=['PATCH-GHETTO-TEAM-DAMAGE','PATCH-NEEDS-DEATH','PATCH-FORTIFICATION','FILES-DEATH']),
 dict(system='Быт, банды и переработка',result='Установлены сохранение нужд после смерти, порог банды и торгуемость щебня/пыли в датированных патчах.',
      missing='Таймеры нужд, числовые бонусы, цены развития камеры и производительность помощников.',
      nextEvidence='Текущие меню камеры/банды и наблюдения работы.',
      findings=['PATCH-NEEDS-DEATH','PATCH-GANG-LEVEL','PATCH-PROCESSING-TRADE']),
 dict(system='Бустеры и интерфейс',result='Есть описание +100% соответствующего множителя, обновление Аукциона 30 с и уборка пола после 5 мин.',
      missing='Длительность каждой покупки, взаимодействие бустеров и реальные серверные исключения.',
      nextEvidence='Подсказки отдельных бустеров и фактическая активация.',findings=['FILES-BOOSTER','FILES-AUCTION-REFRESH','FILES-GROUND-CLEANUP'])]

data = dict(recordedDate='2026-10-20',scope='Independent public/local gap research. No game state modified; no server execution or current balance configuration obtained.',
    publicArchive=dict(visiblePosts=len(posts),minId=min(posts),maxId=max(posts),
        limitation='Visible posts include service/media entries; this is not 35 distinct patch notes or proof deleted posts were recovered.'),
    cacheReaudit=(OUT/'current-cache/cache-reaudit.json').as_posix(),findings=findings,
    excludedCrossModeOrHistoricalSources=excluded,gapMatrix=gaps,
    searchScope='Targeted web searches for Classic books, blacksmith, trainer, skills, needs, block prices, levels, public code and wiki; official-forum tag and visible mode-channel archive reviewed. Not exhaustive internet coverage.',
    unresolvedPublicAccess=[dict(url='https://ruwebdata.c7x.dev/client/addons.json',result='HTTP 404 during this pass; a historically recovered URL is not a current usable index endpoint.'),
                            dict(url='https://cristalix.gg/info/minigames/prisonclassic',result='404 page; not a public Classic wiki.')])
(OUT/'independent-gap-research.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def proof(f):
    links=[]
    for s in f['sources']:
        if 'url' in s:
            links.append(f"[источник]({s['url']})")
        else:
            links.append(f"[строка {s['line']}]({Path(s['path']).as_posix()}:{s['line']})")
    return ', '.join(links)

table='\n'.join(f"| {f['id']} | {f['claim']} | {f['publishedAt'][:10] if f.get('publishedAt') else 'Текст клиента / метаданные'} | {proof(f)} |" for f in findings)
matrix='\n'.join(f"| {g['system']} | {g['result']} | {g['missing']} |" for g in gaps)
report=f'''# Prison Classic: самостоятельный поиск недостающих правил

20 октября 2026 года. Проверены свежий локальный кэш дополнений/переводов, RU/EN-тексты, публичная история канала режима, официальный форум, сайт статистики и результаты поиска исходников/гайдов. Это отдельный проход по пробелам после разбора 289 игровых кадров.

## Что удалось уточнить

Найдены **{len(findings)} закреплённых уточнений**. У них разные статусы: описание в клиенте, датированный патчноут или поля публичного сайта. Они не объявлены проверенными действиями текущего сезона.

| ID | Уточнение | Дата / тип | Доказательство |
| --- | --- | --- | --- |
{table}

Кузница теперь уточнена и в [каталоге книг](C:/Users/user/Documents/roblox-prison-research/client-audit/BOOKS-SYSTEM.md): две книги одного типа и уровня, оплата звёздами. Ошибка и подпись кнопки не раскрывают цену или формулу результата. `100%` в шаблоне бустера не устанавливает порядок сложения нескольких бустеров.

Декабрьское `3 → 2` у Укрепления — историческое изменение силы эффекта слабости, не таблица уровней книги. [Февральская новость](https://forum.cristalix.gg/threads/303993/) дополнительно говорит об ослаблении Укрепления в PvP, без новых чисел. Поэтому декабрьское значение не проставлено всем текущим книгам.

## Что показал повторный просмотр файлов

Индекс дополнений обновлялся 20 октября, но content hash всех трёх модулей совпадает с прежним: Socials, Gama, Wada **4.18.6**. В четырёх доступных RU/EN-пакетах Prison/PrisonEvo нет добавленных, удалённых или изменённых свойств по сравнению с сохранёнными копиями. Русский Prison содержит 2500 свойств, из них **1837 Classic**; английский — 2323 / 1705.

В локальном cache 1041 файл: 4 addons, 99 lang, 474 p13n, 464 textures. `cache/mods` отсутствует. Это ограничение найденного дискового кэша, а не доказательство отсутствия загруженных в память дополнений. Системные файлы аккаунта, игровые логи и память процесса в этом проходе не читались. [Результат повторной проверки](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/current-cache/cache-reaudit.json).

Ранее разобранный [код интерфейсов](C:/Users/user/Documents/roblox-prison-research/client-audit/CLIENT-LOGIC-AUDIT.md) получает схемы, цены и состояние с сервера. Новое чтение переводов даёт дополнительные условия и единицы, но не заменяет отсутствующие значения `%d` и `%s`.

## Публичные источники и границы

Сохранены 35 доступных записей канала с ID 1–43, включая служебные сообщения и медиа. Прочитаны патчи декабря 2025, февраля 2026, анонсы мая/августа/октября. В канале есть **оба варианта Classic и Quick**. Августовский пост 40 следует за явным анонсом Quick в посте 39: правила 50 уровней и выдачи силы не перенесены автоматически в текущий Classic.

Официальный сайт статистики публикует 10 полей Prison: уровень, блоки, чистые блоки, деньги, убитые боссы, крысы, чистые крысы, убийства, смерти и время игры. Это метаданные статистики, а не таблица требований уровня. `default / Обычный` в этой схеме не отождествлён с под-сервером снимков. [Поля сайта](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/public-gap-sources/top-prison-field-metadata.json).

Поиск часто возвращает подробные, но неподходящие числа: Prison OldSchool, PrisonEvo, VimeWorld Classic, SkyBlock и предложения игроков. Они исключены из баланса Cristalix Classic. Например, найденное сообщение об удалении Пластолома относится к VimeWorld; наши снимки показывают Пластолом в Cristalix. Гайд 2018 года сохранён как исторический ориентир, его цены не заменяют текущие меню.

## Что закрыто и что осталось

| Система | Результат самостоятельного поиска | Осталось получить |
| --- | --- | --- |
{matrix}

Ни в проверенных локальных файлах, ни в просмотренных публичных первичных материалах не получена полная серверная конфигурация текущего Classic. Следующий прямой источник — серверные меню `/wiki`, `/skills`, `/level`, `/upgrade`, Кузница и наблюдения игры. Увидеть меню можно отдельно от подтверждения покупки; вероятности и поведение неудачи требуют дополнительных свидетельств, а не подстановки похожих чисел из другого режима.

## Проверяемые материалы

- [14 уточнений, источники, исключения и матрица пробелов](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/independent-gap-research.json).
- [Проверка источников и ссылок этого прохода](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/independent-gap-validation.json).
- [Общий отчёт по игровым снимкам](C:/Users/user/Documents/roblox-prison-research/client-audit/RECOVERED-GAME-DATA.md).
'''
(ROOT/'INDEPENDENT-GAP-RESEARCH.md').write_text(report,encoding='utf-8')

# Check source hashes and exact localization anchor lines.
checked_sources = set()
for f in findings:
    for s in f['sources']:
        path=Path(s['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest()==s['sha256'],path
        checked_sources.add((path.as_posix(),s['sha256']))
        if 'key' in s:
            assert '"'+s['key']+'"' in path.read_text(encoding='utf-8').splitlines()[s['line']-1]
for p in public['pages']:
    assert hashlib.sha256(Path(p['localPath']).read_bytes()).hexdigest()==p['sha256']
for language in cache['languageRecords']:
    if language['cached']:
        assert not language['added'] and not language['changed'] and not language['removed']
assert not any(a['contentChanged'] for a in cache['addonComparison'])
assert sum(cache['cacheCounts'].values())==1041
assert len(findings)==14 and len(gaps)==8
validation_path=OUT/'independent-gap-validation.json'
validation_path.write_text('{}\n',encoding='utf-8')
links=0
for target in re.findall(r'\]\(([^)\n]+)\)',report):
    if target.startswith(('https://','http://','#')):continue
    m=re.fullmatch(r'(.+?)(?::(\d+))?',target);path=Path(m[1])
    assert path.is_file(),target
    if m[2]:assert 1<=int(m[2])<=len(path.read_text(encoding='utf-8').splitlines())
    links+=1
validation=dict(findings=len(findings),statusCounts=dict(Counter(f['status'] for f in findings)),
    gapCategories=len(gaps),publicChannelVisiblePosts=len(posts),preservedPublicPages=len(public['pages'])+1,
    uniqueFindingSourceHashes=len(checked_sources),localLinksChecked=links,
    addonContentUnchanged=True,languagePropertiesUnchanged=True,
    fullCurrentServerBalanceRecovered=False,status='Source hashes, localization anchors, counts and report links passed.')
validation_path.write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
