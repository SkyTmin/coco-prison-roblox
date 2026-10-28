--!strict
-- Where the chat goes (docs/research/chat-ux-spec.md) [владелец 28.10: «МАКСИМУМ УСИЛИЙ К ЧАТУ … чтобы не мешало
-- игрокам, расположение чата, размеры»]. Pure geometry, no instances: ChatWindow feeds it the rects of the HUD it
-- must keep clear of (live: the real AbsolutePosition / AbsoluteSize of the HUD objects; QA: `model`, the same
-- formulas init.client uses, for a fake viewport) and gets the closed feed, the open panel and the phone button back,
-- in screen pixels (ScreenGuis with IgnoreGuiInset), plus the scale their UIScale gets.
--   * Computer: bottom-left. Width clamp(0.32 × vw, 320, 560) logical × the scale, but never past the hotbar's (or the
--     gameplay centre's) left edge − gap; too narrow for that → the chat sits above the hotbar band instead. The
--     feed's bottom rises over whatever it would touch below (the key hints, the hotbar band); the open panel goes
--     down to the margin and the key hints fade out under it. The top never reaches the Artifacts / Menu buttons,
--     the booster bar or Roblox's top bar: the panel gets shorter, the feed shows fewer lines.
--   * Phone / tablet: the joystick is bottom-left and the action buttons bottom-right, so the chat lives top-left: a
--     small round button under the touch menu button, the feed under it (below the booster bar when that reaches
--     so far), the open panel right of the menu column from the top inset down to ~48 % of the height (the on-screen
--     keyboard takes the lower half), never over the crosshair, the joystick or the hotbar.
--   * The scale: by the viewport height (1080 px on a computer, 390 px on a phone), clamped, × the chat size setting
--     × the player's size from the HUD editor.
-- Obstacles are "hard" (never under the chat) or "soft" (allowed under the open panel only — transient or mostly
-- empty: a toast, the booster bar on a phone, the effect icons frame, the teleport countdown); `fade` ones (the key
-- hints) hide while the panel covers them.
local TextService = game:GetService("TextService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ChatLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Input = {
	w: number,
	h: number,
	touch: boolean,
	inset: number, -- Roblox's top bar (GuiService:GetGuiInset().Y)
	hud: { [string]: Rect }, -- the visible HUD elements by name (see HARD / SOFT)
	setting: number, -- the chat size setting (0.85 / 1 / 1.2)
	user: number, -- the player's size from the HUD editor
	lines: number, -- feed lines wanted
	button: boolean, -- the optional chat button on a computer (always there on a phone)
	moved: Vector2?, -- the player's own place of the chat (HUD editor): the anchor point in pixels
}
export type Result = {
	touch: boolean,
	scale: number, -- the viewport scale
	k: number, -- the UIScale of the chat: scale × setting × user
	textSize: number, -- logical
	lineH: number, -- logical height of one feed line
	-- the HudLayout holder (the feed area + the phone button / the optional button): its anchor and logical size
	anchor: Vector2, -- (0, 1) bottom-left on a computer, (0, 0) top-left on a phone
	at: Vector2, -- the anchor point in pixels
	holderSize: Vector2, -- logical
	feedLines: number, -- lines that fit (0 = no room: the feed stays hidden)
	feed: Rect, -- pixels, the area the full feed takes
	feedWidth: number, -- logical
	button: Rect?, -- pixels
	panel: Rect, -- pixels
	panelSize: Vector2, -- logical
	fadeHints: boolean, -- the open panel covers the key hints: they fade out while it is open
	above: boolean, -- computer: too narrow beside the hotbar, so the chat sits above it
}

local cfg = Config.chat
local L = cfg.layout
local P = L.phone

