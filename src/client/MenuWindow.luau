--!strict
-- «Меню» [X] — every window in one place, like the original's main menu tiles (Шахты и локации, Повышение уровня,
-- Фракции, Хранилище, …) [вики MENUS-SOCIAL; владелец 27.10: «в меню нужно хранение бустеров … и аукцион»]: a tile
-- per window with its picture, name and key. On a phone the touch menu grid plays this part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
export type Entry = { kind: string, caption: string, key: string, icon: string? }

local MenuWindow = {}

local TILE_W, TILE_H, GAP, COLS = 150, 96, 8, 4

-- the tiles in the order of the original menu; `icon` overrides menu_<kind>
MenuWindow.ENTRIES = {
	{ kind = "locations", caption = "locations", key = "M" },
	{ kind = "level", caption = "level_up", key = "U" },
	{ kind = "upgrade", caption = "upgrade", key = "J" },
	{ kind = "jobs", caption = "jobs", key = "O" },
	{ kind = "achievements", caption = "achievements", key = "L" },
	{ kind = "boosters", caption = "boosters_title", key = "B" },
	{ kind = "auction", caption = "auction_title", key = "Y" },
	{ kind = "artifacts", caption = "artifacts", key = "I" },
	{ kind = "factions", caption = "factions_title", key = "G" },
	{ kind = "inventory", caption = "inventory", key = "E" },
	{ kind = "layout", caption = "touch_layout", key = "H" },
	{ kind = "settings", caption = "settings_title", key = "P" },
} :: { Entry }

function MenuWindow.build(
	parent: Instance,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow,
	onPick: (kind: string) -> ()
): Frame
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local rows = math.ceil(#MenuWindow.ENTRIES / COLS)
	local win, content = createWindow(
		parent,
		T("menu_title"),
		UDim2.fromOffset(COLS * (TILE_W + GAP) + 4, rows * (TILE_H + GAP) + 50),
		onClose
	)
	win.Name = "Window_Menu"
	for i, entry in ipairs(MenuWindow.ENTRIES) do
		local tile = Ui.button(
			content,
			"",
			UDim2.fromOffset(TILE_W, TILE_H),
			UDim2.fromOffset(
				((i - 1) % COLS) * (TILE_W + GAP),
				math.floor((i - 1) / COLS) * (TILE_H + GAP)
			),
			Ui.colors.buttonGrey
		)
		tile.Name = "Tile_" .. entry.kind
		local picture = Instance.new("ImageLabel")
		picture.AnchorPoint = Vector2.new(0.5, 0)
		picture.Position = UDim2.new(0.5, 0, 0, 8)
		picture.Size = UDim2.fromOffset(44, 44)
		picture.BackgroundTransparency = 1
		picture.ScaleType = Enum.ScaleType.Fit
		picture.ResampleMode = Enum.ResamplerMode.Pixelated
		picture.Image = (
			if entry.icon
				then Config.iconFor(entry.icon)
				else Config.icons.icons["menu_" .. entry.kind]
		) or ""
		picture.Parent = tile
		local caption = Ui.label(
			tile,
			T(entry.caption),
			UDim2.new(1, -8, 0, 18),
			UDim2.fromOffset(4, 54),
			14,
			Ui.colors.white
		)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.TextTruncate = Enum.TextTruncate.AtEnd
		local key = Ui.label(
			tile,
			"[" .. entry.key .. "]",
			UDim2.new(1, -8, 0, 16),
			UDim2.fromOffset(4, 74),
			12,
			Ui.colors.muted
		)
		key.TextXAlignment = Enum.TextXAlignment.Center
		tile.Activated:Connect(function()
			onPick(entry.kind)
		end)
	end
	return win
end

return MenuWindow
