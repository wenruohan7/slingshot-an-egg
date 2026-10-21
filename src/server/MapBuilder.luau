--!strict
-- Builds the greybox map from code: the hub with 5 plots and launch pads,
-- and the 8-zone lane. Everything goes into workspace.Map.
-- Real art replaces these blocks later; keep part names stable so code can find them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Lane = require(Shared.Lane)
local SlingshotModel = require(Shared.SlingshotModel)

local MapBuilder = {}

MapBuilder.PLOT_COUNT = 5

-- Hub sits on the -X side of the lane.
local HUB_CENTER = Vector3.new(-100, 0, 0)
local HUB_SIZE = Vector3.new(180, 2, 200)
local PLOT_X = -150
local PAD_X = -25
local PLOT_SPACING = 40

local HUB_COLOR = Color3.fromRGB(255, 225, 235)
local PLOT_COLOR = Color3.fromRGB(255, 245, 210)
local PAD_COLOR = Color3.fromRGB(120, 190, 255)
local WOOD_COLOR = Color3.fromRGB(170, 120, 80)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- `size` in scale units is measured in studs, so far-away signs shrink with distance.
local function sign(parent: BasePart, text: string, height: number, size: UDim2, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui

	gui.Parent = parent
end

-- Position of plot / pad N along Z, centred on the hub.
function MapBuilder.slotZ(index: number): number
	return (index - (MapBuilder.PLOT_COUNT + 1) / 2) * PLOT_SPACING
end

local function buildHub(map: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	part({
		Name = "Ground",
		Size = HUB_SIZE,
		Position = HUB_CENTER - Vector3.new(0, HUB_SIZE.Y / 2, 0),
		Color = HUB_COLOR,
		Parent = hub,
	})

	for i = 1, MapBuilder.PLOT_COUNT do
		local z = MapBuilder.slotZ(i)

		local plot = part({
			Name = "Plot" .. i,
			Size = Vector3.new(50, 1, 34),
			Position = Vector3.new(PLOT_X, 0.5, z),
			Color = PLOT_COLOR,
			Parent = hub,
		})
		sign(plot, "Plot " .. i, 6, UDim2.fromOffset(240, 60), 400)

		local pad = part({
			Name = "LaunchPad" .. i,
			Size = Vector3.new(14, 1, 14),
			Position = Vector3.new(PAD_X, 0.5, z),
			Color = PAD_COLOR,
			Parent = hub,
		})
		-- Slingshot at the lane-side edge of the pad, so the player stands behind it.
		local padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
		SlingshotModel.build(pad, CFrame.new(padTop + Vector3.new(3, 0, 0)))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(-90, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Parent = hub
end

local function buildLane(map: Folder)
	-- The lane is longer than the default streaming radius (1024 studs), so keep it
	-- loaded on every client; otherwise the far zones never appear from the hub.
	local laneFolder = Instance.new("Model")
	laneFolder.Name = "Lane"
	laneFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	laneFolder.Parent = map

	local length = Config.Lane.ZoneLength
	for i, zone in Config.Zones do
		local startX = Lane.zoneStartX(i)
		local ground = part({
			Name = "Zone" .. i,
			Size = Vector3.new(length, 2, Config.Lane.Width),
			Position = Vector3.new(startX + length / 2, -1, 0),
			Color = zone.Color,
			Material = Enum.Material.Grass,
			Parent = laneFolder,
		})
		ground:SetAttribute("ZoneIndex", i)

		-- A sign post on the edge of the lane. Posts alternate sides so the
		-- names don't stack on top of each other when seen from the hub.
		local side = if i % 2 == 0 then 1 else -1
		local post = part({
			Name = "Sign",
			Size = Vector3.new(2, 10, 2),
			Position = Vector3.new(startX + 6, 5, side * (Config.Lane.Width / 2 - 4)),
			Color = WOOD_COLOR,
			Parent = ground,
		})
		sign(post, zone.Name, 10, UDim2.fromScale(40, 10), math.huge)

		-- White line marking where the zone begins.
		part({
			Name = "Line",
			Size = Vector3.new(1, 0.2, Config.Lane.Width),
			Position = Vector3.new(startX, 0.1, 0),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			Parent = ground,
		})
	end
end

function MapBuilder.build(): Folder
	-- The default Baseplate would overlap our ground, so remove it while playing.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	buildHub(map)
	buildLane(map)
	map.Parent = workspace
	return map
end

return MapBuilder
