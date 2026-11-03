--!strict
local Layout = {}
function Layout.window(kind: string, width: number, height: number, inset: number): (number, number)
	return math.min(if kind == "Window_Creative" then 780 else 560, width - 24),
		math.min(680, height - inset - 24)
end

function Layout.header(win: Frame, content: Frame)
	local close = win:FindFirstChild("Close")
	if close and close:IsA("GuiButton") then
		close.Size, close.Position = UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 4)
	end
	local title = win:FindFirstChild("TitleBar")
	if title and title:IsA("Frame") then
		title.Size = UDim2.new(1, -58, 0, 44)
	end
	content.Position, content.Size = UDim2.fromOffset(6, 52), UDim2.new(1, -12, 1, -58)
end
return Layout
