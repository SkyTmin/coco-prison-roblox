import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = 'C:/Users/user/Documents/roblox-prison-research/client-audit';
const game = 'C:/Users/user/.cristalix/updates/Minigames';
const decoded = path.join(root, 'decoded');
const properties = JSON.parse(fs.readFileSync(path.join(decoded, 'ru_RU-prison.json'), 'utf8')).properties;
const classic = Object.fromEntries(Object.entries(properties).filter(([key]) => key.startsWith('prison.classic.')));
const clean = value => String(value ?? '').replace(/§[0-9a-fk-or]/gi, '').replace(/¨[0-9a-f]{6}/gi, '').replace(/[\uE000-\uF8FF]/g, '').replace(/\r/g, '').trim();
const prefix = 'prison.classic.';
const rules = [];
function rule(id, group, summary, references, limitation = '') {
  const keys = references.map(key => prefix + key);
  for (const key of keys) if (!(key in classic)) throw new Error('Missing evidence key: ' + key);
  rules.push({id, group, summary, status:'described_in_client_text', limitation, evidence:keys.map(key => ({key, text:clean(classic[key])}))});
}
rule('needs-shower','Потребности','Мыло позволяет удовлетворить потребность в душе вне стационарной зоны.', ['disease.anti.item.shower.lore']);
rule('needs-sleep','Потребности','Спальный мешок позволяет отдохнуть в выбранном месте.', ['disease.anti.item.sleep.lore']);
rule('needs-toilet','Потребности','Туалетная бумага позволяет удовлетворить туалетную потребность вне стационарной зоны.', ['disease.anti.item.toilet.lore']);
rule('needs-item-check','Потребности','Использование расходника без подходящей нужды отклоняется.', ['disease.anti.no_disease']);
rule('needs-vaccine','Потребности','Вакцина описана как отключение всех трёх бытовых потребностей.', ['disease.vaccine.lore','disease.vaccine.error_already_used'], 'Срок действия в границах сезонов и вайпов не установлен.');
rule('needs-training','Потребности','Тренер позволяет развивать сопротивляемость нуждам.', ['trainer.upgrade.needs.description','trainer.needs.upgrade'], 'Частота возникновения и величина изменения отсутствуют.');
rule('needs-gang','Потребности','Улучшение банды «Выносливость» снижает частоту нужд.', ['gang.upgrades.endurance.lore']);
rule('needs-enchantment','Потребности','Зачарование «Чистюля» делает душ, сон и туалет более редкими.', ['ancient_enchantment.list.neat.lore']);
rule('faction-entry','Фракции','Вступление во фракцию требует пятого уровня.', ['fraction.error.level']);
rule('faction-capacity','Фракции','Вступление в переполненную фракцию ограничивается.', ['fraction.error.overloaded']);
rule('faction-storage','Фракции','Открытие сундуков на чужой базе фракции запрещается.', ['fraction.error.foreign_base']);
rule('faction-capture','Фракции','Для захвата точки во дворах нужно копать блоки возле маяка.', ['fraction.warzone.gui.mine_block','fraction.warzone.capture_start']);
rule('faction-bonuses','Фракции','В интерфейсе точек предусмотрены направления: блоки, спешка, мобы и деньги.', ['fraction.warzone.point.blocks','fraction.warzone.point.haste','fraction.warzone.point.mobs','fraction.warzone.point.money'], 'Размер бонусов и правила удержания отсутствуют.');
rule('gang-quests','Банды','Задания охватывают добычу, мобов, боссов, PvP, лечение и продажу предметов.', ['gang.quests.description.block_break','gang.quests.description.mob_kill','gang.quests.description.boss_damage','gang.quests.description.boss_kill','gang.quests.description.player_damage','gang.quests.description.health_regain','gang.quests.description.item_sell']);
rule('gang-quest-reset','Банды','При обновлении категории заданий предыдущий прогресс сбрасывается.', ['gang.gui.quests.update.lore']);
rule('gang-blacksmith','Банды','Открытая кузница позволяет объединять книги одного типа для повышения уровня.', ['gang.upgrades.blacksmith_description']);
rule('gang-librarian','Банды','В библиотеке древние книги перерабатываются в пользу общей прогрессии банды.', ['gang.upgrades.librarian_description','gang.librarian.description'], 'Один текст обещает древние звёзды, другой описывает очки и пороговую награду. Точную последовательность нужно проверить в игре.');
rule('gang-storage','Банды','Прокачка сундуков увеличивает общий склад, прокачка казны увеличивает её вместимость.', ['gang.upgrades.chests_description','gang.upgrades.treasury_description']);
rule('gang-block-rewards','Банды','«Фарт» даёт шанс дополнительного предмета-блока, «Конверсия» — дополнительного блока в статистику.', ['gang.upgrades.additional_blocks.item.lore','gang.upgrades.additional_blocks.stats.lore'], 'Это разные виды награды; проценты не раскрыты.');
rule('gang-mob-stats','Банды','«Охотник» даёт шанс дополнительного убийства моба в статистике.', ['gang.upgrades.hunter.lore']);
rule('cell-entry-food','Камера','Текст арбуза указывает доступ к личной камере с восьмого уровня и необходимость кормить помощников.', ['cell.melon.lore'], 'Описание говорит, что голодный помощник сбегает; таймер и точный порядок штрафа не установлены.');
rule('cell-food-types','Камера','В интерфейсе еды помощников предусмотрены яблоки, плоть и арбузы.', ['cell.henchman.food.apple.non_emoji_text','cell.henchman.food.flesh.non_emoji_text','cell.henchman.food.melon.non_emoji_text']);
rule('cell-sieve','Камера','Для сита имеются подписи наград: пыль, ключ и древняя звезда.', ['cell.sieve.dust','cell.sieve.key','cell.sieve.star'], 'Это подписи интерфейса, не таблица шансов выпадения.');
rule('career-drill','Карьеры','Бур требует топливных бочек; для него предусмотрены отдельный экран и отсчёт оставшегося времени.', ['carrier.screen.fuel_hint','carrier.screen.time_left_label','barrel.lore']);
rule('career-entry-pass','Карьеры','Пропуска четырёх типов карьеров описывают минутное окно входа для банды.', ['carrier.pass.stone.lore','carrier.pass.diamond.lore','carrier.pass.synthetic.lore','carrier.pass.titan.lore'], 'Минутное окно входа нельзя считать длительностью добычи.');
rule('gang-mine-pass','Карьеры','Отдельный пропуск открывает шахту банды на десять минут.', ['gang.mine.pass.lore'], 'Этот пропуск и пропуск на карьер — разные предметы.');
rule('lootbox-kinds','Ключи и кейсы','Ключи обычного, древнего и именного кейса имеют разные назначения.', ['item.lootbox.default.lore','item.lootbox.ancient.lore','item.lootbox.rank.lore'], 'Источники выпадения всех ключей и их Minecraft-материалы здесь не заданы.');
rule('stars-exchange','Ключи и кейсы','Древняя звезда описана как награда босса или обычного кейса и обменивается на ключи на рынке.', ['item.nether.star.lore']);
rule('enchantment-failure','Зачарования','Наложение древнего зачарования вероятностное; при неудаче книга рвётся.', ['ancient_enchantment.lore','ancient_enchantment.not_applied'], 'Вместо процента стоит подстановка.');
rule('enchantment-powder','Зачарования','Древний порошок увеличивает шанс наложения книги.', ['ancient_enchantment.powder.lore','ancient_enchantment.powder.already_max_chance']);
rule('enchantment-remove','Зачарования','Развеиватель снимает зачарование без возврата использованной книги.', ['ancient_enchantment.disenchanter.lore']);
rule('enchantment-improved-key','Зачарования','Описание предпросмотра обещает книгу максимального уровня при открытии улучшенным древним ключом.', ['ancient_enchantment.lore_preview']);
rule('artifact-puzzle','Артефакты','Сбор всех девяти фрагментов картинки даёт ключ от кейса артефактов.', ['artifact.claim.error.incomplete','artifact.claim.success','artifact.screen.create_ready_tooltip']);
rule('artifact-duplicates','Артефакты','Накопленные дубликаты конвертируются в отсутствующий фрагмент.', ['artifact.screen.howto','artifact.fragment.notify.converted'], 'Порог дубликатов подставляется сервером через %d.');
rule('artifact-rarities','Артефакты','Предусмотрены обычные, редкие и эпические артефакты.', ['artifact.tier.common.title','artifact.tier.rare.title','artifact.tier.epic.title']);
rule('artifact-sources','Артефакты','Описание перечисляет шахты, боссов, мобов, ключи и другие занятия как источники фрагментов.', ['artifact.screen.howto'], 'Список не раскрывает вероятности и ограничения конкретного источника.');
rule('boss-last-hit','Боссы','Сообщение денежной награды обещает дополнительный бонус 20% за финальное убийство.', ['boss.reward.balance_notify_final'], 'Серверный расчёт распределения денег не получен.');
rule('boss-presence','Боссы','Сообщение отказа указывает, что для получения награды нужно быть на локации в момент смерти босса.', ['boss.reward.not_at_location']);
rule('boss-damage-ranking','Боссы','После победы предусмотрено сообщение с рейтингом нанесённого урона и последним ударом.', ['boss.killed_info']);
rule('boss-minion-shield','Боссы','Описание Древесного хранителя связывает его неуязвимость с живыми призванными существами.', ['boss.forest_guardian.description','boss.forest_guardian.notify.minions'], 'Описание боя нужно подтвердить наблюдением; это не код ИИ.');
rule('training-combat','Развитие','Тренер развивает силу удара и вероятность уклонения.', ['trainer.upgrade.strength.description','trainer.upgrade.agility.description']);
rule('tutorial-tasks','Обучение','В начальном сценарии есть задачи убить двух крыс, выкопать пятнадцать блоков и купить новую лопату.', ['guide.stage.second.3','guide.stage.third.3','guide.stage.fourth.requirements_not_met'], 'Наличие текста само по себе не доказывает доступность этапа в текущем сезоне.');

