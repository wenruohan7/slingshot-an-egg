--!strict
-- Builds a simple greybox pet: a round body in its zone's colour, eyes and ears,
-- and a base ring in its rarity's colour. Mutations change the body's look.
-- Real pet models replace this later; keep the "Body" part name.

local Config = require(script.Parent.Config)
local Pets = require(script.Parent.Pets)

local PetModel = {}

local BODY_SIZE = 2.6
local EYE_COLOR = Color3.fromRGB(30, 30, 40)
local GLOW_FROM_RARITY = 4 -- Epic and up glow

local MUTATION_MATERIALS: { [string]: Enum.Material } = {
	Golden = Enum.Material.Foil,
	Diamond = Enum.Material.Glass,
	Rainbow = Enum.Material.Neon,
	Blocky = Enum.Material.SmoothPlastic,
	Galaxy = Enum.Material.Neon,
	Divine = Enum.Material.Neon,
}

local function part(name: string, shape: Enum.PartType, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Builds the pet with its feet at `base`, facing +X (down the lane).
function PetModel.build(pet: Pets.Pet, base: CFrame): Model
	local def = Pets.ById[pet.Id]
	local zone = Config.Zones[if def then def.Zone else 1]
	local rarity = Config.Rarities[if def then def.Rarity else 1]
	local mutation = if pet.Mutation then Config.Mutations[pet.Mutation] else nil
	local scale = if pet.Big then 1.6 else 1

	local model = Instance.new("Model")
	model.Name = "Pet"

	local function at(offset: Vector3): CFrame
		return base * CFrame.new(offset * scale)
	end

	local ring = part("Ring", Enum.PartType.Cylinder, Vector3.new(0.3, 3.4, 3.4) * scale, rarity.Color, model)
	ring.CFrame = at(Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Neon

	local bodyShape = if mutation and mutation.Name == "Blocky" then Enum.PartType.Block else Enum.PartType.Ball
	local body = part("Body", bodyShape, Vector3.one * BODY_SIZE * scale, if mutation then mutation.Color else zone.Color, model)
	body.CFrame = at(Vector3.new(0, 0.3 + BODY_SIZE / 2, 0))
	if mutation then
		body.Material = MUTATION_MATERIALS[mutation.Name] or Enum.Material.SmoothPlastic
	end

	local headY = 0.3 + BODY_SIZE * 0.65
	for _, side in { -1, 1 } do
		local eye = part("Eye", Enum.PartType.Ball, Vector3.one * 0.45 * scale, EYE_COLOR, model)
		eye.CFrame = at(Vector3.new(BODY_SIZE * 0.42, headY, side * 0.5))
		local ear = part("Ear", Enum.PartType.Ball, Vector3.one * 0.9 * scale, body.Color, model)
		ear.CFrame = at(Vector3.new(0, 0.3 + BODY_SIZE * 0.95, side * 0.8))
		ear.Material = body.Material
	end

	if (def and def.Rarity >= GLOW_FROM_RARITY) or (mutation and mutation.Name == "Divine") then
		local light = Instance.new("PointLight")
		light.Color = if mutation then mutation.Color else rarity.Color
		light.Range = 10 * scale
		light.Brightness = 2
		light.Parent = body
	end

	model.PrimaryPart = body
	return model
end

return PetModel
