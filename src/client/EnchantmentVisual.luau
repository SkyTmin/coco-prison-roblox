--!strict
-- Surface colour/runes only: no emissive material, lights, Highlight or bloom.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Truth = require(Shared.ItemEnchantment)
local Visual = {}
local PURPLE, CYAN = Color3.fromRGB(180, 115, 245), Color3.fromRGB(105, 205, 225)
local slots: { [ImageLabel]: any } = {}
local models: { [Instance]: any } = {}
local animation: RBXScriptConnection? = nil

function Visual.slot(image: ImageLabel, stack: any)
	local entry = slots[image]
	if not Truth.active(stack) then
		if entry then
			entry.connection:Disconnect()
			entry.tween:Cancel()
			entry.overlay:Destroy()
			entry.badge:Destroy()
			slots[image] = nil
		end
		return
	end
	if not entry then
		local overlay = Instance.new("ImageLabel")
		overlay.Name, overlay.BackgroundTransparency, overlay.ImageTransparency =
			"EnchantGlint", 1, 0.3
		overlay.Size, overlay.Position, overlay.AnchorPoint =
			UDim2.fromScale(1, 1), UDim2.new(), Vector2.zero
		overlay.ImageColor3, overlay.ScaleType, overlay.ResampleMode =
			Color3.new(1, 1, 1), image.ScaleType, image.ResampleMode
		overlay.ZIndex, overlay.Parent = image.ZIndex + 1, image
		local gradient = Instance.new("UIGradient")
		gradient.Rotation, gradient.Offset = 30, Vector2.new(-1.3, 0)
		gradient.Color = ColorSequence.new(PURPLE, CYAN)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(0.65, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = overlay
		local badge = Instance.new("TextLabel")
		badge.Name, badge.Text, badge.Font, badge.TextSize =
			"EnchantRune", "✦", Enum.Font.Code, 16
		badge.TextColor3, badge.BackgroundColor3, badge.BackgroundTransparency =
			CYAN, Color3.fromRGB(30, 24, 45), 0.12
		badge.Size, badge.Position, badge.ZIndex, badge.Parent =
			UDim2.fromOffset(16, 16), UDim2.fromOffset(0, 0), image.ZIndex + 2, image
		badge.BorderSizePixel = 0
		local tween = TweenService:Create(
			gradient,
			TweenInfo.new(2.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Offset = Vector2.new(1.3, 0) }
		)
		entry = { overlay = overlay, badge = badge, tween = tween }
		slots[image] = entry
		entry.connection = image.Destroying:Connect(function()
			tween:Cancel()
			slots[image] = nil
		end)
		tween:Play()
	end
	entry.overlay.Image = image.Image
	entry.overlay.ImageRectOffset, entry.overlay.ImageRectSize =
		image.ImageRectOffset, image.ImageRectSize
end

local function animate()
	if animation then
		return
	end
	local elapsed = 0
	animation = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 1 / 15 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for container, record in models do
			local camera = workspace.CurrentCamera
			if
				container:IsDescendantOf(workspace)
				and (not camera or (record.root.Position - camera.CFrame.Position).Magnitude <= 120)
			then
				for _, pixel in record.pixels do
					local wave = (math.sin(now * 2.2 + pixel.phase) + 1) / 2
					pixel.part.Color =
						pixel.color:Lerp(PURPLE:Lerp(CYAN, wave), 0.10 + 0.22 * wave ^ 3)
				end
				for _, line in record.runes do
					line.BackgroundColor3 = PURPLE:Lerp(CYAN, (math.sin(now * 1.6) + 1) / 2)
				end
			end
		end
	end)
end

function Visual.held(container: Instance, root: BasePart)
	if models[container] then
		return
	end
	local record = { pixels = {}, runes = {}, root = root }
	local surface: BasePart? = nil
	local area = 0
	local parts = container:GetDescendants()
	if container:IsA("BasePart") then
		table.insert(parts, container)
	end
	for _, part in parts do
		if part:IsA("BasePart") and part.Transparency < 0.9 then
			local localPosition = root.CFrame:PointToObjectSpace(part.Position)
			table.insert(record.pixels, {
				part = part,
				color = part.Color,
				phase = (localPosition.Y + localPosition.Z) * 3 / math.max(root.Size.Y, 0.1),
			})
			if part.Size.Y * part.Size.Z > area then
				surface, area = part, part.Size.Y * part.Size.Z
			end
		end
	end
	-- Two small matte diamond runes on the actual broad faces, never a square around the silhouette.
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.AlwaysOnTop, gui.LightInfluence, gui.Brightness =
			"EnchantRune", face, false, 1, 1
		gui.CanvasSize, gui.Parent = Vector2.new(64, 64), surface or root
		local rune = Instance.new("Frame")
		rune.AnchorPoint, rune.Position, rune.Size, rune.BackgroundTransparency =
			Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.32, 0.32), 1
		rune.Rotation, rune.Parent = 45, gui
		for index = 1, 4 do
			local line = Instance.new("Frame")
			line.Size = if index <= 2 then UDim2.new(1, 0, 0, 3) else UDim2.new(0, 3, 1, 0)
			line.Position = if index == 2
				then UDim2.new(0, 0, 1, -3)
				elseif index == 4 then UDim2.new(1, -3, 0, 0)
				else UDim2.new()
			line.BorderSizePixel, line.BackgroundColor3, line.Parent = 0, CYAN, rune
			table.insert(record.runes, line)
		end
	end
	models[container] = record
	container.Destroying:Connect(function()
		models[container] = nil
		if not next(models) and animation then
			animation:Disconnect()
			animation = nil
		end
	end)
	animate()
end
return Visual
