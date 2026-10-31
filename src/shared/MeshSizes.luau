--!strict
-- Made by blender/build.py: do not edit by hand.
-- The size and centre of each model in models/, in the model's own space
-- (Slingshots: before SlingshotModel's 0.4 scale; Eggs and Stands: studs).
-- An imported mesh is resized and placed from these, so it lines up no
-- matter what scale Studio's importer picked.

export type Box = { Size: Vector3, Center: Vector3 }

local MeshSizes: { [string]: { [string]: Box } } = {
	Slingshots = {
		["Candy Slingshot"] = { Size = Vector3.new(2.8456, 13.9156, 11.6), Center = Vector3.new(0.4628, 6.8422, -0) },
		["Crystal Slingshot"] = { Size = Vector3.new(2.6355, 15.0802, 10.0636), Center = Vector3.new(0.3577, 7.4245, -0) },
		["Galaxy Slingshot"] = { Size = Vector3.new(3.0034, 13.2656, 11.0949), Center = Vector3.new(0, 6.5172, -0) },
		["Golden Slingshot"] = { Size = Vector3.new(2.86, 13.9727, 9.6), Center = Vector3.new(0.27, 6.9136, 0) },
		["Ice Slingshot"] = { Size = Vector3.new(2.5, 14.8156, 9.9834), Center = Vector3.new(0, 7.2922, -0) },
		["Iron Slingshot"] = { Size = Vector3.new(2.36, 13.1, 9.9), Center = Vector3.new(0, 6.25, -0) },
		["Lava Slingshot"] = { Size = Vector3.new(2.0367, 14.2977, 9.8465), Center = Vector3.new(0.0183, 7.0761, -0) },
		["Leafy Slingshot"] = { Size = Vector3.new(4.1991, 13.3856, 10.6307), Center = Vector3.new(0.7004, 6.5772, -0) },
		["Moon Slingshot"] = { Size = Vector3.new(2.28, 14.0102, 11.2), Center = Vector3.new(0, 6.8895, -0) },
		["Rainbow Slingshot"] = { Size = Vector3.new(3.4, 14.7537, 10.8602), Center = Vector3.new(-0, 6.3268, -0) },
		["Sturdy Slingshot"] = { Size = Vector3.new(2.62, 13.5227, 9.9), Center = Vector3.new(0, 6.6886, -0) },
		["Wooden Slingshot"] = { Size = Vector3.new(1.96, 12.9656, 9.7), Center = Vector3.new(0, 6.3672, -0) },
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
		["Egg Shop"] = { Size = Vector3.new(17.4, 16.95, 11.3), Center = Vector3.new(0, 8.475, -0.05) },
		["Rebirth"] = { Size = Vector3.new(18.8, 17.1347, 18.8), Center = Vector3.new(0, 8.5673, -0) },
		["Slingshot Shop"] = { Size = Vector3.new(17.4, 17.419, 11.3), Center = Vector3.new(0, 8.7095, -0.05) },
	},
}

return MeshSizes
