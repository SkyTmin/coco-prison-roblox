--!nocheck
-- Studio Relay plugin: lets a cloud agent run Luau, read the output, take screenshots and start/stop
-- Play in this Studio through the coco-studio-relay Worker. Studio only makes outgoing requests
-- (long-poll); nothing listens on this PC. Pairing: the widget shows a 6-digit code, the owner gives
-- it to the agent, the relay hands this plugin its own token (stored in plugin settings).
-- Runs in every Studio DataModel: "edit", and during a test "server" and "client" (+ "client:<Name>").

local VERSION = "1.0"
local DEFAULT_URL = "__RELAY_URL__"

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")

local function getSetting(key)
	local ok, v = pcall(function()
		return plugin:GetSetting(key)
	end)
	return ok and v or nil
end
local function setSetting(key, value)
	pcall(function()
		plugin:SetSetting(key, value)
	end)
end

local function relayUrl()
	local u = getSetting("RelayUrl")
	if type(u) ~= "string" or u == "" then
		u = DEFAULT_URL
	end
	return (u:gsub("/$", ""))
end

local role
if RunService:IsRunning() then
	role = (RunService:IsClient() and not RunService:IsServer()) and "client" or "server"
else
	role = "edit"
end

local alive = true
plugin.Unloading:Connect(function()
	alive = false
end)

---------------------------------------------------------------- UI (edit only)
local ui = {}
local function setStatus(text)
	ui.statusText = text
	if ui.status then
		ui.status.Text = text
	end
end

local function header(name)
	return name:lower()
end

local function getHeader(res, name)
	for k, v in pairs(res.Headers or {}) do
		if header(k) == name then
			return v
		end
	end
	return nil
end

local function request(method, path, body)
	local opts = {
		Url = relayUrl() .. path,
		Method = method,
		Headers = { Authorization = "Bearer " .. tostring(getSetting("RelayToken") or "none") },
	}
	if body ~= nil then
		opts.Body = body
		opts.Headers["Content-Type"] = "text/plain; charset=utf-8"
		if #body > 16000 then
			opts.Compress = Enum.HttpCompression.Gzip
		end
	end
	return pcall(function()
		return HttpService:RequestAsync(opts)
	end)
end

---------------------------------------------------------------- base64 (fast, buffer based)
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LUT = {}
for i = 1, 64 do
	LUT[i - 1] = string.byte(ALPHA, i)
end
local function base64(b)
	local n = buffer.len(b)
	local out = buffer.create(math.ceil(n / 3) * 4)
	local o = 0
	local i = 0
	while i + 2 < n do
		local v = buffer.readu8(b, i) * 65536
			+ buffer.readu8(b, i + 1) * 256
			+ buffer.readu8(b, i + 2)
		buffer.writeu8(out, o, LUT[bit32.rshift(v, 18)])
		buffer.writeu8(out, o + 1, LUT[bit32.band(bit32.rshift(v, 12), 63)])
		buffer.writeu8(out, o + 2, LUT[bit32.band(bit32.rshift(v, 6), 63)])
		buffer.writeu8(out, o + 3, LUT[bit32.band(v, 63)])
		i += 3
		o += 4
	end
	local rest = n - i
	if rest > 0 then
		local v = buffer.readu8(b, i) * 65536 + (rest == 2 and buffer.readu8(b, i + 1) * 256 or 0)
		buffer.writeu8(out, o, LUT[bit32.rshift(v, 18)])
		buffer.writeu8(out, o + 1, LUT[bit32.band(bit32.rshift(v, 12), 63)])
		buffer.writeu8(out, o + 2, rest == 2 and LUT[bit32.band(bit32.rshift(v, 6), 63)] or 61)
		buffer.writeu8(out, o + 3, 61)
	end
	return buffer.tostring(out)
end

---------------------------------------------------------------- command handlers
local function toText(v)
	if type(v) == "table" then
		local ok, s = pcall(function()
			return HttpService:JSONEncode(v)
		end)
		if ok then
			return s
		end
	end
	return tostring(v)
end

