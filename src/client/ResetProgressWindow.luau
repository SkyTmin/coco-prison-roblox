--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)
local ResetWindow = {}

function ResetWindow.open(parent: Instance, locale: string, createWindow: any): Frame
	local function t(key: string, ...: any)
		return Strings.t(key, locale, ...)
	end
	local shade = Instance.new("Frame")
	shade.Name, shade.Size, shade.Active = "OwnResetConfirmation", UDim2.fromScale(1, 1), true
	shade.BackgroundColor3, shade.BackgroundTransparency, shade.ZIndex = Color3.new(), 0.2, 30
	shade.Parent = parent
	local viewport = workspace.CurrentCamera.ViewportSize
	local win, content = createWindow(
		shade,
		t("release_reset"),
		UDim2.fromOffset(
			math.min(560, viewport.X - 24),
			math.min(680, viewport.Y - GuiService:GetGuiInset().Y - 24)
		),
		function()
			shade:Destroy()
		end
	)
	win.Name, win.ZIndex = "Window_ResetProgress", 31
	require(script.Parent.ReleaseLayout).header(win, content)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size, scroll.BackgroundTransparency, scroll.BorderSizePixel = UDim2.fromScale(1, 1), 1, 0
	scroll.ScrollBarThickness, scroll.AutomaticCanvasSize, scroll.CanvasSize =
		6, Enum.AutomaticSize.Y, UDim2.new()
	scroll.Parent = content
	local list = Instance.new("UIListLayout")
	list.SortOrder, list.Padding, list.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 12), scroll
	local function label(text: string, order: number, color: Color3): TextLabel
		local item = Ui.label(scroll, text, UDim2.new(1, -10, 0, 0), UDim2.new(), 16, color)
		item.TextWrapped, item.AutomaticSize, item.LayoutOrder = true, Enum.AutomaticSize.Y, order
		return item
	end
	local deleted = label(t("release_reset_deleted"), 1, Ui.colors.red)
	local kept = label(t("release_reset_kept"), 2, Ui.colors.text)
	local state = label("", 3, Ui.colors.yellow)
	local proceed = Ui.button(
		scroll,
		t("release_reset_review"),
		UDim2.new(1, -10, 0, 52),
		UDim2.new(),
		Ui.colors.close
	)
	proceed.LayoutOrder, proceed.TextSize = 4, 15
	local cancel = Ui.button(
		scroll,
		t("release_action_cancel"),
		UDim2.new(1, -10, 0, 44),
		UDim2.new(),
		Ui.colors.buttonGrey
	)
	cancel.LayoutOrder = 5
	cancel.Activated:Connect(function()
		shade:Destroy()
	end)
	local token: string? = nil
	local waiting = false
	proceed.Activated:Connect(function()
		if waiting then
			return
		end
		waiting = true
		local confirming = token ~= nil
		state.Text = t("release_action_wait")
		task.spawn(function()
			local ok, answer = pcall(function()
				return Remotes.func("CreativeReset")
					:InvokeServer(if confirming then "confirm" else "prepare", token)
			end)
			if not shade.Parent then
				return
			end
			waiting = false
			if not ok or typeof(answer) ~= "table" or not answer.ok then
				token = nil
				deleted.Visible, kept.Visible = true, true
				state.Text = t(
					if ok and typeof(answer) == "table"
						then answer.key or "release_reset_failed"
						else "release_reset_failed"
				)
				proceed.Text = t("release_reset_review")
			elseif confirming then
				state.Text = t("release_reset_done")
				proceed.Visible = false
			else
				token = answer.token
				deleted.Visible, kept.Visible = false, false
				state.Text = t("release_reset_question", Players.LocalPlayer.Name)
				proceed.Text = t("release_reset_confirm")
				scroll.CanvasPosition = Vector2.zero
			end
		end)
	end)
	return shade
end

return ResetWindow
