"""Render real Blender motion, headlessly. Assemble with assemble_showcase.py afterwards."""
import json
import os
import sys
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import splinter
from blockmob import Mob

mob=Mob(vars(splinter))
joints,order=mob.scene_joints()
scene,cam=mob.setup_render(640,420)
scene.eevee.taa_render_samples=24
folder=os.path.join(splinter.HERE,"render-frames")
os.makedirs(folder,exist_ok=True)
clips=[("idle",1.0,"Ожидание"),("melee",1.0,"Удар"),("swoop",1.1,"Наскок"),
       ("potion",1.55,"Склянка"),("shoot",2.25,"Выстрел"),("summon",4.0,"Призыв"),("death",4.0,"Гибель")]
manifest=[]
for clip,duration,title in clips:
    camera=((20,19,12),(1.7,0,2.6),48) if clip=="death" else ((18,17,11),(0,-.4,4.2),42)
    mob.perspective(cam,camera)
    count=round(duration*10)
    for i in range(count+1):
        mob.pose(joints,order,clip,i/count*duration*30)
        path=os.path.join(folder,f"{len(manifest):04d}.png")
        scene.render.filepath=path
        bpy.ops.render.render(write_still=True)
        manifest.append({"file":path,"title":title,"seconds":round(i/count*duration,2),"duration":duration})
with open(os.path.join(folder,"manifest.json"),"w",encoding="utf-8") as f:
    json.dump(manifest,f,ensure_ascii=False)
print("SHOWCASE_FRAMES",len(manifest))
