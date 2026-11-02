"""Compose exported-curve renders; retains review videos, not raw frames in git."""
import json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).parent
font=lambda s:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',s)
def frame(row):
 im=Image.new('RGB',(640,480),(25,29,36));im.paste(Image.open(row['file']).convert('RGB').resize((581,436),Image.Resampling.LANCZOS),(29,44));d=ImageDraw.Draw(im)
 d.text((15,10),f"{row['clip']} · {row['seconds']:.2f} с",font=font(19),fill=(226,231,238));return im
def video(name,rows):
 process=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r','16','-i','-','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(HERE/(name+'.mp4'))],stdin=subprocess.PIPE)
 for r in rows:process.stdin.write(frame(r).tobytes())
 process.stdin.close();assert process.wait()==0
def read(folder):return json.loads((HERE/folder/'manifest.json').read_text(encoding='utf8'))
def choose(rows,clip,t):return min([r for r in rows if r['clip']==clip],key=lambda r:abs(r['seconds']-t))

def sheet(name,title,choices,rows,subtitle=''):
 out=Image.new('RGB',(1280,100+480*((len(choices)+1)//2)),(25,29,36));d=ImageDraw.Draw(out)
 d.text((25,14),title,font=font(27),fill=(226,231,238));d.text((25,55),subtitle,font=font(19),fill=(170,183,200))
 for i,(clip,t)in enumerate(choices):out.paste(frame(choose(rows,clip,t)),(i%2*640,100+i//2*480))
 out.save(HERE/name)

rows=sorted(read('render-frames'),key=lambda r:(r['clip'],r['seconds']))
video('ent-motion',[r for r in rows if r['clip']!='death'])
death=[r for r in rows if r['clip']=='death'];video('ent-death',death)
frames=[frame(r).resize((480,360),Image.Resampling.LANCZOS).quantize(colors=96)for r in death[::2]]
frames[0].save(HERE/'ent-death.gif',save_all=True,append_images=frames[1:],duration=125,loop=0,optimize=False)
sheet('ent-showcase.png','ГРУТ · ДУБОВЫЙ КОРОЛЬ',[('idle',1),('walk',.3),('rightpunch',.92),('leftpunch',.96),('stomp',1.35),('rise',1.5),('leafstorm',2.1),('death',4.4)],rows,'54 сустава · 12 клипов · Оригинальная модель · Studio: проверка вечером')
sheet('ent-death-poses.png','ГРУТ · ПОТЕРЯ ОПОРЫ И ПАДЕНИЕ',[('death',.65),('death',1.7),('death',2.4),('death',4.4)],rows)
for name in ['ent_minion','ent_branch','ent_leaves']:
 rr=sorted(read('render-frames-'+name),key=lambda r:(r['clip'],r['seconds']))
 video(name.replace('_','-')+'-motion',rr)
 for clip in sorted(set(r['clip']for r in rr)):
  t=max(r['duration']for r in rr if r['clip']==clip) if clip=='death' else .5
  Image.open(choose(rr,clip,t)['file']).save(HERE/(name+'-preview-'+clip+'.png'))
print('20 exported clips assembled')
