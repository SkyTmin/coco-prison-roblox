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

for name,chosen in [('piglin-king-motion',[r for r in rows if r['clip'] not in ['death','spawn']]),
                    
                    ('piglin-king-death',[r for r in rows if r['clip']=='death'])]:
    process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y',
        '-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r','16','-i','-',
        '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
        str(HERE/(name+'.mp4'))],stdin=subprocess.PIPE)
    for r in chosen: process.stdin.write(frame(r).tobytes())
    process.stdin.close()
    assert process.wait()==0,'ffmpeg encoding failed'
    if name=='piglin-king-death':
        frames=[frame(r).resize((480,360),Image.Resampling.LANCZOS).quantize(colors=96) for r in chosen[::2]]
        frames[0].save(HERE/(name+'.gif'),save_all=True,append_images=frames[1:],duration=125,loop=0,optimize=False)
selected=[]
for clip,t in [('verticalatk',.9),('spinslam',2.7),('upchuck',2.5),('bodyslam',2.5),('summoningchant',2.2),('death',4.8)]:
    selected.append(min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t)))
sheet=Image.new('RGB',(1280,1540),(25,32,29)); d=ImageDraw.Draw(sheet)
d.text((25,14),'КОРОЛЬ ПИГЛИНОВ · BLENDER → ROBLOX',font=font(28),fill=(235,231,206))
d.text((25,56),'708 деталей · 33 сустава · 16 клипов · экспортированные движения',font=font(20),fill=(176,190,176))
for i,r in enumerate(selected):sheet.paste(frame(r),(i%2*640,100+i//2*480))
sheet.save(HERE/'piglin-king-showcase.png')
death=[r for r in rows if r['clip']=='death'];sheet=Image.new('RGB',(1280,960),(25,32,29))
for i,t in enumerate([.6,1.6,2.8,4.9]):sheet.paste(frame(min(death,key=lambda r:abs(r['seconds']-t))),(i%2*640,i//2*480))
sheet.save(HERE/'piglin-king-death-poses.png')
# Restore king previews after the guard export used the common preview filenames.
for name,t in [('idle',1),('death',4.9)]:
    row=min([r for r in rows if r['clip']==name],key=lambda r:abs(r['seconds']-t))
    Image.open(row['file']).save(HERE/('preview-'+name+'.png'))
print('Assembled videos, GIF and showcase')
