--!strict
-- Builds the greybox map from code: the studded green hub ringed by checkered
-- walls, 5 fenced plots (each with 12 pedestals), the slingshot, egg and luck
-- stands, the rebirth stand, and the 8-zone lane. Everything goes into workspace.Map.
-- Real art replaces these blocks later; keep part names stable so code can find them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Lane = require(Shared.Lane)

local MapBuilder = {}

MapBuilder.PLOT_COUNT = 4 -- one per player; servers hold 4

-- Pedestal spots on a plot, relative to the plot's centre, in fill order
-- (front row nearest the lane first).
local PEDESTAL_SPOTS: { Vector2 } = {}
for _, x in { 9, -3, -15 } do
	for _, z in { -4, 4, -12, 12 } do
		table.insert(PEDESTAL_SPOTS, Vector2.new(x, z))
	end
end
assert(#PEDESTAL_SPOTS == Config.Plot.MaxPedestals, "pedestal spots must match Config.Plot.MaxPedestals")

-- The three upgrade stands and the rebirth stand: name, position, roof colour.
MapBuilder.STANDS = {
	{ Kind = "Slingshot", Title = "Slingshot", Position = Vector3.new(-55, 0, -45), Color = Color3.fromRGB(255, 120, 160) },
	{ Kind = "Egg", Title = "Eggs", Position = Vector3.new(-55, 0, 0), Color = Color3.fromRGB(255, 205, 80) },
	{ Kind = "Luck", Title = "Luck", Position = Vector3.new(-55, 0, 45), Color = Color3.fromRGB(110, 210, 110) },
	{ Kind = "Rebirth", Title = "Rebirth", Position = Vector3.new(-100, 0, 62), Color = Color3.fromRGB(150, 110, 255) },
}

local PLOT_X = -150
local PLOT_SPACING = 46

-- Two greens for the checkered, studded hub floor.
local FLOOR_COLORS = { Color3.fromRGB(118, 205, 72), Color3.fromRGB(104, 190, 62) }
local FLOOR_TILE = 20 -- studs per floor square
local PLOT_COLOR = Color3.fromRGB(150, 225, 100)
local WOOD_COLOR = Color3.fromRGB(170, 120, 80)

-- The walls around the hub: two checkered browns with a strip of grass on top.
local WALL_COLORS = { Color3.fromRGB(215, 150, 95), Color3.fromRGB(190, 125, 75) }
local WALL_HEIGHT = 24
local WALL_THICKNESS = 4
local WALL_TILE = Vector2.new(20, 12) -- width and height of each wall square around the hub
local LANE_WALL_TILE = Vector2.new(50, 24) -- bigger squares along the long lane, to keep the part count down

-- Plot fences: dark posts with orange rails and cross braces.
local FENCE_POST_COLOR = Color3.fromRGB(85, 60, 45)
local FENCE_RAIL_COLOR = Color3.fromRGB(195, 115, 60)
local FENCE_HEIGHT = 4.5
local FENCE_GATE = 10 -- gap in the front fence, facing the lane

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

-- A thin bar from `a` to `b`.
local function bar(parent: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3): Part
	return part({
		Name = name,
		Size = Vector3.new(thickness, thickness, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color,
		Parent = parent,
	})
end

-- One straight run of fence on the ground at height `y`, from `a` to `b`:
-- posts about every 8 studs, a top and bottom rail, and an X brace between posts.
local function fenceRun(parent: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local segments = math.max(1, math.ceil(length / 8))
	local up = Vector3.new(0, FENCE_HEIGHT, 0)
	local low = Vector3.new(0, 0.8, 0)
	local high = Vector3.new(0, FENCE_HEIGHT - 0.6, 0)
	for i = 0, segments do
		local at = a:Lerp(b, i / segments)
		part({
			Name = "Post",
			Size = Vector3.new(1, FENCE_HEIGHT, 1),
			Position = at + up / 2,
			Color = FENCE_POST_COLOR,
			Parent = parent,
		})
		if i > 0 then
			local from = a:Lerp(b, (i - 1) / segments)
			bar(parent, "Brace", from + low, at + high, 0.4, FENCE_RAIL_COLOR).CanCollide = false
			bar(parent, "Brace", from + high, at + low, 0.4, FENCE_RAIL_COLOR).CanCollide = false
		end
	end
	bar(parent, "Rail", a + low, b + low, 0.6, FENCE_RAIL_COLOR)
	bar(parent, "Rail", a + high, b + high, 0.6, FENCE_RAIL_COLOR)
end

-- A fence around a plot, open in the middle of the side facing the lane (+X).
local function buildFence(plot: BasePart)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local top = plot.Position.Y + plot.Size.Y / 2
	local halfX = plot.Size.X / 2 - 0.5
	local halfZ = plot.Size.Z / 2 - 0.5
	local function corner(x: number, z: number): Vector3
		return Vector3.new(plot.Position.X + x, top, plot.Position.Z + z)
	end
	fenceRun(fence, corner(-halfX, -halfZ), corner(-halfX, halfZ)) -- back
	fenceRun(fence, corner(-halfX, -halfZ), corner(halfX, -halfZ)) -- sides
	fenceRun(fence, corner(-halfX, halfZ), corner(halfX, halfZ))
	fenceRun(fence, corner(halfX, -halfZ), corner(halfX, -FENCE_GATE / 2)) -- front, either side of the gate
	fenceRun(fence, corner(halfX, FENCE_GATE / 2), corner(halfX, halfZ))
	fence.Parent = plot
end

-- The hub floor: big studded squares in two greens, like a checkerboard.
local function buildFloor(hub: Folder)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	local length = Config.Hub.MaxX - Config.Hub.MinX
	local columns = math.ceil(length / FLOOR_TILE)
	local rows = math.ceil(Config.Hub.Width / FLOOR_TILE)
	for col = 0, columns - 1 do
		for row = 0, rows - 1 do
			local x0 = Config.Hub.MinX + col * FLOOR_TILE
			local x1 = math.min(x0 + FLOOR_TILE, Config.Hub.MaxX)
			local z0 = -Config.Hub.Width / 2 + row * FLOOR_TILE
			local z1 = math.min(z0 + FLOOR_TILE, Config.Hub.Width / 2)
			part({
				Name = "Tile",
				Size = Vector3.new(x1 - x0, 2, z1 - z0),
				Position = Vector3.new((x0 + x1) / 2, -1, (z0 + z1) / 2),
				Color = FLOOR_COLORS[(col + row) % 2 + 1],
				Material = Enum.Material.Plastic,
				TopSurface = Enum.SurfaceType.Studs,
				Parent = ground,
			})
		end
	end
	ground.Parent = hub
end

-- A checkered wall from `a` to `b` (on the ground, wall centre line), with grass on top.
-- Each square's length runs along its Z axis, which lookAt points down the wall.
local function wallRun(parent: Instance, a: Vector3, b: Vector3, tile: Vector2?)
	local size = tile or WALL_TILE
	local length = (b - a).Magnitude
	local columns = math.ceil(length / size.X)
	local rows = math.ceil(WALL_HEIGHT / size.Y)
	local direction = (b - a).Unit
	for col = 0, columns - 1 do
		local s0 = col * size.X
		local s1 = math.min(s0 + size.X, length)
		for row = 0, rows - 1 do
			local y0 = row * size.Y
			local y1 = math.min(y0 + size.Y, WALL_HEIGHT)
			local centre = a + direction * ((s0 + s1) / 2) + Vector3.new(0, (y0 + y1) / 2, 0)
			part({
				Name = "Wall",
				Size = Vector3.new(WALL_THICKNESS, y1 - y0, s1 - s0),
				CFrame = CFrame.lookAt(centre, centre + direction),
				Color = WALL_COLORS[(col + row) % 2 + 1],
				Material = Enum.Material.Plastic,
				Parent = parent,
			})
		end
	end
	local capCentre = (a + b) / 2 + Vector3.new(0, WALL_HEIGHT + 1, 0)
	part({
		Name = "Grass",
		Size = Vector3.new(WALL_THICKNESS + 2, 2, length + 2),
		CFrame = CFrame.lookAt(capCentre, capCentre + direction),
		Color = FLOOR_COLORS[1],
		Material = Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Studs,
		Parent = parent,
	})
end

-- Walls on the back and both sides of the hub; the side facing the lane stays open.
local function buildWalls(hub: Folder)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	local back = Config.Hub.MinX - WALL_THICKNESS / 2
	local side = Config.Hub.Width / 2 + WALL_THICKNESS / 2
	local front = Config.Hub.MaxX
	wallRun(walls, Vector3.new(back, 0, -side - WALL_THICKNESS / 2), Vector3.new(back, 0, side + WALL_THICKNESS / 2))
	wallRun(walls, Vector3.new(back + WALL_THICKNESS / 2, 0, -side), Vector3.new(front, 0, -side))
	wallRun(walls, Vector3.new(back + WALL_THICKNESS / 2, 0, side), Vector3.new(front, 0, side))
	walls.Parent = hub
end

-- `size` in scale units is measured in studs, so far-away signs shrink with distance.
local function sign(parent: BasePart, text: string, height: number, size: UDim2, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = size
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui

	gui.Parent = parent
	return gui
end

-- A zone's drop rates as one line of text, with a dot in each rarity's colour.
local function dropRatesText(rates: { number }): string
	local items = {}
	for i, rate in rates do
		if rate > 0 then
			local color = Config.Rarities[i].Color:ToHex()
			table.insert(items, `<font color="#{color}">●</font>{rate}%`)
		end
	end
	return table.concat(items, "  ")
end

-- Position of plot N along Z, centred on the hub.
function MapBuilder.slotZ(index: number): number
	return (index - (MapBuilder.PLOT_COUNT + 1) / 2) * PLOT_SPACING
end

-- A small kiosk: posts, a counter with a prompt, a coloured roof and a sign.
local function buildStand(parent: Instance, kind: string, title: string, position: Vector3, roofColor: Color3)
	local stand = Instance.new("Model")
	stand.Name = kind .. "Stand"

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(4, 4, 12),
		Position = position + Vector3.new(0, 2, 0),
		Color = WOOD_COLOR,
		Parent = stand,
	})
	for _, z in { -5.5, 5.5 } do
		part({
			Name = "Post",
			Size = Vector3.new(1, 10, 1),
			Position = position + Vector3.new(-1.5, 5, z),
			Color = WOOD_COLOR,
			Parent = stand,
		})
	end
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(7, 1, 14),
		Position = position + Vector3.new(-1, 10.5, 0),
		Color = roofColor,
		Parent = stand,
	})
	sign(roof, title, 4, UDim2.fromScale(12, 3), 300)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = title
	prompt.ActionText = "Open shop" -- the client opens the Shop on this stand's page
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = counter

	stand.Parent = parent
