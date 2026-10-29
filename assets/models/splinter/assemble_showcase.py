"""Compose only Blender renders (never the AI reference). Requires Pillow."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).parent
def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",size)

names=[("idle","СПЛИНТЕР · модель Blender"),("melee","Удар · 1,0 с"),
       ("potion","Склянка · 1,55 с"),("shoot","Выстрел · 2,25 с"),
       ("summon","Призыв пауков · 4,0 с"),("swoop","Наскок · 1,1 с")]
sheet=Image.new("RGB",(1500,1120),(24,29,28))
d=ImageDraw.Draw(sheet)
d.text((36,18),"СПЛИНТЕР / ПОДВАЛ",font=font(30),fill=(234,226,205))
d.text((36,61),"Оригинальная модель по концепту · реальные рендеры Blender · 316 деталей / 23 сустава",font=font(17),fill=(165,176,165))
for i,(clip,label) in enumerate(names):
    x=24+(i%3)*492
    y=109+(i//3)*494
    im=Image.open(HERE/f"preview-{clip}.png").convert("RGB")
    # Fit full frame: never crop limbs or tail from animation poses.
    im=im.resize((476,318),Image.Resampling.LANCZOS)
    sheet.paste(im,(x,y+60))
    d.text((x+8,y+16),label,font=font(23),fill=(235,230,212))
    if i==0:
        d.text((x+8,y+400),"Матовая шерсть · подвижные челюсть и хвост",font=font(17),fill=(165,176,165))
d.text((36,1080),"Studio не запускалась. Имена и длительности приёмов — по разбору вики; игровой баланс требует проверки.",font=font(18),fill=(165,176,165))
sheet.save(HERE/"splinter-showcase.png")

manifest_path=HERE/"render-frames"/"manifest.json"
if manifest_path.exists():
    frames=[]
    for row in json.loads(manifest_path.read_text(encoding="utf-8")):
        im=Image.open(row["file"]).convert("RGB")
        draw=ImageDraw.Draw(im)
        draw.rectangle((0,0,640,44),fill=(24,29,28))
        draw.text((16,9),f'{row["title"]}  /  {row["seconds"]:.1f} из {row["duration"]} с',font=font(18),fill=(234,226,205))
        frames.append(im.quantize(colors=128))
    frames[0].save(HERE/"splinter-motion.gif",save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False)
    print("Saved motion and showcase",len(frames),"frames")
