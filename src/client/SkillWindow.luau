--!strict
-- «Древо навыков» [меню 26.10, wiki/in-game-wiki/SKILL-TREE.md; владелец 28.10: «умения надо добавить в меню и все
-- прокачки … меню сделай красивым, иконки через кодекс»]: the free points over a row per branch — its emblem (Codex →
-- Blender), name and «2 / 5» — and five nodes on a line: bought ones purple and joined by a purple bar, the next one
-- with a «+» strip, the rest locked. A node or emblem tapped shows its text below with the «Изучить» button (one point,
-- SkillBuy); the oblivion scroll from the hand resets everything (SkillService). Built once, updated in place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local SkillWindow = {}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local W, ROW, ROW_H = 680, 84, 76
local BOUGHT = Color3.fromRGB(104, 58, 205)
local BOUGHT_LIGHT = Color3.fromRGB(150, 100, 255)
local NEXT = Color3.fromRGB(52, 36, 92)
local LINE_OFF = Color3.fromRGB(58, 60, 72)

type Node = {
	button: TextButton,
	label: TextLabel,
	plus: Frame,
	lock: ImageLabel,
	stroke: UIStroke,
}
type Row = {
	branch: Skills.Branch,
	count: TextLabel,
	nodes: { Node },
	lines: { Frame },
	shown: number,
}

function SkillWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local icons = Config.icons.icons
	local rowsTop = 52
	local infoY = rowsTop + #Skills.branches * ROW + 2
	local win, content =
		createWindow(parent, t("skills_title"), UDim2.fromOffset(W, infoY + 74 + 26 + 46), onClose)
	Ui.titleColor(win, Ui.colors.header)
	local inner = W - 12

	-- header: the free points and when the next one comes
	local head =
		Kit.frame(content, UDim2.fromOffset(inner - 8, 42), UDim2.fromOffset(4, 4), Kit.CARD)
	Kit.corner(head, 8)
	Kit.stroke(head, Kit.EDGE, 1)
	local coin =
		Kit.image(head, icons.skill_point, UDim2.fromOffset(30, 30), UDim2.fromOffset(10, 6))
	Kit.bob(coin, 2, 2.4)
	local pointsLabel = Kit.text(
		head,
		"",
		UDim2.fromOffset(300, 42),
		UDim2.fromOffset(48, 0),
		18,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	local nextLabel =
		Kit.text(head, "", UDim2.new(1, -360, 1, 0), UDim2.fromOffset(350, 0), 13, Ui.colors.muted)
	nextLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- the text of the chosen emblem / node with its button
	local info =
		Kit.frame(content, UDim2.fromOffset(inner - 8, 70), UDim2.fromOffset(4, infoY), Kit.CARD)
	Kit.corner(info, 8)
	Kit.stroke(info, Kit.EDGE, 1)
	local infoTitle = Kit.text(
		info,
		"",
		UDim2.new(1, -220, 0, 24),
		UDim2.fromOffset(12, 8),
		16,
		Color3.new(1, 1, 1),
		Kit.BOLD
	)
	local infoText =
		Kit.text(info, "", UDim2.new(1, -220, 0, 32), UDim2.fromOffset(12, 32), 13, Ui.colors.text)
	infoText.TextWrapped = true
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	local learn, learnLabel, learnBack =
		Kit.actionButton(info, UDim2.fromOffset(190, 46), UDim2.new(1, -202, 0, 12), 15)
	Kit.pressable(learn)
	local learnGlow = Kit.glow(learn, BOUGHT_LIGHT)
	local hint = Kit.text(
		content,
		t("skills_reset_hint"),
		UDim2.new(1, -40, 0, 20),
		UDim2.fromOffset(32, infoY + 76),
		12,
		Ui.colors.muted
	)
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	Kit.image(
		content,
		icons.oblivion_scroll,
		UDim2.fromOffset(20, 20),
		UDim2.fromOffset(6, infoY + 76)
	)

	local selected: { branch: string, level: number? } =
		{ branch = Skills.branches[1].id, level = nil }
	local rows: { Row } = {}
	local refresh: (Types.Profile?) -> ()
	local function color(branch: Skills.Branch): Color3
		return Color3.fromRGB(branch.color[1], branch.color[2], branch.color[3])
	end
	local function nodeText(id: string, level: number): string
		local key = "skill_node_" .. id .. "_" .. level
		if Strings.has(key, locale) then
			return t(key)
		end
		local branch = Skills.branch(id)
		if id == "lucky" and branch then
			return t(
				"skill_node_lucky",
				math.floor((branch.keyChanceBonus or 0) * level * 100 + 0.5)
			)
		elseif id == "hunter" and branch and branch.doubleKill then
			return t("skill_node_hunter", math.floor((branch.doubleKill[level] or 0) * 100 + 0.5))
		end
		return ""
	end

	for i, branch in ipairs(Skills.branches) do
		local y = rowsTop + (i - 1) * ROW
		local tint = color(branch)
		-- the emblem card
		local card = Instance.new("TextButton")
		card.AutoButtonColor = false
		card.Text = ""
		card.BackgroundColor3 = Kit.CARD
		card.Size, card.Position = UDim2.fromOffset(176, ROW_H), UDim2.fromOffset(4, y)
		card.Parent = content
		Kit.corner(card, 8)
		Kit.stroke(card, Kit.EDGE, 1)
		Kit.hoverable(card)
		Kit.pressable(card)
		local emblem = Kit.image(
			card,
			icons["skill_" .. branch.id],
			UDim2.fromOffset(56, 56),
			UDim2.fromOffset(8, 10)
		)
		emblem.Active = false
		local name = Kit.text(
			card,
			t("skill_" .. branch.id),
			UDim2.fromOffset(104, 24),
			UDim2.fromOffset(70, 14),
			16,
			tint,
			Kit.BOLD
		)
		Kit.fit(name)
		local count = Kit.text(
			card,
			"",
			UDim2.fromOffset(104, 20),
			UDim2.fromOffset(70, 40),
			13,
			Ui.colors.muted
		)
		card.Activated:Connect(function()
			selected = { branch = branch.id, level = nil }
			refresh(profile)
		end)
		-- the line of nodes
		local track = Kit.frame(
			content,
			UDim2.fromOffset(inner - 196, ROW_H),
			UDim2.fromOffset(188, y),
			Kit.CARD
		)
		Kit.corner(track, 8)
		Kit.stroke(track, Kit.EDGE, 1)
		local nodeSize = 56
		local step = (inner - 196 - 40 - nodeSize) / math.max(branch.levels - 1, 1)
		local row: Row = { branch = branch, count = count, nodes = {}, lines = {}, shown = -1 }
		for level = 1, branch.levels - 1 do
			local line = Kit.frame(
				track,
				UDim2.fromOffset(step - nodeSize + 8, 6),
				UDim2.fromOffset(20 + (level - 1) * step + nodeSize - 4, ROW_H / 2 - 3),
				LINE_OFF
			)
			Kit.corner(line, 3)
			row.lines[level] = line
		end
		for level = 1, branch.levels do
			local button = Instance.new("TextButton")
			button.AutoButtonColor = false
			button.Text = ""
			button.Size = UDim2.fromOffset(nodeSize, nodeSize)
			button.Position = UDim2.fromOffset(20 + (level - 1) * step, (ROW_H - nodeSize) / 2)
			button.BackgroundColor3 = Kit.TRACK
			button.ZIndex = 2
			button.Parent = track
			Kit.corner(button, 8)
			local stroke = Kit.stroke(button, Kit.EDGE, 1.5)
			Kit.pressable(button)
			local label = Kit.text(
				button,
				ROMAN[level] or tostring(level),
				UDim2.new(1, 0, 1, -8),
				UDim2.new(),
				18,
				Color3.new(1, 1, 1),
				Kit.BOLD
			)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.ZIndex = 3
			local plus = Kit.frame(button, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -14), BOUGHT)
			Kit.corner(plus, 6)
			plus.ZIndex = 3
			local plusText = Kit.text(
				plus,
				"+",
				UDim2.fromScale(1, 1),
				UDim2.fromOffset(0, -1),
				15,
				Color3.new(1, 1, 1),
				Kit.BOLD
			)
			plusText.TextXAlignment = Enum.TextXAlignment.Center
			plusText.ZIndex = 4
			local lock = Kit.image(
				button,
				icons.ui_lock,
				UDim2.fromOffset(26, 26),
				UDim2.new(0.5, -13, 0.5, -13)
			)
			lock.ZIndex = 3
			button.Activated:Connect(function()
				selected = { branch = branch.id, level = level }
				refresh(profile)
			end)
			row.nodes[level] =
				{ button = button, label = label, plus = plus, lock = lock, stroke = stroke }
		end
		table.insert(rows, row)
	end

	learn.Activated:Connect(function()
		local branch = Skills.branch(selected.branch)
		if not branch or not learn.Active then
			return
		end
		Remotes.event("SkillBuy"):FireServer(branch.id)
	end)

	refresh = function(p: Types.Profile?)
		profile = p
		local free = Skills.free(p)
		pointsLabel.Text = t("skills_points", free)
		-- the next point: the first level above the current one that gives points
		local nextLevel: number? = nil
		for _, rule in ipairs(Config.levels.levels) do
			if p and rule.level > p.level and (rule.skillPoints or 0) > 0 then
				nextLevel = rule.level
				break
			end
		end
		nextLabel.Text = if nextLevel
			then t("skills_next_point", nextLevel)
			else t("skills_all_points")
		for _, row in ipairs(rows) do
			local have = Skills.level(p, row.branch.id)
			row.count.Text = string.format("%d / %d", have, row.branch.levels)
			for level, node in ipairs(row.nodes) do
				local bought = level <= have
				local isNext = level == have + 1
				node.button.BackgroundColor3 = if bought
					then BOUGHT
					elseif isNext then NEXT
					else Kit.TRACK
				node.stroke.Color = if bought or isNext then BOUGHT_LIGHT else Kit.EDGE
				node.stroke.Transparency = if bought then 0.3 elseif isNext then 0 else 0.4
				node.label.Visible = bought or isNext
				node.label.Position = if isNext
					then UDim2.fromOffset(0, -4)
					else UDim2.fromOffset(0, 4)
				node.plus.Visible = isNext and free >= Skills.COST
				node.lock.Visible = not bought and not isNext
				local chosen = selected.branch == row.branch.id and selected.level == level
				if chosen then
					node.stroke.Color = Color3.new(1, 1, 1)
					node.stroke.Transparency = 0
				end
			end
			for level, line in ipairs(row.lines) do
				line.BackgroundColor3 = if level < have then BOUGHT_LIGHT else LINE_OFF
			end
			if row.shown >= 0 and have > row.shown then
				local node = row.nodes[have]
				if node then
					Kit.flash(node.button, BOUGHT_LIGHT)
					Kit.pop(node.button, 1.15)
				end
			end
			row.shown = have
		end
		-- the info panel
		local branch = Skills.branch(selected.branch) or Skills.branches[1]
		local have = Skills.level(p, branch.id)
		local tint = color(branch)
		local level = selected.level
		if level then
			infoTitle.Text = Kit.colored(t("skill_" .. branch.id), tint)
				.. " "
				.. (ROMAN[level] or tostring(level))
			infoText.Text = nodeText(branch.id, level)
		else
			infoTitle.Text = Kit.colored(t("skill_" .. branch.id), tint)
				.. "  "
				.. Kit.colored(string.format("%d / %d", have, branch.levels), Ui.colors.muted)
			infoText.Text = t("skill_desc_" .. branch.id)
		end
		-- the button always buys the branch's next level; its text says why it cannot
		local target = level or have + 1
		local canBuy = Skills.refusal(p, branch.id) == nil and target == have + 1
		learnLabel.Text = if target <= have
			then t("skills_learned")
			elseif have >= branch.levels then t("skills_learned")
			elseif target > have + 1 then t("skills_locked_short")
			elseif free < Skills.COST then t("skills_no_points_short")
			else t("skills_learn")
		learn.Active = canBuy
		TweenService:Create(learnBack, TweenInfo.new(0.15), {
			BackgroundColor3 = if canBuy
				then BOUGHT
				elseif target <= have then Color3.fromRGB(40, 120, 60)
				else Kit.GREY,
		}):Play()
		learnGlow(canBuy)
	end
	refresh(profile)
	return win, refresh
end

return SkillWindow
