--!strict
-- Unanchoring resets Roblox assembly ownership to automatic. Bosses must stay server-owned.
-- https://create.roblox.com/docs/physics/network-ownership
local BossPhysics = {}

function BossPhysics.face(root: BasePart, target: Vector3): boolean
	local delta = (target - root.Position) * Vector3.new(1, 0, 1)
	-- lookAt(p, p) produces NaN rotation components; a dash can end exactly on its target.
	if not (delta.Magnitude >= 0.01 and delta.Magnitude < math.huge) then
		return false
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + delta)
	return true
end

function BossPhysics.restore(root: BasePart, anchored: boolean)
	if not root:IsDescendantOf(workspace) then
		return
	end
	root.Anchored = anchored
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if not anchored then
		root:SetNetworkOwner(nil)
	end
end

return BossPhysics