local function compile(code, output)
	local function capture(prefix)
		return function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			table.insert(output, prefix .. table.concat(parts, " "))
		end
	end
	local realPrint, realWarn = print, warn
	local myPrint, myWarn = capture(""), capture("WARN: ")
	local env = setmetatable({
		print = function(...)
			myPrint(...)
			realPrint(...)
		end,
		warn = function(...)
			myWarn(...)
			realWarn(...)
		end,
		plugin = plugin,
	}, { __index = getfenv(0) })

	local okLs, fn, err = pcall(function()
		return loadstring(code)
	end)
	if okLs and fn then
		setfenv(fn, env)
		return fn
	end
	if okLs and not fn and err then
		return nil, "compile: " .. tostring(err)
	end
	-- loadstring unavailable here: fall back to a throwaway ModuleScript
	local m = Instance.new("ModuleScript")
	m.Name = "StudioRelayChunk"
	m.Source = "return function(print, warn, plugin, ...)\n" .. code .. "\nend"
	local okReq, f = pcall(require, m)
	m:Destroy()
	if not okReq then
		return nil, "compile: " .. tostring(f)
	end
	return function(...)
		return f(env.print, env.warn, plugin, ...)
	end
end

local function runCode(code, timeout)
	local output = {}
	local fn, cerr = compile(code, output)
	if not fn then
		return false, { ok = false, output = output, error = cerr }
	end
	local done, packed = false, nil
	task.spawn(function()
		packed = table.pack(xpcall(fn, debug.traceback))
		done = true
	end)
	local deadline = os.clock() + timeout
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	if not done then
		return false,
			{
				ok = false,
				output = output,
				timedOut = true,
				error = "timeout after " .. timeout .. " s",
			}
	end
	if not packed[1] then
		return false, { ok = false, output = output, error = tostring(packed[2]) }
	end
	local vals = {}
	for i = 2, packed.n do
		table.insert(vals, toText(packed[i]))
	end
	return true, { ok = true, output = output, value = table.concat(vals, ", ") }
end

local function screenshot(payload)
	local opts = {}
	pcall(function()
		opts = HttpService:JSONDecode(payload)
	end)
	local maxSide = math.clamp(tonumber(opts.max) or 1024, 64, 1024)
	local CaptureService = game:GetService("CaptureService")
	local AssetService = game:GetService("AssetService")
	local contentId
	local okCap, capErr = pcall(function()
		CaptureService:CaptureScreenshot(function(id)
			contentId = id
		end)
	end)
	if not okCap then
		return false, { error = "CaptureScreenshot: " .. tostring(capErr) }
	end
	local t0 = os.clock()
	while not contentId and os.clock() - t0 < 15 do
		task.wait(0.05)
	end
	if not contentId then
		return false, { error = "no screenshot (is the Studio window minimized?)" }
	end
	local img
	local ok, err = pcall(function()
		img = AssetService:CreateEditableImageAsync(Content.fromUri(contentId))
	end)
	if not ok then
		local ok2, err2 = pcall(function()
			img = AssetService:CreateEditableImageAsync(contentId)
		end)
		if not ok2 then
			return false, { error = "EditableImage: " .. tostring(err) .. " | " .. tostring(err2) }
		end
	end
	local size = img.Size
	local scale = math.min(1, maxSide / size.X, maxSide / size.Y)
	local w, h = math.max(1, math.floor(size.X * scale)), math.max(1, math.floor(size.Y * scale))
	local src = img
	if scale < 1 then
		local okR, errR = pcall(function()
			src = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
			src:DrawImageTransformed(
				Vector2.new(w / 2, h / 2),
				Vector2.new(scale, scale),
				0,
				img,
				{ CombineType = Enum.ImageCombineType.Overwrite }
			)
		end)
		if not okR then
			img:Destroy()
			return false, { error = "resize: " .. tostring(errR) }
		end
	end
	local rgba = src:ReadPixelsBuffer(Vector2.zero, Vector2.new(w, h))
	if src ~= img then
		src:Destroy()
	end
	img:Destroy()
	local rgb = buffer.create(w * h * 3)
	local nonBlack = 0
	for i = 0, w * h - 1 do
		buffer.writeu16(rgb, i * 3, buffer.readu16(rgba, i * 4))
		local b = buffer.readu8(rgba, i * 4 + 2)
		buffer.writeu8(rgb, i * 3 + 2, b)
		if nonBlack == 0 and (b > 8 or buffer.readu16(rgba, i * 4) > 0x0808) then
			nonBlack = 1
		end
	end
	if nonBlack == 0 then
		return false, { error = "screenshot is all black (window minimized or capture refused)" }
	end
	return true, { w = w, h = h, srcW = size.X, srcH = size.Y, b64 = base64(rgb) }
