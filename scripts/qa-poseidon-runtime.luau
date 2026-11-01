--!nocheck
-- Distant disposable fixtures; no real boss/profile/reward changes.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.PoseidonAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local BlockRig=require(game.ReplicatedStorage.Shared.BlockRig)
local cfg
for _,c in Config.bosses.bosses do if c.id=="poseidon" then cfg=c.fight end end
assert(cfg and cfg.poseidon)
assert(not workspace:FindFirstChild("QAPoseidonFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAPoseidonFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAPoseidonResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAPoseidonResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
	local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
	number+=1;local origin=Vector3.new(86000+number*500,30000,0)
	local g=Instance.new("Folder");g.Parent=folder
	part("Floor",origin-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
	local m=Instance.new("Model");m.Parent=g
	local r=part("HumanoidRootPart",origin+Vector3.new(0,4.5,0),Vector3.new(4,5,3),m)
	local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=1120,1120,cfg.walkSpeed;h.Parent=m
	local spawn=part("Spawn",origin-Vector3.new(0,.5,0),Vector3.one,g);spawn.CanCollide,spawn.CanQuery=false,false
	local target=Instance.new("Model");target.Parent=g
	local tr=part("HumanoidRootPart",origin+Vector3.new(0,3,-7),Vector3.new(2,2,2),target)
	local th=Instance.new("Humanoid");th.RequiresNeck=false;th.Parent=target
	local fighter={player={Character=target},root=tr,humanoid=th}
	local state=Instance.new("Folder");state.Parent=g
	local boss={root=r,model=m,humanoid=h,spawn=spawn,state=state,fight=cfg,arenaRadius=60,busyUntil=0,nextAbilityAt=0}
	table.insert(active,boss)
	local hits,actions,snares={},{},{}
	local hooks={fighters=function() return {fighter} end,
		hurt=function(_,_,amount,_,strength,lift) table.insert(hits,{amount=amount,strength=strength,lift=lift});return true end,
		snare=function(_,duration) table.insert(snares,duration) end,
		act=function(_,name) table.insert(actions,name);m:SetAttribute("Action",name) end,
		telegraph=function(size,cf) local p=part("Mark",cf.Position,size,g);p.CFrame=cf;p.CanCollide,p.CanQuery=false,false;return p end}
	return boss,tr,hooks,hits,actions,g,origin,snares
end
local function check(name,ok) assert(ok,name);table.insert(checks,name) end
local function run(name,fn)
	remaining+=1;task.spawn(function() local ok,err=xpcall(fn,debug.traceback);if not ok then table.insert(errors,name..": "..tostring(err)) end;remaining-=1 end)
end
for index,name in {"wave_clash","epicenter","torpedo","stab"} do
 for _,mode in {"hit","wall","death","dodge","dynamicWall"} do
  run(name..mode,function()
   local b,tr,hooks,hits,actions,g,o=fixture()
   local function wall() return part("Wall",o+Vector3.new(0,6,-3.5),Vector3.new(35,12,1),g) end
   if mode=="wall" then wall() end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="death" then task.wait(.05);b.humanoid.Health=0;API.Clear(b) end
   if mode=="dodge" then tr.Position+=Vector3.new(40,0,0) end
   if mode=="dynamicWall" then task.wait(.1);wall() end
   local c=cfg.poseidon[name];task.wait(c.duration+(if name=="wave_clash" then 1.2 else .5))
   local total=0;for _,hit in hits do total+=hit.amount end
   check(name.."/"..mode.." total="..total.." hits="..#hits,if mode=="hit" then #hits==1 and math.abs(total-c.damage)<.001 else #hits==0)
   if mode=="hit" then check(name.." motion restored",b.humanoid.WalkSpeed==cfg.walkSpeed and b.root.Anchored) end
   API.Clear(b);g:Destroy()
  end)
 end
end
for index,name in {[1]="wave_clash",[3]="torpedo"} do
 for _,mode in {"lowWall","overlap","wallInFlight","clearAfterRelease"} do
  run(name..mode,function()
   local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-16)
   local function wall(low,inside) return part("Wall",o+Vector3.new(0,if low then .8 else 6,if inside then 0 else -7),Vector3.new(35,if low then 1.6 else 12,1),g) end
   if mode=="lowWall" then wall(true,false) end
   if mode=="overlap" then wall(false,true) end
   API.Cast(b,index,tr.Position,false,hooks)
   if mode=="wallInFlight" then task.wait(.75);wall(false,false) end
   if mode=="clearAfterRelease" then task.wait(.75);API.Clear(b) end
   task.wait(3.4)
   check(name..mode.." no leaked contact",#hits==0)
   API.Clear(b);g:Destroy()
  end)
 end
end
run("wave survives next cast",function()
 local b,tr,hooks,hits,actions,g,o=fixture();tr.Position=o+Vector3.new(0,3,-25)
 API.Cast(b,1,tr.Position,false,hooks);task.wait(1.34);API.Melee(b,tr.Position,hooks);task.wait(1.2)
 check("wave has independent encounter lifetime",#hits==1 and hits[1].amount==19);API.Clear(b);g:Destroy()
end)
run("melee alternating",function()
 local b,tr,hooks,hits,actions,g=fixture()
 for i=1,2 do API.Melee(b,tr.Position,hooks);task.wait(1.15);check("swing"..i,#hits==i and hits[i].amount==12) end
 check("melee keeps special deadline",b.nextAbilityAt==0);API.Clear(b);g:Destroy()
end)
run("phase two targets and effect cleanup",function()
 local b,tr,hooks,hits,actions,g,o=fixture()
 local t2=Instance.new("Model");t2.Parent=g;local r2=part("HumanoidRootPart",o+Vector3.new(9,3,-7),Vector3.new(2,2,2),t2)
 local h2=Instance.new("Humanoid");h2.RequiresNeck=false;h2.Parent=t2
 local original=hooks.fighters;hooks.fighters=function() local list=original();table.insert(list,{player={Character=t2},root=r2,humanoid=h2});return list end
 API.Cast(b,2,tr.Position,true,hooks);task.wait(2)
 check("two distinct phase-two lightning targets",#hits==2 and hits[1].amount==19 and hits[2].amount==19)
 local effects=0;for _,d in workspace:GetDescendants() do if d.Name=="BossImpact" and (d.Position-o).Magnitude<50 then effects+=1 end end
 check("impact debris cleaned during living encounter",effects==0);API.Clear(b);g:Destroy()
end)
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks);check("awakening vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(3.4);check("awakening finishes",actions[1]=="awaken" and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
run("coincident melee facing",function()
 local b,tr,hooks,_,_,g=fixture();local Physics=require(game.ServerScriptService.Server.Services.BossPhysics)
 local before=b.root.CFrame
 for _,offset in {Vector3.zero,Vector3.new(0,12,0),Vector3.new(.001,0,.001)} do
  check("coincident target keeps rotation",not Physics.face(b.root,b.root.Position+offset) and b.root.CFrame==before)
 end
 check("separate target turns",Physics.face(b.root,b.root.Position+Vector3.new(4,1,4)))
 for _,v in {b.root.CFrame:GetComponents()} do assert(v==v and math.abs(v)<math.huge,"invalid rotation")end
 API.Clear(b);g:Destroy()
end)
run("physics ownership",function()
 local b,tr,hooks,_,_,g=fixture();b.root.Anchored=false;b.root:SetNetworkOwner(nil)
 API.Melee(b,tr.Position,hooks);task.wait(1.2)
 check("unanchored cast restores server ownership",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 API.Cast(b,3,tr.Position,false,hooks);task.wait(3.3)
 check("rush restores server ownership",not b.root.Anchored and b.root:GetNetworkOwner()==nil and not b.root:GetNetworkOwnershipAuto())
 API.Clear(b);g:Destroy()
end)
run("invalid root and displaced arena",function()
 local b,tr,hooks,_,_,g,o=fixture();local Cast=require(game.ServerScriptService.Server.Services.BossCast)
 local s=Cast.Begin(b,"test",.1,0,nil,hooks);b.root.Position=o+Vector3.new(5000,5,0)
 local goal=Cast.Destination(b,s,hooks,tr.Position,18)
 check("outside arena dash remains bounded",(goal-b.root.Position).Magnitude<=18.01)
 b.root.Parent=nil;local at,blocked=Cast.Destination(b,s,hooks,tr.Position,18)
 check("removed root cancels destination",blocked and at==b.root.Position)
 b.root:Destroy();Cast.Clear(b);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2) end
for _,b in active do API.Clear(b) end
folder:Destroy();result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS" else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
