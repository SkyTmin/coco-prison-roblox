--!strict
-- «Повышение уровня» [U] [меню 26.10, wiki/in-game-wiki/LEVELS.md; владелец 27.10: «меню улучшения уровня нужно больше
-- интерактивности»; «уровень выглядит так себе. Включай дизайнерскую мощь. И раздели картинку по рангам»]:
--   * a header in the colours of the player's rank (Ranks: every 10 levels, its own emblem): the emblem floating, the
--     rank name, «Уровень 11 → 12», and the rank track — the five emblems on a line, the passed ones lit, ours ringed;
--   * left: «Общий прогресс» as a big number with its bar (the mean of the two requirements, each at most 100 %:
--     77.69K / 82.1K blocks and a full balance gave 97 % in the original) and the ten levels of the rank as cells;
--   * right: «Требования 1 / 2» — a card per requirement with its picture and bar; the missing number red, the goal
--     green, a met card green with a tick;
--   * «Улучшения N»: what the level gives as tiles — the new location over its preview picture, hearts, skill points;
--   * the button: in the rank's colours and glowing when everything is met, otherwise grey with what is missing.
-- The window is built once and updated in place (the profile changes many times a second while digging): the bars
-- slide. After a level-up the whole screen shows «Уровень повышен / 12 уровень», a new rank with its emblem.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
type Rank = Ranks.Rank

local LevelWindow = {}

local W, H = 720, 476
local GOOD, BAD = Kit.GOOD, Kit.BAD
local CARD, EDGE, TRACK = Kit.CARD, Kit.EDGE, Kit.TRACK
local SLIDE = Kit.SLIDE
local BOLD = Kit.BOLD
local corner, stroke, frame, text = Kit.corner, Kit.stroke, Kit.frame, Kit.text
local colored, gradient, bar, hoverable = Kit.colored, Kit.gradient, Kit.bar, Kit.hoverable
type Bar = Kit.Bar

-- the rank's emblem: its icon (Codex sheet → Blender like every item picture); until the icon is uploaded a shield
-- drawn in the rank's colours
local function emblem(parent: Instance, rank: Rank, size: number, position: UDim2): GuiObject
	local icon = Config.icons.icons[Ranks.icon(rank)]
	if icon then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(size, size)
		image.Position = position
		image.Image = icon
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = parent
		return image
	end
	local holder = frame(parent, UDim2.fromOffset(size, size), position, Color3.new())
	holder.BackgroundTransparency = 1
	local k = size / 100
	local point = frame(
		holder,
		UDim2.fromOffset(60 * k, 60 * k),
		UDim2.fromOffset(20 * k, 32 * k),
		Color3.new(1, 1, 1)
	)
	point.Rotation = 45
	corner(point, math.max(2, 8 * k))
	local body = frame(
		holder,
		UDim2.fromOffset(84 * k, 64 * k),
		UDim2.fromOffset(8 * k, 4 * k),
		Color3.new(1, 1, 1)
	)
	corner(body, math.max(3, 14 * k))
	for _, part in ipairs({ point, body }) do
		gradient(part, rank.color, rank.dark, 70)
		stroke(part, rank.dark, math.max(1, 2 * k))
	end
	local gem = frame(
		holder,
		UDim2.fromOffset(30 * k, 30 * k),
		UDim2.fromOffset(35 * k, 24 * k),
		Color3.new(1, 1, 1)
	)
	gem.Rotation = 45
	corner(gem, math.max(2, 4 * k))
	gradient(gem, Color3.new(1, 1, 1), rank.color, -45)
	stroke(gem, rank.dark, math.max(1, 1.5 * k))
	return holder
end

