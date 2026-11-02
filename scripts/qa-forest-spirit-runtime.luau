--!nocheck
-- Disposable distant fixtures exercise actual installed server mechanics, never live rewards/profiles.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.ForestSpiritAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local cfg
for _,c in Config.bosses.bosses do if c.id=="forest_spirit" then cfg=c.fight;assert(c.hp==2320) end end
assert(cfg and cfg.forestSpirit)
assert(not workspace:FindFirstChild("QAForestSpiritFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAForestSpiritFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAForestSpiritResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAForestSpiritResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
 local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
 number+=1;local o=Vector3.new(185000+number*500,30000,0)
 local g=Instance.new("Folder");g.Parent=folder
 part("Floor",o-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
 local m=Instance.new("Model");m.Parent=g
 local r=part("HumanoidRootPart",o+Vector3.new(0,4.5,0),Vector3.new(4,9,3),m)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=2320,2320,cfg.walkSpeed;h.Parent=m
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
 for _,f in workspace:GetChildren()do if f.Name=="ForestSpiritEncounter"then
  for _,p in f:GetChildren()do if p:IsA("BasePart")and(p.Position-o).Magnitude<100 and(not name or p.Name==name)then n+=1 end end
 end end
 return n
end
local function summons(o,name)
 local list={}
 for _,e in workspace:GetChildren()do if e.Name=="ForestSpiritEncounter"then
  for _,m in e:GetDescendants()do if m:IsA("Model")and m.PrimaryPart and(m.PrimaryPart.Position-o).Magnitude<100 and(not name or m.Name==name)then table.insert(list,m)end end
 end end
 return list
end
for index,name in {"attack1","attack2","attack3","attack4","attack5","attack6","attack8"}do
 for _,mode in {"hit","wall","dodge","death","dynamicWall","clear"}do
  run(name..mode,function()
   local b,tr,hooks,hits,_,g,o,snares=fixture()
   if index==7 then tr.Position=o+Vector3.new(0,3,-6)end
   local function wall()part("Wall",o+Vector3.new(0,8,-5),Vector3.new(45,16,1),g)end
   if mode=="wall"then wall()end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="dodge"then tr.Position+=Vector3.new(55,0,0)end
   if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
   if mode=="clear"then task.wait(.1);API.Clear(b)end
   if mode=="dynamicWall"then task.wait(.3);wall()end
   task.wait(if index==6 then 8.8 elseif index==7 then 7.8 else 4.4)
   local expected=cfg.forestSpirit[name].damage;local n=0;for _,d in hits do if d==expected then n+=1 end end
   local total=if index==4 then 2 elseif index==6 then 3 else 1
   check(name..mode.." damage count="..n,if mode=="hit"then n==total else n==0)
   if index==1 and mode=="hit"then check("roots slow",#snares==1 and snares[1][1]==1 and snares[1][2]==1.2)end
   API.Clear(b);check(name..mode.." cleanup",effects(o)==0 and #summons(o)==0);g:Destroy()
  end)
 end
end
for index=1,7 do
 if index~=3 then
  for _,mode in {"noFloor","lateFloor","lateClear"}do
   run("ground/cancel "..index..mode,function()
    local b,tr,hooks,hits,_,g,o=fixture()
    if index==7 then tr.Position=o+Vector3.new(0,3,-6)end
    if mode=="noFloor"then g.Floor:Destroy()end
    API.Cast(b,index,tr.Position,false,hooks)
    if mode=="lateFloor"then task.wait(.3);g.Floor:Destroy()end
    if mode=="lateClear"then task.wait(if index==7 then 1.9 else .7);API.Clear(b)end
    task.wait(if index>=6 then 8 else 4.7)
    check("no unsupported/delayed damage "..index..mode,#hits==0)
    API.Clear(b);check("cleanup "..index..mode,#summons(o)==0 and effects(o)==0);g:Destroy()
   end)
  end
 end
end
for _,mode in {"gap","jump","lowWall","lateWall","lostFloor"}do
 run("wave escape "..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,5,tr.Position,false,hooks);task.wait(.3)
  if mode=="gap"then tr.Position=o+Vector3.new(12,3,0)end
  if mode=="jump"then tr.Position+=Vector3.new(0,5,0)end
  if mode=="lowWall"then part("LowWall",o+Vector3.new(0,.7,-6),Vector3.new(25,1.4,1),g)end
  if mode=="lateWall"then task.wait(1.7);part("Wall",o+Vector3.new(0,5,-6),Vector3.new(25,10,1),g)end
  if mode=="lostFloor"then task.wait(1.7);g.Floor:Destroy()end
  task.wait(3.5);check("wave avoids "..mode,#hits==0);API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"damage","death","replacement","ceiling","lateCeiling"}do
 run("storm interrupt "..mode,function()
  local b,tr,hooks,hits,actions,g,o=fixture()
  if mode=="ceiling"then part("Ceiling",o+Vector3.new(0,2.5,-12),Vector3.new(30,.5,20),g)end
  API.Cast(b,6,tr.Position,true,hooks);task.wait(1.1)
  if mode=="damage"then b.humanoid.Health-=100 end
  if mode=="death"then b.humanoid.Health=0;API.Clear(b)end
  if mode=="replacement"then API.Melee(b,tr.Position,hooks)end
  if mode=="lateCeiling"then part("Ceiling",o+Vector3.new(0,2.5,-12),Vector3.new(30,.5,20),g)end
  task.wait(8)
  check("storm stopped "..mode,#hits==0)
  if mode=="damage"then check("interrupt animation",table.find(actions,"spawn_cancelled")~=nil and b.humanoid.WalkSpeed==cfg.walkSpeed)end
  API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"killTotem","killAdds","cap","deathAfterRelease","replacement"}do
 run("ritual "..mode,function()
  local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
  API.Cast(b,7,tr.Position,true,hooks)
  local deadline=os.clock()+3;repeat task.wait(.05)until #summons(o)==5 or os.clock()>deadline
  local totems=summons(o,"forest_totem");check("one totem "..mode,#totems==1)
  check("four adds "..mode,#summons(o)==5)
  check("totem vulnerable",totems[1].Humanoid.MaxHealth==60 and b.model:GetAttribute("Shielded")==false)
  if mode=="killTotem"then check("normal combat kills totem",require(game.ServerScriptService.Server.Services.CombatService).ApplyDamage(totems[1].Humanoid,1000,"player")and totems[1].Humanoid.Health<=0)end
  if mode=="killAdds"then for _,m in summons(o)do if m.Name~="forest_totem"then m.Humanoid.Health=0 end end end
  if mode=="deathAfterRelease"then b.humanoid.Health=0;API.Clear(b)end
  if mode=="replacement"then API.Melee(b,tr.Position+Vector3.new(30,0,0),hooks)end
  if mode=="cap"then
   tr.Position=o+Vector3.new(0,3,-50);API.Cast(b,7,tr.Position,true,hooks);task.wait(2.2)
   local count=0;for _,m in summons(o)do if m.Name~="forest_totem"and m.Humanoid.Health>0 then count+=1 end end
   check("four live add cap",count<=4)
  end
  task.wait(6)
  local blasts=0;for _,d in hits do if d==42 then blasts+=1 end end
  if mode=="killAdds"then check("totem still bursts",blasts==1)else check("ritual burst avoided "..mode,blasts==0)end
  if mode=="killTotem"then check("totem interrupt animation",table.find(actions,"spawn_cancelled")~=nil);check("ritual squad dies",#summons(o)==0)end
  API.Clear(b);check("ritual clear removes all",#summons(o)==0);g:Destroy()
 end)
end
for id,damage in {forest_shaman=9,forest_explorer=8,forest_skull=7}do
 for _,mode in {"hit","wall","kill"}do
  run("summon contact "..id..mode,function()
   local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,7,tr.Position,false,hooks)
   local deadline=os.clock()+3;local list={};repeat task.wait(.05);list=summons(o,id)until #list>0 or os.clock()>deadline
   check("summon exists "..id..mode,#list==1)
   local chosen=list[1]
   for _,m in summons(o)do if m.Name~=id and m.Name~="forest_totem"then m.Humanoid.Health=0 end end
   local pos=chosen.PrimaryPart.Position;tr.Position=pos+Vector3.new(0,0,-2)
   if mode=="wall"then part("Wall",pos+Vector3.new(0,3,-1),Vector3.new(16,12,.35),g)end
   if mode=="kill"then check("combat damage kills summon "..id,require(game.ServerScriptService.Server.Services.CombatService).ApplyDamage(chosen.Humanoid,1000,"player")and chosen.Humanoid.Health<=0)end
   task.wait(3.5)
   local contacts=0;for _,d in hits do if d==damage then contacts+=1 end end
   check("summon contact "..id..mode,if mode=="hit"then contacts>0 else contacts==0)
   if mode=="hit"and id~="forest_skull"then check("minion server owned "..id,not chosen.PrimaryPart.Anchored and chosen.PrimaryPart:GetNetworkOwner()==nil and not chosen.PrimaryPart:GetNetworkOwnershipAuto())end
   API.Clear(b);g:Destroy()
  end)
 end
end
for _,index in {1,2,3,4}do
 run("phase two budget "..index,function()
  local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,index,tr.Position,true,hooks);task.wait(5)
  check("phase two damage budget "..index,#hits==(if index==4 then 2 else 1))
  API.Clear(b);g:Destroy()
 end)
end
run("melee and ownership",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
 b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 API.Melee(b,tr.Position,hooks);task.wait(2.2)
 check("claw contact",#hits==1 and hits[1]==23 and actions[1]=="attack7")
 check("claw restores ownership",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 API.Clear(b);g:Destroy()
end)
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks);check("spawn vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(3.5);check("spawn finishes",actions[1]=="spawn"and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2)end
for _,b in active do API.Clear(b)end
folder:Destroy();result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS"else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
