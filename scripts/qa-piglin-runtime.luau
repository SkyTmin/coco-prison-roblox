--!nocheck
-- Isolated live service fixtures, no profiles/rewards/map edits. Starts asynchronously; read Result.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API=require(game.ServerScriptService.Server.Services.PiglinAbilities)
local Config=require(game.ReplicatedStorage.Shared.Config)
local BlockRig=require(game.ReplicatedStorage.Shared.BlockRig)
local cfg
for _,c in Config.bosses.bosses do if c.id=="piglin" then cfg=c.fight end end
assert(cfg and cfg.piglin)
assert(not workspace:FindFirstChild("QAPiglinFixtures"))
local folder=Instance.new("Folder");folder.Name,folder.Parent="QAPiglinFixtures",workspace
local result=game.ServerStorage:FindFirstChild("QAPiglinResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAPiglinResult","running",game.ServerStorage
local checks,errors,active={},{},{}
local remaining,number=0,0
local function part(name,at,size,parent)
	local p=Instance.new("Part");p.Name,p.Position,p.Size,p.Anchored,p.Parent=name,at,size,true,parent;return p
end
local function fixture()
	number+=1
	local origin=Vector3.new(48000+number*500,30000,0)
	local group=Instance.new("Folder");group.Parent=folder
	part("Floor",origin-Vector3.new(0,1,0),Vector3.new(150,2,150),group)
	local m=Instance.new("Model");m.Parent=group
	local r=part("HumanoidRootPart",origin+Vector3.new(0,4.5,0),Vector3.new(4,5,3),m)
	local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.WalkSpeed=580,400,cfg.walkSpeed;h.Parent=m
	local spawn=part("Spawn",origin-Vector3.new(0,.5,0),Vector3.one,group);spawn.CanCollide,spawn.CanQuery=false,false
	local target=Instance.new("Model");target.Parent=group
	local tr=part("HumanoidRootPart",origin+Vector3.new(0,3,-5),Vector3.new(2,2,2),target)
	local th=Instance.new("Humanoid");th.RequiresNeck=false;th.Parent=target
	local fighter={player={Character=target},root=tr,humanoid=th}
	local state=Instance.new("Folder");state.Parent=group
	local boss={root=r,model=m,humanoid=h,spawn=spawn,state=state,fight=cfg,arenaRadius=60,busyUntil=0,nextAbilityAt=0}
	table.insert(active,boss)
	local hits,actions={},{}
	local hooks={fighters=function() return {fighter} end,hurt=function(_,_,amount) table.insert(hits,amount) end,
		act=function(_,name) table.insert(actions,name);m:SetAttribute("Action",name) end,
		telegraph=function(size,cf) local p=part("Mark",cf.Position,size,group);p.CFrame=cf;p.CanCollide,p.CanQuery=false,false;return p end}
	return boss,tr,hooks,hits,actions,group,origin
end
local function check(name,ok) assert(ok,name);table.insert(checks,name) end
local function run(name,fn)
	remaining+=1
	task.spawn(function()
		local ok,err=xpcall(fn,debug.traceback)
		if not ok then table.insert(errors,name..": "..tostring(err)) end
		remaining-=1
	end)
end
local names={"footstomp","upchuck","summoningchant","charge","healing","spinslam","bodyslam"}
for index,name in names do
	if name~="healing" and name~="summoningchant" then
		for _,mode in {"hit","wall","death","dodge"} do
			run(name..mode,function()
				local b,tr,hooks,hits,_,g,o=fixture()
				if name=="charge" or name=="upchuck" then tr.Position=o+Vector3.new(0,3,-18) end
				if mode=="wall" then part("Wall",o+Vector3.new(0,18,if name=="charge" or name=="upchuck" then -9 else -2.5),Vector3.new(40,40,1),g) end
				API.Cast(b,index,tr.Position,false,hooks)
				check(name.." vulnerable",b.model:GetAttribute("Shielded")==false)
				if mode=="death" then task.wait(.1);b.humanoid.Health=0;API.Clear(b) end
				if mode=="dodge" then tr.Position+=Vector3.new(40,0,0) end
				task.wait(cfg.piglin[name].duration+.15)
				check(name.." / "..mode,if mode=="hit" then #hits>0 else #hits==0)
				if mode~="death" then check(name.." movement restored",b.humanoid.WalkSpeed==cfg.walkSpeed and b.root.Anchored) end
				if name=="charge" and mode=="wall" then check("charge wall collision",b.root.Position.Z>o.Z-7) end
				API.Clear(b);g:Destroy()
			end)
		end
	end
end
run("melee alternates",function()
	local b,tr,hooks,hits,actions,g=fixture()
	API.Melee(b,tr.Position,hooks);task.wait(3.2)
	API.Melee(b,tr.Position,hooks);task.wait(3.2)
	check("axe alternate two contacts",#hits==2 and actions[1]=="verticalatk" and actions[2]=="horizontalatk")
	check("melee cannot postpone abilities indefinitely",b.nextAbilityAt==0)
	API.Clear(b);g:Destroy()
end)
for _,interrupt in {false,true} do
	run("healing",function()
		local b,tr,hooks,_,actions,g=fixture();API.Cast(b,5,tr.Position,false,hooks)
		if interrupt then task.wait(.4);b.humanoid.Health-=60 end
		task.wait(4)
		check("healing interrupt "..tostring(interrupt),if interrupt then b.humanoid.Health==340 and actions[#actions]=="hurt" else b.humanoid.Health==458)
		API.Clear(b);g:Destroy()
	end)
end
run("summons",function()
	local b,tr,hooks,_,_,g=fixture();API.Cast(b,3,tr.Position,true,hooks);task.wait(3)
	local guards={}
	for _,m in game:GetService("CollectionService"):GetTagged("Mob") do
		if m:GetAttribute("MobId")=="piglin_guard" and m.PrimaryPart and (m.PrimaryPart.Position-b.root.Position).Magnitude<80 then table.insert(guards,m) end
	end
	check("three guards in phase two",#guards==3)
	task.wait(1.2);API.Melee(b,tr.Position,hooks)
	check("guards survive next cast",guards[1].Parent~=nil)
	b.humanoid.Health=0;API.Clear(b)
	check("all guards cancelled at death",guards[1].Parent==nil and guards[2].Parent==nil and guards[3].Parent==nil)
	g:Destroy()
end)
task.spawn(function()
	while remaining>0 do task.wait(.2) end
	for _,b in active do API.Clear(b) end
	folder:Destroy()
	local d=BlockRig.prepare(require(game.ReplicatedStorage.Shared.Models.piglin_king))
	local n=0;for _ in d.clips do n+=1 end
	if n~=16 then table.insert(errors,"expected 16 clips") end
	result.Value=game:GetService("HttpService"):JSONEncode({checks=#checks,errors=errors,status=if #errors==0 then "PASS" else "FAIL"})
end)
return "started "..remaining.." isolated cases"
