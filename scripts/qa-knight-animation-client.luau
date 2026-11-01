--!nocheck
-- Actual client animators, local disposable rigs and restored camera; no server mutations.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local RS=game:GetService("RunService");local CS=game:GetService("CollectionService")
local Shared=game.ReplicatedStorage.Shared;local BlockRig=require(Shared.BlockRig)
local player=game.Players.LocalPlayer;local camera=workspace.CurrentCamera
local cf,kind=camera.CFrame,camera.CameraType
local model,warrior;local checks={};local maxPosition,maxAngle=0,0
local function check(name,ok) assert(ok,name);table.insert(checks,name) end
local ok,err=xpcall(function()
	player:RequestStreamAroundAsync(Vector3.new(5400,6004.5,-176),5)
	local source=workspace:FindFirstChild("Boss_knight");assert(source,"live Royal Garden knight missing")
	model=source:Clone();CS:RemoveTag(model,"Boss");model.Name="QAKnightAnimation"
	model:SetAttribute("BossId","qa_knight");model.PrimaryPart.Anchored=true
	model:PivotTo(source:GetPivot()+Vector3.new(0,25,0));model.Parent=workspace;CS:AddTag(model,"Boss")
	local eye=model.PrimaryPart.Position+Vector3.new(13,6,19)
	camera.CameraType=Enum.CameraType.Scriptable
	RS:BindToRenderStep("QAKnightAnimationCamera",Enum.RenderPriority.Camera.Value+1,function() camera.CFrame=CFrame.lookAt(eye,model.PrimaryPart.Position) end)
	task.wait(.25)
	local prepared=BlockRig.prepare(require(Shared.Models.royal_knight));local motors={}
	for _,m in model:GetDescendants() do if m:IsA("Motor6D") then motors[m.Name]=m end end
	for _,name in {"c1","c2","c3","c4","c5","dashfront","dashback","dashleft","dashright","berserkerleap","strikeoffury1","strikeoffury2","viciousstrike","bulwarkinstinct","relentlesswhirlwindpierce","startcombat","flinch","hurt","jump","death"} do
		local clip=prepared.clips[name];local t=if name=="death" then clip.length else clip.length*.55
		model:SetAttribute("Action",name);model:SetAttribute("ActionLen",10000)
		model:SetAttribute("ActionAt",workspace:GetServerTimeNow()-t/clip.length*10000)
		task.wait(.2);RS.PostSimulation:Wait()
		local at=math.min(clip.length,(workspace:GetServerTimeNow()-model:GetAttribute("ActionAt"))/10000*clip.length)
		local position,angle=0,0
		for joint in clip.tracks do
			local difference=BlockRig.sample(clip,joint,at):ToObjectSpace(motors[joint].Transform)
			local _,r=difference:ToAxisAngle();position=math.max(position,difference.Position.Magnitude);angle=math.max(angle,math.abs(r))
		end
		maxPosition,maxAngle=math.max(maxPosition,position),math.max(maxAngle,angle)
		check(name.." client plays exported joints",position<.03 and angle<.025)
	end
 model:SetAttribute("Action","bloodboundbarrier");model:SetAttribute("ActionLen",10000);model:SetAttribute("ActionAt",workspace:GetServerTimeNow()-1.1)
 task.wait(.2);RS.PostSimulation:Wait()
 local guard=BlockRig.sample(prepared.clips.bloodboundbarrier,"armL",.4):ToObjectSpace(motors.armL.Transform)
 local _,guardAngle=guard:ToAxisAngle();check("looping guard pose",math.abs(guardAngle)<.025)
 model:SetAttribute("Action","relentlesswhirlwindspin");model:SetAttribute("ActionLen",10000);model:SetAttribute("ActionAt",workspace:GetServerTimeNow()-.35)
 local maxSpin=0
 for i=1,20 do RS.PostSimulation:Wait();local _,r=motors.root.Transform:ToAxisAngle();maxSpin=math.max(maxSpin,math.abs(r)) end
 check("spin loops in real time, not stretched over ActionLen",maxSpin>.7)

end,debug.traceback)
RS:UnbindFromRenderStep("QAKnightAnimationCamera");camera.CameraType,camera.CFrame=kind,cf
if model then model:Destroy() end;if warrior then warrior:Destroy() end
return game.HttpService:JSONEncode({status=if ok then "PASS" else "FAIL",checks=#checks,error=if ok then nil else err,maxPosition=maxPosition,maxAngleDegrees=math.deg(maxAngle)})
