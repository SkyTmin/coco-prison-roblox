--!strict
-- Block textures as MaterialVariants ("px_<id>") in MaterialService. The variants are created at
-- edit time (scripts/build-textures.luau or the Rojo project's materials tree); runtime code only
-- checks they exist and applies them: Part.Material = Plastic, Part.MaterialVariant = "px_<id>".

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local TextureService = {}
local PREFIX = "px_"
local available: { [string]: boolean } = {}

function TextureService.variantName(textureId: string): string?
	local name = PREFIX .. textureId
	return if available[name] then name else nil
end

-- Applies a texture to a part; keeps the given colour when the texture is unavailable.
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
	for _, child in ipairs(MaterialService:GetChildren()) do
		if child:IsA("MaterialVariant") then
			available[child.Name] = true
		end
	end

	local cfg = Config.textures
	if cfg then
		for id in pairs(cfg.textures) do
			if not available[PREFIX .. id] then
				warn(
					"[TextureService] missing MaterialVariant px_"
						.. id
						.. " — run scripts/build-textures.luau in Studio"
				)
			end
		end
	end
end

return TextureService
