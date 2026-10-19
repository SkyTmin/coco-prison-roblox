"""Preserve only relevant game regions from the next three user screenshot batches."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
TEMP=Path('C:/Users/user/AppData/Local/Temp')
GROUPS={
'shop_mines':[
'ce9a9bdb-882f-4b26-bebe-ccaa4400d1d8','859b444e-77cc-4abd-b1a8-dc286604db6b',
'7c5d00f4-f03c-4685-801e-06e8e20313d8','178f07eb-e597-4c43-ad66-43f6695c41a5',
'93b3ee7d-4662-4cbc-b8bf-bd1474f1a64e','6924c400-6a0c-4d80-97c1-2713ac5aab21',
'dcf045d5-99a7-4443-83d9-28c95854e984','7ff6e4a2-3940-490d-af61-780fcbe1ca5a',
'f156c4b2-967c-4369-a6bd-178da16ace6c','307f1a47-0b90-4caf-ab71-e843d5b1cd2f',
'282efd21-a8db-40c5-bf08-6b46256e63a2','4d6d1c39-9fa5-4f59-9b6f-8bb219853673',
'5df1987a-707a-4a69-a16c-a5cf371e7277','23fea0f3-5bc6-4fd0-8bdf-a64000b1fdc2',
'2bbb4cee-e0d0-4fa1-aa0a-1010e4ddf759','734ab836-e162-4d87-a934-0edf62d52789',
'3f9d8e69-b1ec-4a8a-9b50-d0c989844b38','e7417b0a-fdb7-4fc2-a71b-f2cf42b02d26',
'ccfd03d2-573a-4f1a-904e-b287033f4fc0','873b309d-e9e0-4e17-95b8-4ee9ed06bda2',
'44542696-0b8c-4540-b5f0-0d6917d2436e','afe1fae7-3e0e-4d3c-ae29-ad7bb05e6fec',
'52668774-7bfb-4914-803d-10a902076cda','e41b4d04-4007-49d9-bbc8-1a545689047d',
'2702a351-6a3b-4a08-9916-99001a60c66d','f7a9d97d-50a5-41ac-a987-12695c9f723a',
'effe5550-f39b-49ce-8e1d-afac5370ca9f','4c75fa95-34c0-41aa-956a-b7d62c2d5b4c',
'771797c4-a4b2-4aa3-9f37-52295d4fe2e0','fd59083b-27a6-43a5-81f0-734cab7d74f8',
'4380239c-b4c9-4937-a25d-3b791b1286ea','d1ab00a8-bf8f-45f0-b32a-322e54b9e8f9',
'0b930418-aeb7-43b7-bbb3-5bf17b320035'],
'bosses':[
'5050c112-40db-45ce-aa1f-71a60d7f0bf1','437ef634-59fc-40fe-b00e-e374e836e201',
'd549605c-caa5-4c7b-a84c-126b93848701','438eb131-a6b0-467e-97da-bbf32c41f7df',
'85ec3134-d6d9-4780-a092-e7cb03e328d3','7c7d65dd-6f4b-4841-b460-ef1c3abf8a24',
'ae22b2b2-6f2f-4210-a46b-722363151732','6d57ccd1-6c5a-463d-a16a-62d601cbbd5d',
'6fdfb9c2-dd20-4ae6-bbc2-b44a4232350e','e1e01b12-23d0-4f4d-8c0b-3b0c1c6c16d8',
'82e2db46-e2c4-4cff-9b08-8f7862d97c15','a4805126-6374-4371-ba26-f78c4e2ea605',
'ade96dad-f911-411e-afeb-f4b1e94daed2','7b354a61-ae72-4fa7-85ca-9e5208812ca1',
'1a072c84-b6e2-435d-b67b-bb932be86ea7','1ea8a5bc-efaf-4865-81b9-4c805085b209',
'284da3be-ee0b-44ac-a190-82b41a03852e','7678d34a-b26e-403f-9e84-9fffbc2d6e0b'],
'map':[
'19d5e347-9715-41b0-a3b8-b30f05445058','fc1e471c-4513-469e-81b9-0a838fc3cbdb',
'de74803b-d286-4aba-97ff-b8ad1aa6c5fc','6a926f58-3df8-42a1-94f1-c28d1b6183eb',
'a96edfc4-ad30-4687-8c66-8433dca99ae7','dbd25917-5687-4e48-ac74-67e3c090e10d',
'd1db9106-8b5b-4fc8-8bd6-07c4e2194b4e','72780a7f-ae61-4c59-bba6-09247547335c',
'af9aa11e-6375-4a3a-8b20-0e2e856a4a1c','7bbca2d5-2fb8-4331-893a-82fb4308be3f'],
}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sources=[]
for group,files in GROUPS.items():
    target=OUT/'late-menu-evidence'/group
    target.mkdir(parents=True,exist_ok=True)
    for n,suffix in enumerate(files,1):
        if group=='shop_mines':
            box=(385,100,1537,1018) if n<=5 else ((550,282,1375,782) if n<=7 else (409,231,1514,832))
        elif group=='bosses':
            box=(409,231,1514,832) if n<=17 else (659,431,1260,632)
        else:box=(0,24,1590,930)
        original=TEMP/f'codex-clipboard-{suffix}.png'
        preserved=target/f'{n:02d}.png'
        with Image.open(original) as im:
            dims=list(im.size)
            assert box[2]<=dims[0] and box[3]<=dims[1]
            im.crop(box).save(preserved)
        sources.append(dict(id=f'{group}_{n}',batch=group,attachmentNumber=n,
            originalFilename=original.name,originalSha256=sha(original),
            originalDimensions=dims,cropBox=list(box),evidencePath=preserved.as_posix(),
            evidenceSha256=sha(preserved)))
assert len(sources)==61
result=dict(recordedDate='2026-10-19',sources=sources,groups={k:len(v) for k,v in GROUPS.items()})
(OUT/'late-menu-sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(screenshots=len(sources),groups=result['groups'],uniqueOriginals=len({s['originalSha256'] for s in sources}))))
