# Чат на маленьких экранах: исследование (октябрь 2026)

> **[!!] Россия (проверено 28.10.2026):** с 17.12.2025 Roblox отключил в России все социальные функции. Разблокировка 10.06.2026 чат не вернула: игроки из России видят «You can only view system messages. Chat is not available in your region», голос и личные сообщения тоже выключены. Обойти нельзя: смена региона недоступна, VPN ненадёжен, обходить ограничение своим кодом запрещено. Для нас: `CanUserChatAsync` у таких игроков = false, они видят только системные строки (объявления, советы, ответы команд). Общение, нужное для игры (банды, обмен), должно работать **без текстового чата**: карточка игрока, приглашения, /pay, /gift, сигналы банды кнопками. Источники: https://meduza.io/en/news/2026/06/11/russian-kids-can-play-roblox-again-they-just-can-t-talk-to-anyone-in-the-game , https://devforum.roblox.com/t/all-chat-features-in-russia-should-be-unblocked/4462865 , https://roblox.fandom.com/wiki/Chat

Цель: чат, который никогда не мешает, особенно на телефоне. У каждого пункта есть источник.
Пометка **[!]** означает, что пункт расходится с текущим планом или его меняет.

---

## 0. Главное: Roblox меняет правила чата (окт. 2026, это важнее UX)

- **[!] Platform-integrated chat.** Анонс 21–22.10.2026. Сейчас опционально (`TextChatService.PlatformIntegratedChat`, только в Studio). **С февраля 2027 включается всем по умолчанию** (можно отключить), **с мая 2027 обязателен**. После включения код **не может читать текст сообщений**: `TextChatMessage.Text`, `PrefixText` и `Translation` возвращают `""`, а `OnIncomingMessage` из скриптов разработчика не срабатывает. «Обновлённый TextChatService будет единственным способом сделать свой чат».
  https://create.roblox.com/docs/chat/platform-integrated-chat
  https://devforum.roblox.com/t/important-textchatservice-updates-how-to-test-and-what%E2%80%99s-next/4948433
  https://www.gamebusiness.jp/article/2026/10/23/28425.html
- **[!] Свой чат = `TextChannelWindow`.** Это GuiObject внутри ScreenGui, сообщения в нём рисует сам Roblox. Можно задать Size, Position, BackgroundTransparency, цвет, рамку, шрифт (`FontFace`/`UseDefaultFont`) и `Target` (один канал на окно, Global нельзя). Его можно поставить и в SurfaceGui. **Размер текста берётся из настроек игрока**. Задать свой размер шрифта и своё затухание построчно нельзя: в доках о затухании ничего не сказано.
  https://create.roblox.com/docs/reference/engine/classes/TextChannelWindow
  https://gamertagmythras.com/blog/roblox/roblox-platform-integrated-chat-migration (вторичный источник)
- **[!] Наш план «Minecraft-лента: 8/3 строки, по 10 с затухания на строку» в виде своих TextLabel станет невозможен с мая 2027.** Его нужно строить на `TextChannelWindow`: компактное окно и управление его видимостью и прозрачностью целиком. Отдельные строки погасить не получится.
- **Bubble chat не затронут:** `BubbleChatConfiguration` и `OnBubbleAdded` продолжают работать. Нативные пузыри для TextChannelWindow обещают позже. (Те же источники.)
- **Команды** только через `TextChatCommand` (событие Triggered, права проверять на сервере). Разбор текста через `Player.Chatted` и `MessageReceived` перестанет работать. (Те же источники.)
- **[!] Пресеты и быстрые фразы = Quick Words.** Настраиваются в Creator Hub → Configure → Chat → Quick Words: до 3 категорий, в каждой 3–10 фраз короче 25 символов, только на английском (Roblox сам переводит). Фразы проходят модерацию и показываются во вкладках Here/Global. Свои пресеты через `SendAsync` больше не отрисовываются. Допустимы только игровые координационные фразы. Приветствия («Hi») и вопросы запрещены.
  https://create.roblox.com/docs/chat/quick-words
  https://devforum.roblox.com/t/march-26-2026-an-update-on-our-age-check-to-chat-fast-follow-roadmap/4539685 (правила для своих пресетов: метка «system preset», не больше 12 штук, лимит 10 с на отправку; Roblox советует не строить свою систему)

