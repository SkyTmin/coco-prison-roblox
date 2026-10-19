"""Validate the evidence for the human-written semantic audit.

This reads sources and class-file indexes as data, never loads game classes.
Anchor validation is not a proof of every interpretation in the prose.
"""
from pathlib import Path
import hashlib
import json
import re
import sqlite3
import zipfile

ROOT = Path(__file__).parent
OUT = ROOT / 'code-analysis'
db = sqlite3.connect((OUT / 'code-index.sqlite').as_uri() + '?mode=ro', uri=True)
db.row_factory = sqlite3.Row
facts = []


def fact(fid, system, finding, entry, start, end, *tokens, archive='addon-wada', limit=''):
    row = db.execute('SELECT * FROM sources WHERE archive=? AND entry=?', (archive, entry)).fetchone()
    assert row is not None, (fid, entry)
    source = Path(row['path'])
    data = source.read_bytes()
    assert hashlib.sha256(data).hexdigest() == row['sha256'], (fid, 'source hash')
    lines = data.decode('utf-8').splitlines()
    assert 1 <= start <= end <= len(lines), (fid, 'range')
    excerpt = '\n'.join(lines[start-1:end])
    for token in tokens:
        assert token in excerpt, (fid, token)
    facts.append(dict(id=fid, system=system, finding=finding, limitation=limit,
                      evidence=dict(archive=archive, originalEntry=entry, path=str(source),
                                    sha256=row['sha256'], startLine=start, endLine=end,
                                    anchorTokens=tokens)))


fact('L01', 'loader', 'Клиент создаёт кэш доставляемых модов в cache/mods относительно сохранённого корневого пути.',
     '#HpebM.java', 151, 169, 'cache/mods', archive='minecraft')
fact('L02', 'loader', 'Загрузчик читает mod.properties, main, persistent и параметры инициализации.',
     '#LWFCU.java', 128, 224, 'mod.properties', 'persistent', 'asyncModLoad', 'disableInitModPlease', 'main', archive='minecraft',
     limit='persistent здесь влияет на повторное использование загрузчика; это не доказательство политики дискового кэша.')
fact('L03', 'loader', 'Имя файла кэша строится из hex хеша с двумя уровнями префиксов по два символа.',
     '#sDygh.java', 22, 31, 'formatHex', 'substring(0, 2)', 'substring(2, 4)', archive='minecraft')
fact('L04', 'loader', 'Байты дополнения записываются в вычисленный путь; ошибка записи перехватывается.',
     '#PrcRb.java', 97, 108, 'Files.write', 'Error on save mod to cache', archive='minecraft')
fact('L05', 'loader', 'В пакетной ветке cjk запись доставленных модов в кэш запускается только при установленном младшем бите флагов.',
     '#HpebM.java', 57, 65, '(var1 & 1L) != 0L', '#KNvmc.sfqz', archive='minecraft',
     limit='Это условие конкретной ветки загрузки; фактическое значение флага в сессии Prison не получено.')
fact('L06', 'loader', 'Парсер пакета модов читает отдельное long-поле флагов и ограничивает массив данных 5242880 байтами.',
     '#KyYjB.java', 131, 140, '!A R L g P', '5242880', archive='minecraft',
     limit='Лимит относится к полю данных этого пакета, не к размеру всего клиента или всего декомпилированного корпуса.')
fact('L07', 'loader', 'Обработчик пакета передаёт разобранный набор модов и long-флаги в cjk.',
     '#WrsTj.java', 59, 70, '#yAyem.shLR', 'var3.cjk(#zRXeH.slUi(var1), var5)', archive='minecraft')
fact('L08', 'loader', 'Чтение из кэша проверяет байты по ожидаемому хешу, при несовпадении возвращает null.',
     '#OCoUe.java', 37, 44, 'Files.readAllBytes', '#eCTsT.seev', '? null', archive='minecraft')
fact('W01', 'transport', 'Wada различает w4 и w2, ставит сообщения в очередь до load и отбрасывает сообщения прежней сессии.',
     'gg/cristalix/wada/a/a.java', 11, 92, '1024', 'w4:', 'w2:', 'var5 != var4', 'var1.e()')
fact('W02', 'transport', 'При смене сервера выполняются сброс и handshake; после load очищается ожидание и отправляется loaded.',
     'gg/cristalix/wada/a/b.java', 86, 150, 'awaitingHandshake=false', 'loaded', 'ready:setup', 'ready_to_setup')
