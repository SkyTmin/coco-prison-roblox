--!strict
-- Pixel layout shared by the auction and viewport sizing; no UIScale shrink on phones.
local AuctionLayout = {}

function AuctionLayout.window(
	viewWidth: number,
	viewHeight: number,
	inset: number
): (number, number)
	return math.min(900, math.max(280, viewWidth - 24)),
		math.min(650, math.max(240, viewHeight - inset - 24))
end

function AuctionLayout.plan(width: number, height: number)
	local wide = width >= 700
	local gridX = if wide then 232 else 0
	local gridWidth = width - gridX
	local columns = math.clamp(math.floor((gridWidth - 8 + 4) / 50), 1, 10)
	local inventoryWidth = if wide then 428 else width - 8
	local inventoryColumns = math.clamp(math.floor((inventoryWidth + 4) / 48), 1, 9)
	local inventoryHeight = 28
		+ (math.ceil(27 / inventoryColumns) + math.ceil(9 / inventoryColumns)) * 48
		+ 8
	return {
		wide = wide,
		gridX = gridX,
		gridWidth = gridWidth,
		columns = columns,
		gridHeight = math.max(46, height - 96),
		gridCanvas = math.ceil(60 / columns) * 50,
		inventoryColumns = inventoryColumns,
		formX = if wide then 444 else 0,
		formY = if wide then 28 else inventoryHeight + 8,
		formWidth = if wide then width - 452 else width - 8,
	}
end

function AuctionLayout.inventory(slot: number, columns: number): (number, number)
	local index = if slot <= 9 then slot - 1 else slot - 10
	local top = if slot <= 9 then 28 + math.ceil(27 / columns) * 48 + 8 else 28
	return (index % columns) * 48, top + math.floor(index / columns) * 48
end

return AuctionLayout
