"""Compose actual exported-model renders into review artifacts (Pillow)."""
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
HERE=Path(__file__).parent
rows=json.loads((HERE/'render-frames-v3'/'manifest.json').read_text(encoding='utf-8'))
font=lambda s:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',s)

def frame(row):
    im=Image.open(row['file']).convert('RGB'); d=ImageDraw.Draw(im)
    d.rectangle((0,0,im.width,44),fill=(25,32,29))
    d.text((15,10),f"{row['title']} · {row['seconds']:.2f} с",font=font(19),fill=(235,231,206))
    return im

for name,chosen in [('basalt-motion',[r for r in rows if r['clip']!='death']),
                    ('basalt-death',[r for r in rows if r['clip']=='death'])]:
    if name=='basalt-motion':
        process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y',
            '-f','rawvideo','-pix_fmt','rgb24','-s','720x520','-r','20','-i','-',
            '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
            str(HERE/(name+'.mp4'))],stdin=subprocess.PIPE)
        for r in chosen: process.stdin.write(frame(r).tobytes())
        process.stdin.close()
        assert process.wait()==0,'ffmpeg encoding failed'
    else:
        frames=[frame(r).quantize(colors=128) for r in chosen]
        frames[0].save(HERE/(name+'.gif'),save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=False)
selected=[]
for clip,t in [('idle',0),('melee',.62),('sword_slash',.7),('sword_smash',1.9),('sword_spike',2.15),('death',3.3)]:
    selected.append(min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t)))
sheet=Image.new('RGB',(1440,1640),(25,32,29)); d=ImageDraw.Draw(sheet)
d.text((30,18),'БАЗАЛЬТОВЫЙ СТРАЖ · BLENDER → ROBLOX',font=font(30),fill=(235,231,206))
d.text((30,62),'422 детали · 24 сустава · 10 клипов · кадры экспортированной модели',font=font(20),fill=(176,190,176))
for i,r in enumerate(selected): sheet.paste(frame(r),(i%2*720,100+i//2*510))
sheet.save(HERE/'basalt-showcase.png')
death=[r for r in rows if r['clip']=='death']
sheet=Image.new('RGB',(1440,1040),(25,32,29))
for i,t in enumerate([.9,1.5,2.5,4]):
    sheet.paste(frame(min(death,key=lambda r:abs(r['seconds']-t))),(i%2*720,i//2*520))
sheet.save(HERE/'basalt-death-poses.png')
print('Assembled showcase, death poses and motion GIFs')
