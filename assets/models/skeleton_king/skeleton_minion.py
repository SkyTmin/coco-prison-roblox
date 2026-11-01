"""Low-part-count original skeleton warrior with authored spawn and articulated death."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import skeleton_king as king
from blockmob import run
from splinter.motion import pose
NAME='skeleton_minion';HERE=os.path.dirname(os.path.abspath(__file__))
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
TILE_STUDS=1.1;GAME_LIFT=king.GAME_LIFT
king.PARTS=[];add=king.add;beam=king.beam
for i in range(7):add('Spine'+str(i),'body' if i<3 else 'chest',(0,-.4,4.4+i*.51),(.55,.6,.35),king.EDGE)
for side,s in [('L',1),('R',-1)]:
 for i in range(4):
  z=7.6-i*.6;rx=1.6 if i<3 else 1.2
  beam(f'RibFront{side}{i}','ribs'+side,(s*.15,.9,z),(s*rx,.2,z-.13),.24,.3,king.BONE)
  beam(f'RibBack{side}{i}','ribs'+side,(s*rx,.2,z-.13),(s*.1,-.7,z+.05),.24,.3,king.EDGE)
 add('Pelvis'+side,'body',(s*.8,0,4.0),(.9,.8,.6),king.BONE)
 beam('Arm'+side,'arm'+side,(s*2.15,-.1,8.05),(s*2.8,0,5.94),.45,.48,king.BONE)
 add('Shoulder'+side,'arm'+side,(s*2.15,-.1,8.0),(.9,.85,.8),king.BONE)
 add('Elbow'+side,'fore'+side,(s*2.8,0,5.94),(.65,.65,.5),king.EDGE)
 for k in [-1,1]:beam(f'Fore{side}{k}','fore'+side,(s*(2.8+k*.16),0,5.94),(s*(3.22+k*.17),.35,3.78),.24,.28,king.BONE)
 add('Palm'+side,'hand'+side,(s*3.22,.5,3.5),(.8,.45,.63),king.BONE)
 for i in range(3):
  beam(f'Finger{side}{i}',f'finger{side}{i}',(s*(3+i*.32),.65,3.25),(s*(3.07+i*.37),.83,2.58),.22,.27,king.BONE)
  beam(f'Tip{side}{i}',f'tip{side}{i}',(s*(3.07+i*.37),.83,2.58),(s*(3.07+i*.37),1.1,2.1),.19,.24,king.EDGE)
 beam('Thumb'+side,'thumb'+side,(s*2.87,.64,3.45),(s*2.6,.9,2.9),.24,.27,king.BONE)
 beam('Femur'+side,'leg'+side,(s*.9,0,4.1),(s*1.25,.2,2.24),.43,.46,king.BONE)
 add('Knee'+side,'shin'+side,(s*1.25,.2,2.24),(.7,.73,.6),king.EDGE)
 for k in [-1,1]:beam(f'Shin{side}{k}','shin'+side,(s*(1.25+k*.14),.2,2.24),(s*(1.4+k*.13),.05,.48),.23,.26,king.BONE)
 for i in [-1,0,1]:beam(f'Toe{side}{i}','foot'+side,(s*1.4+i*.28,.05,.31),(s*1.4+i*.43,1.4,.15),.25,.28,king.BONE)
add('Skull','head',(0,.63,9.38),(1.9,1.5,1.53),king.BONE)
for side,s in [('L',1),('R',-1)]:
 add('Eye'+side,'head',(s*.46,1.405,9.3),(.6,.06,.53),king.SOCKET)
 add('Brow'+side,'head',(s*.49,1.47,9.63),(.91,.22,.22),king.LIGHT,(0,-s*9,0))
 add('JawSide'+side,'jaw',(s*.74,1.13,8.47),(.25,.8,.24),king.BONE)
 for i in range(3):add(f'Tooth{side}{i}','head',(s*(.14+i*.22),1.43,8.62),(.15,.2,.27),king.LIGHT)
add('Jaw','jaw',(0,1.47,8.32),(1.4,.4,.24),king.BONE)
add('Nose','head',(0,1.41,8.96),(.23,.07,.32),king.SOCKET)
add('Cloth','clothFront',(0,.83,3.22),(1.25,.16,1.65),king.CLOTH)
S=.4
JOINTS=[(n,p,tuple(v*S for v in pos)) for n,p,pos in king.JOINTS]
PARTS=[(n,j,tuple(v*S for v in c),tuple(v*S for v in size),color,top,rot,flags) for n,j,c,size,color,top,rot,flags in king.PARTS]
CLIP_IMPACTS={'bite':.58/1.25};EXTRA_JSON={'walkSpeed':1.4*S*4/1.5038}
def actions():
 source=king.make_actions(king.JOINTS);out={}
 for name,original,duration in [('idle','idle',3.0075),('walk','walk',1.5038),('bite','atkrswipe',1),('hurt','hurt',.5),('death','death',2.5)]:
  keys,loop=source[original];length=keys[-1][0]
  out[name]=([(f/length*duration*30,{n:(rx,ry,rz,tuple(v*S for v in off) if off else None) for n,(rx,ry,rz,off) in p.items()}) for f,p in keys],loop)
 end=out['idle'][0][0][1]
 # Knees unfold while the rib cage, skull and hands emerge successively, no root teleport.
 keys=[]
 for f,drop,ch,head,arm in [(0,1.15,-37,-12,48),(20,.98,-31,-3,64),(43,.65,-22,8,44),(64,.26,-15,17,23),(80,.12,-10,15,8),(90,.1,-8,14,0)]:
  p=dict(end);p.update(pose(body=(0,0,0,(0,0,-drop)),chest=ch,head=head,armL=arm,armR=arm,
   legL=42*(drop/1.15),legR=42*(drop/1.15),shinL=-80*(drop/1.15),shinR=-80*(drop/1.15),footL=38*(drop/1.15),footR=38*(drop/1.15)))
  keys.append((f,p))
 keys[-1]=(90,dict(end));out['spawn']=(keys,False)
 return out
PREVIEWS=[];PREVIEW_CAMERA=((8,11,6),(0,0,2.0),47)
if __name__=='__main__':run(globals())
