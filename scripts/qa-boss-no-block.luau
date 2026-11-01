--!nocheck
-- Synthetic targets only. No player profile, health, rewards, or world boss HP is changed.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local CS=game:GetService("CollectionService")
local Shared=game.ReplicatedStorage.Shared
local Services=game.ServerScriptService.Server.Services
local Combat=require(Services.CombatService)
local Hurt=require(Services.HurtService)
local Config=require(Shared.Config)
local player=game.Players:GetPlayers()[1]
assert(player,"a play client is needed for HitConfirm")
local count=0
local function check(ok,label) assert(ok,label);count+=1 end
local fixtures={}
local function target(boss)
 local m=Instance.new("Model");m.Name="QANoBossBlock"
 local r=Instance.new("Part");r.Name,r.Anchored,r.Position,r.Parent="HumanoidRootPart",true,Vector3.new(45000,30000,0),m
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath=false,false;h.MaxHealth,h.Health,h.Parent=100,100,m
 m.PrimaryPart=r;m.Parent=workspace;table.insert(fixtures,m)
 if boss then CS:AddTag(m,"Boss") end
 m:SetAttribute("Shielded",true)
 local ff=Instance.new("ForceField");ff.Visible=false;ff.Parent=m
 return m,h
end
local ok,err=xpcall(function()
 for _,card in Config.bosses.bosses do
  local id=card.id
  local m,h=target(true);m:SetAttribute("BossId",id)
  check(Combat.ApplyDamage(h,7,"mob") and h.Health==93,id.." damage during stale shield/ForceField")
  Hurt.Damage(h,3);check(h.Health==90,id.." direct/book damage")
  m:Destroy()
 end
 local m,h=target(false)
 check(not Combat.ApplyDamage(h,7,"mob") and h.Health==100,"non-boss ForceField preserved")
 Hurt.Damage(h,3);check(h.Health==100,"non-boss direct protection preserved");m:Destroy()
 m,h=target(true)
 local profile={inventory={},selectedSlot=1}
 local args={prepared=true,sweep=true} -- bypass random books for this isolated hit-path check
 local result=Combat.HitModel(player,profile,m,7,false,Vector3.zAxis,nil,false,args)
 check(result=="hit" and h.Health==93,"player melee penetrates boss block")
 result=Combat.HitModel(player,profile,m,7,false,Vector3.zAxis,nil,false,args)
 check(result=="cooldown" and h.Health==93,"early repeat is cooldown, never Block")
 result=Combat.HitModel(player,profile,m,11,false,Vector3.zAxis,nil,false,args)
 check(result=="hit" and h.Health==89,"stronger hit adds difference during hurt window")
end,debug.traceback)
for _,m in fixtures do m:Destroy() end
assert(ok,err)
return game:GetService("HttpService"):JSONEncode({status="PASS",checks=count})
