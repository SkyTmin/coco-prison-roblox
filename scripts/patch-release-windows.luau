--!strict
local apply = require(game:GetService("ReplicatedStorage").Shared.MatteWindows).Apply
local count = apply(workspace:FindFirstChild("Ghetto"))
	+ apply(game:GetService("ServerStorage"):FindFirstChild("GangHouseTemplate"))
for _, model in workspace:GetChildren() do
	if model:IsA("Model") and string.match(model.Name, "^GangHouse_") then
		count += apply(model)
	end
end
return string.format("Matte windows repaired: %d", count)