end

local function playControl(kind)
	local StudioTestService = game:GetService("StudioTestService")
	if kind == "stop" then
		local ok, err = pcall(function()
			StudioTestService:EndTest("stopped by relay")
		end)
		return ok,
			{
				ok = ok,
				error = ok and nil or tostring(err),
				value = ok and "stopping" or nil,
				output = {},
			}
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if kind == "runmode" then
				StudioTestService:ExecuteRunModeAsync({})
			else
				StudioTestService:ExecutePlayModeAsync({})
			end
		end)
		if not ok then
			warn("[StudioRelay] " .. kind .. ": " .. tostring(err))
		end
	end)
	return true, { ok = true, value = kind .. " requested", output = {} }
end

local busy = 0
local function handle(id, kind, timeout, payload)
	busy += 1
	setStatus("Выполняю команду: " .. kind)
	local ok, result
	local okAll, errAll = pcall(function()
		if kind == "run" then
			ok, result = runCode(payload, timeout)
		elseif kind == "screenshot" then
			ok, result = screenshot(payload)
		elseif kind == "play" or kind == "runmode" or kind == "stop" then
			ok, result = playControl(kind)
		elseif kind == "ping" then
			ok, result = true, { ok = true, value = role .. " " .. VERSION, output = {} }
		else
			ok, result = false, { error = "unknown kind " .. tostring(kind) }
		end
	end)
	if not okAll then
		ok, result = false, { error = "plugin: " .. tostring(errAll) }
	end
	local okEnc, body = pcall(function()
		return HttpService:JSONEncode(result)
	end)
	if not okEnc then
		ok, body = false, '{"error":"result not encodable"}'
	end
	for _ = 1, 3 do
		local sent, res = request(
			"POST",
			"/plugin/result?id=" .. HttpService:UrlEncode(id) .. "&ok=" .. (ok and "1" or "0"),
			body
		)
		if sent and res.StatusCode < 500 then
			break
		end
		task.wait(1)
	end
	busy -= 1
	if busy == 0 then
		setStatus("Подключено, жду команды")
	end
end

---------------------------------------------------------------- logs
local pendingLogs = {}
LogService.MessageOut:Connect(function(msg, msgType)
	if #pendingLogs < 1000 then
		table.insert(
			pendingLogs,
			{ t = os.time(), type = msgType.Name, msg = string.sub(msg, 1, 4000) }
		)
	end
end)

local function flushLogs()
	if #pendingLogs == 0 or not getSetting("RelayToken") or getSetting("RelayPaused") then
		return
	end
	local batch = pendingLogs
	pendingLogs = {}
	local okEnc, body = pcall(function()
		return HttpService:JSONEncode(batch)
	end)
	if okEnc then
		request("POST", "/plugin/logs?target=" .. role, body)
	end
end

task.spawn(function()
	while alive do
		task.wait(2)
		flushLogs()
	end
end)

---------------------------------------------------------------- main poll loop
local function targets()
	if role == "client" then
		local lp = Players.LocalPlayer
		return "client" .. (lp and (",client:" .. lp.Name) or "")
	end
	return role
end

local function pollLoop()
	local fails = 0
	while alive do
		if not getSetting("RelayToken") then
			setStatus("Не подключено. Нажми «Подключить».")
			task.wait(2)
			continue
		end
		if getSetting("RelayPaused") then
			setStatus("Пауза: команды не принимаются")
			task.wait(2)
			continue
		end
		local q = "targets="
			.. HttpService:UrlEncode(targets())
			.. "&wait=15&v="
			.. VERSION
			.. "&placeId="
			.. tostring(game.PlaceId)
			.. "&place="
			.. HttpService:UrlEncode(game.Name)
		local ok, res = request("GET", "/plugin/next?" .. q)
		if not ok then
			fails += 1
			setStatus(
				"Нет связи с реле ("
					.. fails
					.. "): "
					.. string.sub(tostring(res), 1, 120)
			)
			task.wait(math.min(30, 2 * fails))
		elseif res.StatusCode == 401 then
			setSetting("RelayToken", nil)
			setStatus(
				"Доступ отозван. Нажми «Подключить» заново."
			)
		elseif res.StatusCode == 200 then
			fails = 0
			local id = getHeader(res, "x-id")
			local kind = getHeader(res, "x-kind") or "run"
			local timeout = tonumber(getHeader(res, "x-timeout")) or 60
			if id then
				task.spawn(handle, id, kind, timeout, res.Body)
			end
		elseif res.StatusCode == 204 then
			fails = 0
			if busy == 0 then
				setStatus("Подключено, жду команды")
			end
		else
			fails += 1
			setStatus(
				"Ответ реле "
					.. res.StatusCode
					.. ": "
					.. string.sub(res.Body or "", 1, 120)
			)
			task.wait(math.min(30, 2 * fails))
		end
	end
