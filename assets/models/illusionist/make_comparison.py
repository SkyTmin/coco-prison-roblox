"""Review the original generated turnaround beside orthographic Blender renders."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
here=Path(__file__).parent;reference=Image.open(here/'illusionist-reference.png').convert('RGB')
sheet=Image.new('RGB',(2160,760),(30,29,32));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
for i,(name,index,label) in enumerate([('side',0,'ПРОФИЛЬ'),('front',1,'СПЕРЕДИ'),('back',2,'СЗАДИ')]):
 x=i*720
 draw.text((x+16,10),label+' · РЕФЕРЕНС / BLENDER',font=font,fill=(230,222,210))
 panel=reference.crop((round(index*reference.width/4),0,round((index+1)*reference.width/4),reference.height))
 panel.thumbnail((360,700));sheet.paste(panel,(x+(360-panel.width)//2,45+(700-panel.height)//2))
 render=Image.open(here/f'compare-{name}.png').convert('RGB').crop((240,0,528,512))
 render.thumbnail((360,700));render=render.resize((360,640),Image.Resampling.LANCZOS)
 sheet.paste(render,(x+360,75))
sheet.save(here/'compare-views.png')