---

## 1. На что жалуются игроки и разработчики

- **Чат съедает экран на телефоне.** Окно TextChatService «съедает массу места на мобиле». Нет надёжного способа узнать, видно ли окно: `GetCore("ChatActive")` не учитывает его затухание.
  https://devforum.roblox.com/t/chatwindowconfiguration-needs-a-visible-property-or-absolutesize-should-change-to-00-if-closed/3261714
- **Окно растёт по высоте и выталкивает поле ввода за экран**, так что писать невозможно. Встречается на части устройств, вероятная причина в ручном ресайзе.
  https://devforum.roblox.com/t/chat-on-mobile-is-too-tall-and-prevents-users-from-speaking/1840260
  https://devforum.roblox.com/t/481168/16
- **Чат закрывает важные кнопки.** На консоли его нельзя выключить, пришлось ставить `HeightScale = 0.75`. Поверх окна чата нельзя положить свой UI.
  https://devforum.roblox.com/t/console-chat-covers-important-ui-elements/3477760
- **Мало позиций для окна** (несколько пресетов). В левом верхнем углу оно накрывает иконки меню.
  https://devforum.roblox.com/t/custom-positions-for-textchatservice/3258774
- **Окно на полэкрана в ширину** (старый баг, обходили через UISizeConstraint).
  https://devforum.roblox.com/t/chat-window-is-massive/2509687
- **`HeightScale` ограничен значением 2** и почти не работает на больших разрешениях.
  https://devforum.roblox.com/t/api-to-resize-the-new-chat-window/2404967
- **Клавиатура закрывает поле ввода.** На iOS в Roblox это исправили 23.10.2023. iOS и Android при этом ведут себя по-разному: на iOS UI сдвигается вверх, на Android вводимый текст показывается вверху под топбаром.
  https://devforum.roblox.com/t/ios-textbox-input-hidden-by-on-screen-keyboard/2338293
  https://devforum.roblox.com/t/make-textbox-entry-consistent-between-android-and-ios/853706
- **Minecraft Bedrock** годами получал баги вида «клавиатура закрывает чат / не вижу, что печатаю». Кроме того, мобильные игроки не могут быстро переотправить сообщение без физической клавиатуры.
  https://bugs.mojang.com/browse/MCPE-23179
  https://bugs.mojang.com/browse/MCPE-171462
- **Злоупотребление эмоутами:** в Clash Royale даже 10 кнопок использовали для токсичности. Supercell сначала отказывалась добавлять «mute», потом добавила.
  https://toucharcade.com/2016/06/14/supercell-doubles-down-on-never-muting-emotes-in-clash-royale
  https://www.pocketgamer.com/clash-royale/supercell-has-pulled-an-about-turn-and-added-a-mute-emotes-option-in-clash-royal

## 2. Паттерны, которые работают

- **Быстрый чат вместо клавиатуры в динамике.** У Clash Royale эмоуты вместо текста, и в бою без чата не обойтись только им. В Brawl Stars пины в колесе эмоутов. В Among Us колесо Quick Chat из 7 категорий; оно появилось в 2021 как «быстрее и безопаснее», и игроки младше 13 лет были ограничены только им.
  https://www.gamesradar.com/among-us-gets-quickchat-wheel-on-all-platforms
  https://among-us.fandom.com/wiki/Quick_Chat
  https://www.exitlag.com/blog/brawl-stars-pin-maker/
- **Свернуть или вывести наружу.** Короткая лента или оверлей в бою, а полноценная история открывается отдельной панелью по кнопке. Это рекомендация «автоскрывающегося оверлея, доступного в одно касание».
  https://bitesizebyte.blogspot.com/2026/02/implementing-real-time-chat-in-mobile.html (блог, мнение)
- **Счётчик непрочитанных на кнопке** вместо постоянно открытого окна: кнопка клана в Clash of Clans, «!» или число.
  https://mobilematters.gg/news/clash-of-clans/clash-of-clans-clan-chat-features
  https://dragon-mania-legends.wiki/wiki/Clan_Chat
