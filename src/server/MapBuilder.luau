--!strict
-- Builds the map from code, following Tmuk's layout sketch: a studded green hub
-- ringed by checkered walls, with the 4 fenced plots (12 pedestals each) in a
-- row; the hub's front corners cut in diagonally (the Bow and Egg shops stand
-- against those walls) to one straight lane, the same width all the way: a short
-- walkway, then the 8 zones. Everything goes into workspace.Map, and Scenery adds
-- the decoration. Keep part names stable so code can find them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Lane = require(Shared.Lane)
local Shops = require(Shared.Shops)
local Scenery = require(script.Parent.Scenery)

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

-- The plots stand in a row across the hub, gates facing the lane (+X).
local PLOT_X = -150
local PLOT_SPACING = 46
local PLOT_SIZE = Vector3.new(50, 1, 34) -- X is front-to-back (gate at +X), Z is across

-- Two bright lime greens for the checkered, studded hub floor.
local FLOOR_COLORS = { Color3.fromRGB(132, 226, 60), Color3.fromRGB(118, 212, 50) }
local FLOOR_TILE = 20 -- studs per floor square
local PLOT_COLOR = Color3.fromRGB(165, 236, 105)
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

-- A fence around a plot, open in the middle of its front (local +X) side.
local function buildFence(plot: BasePart)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local top = plot.Size.Y / 2
	local halfX = plot.Size.X / 2 - 0.5
	local halfZ = plot.Size.Z / 2 - 0.5
	local function corner(x: number, z: number): Vector3
		return plot.CFrame:PointToWorldSpace(Vector3.new(x, top, z))
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
			-- Skip squares wholly outside the diagonal front corners.
			local nearZ = math.min(math.abs(z0), math.abs(z1))
			if z0 < 0 and z1 > 0 then
				nearZ = 0
			end
			if nearZ > Lane.hubHalfWidthAt(x0) + 2 then
				continue
			end
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

-- A wall along a path of corners, with a pillar at each corner so the joints
-- where the wall changes direction look solid.
local function wallPath(parent: Instance, points: { Vector3 }, tile: Vector2?, skipFirstPillar: boolean?)
	for i = 2, #points do
		wallRun(parent, points[i - 1], points[i], tile)
	end
	for i, point in points do
		if i == 1 and skipFirstPillar then
			continue -- another wall already put a pillar here
		end
		part({
			Name = "Pillar",
			Size = Vector3.new(WALL_THICKNESS + 2, WALL_HEIGHT + 2, WALL_THICKNESS + 2),
			Position = point + Vector3.new(0, (WALL_HEIGHT + 2) / 2, 0),
			Color = WALL_COLORS[2],
			Material = Enum.Material.Plastic,
			Parent = parent,
		})
		part({
			Name = "Grass",
			Size = Vector3.new(WALL_THICKNESS + 3, 1.5, WALL_THICKNESS + 3),
			Position = point + Vector3.new(0, WALL_HEIGHT + 2.75, 0),
			Color = FLOOR_COLORS[1],
			Material = Enum.Material.Plastic,
			TopSurface = Enum.SurfaceType.Studs,
			Parent = parent,
		})
	end
end

-- The hub's walls: across the back, down both sides, then diagonally in to the
-- corridor's mouth. The front stays open into the corridor.
local function buildWalls(hub: Folder)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	local back = Config.Hub.MinX - WALL_THICKNESS / 2
	local half = Config.Hub.Width / 2 + WALL_THICKNESS / 2
	local corridor = Config.Lane.Width / 2 + WALL_THICKNESS / 2
	wallRun(walls, Vector3.new(back, 0, -half), Vector3.new(back, 0, half))
	for _, side in { -1, 1 } do
		wallPath(walls, {
			Vector3.new(back, 0, side * half),
			Vector3.new(Config.Hub.ChamferX, 0, side * half),
			Vector3.new(Config.Hub.MaxX, 0, side * corridor),
		})
	end
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

-- Where plot N sits: in a row along Z, centred on the hub, gate (+X) toward the lane.
function MapBuilder.plotCFrame(index: number): CFrame
	local z = (index - (MapBuilder.PLOT_COUNT + 1) / 2) * PLOT_SPACING
	return CFrame.new(PLOT_X, 0.5, z)
end

