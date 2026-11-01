--!strict
-- Audited trident/wave/water action names; original server mechanics. No defensive immunity.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local PoseidonAbilities = {}
local encounters: { [any]: any } = {}
local FLAT, WATER = Vector3.new(1, 0, 1), Color3.fromRGB(67, 137, 151)
local NAMES = { "wave_clash", "epicenter", "torpedo", "stab" }
local function living(boss: any, e: any): boolean
	return encounters[boss] == e
		and boss.root == e.root
		and e.root.Parent ~= nil
		and boss.humanoid.Health > 0
end
function PoseidonAbilities.Clear(boss: any)
	Cast.Clear(boss)
	local e = encounters[boss]
	encounters[boss] = nil
	if e then
		e.folder:Destroy()
	end
end
local function encounter(boss: any): any
	local e = encounters[boss]
	if not e or not living(boss, e) then
		PoseidonAbilities.Clear(boss)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "PoseidonEncounter", workspace
		e = { root = boss.root, folder = folder }
		encounters[boss] = e
	end
	return e
end
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = name, true, false, false, false
	p.Size, p.CFrame, p.Color, p.Material, p.Transparency =
		size, cf, color, Enum.Material.SmoothPlastic, transparency or 0
	p.Parent = parent
	return p
end
local function overlap(cf: CFrame, size: Vector3, ray: RaycastParams): boolean
	local params = OverlapParams.new()
	params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide =
		ray.FilterType, ray.FilterDescendantsInstances, true
	return #workspace:GetPartBoundsInBox(cf, size, params) > 0
end
local function uniqueHit(
	boss: any,
	e: any,
	hooks: any,
	f: any,
	damage: number,
	from: Vector3,
	seen: any,
	ray: RaycastParams
)
	if seen[f.humanoid] or not living(boss, e) or not f.root.Parent or f.humanoid.Health <= 0 then
		return
	end
	if workspace:Raycast(from, f.root.Position - from, ray) then
		return
	end
	if hooks.hurt(boss, f, damage, from, 0.7, 0.15) ~= false then
		seen[f.humanoid] = true
	end
end
local function wave(boss: any, e: any, target: Vector3, cfg: any, hooks: any)
	local flat = (target - boss.root.Position) * FLAT
	local direction = if flat.Magnitude > 0.01 then flat.Unit else boss.root.CFrame.LookVector
	local ray = Cast.Params(boss, e, hooks)
	local base = Cast.FloorAt(boss, boss.root.Position, ray) + Vector3.new(0, 1.65, 0)
	local at = base + direction * 2.5
	local size = Vector3.new(cfg.width, 3, 0.65)
	if
		overlap(CFrame.lookAt(base, base + direction), Vector3.new(1, 3, 1), ray)
		or workspace:Raycast(base, at - base, ray)
		or overlap(CFrame.lookAt(at, at + direction), size, ray)
	then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PoseidonWave", e.folder
	local strips = {}
	for i = -3, 3 do
		local h = 2.8 - math.abs(i) * 0.4
		local p = part(
			folder,
			"WaterCrest",
			Vector3.new(cfg.width / 7 + 0.02, h, 0.5),
			CFrame.new(at),
			WATER,
			0.35
		)
		table.insert(
			strips,
			{ part = p, offset = CFrame.new(i * cfg.width / 7, h / 2 - 1.4, -0.12 * math.abs(i)) }
		)
	end
	local start, previous, seen = os.clock(), at, {}
	while living(boss, e) and folder.Parent do
		local distance = math.min(cfg.range, (os.clock() - start) * cfg.speed)
		local point = at + direction * distance
		if ((point - boss.spawn.Position) * FLAT).Magnitude > boss.arenaRadius - 2 then
			break
		end
		local step = point - previous
		local cf = CFrame.lookAt(point, point + direction)
		if
			overlap(cf, size, ray)
			or (
				step.Magnitude > 0.001
				and workspace:Blockcast(
					CFrame.lookAt(previous, previous + direction),
					size,
					step,
					ray
				)
			)
		then
			break
		end
		for _, row in strips do
			row.part.CFrame = cf * row.offset
		end
		for _, f in hooks.fighters(boss) do
			local offset = (f.root.Position - previous) * FLAT
			local along = math.clamp(offset:Dot(direction), 0, step.Magnitude)
			local closest = previous + direction * along
			if
				((f.root.Position - closest) * FLAT).Magnitude <= cfg.width / 2 + 0.7
				and math.abs(f.root.Position.Y - closest.Y) < 5
			then
				uniqueHit(
					boss,
					e,
					hooks,
					f,
					cfg.damage,
					closest + Vector3.new(0, 1.5, 0),
					seen,
					ray
				)
			end
		end
		previous = point
		if distance >= cfg.range then
			break
		end
		RunService.Heartbeat:Wait()
	end
	folder:Destroy()
