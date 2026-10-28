# Chat UX spec — «чат не мешает играть» (28.10.2026)

> **Superseded 28.10 evening**: the game moved to Roblox's own chat window [владелец: «Давай тогда переводить на чат в роблокс»]. Our feed / panel / gear are gone; see docs/GAME-DESIGN.md §11.5. Kept for the reasoning only.

Owner [28.10, evening]: «МАКСИМУМ УСИЛИЙ К ЧАТУ. Как сделать так, чтобы не мешало игрокам, расположение чата,
размеры». The first version (`src/client/ChatWindow.luau`, stage 3) is a permanent 300×220 dark panel bottom-left
with tabs; in Studio it covered the hotkey hints and the top-left buttons. This spec replaces its look and
behaviour; channels, routing, filtering, commands and the server side stay as they are.

## Principles
1. **Out of the way when closed.** No panel, no tabs, no input while the player plays: only the newest lines,
   and they fade out. Nothing in the closed chat takes clicks or touches (all `Active = false`, no buttons over the
   game) except the small phone chat button.
2. **Full chat only when the player asks for it** (Enter / «/» on a computer, the chat button on a phone, a
   gamepad button if cheap). Closing: Esc, Enter on an empty input, sending a message (computer), the × or the chat
   button (phone), clicking/tapping the game world.
3. **Never over the gameplay centre**, the crosshair, the hotbar, hearts/hunger, the joystick, the jump/action
   buttons, the right stats panel, the top-left Artifacts/Menu buttons, Roblox's top bar.
4. **Readable on any background**: white text with a thin dark stroke or a per-line dark backing (Minecraft
   style), not one big opaque panel.
5. **Scales with the screen** (UIScale by viewport height, clamped), works from 360×640 phones to 4K.
6. **Player control**: the HUD editor [H] can move and resize the chat like the other HUD elements (HudLayout);
   Settings get a «Чат» section.

## Computer
- **Closed («лента»)**: bottom-left. The last `feedLines` (default 8) lines of the active tab + system lines,
  each line on its own semi-transparent black backing (≈ 0.55 transparency → fully transparent), text 16 px at
  1080p. A line stays `fadeSeconds` (default 10 s, vanilla Minecraft) then fades over 1 s. Hovering does nothing.
  Tabs are not shown; a small «+N» unread marker can sit above the feed only when another tab got messages
  (fades with the feed).
- **Open**: the same corner grows into the panel: compact tab pills on top (Общий, Глобальный, Фракция, Банда —
  hide Фракция / Банда when the player has none), a scrollable history (last 100 lines per tab, newest at the
  bottom, the mouse wheel scrolls, new lines do not yank the view while the player scrolled up — show «↓ новые»),
  the input line at the bottom with the channel hint («Сообщение… ! — все серверы, @ — фракция, # — банда»).
  Background dark ≈ 0.35 transparency. The mouse is free while open (MouseBehavior Default / MouseIconEnabled).
- **Size and place** (computed, then the player's HudLayout offset/scale applied):
  width = clamp(0.32 × vw, 320, 560) (before UIScale), but never past the hotbar's left edge − 12 px;
  open height = clamp(0.38 × vh, 180, 420); closed feed height = what `feedLines` need.
  The bottom sits above the bottom edge by 12 px; if the hotbar or hearts reach that far left on narrow screens,
  the chat sits above them instead. The left hotkey hint list fades out while the chat is open (or the chat top is
  clamped below it — choose whichever never overlaps; check with the real rects).
- Typing must not trigger game hotkeys (all hotkey handlers already check `gameProcessed` — verify, and also that
  WASD movement stops while the TextBox has focus, which Roblox does by default).

## Phone / tablet (touch, no keyboard; `UserInputService.TouchEnabled and not KeyboardEnabled`, or
workspace attribute `ForceMobile` in Studio)
- The joystick is bottom-left and the action buttons bottom-right, so the chat lives **top-left**, below
  Roblox's top bar (`GuiService:GetGuiInset()`) and our top-left buttons.
- **Closed**: a round chat button (our icon style, 44 px, unread badge) next to/under the menu button, plus a
  thin feed of the last 3 lines (14 px, max width 42 % of the screen, same fade) under it. The feed takes no
  touches.
- **Open**: a panel from the top inset down to ~48 % of the screen height (the on-screen keyboard covers the lower
  half), width min(46 % vw, 440); tabs, history, input at the panel's bottom; a × button. Opening focuses the
  input only when the player taps the input (so reading does not pop the keyboard).
- Tap targets ≥ 36 px.

## Gamepad (cheap)
- DPadUp or ButtonSelect toggles the open chat if no other binding uses it; otherwise skip.

## Bubbles
- Turn on Roblox bubble chat over heads for the Общий (local) channel: `TextChatService.BubbleChatConfiguration`
  Enabled, short `BubbleDuration` (≈ 8 s), max distance ≈ 60 studs, our dark style (BackgroundColor3, TextColor3,
  font). Faction / gang / global / system lines never make bubbles.

## Settings («Чат» section in SettingsWindow, saved in the profile settings like the other switches)
- Размер чата: Маленький / Средний / Большой (scale 0.85 / 1 / 1.2).
- Прозрачность фона ленты (3 steps).
- Скрывать ленту: через 10 с (default) / никогда / всегда скрыта (only the open chat shows messages).
- Пузыри над головами: вкл/выкл.
- Советы: on/off (exists), Глобальный чат в ленте: вкл/выкл (global lines only in the open «Глобальный» tab).

## Spam control in the view
- Identical consecutive lines from the same sender collapse into one with «×N».
- System announcements: max 1 line per 2 s in the feed (queue, drop duplicates).

## HUD editor
- Register the chat with `HudLayout` (movable + scalable like the effects icons). Show a sample feed while the
  editor is open so it can be placed.

## QA
- `ServerStorage.ChatDebug` / a client hook `ClientDebug` → `chatLayout(w, h, touch)` returns the computed rects
  of the closed feed and the open panel for a fake viewport, plus the rects of the HUD elements it checked, and
  `overlaps = {...}`; test 1920×1080, 1366×768, 1280×720, 2560×1440, phone 844×390, 667×375, tablet 1024×768.
- `chatSpam(n)` pushes n test lines (feed fade, scrolling, ×N collapse).

## Owner additions [владелец 28.10, evening]
1. **Gear (⚙) in the corner of the open panel** → a compact quick-settings popover right there: chat size
   (smaller / bigger), background transparency, «Кнопка чата» (computer) and «Выключить чат». The same values as the
   Settings «Чат» section (one source of truth: the profile settings).
2. **«Выключить чат»**: the chat (feed, panel, phone button) disappears completely; one toast «Чат выключен. Включить
   снова: Меню → Настройки → Чат». Enter / «/» do nothing while it is off (commands too: off = off). Re-enabled in
   Settings «Чат».
3. **Closed state exactly like Minecraft**: player messages appear bottom-left and fade; when nobody writes, nothing
   of the chat is visible at all.
4. **«Кнопка чата» as an option**: on a computer an optional small chat button (off by default; a switch in Settings
   «Чат» and in the gear popover) that opens the chat by click; on a phone the button always stays (it is the only
   way to open the chat), small and unobtrusive.
