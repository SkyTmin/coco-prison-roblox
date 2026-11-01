"""Compose actual exported-model renders into review artifacts (Pillow)."""
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
HERE=Path(__file__).parent
rows=json.loads((HERE/'render-frames'/'manifest.json').read_text(encoding='utf-8'))
font=lambda s:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',s)

def frame(row):
    im=Image.open(row['file']).convert('RGB'); d=ImageDraw.Draw(im)
    d.rectangle((0,0,im.width,44),fill=(25,32,29))
    d.text((15,10),f"{row['title']} · {row['seconds']:.2f} с",font=font(19),fill=(235,231,206))
    return im

for name,chosen in [('minotaur-motion',[r for r in rows if r['clip'] not in ['death','awakening']]),
                    ('minotaur-awakening',[r for r in rows if r['clip']=='awakening']),
                    ('minotaur-death',[r for r in rows if r['clip']=='death'])]:
    process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y',
        '-f','rawvideo','-pix_fmt','rgb24','-s','720x520','-r','20','-i','-',
        '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
        str(HERE/(name+'.mp4'))],stdin=subprocess.PIPE)
    for r in chosen: process.stdin.write(frame(r).tobytes())
    process.stdin.close()
    assert process.wait()==0,'ffmpeg encoding failed'
    if name=='minotaur-death':
        frames=[frame(r).resize((504,364),Image.Resampling.LANCZOS).quantize(colors=96) for r in chosen[::2]]
        frames[0].save(HERE/(name+'.gif'),save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False)
selected=[]
for clip,t in [('melee',.55),('double_attack',1.05),('throws_the_ground',2.05),('minotaur_rush',1.65),('awakening',7.3),('death',10.5)]:
    selected.append(min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t)))
sheet=Image.new('RGB',(1440,1640),(25,32,29)); d=ImageDraw.Draw(sheet)
d.text((30,18),'МИНОТАВР · BLENDER → ROBLOX',font=font(30),fill=(235,231,206))
d.text((30,62),'456 деталей · 34 сустава · 16 клипов · кадры экспортированной модели',font=font(20),fill=(176,190,176))
for i,r in enumerate(selected): sheet.paste(frame(r),(i%2*720,100+i//2*510))
sheet.save(HERE/'minotaur-showcase.png')
death=[r for r in rows if r['clip']=='death']
sheet=Image.new('RGB',(1440,1040),(25,32,29))
for i,t in enumerate([1.3,4.1,7.4,12.95]):
    sheet.paste(frame(min(death,key=lambda r:abs(r['seconds']-t))),(i%2*720,i//2*520))
sheet.save(HERE/'minotaur-death-poses.png')
print('Assembled showcase, death poses and motion GIFs')
