--!nocheck
-- Server tests with synthetic Humanoids only; no players' health, inventories, rewards or PvP state changed.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local C=require(game.ReplicatedStorage.Shared.Combat)
local I=require(game.ServerScriptService.Server.Services.DamageImmunity)
local Service=require(game.ServerScriptService.Server.Services.CombatService)
local checks=0
local function check(ok,name) assert(ok,name);checks+=1 end
local function near(a,b) return math.abs(a-b)<1e-6 end
check(near(C.duration("sword",15),.625),"sword recharge")
check(near(C.duration("pickaxe",15),1/1.2),"pickaxe recharge")
check(near(C.duration("axe",1),1.25) and near(C.duration("axe",13),1),"axes by material")
check(C.charge(2,.625)==1 and near(C.charge(0,.625),.04),"charge half-tick and clamp")
check(near(C.meleeDamage(7,4.5,1,false),11.5),"ordinary diamond + Sharpness VIII")
check(near(C.meleeDamage(7,4.5,1,true),15),"crit before enchant, not 17.25")
check(near(C.meleeDamage(7,4.5,.5,false),5.05),"weak half charge scales enchant linearly")
check(near(C.meleeDamage(10,4.5,1,true),19.5),"Strength before crit")
check(near(C.meleeDamage(3,4.5,1,true),9),"Weakness before crit")
check(not C.canCrit(.9,true,false,false) and C.canCrit(.901,true,false,false),"critical charge threshold")
check(not C.canCrit(1,false,false,false),"ascending jump is not crit")
check(not C.canCrit(1,true,true,false),"grounded is not crit")
check(not C.canCrit(1,true,false,true),"water/ladder/sprint/blindness restrict crit")
local h=Instance.new("Humanoid")
check(I.Accept(h,7,nil,0)==7,"first hit")
check(I.Accept(h,7,nil,.1)==0 and I.Accept(h,3,nil,.2)==0,"equal/weaker ignored")
check(I.Accept(h,12,nil,.3)==5,"stronger only raw difference")
check(I.Accept(h,13,nil,.49)==1,"successive maximum increases")
check(I.Accept(h,7,nil,.501)==7,"stronger hit did not extend immunity")
h:Destroy();h=Instance.new("Humanoid")
check(I.Accept(h,7,101,0)==7 and I.Accept(h,7,102,0)==7,"raid participants both contribute")
check(I.Accept(h,7,101,.1)==0 and I.Accept(h,12,101,.2)==5,"raid per-attacker protection")
check(I.Accept(h,0,101,1)==0 and I.Accept(h,0/0,101,1)==0,"invalid damage ignored")
h:Destroy()
local m=Instance.new("Model");m.Name="QAJavaCombatTarget"
local root=Instance.new("Part");root.Name,root.Anchored,root.Position,root.Parent="HumanoidRootPart",true,Vector3.new(45000,30000,0),m
h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.Parent=100,100,m;m.Parent=workspace
local ok,err=pcall(function()
	Service.ApplyDamage(h,7,"mob")
	check(h.Health==93,"ApplyDamage integrates immunity")
	Service.ApplyDamage(h,7,"mob")
	check(h.Health==93,"real duplicate damage blocked")
	Service.ApplyDamage(h,12,"mob")
	check(h.Health==88,"real stronger difference applied")
end)
m:Destroy();assert(ok,err)
local result=game.ServerStorage:FindFirstChild("QAJavaCombatResult") or Instance.new("StringValue")
result.Name,result.Value,result.Parent="QAJavaCombatResult",game:GetService("HttpService"):JSONEncode({checks=checks,status="PASS"}),game.ServerStorage
return result.Value
