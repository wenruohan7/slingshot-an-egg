--!strict
-- Made by blender/build.py: do not edit by hand.
-- The size and centre of each model in models/, in the model's own space
-- (Bows and Slingshots: before SlingshotModel's 0.4 scale; Eggs and Stands: studs).
-- An imported mesh is resized and placed from these, so it lines up no
-- matter what scale Studio's importer picked.

export type Box = { Size: Vector3, Center: Vector3 }

local MeshSizes: { [string]: { [string]: Box } } = {
	Bows = {
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
		["Egg Shop"] = { Size = Vector3.new(17.4, 16.95, 11.3), Center = Vector3.new(0, 8.475, -0.05) },
		["Rebirth"] = { Size = Vector3.new(18.8, 17.1347, 18.8), Center = Vector3.new(0, 8.5673, -0) },
	},
}

return MeshSizes