end

local function buildHub(map: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	-- Hub floor sits on the -X side of the lane and runs right up to its start line.
	buildFloor(hub)
	buildWalls(hub)

	for i = 1, MapBuilder.PLOT_COUNT do
		local z = MapBuilder.slotZ(i)

		local plot = part({
			Name = "Plot" .. i,
			Size = Vector3.new(50, 1, 34),
			Position = Vector3.new(PLOT_X, 0.5, z),
			Color = PLOT_COLOR,
			Material = Enum.Material.Plastic,
			TopSurface = Enum.SurfaceType.Studs,
			Parent = hub,
		})
		buildFence(plot)
		sign(plot, "Plot " .. i, 8, UDim2.fromOffset(260, 70), 400)

		local plotTop = plot.Position.Y + plot.Size.Y / 2
		for n, spot in PEDESTAL_SPOTS do
			local pedestal = part({
				Name = "Pedestal" .. n,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.5, 5, 5),
				CFrame = CFrame.new(plot.Position.X + spot.X, plotTop + 0.75, plot.Position.Z + spot.Y)
					* CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(240, 240, 250),
				Parent = plot,
			})
			pedestal:SetAttribute("Index", n)
		end
	end

	for _, info in MapBuilder.STANDS do
		buildStand(hub, info.Kind, info.Title, info.Position, info.Color)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- Face the lane, so players spawn looking down it.
	spawn.CFrame = CFrame.lookAt(Vector3.new(-90, 0.5, 0), Vector3.new(0, 0.5, 0))
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

	-- Walls down both sides of the lane and across its far end, joining the hub's walls.
	local laneEnd = Config.Lane.StartX + Lane.Length
	local wallZ = Config.Lane.Width / 2 + WALL_THICKNESS / 2
	local laneWalls = Instance.new("Folder")
	laneWalls.Name = "Walls"
	wallRun(laneWalls, Vector3.new(Config.Lane.StartX, 0, -wallZ), Vector3.new(laneEnd, 0, -wallZ), LANE_WALL_TILE)
	wallRun(laneWalls, Vector3.new(Config.Lane.StartX, 0, wallZ), Vector3.new(laneEnd, 0, wallZ), LANE_WALL_TILE)
	local endX = laneEnd + WALL_THICKNESS / 2
	wallRun(laneWalls, Vector3.new(endX, 0, -wallZ - WALL_THICKNESS / 2), Vector3.new(endX, 0, wallZ + WALL_THICKNESS / 2), LANE_WALL_TILE)
	laneWalls.Parent = laneFolder

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
		-- Zone name, with its drop rates underneath.
		local zoneSign = sign(post, zone.Name, 12, UDim2.fromScale(40, 14), math.huge)
		local nameLabel = zoneSign:FindFirstChild("Label") :: TextLabel
		nameLabel.Size = UDim2.fromScale(1, 0.68)
		local rates = Instance.new("TextLabel")
		rates.Name = "DropRates"
		rates.BackgroundTransparency = 1
		rates.Position = UDim2.fromScale(0, 0.7)
		rates.Size = UDim2.fromScale(1, 0.3)
		rates.Font = Enum.Font.FredokaOne
		rates.TextScaled = true
		rates.RichText = true
		rates.TextColor3 = Color3.new(1, 1, 1)
		rates.TextStrokeTransparency = 0.2
		rates.Text = dropRatesText(zone.DropRates)
		rates.Parent = zoneSign

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
	-- So would the template's spawn pad; players should only spawn on ours in the hub.
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") then
			instance:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	buildHub(map)
	buildLane(map)
	map.Parent = workspace
	return map
end

return MapBuilder
