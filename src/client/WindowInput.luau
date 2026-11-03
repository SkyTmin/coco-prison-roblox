--!strict
-- Menus own the pointer and suspend movement even in Roblox's locked first-person camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local WindowInput = {}

-- All gameplay intents share this gate; pointer/movement ownership alone does not stop remotes.
function WindowInput.GameplayBlocked(windowOpen: boolean): boolean
	if
		windowOpen
		or Players.LocalPlayer:GetAttribute("LoadingBlocked") == true
		or require(script.Parent.HudLayout).isEditing()
		or UserInputService:GetFocusedTextBox()
	then
		return true
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health <= 0
end

function WindowInput.Start(isOpen: () -> boolean)
	local player = Players.LocalPlayer
	local controls: any = nil
	local blocked = false
	local savedCamera: Camera? = nil
	local savedType = Enum.CameraType.Custom
	local savedMouseIcon = true
	task.spawn(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
		controls = (require(module :: ModuleScript) :: any):GetControls()
		if blocked then
			controls:Disable()
		end
	end)
	RunService:BindToRenderStep(
		"PrisonWindowInput",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			local open = isOpen() or player:GetAttribute("LoadingBlocked") == true
			if open ~= blocked then
				blocked = open
				if open then
					savedMouseIcon = UserInputService.MouseIconEnabled
					if controls then
						controls:Disable()
					end
				else
					if controls then
						controls:Enable()
					end
					if savedCamera and savedCamera.Parent then
						savedCamera.CameraType = savedType
						local character = player.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if savedType == Enum.CameraType.Custom and humanoid then
							savedCamera.CameraSubject = humanoid
						end
					end
					savedCamera = nil
					UserInputService.MouseIconEnabled = savedMouseIcon
				end
			end
			if not open then
				return
			end
			local camera = workspace.CurrentCamera
			if camera and camera ~= savedCamera then
				savedCamera, savedType = camera, camera.CameraType
			end
			if camera then
				camera.CameraType = Enum.CameraType.Scriptable
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			player:Move(Vector3.zero)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Jump = false
			end
		end
	)
end

return WindowInput
