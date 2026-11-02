"""Small closed cuboid volumes shared only by the king's original summons."""
import math
from mathutils import Vector
from blockmob import box
BONE=(177,171,150);IVORY=(204,196,172);SOCKET=(31,32,30);IRON=(52,66,67);EDGE=(82,95,94);CLOTH=(43,48,49);TEAL=(48,79,79);BRONZE=(124,111,83)
class Geometry:
 def __init__(self):self.parts=[]
 def add(self,n,j,c,size,col,rot=(0,0,0)):
  x,y,z=c;w,d,h=[v/2 for v in size];self.parts.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
 def mass(self,n,j,c,size,col,layers=3,slices=3):
  x,y,z=c;w,d,h=size
  for i in range(layers):
   u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
   for k in range(slices):
    v=(k+.5)/slices*2-1
    self.add(n+str(i)+'_'+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*math.sqrt(1-v*v),d*r/slices,h/layers),col)
 def beam(self,n,j,a,b,w,d,col):
  a,b=Vector(a),Vector(b);v=b-a
  self.add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x)for x in v.to_track_quat('Z','Y').to_euler()))
