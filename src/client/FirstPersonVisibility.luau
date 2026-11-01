--!strict
-- Scriptable menu cameras bypass Roblox's normal first-person transparency updates.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local FirstPersonVisibility = {}
local started = false

function FirstPersonVisibility.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local current: Model? = nil
	local parts: { [Instance]: boolean } = {}
	local modifiers: { [Instance]: number } = {}
	local enabled: { [Instance]: boolean } = {}
	local added: RBXScriptConnection? = nil
	local removed: RBXScriptConnection? = nil
	local function restore()
		for object, value in modifiers do
			if object.Parent then
				(object :: any).LocalTransparencyModifier = value
			end
		end
		for object, value in enabled do
			if object.Parent then
				(object :: any).Enabled = value
			end
		end
		table.clear(modifiers)
		table.clear(enabled)
	end
	local function track(object: Instance)
		if
			object:IsA("BasePart")
			or object:IsA("Decal")
			or object:IsA("BillboardGui")
			or object:IsA("Highlight")
		then
			parts[object] = true
		end
	end
	local function bind(character: Model?)
		restore()
		if added then
			added:Disconnect()
		end
		if removed then
			removed:Disconnect()
		end
		table.clear(parts)
		current = character
		if not character then
			return
		end
		for _, object in character:GetDescendants() do
			track(object)
		end
		added = character.DescendantAdded:Connect(track)
		removed = character.DescendantRemoving:Connect(function(object)
			parts[object], modifiers[object], enabled[object] = nil, nil, nil
		end)
	end
	RunService:BindToRenderStep(
		"PrisonFirstPersonVisibility",
		Enum.RenderPriority.Camera.Value + 3,
		function()
			if current ~= player.Character then
				bind(player.Character)
			end
			local camera = workspace.CurrentCamera
			local humanoid = current and current:FindFirstChildOfClass("Humanoid")
			local first = camera ~= nil
				and humanoid ~= nil
				and humanoid.Health > 0
				and (
					player.CameraMode == Enum.CameraMode.LockFirstPerson
					or (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1.5
				)
			if not first then
				restore()
				return
			end
			for object in parts do
				if object:IsA("BasePart") or object:IsA("Decal") then
					if modifiers[object] == nil then
						-- A value of 1 may already belong to Roblox's first-person camera; release it on exit.
						modifiers[object] = if object.LocalTransparencyModifier == 1
							then 0
							else object.LocalTransparencyModifier
					end
					if object.LocalTransparencyModifier ~= 1 then
						object.LocalTransparencyModifier = 1
					end
				else
					if enabled[object] == nil then
						enabled[object] = (object :: any).Enabled
					end
					(object :: any).Enabled = false
				end
			end
		end
	)
end

return FirstPersonVisibility