fact('T01', 'talents', 'JSON схемы содержит версию, resetAllowed, usePoints, requireConnectionToStart, revealDepth и список узлов.',
     'gg/cristalix/wada/component/menu/h/a/b.java', 33, 62, 'protocolVersion', 'resetAllowed', 'usePoints', 'requireConnectionToStart', 'revealDepth', 'nodes')
fact('T02', 'talents', 'Узел принимает id, вид, координаты, максимальный ранг, родителей и режим зависимости из JSON.',
     'gg/cristalix/wada/component/menu/h/a/c.java', 154, 194, 'id', 'maxRank', 'parents', 'parentsMode', 'parentsCount')
fact('T03', 'talents', 'Доступные очки, потраченные очки, состояние, ранг и цена следующего ранга обновляются из полученного JSON.',
     'gg/cristalix/wada/component/menu/h/a/b.java', 82, 102, 'availablePoints', 'spentPoints', 'state', 'rank', 'nextCost')
fact('T04', 'talents', 'На клиенте вычисляется предпросмотр пути: режимы родителей, множества узлов и сумма nextCost.',
     'gg/cristalix/wada/component/menu/h/d/a.java', 25, 179, 'var4.sort', 'switch (var3)', 'this.a.size()', 'var2 += var5.as().s()',
     limit='Сортировка отдельных родительских путей и последовательные улучшения не доказывают глобальную оптимальность результата.')
fact('T05', 'talents', 'Upgrade и refund создают UUID запроса и отправляют идентификатор меню и узла.',
     'gg/cristalix/wada/component/menu/h/a.java', 49, 83, 't4t:refund', 't4t:upgrade', 'UUID.randomUUID()', 'CONFIRM_REQUIRED', 'OK')
fact('T06', 'talents', 'Запрос пути содержит UUID меню, целевой id, UUID запроса, флаг и список ещё не изученных узлов.',
     'gg/cristalix/wada/component/menu/h/a.java', 178, 202, 'var4.size()', 't4t:path')
fact('T07', 'talents', 'Обработчики state и delta используют один разбор; result проверяет UUID меню.',
     'gg/cristalix/wada/component/menu/h/b.java', 10, 79, 't4t:state', 't4t:delta', 't4t:result', 'this.a(var2)')
fact('T08', 'talents_old', 'Старая схема создаёт узлы из пакета до исчерпания данных и затем связывает их.',
     'b/a/a/b/s/a.java', 52, 68, 'while (var2.p())', 'new e(', 'var6.a(this.b)')
fact('T09', 'talents_old', 'Старый интерфейс рассчитывает доступность по связям; запросы клика ограничены паузой 500 мс.',
     'b/a/a/b/s/e.java', 299, 321, '500L', 'tree:any_click', 'tree:upgrade',
     limit='Это ограничение частоты действий UI; не длительность выдачи таланта на сервере.')
fact('T10', 'talents_old', 'Обновление изученного состояния старого узла читает boolean из пакета.',
     'b/a/a/b/s/e.java', 96, 147, 'this.m(var1.f())', 'this.an.isEmpty()', 'this.aq')
fact('D01', 'daily', 'Серверная модель календаря передаёт currentIndex, taken, следующий deadline и множества доступных/полученных дней.',
     'gg/cristalix/wada/component/menu/c/b/a.java', 52, 74, 'nextRewardAvailableAt', 'claimableDays', 'claimedDays', 'totalPages')
fact('D02', 'daily', 'Нажатие на доступную карточку отправляет daily:click с UUID меню и индексом дня.',
     'gg/cristalix/wada/component/menu/c/c/a.java', 109, 117, 'daily:click', 'this.O.aJ()', 'this.Q')
fact('D03', 'daily', 'Остаток времени отображается по абсолютному сроку в миллисекундах с округлением секунд вверх.',
     'gg/cristalix/wada/component/menu/c/b.java', 219, 229, 'toEpochMilli()', '999L', '1000L')
fact('S01', 'skills', 'Активация навыка читает UUID и длительность double из пакета; реестр содержит отдельные каналы счётчика и привязки.',
     'gg/cristalix/wada/component/O/a.java', 166, 194, 'var1.e()', 's7v:activate', 's7v:count', 's7v:binding')
