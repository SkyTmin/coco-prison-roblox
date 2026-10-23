--!strict
-- Cosmetic life in the locations [владелец 23.10: «всё в покое»], local to each client (nothing replicates).
-- Models tagged by the build scripts (Atomic, so they stream in whole):
--   AmbientSpin   — turns round its pivot's Y axis (attribute Speed, rad/s): the spider in a spawner cage;
--   AmbientDangle — a spider on a thread drops and climbs back (Amplitude studs, Period s); the part "Thread" keeps
--                   its top fixed and stretches down to the spider;
--   AmbientCrawl  — walks round a circle about its first position, facing the way it goes, the legs twitching
--                   (Radius studs, Speed rad/s, negative = the other way);
--   AmbientSway   — swings round a point TopOffset studs above the pivot (Amplitude rad, Period s): hanging cocoons;
--   AmbientPulse  — the parts named "Glow" breathe in transparency (Period s): egg sacs.
-- Only models within REACH of the camera move; parts move with BulkMoveTo.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AmbientMotion = {}

local REACH = 220
local TAGS = { "AmbientSpin", "AmbientDangle", "AmbientCrawl", "AmbientSway", "AmbientPulse" }

type Entry = {
	model: Model,
	tag: string,
	pivot: CFrame,
	parts: { BasePart },
	offsets: { CFrame },
	cframes: { CFrame },
	phase: number,
	thread: BasePart?,
	threadTop: Vector3?,
	glows: { BasePart }?,
	glowBase: { number }?,
}

local entries: { [Model]: Entry } = {}
local random = Random.new()

local function register(inst: Instance, tag: string)
	if not inst:IsA("Model") or entries[inst] then
		return
	end
	local pivot = inst:GetPivot()
	local entry: Entry = {
		model = inst,
		tag = tag,
		pivot = pivot,
		parts = {},
		offsets = {},
		cframes = {},
		phase = random:NextNumber(0, math.pi * 2),
	}
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			if tag == "AmbientDangle" and d.Name == "Thread" then
				entry.thread = d
				entry.threadTop = d.Position + Vector3.new(0, d.Size.Z / 2, 0) -- a beam part: its length is Z
			else
				table.insert(entry.parts, d)
				table.insert(entry.offsets, pivot:ToObjectSpace(d.CFrame))
				table.insert(entry.cframes, d.CFrame)
			end
		end
	end
	if tag == "AmbientPulse" then
		local glows, base = {}, {}
		for _, p in ipairs(entry.parts) do
			if p.Name == "Glow" then
				table.insert(glows, p)
				table.insert(base, p.Transparency)
			end
		end
		entry.glows, entry.glowBase = glows, base
	end
	entries[inst] = entry
end

local function unregister(inst: Instance)
	entries[inst :: Model] = nil
end

local function place(entry: Entry, pivot: CFrame)
	for i, offset in ipairs(entry.offsets) do
		entry.cframes[i] = pivot * offset
	end
	workspace:BulkMoveTo(entry.parts, entry.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	for model, e in pairs(entries) do
		if not model.Parent then
			entries[model] = nil
			continue
		end
		if (e.pivot.Position - eye).Magnitude > REACH then
			continue
		end
		local tag = e.tag
		if tag == "AmbientSpin" then
			local speed = (model:GetAttribute("Speed") :: number?) or 1
			place(e, e.pivot * CFrame.Angles(0, t * speed + e.phase, 0))
		elseif tag == "AmbientDangle" then
			local amp = (model:GetAttribute("Amplitude") :: number?) or 4
			local period = (model:GetAttribute("Period") :: number?) or 8
			-- rises and drops back with a pause at the bottom (half a sine, squared)
			local s = math.sin(t * math.pi * 2 / period + e.phase)
			local up = amp * (if s > 0 then s * s else 0)
			local pivot = e.pivot + Vector3.new(0, up, 0)
			place(e, pivot * CFrame.Angles(0, math.sin(t * 0.7 + e.phase) * 0.6, 0))
			local thread, top = e.thread, e.threadTop
			if thread and top then
				local bottom = Vector3.new(top.X, pivot.Position.Y + 0.4, top.Z)
				local len = math.max(0.2, top.Y - bottom.Y)
				thread.Size = Vector3.new(thread.Size.X, thread.Size.Y, len)
				thread.CFrame = CFrame.lookAt((top + bottom) / 2, bottom)
			end
		elseif tag == "AmbientCrawl" then
			local radius = (model:GetAttribute("Radius") :: number?) or 5
			local speed = (model:GetAttribute("Speed") :: number?) or 0.4
			local a = t * speed + e.phase
			local right, look = e.pivot.RightVector, e.pivot.LookVector
			local pos = e.pivot.Position + (math.cos(a) * right + math.sin(a) * look) * radius
			local dir = (-math.sin(a) * right + math.cos(a) * look) * math.sign(speed)
			local bob = Vector3.new(0, math.abs(math.sin(t * 9 + e.phase)) * 0.08, 0)
			place(e, CFrame.lookAt(pos + bob, pos + bob + dir))
		elseif tag == "AmbientSway" then
			local topOffset = (model:GetAttribute("TopOffset") :: number?) or 5
			local amp = (model:GetAttribute("Amplitude") :: number?) or 0.06
			local period = (model:GetAttribute("Period") :: number?) or 6
			local w = t * math.pi * 2 / period + e.phase
			local top = CFrame.new(e.pivot.Position + Vector3.new(0, topOffset, 0))
			local swing = top
				* CFrame.Angles(math.sin(w) * amp, 0, math.cos(w * 0.8) * amp * 0.6)
				* top:Inverse()
			place(e, swing * e.pivot)
		elseif tag == "AmbientPulse" then
			local period = (model:GetAttribute("Period") :: number?) or 3
			local k = (math.sin(t * math.pi * 2 / period + e.phase) + 1) / 2
			local glows, base = e.glows, e.glowBase
			if glows and base then
				for i, p in ipairs(glows) do
					p.Transparency = math.clamp(base[i] + k * 0.45, 0, 0.95)
				end
			end
		end
	end
end

function AmbientMotion.Start()
	for _, tag in ipairs(TAGS) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			register(inst, tag)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unregister)
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			register(inst, tag)
		end
	end
	RunService.RenderStepped:Connect(step)
end

return AmbientMotion
