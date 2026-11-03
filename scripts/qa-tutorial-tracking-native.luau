--!nocheck
-- Run through Studio Client execute after the current Client modules are synced.
-- No real profile reads/writes, remotes, Guide.Start, HudLayout registration or input injection.
-- Visual preview: set _G.QATutorialTrackingPreviewSeconds = 15 before executing this script;
-- then take a screenshot of the actual viewport. The isolated card's X only hides this QA card.
-- The test GUI is automatically removed; results remain in _G.QATutorialTrackingNativeReport.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local player = assert(Players.LocalPlayer, "Execute in Client context")
local client = assert(player.PlayerScripts:FindFirstChild("Client"), "Client not ready")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local Strings = require(Shared.Strings)
local Config = require(Shared.Config)
local Panel = require(client.TutorialPanel)
local Path = require(client.TutorialPath)
local Ui = require(client.Ui)
local old = player.PlayerGui:FindFirstChild("__QATutorialTrackingNative")
if old then
	old:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder =
	"__QATutorialTrackingNative", true, false, 950
gui.Parent = player.PlayerGui
local previewSeconds = math.clamp(tonumber(_G.QATutorialTrackingPreviewSeconds) or 0, 0, 30)
_G.QATutorialTrackingPreviewSeconds = nil
local report = {
	status = "RUNNING",
	checks = {},
	layouts = {},
	assets = {},
	realProfileAccess = false,
	remoteCalls = 0,
	physicalPhoneTest = false,
	simulatedInput = false,
	closeClicked = false,
	menuShortcutClicked = false,
	previewSeconds = previewSeconds,
}
_G.QATutorialTrackingNativeReport = report
local function check(name, passed, detail)
	table.insert(report.checks, { name = name, pass = passed == true, detail = detail })
end
local function inside(a, b)
	return a.X >= b.X - 1 and a.Y >= b.Y - 1
end
local card = Panel.new(gui, function()
	report.menuShortcutClicked = true
end, function()
	report.closeClicked = true
	gui.Enabled = false
end)
local previousPath = workspace:FindFirstChild("__QATutorialDirectionArrows")
if previousPath then
	previousPath:Destroy()
end
local path = Path.new(Ui.colors.yellow, "__QATutorialDirectionArrows")
local fakeProfile = {
	level = 1,
	coins = 1000,
	blocksTotal = 7,
	counters = { ["Гравий"] = 7, ["Песок"] = 3, ["Земля"] = 2 },
	stats = {},
	inventory = { [1] = { id = "shovel", count = 1, level = 1 } },
	armor = {},
	selectedSlot = 1,
	tutorial = Tutorial.new(),
	professions = { upgrades = { money = 0 } },
	activeBoosters = {},
	settings = {},
}
local goal = Tutorial.upgradeGoal(fakeProfile)
local function find(name)
	return assert(card.frame:FindFirstChild(name, true), name)
