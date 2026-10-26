--!strict
-- Builds the egg a player launches, in the look of the egg they own
-- (Config.Eggs). Shared so the Shop can show a picture of each egg.
-- A MeshPart with the egg's name in ReplicatedStorage.EggModels is used
-- instead of the built-in shape, so real models can be dropped in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)

local EggModel = {}

EggModel.CUSTOM_FOLDER = "EggModels"

-- The egg for an egg level (0 = the first egg), anchored and not yet parented.
function EggModel.build(level: number?): BasePart
	local look = Economy.egg(level or 0)
	local folder = ReplicatedStorage:FindFirstChild(EggModel.CUSTOM_FOLDER)
	local custom = folder and folder:FindFirstChild(look.Name)
	if custom and custom:IsA("BasePart") then
		local egg = custom:Clone()
		egg.Name = "Egg"
		egg.Anchored = true
		egg.CanCollide = false
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