- **Отключаемые каналы:** в Tower of Fantasy выключенный канал не показывается на основном экране, но остаётся в меню чата.
  https://progameguides.com/tower-of-fantasy/can-you-hide-the-chat-in-tower-of-fantasy
- **Minecraft Java:** у закрытого чата своя высота (по умолчанию 0.4375 от высоты открытого), есть отдельные настройки ширины и прозрачности фона. Открытый и закрытый чат — два разных размера.
  https://breezewiki.discard.no/minecraft/wiki/Options.txt
  https://help-redesign.zendesk.com/hc/en-us/articles/43045900209293
- **Bubble chat над головой** для локального общения поддерживается Roblox нативно и остаётся доступным при platform-integrated chat.
  https://create.roblox.com/docs/reference/engine/classes/BubbleChatConfiguration
- **Контекстный UI:** во время активной игры показывать только важное.
  https://create.roblox.com/docs/ui/cross-platform-design

## 3. Конкретные цифры

| Параметр | Значение | Источник |
|---|---|---|
| Touch target, iOS | ≥ 44×44 pt | https://www.uxpin.com/studio/blog/responsive-design-touch-devices-key-considerations/ (цитата HIG) |
| Touch target, Android | ≥ 48×48 dp (≈ 9 мм), промежуток ≥ 8 dp | https://support.google.com/accessibility/android/answer/7101858 |
| WCAG | AA ≥ 24×24 px, AAA ≥ 44×44 px | https://github.com/w3c/wcag/issues/1831 |
| Текст iOS | body 17 pt, не меньше ~11 pt (общепринятая планка HIG; на странице HIG проверить не удалось) | https://developer.apple.com/design/human-interface-guidelines/typography |
| Roblox ChatWindow по умолчанию | TextSize 14, BackgroundTransparency 0.3, TextStrokeTransparency 0.5, Left/Top, Height/WidthScale 1 | https://create.roblox.com/docs/chat/chat-window |
| Roblox InputBar по умолчанию | TextSize 14, BackgroundTransparency 0.2, клавиша фокуса `/` (KeyboardKeyCode) | там же |
| Quick Words | 3 категории × 3–10 фраз, < 25 символов | https://create.roblox.com/docs/chat/quick-words |
| Свои пресеты (если всё-таки) | ≤ 12 штук, 10 с между отправками | https://devforum.roblox.com/t/march-26-2026-an-update-on-our-age-check-to-chat-fast-follow-roadmap/4539685 |
| Ввод не-чат текста (таблички) | лимит ≥ 1 мин | https://create.roblox.com/docs/chat/guidelines |
| Таймер затухания | стандарта нет. В Minecraft Java встроенной настройки длительности жизни сообщения нет, она есть только в модах. Наши 10 с — разумное значение, но подтвердить его источником не удалось | https://www.curseforge.com/minecraft/mc-mods/chat-customizer |

## 4. Специфика Roblox: ограничения и советы

- **Обязательно:** любой текстовый чат идёт через TextChatService (Community Standard «Misusing Roblox Systems»). Входящий текст другого игрока фильтруется до показа. `SendAsync` учитывает приватность и родительский контроль. Каналы ЛС помечаются `SetDirectChatRequester`. На жалобы TextChannel отвечает сам. Проверки доступа: `CanUserChatAsync`, `CanUsersChatAsync`, `CanUsersDirectChatAsync`.
  https://create.roblox.com/docs/chat/guidelines
- **Legacy-чат удалён** (дедлайн 30.04.2025, авто-миграция с мая 2025).
  https://devforum.roblox.com/t/update-on-legacy-chat-deprecation-and-textchatservice-migration/3376880
- **Возраст:** с конца 2025 для чата нужна проверка возраста по лицу. Общаться можно только внутри соседних возрастных групп (<9, 9–12, 13–15, 16–17, 18–20, 21+). Детям младше 9 лет чат в experience по умолчанию выключен. **Значит, у заметной части игроков свободного чата нет вовсе, и Quick Words — единственный способ для них что-то сказать.**
  https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
