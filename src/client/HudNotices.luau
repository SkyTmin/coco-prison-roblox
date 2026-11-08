--!strict
-- A bounded lane for the existing three-second toast; critical gameplay cards have priority.
local RunService = game:GetService("RunService")
local Notices = {}
function Notices.start(
	player: Player,
	frame: Frame,
	label: TextLabel,
	hidden: () -> boolean,
	editing: () -> boolean
): (string) -> ()
	local queue: { { text: string, expires: number, left: number } } = {}
	local current: { text: string, expires: number, left: number }? = nil
	local function publish()
		player:SetAttribute("HudToastActive", frame.Visible)
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(publish)
	publish()
	RunService.Heartbeat:Connect(function(dt)
		if editing() then
			current = nil
			table.clear(queue)
			return
		end
		local now = os.clock()
		if current and (current.expires <= now or current.left <= 0) then
			current = nil
		end
		while not current and #queue > 0 do
			local nextNotice = table.remove(queue, 1)
			if nextNotice.expires > now then
				current = nextNotice
			end
		end
		local critical = player:GetAttribute("HudGameplayOpen") ~= false
			and (
				player:GetAttribute("HudBossActive") == true
				or player:GetAttribute("HudWarzoneActive") == true
			)
		frame.Visible = current ~= nil
			and not hidden()
			and not critical
			and player:GetAttribute("LoadingBlocked") ~= true
		if current and frame.Visible then
			label.Text = current.text
			current.left -= dt
		end
	end)
	return function(text: string)
		if hidden() then
			return
		end
		local notice = { text = text, expires = os.clock() + 20, left = 3 }
		-- Menu errors/results are immediate; old gameplay notices must not delay them.
		if player:GetAttribute("HudGameplayOpen") == false then
			table.clear(queue)
			current = notice
		else
			if #queue >= 8 then
				table.remove(queue, 1)
			end
			table.insert(queue, notice)
		end
	end
end
return Notices
