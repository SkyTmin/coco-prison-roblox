--!strict
-- Negative StudioTestService actors get one fresh server-run namespace shared by profiles and mailboxes.
-- Real accounts and ordinary servers always retain their established production stores.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Scope = {}
local checked, current = false, nil :: string?

function Scope.Get(): string?
	if checked then
		return current
	end
	checked = true
	if not RunService:IsStudio() then
		return nil
	end
	local ok, args = pcall(function()
		return game:GetService("StudioTestService"):GetTestArgs()
	end)
	if not ok or typeof(args) ~= "string" or args == "" then
		return nil
	end
	current = "Run_" .. HttpService:GenerateGUID(false)
	game:GetService("ServerStorage"):SetAttribute("TestSessionScope", current)
	return current
end

return Scope
