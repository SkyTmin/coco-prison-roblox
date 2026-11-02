--!nocheck
-- Disposable distant fixtures exercise actual installed server mechanics, never live rewards/profiles.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.SpiderQueenAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local cfg
for _,c in Config.bosses.bosses do if c.id=="spider_queen" then cfg=c.fight;assert(c.hp==1570) end end
assert(cfg and cfg.spiderQueen)
assert(not workspace:FindFirstChild("QASpiderQueenFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QASpiderQueenFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QASpiderQueenResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QASpiderQueenResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
 local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
 number+=1;local o=Vector3.new(86000+number*500,30000,0)
 local g=Instance.new("Folder");g.Parent=folder
 part("Floor",o-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
 local m=Instance.new("Model");m.Parent=g
 local r=part("HumanoidRootPart",o+Vector3.new(0,4.5,0),Vector3.new(4,5,3),m)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=1570,1570,cfg.walkSpeed;h.Parent=m
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
local function adds(o)
 local list={};for _,m in game.CollectionService:GetTagged("Mob")do
 if m.Name=="HuntsmanSpider"and m.PrimaryPart and(m.PrimaryPart.Position-o).Magnitude<100 then table.insert(list,m)end end
 return list
end
local function zones(o)
 local list={};for _,e in workspace:GetChildren()do if e.Name=="SpiderQueenEncounter"then
 for _,z in e:GetChildren()do if z.Name=="QueenWeb"then local p=z:FindFirstChildWhichIsA("BasePart");if p and(p.Position-o).Magnitude<100 then table.insert(list,z)end end end end end
 return list
end
for index,name in {"webattack","fangattack"}do
 for _,mode in {"hit","wall","dodge","death","dynamicWall","clear","afterRelease"}do
  run(name..mode,function()
   local b,tr,hooks,hits,_,g,o,snares=fixture();tr.Position=o+Vector3.new(0,3,if index==1 then -14 else -7)
   local function wall()part("Wall",o+Vector3.new(0,6,-3.5),Vector3.new(40,12,1),g)end
   if mode=="wall"then wall()end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="dodge"then tr.Position+=Vector3.new(40,0,0)end
   if mode=="death"then task.wait(.05);b.humanoid.Health=0;API.Clear(b)end
   if mode=="clear"then task.wait(.1);API.Clear(b)end
   if mode=="dynamicWall"then task.wait(.15);wall()end
   if mode=="afterRelease"then task.wait(if index==1 then 1.2 else .4);API.Clear(b)end
   task.wait(3.2)
   check(name..mode.." hits="..#hits,if mode=="hit"then #hits==1 and hits[1]==cfg.spiderQueen[name].damage else #hits==0)
   if index==1 then check("web slow "..mode,if mode=="hit"then #snares>0 and snares[1][1]==3 else #snares==0)end
   API.Clear(b);check("cleanup "..name..mode,#zones(o)==0);g:Destroy()
  end)
 end
end
for _,mode in {"lowWall","inFlightWall","ceiling","void","range","arena"}do
 run("web geometry "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-15)
  if mode=="lowWall"then part("LowWall",o+Vector3.new(0,.7,-7),Vector3.new(40,1.4,1),g)end
  if mode=="ceiling"then part("Ceiling",o+Vector3.new(0,6,-5),Vector3.new(30,.8,30),g)end
  if mode=="void"then g.Floor:Destroy()end
  if mode=="range"then tr.Position=o+Vector3.new(0,3,-35)end
  if mode=="arena"then b.arenaRadius=14 end
  API.Cast(b,1,tr.Position,false,hooks)
  if mode=="inFlightWall"then task.wait(1.2);part("Wall",o+Vector3.new(0,6,-8),Vector3.new(40,12,1),g)end
  task.wait(3)
  check("web "..mode.." stopped",#hits==0 and #zones(o)==0);API.Clear(b);g:Destroy()
 end)
end
run("late entry, independent lifetime and cleanup",function()
 local b,tr,hooks,hits,_,g,o,snares=fixture();local at=tr.Position
 API.Cast(b,1,at,false,hooks);tr.Position+=Vector3.new(30,0,0);task.wait(2.5)
 check("warning locks target",#hits==0 and #zones(o)==1)
 tr.Position=at;API.Melee(b,tr.Position,hooks);task.wait(.5)
 check("entering web slows without another impact",#hits==0 and #snares>0)
 API.Clear(b);local n=#snares;task.wait(.8)
 check("clear ends zone refresh",#snares==n and #zones(o)==0);g:Destroy()
end)
run("phase two and zone lifetime",function()
 local b,tr,hooks,hits,_,g,o=fixture()
 local m=Instance.new("Model");m.Parent=g;local r=part("HumanoidRootPart",o+Vector3.new(10,3,-12),Vector3.new(2,2,2),m)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.Parent=false,m
 local original=hooks.fighters;hooks.fighters=function()local fs=original();table.insert(fs,{player={Character=m},root=r,humanoid=h});return fs end
 API.Cast(b,1,tr.Position,true,hooks);task.wait(3)
 check("two warned targets",#hits==2 and hits[1]==25 and hits[2]==25 and #zones(o)==2)
 task.wait(7)
 check("webs expire while boss lives",#zones(o)==0);API.Clear(b);g:Destroy()
end)
run("web zone cap",function()
 local b,tr,hooks,_,_,g,o=fixture()
 for i=1,5 do API.Cast(b,1,tr.Position,false,hooks);task.wait(1.9);check("bounded web zones "..i,#zones(o)<=3)end
 API.Clear(b);g:Destroy()
end)
run("melee and ownership",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
 b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 for i=1,2 do API.Melee(b,tr.Position,hooks);task.wait(1.25);check("bite"..i,#hits==i and hits[i]==16)end
 check("alternating fangs",actions[1]=="bite"and actions[2]=="bite_2")
 check("server owns released cast",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 check("melee does not postpone specials",b.nextAbilityAt==0);API.Clear(b);g:Destroy()
end)
for _,mode in {"count","phase2","cap","death","wall","void","hit","kill","blocked"}do
 run("adds "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-45)
  if mode=="void"then g.Floor:Destroy()end
  if mode=="wall"then for i=0,3 do local a=i*math.pi/2;part("Wall",o+Vector3.new(math.cos(a)*3,3,math.sin(a)*3),if i%2==0 then Vector3.new(1,6,10)else Vector3.new(10,6,1),g)end end
  API.Cast(b,3,tr.Position,mode=="phase2"or mode=="cap",hooks)
  if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
  task.wait(2.6);local list=adds(o)
  check("add count "..mode.."="..#list,#list==(if mode=="death"or mode=="wall"or mode=="void"then 0 elseif mode=="phase2"or mode=="cap"then 4 else 3))
  if mode=="count"then
   task.wait(.4)
   local grounded,serverOwned=true,true
   for _,m in list do
    local r=m.PrimaryPart
    grounded=grounded and math.abs(r.Position.Y-o.Y-.9)<.08
    serverOwned=serverOwned and not r.Anchored and r:GetNetworkOwner()==nil and not r:GetNetworkOwnershipAuto()
   end
   check("add feet meet floor",grounded);check("server owns walking adds",serverOwned)
  end
  if mode=="cap"then API.Cast(b,3,tr.Position,true,hooks);task.wait(2.6);check("six living add cap",#adds(o)==6)end
  if mode=="hit"or mode=="kill"or mode=="blocked"then
   local m=list[1];for i=2,#list do list[i]:FindFirstChildOfClass("Humanoid").Health=0 end
   local root,h=m.PrimaryPart,m:FindFirstChildOfClass("Humanoid");h.WalkSpeed=0;root.Anchored=true
   tr.Position=root.Position+Vector3.new(0,0,-2.5)
   if mode=="blocked"then part("AttackWall",root.Position+Vector3.new(0,0,-1.25),Vector3.new(10,10,.3),g)end
   local deadline=os.clock()+1;repeat task.wait(.03)until m:GetAttribute("MobWindup")or os.clock()>deadline
   check("add attack motion",typeof(m:GetAttribute("MobWindup"))=="number")
   if mode=="kill"then h.Health=0 end
   task.wait(.6)
   check("add contact "..mode.."="..#hits,if mode=="hit"then #hits==1 and hits[1]==6 else #hits==0)
   if mode=="kill"then check("killed add held for death",m.Parent~=nil and root.Anchored);task.wait(1.6);check("dead add removed",m.Parent==nil)end
  end
  API.Clear(b);check("all adds removed on clear",#adds(o)==0);g:Destroy()
 end)
end
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks);check("spawn vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(2);check("spawn finishes",actions[1]=="spawn"and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2)end
for _,b in active do API.Clear(b)end
folder:Destroy();result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS"else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