end
local function lightning(e: any, at: Vector3, ray: RaycastParams)
	local ceiling = workspace:Raycast(at + Vector3.new(0, 0.3, 0), Vector3.new(0, 9, 0), ray)
	local height = if ceiling then math.max(0.3, ceiling.Distance) else 9
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PoseidonLightning", e.folder
	local previous = at
	for i = 1, 6 do
		local nextPoint = at
			+ Vector3.new(
				if i == 6 then 0 else (if i % 2 == 0 then 0.45 else -0.45),
				height * i / 6,
				0.2 * math.sin(i)
			)
		local p = part(
			folder,
			"Bolt",
			Vector3.new(0.14, 0.14, (nextPoint - previous).Magnitude),
			CFrame.lookAt((nextPoint + previous) / 2, nextPoint),
			Color3.fromRGB(160, 197, 199),
			0.2
		)
		TweenService:Create(p, TweenInfo.new(0.32), { Transparency = 1 }):Play()
		previous = nextPoint
	end
	Debris:AddItem(folder, 0.4)
end
function PoseidonAbilities.Spawn(boss: any, hooks: any)
	encounter(boss)
	local d = boss.fight.poseidon.spawnDuration
	local s = Cast.Begin(boss, "awaken", d, 0, nil, hooks, nil)
	task.delay(d, function()
		Cast.Finish(boss, s)
	end)
end
function PoseidonAbilities.Melee(boss: any, target: Vector3, hooks: any)
	encounter(boss)
	boss.poseidonMelee = (boss.poseidonMelee or 0) % #boss.fight.poseidon.melee + 1
	local cfg = boss.fight.poseidon.melee[boss.poseidonMelee]
	local s = Cast.Begin(boss, cfg.name, cfg.duration, cfg.release, target, hooks, nil)
	task.spawn(function()
		local start = os.clock()
		if Cast.WaitUntil(boss, s, start, cfg.release) then
			Cast.Hit(boss, s, hooks, s.root.Position, cfg, cfg.damage)
		end
		Cast.EndAfter(boss, s, start, cfg.duration)
	end)
