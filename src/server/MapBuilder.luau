--!strict
-- Builds the greybox map from code: the grassy hub with 5 plots (each with
-- 12 pedestals), the slingshot, egg and luck stands, the rebirth stand,
-- and the 8-zone lane. Everything goes into workspace.Map.
-- Real art replaces these blocks later; keep part names stable so code can find them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Lane = require(Shared.Lane)

local MapBuilder = {}

MapBuilder.PLOT_COUNT = 5

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
local PLOT_SPACING = 40

local HUB_COLOR = Color3.fromRGB(110, 185, 90)
local PLOT_COLOR = Color3.fromRGB(255, 245, 210)
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
	prompt.ActionText = if kind == "Rebirth" then "Rebirth" else "Upgrade"
	prompt.HoldDuration = if kind == "Rebirth" then 1.5 else 0
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
	local hubLength = Config.Hub.MaxX - Config.Hub.MinX
	part({
		Name = "Ground",
		Size = Vector3.new(hubLength, 2, Config.Hub.Width),
		Position = Vector3.new(Config.Hub.MinX + hubLength / 2, -1, 0),
		Color = HUB_COLOR,
		Material = Enum.Material.Grass,
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

	local map = Instance.new("Folder")
	map.Name = "Map"
	buildHub(map)
	buildLane(map)
	map.Parent = workspace
	return map
end

return MapBuilder
