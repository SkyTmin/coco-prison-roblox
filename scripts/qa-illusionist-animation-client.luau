--!nocheck
-- Actual client animation on disposable local rigs; always remove them and restore the camera.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local RS=game:GetService("RunService");local CS=game:GetService("CollectionService")
local Shared=game.ReplicatedStorage.Shared;local BlockRig=require(Shared.BlockRig)
local player=game.Players.LocalPlayer;local camera=workspace.CurrentCamera
local cf,kind=camera.CFrame,camera.CameraType
local model,rabbit;local checks={};local maxPosition,maxAngle=0,0
local function check(name,ok)assert(ok,name);table.insert(checks,name)end
local function compare(rig,clip,t,motors)
 local position,angle=0,0
 for joint in rig.clips[clip].tracks do
  local diff=BlockRig.sample(rig.clips[clip],joint,t):ToObjectSpace(motors[joint].Transform)
  local _,r=diff:ToAxisAngle();position=math.max(position,diff.Position.Magnitude);angle=math.max(angle,math.abs(r))
 end
 return position,angle
end
local ok,err=xpcall(function()
 player:RequestStreamAroundAsync(Vector3.new(7400,9005,-205),5)
 local source=workspace:FindFirstChild("Boss_illusionist");assert(source,"live Illusionist missing")
 model=source:Clone();CS:RemoveTag(model,"Boss");model.Name="QAIllusionistAnimation"
 model:SetAttribute("BossId","qa_illusionist");model.PrimaryPart.Anchored=true
 model:PivotTo(source:GetPivot()+Vector3.new(0,25,0));model.Parent=workspace;CS:AddTag(model,"Boss")
 local eye=model.PrimaryPart.Position+Vector3.new(13,6,19)
 camera.CameraType=Enum.CameraType.Scriptable
 RS:BindToRenderStep("QAIllusionistCamera",Enum.RenderPriority.Camera.Value+1,function()camera.CFrame=CFrame.lookAt(eye,model.PrimaryPart.Position)end)
 task.wait(.25)
 local prepared=BlockRig.prepare(require(Shared.Models.illusionist));local motors={}
 for _,m in model:GetDescendants()do if m:IsA("Motor6D")then motors[m.Name]=m end end
 for _,name in {"attack","attack2","attackdagger","attackcards","attackbox","summonrabbits","phasecards","regeneration","active","hurt","jump","death"}do
  local clip=prepared.clips[name];local t=if name=="death"then clip.length else clip.length*.55
  model:SetAttribute("Action",name);model:SetAttribute("ActionLen",10000)
  model:SetAttribute("ActionAt",workspace:GetServerTimeNow()-t/clip.length*10000)
  task.wait(.2);RS.PostSimulation:Wait()
  local at=math.min(clip.length,(workspace:GetServerTimeNow()-model:GetAttribute("ActionAt"))/10000*clip.length)
  local p,a=compare(prepared,name,at,motors)
  maxPosition,maxAngle=math.max(maxPosition,p),math.max(maxAngle,a)
  check(name.." actual joints",p<.03 and a<.025)
 end
 rabbit=Instance.new("Model");rabbit.Name="QAIllusionistRabbit"
 local root=Instance.new("Part");root.Name,root.Anchored,root.CFrame,root.Parent="HumanoidRootPart",true,model.PrimaryPart.CFrame*CFrame.new(4,0,0),rabbit
 BlockRig.build(require(Shared.Models.illusionist_rabbit),rabbit,root,root.CFrame)
 local h=Instance.new("Humanoid");h.RequiresNeck,h.BreakJointsOnDeath,h.Parent=false,false,rabbit
 rabbit.PrimaryPart=root;rabbit:SetAttribute("MobId","illusionist_rabbit");rabbit.Parent=workspace;CS:AddTag(rabbit,"Mob")
 local rm={};for _,m in rabbit:GetDescendants()do if m:IsA("Motor6D")then rm[m.Name]=m end end
 local rr=BlockRig.prepare(require(Shared.Models.illusionist_rabbit))
 rabbit:SetAttribute("MobWindup",workspace:GetServerTimeNow()-.8)
 task.wait(.3);RS.PostSimulation:Wait()
 local p,a=compare(rr,"bite",workspace:GetServerTimeNow()-rabbit:GetAttribute("MobWindup"),rm)
 check("rabbit explosion warning actual joints",p<.1 and a<.1)
 h.Health=0;task.wait(3.7);RS.PostSimulation:Wait()
 p,a=compare(rr,"death",3.5,rm)
 check("rabbit articulated final death",p<.03 and a<.025)
end,debug.traceback)
RS:UnbindFromRenderStep("QAIllusionistCamera");camera.CameraType,camera.CFrame=kind,cf
if model then model:Destroy()end
if rabbit then rabbit:Destroy()end
return game.HttpService:JSONEncode({status=if ok then "PASS"else "FAIL",checks=#checks,error=if ok then nil else err,maxPosition=maxPosition,maxAngleDegrees=math.deg(maxAngle)})
