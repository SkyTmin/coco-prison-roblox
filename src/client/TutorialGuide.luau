--!strict
-- First-login guidance follows real world/UI targets; only server outcomes advance persisted steps.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local Strings = require(Shared.Strings)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Ui = require(script.Parent.Ui)
local TutorialPanel = require(script.Parent.TutorialPanel)
local TutorialPath = require(script.Parent.TutorialPath)
local HudLayout = require(script.Parent.HudLayout)
local Guide = {}
local started = false

-- A shaft and two wings remain recognizable without relying on a font's triangle glyph.
local function pointer(parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency, holder.Size, holder.Parent = 1, UDim2.fromOffset(42, 42), parent
	for _, shape in { { 21, 17, 6, 34, 0 }, { 14, 29, 20, 6, 45 }, { 28, 29, 20, 6, -45 } } do
		local part = Instance.new("Frame")
		part.AnchorPoint, part.Position =
			Vector2.new(0.5, 0.5), UDim2.fromOffset(shape[1], shape[2])
		part.Size, part.Rotation = UDim2.fromOffset(shape[3], shape[4]), shape[5]
		part.BorderSizePixel, part.BackgroundColor3, part.ZIndex, part.Parent =
			0, Ui.colors.yellow, 31, holder
		local edge = Instance.new("UIStroke")
		edge.Color, edge.Thickness, edge.Parent = Color3.fromRGB(20, 20, 20), 1, part
	end
	return holder
end

function Guide.Start(
	gui: ScreenGui,
	getProfile: () -> any,
	openMenu: (string) -> (),
	menuOpen: () -> boolean
)
	if started then
		return
	end
	started = true
	local player, alive = Players.LocalPlayer, true
	local step, locale = 5, Config.defaultLocale
	local target: BasePart? = nil
	local control: GuiObject? = nil
	local itemConfirmed = false
	local seenButtons: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local marks: { [GuiObject]: UIStroke } = {}
	local hideRequestedAt = -math.huge
	local taskPanel = TutorialPanel.new(gui, openMenu, function()
		hideRequestedAt = os.clock()
		Remotes.event("SetSetting"):FireServer("hideRequirements", true)
	end)
	local panel, shortcut = taskPanel.frame, taskPanel.shortcut
	HudLayout.register("requirements", panel, true, true)
	local marker = Instance.new("BillboardGui")
	marker.Name, marker.AlwaysOnTop = "TutorialWorldMarker", true
	marker.Size, marker.StudsOffsetWorldSpace, marker.Parent =
		UDim2.fromOffset(160, 82), Vector3.new(0, 5, 0), gui
	local arrow = pointer(marker)
	arrow.Position = UDim2.fromOffset(59, 0)
	local caption =
		Ui.label(marker, "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 48), 16, Ui.colors.yellow)
	caption.TextXAlignment, caption.TextStrokeTransparency = Enum.TextXAlignment.Center, 0.25
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.FillColor, highlight.OutlineColor =
		"TutorialBlock", Ui.colors.yellow, Ui.colors.yellow
	highlight.FillTransparency, highlight.Parent = 0.7, gui
	local uiArrow = pointer(gui)
	uiArrow.Name, uiArrow.AnchorPoint, uiArrow.ZIndex = "TutorialUiArrow", Vector2.new(0.5, 1), 30
	uiArrow.Visible = false
	local line: Beam? = nil
	local startAttachment: Attachment? = nil
	local endAttachment: Attachment? = nil
	local groundPath: any = nil
	local function clearLine()
		if groundPath then
			groundPath.Destroy()
			groundPath = nil
		end
		if line then
			line:Destroy()
			line = nil
		end
		if startAttachment then
			startAttachment:Destroy()
			startAttachment = nil
		end
		if endAttachment then
			endAttachment:Destroy()
			endAttachment = nil
		end
	end
	local function bindLine(part: BasePart?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not part then
			clearLine()
			return
		end
		if
			startAttachment
			and startAttachment.Parent == root
			and endAttachment
			and endAttachment.Parent == part
		then
			return
		end
		clearLine()
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, a.Position, a.Parent = "TutorialPathStart", Vector3.new(0, -1, 0), root
		b.Name, b.Position, b.Parent =
			"TutorialPathTarget", Vector3.new(0, part.Size.Y / 2 + 0.5, 0), part
		local beam = Instance.new("Beam")
		beam.Name, beam.Attachment0, beam.Attachment1 = "TutorialPath", a, b
		beam.FaceCamera, beam.Color, beam.Transparency =
			true, ColorSequence.new(Ui.colors.yellow), NumberSequence.new(0.15)
		-- The thin stock beam connects the endpoints; full local ground arrows carry direction.
		-- No external texture asset can make the guide disappear.
		beam.Width0, beam.Width1, beam.Segments, beam.Parent = 0.07, 0.07, 1, root
		startAttachment, endAttachment, line = a, b, beam
		groundPath = TutorialPath.new(Ui.colors.yellow)
	end
	local function visible(object: Instance?): boolean
		local current = object
		while current and current ~= gui do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			if current:IsA("ScreenGui") and not current.Enabled then
				return false
			end
			current = current.Parent
		end
		return object ~= nil and current == gui
	end
	local function object(name: string): GuiObject?
		local found = gui:FindFirstChild(name, true)
		return if found and found:IsA("GuiObject") and visible(found) then found else nil
	end
	local cachedTarget: BasePart? = nil
	local cachedMode: string? = nil
	local cachedCounter: string? = nil
	local searchedPosition = Vector3.zero
	local searchedLook = Vector3.zero
	local searchedAt = -math.huge
	local cachedFallback = false
	local rejectedWanted: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local rejectedFallback: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function chooseTarget(mode: string?, counters: { [string]: boolean }?): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not mode then
			cachedTarget, cachedMode, cachedFallback = nil, nil, false
			table.clear(rejectedWanted)
			table.clear(rejectedFallback)
			return nil
		end
		local keys = {}
		for key in counters or {} do
			table.insert(keys, key)
		end
		table.sort(keys)
		local counterKey = table.concat(keys, "|")
		local camera = workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else root.CFrame.LookVector
		local eye = if camera then camera.CFrame.Position else root.Position
		local function facing(part: BasePart): number
			local delta = part.Position + Vector3.new(0, part.Size.Y / 2, 0) - eye
			return if delta.Magnitude < 0.01 then 1 else delta.Unit:Dot(look)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character :: Model }
		local function exposed(part: BasePart): boolean
			if not part:IsDescendantOf(workspace) or part.LocalTransparencyModifier >= 1 then
				return false
			end
			if mode ~= "mine" then
				return true
			end
			if facing(part) < 0.65 then
				return false
			end
			local surface = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
			local hit =
				workspace:Raycast(surface + Vector3.new(0, 5, 0), Vector3.new(0, -5.1, 0), params)
			if not hit or hit.Instance ~= part then
				return false
			end
			-- Do not point through a wall or an intervening column of mine blocks.
			local sight = workspace:Raycast(eye, part.Position - eye, params)
			return sight ~= nil and sight.Instance == part
		end
		local sameGoal = cachedMode == mode and cachedCounter == counterKey
		if not sameGoal then
			table.clear(rejectedWanted)
			table.clear(rejectedFallback)
		end
		local valid = sameGoal and cachedTarget and exposed(cachedTarget)
		local retained = if valid then cachedTarget else nil
		local retainedFallback = cachedFallback
		local elapsed = os.clock() - searchedAt
		if
			valid
			and (
				elapsed < 0.5
				or (
					elapsed < 2
					and not cachedFallback
					and (root.Position - searchedPosition).Magnitude < 2
					and look:Dot(searchedLook) > 0.99
				)
			)
		then
			return cachedTarget
		end
		cachedTarget = nil
		if sameGoal and elapsed < 0.5 then
			return nil
		end
		cachedMode, cachedCounter, searchedAt = mode, counterKey, os.clock()
		searchedPosition, searchedLook = root.Position, look
		local mine = workspace:FindFirstChild("Mine_prison")
		local candidates = if mode == "mine" and mine
			then mine:GetChildren()
			elseif mode == "sell" then CollectionService:GetTagged("SellPoint")
			elseif mode == "case" then CollectionService:GetTagged("OrdinaryCase")
			elseif mode == "mine_area" then CollectionService:GetTagged("MineAnchor")
			else {}
		-- Fresh nearby probes respond promptly when another player exposes a block;
		-- paged candidates ensure buried nearer blocks cannot starve every farther one.
		local fresh, nearest, fallbackFresh, fallback = {}, {}, {}, {}
		local function keep(list: any, part: BasePart, distance: number, limit: number)
			if #list == limit and distance >= list[limit].distance then
				return
			end
			local at = #list + 1
			for index, entry in list do
				if distance < entry.distance then
					at = index
					break
				end
			end
			table.insert(list, at, { part = part, distance = distance })
			if #list > limit then
				table.remove(list)
			end
		end
		for _, candidate in candidates do
			if not candidate:IsA("BasePart") or not candidate:IsDescendantOf(workspace) then
				continue
			end
			local distance = (candidate.Position - root.Position).Magnitude
			if mode == "mine_area" and candidate:GetAttribute("MineId") ~= "prison" then
				continue
			end
			if mode == "mine" then
				local block = Config.block(candidate.Name)
				if
					not block
					or block.tool ~= "shovel"
					or candidate:GetAttribute("MineId") ~= "prison"
					or candidate.LocalTransparencyModifier >= 1
					or facing(candidate) < 0.65
				then
					continue
				end
				-- Nearby upper surfaces are easier to reach than the bottom of a dug shaft.
				distance += math.max(
					0,
					root.Position.Y - candidate.Position.Y - candidate.Size.Y / 2
				) * 3
				distance += (1 - facing(candidate)) * 8
				if #keys > 0 and not (counters and counters[block.upgradeCounter]) then
					keep(fallbackFresh, candidate, distance, 4)
					if not rejectedFallback[candidate] then
						keep(fallback, candidate, distance, 20)
					end
					continue
				end
			end
			keep(fresh, candidate, distance, 8)
			if not rejectedWanted[candidate] then
				keep(nearest, candidate, distance, 32)
			end
		end
		-- A completed pass may revisit previously occluded cells on the next attempt.
		if #nearest == 0 then
			table.clear(rejectedWanted)
		end
		if #fallback == 0 then
			table.clear(rejectedFallback)
		end
		local checked: { [BasePart]: boolean } = {}
		-- At most 8+32+4+20 candidates / 128 rays; up to two extra rays validate the cache.
		for group, list in { fresh, nearest, fallbackFresh, fallback } do
			if group == 3 and retained and not retainedFallback then
				cachedTarget, cachedFallback = retained, false
				return cachedTarget
			end
			for _, entry in list do
				if checked[entry.part] then
					continue
				end
				checked[entry.part] = true
				if exposed(entry.part) then
					cachedTarget, cachedFallback = entry.part, group >= 3
					if not cachedFallback then
						table.clear(rejectedWanted)
						table.clear(rejectedFallback)
					end
					return cachedTarget
				end
				if group < 3 then
					rejectedWanted[entry.part] = true
				else
					rejectedFallback[entry.part] = true
				end
			end
		end
		cachedTarget, cachedFallback = retained, retainedFallback
		if retained then
			return retained
		end
		return nil
	end
	local function chooseControl(goal: any): (GuiObject?, string)
		local buy = object("TutorialUpgrade")
		if buy then
			local shovel: GuiObject? = nil
			for _, candidate in gui:GetDescendants() do
				if
					candidate:IsA("GuiObject")
					and candidate.Name == "TutorialUpgradeItem"
					and candidate:GetAttribute("TutorialItemId") == "shovel"
					and candidate:GetAttribute("TutorialItemTarget") == "inv:" .. tostring(
						goal.target
					)
					and visible(candidate)
				then
					shovel = candidate
					if candidate:GetAttribute("TutorialSelected") then
						break
					end
				end
			end
			if shovel and (not itemConfirmed or not shovel:GetAttribute("TutorialSelected")) then
				return shovel, "tutorial_choose_shovel"
			end
			return buy, "tutorial_buy_upgrade"
		end
		itemConfirmed = false
		local tile = object("Tile_upgrade") or object("Touch_upgrade")
		if tile then
			return tile, "tutorial_choose_upgrade"
		end
		return object("MenuButton") or object("Touch_menu") or shortcut, "tutorial_open_menu"
	end
	local function watch(objectToWatch: Instance)
		if objectToWatch:IsA("GuiButton") and not seenButtons[objectToWatch] then
			seenButtons[objectToWatch] = true
			objectToWatch.Activated:Connect(function()
				if
					objectToWatch.Name == "TutorialUpgradeItem"
					and objectToWatch:GetAttribute("TutorialItemId") == "shovel"
				then
					itemConfirmed = true
				end
			end)
		end
	end
	local added = gui.DescendantAdded:Connect(watch)
	for _, existing in gui:GetDescendants() do
		watch(existing)
	end
	local function mark(nextControl: GuiObject?)
		for objectToClear, stroke in marks do
			if objectToClear ~= nextControl or not objectToClear.Parent then
				stroke:Destroy()
				marks[objectToClear] = nil
			end
		end
		if nextControl and not marks[nextControl] then
			local stroke = Instance.new("UIStroke")
			stroke.Name, stroke.Color, stroke.Thickness, stroke.Parent =
				"TutorialGuideStroke", Ui.colors.yellow, 3, nextControl
			marks[nextControl] = stroke
		end
		control = nextControl
		gui:SetAttribute("TutorialTargetControl", if nextControl then nextControl.Name else nil)
	end
	local animation = RunService.RenderStepped:Connect(function()
		local pulse = (math.sin(os.clock() * 5) + 1) / 2
		marker.StudsOffsetWorldSpace = Vector3.new(0, 5 + pulse * 0.6, 0)
		if line then
			line.Width0, line.Width1 = 0.06 + pulse * 0.02, 0.06 + pulse * 0.02
		end
		if
			groundPath
			and startAttachment
			and endAttachment
			and startAttachment.Parent
			and endAttachment.Parent
		then
			groundPath.Update(
				startAttachment.WorldPosition,
				endAttachment.WorldPosition,
				player.Character
			)
		elseif groundPath then
			-- A dug/streamed-out block destroys its attachment before the next 0.25 s retarget.
			clearLine()
		end
		for _, stroke in marks do
			stroke.Thickness = 2 + pulse * 2
		end
		uiArrow.Visible = control ~= nil and visible(control) and step < 5
		if control and uiArrow.Visible then
			local pos, size = control.AbsolutePosition - gui.AbsolutePosition, control.AbsoluteSize
			local camera = workspace.CurrentCamera
			local view = if camera then camera.ViewportSize else Vector2.new(800, 600)
			local below = pos.Y < GuiService:GetGuiInset().Y + 52
			uiArrow.Rotation = if below then 180 else 0
			uiArrow.Position = UDim2.fromOffset(
				math.clamp(pos.X + size.X / 2, 24, view.X - 24),
				if below then pos.Y + size.Y + 48 + pulse * 6 else pos.Y - 4 - pulse * 6
			)
		end
	end)
	gui.Destroying:Connect(function()
		alive = false
		added:Disconnect()
		animation:Disconnect()
		clearLine()
	end)
	local initialFacing = false
	local function faceMine(profile: any)
		if initialFacing or not profile then
			return
		end
		if step ~= 3 or profile.blocksTotal > 0 or profile.location ~= "prison" then
			initialFacing = true
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if not root or not root:IsA("BasePart") or not camera then
			return
		end
		for _, anchor in CollectionService:GetTagged("MineAnchor") do
			if anchor:IsA("BasePart") and anchor:GetAttribute("MineId") == "prison" then
				local delta = (anchor.Position - root.Position) * Vector3.new(1, 0, 1)
				if delta.Magnitude < 0.1 then
					return
				end
				local direction = delta.Unit
				root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
				local focus = root.Position + Vector3.new(0, 1.5, 0)
				local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
				local eye = if distance < 1
					then focus
					else focus - direction * math.min(distance, 12) + Vector3.new(0, 3, 0)
				camera.CFrame, camera.Focus =
					CFrame.lookAt(eye, focus + direction * 12), CFrame.new(focus)
				initialFacing = true
				return
			end
		end
	end
	task.spawn(function()
		while alive do
			local profile = getProfile()
			local previous = step
			step, locale =
				Tutorial.step(profile), profile and profile.locale or Config.defaultLocale
			if step ~= previous then
				itemConfirmed = false
				if previous >= 5 and step == 3 then
					initialFacing = false
				end
			end
			local phase = "tutorial_open_menu"
			local nextControl: GuiObject? = nil
			local worldMode: string? = nil
			local wantedCounters: { [string]: boolean } = {}
			local displayGoal: any = nil
			local readyForMenu = false
			if step == 3 then
				local goal = Tutorial.upgradeGoal(profile)
				displayGoal = goal
				if goal then
					for _, requirement in goal.requirements do
						if requirement.have < requirement.needed then
							wantedCounters[requirement.counter] = true
						end
					end
					readyForMenu = goal.ready
					if goal.ready then
						nextControl, phase = chooseControl(goal)
					else
						phase = "tutorial_collect_upgrade"
						worldMode = if goal.saleReady
							then "sell"
							elseif profile.tutorial.upgradeSold then nil
							else "mine"
						if profile.tutorial.upgradeSold and not goal.saleReady then
							phase = "tutorial_earn_upgrade"
						end
					end
				end
			elseif step == 4 then
				local goal = Tutorial.levelGoal(profile)
				displayGoal = goal
				if goal then
					readyForMenu = goal.ready
					if goal.ready then
						nextControl = object("LevelUp")
						phase = "tutorial_buy_level"
						if not nextControl then
							nextControl = object("Tile_level") or object("Touch_level")
							phase = "tutorial_choose_level"
						end
						if not nextControl then
							nextControl = object("MenuButton") or object("Touch_menu") or shortcut
							phase = "tutorial_open_menu"
						end
					else
						phase = "tutorial_collect_level"
						worldMode = if goal.saleReady then "sell" else "mine_area"
					end
				end
			end
			if worldMode == "sell" then
				phase = "tutorial_sell_blocks"
				nextControl = object("TutorialSell")
			end
			if Tutorial.shouldGuideCase(profile) then
				worldMode, phase, nextControl = "case", "tutorial_first_case", nil
			end
			local ready = player:GetAttribute("LoadingBlocked") == false
			if ready then
				faceMine(profile)
			end
			mark(if ready and step < 5 then nextControl else nil)
			gui:SetAttribute("TutorialStep", step)
			gui:SetAttribute("TutorialPhase", phase)
			gui:SetAttribute("TutorialRequirementsReady", readyForMenu)
			local camera = workspace.CurrentCamera
			local tracked, trackedStep = Tutorial.trackedGoal(profile)
			taskPanel.manual = tracked ~= nil
			if tracked or step >= 5 then
				displayGoal = tracked
			end
			local editing = HudLayout.isEditing()
			if editing and not displayGoal then
				displayGoal, trackedStep = Tutorial.levelGoal(profile), 4
			end
			taskPanel.preservePosition = editing or HudLayout.moved("requirements")
			if camera then
				taskPanel.Update(
					if tracked or step >= 5 then trackedStep else step,
					locale,
					displayGoal,
					phase,
					camera.ViewportSize,
					GuiService:GetGuiInset().Y,
					TutorialPanel.obstacles(gui, panel, player.PlayerGui)
				)
				if not taskPanel.preservePosition then
					HudLayout.setDefault(panel)
				end
			end
			local hidden = profile and profile.settings and profile.settings.hideRequirements
			panel.Visible = editing
				or (
					ready
					and (step < 5 or tracked ~= nil)
					and not hidden
					and os.clock() - hideRequestedAt >= 1
					and not menuOpen()
					and (taskPanel.preservePosition or panel:GetAttribute("LayoutFits") == true)
				)
			if taskPanel.preservePosition and not editing and camera then
				local scale = panel:FindFirstChildOfClass("UIScale")
				local factor = if scale then scale.Scale else 1
				local view = camera.ViewportSize
				local origin = panel.AbsolutePosition - gui.AbsolutePosition
				local rect = TutorialPanel.relocate(view, GuiService:GetGuiInset().Y, {
					x = origin.X,
					y = origin.Y,
					width = panel.Size.X.Offset * factor,
					height = panel.Size.Y.Offset * factor,
				}, TutorialPanel.obstacles(gui, panel, player.PlayerGui))
				panel.Position, panel.Size =
					UDim2.fromOffset(rect.x, rect.y),
					UDim2.fromOffset(rect.width / factor, rect.height / factor)
				if rect.height <= 0 then
					panel.Visible = false
				end
			end
			caption.Text = Strings.t(
				if worldMode == "mine" or worldMode == "mine_area"
					then "tutorial_marker_mine"
					elseif worldMode == "case" then "tutorial_marker_case"
					else "tutorial_marker_sell",
				locale
			)
			-- Re-evaluate every tick, including when another player digs our target or streaming removes it.
			target = if ready
					and step < 5
					and profile
					and profile.location == "prison"
				then chooseTarget(worldMode, wantedCounters)
				else nil
			marker.Adornee, marker.Enabled = target, target ~= nil
			highlight.Adornee, highlight.Enabled =
				if worldMode == "mine" then target else nil, worldMode == "mine" and target ~= nil
			bindLine(target)
			task.wait(0.25)
		end
	end)
end

return Guide
