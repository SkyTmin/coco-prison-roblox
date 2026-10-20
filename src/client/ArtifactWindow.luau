--!strict
-- "Артефакты" window of the original (owner's screenshots 066–068): title "✱ АРТЕФАКТЫ", a wide blue
-- "Сбор" tab (+ "Альбом"), left column with the "✱ РЕДКОСТЬ" list (icon, coloured name, n / 9 in
-- green, blue progress bar, "Собрано: N"; the selected rarity card is blue) and the "⌚ НАХОДКИ" panel
-- ("Здесь появятся находки" until something is assembled); on the right the picture panel
-- "◆ Огород  9 / 9" with the 3×3 mosaic (roman numerals on missing fragments) and the green
-- "Создать артефакт" button (grey until all nine fragments are there).
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
	common = Color3.fromRGB(190, 190, 255),
	rare = Ui.colors.header,
	epic = Ui.colors.purple,
}
local ArtifactWindow = {}

local W, H = 900, 580
local LEFT = 300
local TILE = 150

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
	local win, content = createWindow(
		parent,
		"✱ " .. string.upper(t("artifacts")),
		UDim2.fromOffset(W, H),
		onClose
	)
	local tier = "common"
	local album = false
	local tabs: { TextButton } = {}
	for index, key in ipairs({ "artifact_collection", "artifact_album" }) do
		local button = Ui.button(
			content,
			t(key),
			UDim2.new(if index == 1 then 0.72 else 0.28, if index == 1 then -4 else -8, 0, 36),
			UDim2.new(if index == 1 then 0 else 0.72, if index == 1 then 0 else 4, 0, 0)
		)
		tabs[index] = button
		button.Activated:Connect(function()
			album = index == 2
		end)
	end
	local body = Instance.new("Frame")
	body.Size, body.Position, body.BackgroundTransparency =
		UDim2.new(1, 0, 1, -44), UDim2.fromOffset(0, 44), 1
	body.Parent = content

	-- left: rarity list
	local rarityPanel = Ui.panel(body, UDim2.fromOffset(LEFT, 262), UDim2.fromOffset(0, 0))
	Ui.label(
		rarityPanel,
		"✱ " .. t("artifact_rarity"),
		UDim2.new(1, -16, 0, 26),
		UDim2.fromOffset(10, 4),
		15,
		Ui.colors.muted
	)
	type Card = { frame: Frame, count: TextLabel, bar: Frame, collected: TextLabel }
	local cards: { [string]: Card } = {}
	for index, rarity in ipairs(TIERS) do
		local card = Ui.panel(
			rarityPanel,
			UDim2.new(1, -20, 0, 70),
			UDim2.fromOffset(10, 32 + (index - 1) * 76)
		)
		card.Name = "Card_" .. rarity
		local icon = Ui.panel(card, UDim2.fromOffset(52, 52), UDim2.fromOffset(8, 9))
		local image = Instance.new("ImageLabel")
		image.Size, image.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		image.ScaleType = Enum.ScaleType.Crop
		image.Image = Config.artifacts.tiers[rarity].image or ""
		image.Parent = icon
		local numeral = Ui.label(
			icon,
			string.upper(string.sub(t("artifact_tier_" .. rarity), 1, 1)),
			UDim2.fromScale(1, 1),
			UDim2.new(),
			22,
			COLORS[rarity]
		)
		numeral.TextXAlignment = Enum.TextXAlignment.Center
		numeral.Visible = image.Image == ""
		Ui.label(
			card,
			t("artifact_tier_" .. rarity),
			UDim2.fromOffset(140, 22),
			UDim2.fromOffset(70, 8),
			15,
			COLORS[rarity]
		)
		local count = Ui.label(
			card,
			"",
			UDim2.fromOffset(80, 22),
			UDim2.new(1, -90, 0, 8),
			15,
			Ui.colors.money
		)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local track = Ui.inset(card, UDim2.new(1, -82, 0, 10), UDim2.fromOffset(70, 34))
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = Ui.colors.buttonBlue
		bar.BorderSizePixel = 0
		bar.Parent = track
		local collected = Ui.label(
			card,
			"",
			UDim2.new(1, -82, 0, 18),
			UDim2.fromOffset(70, 46),
			13,
			Ui.colors.muted
		)
		local hit = Instance.new("TextButton")
		hit.Size, hit.BackgroundTransparency, hit.Text = UDim2.fromScale(1, 1), 1, ""
		hit.Parent = card
		hit.Activated:Connect(function()
			tier = rarity
			album = false
		end)
		cards[rarity] = { frame = card, count = count, bar = bar, collected = collected }
	end
	-- left: finds
	local findsPanel = Ui.panel(body, UDim2.new(0, LEFT, 1, -272), UDim2.fromOffset(0, 270))
	Ui.label(
		findsPanel,
		"⌚ " .. t("artifact_finds"),
		UDim2.new(1, -16, 0, 26),
		UDim2.fromOffset(10, 4),
		15,
		Ui.colors.muted
	)
	local findsEmpty = Ui.label(
		findsPanel,
		t("artifact_finds_empty"),
		UDim2.new(1, -20, 1, -40),
		UDim2.fromOffset(10, 32),
		14,
		Ui.colors.muted
	)
	findsEmpty.TextXAlignment = Enum.TextXAlignment.Center
	findsEmpty.TextWrapped = true
	local findLabels: { TextLabel } = {}
	for index, rarity in ipairs(TIERS) do
		local l = Ui.label(
			findsPanel,
			"",
			UDim2.new(1, -20, 0, 22),
			UDim2.fromOffset(10, 32 + (index - 1) * 26),
			14,
			COLORS[rarity]
		)
		findLabels[index] = l
	end

	-- right: picture + mosaic
	local right = Ui.panel(body, UDim2.new(1, -LEFT - 8, 1, -54), UDim2.fromOffset(LEFT + 8, 0))
	local pictureName =
		Ui.label(right, "", UDim2.new(1, -120, 0, 28), UDim2.fromOffset(10, 4), 15, Ui.colors.text)
	local pictureCount = Ui.label(
		right,
		"",
		UDim2.fromOffset(100, 28),
		UDim2.new(1, -110, 0, 4),
		15,
		Ui.colors.money
	)
	pictureCount.TextXAlignment = Enum.TextXAlignment.Right
	local mosaic = Ui.inset(
		right,
		UDim2.fromOffset(3 * TILE + 16, 3 * TILE + 16),
		UDim2.new(0.5, -(3 * TILE + 16) / 2, 0, 36)
	)
	local tiles: { Frame } = {}
	local images: { ImageLabel } = {}
	local numerals: { TextLabel } = {}
	for index = 1, 9 do
		local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
		local tile = Ui.panel(
			mosaic,
			UDim2.fromOffset(TILE, TILE),
			UDim2.fromOffset(8 + column * TILE, 8 + row * TILE)
		)
		tile.ClipsDescendants = true
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(3 * TILE, 3 * TILE)
		image.Position = UDim2.fromOffset(-column * TILE, -row * TILE)
		image.Parent = tile
		local numeral =
			Ui.label(tile, ROMAN[index], UDim2.fromScale(1, 1), UDim2.new(), 28, Ui.colors.muted)
		numeral.TextXAlignment = Enum.TextXAlignment.Center
		numeral.ZIndex = image.ZIndex + 1
		tiles[index], images[index], numerals[index] = tile, image, numeral
	end
	local assemble = Ui.button(
		body,
		t("artifact_create"),
		UDim2.new(1, -LEFT - 8, 0, 44),
		UDim2.new(0, LEFT + 8, 1, -46),
		Ui.colors.buttonGreen
	)
	assemble.TextSize = 17
	assemble.Activated:Connect(function()
		if assemble.Interactable then
			Remotes.event("ArtifactAssemble"):FireServer(tier)
		end
	end)
	-- album: assembled artifacts per rarity
	local albumFrame = Ui.panel(body, UDim2.new(1, -LEFT - 8, 1, -8), UDim2.fromOffset(LEFT + 8, 0))
	local albumLabels: { [string]: TextLabel } = {}
	for index, rarity in ipairs(TIERS) do
		local card = Ui.panel(
			albumFrame,
			UDim2.new(1, -20, 0, 70),
			UDim2.fromOffset(10, 10 + (index - 1) * 78)
		)
		Ui.label(
			card,
			t("artifact_tier_" .. rarity),
			UDim2.new(0.5, 0, 0, 30),
			UDim2.fromOffset(12, 8),
			16,
			COLORS[rarity]
		)
		albumLabels[rarity] = Ui.label(
			card,
			"",
			UDim2.new(1, -24, 0, 24),
			UDim2.fromOffset(12, 38),
			14,
			Ui.colors.muted
		)
	end

	local function refresh(p: Types.Profile?)
		profile = p
		right.Visible, assemble.Visible, albumFrame.Visible = not album, not album, album
		for index, button in ipairs(tabs) do
			button.BackgroundColor3 = if album == (index == 2)
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		local anyFind = false
		for index, rarity in ipairs(TIERS) do
			local state = if p and p.artifacts then p.artifacts[rarity] else nil
			local owned = 0
			for i = 1, 9 do
				if state and (state.fragments[i] or 0) > 0 then
					owned += 1
				end
			end
			local card = cards[rarity]
			card.frame.BackgroundColor3 = if rarity == tier and not album
				then Ui.colors.buttonBlue
				else Ui.colors.panel
			card.frame.BackgroundTransparency = if rarity == tier and not album
				then 0.1
				else Ui.colors.panelTransparency
			card.count.Text = string.format("%d / 9", owned)
			card.bar.Size = UDim2.fromScale(owned / 9, 1)
			card.collected.Text = t("artifact_collected", if state then state.completed else 0)
			local completed = if state then state.completed else 0
			local definition = Config.artifacts.tiers[rarity]
			findLabels[index].Text = if completed > 0
				then string.format(
					"%s ×%d",
					Strings.artifactPictureName(definition.pictures[1], locale),
					completed
				)
				else ""
			anyFind = anyFind or completed > 0
			albumLabels[rarity].Text = t("artifact_completed", completed)
		end
		findsEmpty.Visible = not anyFind
		local state = if p and p.artifacts then p.artifacts[tier] else nil
		local definition = Config.artifacts.tiers[tier]
		pictureName.Text = "◆ " .. Strings.artifactPictureName(definition.pictures[1], locale)
		local complete = true
		local ownedCount = 0
		for index = 1, 9 do
			local owned = state ~= nil and (state.fragments[index] or 0) > 0
			complete = complete and owned
			ownedCount += if owned then 1 else 0
			tiles[index].BackgroundColor3 = if owned then COLORS[tier] else Ui.colors.slot
			tiles[index].BackgroundTransparency = if owned then 0.6 else 0.2
			images[index].Image = definition.image or ""
			images[index].Visible = owned
				and typeof(definition.image) == "string"
				and definition.image ~= ""
			numerals[index].Visible = not images[index].Visible
			numerals[index].TextColor3 = if owned then Ui.colors.text else Ui.colors.muted
		end
		pictureCount.Text = string.format("%d / 9", ownedCount)
		assemble.Interactable = complete
		assemble.BackgroundColor3 = if complete then Ui.colors.buttonGreen else Ui.colors.buttonGrey
	end
	for _, button in ipairs(tabs) do
		button.Activated:Connect(function()
			refresh(profile)
		end)
	end
	for _, card in pairs(cards) do
		local hit = card.frame:FindFirstChildOfClass("TextButton")
		if hit then
			hit.Activated:Connect(function()
				refresh(profile)
			end)
		end
	end
	refresh(profile)
	return win, refresh
end

return ArtifactWindow
