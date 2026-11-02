"""Original stepped Spider Queen, measured from our four-view concept; headless only."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from spider_motion import make_actions
NAME='spider_queen';HERE=os.path.dirname(os.path.abspath(__file__))
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
TILE_STUDS=1.65;GAME_LIFT={'saturate':1,'gain':1.1}
DARK=(43,39,34);SHELL=(63,56,47);RIDGE=(78,68,53);BAND=(119,99,66);BANDD=(92,78,54)
IVORY=(177,165,139);FANGTIP=(134,126,110);AMBER=(150,86,27)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,3.2)),('abdomen','body',(0,-1.4,3.5)),
 ('head','body',(0,1.7,3.05))]
LEG_POINTS=[((1.3,1.5,3.0),(3.55,3.5,4.2),(5.7,5,.12)),
 ((1.65,.7,3.05),(4.5,1.75,4.4),(6.9,2,.12)),
 ((1.65,-.15,3.1),(4.7,-1.5,4.2),(7.15,-2.1,.12)),
 ((1.35,-.95,3.25),(3.95,-3.5,4.4),(5.9,-5.4,.12))]
for side,s in [('L',1),('R',-1)]:
 for i,(hip,knee,foot) in enumerate(LEG_POINTS):
  n=side+str(i);JOINTS += [('leg'+n,'body',(s*hip[0],*hip[1:])),('shin'+n,'leg'+n,(s*knee[0],*knee[1:])),('foot'+n,'shin'+n,(s*foot[0],*foot[1:]))]
 JOINTS += [('jaw'+side,'head',(s*.53,2.65,2.64)),('fang'+side,'jaw'+side,(s*.62,3.08,2.37)),
  ('palp'+side,'head',(s*1.02,2.28,2.7)),('palpTip'+side,'palp'+side,(s*1.48,3.0,2.2)),
  ('spinner'+side,'abdomen',(s*.35,-4.85,2.9))]
PARTS=[]
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler()))
def shell(n,j,c,size,step,pattern=False):
 # Solid quantized columns make a rounded back/underside, with a separate patterned upper cap.
 x,y,z=c;w,d,h=size;nx=math.ceil(w/step);ny=math.ceil(d/step)
 for a in range(nx):
  u=(a+.5)/nx*2-1
  for b in range(ny):
   v=(b+.5)/ny*2-1;rest=1-u*u-v*v
   if rest<=.025:continue
   r=math.sqrt(rest);low=z-math.floor(h/2*r/step)*step;high=z+math.floor(h/2*r/step)*step
   if high-low<step:continue
   cap=BANDD if pattern and any(abs(v-(q+.58*abs(u)))<.11 for q in [-.7,-.08,.53]) else (RIDGE if (a+b)%5==0 else SHELL)
   center=(x+u*w/2,y+v*d/2,(low+high-step)/2)
   add(n+str(a)+'_'+str(b),j,center,(w/nx,d/ny,high-low-step),SHELL)
   add(n+'Cap'+str(a)+'_'+str(b),j,(center[0],center[1],high-step/2),(w/nx,d/ny,step),cap)
shell('Abdomen','abdomen',(0,-2.85,3.72),(4.35,5.1,3.9),.37,True)
shell('Carapace','body',(0,.28,3.2),(3.6,3.65,2.65),.32,True)
shell('Head','head',(0,2.22,2.94),(2.75,2.15,2.05),.29,True)
# Eight inset, matte eyes: highlights are paint, never emission.
for i,(x,z,size) in enumerate([(-.38,3.43,.32),(.38,3.43,.32),(-.82,3.55,.22),(.82,3.55,.22),
 (-.48,3.02,.29),(.48,3.02,.29),(-1.02,3.17,.18),(1.02,3.17,.18)]):
 y=3.13-.14*abs(x)
 add('EyeSocket'+str(i),'head',(x,y,z),(size*1.5,.19,size*1.5),DARK)
 add('Eye'+str(i),'head',(x,y+.12,z),(size,.17,size),AMBER)
 add('EyePaint'+str(i),'head',(x-.025,y+.21,z+.035),(size*.28,.025,size*.26),IVORY)
for side,s in [('L',1),('R',-1)]:
 for i,(hip,knee,foot) in enumerate(LEG_POINTS):
  n=side+str(i);a,b,c=[Vector((s*p[0],*p[1:])) for p in [hip,knee,foot]]
  for k in range(4):
   beam('Femur'+n+str(k),'leg'+n,a.lerp(b,k/4),a.lerp(b,(k+1)/4),.72-k*.065,.7-k*.055,RIDGE if k==0 else SHELL)
  beam('FemurSeam'+n,'leg'+n,a+Vector((0,0,.3)),b+Vector((0,0,.22)),.16,.13,DARK)
  for k in range(5):
   u=k/5;v=(k+1)/5*.94
   beam('Tibia'+n+str(k),'shin'+n,b.lerp(c,u*.94),b.lerp(c,v),.62-k*.095,.59-k*.09,SHELL if k!=3 else BANDD)
  # Raised knuckle plates and a narrower distal ring.
  for k in range(3):
   p=a.lerp(b,.83+k*.06)
   beam('KneeRing'+n+str(k),'leg'+n,p,a.lerp(b,.89+k*.06),.77,.74,BAND if k==1 else BANDD)
  beam('AnkleRing'+n,'shin'+n,b.lerp(c,.73),b.lerp(c,.8),.36,.35,BAND)
  add('Foot'+n,'foot'+n,(c.x,c.y,c.z+.015),(.22,.3,.27),DARK)
  add('Claw'+n,'foot'+n,(c.x+s*.07,c.y+.06,.08),(.19,.2,.16),SHELL)
  for k in range(2):
   p=a.lerp(b,.35+k*.36);beam('LegBristle'+n+str(k),'leg'+n,p,p+Vector((s*.1,0,.28)),.1,.1,DARK)
 # Pedipalps are independent from fangs and legs.
 beam('PalpBase'+side,'palp'+side,(s*1.02,2.28,2.7),(s*1.48,3,2.2),.43,.41,SHELL)
 beam('PalpBand'+side,'palpTip'+side,(s*1.48,3,2.2),(s*1.5,3.12,2.0),.47,.45,BANDD)
 beam('PalpTip'+side,'palpTip'+side,(s*1.5,3.12,2.0),(s*1.4,3.45,1.45),.26,.26,DARK)
 shell('Jaw'+side,'jaw'+side,(s*.55,2.84,2.55),(.67,.85,.75),.23)
 points=[(s*.62,3.08,2.37),(s*.72,3.28,2.13),(s*.73,3.43,1.85),(s*.67,3.5,1.59),(s*.51,3.49,1.38)]
 for k in range(4):beam('Fang'+side+str(k),'fang'+side,points[k],points[k+1],.34-k*.067,.35-k*.069,IVORY if k<3 else FANGTIP)
 beam('SpinnerBase'+side,'spinner'+side,(s*.35,-4.85,2.9),(s*.43,-5.35,2.55),.42,.4,BANDD)
 beam('SpinnerTip'+side,'spinner'+side,(s*.43,-5.35,2.55),(s*.43,-5.67,2.38),.25,.23,DARK)
# Sparse raised silhouette bristles follow the abdomen rather than forming a glowing halo.
for i in range(15):
 y=-4.6+i*.27;v=(y+2.85)/2.55;z=3.72+1.95*math.sqrt(max(0,1-v*v))
 beam('Crest'+str(i),'abdomen',(0,y,z-.15),(0,y-.08,z+.25),.13,.14,DARK)
 for s in [-1,1]:
  x=s*1.7*math.sqrt(max(0,1-v*v));z2=3.72+.55
  beam('Bristle'+str(i)+str(s),'abdomen',(x,y,z2),(x+s*.22,y-.06,z2+.24),.12,.12,DARK)
EXTRA_JSON={'walkSpeed':4.166667,'runSpeed':5.555556}
CLIP_IMPACTS={'bite':.5,'bite_2':.53,'fangattack':.83,'webattack':1.05,'broodcall':1.65}
CLIP_FILES={'locomotion':['idle','hurt','jump'],'walk':['walk'],'run':['run'],'combat':['bite','bite_2','fangattack'],
 'silk':['webattack','broodcall'],'lifecycle':['spawn','death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('fangattack',24.9),('webattack',31.5),('broodcall',49.5),('death',185)]
PREVIEW_CAMERA=((15,22,15),(0,0,2),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,2.8),17),'side':((0,-1,0),(0,0,1),(0,0,2.8),17),
 'back':((1,0,0),(0,0,1),(0,0,2.8),17),'top':((1,0,0),(0,1,0),(0,0,0),18.5)}
if __name__=='__main__':run(globals())