fact('S02', 'skills', 'Виджет переводит длительность навыка из секунд в миллисекунды для анимации.',
     'gg/cristalix/wada/component/O/b/a.java', 21, 31, '1000.0',
     limit='Длительность индикатора не определяет серверный урон/эффект навыка.')
fact('B01', 'battle_pass', 'Контроллер battle pass принимает отдельные обновления уровня, опыта, наград, результатов и заданий.',
     'gg/cristalix/wada/component/menu/a/a.java', 128, 154, 'b8s:level', 'b8s:exp', 'b8s:reward-result', 'b8s:questProgress')
fact('B02', 'battle_pass', 'Кнопка награды отправляет claim-reward; в этом обработчике нет выдачи предмета.',
     'gg/cristalix/wada/component/menu/a/d/c/a/c.java', 8, 14, 'b8s:claim-reward')
fact('R01', 'reward_display', 'SimpleViewReward разбирает присланный JSON items и запускает показ.',
     'gg/cristalix/wada/component/N/a.java', 119, 132, 'fromJson', 'items', 'this.a.b(var4)')
fact('R02', 'reward_display', 'Модель показываемой награды содержит icon, name, quality.',
     'gg/cristalix/wada/component/N/a/a.java', 28, 40, 'icon', 'name', 'quality',
     limit='В исследованной модели показа нет таблицы вероятностей выпадения Prison.')
fact('H01', 'health_display', 'Полоса сущности отображает отношение текущего здоровья к максимуму и округлённые подписи.',
     'gg/cristalix/wada/component/s/b/a.java', 104, 142, 'Math.ceil',
     limit='Это визуализация здоровья, не серверный ИИ и не формула боя босса.')
fact('P01', 'progress_display', 'ReactiveProgress принимает текущий и максимальный прогресс как внешние значения.',
     'gg/cristalix/wada/component/H/a.java', 42, 66, 'var1.e()', 'var1.k()')
fact('P02', 'level_hud_old', 'Старый HUD читает деньги, текст уровня и пару значений опыта из пакета.',
     'b/a/a/b/h/a/d.java', 39, 82, 'var1.b()', 'var1.h()', 'textCoin', 'textExperience')
fact('U01', 'boosters', 'Время завершения бустера устанавливается по UUID и long из пакета.',
     'gg/cristalix/wada/component/g/a.java', 239, 249, 'var1.k()', 'var1.c()')
fact('E01', 'events', 'IncidentManager принимает отдельный пакет периода события и передаёт данные виджету.',
     'gg/cristalix/wada/component/v/a.java', 40, 86, 'i6t:period', 'gg.cristalix.wada.component.v.a.a.b(var1)',
     limit='Сам реестр не устанавливает конкретный 20-минутный цикл Prison.')
fact('N01', 'dialogs', 'Модель диалога принимает UUID, заголовок, параметры отображения, реплики и ответы из пакета.',
     'gg/cristalix/wada/component/n/a/a.java', 79, 105, 'var0.k()', 'var0.h()', 'while (var0.p())')
fact('N02', 'dialogs', 'Выбранный номер ответа отправляется через d11r:request.',
     'gg/cristalix/wada/component/n/b/b.java', 417, 421, 'd11r:request', '.a(var1)')
fact('I01', 'inventory', 'Менеджер инвентаря применяет обновления предметов и эффектов только к совпадающему UUID окна.',
     'gg/cristalix/wada/component/x/a/a.java', 15, 64, 'equals(var3)', 'piv:items', 'piv:effects')
fact('I02', 'inventory', 'Модель инвентаря наполняет слоты предметами, прочитанными из пакета.',
     'gg/cristalix/wada/component/x/a/b/a.java', 25, 49, 'int var4 = var1.b()', 'var1.a()', 'this.a(var4, var5)')
fact('C01', 'input_control', 'Правило клика принимает target, buttons, mode, материалы с data, координаты и id сущностей.',
     'gg/cristalix/wada/component/i/a/d.java', 25, 79, 'target', 'buttons', 'mode', 'materials', 'locations', 'entities')
fact('C02', 'input_control', 'Клиентский cooldown ограничивается минимумом 0.1 секунды, хранит срок и при необходимости рисует полосу.',
     'gg/cristalix/wada/component/i/a.java', 185, 199, 'Math.max(var3.b(), 0.1)', '1000.0', 'this.h.put')
