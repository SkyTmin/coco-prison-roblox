"""Preserve the new 34-frame ancient case/book attachment batch."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
TEMP=Path('C:/Users/user/AppData/Local/Temp')
IDS='''f11804a3-840a-415a-8e2c-94b60e53e447
4b9688ee-6c5f-4277-9099-33bc646daed0
d0b7ddce-ab18-497b-8d68-592c1d5c7c4f
709befb7-4479-4cfe-956c-748b947dc436
8899245f-3558-4d05-b201-88c80626c3b9
1b990311-0a41-4446-bd3f-bb1ba8822a41
55aec94f-736a-4694-ab5d-9968fb85d6f6
9cdfe1bb-7420-4d12-9e13-5912920d9a2b
e36e826d-b457-497a-9941-2eca782d7f6f
950ffa9b-9234-4a1e-9585-730d26359b46
3168c576-c657-4e70-9e15-6ac984fb2cfe
8a1041e2-1c6b-438a-b85d-45613b487d18
216a91a9-d4f2-43f1-9abd-5d19fb3ef562
af41fe33-4aa4-4665-8a26-bc5f70c62e14
b7ef8152-1b9c-44bf-8746-6e06cefded75
df31462f-22a9-479b-8091-0e71036039e7
97add7d6-19c2-4104-8351-5ef15845bdef
da21e9ea-8a18-47b4-9fda-a9584504577e
df83634a-712d-4d1a-b203-a47d5b6e7b91
7e7f5e58-d292-4f2e-847d-3899fc7ac631
e5d67dd0-d598-4b6b-b6a0-442fb0f64e5c
847b5d16-d596-43ea-8be3-645c605fae01
354c0fa4-f9f3-460d-8d43-3de70f9a94b2
4aabce64-c0fa-463a-a275-b2c6b684fe18
d52914e0-2d16-4e79-9ce9-80216eff77a5
6c24f4d8-4495-4d7c-86d0-e38dee1a66d1
3340aeb5-75c5-4776-b9a1-c0936e4b4a10
0e5cc1c1-73ed-4243-abd7-a206fb09fa3b
91547e5a-f05b-4687-8ffa-3bb06be829a5
14e16040-2c9d-48c1-8613-078d3b7cece8
e195033a-5dd5-4d57-a4a5-20d10f840099
668b484d-60ac-4f99-9658-43749b557881
1ccd8b20-ffb2-4745-b0b5-3ea30eeef31e
ec3b3dae-3153-4bd9-b036-4044434da52f'''.splitlines()
sources=[]
for n,suffix in enumerate(IDS,1):
    original=TEMP/f'codex-clipboard-{suffix}.png'
    box=(500,24,1910,1040) if n==1 else ((385,100,1537,1018) if n==2 else (620,315,1770,1040))
    target=OUT/'book-case-evidence'/f'{n:02d}.png'
    target.parent.mkdir(exist_ok=True)
    with Image.open(original) as im:
        dims=list(im.size)
        im.crop(box).save(target)
    sources.append(dict(id=f'book_case_{n}',attachmentNumber=n,originalFilename=original.name,
        originalSha256=hashlib.sha256(original.read_bytes()).hexdigest(), originalDimensions=dims,
        cropBox=list(box), evidencePath=target.as_posix(), evidenceSha256=hashlib.sha256(target.read_bytes()).hexdigest()))
data=dict(recordedDate='2026-10-20',sources=sources,
    userStatement='Books are obtained with keys, which can be bought through donations or exchanged for stars at the market.')
(OUT/'book-case-sources.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(screenshots=len(sources),uniqueOriginals=len({s['originalSha256'] for s in sources}))))
