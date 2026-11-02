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

for name,chosen in [('forest-spirit-motion',[r for r in rows if r['clip'] not in ['death','spawn']]),

                    ('forest-spirit-death',[r for r in rows if r['clip']=='death'])]:
    process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y',
        '-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r','16','-i','-',
        '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',
        str(HERE/(name+'.mp4'))],stdin=subprocess.PIPE)
    for r in chosen: process.stdin.write(frame(r).tobytes())
    process.stdin.close()
    assert process.wait()==0,'ffmpeg encoding failed'
    if name=='forest-spirit-death':
        frames=[frame(r).resize((480,360),Image.Resampling.LANCZOS).quantize(colors=96) for r in chosen[::2]]
        frames[0].save(HERE/(name+'.gif'),save_all=True,append_images=frames[1:],duration=125,loop=0,optimize=False)
selected=[]
for clip,t in [('attack1',2.2),('attack2',2.5),('attack3',1.35),('attack4',2.5),('attack5',1.8),('attack6',5.3),('attack7',.93),('attack8',7.2),('spawn',2.05),('death',6.2)]:
    selected.append(min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t)))
sheet=Image.new('RGB',(1280,2500),(25,32,29)); d=ImageDraw.Draw(sheet)
d.text((25,14),'ЛЕСНОЙ ДУХ · BLENDER → ROBLOX',font=font(28),fill=(235,231,206))
d.text((25,56),'752 детали · 47 суставов · 17 клипов · экспортированные движения',font=font(20),fill=(176,190,176))
for i,r in enumerate(selected):sheet.paste(frame(r),(i%2*640,100+i//2*480))
sheet.save(HERE/'forest-spirit-showcase.png')
death=[r for r in rows if r['clip']=='death'];sheet=Image.new('RGB',(1280,960),(25,32,29))
for i,t in enumerate([.4,1.55,3.07,6.2]):sheet.paste(frame(min(death,key=lambda r:abs(r['seconds']-t))),(i%2*640,i//2*480))
sheet.save(HERE/'forest-spirit-death-poses.png')
# Stills from the actual exported clips.
for name,t in [('idle',1),('death',6.2),('attack1',2.2),('attack3',1.35),('attack6',5.3),('attack8',7.2),('walk',.4)]:
    row=min([r for r in rows if r['clip']==name],key=lambda r:abs(r['seconds']-t))
    Image.open(row['file']).save(HERE/('preview-'+name+'.png'))
print('Assembled videos, GIF and showcase')