const enchantments = Object.entries(classic).filter(([key]) => /^prison\.classic\.ancient_enchantment\.list\.[^.]+\.display_name$/.test(key)).map(([key,value]) => {
  const id=key.split('.')[4], loreKey=prefix+'ancient_enchantment.list.'+id+'.lore';
  return {id,name:clean(value),description:clean(classic[loreKey]),nameKey:key,descriptionKey:loreKey in classic ? loreKey : null};
});
const bosses = Object.entries(classic).filter(([key]) => /^prison\.classic\.boss\.[^.]+\.name$/.test(key)).map(([key,value]) => {
  const id=key.split('.')[3], descriptionKey=prefix+'boss.'+id+'.description';
  return {id,name:clean(value),description:clean(classic[descriptionKey]),nameKey:key,descriptionKey:descriptionKey in classic ? descriptionKey : null};
});
const evidence = {collectedOn:'2026-10-18',kind:'Client localization evidence, not server source',source:'decoded/ru_RU-prison.json',totalPrisonStrings:Object.keys(properties).length,classicStrings:Object.keys(classic).length,rules,enchantments,bosses};
const writeJson=(name,value)=>fs.writeFileSync(path.join(root,name),JSON.stringify(value,null,2)+'\n');
writeJson('classic-mechanics-evidence.json',evidence);
writeJson('decoded/ru_RU-classic.json',{properties:classic});
writeJson('decoded/classic-enchantments.json',enchantments);
writeJson('decoded/classic-bosses.json',bosses);

