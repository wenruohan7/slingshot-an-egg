--!strict
-- Builds a pet: a base ring in its rarity's colour, and either a real model or
-- a simple greybox one (a round body in its zone's colour, eyes and ears).
-- Mutations change the body's look.
-- A real model is a Model in ReplicatedStorage.PetModels named exactly like the
-- pet (see Pets.luau), with its front facing -Z (Studio's front). It's resized
-- to pet height, so it can be any size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Pets = require(script.Parent.Pets)

local PetModel = {}

local BODY_SIZE = 2.6
local EYE_COLOR = Color3.fromRGB(30, 30, 40)
local GLOW_FROM_RARITY = 4 -- Epic and up glow
local CUSTOM_HEIGHT = 3.4 -- real models are scaled to this tall (before Big)

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

-- A copy of the pet's real model, sized and placed with its feet at `base`
-- facing +X, or nil if there isn't one. Scripts inside are removed.
local function customModel(name: string, base: CFrame, scale: number, mutation: { Name: string, Color: Color3 }?): Model?
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local source = folder and folder:FindFirstChild(name)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	local biggest: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			if mutation and not (item:IsA("MeshPart") and item.TextureID ~= "") then
				-- Textured meshes keep their texture; plain parts take the mutation's look.
				item.Color = mutation.Color
				item.Material = MUTATION_MATERIALS[mutation.Name] or item.Material
			end
			if biggest == nil or item.Size.Magnitude > biggest.Size.Magnitude then
				biggest = item
			end
		end
	end
	if not biggest then
		model:Destroy()
		return nil
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * CUSTOM_HEIGHT * scale / math.max(size.Y, 0.1))
	-- Turn Studio's front (-Z) to +X, then stand the bounding box on the base.
	local turned = base * CFrame.Angles(0, -math.pi / 2, 0)
	model:PivotTo(turned)
	local box, boxSize = model:GetBoundingBox()
	local lift = (base.Position.Y + 0.3) - (box.Position.Y - boxSize.Y / 2)
	model:PivotTo(turned + Vector3.new(0, lift, 0))
	model.Name = "Pet"
	model.PrimaryPart = biggest
	return model
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

	local function addRing(parent: Model)
		local ring = part("Ring", Enum.PartType.Cylinder, Vector3.new(0.3, 3.4, 3.4) * scale, rarity.Color, parent)
		ring.CFrame = at(Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Material = Enum.Material.Neon
	end

	local glows = (def ~= nil and def.Rarity >= GLOW_FROM_RARITY) or (mutation ~= nil and mutation.Name == "Divine")
	local function addGlow(target: BasePart)
		local light = Instance.new("PointLight")
		light.Color = if mutation then mutation.Color else rarity.Color
		light.Range = 10 * scale
		light.Brightness = 2
		light.Parent = target
	end

	local custom = def and customModel(def.Name, base, scale, mutation)
	if custom then
		addRing(custom)
		if glows and custom.PrimaryPart then
			addGlow(custom.PrimaryPart)
		end
		return custom
	end
	addRing(model)

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

	if glows then
		addGlow(body)
	end

	model.PrimaryPart = body
	return model
end

return PetModel
