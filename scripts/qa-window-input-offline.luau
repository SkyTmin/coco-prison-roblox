--!nocheck
-- Actual WindowInput. Services/control scheduling are mocked; this is not native acceptance.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function fixture()
	local f = { open = false, loading = false, tasks = {}, moves = 0, enables = 0, disables = 0 }
	f.camera = { Parent = {}, CameraType = rb.Enum.CameraType.Custom }
	f.world = { CurrentCamera = f.camera }
	f.humanoid = { Health = 100, Jump = true }
	f.player = {
		Character = {
			FindFirstChildOfClass = function()
				return f.humanoid
			end,
		},
		GetAttribute = function(_, key)
			return if key == "LoadingBlocked" then f.loading else nil
		end,
		Move = function(_, direction)
			f.moves += 1
			f.direction = direction
		end,
		WaitForChild = function()
			return {
				WaitForChild = function()
					return "PlayerModule"
				end,
			}
		end,
	}
	f.input = { MouseIconEnabled = false, MouseBehavior = rb.Enum.MouseBehavior.LockCenter }
	local controls = {
		Disable = function()
			f.disables += 1
		end,
		Enable = function()
			f.enables += 1
			if f.pauseEnable then
				coroutine.yield("Enable suspended")
			end
		end,
	}
	local services = {
		Players = { LocalPlayer = f.player },
		UserInputService = f.input,
		RunService = {
			BindToRenderStep = function(_, _, _, callback)
				f.frame = callback
			end,
		},
	}
	local fn = assert(loadstring(fs.readFile("src/client/WindowInput.luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, id)
					return services[id]
				end,
			},
			workspace = f.world,
			Enum = rb.Enum,
			Vector3 = rb.Vector3,
			task = {
				spawn = function(callback)
					table.insert(f.tasks, coroutine.create(callback))
				end,
			},
			require = function()
				return {
					GetControls = function()
						return controls
					end,
				}
			end,
		}, { __index = getfenv() })
	)
	f.module = fn()
	f.module.Start(function()
		return f.open
	end)
	function f:pump()
		local list = self.tasks
		self.tasks = {}
		for _, thread in list do
			assert(coroutine.resume(thread))
		end
	end
	function f:tick()
		local thread = coroutine.create(self.frame)
		assert(coroutine.resume(thread))
		return thread
	end
	f:pump()
	return f
end
local f = fixture()
for index = 1, 8 do
	f.open = true
	f:tick()
	check("open freezes camera " .. index, f.camera.CameraType == rb.Enum.CameraType.Scriptable)
	check(
		"open frees cursor " .. index,
		f.input.MouseBehavior == rb.Enum.MouseBehavior.Default and f.input.MouseIconEnabled
	)
	check("open zeroes movement " .. index, f.direction == rb.Vector3.zero and not f.humanoid.Jump)
	f.open = false
	f:tick()
	check(
		"ordinary close restores camera " .. index,
		f.camera.CameraType == rb.Enum.CameraType.Custom
	)
end
check("ordinary close restores cursor visibility", not f.input.MouseIconEnabled)
check("controls transition once per window", f.enables == 8 and f.disables == 8)
f.loading = true
f:tick()
check("loader also owns camera", f.camera.CameraType == rb.Enum.CameraType.Scriptable)
f.loading = false
f:tick()
check("loader release restores camera", f.camera.CameraType == rb.Enum.CameraType.Custom)
f.player.Character = nil
f.open = true
f:tick()
check("window without character still frees cursor", f.input.MouseIconEnabled)
f.open = false
f:tick()
check("close without character restores type", f.camera.CameraType == rb.Enum.CameraType.Custom)

local cycle = fixture()
local original = cycle.camera
cycle.open = true
cycle:tick()
cycle.world.CurrentCamera = { Parent = {}, CameraType = rb.Enum.CameraType.Custom }
cycle:tick()
cycle.world.CurrentCamera = original
cycle:tick()
cycle.open = false
cycle:tick()
check("A to B to A camera swap releases A", original.CameraType == rb.Enum.CameraType.Custom)
check("restored camera follows the player", original.CameraSubject == cycle.humanoid)

local startup = fixture()
startup.camera.CameraType = rb.Enum.CameraType.Scriptable
startup.loading = true
startup:tick()
startup.loading = false
startup.player.Character = nil
startup:tick()
startup.player.Character = {
	FindFirstChildOfClass = function()
		return startup.humanoid
	end,
}
startup:tick()
check("startup rebinds a late humanoid", startup.camera.CameraSubject == startup.humanoid)
check(
	"startup releases inherited Scriptable",
	startup.camera.CameraType == rb.Enum.CameraType.Custom
)

local replacement = fixture()
replacement.loading = true
replacement:tick()
replacement.world.CurrentCamera = { CameraType = rb.Enum.CameraType.Scriptable }
replacement.loading = false
replacement:tick()
check(
	"camera replaced on release follows the player",
	replacement.world.CurrentCamera.CameraType == rb.Enum.CameraType.Custom
		and replacement.world.CurrentCamera.CameraSubject == replacement.humanoid
)
check("old loading camera is restored", replacement.camera.CameraType == rb.Enum.CameraType.Custom)

local yielding = fixture()
yielding.open = true
yielding:tick()
yielding.pauseEnable, yielding.open = true, false
local closeThread = yielding:tick()
yielding:tick()
check(
	"camera is released before a slow control enable",
	yielding.camera.CameraType == rb.Enum.CameraType.Custom
)
assert(coroutine.resume(closeThread))
check(
	"completion of Enable eventually restores camera",
	yielding.camera.CameraType == rb.Enum.CameraType.Custom
)
print(serde.encode("json", {
	ordinaryAssertionsPassed = #checks,
	actualWindowInput = true,
	nativeRendering = false,
}, true))