const inspection=JSON.parse(fs.readFileSync(path.join(decoded,'inspection.json'),'utf8'));
const snapshots=[];
for(const item of inspection.filter(x=>x.relative && !x.missing)){
  const source=path.join(game,item.relative);
  const destination=path.join(root,'snapshot',item.relative);
  fs.mkdirSync(path.dirname(destination),{recursive:true});
  fs.copyFileSync(source,destination);
  const bytes=fs.readFileSync(destination);
  snapshots.push({source:source.replaceAll('\\','/'),copy:path.relative(root,destination).replaceAll('\\','/'),bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
}
const audit=JSON.parse(fs.readFileSync(path.join(decoded,'class-constant-audit.json'),'utf8'));
const addonIndex=JSON.parse(fs.readFileSync(path.join(decoded,'addons-index.json'),'utf8'));
writeJson('client-snapshot-manifest.json',{collectedOn:'2026-10-18',gameRoot:game,scope:'Cached public addon files and Prison translations only; no account, launcher, session, chat or player files copied.',files:snapshots,addons:addonIndex.addons.map(({name,displayName,version,hash})=>({name,displayName,version,hash})),scan:audit.map(({archive,entries,classes,hits,errors})=>({archive,entries,classes,matchingClasses:hits.length,parseErrors:errors.length})),limits:'Name and JVM constant-pool scan does not resolve obfuscated strings or prove absence of hidden functionality.'});

const lines=[
  '# Prison Classic: что удалось получить из установленного клиента',
  '',
  'Проверено 18 октября 2026 года. Пользователь подтвердил, что уже находится внутри мира Prison Classic.',
  '',
  '**Найдены реальные клиентские файлы и подробные описания механик. Серверный исходник или серверный plugin JAR из установки не получен.**',
  '',
  '## Полученные материалы',
  '',
  '- Папка игры: C:/Users/user/.cristalix/updates/Minigames.',
  '- Распакованы стандартные Zstandard-контейнеры дополнений и переводов. В индексах CXOD найден встроенный JSON.',
  '- Общий русский пакет Prison содержит '+Object.keys(properties).length+' строк. Из них '+Object.keys(classic).length+' относятся к префиксу prison.classic.; строки OldSchool выделены отдельно и в приведённые правила не смешаны.',
  '- [Русские тексты Classic](decoded/ru_RU-classic.json).',
  '- [Доказательства для '+rules.length+' правил с исходными ключами](classic-mechanics-evidence.json).',
  '- [Зачарования: '+enchantments.length+' названий](decoded/classic-enchantments.json).',
  '- [Боссы: '+bosses.length+' названий](decoded/classic-bosses.json).',
  '- [Копии выбранных файлов и SHA-256](client-snapshot-manifest.json).',
  '',
  'Количество строк не равно количеству механик. В переводах есть реплики, подписи, ошибки, описания и возможные неиспользуемые элементы.',
  '',
  '## Что описано в текстах Classic',
  '',
  'Каждый пункт ниже имеет статус «описано в клиентской локализации». Исполнение на сервере отдельно не проверено. Полные ключи и исходные строки находятся в JSON доказательств.',
  ''
];
for(const group of [...new Set(rules.map(r=>r.group))]){
  lines.push('### '+group,'');
  for(const r of rules.filter(r=>r.group===group)) lines.push('- **'+r.id+'** — '+r.summary+(r.limitation?' Ограничение: '+r.limitation:''));
  lines.push('');
}
lines.push('## Описания древних зачарований','','Показаны тексты из файлов, очищенные от кодов цвета. Отсутствующее описание не дополнялось догадками.','','| Название | Эффект по тексту |','| --- | --- |');
for(const item of enchantments) lines.push('| '+item.name.replaceAll('|','/')+' | '+(item.description || 'Описание отсутствует').replaceAll('\n',' ').replaceAll('|','/')+' |');
lines.push('','## Имена боссов','','В локализации перечислены: '+bosses.map(b=>b.name).join(', ')+'.','','Наличие имени или описания не означает, что босс доступен игроку прямо сейчас. В пакете одновременно могут оставаться старые записи и материалы будущих обновлений. Точные тайминги, здоровье, урон и таблицы наград отсутствуют.','','## Какие исполняемые дополнения обнаружены','','| Архив | Классов | Назначение, установленное по метаданным |','| --- | --- |');
for(const [short,label] of [['25a8d380e3ff','Socials 2.2.2 — социальный интерфейс'],['b8ab8e19b366','Gama 1.9.1 — общий клиентский мод; содержит также подписи иконок'],['d2cae0873b9f','Wada 4.18.6 — общий клиентский мод']]){
  const record=audit.find(a=>a.archive.includes(short));
  lines.push('| addon-'+short+'.zip | '+record.classes+' | '+label+' |');
}
lines.push('','Архивы прочитаны как данные. Просмотрены имена записей, mod.properties и константы классов. В Gama нашёлся перечень иконок с несколькими вариантами туалетной бумаги; это не реализация потребностей. assets-addon.jar содержит ресурсы, а minecraft.jar — базовый клиент.','','В списке постоянных кэшированных дополнений нет отдельной записи Prison. Папки resourcepacks и server-resource-packs пусты на момент просмотра. Это ограничение снимка диска: временно загруженный или находящийся только в памяти код таким способом не исследован. Поиск имён и констант не раскрывает все возможности обфусцированного кода.','','## Что осталось неизвестным','','- Реальные интервалы нужд и конкретные дебаффы.','- Шансы ключей, фрагментов, зачарований и срабатываний.','- Подставляемые параметры %s, %d, %a: цены, уровни, требования и коэффициенты.','- Серверный ИИ боссов, проверки действий, расчёт наград и сохранения.','- Какие из найденных текстов используются именно в текущем сезоне.','','Некоторые строки показывают разные стадии системы: например, библиотекарь описан и как переработка книг в звёзды, и как накопление очков до награды. Эти различия сохранены, а не превращены в придуманные правила.','','## Применение к нашей игре','','Эти материалы дают существенно более точную основу для каталога механик: потребности имеют несколько способов смягчения, предметная награда отделена от статистики, артефакты собираются из фрагментов, а фракционные точки требуют действия в опасной зоне. Собственные параметры Roblox нужно явно задавать и проверять в игре.','','Клиент и его настройки не менялись. Скачанный игровой байткод не запускался этим исследованием; чтение архивов и констант выполнялось отдельными собственными скриптами. Снимок содержит только выбранные дополнения и локализацию, без аккаунтов и переписки.','');
fs.writeFileSync(path.join(root,'CLASSIC-CLIENT-FINDINGS.md'),lines.join('\n'));
console.log(JSON.stringify({prisonStrings:Object.keys(properties).length,classicStrings:Object.keys(classic).length,rules:rules.length,enchantments:enchantments.length,bosses:bosses.length,snapshotFiles:snapshots.length,report:path.join(root,'CLASSIC-CLIENT-FINDINGS.md')},null,2));
