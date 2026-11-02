--!nocheck
-- Eight-second camera-only view; restores UI/camera automatically, never edits a live rig.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local player=game.Players.LocalPlayer;local camera=workspace.CurrentCamera
local original,kind=camera.CFrame,camera.CameraType
local boss=workspace:FindFirstChild("Boss_un_king");assert(boss and boss.PrimaryPart,"stream the king first")
local root=boss.PrimaryPart;local ui={}
for _,g in player.PlayerGui:GetChildren()do if g:IsA("ScreenGui")then ui[g]=g.Enabled;g.Enabled=false end end
camera.CameraType=Enum.CameraType.Scriptable
game.RunService:BindToRenderStep("UndeadReviewCamera",Enum.RenderPriority.Last.Value,function()
 if root.Parent then
  local target=root.Position+Vector3.new(0,1,0)
  local eye=root.CFrame:PointToWorldSpace(Vector3.new(8,5,-14))
  camera.CFrame=CFrame.lookAt(eye,target)
 end
end)
task.delay(8,function()
 game.RunService:UnbindFromRenderStep("UndeadReviewCamera")
 camera.CameraType,camera.CFrame=kind,original
 for g,enabled in ui do if g.Parent then g.Enabled=enabled end end
end)
return "Eight-second king review camera active"
