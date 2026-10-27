--!strict
-- Status effects shown like Minecraft: an icon with level and timer in the HUD and swirl particles of
-- the effect colour around the player. The server sets character attributes, the client only reads them:
--   <attribute> = level (number) while active, nil otherwise
--   <attribute>Until = workspace:GetServerTimeNow() when it ends; nil = lasts while the cause lasts
--     (a need at 0 — the effect ends as soon as the need is restored)
-- Colours are the vanilla potion colours [ваниль]; Insomnia is the original server's own effect
-- (no vanilla equivalent, owner: "cannot dig") [вики, владелец].

export type Effect = {
	id: string, -- Strings key effect_<id>, icon effect_<id>
	attribute: string,
	color: Color3,
	harmful: boolean,
}

local Effects = {}

Effects.UNTIL = "Until"

Effects.list = {
	{ id = "nausea", attribute = "Nausea", color = Color3.fromRGB(85, 29, 74), harmful = true },
	{
		id = "insomnia",
		attribute = "Insomnia",
		color = Color3.fromRGB(46, 58, 140),
		harmful = true,
	},
	{
		id = "slowness",
		attribute = "Slowness",
		color = Color3.fromRGB(139, 175, 224),
		harmful = true,
	},
	{ id = "haste", attribute = "Haste", color = Color3.fromRGB(217, 192, 67), harmful = false },
	{ id = "speed", attribute = "Speed", color = Color3.fromRGB(51, 235, 255), harmful = false },
	{
		id = "regeneration",
		attribute = "Regeneration",
		color = Color3.fromRGB(205, 92, 171),
		harmful = false,
	},
	{
		id = "strength",
		attribute = "Strength",
		color = Color3.fromRGB(255, 199, 0),
		harmful = false,
	},
	-- the injection «Без нужд» from the donate shop [владелец 28.10]: needs never drain, for good
	{
		id = "needs_free",
		attribute = "NeedsFree",
		color = Color3.fromRGB(120, 220, 140),
		harmful = false,
	},
	-- the golden apple's golden hearts [ваниль]
	{
		id = "absorption",
		attribute = "Absorption",
		color = Color3.fromRGB(37, 82, 165),
		harmful = false,
	},
} :: { Effect }

-- Vanilla movement modifiers [ваниль]: Slowness −15 % and Speed +20 % per level.
Effects.SLOWNESS_PER_LEVEL = 0.15
Effects.SPEED_PER_LEVEL = 0.2

-- Active effects on a character, in display order.
function Effects.active(
	character: Instance?
): { { effect: Effect, level: number, endsAt: number? } }
	local result = {}
	if not character then
		return result
	end
	for _, effect in ipairs(Effects.list) do
		local level = character:GetAttribute(effect.attribute)
		if typeof(level) == "number" and level > 0 then
			local endsAt = character:GetAttribute(effect.attribute .. Effects.UNTIL)
			table.insert(result, {
				effect = effect,
				level = level,
				endsAt = if typeof(endsAt) == "number" then endsAt else nil,
			})
		end
	end
	return result
end

return Effects
