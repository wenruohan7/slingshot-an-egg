--!strict
-- The slingshot on each launch pad: a Y-shaped wooden fork on a round base,
-- candy-striped grip, two elastic bands and a leather pouch.
-- Shared so the server can build it and the client can pull the pouch back
-- on its own copy while charging (the pull is local to that player).

local SlingshotModel = {}

local WOOD = Color3.fromRGB(176, 122, 78)
local WOOD_DARK = Color3.fromRGB(140, 92, 56)
local CANDY_PINK = Color3.fromRGB(255, 120, 160)
local CANDY_WHITE = Color3.fromRGB(255, 245, 250)
local BAND_COLOR = Color3.fromRGB(235, 60, 110)
local LEATHER = Color3.fromRGB(120, 72, 40)

-- Points in the slingshot's own space: +X faces down the lane, +Y is up,
-- and the fork spreads along Z.
local FORK = Vector3.new(0, 6, 0)
local TIP_LEFT = Vector3.new(0, 12, -4)
local TIP_RIGHT = Vector3.new(0, 12, 4)
local POUCH_REST = Vector3.new(-1, 11.5, 0)
local PULL_BACK = Vector3.new(-6, -1.5, 0) -- where the pouch goes at full charge, relative to rest
local BAND_THICKNESS = 0.4
local BAND_THINNING = 0.15 -- bands get thinner as they stretch

local function newPart(name: string, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Stretches a cylinder between two world points.
local function placeRod(rod: BasePart, a: Vector3, b: Vector3, diameter: number)
	local direction = b - a
	local length = math.max(direction.Magnitude, 0.05)
	-- CFrame.lookAt needs an up vector that isn't parallel to the rod.
	local up = if length > 0.05 and math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	rod.Size = Vector3.new(length, diameter, diameter)
	-- A cylinder's length runs along its X axis; turn it to face along the rod.
	rod.CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
end

local function rod(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, parent: Instance): Part
	local p = newPart(name, color, parent)
	p.Shape = Enum.PartType.Cylinder
	placeRod(p, a, b, diameter)
	return p
end

local function ball(name: string, at: Vector3, diameter: number, color: Color3, parent: Instance): Part
	local p = newPart(name, color, parent)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.Position = at
	return p
end

-- Builds a slingshot standing at `origin` (its base, facing origin's +X).
function SlingshotModel.build(parent: Instance, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Slingshot"

	local function at(localPoint: Vector3): Vector3
		return origin:PointToWorldSpace(localPoint)
	end

	rod("Base", at(Vector3.zero), at(Vector3.new(0, 1, 0)), 7, WOOD_DARK, model)
	rod("Handle", at(Vector3.new(0, 1, 0)), at(FORK), 1.6, WOOD, model)
	for i, y in { 2.4, 3.4, 4.4 } do
		rod("Grip" .. i, at(Vector3.new(0, y, 0)), at(Vector3.new(0, y + 0.5, 0)), 1.9,
			if i % 2 == 1 then CANDY_PINK else CANDY_WHITE, model)
	end
	ball("Joint", at(FORK), 2, WOOD, model)
	rod("ArmLeft", at(FORK), at(TIP_LEFT), 1.3, WOOD, model)
	rod("ArmRight", at(FORK), at(TIP_RIGHT), 1.3, WOOD, model)
	ball("TipLeft", at(TIP_LEFT), 1.7, CANDY_PINK, model)
	ball("TipRight", at(TIP_RIGHT), 1.7, CANDY_PINK, model)

	local pouch = newPart("Pouch", LEATHER, model)
	pouch.Size = Vector3.new(0.8, 1.4, 2.4)
	pouch.CanCollide = false

	for _, name in { "BandLeft", "BandRight" } do
		local band = newPart(name, BAND_COLOR, model)
		band.Shape = Enum.PartType.Cylinder
		band.CanCollide = false
	end

	model.WorldPivot = origin
	-- Also kept as an attribute, which clients can always read.
	model:SetAttribute("Origin", origin)
	SlingshotModel.setPull(model, 0)
	model.Parent = parent
	return model
end

local function originOf(model: Model): CFrame
	local origin = model:GetAttribute("Origin")
	return if typeof(origin) == "CFrame" then origin else model.WorldPivot
end

-- Moves the pouch and bands: 0 = at rest, 1 = fully pulled back.
-- Values a little below 0 overshoot forward, for the snap after release.
function SlingshotModel.setPull(model: Model, amount: number)
	local pouch = model:FindFirstChild("Pouch")
	local left = model:FindFirstChild("BandLeft")
	local right = model:FindFirstChild("BandRight")
	if not (pouch and left and right and pouch:IsA("BasePart") and left:IsA("BasePart") and right:IsA("BasePart")) then
		return
	end

	local origin = originOf(model)
	local pouchPosition = origin:PointToWorldSpace(POUCH_REST + PULL_BACK * amount)
	pouch.CFrame = CFrame.new(pouchPosition) * origin.Rotation

	local thickness = BAND_THICKNESS - BAND_THINNING * math.clamp(amount, 0, 1)
	placeRod(left, origin:PointToWorldSpace(TIP_LEFT), pouchPosition, thickness)
	placeRod(right, origin:PointToWorldSpace(TIP_RIGHT), pouchPosition, thickness)
end

-- Where the egg sits before launch (the pouch's rest position).
function SlingshotModel.pouchPosition(model: Model): Vector3
	return originOf(model):PointToWorldSpace(POUCH_REST)
end

return SlingshotModel
