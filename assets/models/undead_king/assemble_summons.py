"""Deliverable videos and sheets from the summons' actual exported tracks."""
import json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).parent;font=lambda s:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',s)
sheet=Image.new('RGB',(1920,1480),(25,32,29));draw=ImageDraw.Draw(sheet)
draw.text((24,14),'ПРИЗЫВЫ КОРОЛЯ НЕЖИТИ · ЭКСПОРТ ROBLOX',font=font(27),fill=(235,231,206))
for row,(name,times) in enumerate([('undead_ghoul',[('idle',1),('bite',.25),('death',2)]),('undead_skull',[('idle',1),('bite',.75),('death',2)]),('undead_sword',[('attack',1),('attack',4),('attack',7)])]):
 rows=json.loads((HERE/('render-frames-'+name)/'manifest.json').read_text(encoding='utf8'))
 def frame(r):
  im=Image.open(r['file']).convert('RGB');d=ImageDraw.Draw(im);d.rectangle((0,0,640,40),fill=(25,32,29));d.text((12,9),f"{name} · {r['clip']} · {r['seconds']:.2f} с",font=font(18),fill=(235,231,206));return im
 process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r','16','-i','-','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(HERE/(name+'-motion.mp4'))],stdin=subprocess.PIPE)
 for r in rows:process.stdin.write(frame(r).tobytes())
 process.stdin.close();assert process.wait()==0
 for col,(clip,t) in enumerate(times):
  selected=min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t));sheet.paste(frame(selected),(col*640,40+row*480))
sheet.save(HERE/'summons-showcase.png')
reference=Image.open(HERE/'undead_king-reference.png').convert('RGB')
sheet=Image.new('RGB',(1280,1320),(25,32,29));d=ImageDraw.Draw(sheet)
for row,(view,box) in enumerate([('front',(640,0,1280,600)),('side',(0,0,640,600)),('back',(0,600,640,1200))]):
 for col,im in enumerate([reference.crop(box),Image.open(HERE/('compare-'+view+'.png')).convert('RGB')]):
  im.thumbnail((640,400));sheet.paste(im,(col*640+(640-im.width)//2,40+row*440))
 d.text((16,8+row*440),view+' · generated reference',font=font(20),fill=(235,231,206));d.text((656,8+row*440),'Original Blender model',font=font(20),fill=(235,231,206))
sheet.save(HERE/'reference-comparison.png')
print('Summons videos and reference comparison assembled')