-- A small kiosk (posts, a counter, a coloured roof and a sign) with a glowing
-- circle on the floor in front of it. Standing in the circle opens the shop.
local function buildStand(parent: Instance, shop: Shops.Shop)
	-- The stand's own frame: -Z (LookVector) points where the counter faces.
	local base = CFrame.lookAt(shop.Position, shop.Position + shop.Facing)
	local stand = Instance.new("Model")
	stand.Name = shop.Kind .. "Stand"

	-- A real stand model: a Model in ReplicatedStorage.StandModels named like the
	-- shop's title, with its pivot on the floor and its front facing -Z.
	local folder = ReplicatedStorage:FindFirstChild("StandModels")
	local custom = folder and folder:FindFirstChild(shop.Title)
	local signAnchor: BasePart
	if custom and custom:IsA("Model") then
		local copy = custom:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		copy:PivotTo(base)
		copy.Parent = stand
		local box, size = copy:GetBoundingBox()
		signAnchor = part({
			Name = "SignAnchor",
			Size = Vector3.one,
			CFrame = CFrame.new(box.Position + Vector3.new(0, size.Y / 2, 0)),
			Transparency = 1,
			CanCollide = false,
			Parent = stand,
		})
	else
		-- Wood and Fabric (not plain plastic), so a MaterialVariant set in
		-- MaterialService restyles every stand at once.
		part({
			Name = "Counter",
			Size = Vector3.new(12, 4, 4),
			CFrame = base * CFrame.new(0, 2, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
			Parent = stand,
		})
		for _, x in { -5.5, 5.5 } do
			part({
				Name = "Post",
				Size = Vector3.new(1, 10, 1),
				CFrame = base * CFrame.new(x, 5, 1.5),
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
				Parent = stand,
			})
		end
		signAnchor = part({
			Name = "Roof",
			Size = Vector3.new(14, 1, 7),
			CFrame = base * CFrame.new(0, 10.5, 1),
			Color = shop.Color,
			Material = Enum.Material.Fabric,
			Parent = stand,
		})
	end
	sign(signAnchor, shop.Title, 4, UDim2.fromScale(14, 3), 300)

	-- The circle: a glowing disc in the shop's colour inside a white ring.
	-- The client makes it pulse (HudController).
	local center = Shops.zoneCenter(shop)
	local diameter = Shops.ZONE_RADIUS * 2
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's round faces point along X; turn them up
	part({
		Name = "ZoneRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, diameter + 1.4, diameter + 1.4),
		CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * flat,
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = stand,
	})
	local zone = part({
		Name = "Zone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, diameter, diameter),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * flat,
		Color = shop.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		Parent = stand,
	})
	zone:SetAttribute("Kind", shop.Kind)
	local light = Instance.new("PointLight")
	light.Color = shop.Color
	light.Range = 14
	light.Brightness = 2
	light.Parent = zone

	stand.Parent = parent
end

local function buildHub(map: Folder): { CFrame }
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	-- Hub floor sits on the -X side of the lane and runs right up to its start line.
	buildFloor(hub)
	buildWalls(hub)

	local plotFrames = {}
	for i = 1, MapBuilder.PLOT_COUNT do
		local plot = part({
			Name = "Plot" .. i,
			Size = PLOT_SIZE,
			CFrame = MapBuilder.plotCFrame(i),
			Color = PLOT_COLOR,
			Material = Enum.Material.Plastic,
			TopSurface = Enum.SurfaceType.Studs,
			Parent = hub,
		})
		buildFence(plot)
		sign(plot, "Plot " .. i, 8, UDim2.fromOffset(260, 70), 400)

		table.insert(plotFrames, plot.CFrame)
		local plotTop = plot.Size.Y / 2
		for n, spot in PEDESTAL_SPOTS do
			local pedestal = part({
				Name = "Pedestal" .. n,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.5, 5, 5),
				CFrame = plot.CFrame * CFrame.new(spot.X, plotTop + 0.75, spot.Y) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(240, 240, 250),
				Parent = plot,
			})
			pedestal:SetAttribute("Index", n)
		end
	end

	for _, shop in Shops.LIST do
		buildStand(hub, shop)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- In front of the plots, facing the lane so players spawn looking down it.
	spawn.CFrame = CFrame.lookAt(Vector3.new(-90, 0.5, 0), Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Parent = hub
	return plotFrames
end

-- The walkway floor from the hub to the zones: hub-style green squares.
local function buildCorridor(lane: Instance)
	local corridor = Instance.new("Folder")
	corridor.Name = "Corridor"
	corridor.Parent = lane
	local length = Config.Lane.StartX - Config.Hub.MaxX
	local width = Config.Lane.Width + WALL_THICKNESS * 2
	local columns = math.ceil(length / FLOOR_TILE)
	local rows = math.ceil(width / FLOOR_TILE)
	for col = 0, columns - 1 do
		for row = 0, rows - 1 do
			local x0 = Config.Hub.MaxX + col * FLOOR_TILE
			local x1 = math.min(x0 + FLOOR_TILE, Config.Lane.StartX)
			local z0 = -width / 2 + row * FLOOR_TILE
			local z1 = math.min(z0 + FLOOR_TILE, width / 2)
			part({
				Name = "Tile",
				Size = Vector3.new(x1 - x0, 2, z1 - z0),
				Position = Vector3.new((x0 + x1) / 2, -1, (z0 + z1) / 2),
				Color = FLOOR_COLORS[(col + row) % 2 + 1],
				Material = Enum.Material.Plastic,
				TopSurface = Enum.SurfaceType.Studs,
				Parent = corridor,
			})
		end
	end
end

local function buildLane(map: Folder)
	-- The lane is longer than the default streaming radius (1024 studs), so keep it
	-- loaded on every client; otherwise the far zones never appear from the hub.
	local laneFolder = Instance.new("Model")
	laneFolder.Name = "Lane"
	laneFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	laneFolder.Parent = map

	buildCorridor(laneFolder)

	-- Walls: straight down both sides of the lane (Lane.Edges), and across the far end.
	local laneWalls = Instance.new("Folder")
	laneWalls.Name = "Walls"
	local corridorZ = Config.Lane.Width / 2 + WALL_THICKNESS / 2
	local ends: { [number]: Vector3 } = {}
	for _, side in { -1, 1 } do
		local points = { Vector3.new(Config.Hub.MaxX, 0, side * corridorZ) }
		for _, edge in Lane.Edges[side] do
			table.insert(points, Vector3.new(edge.X, 0, side * (edge.Y + WALL_THICKNESS / 2)))
		end
		wallPath(laneWalls, points, LANE_WALL_TILE, true)
		ends[side] = points[#points]
	end
	local endX = Lane.EndX + WALL_THICKNESS / 2
	wallRun(laneWalls, Vector3.new(endX, 0, ends[-1].Z), Vector3.new(endX, 0, ends[1].Z), LANE_WALL_TILE)
	laneWalls.Parent = laneFolder

	-- The ground is wider than the widest point between the walls, so it always
	-- reaches under them. Each zone is striped in two shades of its colour, which
	-- also helps you judge how far an egg went.
	local length = Config.Lane.ZoneLength
	local groundWidth = (Lane.MaxHalfWidth + 20) * 2
	local STRIPE = 25
	for i, zone in Config.Zones do
		local startX = Lane.zoneStartX(i)
		local ground = part({
			Name = "Zone" .. i,
			Size = Vector3.new(length, 2, groundWidth),
			Position = Vector3.new(startX + length / 2, -1, 0),
			Color = zone.Color,
			Material = Enum.Material.Plastic,
			TopSurface = Enum.SurfaceType.Studs,
			Parent = laneFolder,
		})
		ground:SetAttribute("ZoneIndex", i)
		local darker = zone.Color:Lerp(Color3.new(0, 0, 0), 0.07)
		for s = 1, length / STRIPE - 1, 2 do
			part({
				Name = "Stripe",
				Size = Vector3.new(STRIPE, 0.2, groundWidth),
				Position = Vector3.new(startX + s * STRIPE + STRIPE / 2, -0.08, 0),
				Color = darker,
				Material = Enum.Material.Plastic,
				TopSurface = Enum.SurfaceType.Studs,
				CanCollide = false,
				CanQuery = false,
				Parent = ground,
			})
		end

		-- A sign post on the edge of the lane. Posts alternate sides so the
		-- names don't stack on top of each other when seen from the hub.
		local side = if i % 2 == 0 then 1 else -1
		local post = part({
			Name = "Sign",
			Size = Vector3.new(2, 10, 2),
			Position = Vector3.new(startX + 6, 5, side * (Lane.halfWidthAt(startX + 6, side) - 10)),
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
			Size = Vector3.new(1.5, 0.2, groundWidth),
			Position = Vector3.new(startX, 0.1, 0),
			Material = Enum.Material.Neon,
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
	local plotFrames = buildHub(map)
	buildLane(map)
	Scenery.build(map, plotFrames)
	map.Parent = workspace
	return map
end

return MapBuilder
