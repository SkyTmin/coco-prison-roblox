--!nocheck
-- Distant disposable fixtures; no real boss/profile/reward changes.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.SkeletonAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local BlockRig=require(game.ReplicatedStorage.Shared.BlockRig)
local cfg
for _,c in Config.bosses.bosses do if c.id=="skeleton" then cfg=c.fight end end
assert(cfg and cfg.skeleton)
assert(not workspace:FindFirstChild("QASkeletonFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QASkeletonFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QASkeletonResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QASkeletonResult","running",game.ServerStorage
local checks,errors,active={},{},{};local remaining,number=0,0
local function part(name,at,size,parent)
	local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
	number+=1;local origin=Vector3.new(66000+number*500,30000,0)
	local g=Instance.new("Folder");g.Parent=folder
	part("Floor",origin-Vector3.new(0,1,0),Vector3.new(150,2,150),g)
	local m=Instance.new("Model");m.Parent=g
	local r=part("HumanoidRootPart",origin+Vector3.new(0,4.5,0),Vector3.new(4,5,3),m)
	local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=740,740,cfg.walkSpeed;h.Parent=m
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
for index,name in {"sklrstomp","sklpoisonbreath","skllstomp"} do
	for _,mode in {"hit","wall","lowWall","dynamicWall","death","dodge","deathAfterRelease"} do
		run(name..mode,function()
			local b,tr,hooks,hits,_,g,o,snares=fixture()
			local function wall(low)
				return part("Wall",o+Vector3.new(0,if low then .8 else 12,-3.5),Vector3.new(35,if low then 1.6 else 30,1),g)
			end
			if mode=="wall" or mode=="lowWall" then wall(mode=="lowWall") end
			API.Cast(b,index,tr.Position,false,hooks);check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
			if mode=="death" then task.wait(.1);b.humanoid.Health=0;API.Clear(b) end
			if mode=="dodge" then tr.Position+=Vector3.new(40,0,0) end
			if mode=="dynamicWall" then task.wait(.2);wall(false) end
			local before=0
			if mode=="deathAfterRelease" then task.wait(cfg.skeleton[name].release+.4);before=#hits;b.humanoid.Health=0;API.Clear(b) end
			task.wait(cfg.skeleton[name].release+cfg.skeleton[name].lifetime+.5)
			local total=0;for _,hit in hits do total+=hit.amount end
			check(name.." / "..mode.." total="..total.." contacts="..#hits,if mode=="hit" then math.abs(total-cfg.skeleton[name].damage)<.001 elseif mode=="deathAfterRelease" then #hits==before else #hits==0)
			if mode=="hit" then
				check(name.." movement restored",b.humanoid.WalkSpeed==cfg.walkSpeed and b.root.Anchored)
				if name=="sklpoisonbreath" then check("poison horizontal push",hits[1].lift==0 and hits[1].strength==.3)
				else check(name.." snare on contacts",#snares==cfg.skeleton[name].ticks) end
			end
			API.Clear(b);g:Destroy()
		end)
	end
end
run("wall during poison flight",function()
	local b,tr,hooks,hits,_,g,o=fixture();API.Cast(b,2,tr.Position,false,hooks)
	task.wait(cfg.skeleton.sklpoisonbreath.release+.1)
	part("NewWall",o+Vector3.new(0,12,-3.5),Vector3.new(35,30,1),g)
	task.wait(2);check("poison blocked by wall added in flight",#hits==0);API.Clear(b);g:Destroy()
end)
run("melee",function()
	local b,tr,hooks,hits,actions,g=fixture()
	API.Melee(b,tr.Position,hooks);task.wait(1.4);API.Melee(b,tr.Position,hooks);task.wait(1.4)
	check("alternate swipes",#hits==2 and hits[1].amount==8 and actions[1]=="atkrswipe" and actions[2]=="atklswipe")
	check("melee cannot starve special timer",b.nextAbilityAt==0)
	API.Clear(b);g:Destroy()
end)
run("melee wall",function()
	local b,tr,hooks,hits,_,g,o=fixture();part("Wall",o+Vector3.new(0,8,-3.5),Vector3.new(30,20,1),g)
	API.Melee(b,tr.Position,hooks);task.wait(1.4);check("swipe blocked by wall",#hits==0);API.Clear(b);g:Destroy()
end)
run("minions",function()
	local b,tr,hooks,hits,_,g=fixture();API.Cast(b,4,tr.Position,true,hooks);task.wait(2.65)
	local function nearby()
		local out={};for _,m in game:GetService("CollectionService"):GetTagged("Mob") do
			if m:GetAttribute("MobId")=="skeleton_minion" and m.PrimaryPart and (m.PrimaryPart.Position-b.root.Position).Magnitude<80 then table.insert(out,m) end
		end;return out
	end
	local minions=nearby();check("phase two summons three",#minions==3)
	check("summons have spawn clip timestamp",typeof(minions[1]:GetAttribute("MobSpawnAt"))=="number" and minions[1].PrimaryPart.Anchored)
	check("summons do not attack while emerging",#hits==0)
	-- Cast replacement must preserve the encounter-owned warriors and their lifecycle.
	API.Melee(b,tr.Position,hooks);check("minions survive next cast",minions[1].Parent~=nil)
	task.wait(3.1);check("summons restore movement after emergence",not minions[1].PrimaryPart.Anchored and math.abs(minions[1].Humanoid.WalkSpeed-cfg.skeleton.sklroar.speed)<.001)
	API.Cast(b,4,tr.Position,true,hooks);task.wait(2.7);check("minion count capped at four",#nearby()==4)
	b.humanoid.Health=0;API.Clear(b);check("minions cancelled at boss death",#nearby()==0)
	g:Destroy()
end)
run("hazard persists",function()
	local b,tr,hooks,hits,_,g=fixture();API.Cast(b,2,tr.Position,false,hooks);task.wait(2)
	local n=#hits;API.Melee(b,tr.Position+Vector3.new(40,0,0),hooks);task.wait(2)
	check("cloud survives another cast",#hits>n);API.Clear(b);local stopped=#hits;task.wait(1)
	check("cloud cancels on cleanup",#hits==stopped);g:Destroy()
end)
task.spawn(function()
	while remaining>0 do task.wait(.2) end
	for _,b in active do API.Clear(b) end;folder:Destroy()
	local d=BlockRig.prepare(require(game.ReplicatedStorage.Shared.Models.skeleton_king));local n=0;for _ in d.clips do n+=1 end
	if n~=12 then table.insert(errors,"expected 12 boss clips") end
	local m=BlockRig.prepare(require(game.ReplicatedStorage.Shared.Models.skeleton_minion));if not m.clips.spawn or m.clips.death.length~=2.5 then table.insert(errors,"missing minion lifecycle") end
	result.Value=game:GetService("HttpService"):JSONEncode({checks=#checks,errors=errors,status=if #errors==0 then "PASS" else "FAIL"})
end)
return "started "..remaining.." isolated cases"
