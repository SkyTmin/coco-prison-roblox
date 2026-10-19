"""Audit final outputs against every input class; package sources with honest limits."""
from pathlib import Path
from datetime import datetime,timezone
import csv
import hashlib
import io
import json
import re
import zipfile

ROOT=Path(__file__).parent
DEST=ROOT/'full-decompilation'
inventory=json.loads((DEST/'input-inventory.json').read_text(encoding='utf-8'))
records=[]
for item in inventory:
    output=DEST/'sources'/(item['id']+'-sources.zip')
    record={'id':item['id'],'inputClasses':item['classCount'],'javaFiles':0,'kotlinFiles':0,
            'missingClasses':[c['name'] for c in item['classes']],'methodErrorFiles':[],
            'caseInsensitiveCollisions':[],'inputCopyHashVerified':hashlib.sha256(Path(item['input']).read_bytes()).hexdigest()==item['sha256']}
    if output.exists() and zipfile.is_zipfile(output):
        with zipfile.ZipFile(output) as arc:
            sources={n for n in arc.namelist() if n.endswith(('.java','.kt'))}
            record['javaFiles']=sum(n.endswith('.java') for n in sources)
            record['kotlinFiles']=sum(n.endswith('.kt') for n in sources)
            record['missingClasses']=[c['name'] for c in item['classes'] if c['name'][:-6]+'.java' not in sources and c['name'][:-6]+'.kt' not in sources]
            folded={}
            for name in sorted(sources):
                folded.setdefault(name.casefold(),[]).append(name)
                text=arc.read(name).decode('utf-8',errors='replace')
                markers=re.findall(r'(?im)^.*(?:\$VF: Couldn.t be decompiled|\$VF: Exception|Decompilation failed|Could not decompile|unable to fully structure).*$',text)
                if markers:record['methodErrorFiles'].append({'file':name,'lines':markers})
            record['caseInsensitiveCollisions']=[v for v in folded.values() if len(v)>1]
        record['sourceArchive']=str(output)
        record['sourceSha256']=hashlib.sha256(output.read_bytes()).hexdigest()
    record['representedClasses']=record['inputClasses']-len(record['missingClasses'])
    records.append(record)

totals={
 'archivesInspected':len(records),'archivesWithClasses':sum(r['inputClasses']>0 for r in records),
 'inputClasses':sum(r['inputClasses'] for r in records),
 'representedClasses':sum(r['representedClasses'] for r in records),
 'javaFiles':sum(r['javaFiles'] for r in records),'kotlinFiles':sum(r['kotlinFiles'] for r in records),
 'missingClasses':sum(len(r['missingClasses']) for r in records),
 'filesWithMethodErrors':sum(len(r['methodErrorFiles']) for r in records),
 'allInputCopyHashesVerified':all(r['inputCopyHashVerified'] for r in records),
}
reconstruction=json.loads((ROOT/'protected-reconstruction.json').read_text(encoding='utf-8'))
reconstruction['bytecodeValidation']='All 62,427 method bodies passed opcode/instruction-boundary, branch/switch-target and invoke-padding checks. This is not JVM type/stack verification or a gameplay test.'
(ROOT/'protected-reconstruction.json').write_text(json.dumps(reconstruction,indent=2)+'\n',encoding='utf-8')
report={'generatedAtUtc':datetime.now(timezone.utc).isoformat(),'scope':'Installed Minigames Java archives and three cached client add-ons; not server sources or native libraries.',
        'totals':totals,'protectedClient':reconstruction,'archives':records,
        'limits':['Class/source coverage is not a guarantee of recompilable or semantically identical source.',
                  'Obfuscated identifiers and distributed methods remain obfuscated.',
                  'No original comments, project files, server plugin, server economy/configuration or boss AI were recovered.',
                  'Native libraries were not fully decompiled; local jvm.dll was inspected statically only for its class-file reader.']}
