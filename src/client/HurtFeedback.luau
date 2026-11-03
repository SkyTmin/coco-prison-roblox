--!strict
-- One accepted server impact drives local health display, sound, direction and physical impulse.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Knockback = require(Shared.Knockback)
local player = Players.LocalPlayer
local changed, impact = Instance.new("BindableEvent"), Instance.new("BindableEvent")
local Feedback = { Changed = changed.Event, Impact = impact.Event }
local started, lastId = false, 0
local pending: any = nil
local source: Vector3? = nil
local sourceUntil = 0

function Feedback.Health(humanoid: Humanoid?): (number, number, number)
	if not humanoid then
		return 0, 20, 0
	end
	local character = humanoid.Parent
	local golden = character and character:GetAttribute("AbsorptionHealth")
	local absorbed = if typeof(golden) == "number" then math.max(0, golden) else 0
	if pending and pending.character == character then
		if
			os.clock() > pending.expires
			or (
				math.abs(humanoid.Health - pending.health) < 0.001
				and math.abs(absorbed - pending.golden) < 0.001
			)
		then
			pending = nil
		else
			return pending.health, pending.maxHealth, pending.golden
		end
	end
	return humanoid.Health, humanoid.MaxHealth, absorbed
end

local function push(velocity: any)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or not Knockback.finite(velocity)
	then
		return
	end
	root.AssemblyLinearVelocity = Knockback.velocity(
		root.AssemblyLinearVelocity,
		velocity,
		humanoid.FloorMaterial ~= Enum.Material.Air
	)
end

function Feedback.Start(gui: ScreenGui)
	if started then
		return
	end
	started = true
	local marker = Instance.new("TextLabel")
	marker.Name = "IncomingHitDirection"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.fromOffset(26, 26)
	marker.BackgroundTransparency = 1
	marker.Text, marker.Font, marker.TextSize = "▲", Enum.Font.GothamBold, 24
	marker.TextColor3 = Color3.fromRGB(255, 65, 65)
	marker.TextStrokeColor3, marker.TextStrokeTransparency = Color3.new(), 0
	marker.ZIndex, marker.Visible, marker.Parent = 8, false, gui
	Remotes.event("HurtImpact").OnClientEvent:Connect(function(packet: any)
		if
			typeof(packet) ~= "table"
			or packet.character ~= player.Character
			or typeof(packet.id) ~= "number"
			or packet.id <= lastId
		then
			return
		end
		lastId = packet.id
		pending = {
			character = packet.character,
			health = packet.health,
			maxHealth = packet.maxHealth,
			golden = packet.golden,
			expires = os.clock() + 0.75,
		}
		if Knockback.finite(packet.push) then
			push(packet.push)
		end
		source = if Knockback.finite(packet.from) then packet.from else nil
		sourceUntil = os.clock() + 0.5
		Sfx.play(packet.sound or "player_hurt", nil, packet.volume or 0.7, packet.pitch or 1)
		impact:Fire(packet)
		changed:Fire()
		task.delay(0.76, function()
			changed:Fire()
		end)
	end)
	-- Books may add a separate impulse after the primary hit; do not replay its damage/sound.
	Remotes.event("Knockback").OnClientEvent:Connect(push)
	player.CharacterAdded:Connect(function()
		pending = nil
		source = nil
		changed:Fire()
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		marker.Visible = source ~= nil
			and os.clock() < sourceUntil
			and camera ~= nil
			and root ~= nil
		if
			not marker.Visible
			or not camera
			or not root
			or not root:IsA("BasePart")
			or not source
		then
			return
		end
		local offset = source - root.Position
		local x, z = offset:Dot(camera.CFrame.RightVector), -offset:Dot(camera.CFrame.LookVector)
		local direction = Vector2.new(x, z)
		if direction.Magnitude < 0.01 then
			direction = Vector2.new(0, -1)
		else
			direction = direction.Unit
		end
		marker.Position = UDim2.new(0.5, direction.X * 72, 0.5, direction.Y * 72)
		marker.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
		marker.TextTransparency = math.clamp(1 - (sourceUntil - os.clock()) / 0.18, 0, 1)
		marker.TextStrokeTransparency = marker.TextTransparency
	end)
end

return Feedback