- **Флуд:** сервер Roblox сам ограничивает частоту отправки (статус `Floodchecked`), повторных нарушителей временно блокирует.
  https://robloxapi.github.io/ref/class/TextChatMessage.html
- **Safe area / вырез экрана:** `ScreenGui.ScreenInsets = CoreUISafeInsets` (по умолчанию) обходит вырез экрана и топбар Roblox. Только для фона ставить `None`.
  https://create.roblox.com/docs/reference/engine/enums/ScreenInsets.md
  https://devforum.roblox.com/t/notched-screen-support-full-release/2074324
- **Зоны пальцев:** нижний левый (стик) и нижний правый (прыжок) углы заняты. Свои кнопки ставить относительно кнопки прыжка. Кнопка на 40 % от верха досягаема на телефоне, но не на планшете.
  https://create.roblox.com/docs/ui/cross-platform-design
- **Клавиатура:** заменить системную клавиатуру через API нельзя. `OnScreenKeyboardSize/Position/Visible` ненадёжны. На iOS Roblox сам сдвигает UI вверх.
  https://devforum.roblox.com/t/custom-chat-mobile/1576149
  https://devforum.roblox.com/t/ios-textbox-input-hidden-by-on-screen-keyboard/2338293
- **Готовые примеры:** WinryChat (кросс-платформенный UI поверх TextChatService). Учтите, что он рисует сообщения сам и после мая 2027 устареет.
  https://devforum.roblox.com/t/winrychat-151-open-source-multi-platform-chat-ui-for-textchatservice/3277800

## 5. Рекомендации для coco-prison (телефон + ПК)

1. **[!] Строить чат на `TextChannelWindow` + ChatWindowConfiguration, а не на своих TextLabel.** Включить `PlatformIntegratedChat` в копии места уже сейчас и проверить. Свой рендер сообщений проживёт только до мая 2027.
2. **[!] «Лента с затуханием» = компактное окно TextChannelWindow** (ПК: внизу слева, ~8 строк; телефон: вверху слева, ~3 строки). Затухает всё окно целиком: через 10 с без новых сообщений прозрачность фона и окна уходит в 1. Построчное затухание а-ля Minecraft, скорее всего, недоступно. «Без касаний» достигается тем, что окно не ловит ввод (`Active=false`/`Interactable=false`, проверить).
3. **[!] Размер шрифта задаёт не наш ползунок, а настройки игрока в Roblox.** Из шестерёнки убрать «размер текста» или заменить его на «размер окна» (строки/ширина). Прозрачность и «выключить чат» оставить.
4. **[!] Добавить Quick Words** (3 категории, например «Шахта / Бой / Торговля», до 10 фраз < 25 символов на английском) и кнопку быстрого чата рядом с кнопкой чата на телефоне. Для игроков без проверки возраста это единственный канал, а в PvP печатать некогда.
5. Кнопка открытия чата на телефоне: ≥ 44–48 px, сверху слева, но **не под иконками топбара** (`CoreUISafeInsets`). Показывать на ней бейдж непрочитанных (число или точку), когда чат выключен или лента скрыта.
6. Открытая панель на телефоне: сверху, высота ≤ ~48 % экрана, поле ввода в верхней части панели. Тогда клавиатура его не закроет ни на iOS, ни на Android. Это совпадает с планом. Ручной ресайз не давать (источник бага «окно ушло за экран»), только пресеты размера в шестерёнке и HUD-редакторе с ограничением сверху.
7. Bubble chat для локального чата оставить (план совпадает). Через `BubbleChatConfiguration`: MaxDistance поменьше, чтобы в толпе тюрьмы не было стены пузырей, и опция «пузыри вкл/выкл» в шестерёнке.
8. Команды (/trade, /pay и т. п.) перевести на `TextChatCommand` с проверкой на сервере. От разбора `Chatted` отказаться.
9. Свой антифлуд не писать: Roblox делает Floodchecked сам. Для табличек и ников банд нужен лимит ≥ 1 мин.
10. В HUD-редакторе для окна чата запретить зоны стика и прыжка (нижние углы) и область топбара.