fact('C03', 'input_control', 'Параметры cooldown приходят в JSON: button, seconds, barColor, showBar.',
     'gg/cristalix/wada/component/i/a/b.java', 43, 50, 'button', 'seconds', 'barColor', 'showBar')
fact('Q01', 'decompiler_quality', 'Java-текст eto выглядит как вызов etn на том же объекте; байткод ссылается на метод суперкласса.',
     '#PrcRb.java', 17, 31, 'eto(this)', 'var0.etn()', archive='minecraft',
     limit='См. проверку INVOKESPECIAL в audit-validation.json; Java-текст нельзя считать точной заменой байткода.')
fact('G01', 'gama', 'В таблице значков Gama есть TOILET_PAPER_LVL1..6.',
     'oS.java', 487, 499, 'TOILET_PAPER_LVL1', 'TOILET_PAPER_LVL6', archive='addon-gama',
     limit='Это имена значков, не реализация потребности в туалете.')

aliases = json.loads((OUT / 'enum-aliases.json').read_text(encoding='utf-8'))
expected = {
    'gg/cristalix/wada/component/menu/h/a/d': ['START', 'NORMAL', 'NOTABLE', 'KEYSTONE', 'DECORATION'],
    'gg/cristalix/wada/component/menu/h/a/e': ['HIDDEN', 'LOCKED', 'EXCLUDED', 'AVAILABLE', 'AFFORDABLE', 'PARTIAL', 'MAXED'],
    'gg/cristalix/wada/component/menu/h/a/f': ['CONNECTIVITY', 'ALL', 'ANY', 'AT_LEAST'],
}
talent_enums = []
enum_initializers = []
for owner, names in expected.items():
    found = {r['fieldAlias']: r for r in aliases if r['archive'] == 'addon-wada' and r['class'] == owner}
    for i, name in enumerate(names):
        assert found[chr(97+i)]['runtimeEnumName'] == name, (owner, name)
        talent_enums.append(found[chr(97+i)])
    initializer = db.execute('''SELECT m.id FROM methods m JOIN classes c ON m.class_id=c.id
        WHERE c.archive='addon-wada' AND c.name=? AND m.name='<clinit>' ''', (owner,)).fetchone()
    strings = [r[0] for r in db.execute('SELECT value FROM literals WHERE method=? ORDER BY pc', (initializer['id'],))]
    ctors = [dict(r) for r in db.execute("SELECT pc,descriptor FROM calls WHERE caller=? AND owner=? AND name='<init>' ORDER BY pc", (initializer['id'], owner))]
    assert strings == names, (owner, strings)
    assert len(ctors) == len(names) and all(r['descriptor']=='(Ljava/lang/String;I)V' for r in ctors)
    enum_initializers.append(dict(owner=owner, stringOrder=strings, constructors=ctors))

special = [dict(r) for r in db.execute('''
    SELECT m.descriptor AS callerDescriptor, x.* FROM calls x
    JOIN methods m ON x.caller=m.id JOIN classes c ON m.class_id=c.id
    WHERE c.archive='minecraft' AND c.name='#PrcRb' AND m.name='eto'
      AND x.owner='#QcTxC' AND x.name='etn' AND x.opcode=183
''')]
assert len(special) == 1
cache_path = [
    ('#HpebM', 'cjk', '#KNvmc', 'sfqz'),
    ('#KNvmc', 'sfqz', '#TLgEk', '<init>'),
    ('#TLgEk', 'fqy', '#vXBDp', 'sciC'),
    ('#vXBDp', 'sciC', '#cAQAr', 'eFz'),
    ('#QWCdd', 'eFz', '#PrcRb', 'seFy'),
    ('#PrcRb', 'seFy', 'java/nio/file/Files', 'write'),
]
for caller_owner, caller_name, callee_owner, callee_name in cache_path:
    assert db.execute('''SELECT 1 FROM calls x JOIN methods m ON x.caller=m.id
        JOIN classes c ON m.class_id=c.id WHERE c.archive='minecraft' AND c.name=?
        AND m.name=? AND x.owner=? AND x.name=?''',
        (caller_owner, caller_name, callee_owner, callee_name)).fetchone(), (caller_owner, caller_name)
handlers = json.loads((OUT / 'wada-handler-map.json').read_text(encoding='utf-8'))
assert len(handlers) == 620 and len({r['channel'] for r in handlers}) == 613
assert all(r['handlers'] for r in handlers)
counts = json.loads((OUT / 'index-report.json').read_text(encoding='utf-8'))
assert counts['totals']['sources'] == counts['totals']['classes'] == 27259
assert db.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
assert db.execute('SELECT count(*) FROM methods').fetchone()[0] == 329094
assert db.execute('SELECT count(*) FROM calls').fetchone()[0] == 843672

