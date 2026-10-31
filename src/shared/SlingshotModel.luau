--!strict
-- The bow every player carries (it used to be a slingshot; the code still calls
-- it the slingshot in places, like the saved SlingshotLevel, so old saves keep
-- working). A curved stave with a wrapped grip, tips in the accent colour and a
-- bowstring with a nock in the middle, coloured for whichever bow the player owns
-- (Config.Slingshots). The egg launches from the nock.
-- It's a Tool, so it sits in the player's hand. Shared so the server can
-- build it, the client can draw the string back while charging (the draw
-- is local to that player), and the Shop can show a picture of each one.
-- A Tool with the bow's name in ReplicatedStorage.BowModels is used instead of
-- the built-in model, so real models can be dropped in. Name its string's middle
-- part "Pouch" so the egg launches from there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)

local SlingshotModel = {}

SlingshotModel.NAME = "Bow"
SlingshotModel.CUSTOM_FOLDER = "BowModels"

local SCALE = 0.4 -- the shape below is drawn 13 studs tall; this sizes it for a hand

local WRAP = Color3.fromRGB(120, 72, 40)

-- Points in the bow's own space, before SCALE: +X is forward (where the egg
-- flies), +Y is up, and the hand holds the grip at the origin. The stave curves
-- back toward the player at both ends, like a D, with the string across the back.
local GRIP_POINT = Vector3.zero
local GRIP_HALF = 1.2 -- the grip runs this far up and down from the hand
local LIMB_LENGTH = 5.3 -- from the end of the grip to a tip, measured up the bow
local LIMB_CURVE = 2.4 -- how far back the tips sit behind the grip
local LIMB_SEGMENTS = 5
local TIP_TOP = Vector3.new(-LIMB_CURVE, GRIP_HALF + LIMB_LENGTH, 0)
local TIP_BOTTOM = Vector3.new(-LIMB_CURVE, -(GRIP_HALF + LIMB_LENGTH), 0)
local POUCH_REST = Vector3.new(-LIMB_CURVE, 0, 0) -- the nock, on the straight string
local PULL_BACK = Vector3.new(-6, 0, 0) -- where the nock goes at full charge, relative to rest
local BAND_THICKNESS = 0.3
local BAND_THINNING = 0.1 -- the string gets thinner as it stretches

-- A point on the upper (side = 1) or lower (side = -1) limb, t from 0 (grip) to 1 (tip).
local function limbPoint(t: number, side: number): Vector3
	return Vector3.new(-LIMB_CURVE * t * t, side * (GRIP_HALF + LIMB_LENGTH * t), 0)
end

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

-- A real model for this bow from ReplicatedStorage.BowModels, if one was added.
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

-- Builds the bow Tool for a level (0 = the first bow).
-- All parts are made in the bow's own space and welded to the handle.
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
	local handle = rod("Handle", Vector3.new(0, -GRIP_HALF, 0), Vector3.new(0, GRIP_HALF, 0), 1.5, frameColor, tool, material)

	local parts: { BasePart } = {}
	-- A leather wrap around the grip, with accent rings at each end.
	table.insert(parts, rod("Wrap", Vector3.new(0, -GRIP_HALF + 0.2, 0), Vector3.new(0, GRIP_HALF - 0.2, 0), 1.75, WRAP, tool, Enum.Material.Fabric))
	for i, y in { -GRIP_HALF, GRIP_HALF } do
		table.insert(parts, rod("Ring" .. i, Vector3.new(0, y - 0.2, 0), Vector3.new(0, y + 0.2, 0), 1.9, accent, tool))
	end
	-- The two limbs, each a chain of short rods that thins toward the tip.
	for _, side in { 1, -1 } do
		local limbName = if side > 0 then "LimbTop" else "LimbBottom"
		for i = 1, LIMB_SEGMENTS do
			local a = limbPoint((i - 1) / LIMB_SEGMENTS, side)
			local b = limbPoint(i / LIMB_SEGMENTS, side)
			local diameter = 1.3 - 0.6 * (i - 1) / (LIMB_SEGMENTS - 1)
			table.insert(parts, rod(limbName .. i, a, b, diameter, frameColor, tool, material))
			if i < LIMB_SEGMENTS then
				table.insert(parts, ball(limbName .. "Joint" .. i, b, diameter, frameColor, tool, material))
			end
		end
	end
	table.insert(parts, ball("TipTop", TIP_TOP, 1.1, accent, tool))
	table.insert(parts, ball("TipBottom", TIP_BOTTOM, 1.1, accent, tool))

	-- The nock in the middle of the string (named Pouch: the egg launches from it
	-- and the free hand reaches for it).
	local pouch = newPart("Pouch", accent, tool)
	pouch.Shape = Enum.PartType.Ball
	pouch.Size = Vector3.one * 0.9 * SCALE
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
	-- so line those up with the bow's forward (+X) and up (+Y).
	local gripFrame = CFrame.fromMatrix(scaled(GRIP_POINT), Vector3.zAxis, Vector3.yAxis, -Vector3.xAxis)
	tool.Grip = handle.CFrame:Inverse() * gripFrame

	-- setPull needs the handle's place in bow space to aim the welds.
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

-- Draws the string: 0 = at rest, 1 = fully drawn back.
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
	-- The two halves of the string, from each tip to the nock.
	local bands: { [string]: Vector3 } = { BandLeft = TIP_TOP, BandRight = TIP_BOTTOM }
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