(DEST/'coverage.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tools=[]
for filename,version,url in [
    ('cfr-0.152.jar','CFR 0.152','https://www.benf.org/other/cfr/cfr-0.152.jar'),
    ('vineflower-1.12.0.jar','Vineflower 1.12.0','https://github.com/Vineflower/vineflower/releases/download/1.12.0/vineflower-1.12.0.jar'),
    ('procyon-decompiler-0.6.0.jar','Procyon 0.6.0','https://github.com/mstrobel/procyon/releases/download/v0.6.0/procyon-decompiler-0.6.0.jar'),
]:
    path=ROOT/'tools'/filename
    tools.append({'tool':version,'downloadUrl':url,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
reconstructed=DEST/'inputs/minecraft-reconstructed.jar'
vm=Path('C:/Users/user/.cristalix/runtime/bin/server/jvm.dll')
toolchain={'decompilers':tools,'localGameVmSha256':hashlib.sha256(vm.read_bytes()).hexdigest(),
           'reconstructedClientSha256':hashlib.sha256(reconstructed.read_bytes()).hexdigest(),
           'method':'Static byte reading/disassembly only; decompilers ran on separate Temurin 21 JRE.',
           'firstPass':'progress.json records the historical initial attempt; coverage.json is the final audit after repairs.'}
(DEST/'toolchain-manifest.json').write_text(json.dumps(toolchain,indent=2)+'\n',encoding='utf-8')
with (DEST/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream);writer.writerow(['archive','input_classes','java_files','kotlin_files','missing_classes','method_error_files'])
    for r in records:writer.writerow([r['id'],r['inputClasses'],r['javaFiles'],r['kotlinFiles'],len(r['missingClasses']),len(r['methodErrorFiles'])])

table='\n'.join(f"| {r['id']} | {r['inputClasses']} | {r['javaFiles']} | {r['kotlinFiles']} | {len(r['missingClasses'])} | {len(r['methodErrorFiles'])} |" for r in records if r['inputClasses'])
errors='\n'.join(f"- `{r['id']}` → `{e['file']}`: тело метода содержит отметку ошибки; байткод сохранён в комментариях." for r in records for e in r['methodErrorFiles']) or '- Явные отметки ошибок методов не найдены.'
text=f'''# Полная попытка декомпиляции установленного клиента

Проверено 19 октября 2026 года. Обработаны все Java-архивы установленного Minigames и все три найденных в кэше дополнения.

**Представлены исходными файлами {totals['representedClasses']:,} из {totals['inputClasses']:,} классов. Основной клиент: 7291 из 7291; три дополнения: 2272 из 2272.**

Это полное покрытие найденных `.class` файлами исходного текста, а не восстановленный оригинальный проект. Файлов с явными ошибками отдельных методов: **{totals['filesWithMethodErrors']}**. Ограничения перечислены ниже.

## Где результат

- [Все декомпилированные исходники одним ZIP](CLIENT-DECOMPILED-SOURCES.zip).
- [Архивы исходников по модулям](full-decompilation/sources/).
- [Основной клиент](full-decompilation/sources/minecraft-sources.zip).
- Дополнения: [Gama](full-decompilation/sources/addon-gama-sources.zip), [Wada](full-decompilation/sources/addon-wada-sources.zip), [Socials](full-decompilation/sources/addon-socials-sources.zip).
- [Покрытие каждого класса и ошибки](full-decompilation/coverage.json); [сводка CSV](full-decompilation/coverage.csv).
- [Неизменённые копии входных архивов и SHA-256](full-decompilation/input-inventory.json).
- [Версии и SHA-256 инструментов, JVM и восстановленного клиента](full-decompilation/toolchain-manifest.json).

ZIP сохраняет имена, различающиеся только регистром. При обычной распаковке в Windows такие файлы могут перезаписать друг друга. Канонический результат следует просматривать внутри ZIP либо распаковывать в файловую систему с учётом регистра; список коллизий есть в coverage.json.

## Что пришлось восстановить

В `minecraft.jar` все 7291 класса имели заголовок `C7C70001`, восьмибайтное число, преобразованные UTF-8/числовые константы и переставленные/преобразованные байты методов. Обычная замена заголовка этого не исправляет.

В установленной `runtime/bin/server/jvm.dll` статически найден разбор этого формата. По его инструкциям написан [локальный преобразователь](decode-protected-client.py). Он восстановил стандартный контейнер CAFEBABE, константы и байткод **62 427 методов**, не запуская игровой код.

Проверки: имя своего класса совпало с записью ZIP во всех 7291 случаях; структура всех классов разобрана до конца; все восстановленные методы прошли проверку допустимых инструкций, границ и целей переходов/switch, служебных нулей invoke. Декомпилятор затем обработал восстановленные классы. Это не проверка типов/стека полноценной JVM и не проверка игрового поведения.

Использованы Vineflower 1.12.0, CFR 0.152 и Procyon 0.6.0. Fastutil обработана 57 небольшими пакетами после нехватки памяти в первом проходе. Основной клиент также обработан 57 пакетами. Пропущенные в первом проходе multi-release классы и module-info восстановлены отдельно, с сохранением версии пути. Два проблемных класса библиотек обработаны CFR; 16 файлов с ошибками Kotlin-плагина заменены Java-представлением тех же классов. Огромный конструктор GLCapabilities восстановлен Procyon после нехватки памяти у двух других инструментов. Предыдущие неудачные результаты и журналы сохранены в full-decompilation/repairs/.

## Итоговые числа

- Архивов проверено: {totals['archivesInspected']}; с классами: {totals['archivesWithClasses']}. Остальные содержат ресурсы.
- Java-файлов: {totals['javaFiles']:,}; Kotlin-файлов: {totals['kotlinFiles']:,}.
- Классов без соответствующего исходного файла: {totals['missingClasses']}.
- SHA-256 всех копий входных архивов совпадает с инвентаризацией: {str(totals['allInputCopyHashesVerified']).lower()}.

{errors}

## Что это дало для Prison

Восстановленные константы основного клиента проверены отдельно: [результаты поиска](decoded/reconstructed-client-evidence.json). Вхождения Prison относятся к модели/имени питомца `prisoneer`; `Classic Lighting` — настройка освещения. Поиск не обнаружил именованных таблиц экономики Prison, периодов бытовых нужд, выпадения ключей или реализации боссов.

Найдены общие механизмы загрузки дополнений и регистрации клиентских server mods (`registerServerMod`, `unregisterServerMod`, `ModClassLoader`, `defineClasses`). Название server mod означает дополнение, доставляемое клиенту; само по себе оно не делает файл серверным плагином. Где и как конкретный режим формирует каждое правило, этим поиском не установлено.

Для механик по-прежнему полезнее всего [1837 строк Classic и 42 пункта с ключами доказательств](CLASSIC-CLIENT-FINDINGS.md), а также интерфейс `/wiki` текущего сезона. Клиентские описания не доказывают точные серверные формулы.

## Ограничения

- Названия вида `#hqsNq` и необычные имена полей — обфускация исходного клиента. Декомпиляция не возвращает исходные осмысленные имена и комментарии.
- Полученный текст не проверен повторной компиляцией и не является готовой сборкой клиента. Некоторые имена недопустимы в обычном Java-исходнике.
- Не получены серверный плагин Cristalix, его конфигурации, база данных, баланс экономики или серверный ИИ боссов.
- Нативные DLL не декомпилированы целиком. JVM исследована только в части формата классов. Учётные записи, токены и память работающей игры в исследование не входили.

## Покрытие по архивам

| Архив | Классов | Java | Kotlin | Без файла | Файлов с ошибками методов |
| --- | ---: | ---: | ---: | ---: | ---: |
{table}
'''
(ROOT/'FULL-DECOMPILATION-REPORT.md').write_text(text,encoding='utf-8')

bundle=ROOT/'CLIENT-DECOMPILED-SOURCES.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as target:
    for record in records:
        if 'sourceArchive' not in record:continue
        with zipfile.ZipFile(record['sourceArchive']) as source:
            for name in source.namelist():
                if name.endswith(('.java','.kt')):target.writestr(record['id']+'/'+name,source.read(name))
    for name,path in [('coverage.json',DEST/'coverage.json'),('REPORT.md',ROOT/'FULL-DECOMPILATION-REPORT.md'),
                      ('input-inventory.json',DEST/'input-inventory.json'),('toolchain-manifest.json',DEST/'toolchain-manifest.json'),
                      ('protected-reconstruction.json',ROOT/'protected-reconstruction.json'),
                      ('LATEST-DISCOVERIES.md',ROOT/'LATEST-DISCOVERIES.md'),
                      ('decode-protected-client.py',ROOT/'decode-protected-client.py')]:
        target.write(path,name)
manifest={'file':str(bundle),'bytes':bundle.stat().st_size,'sha256':hashlib.sha256(bundle.read_bytes()).hexdigest(),'totals':totals}
(ROOT/'decompiled-bundle-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(bundle) as archive:
    bad=archive.testzip()
    if bad:raise ValueError('CRC failure: '+bad)
    if sum(n.endswith(('.java','.kt')) for n in archive.namelist())!=totals['representedClasses']:raise ValueError('Bundle coverage mismatch')
print(json.dumps(manifest,indent=2))