function LevelWindow.build(
	parent: Instance,
	locale: string,
	getProfile: () -> Types.Profile?,
	createWindow: CreateWindow,
	onClose: () -> ()
): (Frame, () -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local alive = true
	local win, content = createWindow(parent, T("level_up"), UDim2.fromOffset(W, H), function()
		alive = false
		onClose()
	end)
	win.Name = "Window_Level"
	local innerW = W - 24

	-- ---------------------------------------------------------------- the header: rank, level, the rank track
	local header =
		frame(content, UDim2.new(1, -8, 0, 112), UDim2.fromOffset(4, 2), Color3.new(1, 1, 1))
	corner(header, 10)
	local headerGradient = gradient(header, Color3.new(), Color3.new(), 0)
	local headerEdge = stroke(header, EDGE, 1.5)
	local emblemHolder =
		frame(header, UDim2.fromOffset(100, 100), UDim2.fromOffset(10, 6), Color3.new())
	emblemHolder.BackgroundTransparency = 1
	local rankName = text(
		header,
		"",
		UDim2.fromOffset(254, 34),
		UDim2.fromOffset(120, 16),
		28,
		Color3.new(1, 1, 1),
		BOLD
	)
	local rankStroke = Instance.new("UIStroke")
	rankStroke.Thickness = 2
	rankStroke.Transparency = 0.4
	rankStroke.Parent = rankName
	local levelLine = text(
		header,
		"",
		UDim2.fromOffset(254, 26),
		UDim2.fromOffset(122, 54),
		18,
		Ui.colors.text,
		BOLD
	)
	-- the texts end before the rank track and shrink when longer [владелец 27.10: «текст выходит снова»]
	Kit.fit(rankName)
	Kit.fit(levelLine)
	local rankSpan =
		text(header, "", UDim2.fromOffset(254, 18), UDim2.fromOffset(122, 80), 13, Ui.colors.muted)
	-- the rank track
	-- the last stop, ringed and ×1.22, still ends inside the header (≈ 702 wide)
	local trackX, trackStep = 386, 62
	local line =
		frame(header, UDim2.fromOffset(trackStep * 4, 4), UDim2.fromOffset(trackX + 23, 40), TRACK)
	corner(line, 2)
	local lineFill = frame(line, UDim2.fromScale(0, 1), UDim2.new(), Color3.new(1, 1, 1))
	corner(lineFill, 2)
	type Stop = { holder: Frame, ring: UIStroke, scale: UIScale, caption: TextLabel }
	local stops: { Stop } = {}
	for i, rank in ipairs(Ranks.list) do
		local holder = frame(
			header,
			UDim2.fromOffset(46, 46),
			UDim2.fromOffset(trackX + (i - 1) * trackStep, 19),
			CARD
		)
		holder.ZIndex = 2
		corner(holder, 23)
		local ring = stroke(holder, EDGE, 2)
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		-- the square picture fits inside the circle (its inscribed square is 46 / √2 ≈ 32) [владелец 27.10: «значки
		-- выходят за рамку»]
		local e = emblem(holder, rank, 28, UDim2.fromOffset(9, 9))
		e.ZIndex = 3
		for _, d in ipairs(e:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 3
			end
		end
		local caption = text(
			header,
			string.format("%d–%d", rank.from, rank.to),
			UDim2.fromOffset(60, 16),
			UDim2.fromOffset(trackX + (i - 1) * trackStep - 7, 81),
			12,
			Ui.colors.muted,
			BOLD
		)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		stops[i] = { holder = holder, ring = ring, scale = scale, caption = caption }
	end

	-- ---------------------------------------------------------------- left: total progress, the rank's ten levels
	local bodyY = 124
	local left = frame(content, UDim2.fromOffset(250, 150), UDim2.fromOffset(4, bodyY), CARD)
	corner(left, 10)
	stroke(left, EDGE, 1)
	text(
		left,
		T("level_total_title"),
		UDim2.new(1, -24, 0, 20),
		UDim2.fromOffset(14, 10),
		14,
		Ui.colors.muted,
		BOLD
	)
	local percent = text(
		left,
		"",
		UDim2.new(1, -24, 0, 50),
		UDim2.fromOffset(12, 30),
		46,
		Color3.new(1, 1, 1),
		BOLD
	)
	local totalBar =
		bar(left, UDim2.new(1, -28, 0, 12), UDim2.fromOffset(14, 86), Color3.new(1, 1, 1))
	local rankProgress =
		text(left, "", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(14, 106), 12, Ui.colors.muted)
	local cells: { Frame } = {}
	for i = 1, Ranks.SIZE do
		local cell =
			frame(left, UDim2.fromOffset(19, 8), UDim2.fromOffset(14 + (i - 1) * 22.4, 128), TRACK)
		corner(cell, 3)
		cells[i] = cell
	end

	-- ---------------------------------------------------------------- right: the requirements
	local x0 = 266
	local rightW = innerW - x0 + 10 -- ends with the header (content − 4)
	local reqHeader = text(
		content,
		"",
		UDim2.fromOffset(rightW, 20),
		UDim2.fromOffset(x0, bodyY - 2),
		14,
		Ui.colors.header,
		BOLD
	)
	type Card = {
		frame: Frame,
		edge: UIStroke,
		tick: Frame,
		title: TextLabel,
		value: TextLabel,
		bar: Bar,
	}
	local function card(i: number, picture: string?, glyph: string): Card
		local f = frame(
			content,
			UDim2.fromOffset(rightW, 60),
			UDim2.fromOffset(x0, bodyY + 22 + (i - 1) * 68),
			CARD
		)
		corner(f, 10)
		local edge = stroke(f, EDGE, 1)
		hoverable(f)
		local tile = frame(f, UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 8), TRACK)
		corner(tile, 8)
		if picture then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromOffset(32, 32)
			image.Position = UDim2.fromOffset(6, 6)
			image.Image = picture
			image.ResampleMode = Enum.ResamplerMode.Pixelated
			image.Parent = tile
		else
			local g = text(tile, glyph, UDim2.fromScale(1, 1), UDim2.new(), 24, GOOD, BOLD)
			g.TextXAlignment = Enum.TextXAlignment.Center
		end
		local title = text(
			f,
			"",
			UDim2.new(0.5, -60, 0, 22),
			UDim2.fromOffset(62, 7),
			15,
			Ui.colors.text,
			BOLD
		)
		local value = text(
			f,
			"",
			UDim2.new(0.5, -14, 0, 22),
			UDim2.new(0.5, -40, 0, 7),
			15,
			Ui.colors.text,
			BOLD
		)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local tick = frame(f, UDim2.fromOffset(22, 22), UDim2.new(1, -30, 0, 7), GOOD)
		corner(tick, 11)
		local mark =
			text(tick, "✓", UDim2.fromScale(1, 1), UDim2.new(), 15, Color3.new(1, 1, 1), BOLD)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		local b = bar(f, UDim2.new(1, -74, 0, 10), UDim2.fromOffset(62, 38), Color3.new(1, 1, 1))
		return { frame = f, edge = edge, tick = tick, title = title, value = value, bar = b }
	end
	local textures = Config.textures and Config.textures.textures
	local blocksCard = card(1, textures and textures.cobblestone, "▦")
	local moneyCard = card(2, Config.icons.icons.money, "$")
	-- at the last level the requirement cards make way for the peak: the rank emblem large and the totals
	-- [владелец 27.10: the max-level window stood half empty]
	local peak =
		frame(content, UDim2.fromOffset(rightW, 128), UDim2.fromOffset(x0, bodyY + 22), CARD)
	corner(peak, 10)
	local peakEdge = stroke(peak, EDGE, 1.5)
	local peakWash = frame(peak, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1))
	corner(peakWash, 10)
	local peakGradient = gradient(peakWash, Color3.new(), Color3.new(), 0)
	peakWash.BackgroundTransparency = 0.75
	local peakEmblemHolder =
		frame(peak, UDim2.fromOffset(96, 96), UDim2.fromOffset(14, 16), Color3.new())
	peakEmblemHolder.BackgroundTransparency = 1
	local peakTitle = text(
		peak,
		T("level_peak_title"),
		UDim2.new(1, -134, 0, 30),
		UDim2.fromOffset(122, 18),
		22,
		Color3.new(1, 1, 1),
		BOLD
	)
	Kit.fit(peakTitle)
	local peakRanks = text(
		peak,
		"",
		UDim2.new(1, -134, 0, 20),
		UDim2.fromOffset(122, 54),
		14,
		Ui.colors.text,
		BOLD
	)
	local peakBlocks = text(
		peak,
		"",
		UDim2.new(1, -134, 0, 20),
		UDim2.fromOffset(122, 78),
		14,
		Ui.colors.muted,
		BOLD
	)
	peak.Visible = false

	-- ---------------------------------------------------------------- the rewards
	local rewardsY = bodyY + 160
	local upHeader = text(
		content,
		"",
		UDim2.fromOffset(innerW, 20),
		UDim2.fromOffset(6, rewardsY),
		14,
		Ui.colors.header,
		BOLD
	)
	local rewards =
		frame(content, UDim2.new(1, -8, 0, 60), UDim2.fromOffset(4, rewardsY + 22), Color3.new())
	rewards.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rewards
	local noRewards = text(rewards, "", UDim2.fromScale(1, 1), UDim2.new(), 14, Ui.colors.muted)
	noRewards.Visible = false

	-- ---------------------------------------------------------------- the button
	local button, buttonLabel, buttonBack =
		Kit.actionButton(content, UDim2.new(1, -8, 0, 48), UDim2.new(0, 4, 1, -52), 20)
	button.Name = "LevelUp"
	local buttonGradient = gradient(buttonBack, Color3.new(), Color3.new(), 90)
	local glow = stroke(button, Color3.new(1, 1, 1), 0)
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	local ready = false
	button.Activated:Connect(function()
		pressScale.Scale = 0.95
		TweenService:Create(pressScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		Remotes.event("LevelUp"):FireServer() -- not ready: the server says what is missing
	end)
	button.MouseEnter:Connect(function()
		TweenService:Create(pressScale, TweenInfo.new(0.12), { Scale = 1.02 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(pressScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	-- the living parts: the floating emblem, the glowing button
	local shownEmblem: GuiObject? = nil
	task.spawn(function()
		local t0 = os.clock()
		while alive and win.Parent do
			local t = os.clock() - t0
			if shownEmblem then
				shownEmblem.Position = UDim2.fromOffset(0, math.sin(t * 2) * 3)
			end
			glow.Thickness = if ready then 2 + math.sin(t * 4) * 1.5 else 0
			buttonGradient.Offset = Vector2.new(0, if ready then math.sin(t * 2) * 0.15 else 0)
			task.wait()
		end
	end)

	local function chip(
		order: number,
		width: number,
		picture: string?,
		icon: string?,
		glyph: string,
		glyphColor: Color3,
		caption: string
	)
		local f = frame(rewards, UDim2.fromOffset(width, 60), UDim2.new(), CARD)
		f.LayoutOrder = order
		f.ClipsDescendants = true
		corner(f, 10)
		stroke(f, EDGE, 1)
		hoverable(f)
		if picture then
			-- the new location's preview behind its name, darkened towards the text
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = picture
			image.ScaleType = Enum.ScaleType.Crop
			image.ImageTransparency = 0.25
			image.Parent = f
			local shade = frame(f, UDim2.fromScale(1, 1), UDim2.new(), Color3.new())
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new(0.1, 0.8)
			g.Parent = shade
		end
		if icon then
			local i = Kit.image(f, icon, UDim2.fromOffset(36, 36), UDim2.fromOffset(10, 12))
			i.ZIndex = 2
		else
			local g = text(
				f,
				glyph,
				UDim2.fromOffset(40, 60),
				UDim2.fromOffset(8, 0),
				26,
				glyphColor,
				BOLD
			)
			g.TextXAlignment = Enum.TextXAlignment.Center
			g.ZIndex = 2
		end
		local t = text(
			f,
			caption,
			UDim2.new(1, -56, 1, 0),
			UDim2.fromOffset(52, 0),
			15,
			Color3.new(1, 1, 1),
			BOLD
		)
		-- a one-word caption (a rank name) never breaks inside the word: it shrinks instead
		t.TextWrapped = string.find(caption, " ") ~= nil
		if not t.TextWrapped then
			Kit.fit(t)
		end
		t.ZIndex = 2
		-- the tiles pop in one after another
		local s = Instance.new("UIScale")
		s.Scale = 0.6
		s.Parent = f
		f.BackgroundTransparency = 1
		task.delay(0.07 * order, function()
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			TweenService:Create(f, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		end)
	end

	local function rebuildRewards(level: number, rule: any)
		for _, child in ipairs(rewards:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		type Reward = {
			picture: string?,
			icon: string?,
			glyph: string,
			color: Color3,
			caption: string,
		}
		local items: { Reward } = {}
		for _, location in ipairs(Config.locationsFile.locations) do
			if location.unlockLevel == rule.level and location.id ~= "prison" then
				table.insert(items, {
					picture = Config.previews.previews[location.id],
					glyph = "⌂",
					color = Ui.colors.cyan,
					caption = T(
						"level_reward_location",
						Strings.locationName(location.name, locale)
					),
				})
			end
		end
		local before = Config.levelRule(level)
		local heartsBefore = if before then before.hearts else 10
		if rule.hearts and rule.hearts ~= heartsBefore then
			table.insert(items, {
				-- every picture is a Codex sprite rendered in Blender [владелец 27.10]; the glyph is only a fallback
				icon = Config.icons.icons.heart,
				glyph = "♥",
				color = Color3.fromRGB(235, 55, 55),
				caption = T(
					"level_reward_hearts",
					string.format("%.1f", heartsBefore),
					colored(string.format("%.1f", rule.hearts), GOOD)
				),
			})
		end
		if (rule.skillPoints or 0) > 0 then
			table.insert(items, {
				icon = Config.icons.icons.ancient_star,
				glyph = "★",
				color = Ui.colors.yellow,
				caption = T("level_reward_points", rule.skillPoints),
			})
		end
		local nextRank, ourRank = Ranks.of(rule.level), Ranks.of(level)
		if nextRank.index ~= ourRank.index then
			table.insert(items, 1, {
				icon = Config.icons.icons[Ranks.icon(nextRank)],
				glyph = "♛",
				color = nextRank.color,
				caption = T("level_reward_rank", T("rank_" .. nextRank.index)),
			})
		end
		local width = if #items > 0 then (innerW + 6 - 8 * (#items - 1)) / #items else 0
		for i, item in ipairs(items) do
			chip(i, width, item.picture, item.icon, item.glyph, item.color, item.caption)
		end
		upHeader.Text = T("level_upgrades", #items)
	end

	local shownLevel = -1
	local function paintRank(rank: Rank)
		headerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rank.dark),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 21, 28)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 17, 22)),
		})
		headerEdge.Color = rank.color
		headerEdge.Transparency = 0.55
		rankName.Text = T("rank_" .. rank.index)
		rankName.TextColor3 = rank.color
		rankStroke.Color = rank.dark
		rankSpan.Text = T("level_rank_span", rank.from, rank.to)
		for _, child in ipairs(emblemHolder:GetChildren()) do
			child:Destroy()
		end
		local wrap = frame(emblemHolder, UDim2.fromScale(1, 1), UDim2.new(), Color3.new())
		wrap.BackgroundTransparency = 1
		emblem(wrap, rank, 100, UDim2.new())
		shownEmblem = wrap
		for i, stop in ipairs(stops) do
			local passed = i < rank.index
			local here = i == rank.index
			local other = Ranks.list[i]
			stop.ring.Color = if here then other.color elseif passed then other.color else EDGE
			stop.ring.Transparency = if here then 0 elseif passed then 0.5 else 0
			stop.scale.Scale = if here then 1.22 else 1
			stop.caption.TextColor3 = if here then other.color else Ui.colors.muted
			for _, d in ipairs(stop.holder:GetDescendants()) do
				if d:IsA("ImageLabel") then
					d.ImageTransparency = if i > rank.index then 0.65 else 0
				elseif d:IsA("Frame") then
					d.BackgroundTransparency = if i > rank.index then 0.65 else 0
				end
			end
		end
		TweenService:Create(lineFill, SLIDE, {
			Size = UDim2.fromScale((rank.index - 1) / (#Ranks.list - 1), 1),
			BackgroundColor3 = rank.color,
		}):Play()
		totalBar.fill.BackgroundColor3 = rank.color
		percent.TextColor3 = rank.color
		buttonGradient.Color = ColorSequence.new(rank.color, rank.dark)
	end

	local function refresh()
		local profile = getProfile()
		if not profile then
			return
		end
		local rank = Ranks.of(profile.level)
		local rule = Config.levelRule(profile.level + 1)
		if profile.level ~= shownLevel then
			paintRank(rank)
		end
		for i, cell in ipairs(cells) do
			local level = rank.from + i - 1
			cell.BackgroundColor3 = if level <= profile.level then rank.color else TRACK
			cell.BackgroundTransparency = if level == profile.level + 1 then 0.5 else 0
		end
		rankProgress.Text = T("level_rank_progress", profile.level - rank.from + 1, Ranks.SIZE)
		if not rule then
			levelLine.Text = T("level_number", profile.level)
				.. "  ·  "
				.. colored(T("level_max"), rank.color)
			percent.Text = "100%"
			totalBar.set(1)
			reqHeader.Text = T("level_peak_header")
			blocksCard.frame.Visible, moneyCard.frame.Visible = false, false
			peak.Visible = true
			peakGradient.Color = ColorSequence.new(rank.color, rank.dark)
			peakEdge.Color = rank.color
			peakRanks.Text = T("level_peak_ranks", #Ranks.list, #Ranks.list)
			peakBlocks.Text = T("level_peak_blocks", Strings.big(profile.blocksTotal))
			if profile.level ~= shownLevel then
				peakEmblemHolder:ClearAllChildren()
				local e = emblem(peakEmblemHolder, rank, 96, UDim2.new())
				Kit.bob(e, 3)
				-- the five ranks in a row, the whole way walked
				upHeader.Text = T("level_ranks_title")
				for _, child in ipairs(rewards:GetChildren()) do
					if child:IsA("Frame") then
						child:Destroy()
					end
				end
				local width = (innerW + 6 - 8 * (#Ranks.list - 1)) / #Ranks.list
				for i, r in ipairs(Ranks.list) do
					chip(
						i,
						width,
						nil,
						Config.icons.icons[Ranks.icon(r)],
						"",
						r.color,
						T("rank_" .. r.index)
					)
				end
			end
			button.Visible = true
			buttonLabel.Text = T("level_max")
			buttonLabel.TextColor3 = Color3.new(1, 1, 1)
			buttonGradient.Color = ColorSequence.new(rank.color, rank.dark)
			ready = false
			shownLevel = profile.level
			return
		end
		peak.Visible = false
		blocksCard.frame.Visible, moneyCard.frame.Visible, button.Visible = true, true, true
		levelLine.Text = T("level_number", profile.level)
			.. "  "
			.. colored("→  " .. T("level_number", rule.level), Ranks.of(rule.level).color)
		local needMoney = rule.money * Config.moneyScale
		local kBlocks = math.clamp(profile.blocksTotal / math.max(1, rule.blocks), 0, 1)
		local kMoney = math.clamp(profile.coins / math.max(1, needMoney), 0, 1)
		local total = (kBlocks + kMoney) / 2
		percent.Text = string.format("%d%%", math.floor(total * 100))
		totalBar.set(total)
		local met = (if kBlocks >= 1 then 1 else 0) + (if kMoney >= 1 then 1 else 0)
		reqHeader.Text = T("level_requirements", met, 2)
		local function show(c: Card, title: string, have: string, need: string, k: number)
			local done = k >= 1
			c.title.Text = title
			c.value.Text = colored(have, if done then GOOD else BAD)
				.. "  /  "
				.. colored(need, GOOD)
			c.tick.Visible = done
			c.edge.Color = if done then GOOD else EDGE
			c.bar.fill.BackgroundColor3 = if done then GOOD else rank.color
			c.bar.set(k)
		end
		show(
			blocksCard,
			T("level_blocks"),
			Strings.big(profile.blocksTotal),
			Strings.big(rule.blocks),
			kBlocks
		)
		show(
			moneyCard,
			T("level_balance"),
			Strings.money(profile.coins),
			Strings.big(rule.money),
			kMoney
		)
		ready = met == 2
		if ready then
			buttonLabel.Text = string.upper(T("level_up"))
			buttonGradient.Color = ColorSequence.new(rank.color, rank.dark)
			buttonLabel.TextColor3 = Color3.new(1, 1, 1)
		else
			local missing = {}
			if kBlocks < 1 then
				table.insert(missing, T("level_missing_blocks"))
			end
			if kMoney < 1 then
				table.insert(missing, T("level_missing_money"))
			end
			buttonLabel.Text = T("level_missing", table.concat(missing, ", "))
			buttonGradient.Color =
				ColorSequence.new(Color3.fromRGB(70, 72, 84), Color3.fromRGB(40, 42, 50))
			buttonLabel.TextColor3 = Color3.fromRGB(215, 215, 225)
		end
		if profile.level ~= shownLevel then
			shownLevel = profile.level
			rebuildRewards(profile.level, rule)
		end
	end
	refresh()
	return win, refresh
end

-- «Уровень повышен / 12 уровень» over the whole screen, big and see-through [меню 26.10]; a new rank brings its
-- emblem and name
function LevelWindow.celebrate(parent: Instance, locale: string, level: number, previous: number?)
	local old = parent:FindFirstChild("LevelUpBanner")
	if old then
		old:Destroy()
	end
	local rank = Ranks.of(level)
	local newRank = previous ~= nil and Ranks.of(previous).index ~= rank.index
	local banner = frame(parent, UDim2.fromScale(1, 1), UDim2.new(), Color3.new())
	banner.Name = "LevelUpBanner"
	banner.BackgroundTransparency = 1
	banner.Active = false
	banner.ZIndex = 60
	local band = frame(
		banner,
		UDim2.new(1, 0, 0, if newRank then 260 else 170),
		UDim2.new(0, 0, 0.5, if newRank then -150 else -95),
		rank.dark
	)
	band.BackgroundTransparency = 1
	band.ZIndex = 60
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	local scale = Instance.new("UIScale")
	scale.Scale = 1.35
	scale.Parent = banner
	local labels: { TextLabel } = {}
	local function big(value: string, y: number, size: number, color: Color3)
		local l = text(
			banner,
			value,
			UDim2.new(1, 0, 0, size + 10),
			UDim2.new(0, 0, 0.5, y),
			size,
			color,
			BOLD
		)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextStrokeTransparency = 1
		l.TextTransparency = 1
		l.ZIndex = 61
		table.insert(labels, l)
	end
	local top = if newRank then -140 else -80
	if newRank then
		local e = emblem(banner, rank, 96, UDim2.new(0.5, -48, 0.5, -146))
		e.ZIndex = 62
		for _, d in ipairs(e:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 62
			end
		end
		top = -44
	end
	big(Strings.t("level_up_done", locale), top, 58, Color3.new(1, 1, 1))
	big(Strings.t("level_up_number", locale, level), top + 70, 38, rank.color)
	if newRank then
		big(
			Strings.t("level_new_rank", locale, Strings.t("rank_" .. rank.index, locale)),
			top + 116,
			26,
			rank.color
		)
	end
	TweenService:Create(
		scale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	TweenService:Create(band, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	for _, l in ipairs(labels) do
		TweenService
			:Create(
				l,
				TweenInfo.new(0.3),
				{ TextTransparency = 0.05, TextStrokeTransparency = 0.5 }
			)
			:Play()
	end
	task.delay(if newRank then 3 else 2, function()
		local out = TweenInfo.new(0.7)
		TweenService:Create(band, out, { BackgroundTransparency = 1 }):Play()
		for _, l in ipairs(labels) do
			TweenService:Create(l, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		for _, d in ipairs(banner:GetDescendants()) do
			if d:IsA("ImageLabel") then
				TweenService:Create(d, out, { ImageTransparency = 1 }):Play()
			elseif d:IsA("Frame") and d ~= band then
				TweenService:Create(d, out, { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.75, function()
			banner:Destroy()
		end)
	end)
end

return LevelWindow
