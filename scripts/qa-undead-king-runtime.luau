--!nocheck
-- Disposable distant fixtures exercise actual installed server mechanics, never live rewards/profiles.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.UndeadKingAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local cfg
for _,c in Config.bosses.bosses do if c.id=="un_king" then cfg=c.fight;assert(c.hp==2070) end end
assert(cfg and cfg.undeadKing)
assert(not workspace:FindFirstChild("QAUndeadKingFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAUndeadKingFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAUndeadKingResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAUndeadKingResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
 local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
 number+=1;local o=Vector3.new(145000+number*500,30000,0)
 local g=Instance.new("Folder");g.Parent=folder
 part("Floor",o-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
 local m=Instance.new("Model");m.Parent=g
 local r=part("HumanoidRootPart",o+Vector3.new(0,4.5,0),Vector3.new(4,9,3),m)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=2070,2070,cfg.walkSpeed;h.Parent=m
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
 for _,f in workspace:GetChildren()do if f.Name=="UndeadKingEncounter"then
  for _,p in f:GetChildren()do if p:IsA("BasePart")and(p.Position-o).Magnitude<100 and(not name or p.Name==name)then n+=1 end end
 end end
 return n
end
local function summons(o,name)
 local list={}
 for _,e in workspace:GetChildren()do if e.Name=="UndeadKingEncounter"then
  for _,m in e:GetChildren()do if m:IsA("Model")and m.PrimaryPart and(m.PrimaryPart.Position-o).Magnitude<100 and(not name or m.Name==name)then table.insert(list,m)end end
 end end
 return list
end
for index,name in {"skill3","skill2","swordcall","skill1"}do
 for _,mode in {"hit","wall","dodge","death","dynamicWall","clear"}do
  run(name..mode,function()
   local b,tr,hooks,hits,_,g,o=fixture()
   local function wall()part("Wall",o+Vector3.new(0,8,-5),Vector3.new(45,16,1),g)end
   if mode=="wall"then wall()end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="dodge"then tr.Position+=Vector3.new(45,0,0)end
   if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
   if mode=="clear"then task.wait(.1);API.Clear(b)end
   if mode=="dynamicWall"then task.wait(.2);wall()end
   task.wait(if index==3 then 6.1 else 3.8)
   local expected=cfg.undeadKing[name].damage;local n=0;for _,d in hits do if d==expected then n+=1 end end
   check(name..mode.." damage count="..n,if mode=="hit"then n==1 else n==0)
   API.Clear(b);check(name..mode.." cleanup",effects(o)==0 and #summons(o)==0);g:Destroy()
  end)
 end
end
for index=2,4 do
 for _,mode in {"noFloor","lateClear","lateDeath","range","lowWall","lateFloor"}do
  run("geometry/cancel "..index..mode,function()
   local b,tr,hooks,hits,_,g,o=fixture()
   if mode=="noFloor"then g.Floor:Destroy()end
   if mode=="range"then tr.Position=o+Vector3.new(0,3,-48)end
   if mode=="lowWall"then part("LowWall",o+Vector3.new(0,.7,-6),Vector3.new(45,1.4,1),g)end
   API.Cast(b,index,tr.Position,false,hooks)
   if mode=="lateFloor"then task.wait(.3);g.Floor:Destroy()end
   if mode=="lateClear"or mode=="lateDeath"then task.wait(1.75);if mode=="lateDeath"then b.humanoid.Health=0 end;API.Clear(b)end
   task.wait(6)
   -- Flying skulls may pass above a knee-high obstacle; only ground-bound casts must reject it.
   if not(index==2 and mode=="lowWall")then
    local n=0;for _,d in hits do if d~=7 then n+=1 end end
    check("no delayed damage "..index..mode,n==0)
   end
   API.Clear(b);check("all summons removed "..index..mode,#summons(o)==0);g:Destroy()
  end)
 end
end
for _,mode in {"kill","dodgeFuse","sharedBudget","cap","wallAfterArm"}do
 run("skulls "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-8)
  API.Cast(b,2,tr.Position,true,hooks)
  local deadline=os.clock()+2.5;local list={}
  repeat task.wait(.05);list=summons(o,"UndeadSkull")until #list==3 or os.clock()>deadline
  check("three skulls "..mode,#list==3)
  for _,m in list do check("killable skull "..mode,m.Humanoid.MaxHealth==8 and m:GetAttribute("MobId")=="undead_skull")end
  if mode=="kill"then for _,m in list do m.Humanoid.Health=0 end end
  if mode=="dodgeFuse"then task.wait(.4);tr.Position+=Vector3.new(30,0,0)end
  if mode=="wallAfterArm"then task.wait(.4);part("LateWall",o+Vector3.new(0,5,-6),Vector3.new(40,10,.5),g)end
  if mode=="cap"then
   tr.Position=o+Vector3.new(0,3,-50);API.Cast(b,2,tr.Position,true,hooks);task.wait(1.3)
   local alive=0;for _,m in summons(o,"UndeadSkull")do if m.Humanoid.Health>0 then alive+=1 end end
   check("four live skull cap",alive<=4)
  end
  task.wait(2)
  if mode=="sharedBudget"then check("skull shared budget",#hits==1 and hits[1]==31)
  elseif mode~="cap"then check("prevent skull damage "..mode,#hits==0)end
  check("no summoned immunity",b.model:GetAttribute("Shielded")==false)
  API.Clear(b);g:Destroy()
 end)
end
run("ghoul lifecycle and cap",function()
 local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-48)
 for i=1,2 do API.Cast(b,4,tr.Position,true,hooks);task.wait(2.6)end
 local list=summons(o,"UndeadGhoul");check("four live ghouls",#list==4)
 for _,m in list do
  check("ghoul stats",m.Humanoid.MaxHealth==20 and m.Humanoid.WalkSpeed==11)
  check("ghoul server ownership",not m.PrimaryPart.Anchored and m.PrimaryPart:GetNetworkOwner()==nil and not m.PrimaryPart:GetNetworkOwnershipAuto())
  m.Humanoid.Health=0
 end
 task.wait(.15);for _,m in list do check("intact ghoul death",m.Parent~=nil and m.PrimaryPart.Anchored and #m:GetDescendants()>100)end
 task.wait(2.2);check("dead ghouls cleaned",#summons(o,"UndeadGhoul")==0)
 API.Clear(b);g:Destroy()
end)
for _,mode in {"phase2","ceiling","lateCeiling","survivesNextCast"}do
 run("sword "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture()
  if mode=="ceiling"then part("Ceiling",o+Vector3.new(0,8,-12),Vector3.new(30,1,20),g)end
  API.Cast(b,3,tr.Position,mode=="phase2",hooks);task.wait(1.8)
  local list=summons(o,"UndeadSword")
  if mode=="ceiling"then check("sword rejects ceiling",#list==0)else
   check("sword count "..mode,#list==(if mode=="phase2"then 2 else 1))
   for _,m in list do check("prop not combat boss",game.CollectionService:HasTag(m,"BossProp")and not game.CollectionService:HasTag(m,"Boss")and not m:FindFirstChildOfClass("Humanoid"))end
  end
  if mode=="lateCeiling"then part("Ceiling",o+Vector3.new(0,8,-12),Vector3.new(30,1,20),g)end
  if mode=="survivesNextCast"then API.Melee(b,tr.Position,hooks)end
  task.wait(4)
  check("sword impact "..mode,if mode=="ceiling"or mode=="lateCeiling"then #hits==0 else #hits==1 and hits[1]==38)
  API.Clear(b);g:Destroy()
 end)
end
run("melee and ownership",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
 b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 for i=1,2 do API.Melee(b,tr.Position,hooks);task.wait(1);check("claw"..i,#hits==i and hits[i]==20)end
 check("two claw motions",actions[1]=="attack"and actions[2]=="attack2")
 check("melee ownership",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 API.Clear(b);g:Destroy()
end)
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks);check("spawn vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(2);check("spawn finishes",actions[1]=="spawn"and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2)end
for _,b in active do API.Clear(b)end
folder:Destroy();result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS"else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
