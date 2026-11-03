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
local Ui = require(script.Parent.Ui)
local TutorialPanel = require(script.Parent.TutorialPanel)
local Guide = {}
local started = false

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
	local taskPanel = TutorialPanel.new(gui, openMenu)
	local panel, shortcut = taskPanel.frame, taskPanel.shortcut
	local marker = Instance.new("BillboardGui")
	marker.Name, marker.AlwaysOnTop = "TutorialWorldMarker", true
	marker.Size, marker.StudsOffsetWorldSpace, marker.Parent =
		UDim2.fromOffset(160, 82), Vector3.new(0, 5, 0), gui
	local arrow = Ui.label(marker, "▼", UDim2.new(1, 0, 0, 48), UDim2.new(), 42, Ui.colors.yellow)
	arrow.Font, arrow.TextXAlignment, arrow.TextStrokeTransparency =
		Enum.Font.GothamBold, Enum.TextXAlignment.Center, 0.25
	local caption =
		Ui.label(marker, "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 48), 16, Ui.colors.yellow)
	caption.TextXAlignment, caption.TextStrokeTransparency = Enum.TextXAlignment.Center, 0.25
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.FillColor, highlight.OutlineColor =
		"TutorialBlock", Ui.colors.yellow, Ui.colors.yellow
	highlight.FillTransparency, highlight.Parent = 0.7, gui
	local uiArrow =
		Ui.label(gui, "▼", UDim2.fromOffset(42, 42), UDim2.new(), 32, Ui.colors.yellow)
	uiArrow.Name, uiArrow.AnchorPoint, uiArrow.ZIndex = "TutorialUiArrow", Vector2.new(0.5, 1), 30
	uiArrow.TextXAlignment, uiArrow.TextStrokeTransparency, uiArrow.Visible =
		Enum.TextXAlignment.Center, 0.25, false
	local line: Beam? = nil
	local startAttachment: Attachment? = nil
	local endAttachment: Attachment? = nil
	local function clearLine()
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
		beam.Width0, beam.Width1, beam.Segments, beam.Parent = 0.14, 0.09, 1, root
		startAttachment, endAttachment, line = a, b, beam
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
	local function chooseTarget(mode: string?, counters: { [string]: boolean }?): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not mode then
			cachedTarget = nil
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
			if mode == "sell" then
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
		local valid = sameGoal and cachedTarget and exposed(cachedTarget)
		local elapsed = os.clock() - searchedAt
		if
			valid
			and (
				elapsed < 0.5
				or (
					elapsed < 2
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
			else {}
		local nearest, fallback = {}, {}
		local function keep(list: any, part: BasePart, distance: number)
			if #list == 32 and distance >= list[32].distance then
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
			if #list > 32 then
				table.remove(list)
			end
		end
		for _, candidate in candidates do
			if not candidate:IsA("BasePart") or not candidate:IsDescendantOf(workspace) then
				continue
			end
			local distance = (candidate.Position - root.Position).Magnitude
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
					keep(fallback, candidate, distance)
					continue
				end
			end
			keep(nearest, candidate, distance)
		end
		-- At most 64 candidates / 128 rays on a retarget; two rays for the cached target.
		for _, list in { nearest, fallback } do
			for _, entry in list do
				if exposed(entry.part) then
					cachedTarget = entry.part
					return cachedTarget
				end
			end
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
			line.Width0, line.Width1 = 0.1 + pulse * 0.08, 0.07 + pulse * 0.04
		end
		for _, stroke in marks do
			stroke.Thickness = 2 + pulse * 2
		end
		uiArrow.Visible = control ~= nil and visible(control) and step < 5
		if control and uiArrow.Visible then
			local pos, size = control.AbsolutePosition, control.AbsoluteSize
			local camera = workspace.CurrentCamera
			local view = if camera then camera.ViewportSize else Vector2.new(800, 600)
			uiArrow.Position = UDim2.fromOffset(
				math.clamp(pos.X + size.X / 2, 24, view.X - 24),
				math.max(GuiService:GetGuiInset().Y + 42, pos.Y - 4 - pulse * 8)
			)
		end
	end)
	gui.Destroying:Connect(function()
		alive = false
		added:Disconnect()
		animation:Disconnect()
		clearLine()
	end)
	task.spawn(function()
		while alive do
			local profile = getProfile()
			local previous = step
			step, locale =
				Tutorial.step(profile), profile and profile.locale or Config.defaultLocale
			if step ~= previous then
				itemConfirmed = false
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
						worldMode = if goal.saleReady then "sell" else "mine"
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
						worldMode = if goal.saleReady then "sell" else "mine"
					end
				end
			end
			if worldMode == "sell" then
				phase = "tutorial_sell_blocks"
				nextControl = object("TutorialSell")
			end
			local ready = player:GetAttribute("LoadingBlocked") == false
			mark(if ready and step < 5 then nextControl else nil)
			gui:SetAttribute("TutorialStep", step)
			gui:SetAttribute("TutorialPhase", phase)
			gui:SetAttribute("TutorialRequirementsReady", readyForMenu)
			local camera = workspace.CurrentCamera
			if camera then
				taskPanel.Update(
					step,
					locale,
					displayGoal,
					phase,
					camera.ViewportSize,
					GuiService:GetGuiInset().Y,
					TutorialPanel.obstacles(gui, panel, player.PlayerGui)
				)
			end
			panel.Visible = ready
				and step < 5
				and not menuOpen()
				and panel:GetAttribute("LayoutFits") == true
			caption.Text = Strings.t("release_tutorial_marker", locale)
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