payload = dict(scope='Static client/add-on analysis; module availability does not establish Prison activation.',
               findings=facts, talentEnumNames=talent_enums,
               limitations=['Every source was indexed/scanned; no claim of manual line-by-line reading of 2,874,693 lines.',
                            'Source anchors validate locations, not automatic semantic correctness.',
                            'Server-side Prison formulas and configuration were not obtained.'])
(OUT / 'semantic-findings.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
validation = dict(sourceAnchorsChecked=len(facts), sourceHashesMatched=True, indexQuickCheck='ok',
                  handlerRegistrations=620, distinctChannels=613, unresolvedRegisteredHandlers=0,
                  talentEnumAliasesChecked=len(talent_enums), talentEnumInitializers=enum_initializers,
                  conditionalCacheWriterEdgesChecked=len(cache_path),
                  invokespecialCounterexample=special,
                  gameCodeExecuted=False, validationLimits='Checks integrity and source anchors, not gameplay or JVM type correctness.')
(OUT / 'audit-validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(validation, ensure_ascii=False))

guides = ['CLIENT-LOGIC-AUDIT.md', 'TALENT-TREE-AUDIT.md', 'DECOMPILER-QUALITY.md']
checked_links = []
for name in guides:
    content = (ROOT/name).read_text(encoding='utf-8')
    for target in re.findall(r'\]\((C:/[^)\n]+)\)', content):
        match = re.fullmatch(r'(.+?)(?::(\d+))?', target)
        path = Path(match[1])
        assert path.exists(), (name, target)
        if match[2]:
            line = int(match[2])
            assert 1 <= line <= len(path.read_text(encoding='utf-8').splitlines()), (name, target)
        checked_links.append(dict(document=name, target=target))
validation['markdownLocalLinksChecked'] = len(checked_links)
(OUT / 'audit-validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

# Compact review bundle: reports, indexes of findings, and only cited source files.
# The full sources remain in CLIENT-DECOMPILED-SOURCES.zip; the SQLite DB is not duplicated.
bundle = ROOT/'CLIENT-LOGIC-AUDIT.zip'
members = {ROOT/name for name in guides}
members.update(OUT/name for name in ['semantic-findings.json', 'audit-validation.json', 'index-report.json',
                                    'WADA-MODULES.md', 'wada-modules.json', 'wada-handler-map.json',
                                    'enum-aliases.json', 'whole-corpus-scan.json', 'whole-corpus-hits.json'])
members.update(ROOT/name for name in ['build-semantic-audit.py', 'code-query.py', 'index-code.py',
                                     'map-wada.py', 'build-handler-map.py', 'scan-corpus.py', 'recover-enum-names.py'])
members.update(Path(f['evidence']['path']) for f in facts)
for target in (r['target'] for r in checked_links):
    path = Path(re.fullmatch(r'(.+?)(?::(\d+))?', target)[1])
    if path.suffix in ('.java', '.kt'):
        members.add(path)
manifest = []
with zipfile.ZipFile(bundle, 'w', zipfile.ZIP_DEFLATED) as z:
    for path in sorted(members):
        data = path.read_bytes()
        entry = path.relative_to(ROOT).as_posix()
        z.writestr(entry, data)
        manifest.append(dict(entry=entry, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    z.writestr('review-bundle-manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
with zipfile.ZipFile(bundle) as z:
    assert z.testzip() is None
bundle_hash = hashlib.sha256(bundle.read_bytes()).hexdigest()
(OUT/'review-bundle.json').write_text(json.dumps(dict(path=str(bundle), bytes=bundle.stat().st_size,
    sha256=bundle_hash, entries=len(manifest)+1, crcCheck='ok', sourceFiles=sum(1 for p in members if p.suffix in ('.java','.kt')),
    note='Reports use original absolute workspace links; retained relative tree permits manual browsing after extraction. Analysis scripts need the original full corpus and SQLite index.'), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(markdownLinksChecked=len(checked_links), bundle=str(bundle), sha256=bundle_hash,
                      bytes=bundle.stat().st_size, entries=len(manifest)+1), ensure_ascii=False))