end
local ok, failure = xpcall(function()
	local camera = assert(workspace.CurrentCamera)
	local view, inset = camera.ViewportSize, GuiService:GetGuiInset().Y
	report.actualViewport = { x = view.X, y = view.Y, inset = inset }
	local assets = {}
	local seen = {}
	local samples = {
		view,
		Vector2.new(320, 568),
		Vector2.new(568, 320),
		Vector2.new(390, 844),
		Vector2.new(844, 390),
	}
	for _, locale in { "ru", "en", "es", "fr" } do
		for index, fixture in samples do
			-- Fixtures exercise native GUI/text layout at these dimensions; they do not change
			-- Roblox's viewport or emulate touch controls. Actual viewport is recorded separately.
			local obstacles = {
				{ x = 8, y = inset + 6, width = 70, height = 44 },
				{ x = 0, y = fixture.Y - 145, width = 145, height = 145 },
				{ x = fixture.X - 95, y = fixture.Y - 130, width = 85, height = 80 },
				{ x = fixture.X / 2 - 100, y = fixture.Y - 50, width = 200, height = 45 },
			}
			card.Update(3, locale, goal, "tutorial_collect_upgrade", fixture, inset, obstacles)
			Run.RenderStepped:Wait()
			Run.RenderStepped:Wait()
			local frame = card.frame
			table.insert(report.layouts, {
				locale = locale,
				fixture = { x = fixture.X, y = fixture.Y },
				actualViewport = index == 1,
				position = { x = frame.Position.X.Offset, y = frame.Position.Y.Offset },
				size = { x = frame.AbsoluteSize.X, y = frame.AbsoluteSize.Y },
				title = find("TaskGoal").Text,
				hint = find("TaskHint").Text,
				scrollHeight = find("TaskContents").CanvasSize.Y.Offset,
			})
			check(
				locale .. " " .. index .. " native frame has usable height",
				frame.AbsoluteSize.Y >= 90
			)
			check(
				locale .. " " .. index .. " card fits fixture viewport",
				frame.Position.X.Offset >= 0
					and frame.Position.Y.Offset >= inset
					and frame.Position.X.Offset + frame.AbsoluteSize.X <= fixture.X
					and frame.Position.Y.Offset + frame.AbsoluteSize.Y <= fixture.Y
			)
			check(
				locale .. " " .. index .. " title fits",
				find("TaskGoal").TextFits,
				find("TaskGoal").Text
			)
			check(
				locale .. " " .. index .. " count stays incomplete",
				find("RequirementsCount").Text == "0 / 3"
					and find("RequirementsCount").TextColor3 == Ui.colors.text
			)
			for row = 1, 3 do
				local entry = find("Requirement_" .. row)
				local icon = entry:FindFirstChild("Icon")
				check(
					locale .. " " .. index .. " actual block icon " .. row,
					icon.Image ~= "" and icon.ResampleMode == Enum.ResamplerMode.Pixelated
				)
				check(
					locale .. " " .. index .. " neutral missing requirement " .. row,
					entry:GetAttribute("RequirementComplete") == false
						and entry.Progress.TextColor3 == Ui.colors.text
				)
				check(
					locale .. " " .. index .. " resource text fits " .. row,
					entry.ResourceName.TextFits,
					entry.ResourceName.Text
				)
				if icon.Image ~= "" and not seen[icon.Image] then
					seen[icon.Image] = true
					table.insert(assets, icon.Image)
				end
			end
			local close = find("HideRequirements")
			check(
				locale .. " " .. index .. " X is inside card",
				inside(close.AbsolutePosition, frame.AbsolutePosition)
					and inside(
						frame.AbsolutePosition + frame.AbsoluteSize,
						close.AbsolutePosition + close.AbsoluteSize
					)
			)
		end
	end
	local complete = false
	task.spawn(function()
		local loaded, err = pcall(function()
			ContentProvider:PreloadAsync(assets, function(asset, status)
				report.assets[asset] = status.Name
			end)
		end)
		report.assetPreloadError = if loaded then nil else tostring(err)
		complete = true
	end)
	local deadline = os.clock() + 10
	while not complete and os.clock() < deadline do
		task.wait(0.05)
	end
	report.assetPreloadComplete = complete
	for _, asset in assets do
		check(
			"own block icon loaded " .. asset,
			report.assets[asset] == "Success",
			report.assets[asset]
		)
	end
	local root = assert(
		player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
		"Character not ready"
	)
	local start = root.Position
	local direction = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local tick = os.clock()
	path.Update(start, start + direction * 24, player.Character, tick)
	Run.RenderStepped:Wait()
	check(
		"native path creates full arrows without external texture",
		path.folder:GetAttribute("VisibleArrows") == 6 and #path.folder:GetChildren() == 18
	)
	path.Update(start, start + direction, player.Character, tick + 1)
	check("near target hides geometry", path.folder:GetAttribute("VisibleArrows") == 0)
	path.Update(start, start + direction * 240, player.Character, tick + 2)
	check(
		"long path stays capped at12arrows36parts",
		path.folder:GetAttribute("VisibleArrows") == 12 and #path.folder:GetChildren() == 36
	)
	for _, part in path.folder:GetChildren() do
		check(
			part.Name .. " has no physics/query/shadow side effects",
			part.Anchored
				and not part.CanCollide
				and not part.CanTouch
				and not part.CanQuery
				and not part.CastShadow
		)
	end
	path.Update(start, start + direction * 24, player.Character, tick + 3)
	report.groundArrows = {
		visible = path.folder:GetAttribute("VisibleArrows"),
		poolParts = #path.folder:GetChildren(),
		externalAsset = false,
	}
	card.manual = true
	card.Update(4, "ru", Tutorial.levelGoal(fakeProfile), "tutorial_collect_level", view, inset, {})
	Run.RenderStepped:Wait()
	check(
		"native manual level title translated",
		find("TaskGoal").Text == Strings.t("tracker_level_goal", "ru", 2)
	)
	card.manual = false
	card.Update(
		3,
		"ru",
		goal,
		"tutorial_collect_upgrade",
		view,
		inset,
		Panel.obstacles(gui, card.frame, player.PlayerGui)
	)
	-- The card remains an isolated sample even if the user clicks its menu shortcut or X.
	card.frame.Visible = true
	report.failed = 0
	for _, result in report.checks do
		if not result.pass then
			report.failed += 1
		end
	end
	report.status = if report.failed == 0 then "PASS" else "FAIL"
end, debug.traceback)
if not ok then
	report.status, report.error = "ERROR", tostring(failure)
end
if ok and previewSeconds > 0 then
	task.delay(previewSeconds, function()
		gui:Destroy()
		path.Destroy()
		report.guiRemoved = true
	end)
else
	gui:Destroy()
	path.Destroy()
	report.guiRemoved = true
end
print(game:GetService("HttpService"):JSONEncode(report))
return report