-- how each HUD element is treated (names given by init.client to ChatWindow.hud / produced by `model`)
local DESKTOP_HARD = {
	"topbar",
	"artifacts",
	"menu",
	"boosters",
	"hotbar",
	"stats",
	"effects",
	"toast",
	"language",
	"centre",
	"view",
}
local DESKTOP_SOFT = { "teleport" }
local PHONE_HARD = {
	"topbar",
	"touchMenu",
	"stats",
	"hotbar",
	"inventory",
	"joystick",
	"jump",
	"eat",
	"sprint",
	"attack",
	"view",
	"crosshair",
}
-- hard for the closed feed and the button, allowed under the open phone panel (transient)
local PHONE_FEED_HARD = { "boosters", "toast" }
-- allowed under everything on a phone: the effect icons' frame (mostly empty, the icons sit by the stats), the middle
-- third (only the crosshair box is kept clear), the teleport countdown
local PHONE_SOFT = { "effects", "centre", "teleport" }

local function overlap(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
ChatLayout.overlap = overlap

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

local function round(r: Rect): Rect
	return rect(
		math.floor(r.x + 0.5),
		math.floor(r.y + 0.5),
		math.floor(r.w + 0.5),
		math.floor(r.h + 0.5)
	)
end

local function pick(hud: { [string]: Rect }, names: { string }): { Rect }
	local out = {}
	for _, name in ipairs(names) do
		local r = hud[name]
		if r and r.w > 0 and r.h > 0 then
			table.insert(out, r)
		end
	end
	return out
end

-- the middle third and the crosshair box only narrow the chat; they never push it up or down
local widthOnly: { [Rect]: boolean } = {}

-- raises `bottom` above every obstacle in the lower half of the screen the column [x0, x1] × [bottom − height,
-- bottom] would touch
local function riseAbove(
	obstacles: { Rect },
	x0: number,
	x1: number,
	bottom: number,
	height: number,
	h: number
): number
	for _ = 1, 12 do
		local moved = false
		for _, o in ipairs(obstacles) do
			if
				not widthOnly[o]
				and o.y + o.h / 2 > h / 2
				and o.x < x1
				and o.x + o.w > x0
				and o.y < bottom
				and o.y + o.h > bottom - height
			then
				bottom = o.y - L.gap
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return bottom
end

-- the lowest bottom edge of the obstacles in the upper half the column [x0, x1] passes under (the top limit)
local function topLimit(
	obstacles: { Rect },
	x0: number,
	x1: number,
	h: number,
	inset: number
): number
	local limit = inset
	for _, o in ipairs(obstacles) do
		if not widthOnly[o] and o.y + o.h / 2 <= h / 2 and o.x < x1 and o.x + o.w > x0 then
			limit = math.max(limit, o.y + o.h)
		end
	end
	return limit + L.gap
end

-- the highest top edge of the obstacles below `from` the column [x0, x1] runs into (the bottom limit)
local function bottomLimit(
	obstacles: { Rect },
	x0: number,
	x1: number,
	from: number,
	h: number
): number
	local limit = h - L.margin
	for _, o in ipairs(obstacles) do
		if o.x < x1 and o.x + o.w > x0 and o.y >= from then
			limit = math.min(limit, o.y - L.gap)
		end
	end
	return limit
end

local function desktop(input: Input): Result
	local w, h = input.w, input.h
	local s = math.clamp(h / L.refHeight, L.scaleMin, L.scaleMax)
	local k = s * input.setting * input.user
	local textSize = L.textSize
	local lineH = textSize + 6
	local markerH = 18 -- the «+N» line over the feed
	local buttonH = if input.button then L.button + 4 else 0
	local hard = pick(input.hud, DESKTOP_HARD)
	local hints = input.hud.hints
	local feedObstacles = table.clone(hard)
	if hints then
		table.insert(feedObstacles, hints)
	end
	local x = L.margin
	-- the width: clamp(0.32 × vw) logical, never past the hotbar / the centre − gap
	local width = math.clamp(L.widthShare * w, L.minWidth, L.maxWidth)
	local limitX = w - L.margin
	for _, name in ipairs({ "hotbar", "centre" }) do
		local r = input.hud[name]
		if r then
			limitX = math.min(limitX, r.x - L.gap)
		end
	end
	local above = false
	if width * k > limitX - x then
		if limitX - x >= L.minWidth * k * 0.8 then
			width = (limitX - x) / k
		else -- no room beside the hotbar: above it, as wide as the screen and the centre allow
			above = true
			local centre = input.hud.centre
			local edge = if centre then centre.x - L.gap else w - L.margin
			width = math.min(width, (edge - x) / k)
		end
	end
	local px = width * k
	-- the closed feed: up over the hints and the hotbar band, down from the top limit
	local feedH = input.lines * lineH + markerH
	local anchorAt: Vector2
	local moved = input.moved
	local feedBottom: number
	if moved then
		x = math.clamp(moved.X, 0, math.max(0, w - px))
		feedBottom = math.clamp(moved.Y, 0, h)
	else
		feedBottom = riseAbove(feedObstacles, x, x + px, h - L.margin, (feedH + buttonH) * k, h)
	end
	local top = topLimit(hard, x, x + px, h, input.inset)
	local lines = input.lines
	while lines > 0 and feedBottom - (lines * lineH + markerH + buttonH) * k < top do
		lines -= 1
	end
	anchorAt = Vector2.new(x, feedBottom)
	local fullFeedH = (lines * lineH + markerH) * k
	local feed = rect(x, feedBottom - buttonH * k - fullFeedH, px, fullFeedH)
	local button = if input.button
		then rect(x, feedBottom - L.button * k, L.button * k, L.button * k)
		else nil
	-- the open panel: from the hotbar band's level (the hints fade under it) or the player's own place
	local panelH = math.clamp(L.openShare * h, L.minOpen, L.maxOpen)
	local panelBottom = if moved
		then math.min(feedBottom, h - L.margin)
		else riseAbove(hard, x, x + px, h - L.margin, panelH * k, h)
	local panelTop = topLimit(hard, x, x + px, h, input.inset)
	if panelBottom - panelH * k < panelTop then
		if moved then -- the player put it high: the panel hangs down from the top limit instead
			panelBottom = math.min(bottomLimit(hard, x, x + px, panelTop, h), panelTop + panelH * k)
		end
		panelH = math.max(120, (panelBottom - panelTop) / k)
	end
	local panel = rect(x, panelBottom - panelH * k, px, panelH * k)
	return {
		touch = false,
		scale = s,
		k = k,
		textSize = textSize,
		lineH = lineH,
		anchor = Vector2.new(0, 1),
		at = anchorAt,
		holderSize = Vector2.new(width, lines * lineH + markerH + buttonH),
		feedLines = lines,
		feed = round(feed),
		feedWidth = width,
		button = if button then round(button) else nil,
		panel = round(panel),
		panelSize = Vector2.new(width, panelH),
		fadeHints = hints ~= nil and overlap(panel, hints),
		above = above,
	}
end

local function phone(input: Input): Result
	local w, h = input.w, input.h
	local s = math.clamp(h / P.refHeight, P.scaleMin, P.scaleMax)
	local k = s * input.setting * input.user
	local textSize = P.textSize
	local lineH = textSize + 6
	local hard = pick(input.hud, PHONE_HARD)
	local panelHard = table.clone(hard)
	local feedHard = table.clone(hard)
	for _, r in ipairs(pick(input.hud, PHONE_FEED_HARD)) do
		table.insert(feedHard, r)
	end
	local crosshair = input.hud.crosshair
	local right = if crosshair then crosshair.x - L.gap else w / 2 -- nothing of the chat reaches the crosshair
	local menu = input.hud.touchMenu or rect(8, 64, 56, 56)
	-- the button: centred under the touch menu button (or the player's own place)
	local b = P.button * k
	local bx, by = menu.x + (menu.w - b) / 2, menu.y + menu.h + L.gap
	local moved = input.moved
	if moved then
		bx, by =
			math.clamp(moved.X, 0, math.max(0, w - b)), math.clamp(moved.Y, 0, math.max(0, h - b))
	end
	local button = rect(bx, by, b, b)
	-- the feed: under the button, below whatever sits in its way (the booster bar), up to the joystick
	local feedW = math.max(80, math.min(P.feedShare * w, w - bx - L.margin, right - bx))
	local feedTop = by + b + 6
	for _ = 1, 6 do
		local pushed = false
		for _, o in ipairs(feedHard) do
			if o ~= menu and overlap(rect(bx, feedTop, feedW, lineH * k), o) then
				feedTop = o.y + o.h + L.gap
				pushed = true
			end
		end
		if not pushed then
			break
		end
	end
	local lines = input.lines
	local limit = bottomLimit(feedHard, bx, bx + feedW, feedTop, h)
	while lines > 0 and feedTop + lines * lineH * k > limit do
		lines -= 1
	end
	local feed = rect(bx, feedTop, feedW, lines * lineH * k)
	-- the open panel: right of the menu column, below the top bar, down to ~48 % (or what the keyboard leaves)
	local px = menu.x + menu.w + L.gap
	local top = math.max(input.inset + 6, menu.y)
	local minH = P.minPanel * s
	-- beside the top-left cluster, up to the crosshair and to whatever hard sits in the upper half on the right (the
	-- stats); on a narrow (portrait) screen that leaves too little, so the panel goes below the upper-half HUD instead,
	-- as wide as the screen allows, and stops above the crosshair
	local panelW = math.min(P.panelShare * w, P.panelMax, right - px)
	for _, o in ipairs(panelHard) do
		if
			o ~= menu
			and o.y + o.h / 2 <= h / 2
			and o.x > px
			and o.y < top + minH
			and o.y + o.h > top
		then
			panelW = math.min(panelW, o.x - L.gap - px)
		end
	end
	if panelW < 200 then
		top = topLimit(panelHard, px, w - L.margin, h, input.inset)
		panelW = math.min(P.panelMax, w - L.margin - px)
	end
	local bottom = math.max(P.panelBottomShare * h, top + minH)
	bottom = math.min(bottom, bottomLimit(panelHard, px, px + panelW, top, h))
	local panel = rect(px, top, panelW, bottom - top)
	return {
		touch = true,
		scale = s,
		k = k,
		textSize = textSize,
		lineH = lineH,
		anchor = Vector2.new(0, 0),
		at = Vector2.new(bx, by),
		holderSize = Vector2.new(math.max(P.button, feedW / k), P.button + 6 + lines * lineH),
		feedLines = lines,
		feed = round(feed),
		feedWidth = feedW / k,
		button = round(button),
		panel = round(panel),
		panelSize = Vector2.new(panelW / k, (bottom - top) / k),
		fadeHints = false,
		above = false,
	}
end

function ChatLayout.compute(input: Input): Result
	table.clear(widthOnly)
	for _, name in ipairs({ "centre", "crosshair" }) do
		local r = input.hud[name]
		if r then
			widthOnly[r] = true
		end
	end
	return if input.touch then phone(input) else desktop(input)
end

-- What overlaps what: { "feed×hotbar", … } for the hard obstacles, soft ones separately, the hints that fade.
function ChatLayout.check(result: Result, hud: { [string]: Rect }): ({ string }, { string })
	local hardList, softList = {}, {}
	local function test(name: string, r: Rect?, hardNames: { string }, softNames: { string })
		if not r or r.w <= 0 or r.h <= 0 then
			return
		end
		for _, o in ipairs(hardNames) do
			local q = hud[o]
			if q and overlap(r, q) then
				table.insert(hardList, name .. "×" .. o)
			end
		end
		for _, o in ipairs(softNames) do
			local q = hud[o]
			if q and overlap(r, q) then
				table.insert(softList, name .. "×" .. o)
			end
		end
	end
	if result.touch then
		local feedNames = table.clone(PHONE_HARD)
		for _, n in ipairs(PHONE_FEED_HARD) do
			table.insert(feedNames, n)
		end
		local panelSoft = table.clone(PHONE_SOFT)
		for _, n in ipairs(PHONE_FEED_HARD) do
			table.insert(panelSoft, n)
		end
		test("feed", if result.feedLines > 0 then result.feed else nil, feedNames, PHONE_SOFT)
		test("button", result.button, feedNames, PHONE_SOFT)
		test("panel", result.panel, PHONE_HARD, panelSoft)
	else
		local feedNames = table.clone(DESKTOP_HARD)
		table.insert(feedNames, "hints")
		test("feed", if result.feedLines > 0 then result.feed else nil, feedNames, DESKTOP_SOFT)
		test("button", result.button, feedNames, DESKTOP_SOFT)
		test("panel", result.panel, DESKTOP_HARD, DESKTOP_SOFT)
	end
	return hardList, softList
end

-- The HUD of init.client for a viewport (the same numbers as its updateLayout) — the QA size matrix without
-- resizing the window. `hintsText` gives the key hints' height (wrapped like the real label).
function ChatLayout.model(
	w: number,
	h: number,
	touch: boolean,
	inset: number,
	hintsText: string,
	boosterRows: number
): { [string]: Rect }
	local hud: { [string]: Rect } = {}
	hud.topbar = rect(0, 0, w, inset)
	local boosterH = if boosterRows > 0 then boosterRows * 28 - 2 else 0
	if not touch then
		hud.artifacts = rect(8, 64, 190, 44)
		hud.menu = rect(204, 64, 130, 44)
		if boosterH > 0 then
			hud.boosters = rect(8, 116, 200, boosterH)
		end
		local hintsW = math.max(40, w / 2 - 270)
		local size =
			TextService:GetTextSize(hintsText, 13, Enum.Font.Code, Vector2.new(hintsW, 10000))
		hud.hints = rect(10, h - 10 - size.Y, hintsW, size.Y)
		local width = 9 * (44 + 4) + 8
		-- the hotbar (56) with the experience bar, the hearts / food, the armour row and the golden hearts over it
		hud.hotbar = rect(w / 2 - width / 2, h - 8 - 56 - 82, width, 56 + 82)
		hud.stats = rect(w - 224, 0.4 * h, 214, 160)
		hud.effects = rect(w - 230 - 264, 0.4 * h, 264, 116)
		hud.toast = rect(w - 530, 12, 520, 66)
		hud.language = rect(w - 74, h - 38, 64, 28)
		hud.teleport = rect(w / 2 - 260, h - 180, 520, 28)
		hud.centre = rect(w / 3, h / 3, w / 3, h / 3)
	else
		hud.touchMenu = rect(8, 64, 56, 56)
		if boosterH > 0 then
			hud.boosters = rect(72, 64, 200, boosterH)
		end
		hud.stats = rect(w - 148, 64, 214 * 0.65, 160 * 0.65)
		hud.effects = rect(w - 152 - 264 * 0.75, 64, 264 * 0.75, 116 * 0.75)
		local toastW = math.min(520, w - 20)
		hud.toast = rect(w / 2 - toastW / 2, 12, toastW, 66)
		local size = if w <= 700 then 40 else 44
		local width = 9 * (size + 4) + 8
		local scale = math.min(1, (w - 20) / width)
		hud.hotbar = rect(
			w / 2 - width * scale / 2,
			h - 8 - (size + 12 + 82) * scale,
			width * scale,
			(size + 12 + 82) * scale
		)
		hud.inventory = rect(w / 2 + width / 2 * scale + 6, h - 8 - size - 4, 40, 40)
		local small = math.min(w, h) <= 500
		-- Roblox's thumbstick (its resting ring, generous) and jump button (TouchJump's formula)
		hud.joystick = if small then rect(0, h - 130, 160, 130) else rect(0, h - 230, 260, 230)
		hud.jump = if small then rect(w - 95, h - 90, 70, 70) else rect(w - 170, h - 210, 120, 120)
		hud.eat = rect(w - 180, h - 200, 60, 60)
		hud.sprint = rect(w - 270, h - 94, 64, 64)
		hud.crosshair = rect(w / 2 - 24, h / 2 - 24, 48, 48)
		hud.centre = rect(w / 3, h / 3, w / 3, h / 3)
	end
	return hud
end

return ChatLayout
