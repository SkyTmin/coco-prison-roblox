--!strict
-- The face grids of our block models (assets/models/player/player.py, assets/models/armor/armor.py): per face of a
-- box, its top-left corner as signs of the half size, the unit vectors along a grid row (right) and down a column
-- (down), and the outward normal, in the box's own space (X = the character's right, Y = up, Z = back; the face looks
-- to −Z). front tl (+X, +Y, −Z) → −X; back tl (−X, +Y, +Z) → +X; right tl (+X, +Y, +Z) → −Z; left tl (−X, +Y, −Z) → +Z;
-- top tl (+X, +Y, +Z) → −X, rows → −Z; bottom tl (+X, −Y, −Z) → −X, rows → +Z. Used by AvatarService (the body's
-- pixel plates) and ArmorVisual (the armor plates).

export type Face = { tl: Vector3, right: Vector3, down: Vector3, normal: Vector3 }

local BlockFaces: { [string]: Face } = {
	front = {
		tl = Vector3.new(1, 1, -1),
		right = Vector3.new(-1, 0, 0),
		down = Vector3.new(0, -1, 0),
		normal = Vector3.new(0, 0, -1),
	},
	back = {
		tl = Vector3.new(-1, 1, 1),
		right = Vector3.new(1, 0, 0),
		down = Vector3.new(0, -1, 0),
		normal = Vector3.new(0, 0, 1),
	},
	right = {
		tl = Vector3.new(1, 1, 1),
		right = Vector3.new(0, 0, -1),
		down = Vector3.new(0, -1, 0),
		normal = Vector3.new(1, 0, 0),
	},
	left = {
		tl = Vector3.new(-1, 1, -1),
		right = Vector3.new(0, 0, 1),
		down = Vector3.new(0, -1, 0),
		normal = Vector3.new(-1, 0, 0),
	},
	top = {
		tl = Vector3.new(1, 1, 1),
		right = Vector3.new(-1, 0, 0),
		down = Vector3.new(0, 0, -1),
		normal = Vector3.new(0, 1, 0),
	},
	bottom = {
		tl = Vector3.new(1, -1, -1),
		right = Vector3.new(-1, 0, 0),
		down = Vector3.new(0, 0, 1),
		normal = Vector3.new(0, -1, 0),
	},
}

return BlockFaces
