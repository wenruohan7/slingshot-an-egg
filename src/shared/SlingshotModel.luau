--!strict
-- The slingshot item every player carries: a Y-shaped fork with a striped
-- grip, round tips, two elastic bands and a leather pouch, coloured for
-- whichever slingshot the player owns (Config.Slingshots).
-- It's a Tool, so it sits in the player's hand. Shared so the server can
-- build it, the client can pull the pouch back while charging (the pull
-- is local to that player), and the Shop can show a picture of each one.
-- A Tool with the slingshot's name in ReplicatedStorage.SlingshotModels is
-- used instead of the built-in model, so real models can be dropped in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)

local SlingshotModel = {}

SlingshotModel.NAME = "Slingshot"
SlingshotModel.CUSTOM_FOLDER = "SlingshotModels"

local SCALE = 0.4 -- the shape below is drawn 13 studs tall; this sizes it for a hand

local STRIPE_WHITE = Color3.fromRGB(255, 245, 250)
local LEATHER = Color3.fromRGB(120, 72, 40)

-- Points in the slingshot's own space, before SCALE: +X is forward (where the
-- egg flies), +Y is up, and the fork spreads along Z.
local FORK = Vector3.new(0, 6, 0)
local TIP_LEFT = Vector3.new(0, 12, -4)
local TIP_RIGHT = Vector3.new(0, 12, 4)
local GRIP_POINT = Vector3.new(0, 3, 0) -- where the hand holds the handle
local POUCH_REST = Vector3.new(-1, 11.5, 0)
local PULL_BACK = Vector3.new(-6, -1.5, 0) -- where the pouch goes at full charge, relative to rest
local BAND_THICKNESS = 0.4
local BAND_THINNING = 0.15 -- bands get thinner as they stretch

local function scaled(point: Vector3): Vector3
	return point * SCALE
end

-- CFrame and size of a cylinder running from a to b. A cylinder's length runs
-- along its X axis, so turn it to face along the rod.
local function rodFrame(a: Vector3, b: Vector3, diameter: number): (CFrame, Vector3)
	local direction = b - a
	local length = math.max(direction.Magnitude, 0.05)
	-- CFrame.lookAt needs an up vector that isn't parallel to the rod.
	local up = if length > 0.05 and math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
	return frame, Vector3.new(length, diameter, diameter)
end

local function newPart(name: string, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function rod(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = newPart(name, color, parent, material)
	p.Shape = Enum.PartType.Cylinder
	local frame, size = rodFrame(scaled(a), scaled(b), diameter * SCALE)
	p.Size = size
	p.CFrame = frame
	return p
end

local function ball(name: string, at: Vector3, diameter: number, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = newPart(name, color, parent, material)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * diameter * SCALE
	p.CFrame = CFrame.new(scaled(at))
	return p
end

local function weldToHandle(handle: BasePart, p: BasePart)
	local weld = Instance.new("Weld")
	weld.Name = "HandleWeld"
	weld.Part0 = handle
	weld.Part1 = p
	weld.C0 = handle.CFrame:Inverse() * p.CFrame
	weld.Parent = p
end

-- A real model for this slingshot from ReplicatedStorage.SlingshotModels, if one was added.
local function customTool(name: string): Tool?
	local folder = ReplicatedStorage:FindFirstChild(SlingshotModel.CUSTOM_FOLDER)
	local custom = folder and folder:FindFirstChild(name)
	if custom and custom:IsA("Tool") then
		local tool = custom:Clone()
		-- Free models often carry their own scripts; our code does the launching.
		for _, item in tool:GetDescendants() do
			if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
				item:Destroy()
			end
		end
		tool.Name = SlingshotModel.NAME
		tool.CanBeDropped = false
		tool.ToolTip = name
		return tool
	end
	return nil
end

-- Builds the slingshot Tool for a slingshot level (0 = the first slingshot).
-- All parts are made in the slingshot's own space and welded to the handle.
function SlingshotModel.buildTool(level: number?): Tool
	local look = Economy.slingshot(level or 0)
	local custom = customTool(look.Name)
	if custom then
		return custom
	end

	local tool = Instance.new("Tool")
	tool.Name = SlingshotModel.NAME
	tool.CanBeDropped = false
	tool.ToolTip = look.Name

	local frameColor, accent, material = look.Frame, look.Accent, look.Material
	local handle = rod("Handle", Vector3.zero, FORK, 1.6, frameColor, tool, material)

	local parts: { BasePart } = {}
	for i, y in { 1.4, 2.6, 3.8 } do
		table.insert(parts, rod("Grip" .. i, Vector3.new(0, y, 0), Vector3.new(0, y + 0.6, 0), 1.9,
			if i % 2 == 1 then accent else STRIPE_WHITE, tool))
	end
	table.insert(parts, ball("Joint", FORK, 2, frameColor, tool, material))
	table.insert(parts, rod("ArmLeft", FORK, TIP_LEFT, 1.3, frameColor, tool, material))
	table.insert(parts, rod("ArmRight", FORK, TIP_RIGHT, 1.3, frameColor, tool, material))
	table.insert(parts, ball("TipLeft", TIP_LEFT, 1.7, accent, tool))
	table.insert(parts, ball("TipRight", TIP_RIGHT, 1.7, accent, tool))

	local pouch = newPart("Pouch", LEATHER, tool)
	pouch.Size = Vector3.new(0.8, 1.4, 2.4) * SCALE
	table.insert(parts, pouch)
	for _, name in { "BandLeft", "BandRight" } do
		local band = newPart(name, look.Band, tool)
		band.Shape = Enum.PartType.Cylinder
		table.insert(parts, band)
	end

	for _, p in parts do
		weldToHandle(handle, p)
	end

	-- In the hand, the grip frame's -Z points where the arm points and +Y points up,
	-- so line those up with the slingshot's forward (+X) and up (+Y).
	local gripFrame = CFrame.fromMatrix(scaled(GRIP_POINT), Vector3.zAxis, Vector3.yAxis, -Vector3.xAxis)
	tool.Grip = handle.CFrame:Inverse() * gripFrame

	-- setPull needs the handle's place in slingshot space to aim the welds.
	tool:SetAttribute("HandleFrame", handle.CFrame)
	SlingshotModel.setPull(tool, 0)
	return tool
end

local function setWeld(p: Instance?, c0: CFrame)
	local weld = p and p:FindFirstChild("HandleWeld")
	if weld and weld:IsA("Weld") then
		weld.C0 = c0
	end
end

-- Moves the pouch and bands: 0 = at rest, 1 = fully pulled back.
-- Values a little below 0 overshoot forward, for the snap after release.
function SlingshotModel.setPull(tool: Tool, amount: number)
	local handleFrame = tool:GetAttribute("HandleFrame")
	if typeof(handleFrame) ~= "CFrame" then
		return
	end
	local toHandle = handleFrame:Inverse()

	local pouchPosition = scaled(POUCH_REST + PULL_BACK * amount)
	setWeld(tool:FindFirstChild("Pouch"), toHandle * CFrame.new(pouchPosition))

	local thickness = (BAND_THICKNESS - BAND_THINNING * math.clamp(amount, 0, 1)) * SCALE
	local bands: { [string]: Vector3 } = { BandLeft = TIP_LEFT, BandRight = TIP_RIGHT }
	for name, tip in bands do
		local band = tool:FindFirstChild(name)
		if band and band:IsA("BasePart") then
			local frame, size = rodFrame(scaled(tip), pouchPosition, thickness)
			band.Size = size
			setWeld(band, toHandle * frame)
		end
	end
end

return SlingshotModel
