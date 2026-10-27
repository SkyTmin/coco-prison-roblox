--!strict
-- Player ranks by level [владелец 27.10: «раздели картинку по рангам типо. До 10 уровня один ранг, дальше до 20 другой
-- ранг»]: every 10 levels a rank with its own emblem (rank_<n> in Config.icons, Codex sheet → Blender like every item
-- icon) and colour. Names and colours [решение]: the shield gets richer like Minecraft's materials — wood, stone, iron,
-- gold, diamond. Strings: rank_<n>.
local Ranks = {}

export type Rank = { index: number, from: number, to: number, color: Color3, dark: Color3 }

Ranks.SIZE = 10

Ranks.list = {
	{
		index = 1,
		from = 1,
		to = 10,
		color = Color3.fromRGB(196, 140, 72),
		dark = Color3.fromRGB(74, 48, 22),
	},
	{
		index = 2,
		from = 11,
		to = 20,
		color = Color3.fromRGB(176, 182, 192),
		dark = Color3.fromRGB(48, 52, 60),
	},
	{
		index = 3,
		from = 21,
		to = 30,
		color = Color3.fromRGB(235, 240, 250),
		dark = Color3.fromRGB(58, 66, 84),
	},
	{
		index = 4,
		from = 31,
		to = 40,
		color = Color3.fromRGB(255, 205, 60),
		dark = Color3.fromRGB(92, 64, 10),
	},
	{
		index = 5,
		from = 41,
		to = 50,
		color = Color3.fromRGB(96, 238, 226),
		dark = Color3.fromRGB(16, 70, 82),
	},
} :: { Rank }

function Ranks.of(level: number): Rank
	for _, rank in ipairs(Ranks.list) do
		if level <= rank.to then
			return rank
		end
	end
	return Ranks.list[#Ranks.list]
end

-- the emblem's icon key in Config.icons.icons
function Ranks.icon(rank: Rank): string
	return "rank_" .. rank.index
end

return Ranks
