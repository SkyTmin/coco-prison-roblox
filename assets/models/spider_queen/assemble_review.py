"""Assemble raw exported-track renders and reference comparison, no geometry edits."""
import json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
P=Path(__file__).parent
font=lambda s:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',s)
rows=json.loads((P/'render-frames-huntsman/manifest.json').read_text())
f=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r','16','-i','-','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(P/'huntsman-motion.mp4')],stdin=subprocess.PIPE)
sheet=Image.new('RGB',(1280,960),(25,32,29))
for r in rows:
 im=Image.open(r['file']).convert('RGB');d=ImageDraw.Draw(im);d.rectangle((0,0,640,42),fill=(25,32,29));d.text((14,8),r['clip']+' '+format(r['seconds'],'.2f')+' s',font=font(20),fill='white');f.stdin.write(im.tobytes())
f.stdin.close();assert f.wait()==0
for i,(name,t) in enumerate([('idle',1),('walk',.25),('bite',.3),('death',1.95)]):
 r=min([r for r in rows if r['clip']==name],key=lambda r:abs(r['seconds']-t));im=Image.open(r['file']).convert('RGB');d=ImageDraw.Draw(im);d.rectangle((0,0,640,42),fill=(25,32,29));d.text((14,8),name,font=font(20),fill='white');sheet.paste(im,(i%2*640,i//2*480))
sheet.save(P/'huntsman-showcase.png')
ref=Image.open(P/'spider_queen-reference.png');w,h=ref.size
sheet=Image.new('RGB',(1536,1666),(25,32,29));d=ImageDraw.Draw(sheet);d.text((20,10),'REFERENCE / ORIGINAL BLENDER MODEL',font=font(24),fill='white')
for i,(view,box) in enumerate([('side',(0,0,w//2,410)),('front',(w//2,0,w,410)),('top',(0,415,w//2,h))]):
 sheet.paste(ImageOps.pad(ref.crop(box),(768,512),color=(190,190,190)),(0,60+i*532));sheet.paste(Image.open(P/('compare-'+view+'.png')).resize((768,512)),(768,60+i*532))
sheet.save(P/'reference-comparison.png')
