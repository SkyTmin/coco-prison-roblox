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
	local followedCamera: Camera? = nil
	local followedHumanoid: Humanoid? = nil
	local followOnRelease = true
	local function releaseCamera()
		local camera = savedCamera
		savedCamera = nil
		if camera then
			camera.CameraType = savedType
		end
	end
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
			local loading = player:GetAttribute("LoadingBlocked") == true
			local open = isOpen() or loading
			local changed = open ~= blocked
			local camera = workspace.CurrentCamera
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if loading then
				followOnRelease = true
			end
			if changed then
				blocked = open
				if open then
					savedMouseIcon = UserInputService.MouseIconEnabled
				else
					UserInputService.MouseIconEnabled = savedMouseIcon
				end
			end
			if open then
				if camera ~= savedCamera then
					-- Release A before freezing B, so an A → B → A swap can't save our own Scriptable.
					releaseCamera()
					if camera then
						savedCamera, savedType = camera, camera.CameraType
					end
				end
				if camera then
					camera.CameraType = Enum.CameraType.Scriptable
				end
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
				if humanoid then
					player:Move(Vector3.zero)
					humanoid.Jump = false
				end
			else
				local restoreFollow = savedCamera == camera and savedType == Enum.CameraType.Custom
				releaseCamera()
				if
					camera
					and humanoid
					and (
						followOnRelease
						or restoreFollow
						or camera ~= followedCamera
						or humanoid ~= followedHumanoid
					)
				then
					camera.CameraSubject = humanoid
					camera.CameraType = Enum.CameraType.Custom
					followedCamera, followedHumanoid = camera, humanoid
					followOnRelease = false
				elseif not camera or not humanoid then
					followOnRelease = true
				end
			end
			-- Restore pointer and camera before enabling PlayerModule controls.
			if changed and controls then
				if open then
					controls:Disable()
				else
					controls:Enable()
				end
			end
		end
	)
end

return WindowInput
