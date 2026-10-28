--!strict
-- The Ancient case roulette [владелец 28.10: «когда открывают древний кейс, я хочу анимацию для игрока. Вокруг кейса
-- крутятся книги с названием, как рулетка, и останавливается сверху та книга, которая выпала … пусть крутятся
-- рандомные книги, штук 7 или больше, и книга, которая выпадет»]. The server has already put the book into the case
-- (CaseService) and sends AncientRoll(part, bookId, level, rarity); here, for this player only: the case window hides,
-- a wheel of 8 books (7 random + the dropped one) stands over the case facing the camera, each with its name in its
-- rarity colour, spins fast, slows down and stops with the dropped book at the top under a golden frame; the others
-- fade, the winner flashes and sinks into the case, the window comes back with the book inside. The window must not
-- close meanwhile: closing a case empties it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Sfx = require(Shared.Sfx)
local ItemModels = require(script.Parent.ItemModels)

local AncientRoulette = {}

local COUNT = 8 -- the dropped book + 7 random ones
local RADIUS = 4.2 -- studs
local LIFT = 5.5 -- the wheel centre above the case top
local SPIN_SECONDS = 4.2
local TURNS = 3 -- full turns before the stop
local BOOK_SIZE = Vector2.new(2.6, 3.6) -- billboard studs: the icon and the name under it
local MODEL_SIZE = 2.4 -- the 3D book, studs tall
-- the model's own turn so its cover looks at the camera (the hand model is thin along X: +X goes to the look side)
local BOOK_TURN = CFrame.Angles(0, math.rad(90), 0)

local playing = false

-- cubic ease-out: fast at first, slows to a stop
local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

local function rarityColor(rarity: string?): Color3
	return ItemInfo.RARITY_COLORS[rarity or "common"] or Color3.new(1, 1, 1)
end

-- the 7 other books: random catalog books (other than the dropped one) at a random level
local function fillers(winner: string): { { id: string, level: number, rarity: string } }
	local ids: { string } = {}
	for id in pairs(Config.books.effects) do
		if id ~= winner then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local random = Random.new()
	local out = {}
	for _ = 1, COUNT - 1 do
		if #ids == 0 then
			break
		end
		local id = table.remove(ids, random:NextInteger(1, #ids)) :: string
		local card = Config.books.catalog[id]
		table.insert(out, {
			id = id,
			level = random:NextInteger(1, #Config.books.effects[id]),
			rarity = if card then card.rarity else "common",
		})
	end
	return out
end

local function bookBillboard(
	holder: BasePart,
	id: string,
	level: number,
	rarity: string,
	locale: string
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(BOOK_SIZE.X, BOOK_SIZE.Y)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = holder
	gui.Parent = holder
	local color = rarityColor(rarity)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0)
	glow.Position = UDim2.fromScale(0.5, 0)
	glow.Size = UDim2.fromScale(0.78, 0.6)
	glow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	glow.BackgroundTransparency = 0.25
	glow.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.15, 0)
	round.Parent = glow
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = 2
	edge.Parent = glow
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.86, 0.86)
	icon.Image = Config.iconFor("ancient_book") or ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ResampleMode = Enum.ResamplerMode.Pixelated
	icon.Parent = glow
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.62)
	name.Size = UDim2.fromScale(1, 0.38)
	name.Font = Enum.Font.SourceSansBold
	name.TextScaled = true
	name.TextWrapped = true
	name.TextColor3 = color
	name.TextStrokeTransparency = 0.2
	name.Text = ItemInfo.bookName(id, level, locale)
	name.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = name
	return gui
end