end
function PoseidonAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	phase2: boolean,
	hooks: any
)
	local e = encounter(boss)
	local name = NAMES[(index - 1) % #NAMES + 1]
	local cfg = boss.fight.poseidon[name]
	local s = Cast.Begin(
		boss,
		name,
		cfg.duration,
		cfg.release,
		target,
		hooks,
		boss.fight.poseidon.recovery
	)
	task.spawn(function()
		local start = os.clock()
		if name == "wave_clash" then
			local delta = (target - s.root.Position) * FLAT
			local direction = if delta.Magnitude > 0.01
				then delta.Unit
				else s.root.CFrame.LookVector
			local floor = Cast.FloorAt(boss, s.root.Position, Cast.Params(boss, e, hooks))
			local mark = hooks.telegraph(
				Vector3.new(cfg.width, 0.12, cfg.range),
				CFrame.lookAt(
					floor + direction * cfg.range / 2,
					floor + direction * (cfg.range / 2 + 1)
				),
				false,
				WATER
			)
			mark.Parent = s.folder
			if Cast.WaitUntil(boss, s, start, cfg.release) then
				task.spawn(wave, boss, e, target, cfg, hooks)
			end
		elseif name == "epicenter" then
			local points = {}
			local targets = { target }
			if phase2 then
				for _, f in hooks.fighters(boss) do
					if ((f.root.Position - target) * FLAT).Magnitude > cfg.radius * 2 then
						table.insert(targets, f.root.Position)
					end
					if #targets >= cfg.phase2Count then
						break
					end
				end
			end
			for _, at in targets do
				local ray = Cast.Params(boss, e, hooks)
				local delta = (at - s.root.Position) * FLAT
				if
					delta.Magnitude <= cfg.range
					and ((at - boss.spawn.Position) * FLAT).Magnitude < boss.arenaRadius - cfg.radius
					and not workspace:Raycast(s.root.Position, at - s.root.Position, ray)
				then
					local mark = Cast.Mark(boss, s, hooks, at, cfg.radius, WATER)
					table.insert(
						points,
						{ at = Vector3.new(at.X, s.root.Position.Y, at.Z), mark = mark }
					)
				end
			end
			if Cast.WaitUntil(boss, s, start, cfg.release) then
				local seen, ray = {}, Cast.Params(boss, e, hooks)
				for _, row in points do
					if not workspace:Raycast(s.root.Position, row.at - s.root.Position, ray) then
						lightning(e, row.mark.Position, ray)
						Cast.Pulse(e, row.mark.Position, cfg.radius, WATER)
						for _, f in hooks.fighters(boss) do
							if
								((f.root.Position - row.at) * FLAT).Magnitude <= cfg.radius
								and math.abs(f.root.Position.Y - row.at.Y) <= 7
							then
								uniqueHit(boss, e, hooks, f, cfg.damage, row.at, seen, ray)
							end
						end
					end
					row.mark:Destroy()
				end
			end
		elseif name == "torpedo" then
			local goal = Cast.Destination(boss, s, hooks, target, cfg.range)
			Cast.Mark(boss, s, hooks, goal, cfg.radius, WATER)
			hooks.act(boss, "swim_idle", cfg.release)
			if Cast.WaitUntil(boss, s, start, cfg.release) then
				hooks.act(boss, "torpedo", cfg.travelDuration)
				local seen = {}
				Cast.Travel(
					boss,
					s,
					hooks,
					goal,
					start,
					cfg.release,
					cfg.release + cfg.travelDuration,
					function(previous, point)
						local ray = Cast.Params(boss, e, hooks)
						local step = (point - previous) * FLAT
						for _, f in hooks.fighters(boss) do
							local t = if step.Magnitude > 0.001
								then math.clamp(
									((f.root.Position - previous) * FLAT):Dot(step) / step:Dot(step),
									0,
									1
								)
								else 0
							local closest = previous + step * t
							if
								((f.root.Position - closest) * FLAT).Magnitude <= cfg.radius
								and math.abs(f.root.Position.Y - point.Y) < 7
							then
								uniqueHit(boss, e, hooks, f, cfg.damage, closest, seen, ray)
							end
						end
					end
				)
				if Cast.WaitUntil(boss, s, start, cfg.release + cfg.travelDuration) then
					hooks.act(boss, "swim_attack", cfg.attackDuration)
					if
						Cast.WaitUntil(
							boss,
							s,
							start,
							cfg.release + cfg.travelDuration + cfg.attackAt
						)
					then
						local ray = Cast.Params(boss, e, hooks)
						for _, f in hooks.fighters(boss) do
							local d = (f.root.Position - s.root.Position) * FLAT
							if
								d.Magnitude <= 8
								and math.abs(f.root.Position.Y - s.root.Position.Y) < 7
								and (
									d.Magnitude < 0.01
									or d.Unit:Dot(s.root.CFrame.LookVector) > 0.75
								)
							then
								uniqueHit(boss, e, hooks, f, cfg.damage, s.root.Position, seen, ray)
							end
						end
					end
				end
			end
		else
			if Cast.WaitUntil(boss, s, start, cfg.release) then
				Cast.Hit(boss, s, hooks, s.root.Position, cfg, cfg.damage)
			end
		end
		Cast.EndAfter(boss, s, start, cfg.duration)
	end)
end
return PoseidonAbilities
