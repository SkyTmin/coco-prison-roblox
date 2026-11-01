--!nocheck
-- Disposable distant fixtures exercise actual installed server mechanics, never live rewards/profiles.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.IllusionistAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local cfg
for _,c in Config.bosses.bosses do if c.id=="illusionist" then cfg=c.fight;assert(c.hp==1340) end end
assert(cfg and cfg.illusionist)
assert(not workspace:FindFirstChild("QAIllusionistFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAIllusionistFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAIllusionistResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAIllusionistResult","running",game.ServerStorage
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
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=1340,1340,cfg.walkSpeed;h.Parent=m
 local spawn=part("Spawn",o-Vector3.new(0,.5,0),Vector3.one,g);spawn.CanCollide,spawn.CanQuery=false,false
 local target=Instance.new("Model");target.Parent=g
 local tr=part("HumanoidRootPart",o+Vector3.new(0,3,-12),Vector3.new(2,2,2),target)
 local th=Instance.new("Humanoid");th.RequiresNeck=false;th.Parent=target
 local fighter={player={Character=target},root=tr,humanoid=th}
 local state=Instance.new("Folder");state.Parent=g
 local boss={root=r,model=m,humanoid=h,spawn=spawn,state=state,fight=cfg,arenaRadius=60,busyUntil=0,nextAbilityAt=0}
 table.insert(active,boss)
 local hits,actions={},{}
 local hooks={fighters=function()return {fighter}end,hurt=function(_,_,amount)table.insert(hits,amount);return true end,
 act=function(_,name)table.insert(actions,name);m:SetAttribute("Action",name)end,
 telegraph=function(size,cf)local p=part("Mark",cf.Position,size,g);p.CFrame=cf;p.CanCollide,p.CanQuery=false,false;return p end}
 return boss,tr,hooks,hits,actions,g,o
end
local function check(name,ok)assert(ok,name);table.insert(checks,name)end
local function run(name,fn)
 remaining+=1;task.spawn(function()local ok,err=xpcall(fn,debug.traceback);if not ok then table.insert(errors,name..": "..tostring(err))end;remaining-=1 end)
end
local function rabbits(o)
 local list={};for _,m in game.CollectionService:GetTagged("Mob") do
 if m.Name=="IllusionistRabbit" and m.PrimaryPart and (m.PrimaryPart.Position-o).Magnitude<100 then table.insert(list,m)end end
 return list
end
for index,name in {"attackdagger","attackcards","attackbox"}do
 for _,mode in {"hit","wall","dodge","death","dynamicWall","clear"}do
  run(name..mode,function()
   local b,tr,hooks,hits,_,g,o=fixture()
   local function wall()part("Wall",o+Vector3.new(0,6,-5),Vector3.new(40,12,1),g)end
   if mode=="wall"then wall()end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="dodge"then tr.Position+=Vector3.new(40,0,0)end
   if mode=="death"then task.wait(.05);b.humanoid.Health=0;API.Clear(b)end
   if mode=="clear"then task.wait(.1);API.Clear(b)end
   if mode=="dynamicWall"then task.wait(.15);wall()end
   task.wait(3.8)
   check(name..mode.." hits="..#hits,if mode=="hit"then #hits==1 and hits[1]==cfg.illusionist[name].damage else #hits==0)
   API.Clear(b);g:Destroy()
  end)
 end
end
run("card fan shared hit budget",function()
 local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-5)
 API.Cast(b,2,tr.Position,true,hooks);task.wait(3.8)
 check("fan cannot shotgun one fighter",#hits==1 and hits[1]==22);API.Clear(b);g:Destroy()
end)
run("released projectile survives cast change",function()
 local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-28)
 API.Cast(b,1,tr.Position,false,hooks);task.wait(.9);API.Melee(b,tr.Position,hooks);task.wait(1.8)
 check("dagger independent lifetime",#hits==1 and hits[1]==22);API.Clear(b);g:Destroy()
end)
run("melee",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-6)
 for i=1,2 do API.Melee(b,tr.Position,hooks);task.wait(1.2);check("melee"..i,#hits==i and hits[i]==14)end
 check("alternating authored swings",actions[1]=="attack"and actions[2]=="attack2")
 check("no special cooldown from melee",b.nextAbilityAt==0);API.Clear(b);g:Destroy()
end)
for _,mode in {"normal","wall","lowWall","dynamicWall","death"}do
 run("phase"..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();local before=b.root.Position
  local function wall(low)part("Wall",o+Vector3.new(3,if low then .7 else 6,0),Vector3.new(.6,if low then 1.4 else 12,40),g)end
  if mode=="wall"then wall(false)elseif mode=="lowWall"then wall(true)end
  API.Cast(b,5,b.root.Position,false,hooks)
  if mode=="dynamicWall"then task.wait(.3);wall(false)end
  if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
  task.wait(1.5)
  check("phase"..mode.." bounded distance",(b.root.Position-before).Magnitude<=(if mode=="normal"then 6.01 else 1.01))
  if mode=="normal"then check("phase actually moves",(b.root.Position-before).Magnitude>5.9)end
  check("phase no damage",#hits==0);API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"heal","interrupt","full","clear","death","empty"}do
 run("regen"..mode,function()
  local b,tr,hooks,_,actions,g=fixture();b.humanoid.Health=if mode=="full"then 1335 else 500
  if mode=="empty"then hooks.fighters=function()return {}end end
  API.Cast(b,6,tr.Position,false,hooks)
  if mode=="interrupt"then task.wait(.3);b.humanoid.Health-=45 end
  if mode=="clear"then task.wait(.3);API.Clear(b)end
  if mode=="death"then task.wait(.3);b.humanoid.Health=0;API.Clear(b)end
  task.wait(6.1)
  local expected=if mode=="heal"then 500+1340*.08 elseif mode=="interrupt"then 455 elseif mode=="full"then 1340 elseif mode=="death"then 0 else 500
  check("regen"..mode.." HP="..b.humanoid.Health,math.abs(b.humanoid.Health-expected)<.01)
  if mode=="interrupt"then check("regen flinch",actions[2]=="hurt")end
  API.Clear(b);g:Destroy()
 end)
end
for _,mode in {"count","phase2","death","wall","cap","kill","explode"}do
 run("rabbits"..mode,function()
  local b,tr,hooks,hits,_,g,o=fixture();tr.Position=o+Vector3.new(0,3,-40)
  if mode=="wall"then for i=0,3 do local a=i*math.pi/2;part("Wall",o+Vector3.new(math.cos(a)*3,3,math.sin(a)*3),if i%2==0 then Vector3.new(1,6,10)else Vector3.new(10,6,1),g)end end
  API.Cast(b,4,tr.Position,mode=="phase2"or mode=="cap",hooks)
  if mode=="death"then task.wait(.1);b.humanoid.Health=0;API.Clear(b)end
  task.wait(2.5);local list=rabbits(o)
  check("rabbit count "..mode.."="..#list,#list==(if mode=="death"or mode=="wall"then 0 elseif mode=="phase2"or mode=="cap"then 4 else 3))
  if mode=="cap"then API.Cast(b,4,tr.Position,true,hooks);task.wait(2.5);check("rabbit cap",#rabbits(o)<=4)end
  if mode=="kill"or mode=="explode"then
   local rabbit=list[1];for i=2,#list do list[i]:FindFirstChildOfClass("Humanoid").Health=0 end
   tr.Position=rabbit.PrimaryPart.Position+Vector3.new(0,1,0)
   local deadline=os.clock()+2;repeat task.wait(.05)until rabbit:GetAttribute("MobWindup")or os.clock()>deadline
   check("rabbit fuse animation",typeof(rabbit:GetAttribute("MobWindup"))=="number")
   if mode=="kill"then rabbit:FindFirstChildOfClass("Humanoid").Health=0 end
   task.wait(2.8)
   check("rabbit "..mode.." hits="..#hits,if mode=="kill"then #hits==0 else #hits==1 and hits[1]==14)
  end
  API.Clear(b);check("rabbit cleanup",#rabbits(o)==0);g:Destroy()
 end)
end
for _,index in {3,4,5}do
 run("unsupported ground "..index,function()
  local b,tr,hooks,hits,_,g,o=fixture();g.Floor:Destroy();local before=b.root.CFrame
  API.Cast(b,index,tr.Position,false,hooks);task.wait(3.8)
  check("unsupported ground no damage "..index,#hits==0)
  check("unsupported ground no rabbits "..index,#rabbits(o)==0)
  check("unsupported ground no displacement "..index,(b.root.Position-before.Position).Magnitude<.01)
  API.Clear(b);g:Destroy()
 end)
end
run("floor removed during card phase",function()
 local b,tr,hooks,_,_,g=fixture();local before=b.root.CFrame
 API.Cast(b,5,tr.Position,false,hooks);task.wait(.2);g.Floor:Destroy();task.wait(1.2)
 check("phase rechecks support at release",(b.root.Position-before.Position).Magnitude<.01)
 API.Clear(b);g:Destroy()
end)
run("spawn and physics",function()
 local b,tr,hooks,_,actions,g=fixture();b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 API.Spawn(b,hooks);check("spawn vulnerable",b.model:GetAttribute("Shielded")==false);task.wait(2)
 check("spawn clip",actions[1]=="active")
 API.Melee(b,tr.Position,hooks);task.wait(1.2)
 check("server ownership restored",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2)end
for _,b in active do API.Clear(b)end
folder:Destroy()
result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS"else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
