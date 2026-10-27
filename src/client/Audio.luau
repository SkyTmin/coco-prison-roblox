--!strict
-- The game's volume on this device [владелец 27.10: «в настройки … уменьшить звук, выключить»]: one "Master"
-- SoundGroup in SoundService; every sound without a group of its own goes into it (ours from Sfx / Footsteps,
-- the map's, Roblox's character sounds) and our own groups (BlockBreak's "Blocks") nest under it, so its volume
-- scales everything. Set from the profile's settings (SettingsWindow).

local SoundService = game:GetService("SoundService")

local Audio = {}

local master: SoundGroup? = nil

local function adopt(instance: Instance)
	local group = master
	if not group then
		return
	end
	if instance:IsA("Sound") then
		if instance.SoundGroup == nil then
			instance.SoundGroup = group
		end
	elseif instance:IsA("SoundGroup") and instance ~= group then
		task.defer(function() -- not while it is being parented
			if instance.Parent == SoundService then
				instance.Parent = group -- a nested group: its volume × the master's
			end
		end)
	end
end

function Audio.Start()
	local group = Instance.new("SoundGroup")
	group.Name = "Master"
	group.Volume = 1
	group.Parent = SoundService
	master = group
	-- where sounds live (game:GetDescendants would reach the locked core services)
	local roots: { Instance } = { workspace, SoundService, game:GetService("ReplicatedStorage") }
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		table.insert(roots, playerGui)
	end
	for _, root in ipairs(roots) do
		for _, instance in ipairs(root:GetDescendants()) do
			adopt(instance)
		end
		root.DescendantAdded:Connect(adopt)
	end
end

-- volume 0..1; muted silences everything without losing the volume
function Audio.set(volume: number, muted: boolean)
	if master then
		master.Volume = if muted then 0 else math.clamp(volume, 0, 1)
	end
end

return Audio
