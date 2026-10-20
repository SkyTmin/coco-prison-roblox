--!strict
-- Creates one MaterialVariant per texture at startup (Config/textures.json) so any Part can use a
-- block texture with a single property: Part.Material = Plastic, Part.MaterialVariant = "px_<id>".

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local TextureService = {}
local PREFIX = "px_"

function TextureService.variantName(textureId: string): string?
	local textures = Config.textures and Config.textures.textures
	if textures and textures[textureId] then
		return PREFIX .. textureId
	end
	return nil
end

-- Applies a texture to a part; falls back to the given colour when the texture is unknown.
function TextureService.apply(part: BasePart, textureId: string, fallback: Color3?)
	local name = TextureService.variantName(textureId)
	if name then
		part.Material = Enum.Material.Plastic
		part.MaterialVariant = name
		part.Color = Color3.new(1, 1, 1)
	elseif fallback then
		part.Color = fallback
	end
end

function TextureService.Start()
	local cfg = Config.textures
	if not cfg then
		return
	end
	for id, assetId in pairs(cfg.textures) do
		local name = PREFIX .. id
		if not MaterialService:FindFirstChild(name) then
			local variant = Instance.new("MaterialVariant")
			variant.Name = name
			variant.BaseMaterial = Enum.Material.Plastic
			variant.ColorMap = assetId
			variant.StudsPerTile = cfg.studsPerTile or 4
			variant.Parent = MaterialService
		end
	end
end

return TextureService
