--!strict
-- A colour for any block / item id, used where there is no picture yet (a slot shows a tile of this
-- colour instead of a text name — owner 21.10: no text on items and blocks). Known blocks have
-- hand-picked colours (the same as MineService's fallbacks); the rest are guessed from the id.

local BlockColors = {}

export type Tint = { base: string, color: Color3, iconOnly: boolean? }

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

-- Wool colours we have no texture of: our white wool texture tinted (Рынок: red and lime wool [меню, вики 26.10])
local TINTED: { [string]: Tint } = {
	red_wool = { base = "white_wool", color = Color3.fromRGB(196, 46, 40) },
	lime_wool = { base = "white_wool", color = Color3.fromRGB(120, 196, 52) },
	-- concrete: our smooth stone tinted (Лепреконовая долина: жёлтый цемент [меню]; the справочник adds four colours)
	yellow_concrete = { base = "smooth_stone", color = Color3.fromRGB(240, 200, 40) },
	orange_concrete = { base = "smooth_stone", color = Color3.fromRGB(235, 120, 30) },
	lime_concrete = { base = "smooth_stone", color = Color3.fromRGB(110, 190, 40) },
	purple_concrete = { base = "smooth_stone", color = Color3.fromRGB(130, 50, 180) },
	red_concrete = { base = "smooth_stone", color = Color3.fromRGB(180, 40, 40) },
	-- quartz (Замок: кварцевый блок [меню]; резной кварцевый блок [вики 26.10])
	quartz_block = { base = "smooth_stone", color = Color3.fromRGB(240, 237, 230) },
	chiseled_quartz = { base = "white_stone_bricks", color = Color3.fromRGB(240, 237, 230) },
	-- leaves (Изнанка: листья мрачного дуба [меню]): our clipped hedge texture darkened to dark oak green
	dark_oak_leaves = { base = "hedge", color = Color3.fromRGB(150, 170, 130) },
	-- pink wool (Киото: розовая шерсть [меню])
	pink_wool = { base = "white_wool", color = Color3.fromRGB(244, 160, 196) },
	-- Ферма: тыква, зелёная шерсть [меню] (the melon has its own texture)
	pumpkin = { base = "hay", color = Color3.fromRGB(240, 140, 40) },
	green_wool = { base = "white_wool", color = Color3.fromRGB(96, 140, 40) },
	-- Амбар: светильник Джека [меню] — has its own lit-face texture now; this is the fallback
	jack_o_lantern = { base = "pumpkin", color = Color3.fromRGB(255, 226, 170) },
	-- Врата края: пурпурный цемент [меню]
	magenta_concrete = { base = "smooth_stone", color = Color3.fromRGB(196, 64, 186) },
	-- Древо: белый цемент [меню]
	white_concrete = { base = "smooth_stone", color = Color3.fromRGB(236, 238, 238) },
	-- Церковь: глина [меню] (blue-grey, as in vanilla)
	clay = { base = "smooth_stone", color = Color3.fromRGB(160, 166, 180) },
	-- Чистилище: резной песчаник [меню] (our cut sandstone, a little warmer)
	chiseled_sandstone = { base = "cut_sandstone", color = Color3.fromRGB(250, 238, 205) },
	-- Эдем: гриб (коричневый) [меню] (a fallback: it has its own drawn texture now, TextureService wins)
	brown_mushroom_block = { base = "terracotta", color = Color3.fromRGB(205, 165, 135) },
	-- Херувимы: снег [меню] (a fallback: its own texture now)
	snow = { base = "smooth_stone", color = Color3.fromRGB(246, 248, 252) },
	-- Рай: гриб (красный) [меню] (a fallback: its own drawn texture now)
	red_mushroom_block = { base = "terracotta", color = Color3.fromRGB(210, 48, 44) },
	-- Врата: гладкий песчаник [меню] (a fallback: its own texture now, warmer than the paving)
	smooth_sandstone = { base = "sandstone", color = Color3.fromRGB(250, 242, 220) },
	-- Врата края: чёрное стекло — the mine uses dark Roblox glass; the UI icon is smooth stone tinted dark
	black_glass = { base = "smooth_stone", color = Color3.fromRGB(52, 44, 64), iconOnly = true },
}
BlockColors.TINTED = TINTED

-- A block picture for the UI when the block has no icon of its own: its tinted base texture (wool, concrete,
-- quartz …), like the mine draws it. Returns the image and the colour to set as ImageColor3.
function BlockColors.icon(id: string): (string?, Color3)
	local Config = require(script.Parent.Config) :: any
	local own = Config.iconFor(id)
	if own then
		return own, Color3.new(1, 1, 1)
	end
	local tint = BlockColors.TINTED[id]
	local base = if tint then Config.textures.textures[tint.base] else nil
	if base then
		return base, tint.color
	end
	return nil, BlockColors.of(id)
end

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
