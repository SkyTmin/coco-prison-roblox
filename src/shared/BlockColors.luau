--!strict
-- A colour for any block / item id, used where there is no picture yet (a slot shows a tile of this
-- colour instead of a text name — owner 21.10: no text on items and blocks). Known blocks have
-- hand-picked colours (the same as MineService's fallbacks); the rest are guessed from the id.

local BlockColors = {}

local KNOWN: { [string]: Color3 } = {
	dirt = Color3.fromRGB(121, 85, 58),
	sand = Color3.fromRGB(219, 207, 163),
	gravel = Color3.fromRGB(131, 127, 126),
	stone = Color3.fromRGB(125, 125, 125),
	coal_ore = Color3.fromRGB(70, 70, 70),
	iron_ore = Color3.fromRGB(180, 150, 130),
	coal_block = Color3.fromRGB(30, 30, 30),
	red_sand = Color3.fromRGB(190, 100, 40),
	gold_ore = Color3.fromRGB(210, 180, 80),
	netherite = Color3.fromRGB(100, 40, 40),
	soul_sand = Color3.fromRGB(80, 60, 50),
	quartz_ore = Color3.fromRGB(170, 120, 110),
	sandstone = Color3.fromRGB(220, 205, 150),
	red_sandstone = Color3.fromRGB(190, 100, 50),
	coal = Color3.fromRGB(40, 40, 40),
	cobweb = Color3.fromRGB(235, 235, 235),
	clay = Color3.fromRGB(160, 166, 179),
	sea_lantern = Color3.fromRGB(190, 230, 225),
	purpur = Color3.fromRGB(170, 125, 170),
	prismarine = Color3.fromRGB(99, 156, 151),
	prismarine_bricks = Color3.fromRGB(99, 171, 158),
	end_stone_bricks = Color3.fromRGB(218, 224, 162),
	lapis_block = Color3.fromRGB(31, 67, 140),
	iron_block = Color3.fromRGB(220, 220, 220),
	gold_block = Color3.fromRGB(246, 208, 61),
	diamond_block = Color3.fromRGB(98, 237, 228),
	pumpkin = Color3.fromRGB(198, 118, 24),
	jack_o_lantern = Color3.fromRGB(214, 140, 30),
	snow = Color3.fromRGB(249, 254, 254),
	ice = Color3.fromRGB(170, 210, 245),
	packed_ice = Color3.fromRGB(125, 165, 225),
	quartz = Color3.fromRGB(235, 229, 222),
	black_glass = Color3.fromRGB(25, 25, 29),
}

-- words of an id → colour (first match wins)
local GUESS: { { word: string, color: Color3 } } = {
	{ word = "magenta", color = Color3.fromRGB(189, 68, 179) },
	{ word = "purple", color = Color3.fromRGB(121, 42, 172) },
	{ word = "pink", color = Color3.fromRGB(237, 141, 172) },
	{ word = "lime", color = Color3.fromRGB(112, 185, 25) },
	{ word = "green", color = Color3.fromRGB(84, 109, 27) },
	{ word = "cyan", color = Color3.fromRGB(21, 137, 145) },
	{ word = "yellow", color = Color3.fromRGB(248, 197, 39) },
	{ word = "orange", color = Color3.fromRGB(240, 118, 19) },
	{ word = "red", color = Color3.fromRGB(160, 39, 34) },
	{ word = "white", color = Color3.fromRGB(233, 236, 236) },
	{ word = "black", color = Color3.fromRGB(20, 21, 25) },
	{ word = "brown", color = Color3.fromRGB(149, 111, 81) },
	{ word = "quartz", color = Color3.fromRGB(235, 229, 222) },
	{ word = "sandstone", color = Color3.fromRGB(220, 205, 150) },
	{ word = "leaves", color = Color3.fromRGB(64, 120, 40) },
	{ word = "log", color = Color3.fromRGB(102, 81, 51) },
	{ word = "wisteria", color = Color3.fromRGB(180, 150, 220) },
	{ word = "cherry", color = Color3.fromRGB(230, 170, 190) },
}

local DEFAULT = Color3.fromRGB(110, 110, 118)

function BlockColors.of(id: string): Color3
	local known = KNOWN[id]
	if known then
		return known
	end
	for _, entry in ipairs(GUESS) do
		if string.find(id, entry.word, 1, true) then
			return entry.color
		end
	end
	return DEFAULT
end

return BlockColors
