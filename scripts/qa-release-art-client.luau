--!nocheck
-- Disposable Play-mode reference camera. Set Scene before parenting to PlayerGui; destroy to restore.
assert(game.RunService:IsStudio() and game.RunService:IsClient())
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local oldType, oldCF, oldFov = camera.CameraType, camera.CFrame, camera.FieldOfView
local guis, labels, core = {}, {}, {}
for _, gui in player.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		guis[gui] = gui.Enabled
		gui.Enabled = false
	end
end
for _, kind in Enum.CoreGuiType:GetEnumItems() do
	if kind == Enum.CoreGuiType.All then
		continue
	end
	local ok, enabled = pcall(game.StarterGui.GetCoreGuiEnabled, game.StarterGui, kind)
	if ok then
		core[kind] = enabled
		game.StarterGui:SetCoreGuiEnabled(kind, false)
	end
end
for _, label in workspace:GetDescendants() do
	if label:IsA("BillboardGui") or label:IsA("SurfaceGui") then
		labels[label] = label.Enabled
		label.Enabled = false
	end
end
local scenes = {
	ghetto = { Vector3.new(11550, 15125, 4180), Vector3.new(11400, 15012, 4000), 52 },
	warzone = { Vector3.new(14610, 19710, 4250), Vector3.new(14400, 19510, 4000), 52 },
}
local centre = script:GetAttribute("Centre")
if typeof(centre) == "Vector3" then
	scenes.gang_base = {centre + Vector3.new(21, 13, 17), centre + Vector3.new(-10, 6, -15), 72}
end
local scene = scenes[script:GetAttribute("Scene")]
assert(scene, "unknown reference scene")
game.RunService:BindToRenderStep("QAReleaseArt", Enum.RenderPriority.Last.Value, function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(scene[1], scene[2])
	camera.FieldOfView = scene[3]
end)
script.Destroying:Connect(function()
	game.RunService:UnbindFromRenderStep("QAReleaseArt")
	camera.CameraType, camera.CFrame, camera.FieldOfView = oldType, oldCF, oldFov
	for gui, enabled in guis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	for label, enabled in labels do
		if label.Parent then
			label.Enabled = enabled
		end
	end
	for kind, enabled in core do
		game.StarterGui:SetCoreGuiEnabled(kind, enabled)
	end
end)
