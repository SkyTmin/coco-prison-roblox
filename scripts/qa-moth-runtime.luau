--!nocheck
-- Disposable distant fixtures exercise actual installed server mechanics, never live rewards/profiles.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.MothAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local cfg
for _,c in Config.bosses.bosses do if c.id=="mole" then cfg=c.fight;assert(c.hp==1820) end end
assert(cfg and cfg.moth)
assert(not workspace:FindFirstChild("QAMothFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAMothFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAMothResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAMothResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
 local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
 number+=1;local o=Vector3.new(105000+number*500,30000,0)
 local g=Instance.new("Folder");g.Parent=folder
 part("Floor",o-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
 local m=Instance.new("Model");m.Parent=g
 local r=part("HumanoidRootPart",o+Vector3.new(0,4.5,0),Vector3.new(4,9,3),m)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=1820,1820,cfg.walkSpeed;h.Parent=m
 local spawn=part("Spawn",o-Vector3.new(0,.5,0),Vector3.one,g);spawn.CanCollide,spawn.CanQuery=false,false
 local target=Instance.new("Model");target.Parent=g
 local tr=part("HumanoidRootPart",o+Vector3.new(0,3,-12),Vector3.new(2,2,2),target)
 local th=Instance.new("Humanoid");th.RequiresNeck=false;th.Parent=target
 local fighter={player={Character=target},root=tr,humanoid=th}
 local state=Instance.new("Folder");state.Parent=g
 local boss={root=r,model=m,humanoid=h,spawn=spawn,state=state,fight=cfg,arenaRadius=60,busyUntil=0,nextAbilityAt=0}
 table.insert(active,boss)
 local hits,actions,snares={},{},{}
 local hooks={fighters=function()return {fighter}end,hurt=function(_,_,amount)table.insert(hits,amount);return true end,
 snare=function(_,level,seconds)table.insert(snares,{level,seconds})end,
 act=function(_,name)table.insert(actions,name);m:SetAttribute("Action",name)end,
 telegraph=function(size,cf)local p=part("Mark",cf.Position,size,g);p.CFrame=cf;p.CanCollide,p.CanQuery=false,false;return p end}
 return boss,tr,hooks,hits,actions,g,o,snares
end
local function check(name,ok)assert(ok,name);table.insert(checks,name)end
local function run(name,fn)
 -- Bound concurrent rig construction so a count assertion does not race unrelated fixture builds.
 while remaining>=6 do task.wait(.1)end
 remaining+=1;task.spawn(function()local ok,err=xpcall(fn,debug.traceback);if not ok then table.insert(errors,name..": "..tostring(err))end;remaining-=1 end)
end
local function effects(o,name)
 local n=0
 for _,f in workspace:GetChildren()do if f.Name=="MothEncounter"then
  for _,p in f:GetChildren()do if p:IsA("BasePart")and(p.Position-o).Magnitude<100 and(not name or p.Name==name)then n+=1 end end
 end end
 return n
end
for index,name in {"shadowlight","moonssight","meteorrain","midnight","startshoot"}do
 for _,mode in {"hit","wall","dodge","death","dynamicWall","clear"}do
  run(name..mode,function()
   local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-12)
   local function wall()part("Wall",o+Vector3.new(0,8,-5),Vector3.new(35,16,1),g)end
   if mode=="wall"then wall()end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="dodge"then tr.Position+=Vector3.new(35,0,0)end
   if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
   if mode=="clear"then task.wait(.1);API.Clear(b)end
   if mode=="dynamicWall"then task.wait(.3);wall()end
   task.wait(if index==5 then 5 else 3.3)
   check(name..mode.." hits="..#hits,if mode=="hit"then #hits==1 and hits[1]==cfg.moth[name].damage else #hits==0)
   if index==5 and mode=="hit"then
    check("flight shoots then lands",table.find(actions,"descendshot")~=nil and table.find(actions,"descendend")~=nil)
    check("flight ends on floor",math.abs(b.root.Position.Y-o.Y-4.5)<.03)
   end
   API.Clear(b);check("cleanup "..name..mode,effects(o)==0);g:Destroy()
  end)
 end
end
for index,release in {[1]=1.02,[3]=1.3,[4]=1.35,[5]=3.2}do
 run("released effect cancellation "..index,function()
  local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-20)
  API.Cast(b,index,tr.Position,false,hooks);task.wait(release);API.Clear(b);task.wait(2)
  check("released effect removed "..index,#hits==0 and effects(o)==0);g:Destroy()
 end)
end
for index=2,5 do
 run("missing support "..index,function()
  local b,tr,hooks,hits,_,g,o=fixture();g.Floor:Destroy()
  API.Cast(b,index,tr.Position,false,hooks);task.wait(if index==5 then 4.5 else 3.2)
  check("unsupported skill rejected "..index,#hits==0 and effects(o)==0);API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"lowWall","removedFloor","range","arena","lowCeiling"}do
 run("meteor geometry "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture()
  if mode=="lowWall"then part("LowWall",o+Vector3.new(0,.7,-6),Vector3.new(40,1.4,1),g)end
  if mode=="range"then tr.Position=o+Vector3.new(0,3,-40)end
  if mode=="arena"then b.arenaRadius=12 end
  if mode=="lowCeiling"then part("Ceiling",o+Vector3.new(0,2.5,-12),Vector3.new(25,.5,20),g)end
  API.Cast(b,3,tr.Position,false,hooks)
  if mode=="removedFloor"then task.wait(.5);g.Floor:Destroy()end
  task.wait(3.3);check("meteor geometry "..mode,#hits==0);API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"gap","jump","lateWall","lowWall"}do
 run("midnight escape "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,4,tr.Position,false,hooks);task.wait(.25)
  if mode=="gap"then tr.Position=o+Vector3.new(12,3,0)end
  if mode=="jump"then tr.Position+=Vector3.new(0,5,0)end
  if mode=="lateWall"then task.wait(1);part("Wall",o+Vector3.new(0,5,-6),Vector3.new(20,10,1),g)end
  if mode=="lowWall"then part("LowWall",o+Vector3.new(0,.7,-6),Vector3.new(20,1.4,1),g)end
  task.wait(3);check("ring escape "..mode,#hits==0);API.Clear(b);g:Destroy()
 end)
end
for _,late in {false,true}do
 run("beam low wall "..tostring(late),function()
  local b,tr,hooks,hits,_,g,o=fixture()
  if late then API.Cast(b,2,tr.Position,false,hooks);task.wait(.5)end
  part("LowWall",o+Vector3.new(0,.7,-6),Vector3.new(20,1.4,1),g)
  if not late then API.Cast(b,2,tr.Position,false,hooks)end
  task.wait(2);check("beam stops at low wall "..tostring(late),#hits==0);API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"phase2","interrupt","ceiling","lateCeiling","clearAir","dieAir","replace"}do
 run("flight "..mode,function()
  local b,tr,hooks,hits,actions,g,o=fixture();local initial=b.root.CFrame
  b.root.Anchored=false;b.root:SetNetworkOwner(nil)
  if mode=="ceiling"then part("Ceiling",o+Vector3.new(0,12,0),Vector3.new(30,1,30),g)end
  API.Cast(b,5,tr.Position,mode=="phase2",hooks);task.wait(1.3)
  if mode~="ceiling"then check("boss rises "..mode,b.root.Position.Y>initial.Y+2.5 and b.root.Position.Y<=initial.Y+4.01)end
  if mode=="interrupt"then b.humanoid.Health-=60 end
  if mode=="lateCeiling"then part("Ceiling",o+Vector3.new(0,12,0),Vector3.new(30,1,30),g)end
  if mode=="clearAir"then API.Clear(b)end
  if mode=="dieAir"then b.humanoid.Health=0;API.Clear(b)end
  if mode=="replace"then API.Melee(b,tr.Position,hooks)end
  task.wait(5.2)
  check("flight restored floor "..mode,math.abs(b.root.Position.Y-o.Y-4.5)<.08)
  if mode=="phase2"then
   local shots=0;for _,a in actions do if a=="descendshot"then shots+=1 end end
   check("phase two two shots",shots==2 and #hits==2 and hits[1]==36 and hits[2]==36)
  else check("interrupted air damage cancelled "..mode,#hits==0)end
  if mode=="interrupt"then check("damage produces stun",table.find(actions,"stun")~=nil)end
  if mode~="dieAir"then check("flight restores ownership "..mode,not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())end
  API.Clear(b);g:Destroy()
 end)
end
for index,name in {[1]="MoonBolt",[3]="SoulMeteor"}do
 run("phase two projectiles "..index,function()
  local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,index,tr.Position,true,hooks)
  task.wait(if index==1 then .98 else 1.22)
  check("five phase two projectiles "..index,effects(o,name)==5)
  task.wait(2);check("single cast damage budget "..index,#hits==1);API.Clear(b);g:Destroy()
 end)
end
run("melee and ownership",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
 b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 for i=1,3 do API.Melee(b,tr.Position,hooks);task.wait(1.1);check("claw"..i,#hits==i and hits[i]==18)end
 check("three claw motions",actions[1]=="attack1"and actions[2]=="attack3"and actions[3]=="attack4")
 check("melee ownership",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 check("melee preserves special deadline",b.nextAbilityAt==0);API.Clear(b);g:Destroy()
end)
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks);check("spawn vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(2);check("spawn finishes",actions[1]=="spawn"and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2)end
for _,b in active do API.Clear(b)end
folder:Destroy();result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS"else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
