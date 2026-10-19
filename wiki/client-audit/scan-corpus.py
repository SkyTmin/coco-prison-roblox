"""Repeatable whole-corpus text analysis, without treating string absence as proof."""
from pathlib import Path
import collections
import csv
import json
import re
import sqlite3

ROOT=Path(__file__).parent/'code-analysis'
db=sqlite3.connect(ROOT/'code-index.sqlite');db.row_factory=sqlite3.Row
patterns={
 'prison_specific':r'prison|prisoneer|тюрьм|чистюля|пластолом|стаpатель|фракци|потребност|туалет|toilet|hygiene|sleepbag|vaccine',
 'server_plugin_api':r'org[./]bukkit|net[./]minecraft[./]server|extends JavaPlugin|plugin\.yml|BukkitScheduler',
 'economy_named':r'(?i)\b(?:loot|dropchance|drop_chance|enchants?|faction|gang|boss|bosses|artifact|soap)\b|артефакт|зачарован|крыса|крысы|шахт',
 'network_ui':r'(?i)registerChannel|writeUtf8|readUtf8|w4:|w2:|registerServerMod|mod\.properties',
 'source_quality_warnings':r'\$VF: Unable|\$VF: Could|ObjectMethods\.bootstrap|java/lang/invoke',
}
compiled={k:re.compile(v,re.I) for k,v in patterns.items()}
hits={k:[] for k in patterns};module_counts=collections.defaultdict(collections.Counter)
with (ROOT/'classifications.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream);writer.writerow(['archive','source','lines','role','matched_groups','path'])
    for source in db.execute('SELECT * FROM sources ORDER BY id'):
        groups=[]
        for key,pattern in compiled.items():
            found=[{'line':n,'text':line.strip()[:450]} for n,line in enumerate(source['text'].splitlines(),1) if pattern.search(line)]
            if found:
                groups.append(key);module_counts[source['archive']][key]+=1
                hits[key].append({'archive':source['archive'],'entry':source['entry'],'path':source['path'],'hits':found})
        archive=source['archive']
        role='third_party_library'
        if archive=='minecraft':role='base_game_and_client_extensions_obfuscated'
        elif archive=='addon-wada':role='shared_ui_and_visual_modules'
        elif archive=='addon-gama':role='shared_global_menus_and_ui_runtime'
        elif archive=='addon-socials':role='social_ui_and_embedded_ui_runtime'
        writer.writerow([archive,source['entry'],source['lines'],role,';'.join(groups),source['path']])
(ROOT/'whole-corpus-hits.json').write_text(json.dumps(hits,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
summary={'groups':{key:{'files':len(value),'lines':sum(len(v['hits']) for v in value)} for key,value in hits.items()},
         'byArchive':dict(module_counts),'limitations':'Lexical matches and module roles, not a semantic proof of presence/absence of a mechanic.'}
(ROOT/'whole-corpus-scan.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2)[:6500])