end

---------------------------------------------------------------- pairing (edit only)
local pairing = false
local function startPairing()
	if pairing then
		return
	end
	pairing = true
	ui.code.Text = "…"
	local ok, res = request("POST", "/plugin/pair/start", "")
	if not ok or res.StatusCode ~= 200 then
		ui.code.Text = ""
		setStatus(
			"Не удалось начать: "
				.. string.sub(tostring(ok and res.StatusCode or res), 1, 160)
		)
		pairing = false
		return
	end
	local data = HttpService:JSONDecode(res.Body)
	ui.code.Text = string.sub(data.code, 1, 3) .. " " .. string.sub(data.code, 4, 6)
	setStatus(
		"Напиши этот код агенту в чат. Код действует 10 минут."
	)
	while alive and pairing do
		local ok2, r2 =
			request("GET", "/plugin/pair/poll?pairId=" .. HttpService:UrlEncode(data.pairId))
		if ok2 and r2.StatusCode == 200 then
			local d = HttpService:JSONDecode(r2.Body)
			if d.status == "ok" then
				setSetting("RelayToken", d.token)
				setSetting("RelayPaused", false)
				ui.code.Text = ""
				setStatus("Подключено, жду команды")
				break
			elseif d.status == "expired" then
				ui.code.Text = ""
				setStatus("Код истёк. Нажми «Подключить» ещё раз.")
				break
			end
		else
			task.wait(3)
		end
	end
	pairing = false
end

local function disconnect()
	pairing = false
	if getSetting("RelayToken") then
		request("POST", "/plugin/unpair", "")
	end
	setSetting("RelayToken", nil)
	ui.code.Text = ""
	setStatus("Отключено. Агент больше не имеет доступа.")
end

local function buildUi()
	local toolbar = plugin:CreateToolbar("Studio Relay")
	local button = toolbar:CreateButton(
		"Studio Relay",
		"Связь с облачным агентом",
		"rbxassetid://4458901886"
	)
	button.ClickableWhenViewportHidden = true
	local info =
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 320, 220, 280, 200)
	local widget = plugin:CreateDockWidgetPluginGui("StudioRelayWidget", info)
	widget.Title = "Studio Relay"
	button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.Parent = widget
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight =
		UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local function label(order, size, textSize, bold)
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, 0, size)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(230, 230, 230)
		l.TextSize = textSize
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = ""
		l.Parent = frame
		return l
	end
	local function btn(order, text, color, onClick)
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = color
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.Text = text
		b.Parent = frame
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	ui.status = label(1, 40, 14, false)
	ui.code = label(2, 40, 32, true)
	ui.code.TextXAlignment = Enum.TextXAlignment.Center
	btn(3, "Подключить", Color3.fromRGB(0, 120, 215), function()
		task.spawn(startPairing)
	end)
	local pauseBtn
	pauseBtn = btn(
		4,
		getSetting("RelayPaused") and "Продолжить" or "Пауза",
		Color3.fromRGB(90, 90, 90),
		function()
			local p = not getSetting("RelayPaused")
			setSetting("RelayPaused", p)
			pauseBtn.Text = p and "Продолжить" or "Пауза"
		end
	)
	btn(5, "Отключить и забыть", Color3.fromRGB(170, 40, 40), disconnect)
	local ver = label(6, 16, 11, false)
	ver.TextColor3 = Color3.fromRGB(150, 150, 150)
	ver.Text = "v" .. VERSION .. " · " .. relayUrl():gsub("^https://", "")
	setStatus(ui.statusText or "")
	if not getSetting("RelayToken") then
		widget.Enabled = true
	end
end

if role == "edit" then
	buildUi()
end
task.spawn(pollLoop)
