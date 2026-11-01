--!nocheck
-- Distant disposable fixtures; no real boss/profile/reward changes.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.KnightAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local BlockRig=require(game.ReplicatedStorage.Shared.BlockRig)
local cfg
for _,c in Config.bosses.bosses do if c.id=="knight" then cfg=c.fight end end
assert(cfg and cfg.knight)
assert(not workspace:FindFirstChild("QAKnightFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAKnightFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAKnightResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAKnightResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
	local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
	number+=1;local origin=Vector3.new(76000+number*500,30000,0)
	local g=Instance.new("Folder");g.Parent=folder
	part("Floor",origin-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
	local m=Instance.new("Model");m.Parent=g
	local r=part("HumanoidRootPart",origin+Vector3.new(0,4.5,0),Vector3.new(4,5,3),m)
	local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=920,920,cfg.walkSpeed;h.Parent=m
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
for index,name in {[1]="berserkerleap",[2]="strikeoffury1",[3]="relentlesswhirlwindspin",[4]="bloodboundbarrier",[6]="strikeoffury2",[7]="viciousstrike"} do
 for _,mode in {"hit","wall","death","dodge","dynamicWall"} do
  run(name..mode,function()
   local b,tr,hooks,hits,actions,g,o=fixture()
   local function wall() return part("Wall",o+Vector3.new(0,6,-3.5),Vector3.new(35,12,1),g) end
   if mode=="wall" then wall() end
   API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
   if mode=="death" then task.wait(.05);b.humanoid.Health=0;API.Clear(b) end
   if mode=="dodge" then tr.Position+=Vector3.new(40,0,0) end
   if mode=="dynamicWall" then task.wait(.1);wall() end
   local c=cfg.knight[name];task.wait(c.duration+(c.pierceDuration or 0)+.4)
   local total=0;for _,hit in hits do total+=hit.amount end
   local expected=c.damage+(c.pierceDamage or 0)
   check(name.."/"..mode.." total="..total,if mode=="hit" then math.abs(total-expected)<.001 else #hits==0)
   if mode=="hit" then check(name.." motion restored",b.humanoid.WalkSpeed==cfg.walkSpeed and b.root.Anchored) end
   check(name.." inside arena",((b.root.Position-b.spawn.Position)*Vector3.new(1,0,1)).Magnitude<60)
   API.Clear(b);g:Destroy()
  end)
 end
end
run("melee chain",function()
 local b,tr,hooks,hits,actions,g=fixture()
 for i,c in cfg.knight.melee do API.Melee(b,tr.Position,hooks);task.wait(c.duration+.1);check("c"..i.." contact",#hits==i and actions[i]=="c"..i) end
 check("melee does not postpone specials",b.nextAbilityAt==0);API.Clear(b);g:Destroy()
end)
for direction=1,4 do
 for _,mode in {"clear","wall","overlap","dynamicWall","death"} do
  run("dash"..direction..mode,function()
   local b,tr,hooks,hits,actions,g,o=fixture();b.knightDash=direction-1
   local dirs={Vector3.new(0,0,-1),Vector3.new(-1,0,0),Vector3.new(1,0,0),Vector3.new(0,0,1)}
   local d=dirs[direction]
   local function wall(overlap) return part("Wall",o+d*(if overlap then 0 else 4)+Vector3.new(0,5,0),Vector3.new(2,10,2),g) end
   if mode=="wall" or mode=="overlap" then wall(mode=="overlap") end
   API.Cast(b,5,tr.Position,false,hooks)
   if mode=="dynamicWall" then task.wait(.2);wall(false) end
   if mode=="death" then task.wait(.08);b.humanoid.Health=0;API.Clear(b) end
   task.wait(3.5)
   local delta=(b.root.Position-(o+Vector3.new(0,4.5,0)))*Vector3.new(1,0,1)
   check("dash"..direction..mode.." movement="..delta.Magnitude,if mode=="clear" then math.abs(delta:Dot(d)-7)<.02 else delta.Magnitude<4)
   check("dash never contact damage",#hits==0)
   if mode=="wall" or mode=="overlap" or mode=="dynamicWall" then check("wall flinch",table.find(actions,"flinch")~=nil) end
   API.Clear(b);g:Destroy()
  end)
 end
end
run("spawn",function()
 local b,_,hooks,_,actions,g=fixture();API.Spawn(b,hooks)
 check("spawn vulnerable",b.model:GetAttribute("Shielded")==false)
 task.wait(1.7);check("opening salute finishes",actions[1]=="startcombat" and b.humanoid.WalkSpeed==cfg.walkSpeed);API.Clear(b);g:Destroy()
end)
while remaining>0 do task.wait(.2) end
for _,b in active do API.Clear(b) end
folder:Destroy()
result.Value=game.HttpService:JSONEncode({status=if #errors==0 then "PASS" else "FAIL",checks=#checks,cases=number,errors=errors})
return result.Value
