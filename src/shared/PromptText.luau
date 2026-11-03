--!strict
-- Server prompt text carries a translation key and typed arguments, never a reverse-parsed price/name.
local HttpService = game:GetService("HttpService")
local Strings = require(script.Parent.Strings)
local PromptText = {}

function PromptText.Set(prompt: ProximityPrompt, property: string, key: string, ...: any)
	assert(property == "ActionText" or property == "ObjectText", "Unsupported prompt property")
	local arguments = { ... }
	prompt:SetAttribute(
		"Localized" .. property,
		HttpService:JSONEncode({ key = key, args = arguments })
	)
	local object: any = prompt
	object[property] = Strings.t(key, "ru", table.unpack(arguments))
end

function PromptText.Render(
	prompt: ProximityPrompt,
	property: string,
	locale: string,
	fallback: string
): string
	local raw = prompt:GetAttribute("Localized" .. property)
	if typeof(raw) == "string" then
		local ok, metadata = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if
			ok
			and typeof(metadata) == "table"
			and typeof(metadata.key) == "string"
			and typeof(metadata.args) == "table"
		then
			return Strings.t(metadata.key, locale, table.unpack(metadata.args))
		end
	end
	return Strings.worldText(fallback, locale)
end

return PromptText
