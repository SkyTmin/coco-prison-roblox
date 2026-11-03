--!strict
local Players = game:GetService("Players")
local Prompts = game:GetService("ProximityPromptService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Strings)
local PromptText = require(Shared.PromptText)
local Localizer = {}
local started = false

function Localizer.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local visible: { [ProximityPrompt]: any } = {}
	local function render(prompt: ProximityPrompt, record: any)
		local object: any = prompt
		for _, property in ipairs({ "ActionText", "ObjectText" }) do
			if prompt:GetAttribute("Localized" .. property) then
				record.source[property] =
					PromptText.Render(prompt, property, "ru", record.source[property])
			end
			local text = PromptText.Render(
				prompt,
				property,
				Strings.localeOf(player),
				record.source[property]
			)
			record.written[property] = text
			object[property] = text
		end
	end
	local function hide(prompt: ProximityPrompt)
		local record = visible[prompt]
		if not record then
			return
		end
		visible[prompt] = nil
		for _, connection in record.connections do
			connection:Disconnect()
		end
		if prompt.Parent then
			local object: any = prompt
			for property, text in record.source do
				object[property] = text
			end
		end
	end
	Prompts.PromptShown:Connect(function(prompt: ProximityPrompt)
		local record = visible[prompt]
		if record then
			render(prompt, record)
			return
		end
		record = {
			source = { ActionText = prompt.ActionText, ObjectText = prompt.ObjectText },
			written = {},
			connections = {},
		}
		visible[prompt] = record
		for _, property in ipairs({ "ActionText", "ObjectText" }) do
			table.insert(
				record.connections,
				prompt:GetAttributeChangedSignal("Localized" .. property):Connect(function()
					render(prompt, record)
				end)
			)
			table.insert(
				record.connections,
				prompt:GetPropertyChangedSignal(property):Connect(function()
					local text = (prompt :: any)[property]
					-- Property signals may be deferred; suppress our last write even after render returns.
					if text ~= record.written[property] then
						record.source[property] = text
						render(prompt, record)
					end
				end)
			)
		end
		table.insert(
			record.connections,
			prompt.Destroying:Connect(function()
				hide(prompt)
			end)
		)
		render(prompt, record)
	end)
	Prompts.PromptHidden:Connect(hide)
	player:GetAttributeChangedSignal("Locale"):Connect(function()
		for prompt, record in pairs(visible) do
			render(prompt, record)
		end
	end)
end

return Localizer