local function fade(gui: BillboardGui, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
end

-- Plays the roulette over `part`; setWindowVisible hides the case window while it runs (called every frame: the
-- window may be rebuilt by a profile update) and shows it at the end.
function AncientRoulette.play(
	part: any,
	bookId: any,
	level: any,
	rarity: any,
	locale: string,
	setWindowVisible: (boolean) -> ()
)
	if
		playing
		or typeof(part) ~= "Instance"
		or not part:IsA("BasePart")
		or typeof(bookId) ~= "string"
		or typeof(level) ~= "number"
	then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	playing = true
	local winnerRarity = if typeof(rarity) == "string" then rarity else "common"
	local books = { { id = bookId, level = level, rarity = winnerRarity } }
	for _, other in ipairs(fillers(bookId)) do
		table.insert(books, other)
	end

	local folder = Instance.new("Folder")
	folder.Name = "AncientRoulette"
	folder.Parent = workspace
	local center = part.Position + Vector3.new(0, part.Size.Y / 2 + LIFT, 0)
	-- the wheel faces the player: its plane holds the camera's flat right vector and the up axis
	local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
	local function holderPart(name: string): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		p.Position = center
		p.Parent = folder
		return p
	end

	-- the golden frame at the top: where the dropped book stops
	local topPart = holderPart("Top")
	topPart.Position = center + Vector3.yAxis * RADIUS
	local frameGui = Instance.new("BillboardGui")
	frameGui.Size = UDim2.fromScale(BOOK_SIZE.X * 1.25, BOOK_SIZE.Y * 0.8)
	frameGui.StudsOffsetWorldSpace = Vector3.new(0, BOOK_SIZE.Y * 0.2 - 0.05, 0)
	frameGui.LightInfluence = 0
	frameGui.AlwaysOnTop = true
	frameGui.Adornee = topPart
	frameGui.Parent = topPart
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = frameGui
	local frameEdge = Instance.new("UIStroke")
	frameEdge.Color = Color3.fromRGB(255, 200, 60)
	frameEdge.Thickness = 3
	frameEdge.Parent = frame
	local frameRound = Instance.new("UICorner")
	frameRound.CornerRadius = UDim.new(0.12, 0)
	frameRound.Parent = frame
	local pulse = Instance.new("UIScale")
	pulse.Parent = frame

	-- the books: the 3D book of the hand (ItemModels) with its name under it; the flat icon if there is no model
	local toward = (camera.CFrame.Position - center) * Vector3.new(1, 0, 1)
	toward = if toward.Magnitude > 0.01 then toward.Unit else Vector3.zAxis
	local holders: { BasePart } = {}
	local guis: { BillboardGui } = {}
	local models: { [number]: Model } = {}
	for i, book in ipairs(books) do
		local holder = holderPart("Book" .. i)
		table.insert(holders, holder)
		local gui = bookBillboard(holder, book.id, book.level, book.rarity, locale)
		table.insert(guis, gui)
		local model = ItemModels.get("ancient_book", nil, MODEL_SIZE)
		if model then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow =
						true, false, false, false, false
				end
			end
			model.Parent = folder
			models[i] = model
			local glow = gui:FindFirstChild("Glow")
			if glow and glow:IsA("Frame") then
				glow.Visible = false
			end
			gui.Size = UDim2.fromScale(BOOK_SIZE.X * 1.4, 0.9)
			gui.StudsOffsetWorldSpace = Vector3.new(0, -MODEL_SIZE / 2 - 0.55, 0)
			local name = gui:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.Position, name.Size = UDim2.new(), UDim2.fromScale(1, 1)
			end
		end
	end
	-- a golden pointer over the top place
	local pointer = Instance.new("Part")
	pointer.Name = "Pointer"
	pointer.Anchored, pointer.CanCollide, pointer.CanQuery, pointer.CanTouch =
		true, false, false, false
	pointer.Material = Enum.Material.Neon
	pointer.Color = Color3.fromRGB(255, 200, 60)
	pointer.Size = Vector3.new(0.55, 0.55, 0.15)
	pointer.CFrame = CFrame.lookAt(
		center + Vector3.yAxis * (RADIUS + MODEL_SIZE / 2 + 0.7),
		center + Vector3.yAxis * (RADIUS + 2) + toward
	) * CFrame.Angles(0, 0, math.rad(45))
	pointer.Parent = folder
	local function pivot(i: number, position: Vector3, scale: number?)
		local model = models[i]
		if model then
			-- the cover faces the player, a slight sway
			model:PivotTo(CFrame.lookAt(position, position + toward) * BOOK_TURN)
			if scale then
				model:ScaleTo(scale)
			end
		end
	end

	local step = 2 * math.pi / #books
	local total = TURNS * 2 * math.pi
	local function place(offset: number)
		for i, holder in ipairs(holders) do
			-- book 1 (the dropped one) sits at the top (π/2) when the offset reaches 0
			local angle = math.pi / 2 + (i - 1) * step + offset
			holder.Position = center
				+ right * math.cos(angle) * RADIUS
				+ Vector3.yAxis * math.sin(angle) * RADIUS
			pivot(i, holder.Position)
		end
	end
	place(total)

	local started = os.clock()
	local lastSlot = math.floor(total / step)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		setWindowVisible(false)
		local t = math.clamp((os.clock() - started) / SPIN_SECONDS, 0, 1)
		local offset = total * (1 - easeOut(t))
		place(offset)
		-- a tick each time a book passes the top: the frame bumps, a rising click like the Minecraft xp
		local slot = math.floor(offset / step)
		if slot ~= lastSlot then
			lastSlot = slot
			pulse.Scale = 1.12
			TweenService:Create(pulse, TweenInfo.new(0.12), { Scale = 1 }):Play()
			Sfx.play("xp", nil, 0.25, 0.8 + 0.6 * t)
		end
		if t >= 1 and connection then
			connection:Disconnect()
			connection = nil
			place(0)
			Sfx.play("level_up", nil, 0.5)
			-- the others fade, the dropped book grows with its rarity colour
			for i, gui in ipairs(guis) do
				if i > 1 then
					fade(gui, 0.4)
					local model = models[i]
					if model then
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("BasePart") then
								TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 })
									:Play()
							end
						end
					end
				end
			end
			local winnerModel = models[1]
			if winnerModel then
				local light = Instance.new("Highlight")
				light.FillColor = rarityColor(winnerRarity)
				light.FillTransparency = 0.75
				light.OutlineColor = rarityColor(winnerRarity)
				light.DepthMode = Enum.HighlightDepthMode.Occluded
				light.Parent = winnerModel
				pivot(1, holders[1].Position, 1.35)
			end
			local winnerGui = guis[1]
			local glow = winnerGui:FindFirstChild("Glow")
			if glow and glow:IsA("Frame") then
				TweenService:Create(
					glow,
					TweenInfo.new(0.3),
					{ BackgroundColor3 = rarityColor(winnerRarity):Lerp(Color3.new(), 0.55) }
				):Play()
			end
			TweenService:Create(
				winnerGui,
				TweenInfo.new(0.35, Enum.EasingStyle.Back),
				{ Size = UDim2.fromScale(BOOK_SIZE.X * 1.5, BOOK_SIZE.Y * 1.5) }
			):Play()
			task.delay(1.4, function()
				-- into the case
				local winnerHolder = holders[1]
				local from = winnerHolder.Position
				local sinkStart = os.clock()
				local sink: RBXScriptConnection? = nil
				sink = RunService.RenderStepped:Connect(function()
					local k = math.clamp((os.clock() - sinkStart) / 0.45, 0, 1)
					local at = from:Lerp(part.Position, k * k)
					winnerHolder.Position = at
					if folder.Parent then
						pivot(1, at, math.max(0.3, 1.35 * (1 - k)))
					end
					if k >= 1 and sink then
						sink:Disconnect()
					end
				end)
				fade(frameGui, 0.3)
				pointer.Transparency = 1
				TweenService
					:Create(winnerGui, TweenInfo.new(0.45), { Size = UDim2.fromScale(0.4, 0.5) })
					:Play()
				fade(frameGui, 0.3)
				task.delay(0.5, function()
					folder:Destroy()
					playing = false
					setWindowVisible(true)
				end)
			end)
		end
	end)
	-- never leave the window hidden (a broken part, a teleport): give up after a while
	task.delay(SPIN_SECONDS + 4, function()
		if playing then
			if connection then
				connection:Disconnect()
			end
			folder:Destroy()
			playing = false
			setWindowVisible(true)
		end
	end)
end

return AncientRoulette
