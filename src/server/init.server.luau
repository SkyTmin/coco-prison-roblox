--!strict
-- Server bootstrap: start services in dependency order.

local ProfileService = require(script.Services.ProfileService)
local WorkService = require(script.Services.WorkService)
local EconomyService = require(script.Services.EconomyService)

ProfileService.Start()
WorkService.Start()
EconomyService.Start()

print("[coco-prison] server started")
