--!nocheck
-- Execute in Studio Server: pure container fixtures, never the player's inventory.
local Inventory = require(game.ServerScriptService.Server.Services.InventoryService)
local passed = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(passed, name)
end
local source = { [1] = { id = "apple", count = 2 }, [2] = { id = "apple", count = 4 } }
local target = {}
Inventory.transfer(source, 1, target, 1, 36)
Inventory.transfer(source, 2, target, 1, 36)
check("two stacks merge", target[1].count == 6 and target[2] == nil and next(source) == nil)
source = { [1] = { id = "apple", count = 8 } }
target = { [1] = { id = "apple", count = 62 } }
Inventory.transfer(source, 1, target, 1, 36)
check(
	"overflow starts next stack",
	target[1].count == 64 and target[2].count == 6 and next(source) == nil
)
source = { [1] = { id = "apple", count = 8 } }
for i = 1, 36 do
	target[i] = { id = "stone", count = 64 }
end
target[9] = { id = "apple", count = 62 }
check("full bag accepts partial merge", Inventory.transfer(source, 1, target, 1, 36) == 2)
check("leftover stays in chest", source[1].count == 6 and target[9].count == 64)
check(
	"replay does not duplicate",
	Inventory.transfer(source, 1, target, 1, 36) == 0 and source[1].count == 6
)
source =
	{ [1] = { id = "pickaxe", count = 1, level = 16, books = { { id = "hammer", level = 3 } } } }
target = { [1] = { id = "pickaxe", count = 1, level = 16 } }
Inventory.transfer(source, 1, target, 1, 36)
check(
	"tool metadata preserved",
	target[2].level == 16 and target[2].books[1].level == 3 and target[1].count == 1
)
source = { [1] = { id = "apple", count = 4 } }
target = { [1] = { id = "apple", count = 2 }, [28] = { id = "apple", count = 3 } }
Inventory.transfer(source, 1, target, 28, 54)
check("vault section stays isolated", target[1].count == 2 and target[28].count == 7)
return { passed = #passed, checks = passed }
