--!strict
-- «/hide» [клиент hide.*: «Игроки скрыты! / показаны!»] — the other players disappear for this client only: their
-- parts and decals through LocalTransparencyModifier, the name plates and other billboards over them switched off.
-- Re-applied twice a second while on (new characters, a picked-up item, a fresh armour model). Turning it off puts
-- back exactly what this module changed. The original binds H; H is the HUD editor here, so it is /hide and the
-- settings switch (settings.hidePlayers) instead.
local Players = game:GetService("Players")

local HidePlayers = {}

local hidden = false
local parts: { [Instance]: number } = {} -- part / decal → its modifier before
local guis: { [Instance]: boolean } = {} -- billboards this module switched off
local running = false

local function hideCharacter(character: Model)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if parts[d] == nil then
				parts[d] = d.LocalTransparencyModifier
			end
			d.LocalTransparencyModifier = 1
		elseif d:IsA("BillboardGui") and d.Enabled then
			d.Enabled = false
			guis[d] = true
		end
	end
end

local function apply()
	local me = Players.LocalPlayer
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= me and other.Character then
			hideCharacter(other.Character)
		end
	end
end

local function restore()
	for d, before in pairs(parts) do
		if d.Parent then
			(d :: any).LocalTransparencyModifier = before
		end
	end
	for gui in pairs(guis) do
		if gui.Parent then
			(gui :: any).Enabled = true
		end
	end
	table.clear(parts)
	table.clear(guis)
end

function HidePlayers.isHidden(): boolean
	return hidden
end

function HidePlayers.set(on: boolean)
	if on == hidden then
		return
	end
	hidden = on
	if not on then
		restore()
		return
	end
	apply()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while hidden do
			task.wait(0.5)
			if hidden then
				apply()
				for d in pairs(parts) do -- forget what was destroyed
					if not d.Parent then
						parts[d] = nil
					end
				end
			end
		end
		running = false
	end)
end

return HidePlayers
