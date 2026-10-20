--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

local TIERS = { "common", "rare", "epic" }
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" }
local COLORS = {
	common = Color3.fromRGB(92, 155, 105),
	rare = Color3.fromRGB(64, 129, 210),
	epic = Color3.fromRGB(164, 88, 201),
}
local ArtifactWindow = {}

function ArtifactWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	-- At 812×375 the existing viewport clamp keeps scale = 1, including 44px targets.
	local win, content = createWindow(parent, t("artifacts"), UDim2.fromOffset(780, 350), onClose)
	content.Position, content.Size = UDim2.fromOffset(6, 56), UDim2.new(1, -12, 1, -62)
	for _, child in ipairs(win:GetChildren()) do
		if child:IsA("TextButton") then
			child.Size, child.Position = UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 6)
		elseif child:IsA("Frame") and child ~= content then
			child.Size = UDim2.new(1, -62, 0, 44)
		end
	end
	local tier = "common"
	local album = false
	local collection = Instance.new("Frame")
	collection.Size, collection.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	collection.Parent = content
	local albumFrame = Instance.new("Frame")
	albumFrame.Size, albumFrame.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	albumFrame.Parent = content
	local tabs: { TextButton } = {}
	local rarityButtons: { [string]: TextButton } = {}
	local tiles: { Frame } = {}
	local images: { ImageLabel } = {}
	local numerals: { TextLabel } = {}
	local finds: { TextLabel } = {}
	local picture = Ui.label(
		collection,
		"",
		UDim2.fromOffset(194, 28),
		UDim2.fromOffset(6, 48),
		16,
		Ui.colors.header
	)
	Ui.label(
		collection,
		t("artifact_finds"),
		UDim2.fromOffset(238, 24),
		UDim2.fromOffset(202, 78),
		15,
		Ui.colors.header
	)
	for index = 1, 9 do
		local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
		local tile = Ui.panel(
			collection,
			UDim2.fromOffset(56, 56),
			UDim2.fromOffset(6 + column * 60, 82 + row * 60)
		)
		tile.ClipsDescendants = true
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(168, 168)
		image.Position = UDim2.fromOffset(-column * 56, -row * 56)
		image.Parent = tile
		local numeral = Ui.label(tile, ROMAN[index], UDim2.fromScale(1, 1), UDim2.new(), 22)
		numeral.TextXAlignment = Enum.TextXAlignment.Center
		numeral.TextStrokeTransparency = 0.4
		numeral.ZIndex = image.ZIndex + 1
		tiles[index], images[index], numerals[index] = tile, image, numeral
		finds[index] = Ui.label(
			collection,
			"",
			UDim2.fromOffset(238, 18),
			UDim2.fromOffset(202, 104 + (index - 1) * 18),
			12
		)
	end
	local duplicates =
		Ui.label(collection, "", UDim2.fromOffset(306, 76), UDim2.fromOffset(450, 78), 14)
	duplicates.TextWrapped = true
	local assemble = Ui.button(
		collection,
		t("artifact_create"),
		UDim2.fromOffset(306, 48),
		UDim2.fromOffset(450, 164),
		Ui.colors.buttonGreen
	)
	local tooltip = Ui.label(
		collection,
		"",
		UDim2.fromOffset(306, 64),
		UDim2.fromOffset(450, 218),
		13,
		Ui.colors.muted
	)
	tooltip.TextWrapped = true
	assemble.Activated:Connect(function()
		if assemble.Active then
			Remotes.event("ArtifactAssemble"):FireServer(tier)
		end
	end)
	local completedLabels: { [string]: TextLabel } = {}
	for index, rarity in ipairs(TIERS) do
		local card = Ui.panel(
			albumFrame,
			UDim2.fromOffset(244, 224),
			UDim2.fromOffset(4 + (index - 1) * 256, 54)
		)
		Ui.label(
			card,
			t("artifact_tier_" .. rarity),
			UDim2.new(1, -16, 0, 44),
			UDim2.fromOffset(8, 12),
			19,
			COLORS[rarity]
		)
		local count = Ui.label(card, "", UDim2.new(1, -16, 0, 100), UDim2.fromOffset(8, 72), 18)
		count.TextWrapped = true
		completedLabels[rarity] = count
	end
	local function refresh(p: Types.Profile?)
		profile = p
		collection.Visible, albumFrame.Visible = not album, album
		for index, button in ipairs(tabs) do
			button.BackgroundColor3 = if album == (index == 2)
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		for rarity, button in pairs(rarityButtons) do
			button.Visible = not album
			button.BackgroundColor3 = if rarity == tier
				then COLORS[rarity]
				else Ui.colors.buttonGrey
		end
		local state = if p and p.artifacts then p.artifacts[tier] else nil
		local definition = Config.artifacts.tiers[tier]
		picture.Text = Strings.artifactPictureName(definition.pictures[1], locale)
		local complete = true
		for index = 1, 9 do
			local count = if state then (state.fragments[index] or 0) else 0
			local owned = count > 0
			complete = complete and owned
			tiles[index].BackgroundColor3 = if owned then COLORS[tier] else Ui.colors.slot
			tiles[index].BackgroundTransparency = 0
			images[index].Image = definition.image or ""
			images[index].Visible = owned
				and typeof(definition.image) == "string"
				and definition.image ~= ""
			numerals[index].TextColor3 = if owned then Ui.colors.text else Ui.colors.muted
			finds[index].Text = t(
				"artifact_fragment_name",
				t("artifact_tier_" .. tier),
				ROMAN[index]
			) .. " ×" .. tostring(count)
			finds[index].TextColor3 = if owned then Ui.colors.text else Ui.colors.muted
		end
		duplicates.Text = t(
			"artifact_duplicates",
			if state then state.duplicates else 0,
			Config.artifacts.duplicatesPerMissingFragment
		)
		assemble.Active, assemble.AutoButtonColor = complete, complete
		assemble.BackgroundColor3 = if complete then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		tooltip.Text = t(if complete then "artifact_ready_tooltip" else "artifact_need_fragments")
		for _, rarity in ipairs(TIERS) do
			local progress = if p and p.artifacts then p.artifacts[rarity] else nil
			completedLabels[rarity].Text =
				t("artifact_completed", if progress then progress.completed else 0)
		end
	end
	for index, key in ipairs({ "artifact_collection", "artifact_album" }) do
		local button = Ui.button(
			content,
			t(key),
			UDim2.fromOffset(110, 44),
			UDim2.fromOffset((index - 1) * 116, 0)
		)
		tabs[index] = button
		button.Activated:Connect(function()
			album = index == 2
			refresh(profile)
		end)
	end
	for index, rarity in ipairs(TIERS) do
		local button = Ui.button(
			content,
			t("artifact_tier_" .. rarity),
			UDim2.fromOffset(172, 44),
			UDim2.fromOffset(240 + (index - 1) * 176, 0)
		)
		rarityButtons[rarity] = button
		button.Activated:Connect(function()
			tier = rarity
			refresh(profile)
		end)
	end
	refresh(profile)
	return win, refresh
end

return ArtifactWindow
