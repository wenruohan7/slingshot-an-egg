--!strict
-- Made by blender/build.py: do not edit by hand.
-- The size and centre of each model in models/, in the model's own space
-- (Bows and Slingshots: before SlingshotModel's 0.4 scale; Eggs and Stands: studs).
-- An imported mesh is resized and placed from these, so it lines up no
-- matter what scale Studio's importer picked.

export type Box = { Size: Vector3, Center: Vector3 }

local MeshSizes: { [string]: { [string]: Box } } = {
	Bows = {
		["Candy Bow"] = { Size = Vector3.new(5.8, 16, 1.9), Center = Vector3.new(-1.1, 0, -0) },
		["Crystal Bow"] = { Size = Vector3.new(5.3618, 17.7469, 1.88), Center = Vector3.new(-0.4809, 0, -0) },
		["Galaxy Bow"] = { Size = Vector3.new(4.7667, 14.6, 2.5693), Center = Vector3.new(-1.2633, 0, -0) },
		["Golden Bow"] = { Size = Vector3.new(4.7409, 15.6, 2.32), Center = Vector3.new(-0.6204, 0, -0) },
		["Ice Bow"] = { Size = Vector3.new(4, 17.4, 1.88), Center = Vector3.new(-0.9, 0, -0) },
		["Iron Bow"] = { Size = Vector3.new(4.1173, 14.6, 1.7), Center = Vector3.new(-0.8586, 0, -0) },
		["Lava Bow"] = { Size = Vector3.new(4.2525, 15.45, 1.96), Center = Vector3.new(-1.0238, 0.575, -0) },
		["Leafy Bow"] = { Size = Vector3.new(4.7832, 14, 3.3408), Center = Vector3.new(-0.9842, 0, -0) },
		["Moon Bow"] = { Size = Vector3.new(3.77, 16.5912, 2.6), Center = Vector3.new(-0.765, 0, -0) },
		["Rainbow Bow"] = { Size = Vector3.new(5.0539, 15.0997, 2.1), Center = Vector3.new(-0.9769, 0.1108, -0) },
		["Sturdy Bow"] = { Size = Vector3.new(4.28, 14.24, 2.52), Center = Vector3.new(-0.88, 0, -0) },
		["Wooden Bow"] = { Size = Vector3.new(3.85, 14, 1.9), Center = Vector3.new(-0.975, 0, -0) },
	},
	Slingshots = {
	},
	Eggs = {
		["Crystal Egg"] = { Size = Vector3.new(3.8794, 5, 3.9392), Center = Vector3.new(-0.0603, 0, -0) },
		["Divine Egg"] = { Size = Vector3.new(4.1276, 5.8402, 7.5954), Center = Vector3.new(-0.0638, 0.4201, -0) },
		["Galaxy Egg"] = { Size = Vector3.new(5.602, 5, 5.8362), Center = Vector3.new(0, 0, -0) },
		["Golden Egg"] = { Size = Vector3.new(4, 5, 4), Center = Vector3.new(0, 0, -0) },
		["Mint Egg"] = { Size = Vector3.new(4, 5, 4), Center = Vector3.new(0, 0, -0) },
		["Plain Egg"] = { Size = Vector3.new(4, 5, 4), Center = Vector3.new(0, 0, -0) },
		["Rainbow Egg"] = { Size = Vector3.new(4, 5, 4), Center = Vector3.new(0, 0, -0) },
		["Sky Egg"] = { Size = Vector3.new(4, 5, 4), Center = Vector3.new(0, 0, -0) },
	},
	Stands = {
		["Bow Shop"] = { Size = Vector3.new(17.4, 20.725, 11.3), Center = Vector3.new(0, 10.3625, -0.05) },
		["Egg Shop"] = { Size = Vector3.new(17.4, 16.95, 11.3), Center = Vector3.new(0, 8.475, -0.05) },
		["Rebirth"] = { Size = Vector3.new(18.8, 17.1347, 18.8), Center = Vector3.new(0, 8.5673, -0) },
	},
}

return MeshSizes
