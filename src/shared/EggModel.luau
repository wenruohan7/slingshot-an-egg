--!strict
-- Builds the egg a player launches, in the look of the egg they own
-- (Config.Eggs). Shared so the Shop can show a picture of each egg.
-- A mesh with the egg's name in ReplicatedStorage.EggModels (a MeshPart, or
-- the Model Studio's 3D Importer makes) is used instead of the built-in
-- shape, so real models can be dropped in.

local CustomModels = require(script.Parent.CustomModels)
local Economy = require(script.Parent.Economy)
local MeshSizes = require(script.Parent.MeshSizes)

local EGG_HEIGHT = 5 -- studs, for a mesh that isn't one of ours in MeshSizes

local EggModel = {}

EggModel.CUSTOM_FOLDER = "EggModels"

-- The egg for an egg level (0 = the first egg), anchored and not yet parented.
function EggModel.build(level: number?): BasePart
	local look = Economy.egg(level or 0)
	local custom = CustomModels.find(EggModel.CUSTOM_FOLDER, look.Name)
	local mesh = if custom then CustomModels.mainPart(custom) else nil
	if mesh then
		local egg = mesh:Clone()
		CustomModels.stripScripts(egg)
		egg.Name = "Egg"
		egg.Anchored = true
		egg.CanCollide = false
		-- Studio's importer may pick any scale, so size it here.
		local box = MeshSizes.Eggs[look.Name]
		egg.Size = if box then box.Size else mesh.Size * (EGG_HEIGHT / math.max(mesh.Size.Y, 0.01))
		return egg
	end

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(4, 4, 4)
	egg.Color = look.Color
	egg.Material = look.Material
	egg.Anchored = true
	egg.CanCollide = false

	-- Stretch the ball into an egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = egg
	return egg
end

return EggModel
