"""Preserve public primary pages and parse the mode's public Telegram archive.

Only ordinary public GET requests are made; no account or game actions.
"""
from pathlib import Path
from html.parser import HTMLParser
from urllib.request import Request, urlopen
import datetime
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
OUT = Path(__file__).parent / 'content-analysis' / 'public-gap-sources'
OUT.mkdir(parents=True, exist_ok=True)

class Node:
    def __init__(self, tag='', attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []
    def has(self, cls):
        return cls in self.attrs.get('class', '').split()
    def nodes(self):
        yield self
        for child in self.children:
            if isinstance(child, Node):
                yield from child.nodes()
    def text(self):
        if self.tag in ['script', 'style']:
            return ''
        return ''.join(c.text() if isinstance(c, Node) else c for c in self.children)

class Parser(HTMLParser):
    VOID = {'area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr'}
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node(); self.stack = [self.root]
    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs); self.stack[-1].children.append(node)
        if tag == 'br':
            node.children.append('\n')
        if tag not in self.VOID:
            self.stack.append(node)
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID:
            self.handle_endtag(tag)
    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]; break
    def handle_data(self, text):
        self.stack[-1].children.append(text)

def fetch(url, name):
    req = Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urlopen(req, timeout=25) as response:
        data = response.read(5_000_001)
        assert len(data) <= 5_000_000
        status = response.status
    path = OUT / name
    path.write_bytes(data)
    parser = Parser(); parser.feed(data.decode('utf-8'))
    return parser.root, dict(url=url, retrievedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        status=status, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), localPath=path.as_posix())

pages, posts, seen = [], [], set()
url = 'https://t.me/s/prison_classic'
for page in range(1, 6):
    root, metadata = fetch(url, f'telegram-page-{page:02d}.html')
    pages.append(metadata)
    ids = []
    for node in root.nodes():
        ident = node.attrs.get('data-post', '')
        if not ident.startswith('prison_classic/'):
            continue
        number = int(ident.split('/')[-1]); ids.append(number)
        if ident in seen:
            continue
        seen.add(ident)
        contents = next((n for n in node.nodes() if n.has('tgme_widget_message_text')), None)
        times = [n.attrs.get('datetime') for n in node.nodes() if n.tag == 'time']
        links = sorted({n.attrs['href'] for n in (contents.nodes() if contents else []) if n.tag == 'a' and 'href' in n.attrs})
        posts.append(dict(id=ident, url='https://t.me/' + ident, date=times[0] if times else None,
            text=contents.text().strip() if contents else '', links=links, sourcePage=metadata['localPath'], sourceSha256=metadata['sha256']))
    if not ids or min(ids) <= 1:
        break
    next_url = 'https://t.me/s/prison_classic?before=' + str(min(ids))
    if next_url == url:
        break
    url = next_url

root, tag_metadata = fetch('https://forum.cristalix.gg/tags/prison-classic/', 'forum-classic-tag.html')
pages.append(tag_metadata)
threads = []
for n in root.nodes():
    href = n.attrs.get('href','')
    if n.tag == 'a' and '/threads/' in href and n.text().strip():
        threads.append(dict(title=n.text().strip(),url='https://forum.cristalix.gg'+href if href.startswith('/') else href))
threads = list({(r['title'],r['url']):r for r in threads}.values())
data = dict(recordedDate='2026-10-20',scope='Public primary channel posts and official-forum tag; modes and dates require per-post classification.',
    pages=pages,posts=sorted(posts,key=lambda x:int(x['id'].split('/')[-1])),tagThreads=threads)
(OUT/'public-source-index.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(pages=len(pages),posts=len(posts),tagThreads=threads),ensure_ascii=False,indent=2))
for p in sorted(posts,key=lambda x:int(x['id'].split('/')[-1])):
    print(json.dumps(p,ensure_ascii=False))
