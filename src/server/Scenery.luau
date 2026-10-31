--!strict
-- Decoration built from simple parts: trees, bushes and flowers around the hub,
-- themed props down the sides of each zone, and floating candy islands, giant
-- lollipops and a big moon out past the walls so the sky never looks empty.
--
-- None of it does anything in the game. Props on the lane stay near the walls
-- (eggs land in the middle) and never collide, so they can't block a landing.
-- Layout uses a fixed random seed, so the map looks the same every time.
-- Real models can replace any of these later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Lane = require(Shared.Lane)
local Shops = require(Shared.Shops)

local Scenery = {}

local rng = Random.new(20261031)

local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis (X) to point up

--------------------------------------------------------------------------------
-- Building blocks
--------------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function ball(parent: Instance, at: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		Position = at,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- An upright cylinder standing on `bottom`.
local function column(parent: Instance, bottom: Vector3, height: number, diameter: number, color: Color3): Part
	return part(parent, {
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * UP,
		Color = color,
	})
end

-- A flat disc lying on the ground (or anywhere), `thickness` tall.
local function disc(parent: Instance, center: Vector3, diameter: number, thickness: number, color: Color3): Part
	return part(parent, {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(center) * UP,
		Color = color,
	})
end

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local TRUNK = Color3.fromRGB(125, 85, 55)
local LEAF = Color3.fromRGB(95, 200, 70)
local CANDY = {
	Color3.fromRGB(255, 120, 170), -- pink
	Color3.fromRGB(120, 200, 255), -- sky blue
	Color3.fromRGB(255, 200, 70), -- lemon
	Color3.fromRGB(170, 120, 255), -- grape
	Color3.fromRGB(120, 230, 150), -- mint
}
local FLOWER = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 60),
}
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 230, 70),
	Color3.fromRGB(100, 220, 100),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(170, 100, 240),
}

--------------------------------------------------------------------------------
-- Props. Each one takes the spot on the ground it stands on.
--------------------------------------------------------------------------------

-- A round cartoon tree: trunk plus three leafy balls.
local function tree(parent: Instance, at: Vector3, scale: number, leaf: Color3?)
	local m = model(parent, "Tree")
	local color = leaf or LEAF
	column(m, at, 6 * scale, 1.6 * scale, TRUNK)
	ball(m, at + Vector3.new(0, 7.5 * scale, 0), 7 * scale, color)
	ball(m, at + Vector3.new(2 * scale, 6 * scale, 1 * scale), 4.5 * scale, shade(color, 0.08))
	ball(m, at + Vector3.new(-1.8 * scale, 6.5 * scale, -1.2 * scale), 4.5 * scale, color:Lerp(Color3.new(1, 1, 0.6), 0.12))
end

local function bush(parent: Instance, at: Vector3, scale: number, color: Color3?)
	local m = model(parent, "Bush")
	local c = color or LEAF
	ball(m, at + Vector3.new(0, 1.4 * scale, 0), 3.4 * scale, c)
	ball(m, at + Vector3.new(1.6 * scale, 1 * scale, 0.4 * scale), 2.4 * scale, shade(c, 0.07))
	ball(m, at + Vector3.new(-1.4 * scale, 1 * scale, -0.5 * scale), 2.6 * scale, c:Lerp(Color3.new(1, 1, 0.6), 0.1))
end

local function rock(parent: Instance, at: Vector3, scale: number, color: Color3?)
	local size = Vector3.new(rng:NextNumber(2.5, 4), rng:NextNumber(1.6, 2.6), rng:NextNumber(2.5, 4)) * scale
	part(parent, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(at + Vector3.new(0, size.Y * 0.35, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Color = color or Color3.fromRGB(150, 155, 165),
	})
end

local function flower(parent: Instance, at: Vector3, color: Color3?)
	local m = model(parent, "Flower")
	column(m, at, 1.2, 0.25, Color3.fromRGB(70, 160, 60))
	ball(m, at + Vector3.new(0, 1.4, 0), 0.9, color or pick(FLOWER))
end

-- A swirly lollipop: white stick, a coloured disc with a white ring on it.
local function lollipop(parent: Instance, at: Vector3, scale: number, color: Color3?)
	local m = model(parent, "Lollipop")
	local c = color or pick(CANDY)
	local stick = 8 * scale
	column(m, at, stick, 0.6 * scale, Color3.fromRGB(250, 250, 250))
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local center = CFrame.new(at + Vector3.new(0, stick + 2.6 * scale, 0)) * yaw
	local function face(diameter: number, thickness: number, color3: Color3)
		part(m, {
			Name = "Candy",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(thickness, diameter, diameter),
			CFrame = center,
			Color = color3,
		})
	end
	face(6 * scale, 1 * scale, c)
	face(4.2 * scale, 1.1 * scale, Color3.fromRGB(255, 255, 255))
	face(2.6 * scale, 1.2 * scale, c)
	face(1 * scale, 1.3 * scale, Color3.fromRGB(255, 255, 255))
end

-- A red and white striped pole with a ball on top.
local function candyPole(parent: Instance, at: Vector3, scale: number)
	local m = model(parent, "CandyPole")
	local segments = 6
	local segment = 1.6 * scale
	for i = 0, segments - 1 do
		local color = if i % 2 == 0 then Color3.fromRGB(240, 60, 70) else Color3.fromRGB(255, 255, 255)
		column(m, at + Vector3.new(0, i * segment, 0), segment, 1.2 * scale, color)
	end
	ball(m, at + Vector3.new(0, segments * segment + 0.6 * scale, 0), 1.8 * scale, Color3.fromRGB(240, 60, 70))
end

local function palm(parent: Instance, at: Vector3, scale: number)
	local m = model(parent, "Palm")
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * 0.6 * scale
	local top = at
	for i = 1, 5 do
		local nextTop = top + Vector3.new(0, 2.2 * scale, 0) + lean * (i / 5)
		part(m, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((nextTop - top).Magnitude + 0.2, (1.3 - i * 0.08) * scale, (1.3 - i * 0.08) * scale),
			CFrame = CFrame.lookAt((top + nextTop) / 2, nextTop) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(170, 120, 75),
		})
		top = nextTop
	end
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		part(m, {
			Name = "Leaf",
			Size = Vector3.new(1.8 * scale, 0.3 * scale, 6 * scale),
			CFrame = CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.Angles(-0.45, 0, 0) * CFrame.new(0, 0, -2.8 * scale),
			Color = Color3.fromRGB(80, 190, 80),
		})
	end
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2
		ball(m, top + Vector3.new(math.cos(angle) * 0.7 * scale, -0.6 * scale, math.sin(angle) * 0.7 * scale), 0.9 * scale, Color3.fromRGB(120, 80, 50))
	end
end

local function cloudPuff(parent: Instance, at: Vector3, scale: number)
	local m = model(parent, "CloudPuff")
	local white = Color3.fromRGB(255, 255, 255)
	ball(m, at + Vector3.new(0, 2 * scale, 0), 5 * scale, white)
	ball(m, at + Vector3.new(3 * scale, 1.4 * scale, 0.5 * scale), 3.6 * scale, white)
	ball(m, at + Vector3.new(-3 * scale, 1.5 * scale, -0.4 * scale), 3.8 * scale, white)
	ball(m, at + Vector3.new(0.5 * scale, 1.2 * scale, 2.4 * scale), 3 * scale, Color3.fromRGB(240, 245, 255))
end

local function crystal(parent: Instance, at: Vector3, scale: number, color: Color3)
	local m = model(parent, "Crystal")
	for i = 1, 3 do
		local height = rng:NextNumber(4, 8) * scale * (if i == 1 then 1.3 else 1)
		local width = rng:NextNumber(1.2, 2) * scale
		local tilt = if i == 1 then 0 else 0.35
		part(m, {
			Name = "Shard",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(at) * CFrame.Angles(0, i * 2.1, 0) * CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, height / 2 - 0.5, 0) * CFrame.Angles(0, math.pi / 4, 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
	end
end

-- A glowing star chunk. Neon makes it glow with the bloom in Environment.
local function star(parent: Instance, at: Vector3, scale: number)
	local m = model(parent, "Star")
	local gold = Color3.fromRGB(255, 225, 110)
	ball(m, at, 1.6 * scale, gold, Enum.Material.Neon)
	for i = 1, 4 do
		part(m, {
			Name = "Point",
			Size = Vector3.new(0.4 * scale, 0.4 * scale, 3.4 * scale),
			CFrame = CFrame.new(at) * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.Angles(math.pi / 2 * (i % 2), 0, 0),
			Color = gold,
			Material = Enum.Material.Neon,
		})
	end
end

local function crater(parent: Instance, at: Vector3, diameter: number, ground: Color3)
	local m = model(parent, "Crater")
	disc(m, at + Vector3.new(0, 0.1, 0), diameter, 0.4, shade(ground, -0.12):Lerp(Color3.new(1, 1, 1), 0.15))
	disc(m, at + Vector3.new(0, 0.15, 0), diameter * 0.75, 0.4, shade(ground, 0.25))
end

local function pond(parent: Instance, at: Vector3, diameter: number)
	local m = model(parent, "Pond")
	disc(m, at + Vector3.new(0, 0.08, 0), diameter + 4, 0.3, Color3.fromRGB(240, 220, 160)) -- sand
	local water = disc(m, at + Vector3.new(0, 0.12, 0), diameter, 0.3, Color3.fromRGB(80, 190, 240))
	water.Material = Enum.Material.Glass
	water.Transparency = 0.1
end

-- A rainbow arch standing on the ground, running along the lane (X).
local function rainbowArch(parent: Instance, at: Vector3, radius: number)
	local m = model(parent, "Rainbow")
	local band = 2
	local segments = 12
	for b, color in RAINBOW do
		local r = radius - (b - 1) * band
		local segLength = math.pi * r / segments + 0.4
		for s = 0, segments - 1 do
			local angle = (s + 0.5) / segments * math.pi
			local point = at + Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
			part(m, {
				Name = "Band",
				Size = Vector3.new(segLength, band, band),
				CFrame = CFrame.new(point) * CFrame.Angles(0, 0, angle + math.pi / 2),
				Color = color,
				CastShadow = false,
			})
		end
	end
end

-- A floating island out past the walls: grass top over a rounded dirt cone,
-- with a few trees or lollipops on top.
local function island(parent: Instance, at: Vector3, diameter: number, candy: boolean)
	local m = model(parent, "Island")
	local grass = if candy then Color3.fromRGB(255, 175, 210) else Color3.fromRGB(120, 215, 75)
	disc(m, at, diameter, 4, grass)
	local layers: { { width: number, height: number, color: Color3 } } = {
		{ width = 0.92, height = 6, color = Color3.fromRGB(170, 115, 75) },
		{ width = 0.7, height = 8, color = Color3.fromRGB(150, 100, 65) },
		{ width = 0.45, height = 9, color = Color3.fromRGB(130, 88, 58) },
		{ width = 0.2, height = 8, color = Color3.fromRGB(115, 78, 52) },
	}
	local y = at.Y - 2
	for _, layer in layers do
		local height = layer.height * diameter / 60
		column(m, Vector3.new(at.X, y - height, at.Z), height, diameter * layer.width, layer.color)
		y -= height
	end
	local top = at + Vector3.new(0, 2, 0)
	local count = math.max(2, math.floor(diameter / 30))
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local spot = top + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0, diameter * 0.32)
		if candy then
			lollipop(m, spot, diameter / 25)
		else
			tree(m, spot, diameter / 22, pick({ LEAF, Color3.fromRGB(255, 160, 200), Color3.fromRGB(140, 220, 90) }))
		end
	end
	for _, item in m:GetDescendants() do
		if item:IsA("BasePart") then
			item.CastShadow = false
			item.CanCollide = false
			item.CanQuery = false
		end
	end
end

--------------------------------------------------------------------------------
-- Hub
--------------------------------------------------------------------------------

-- Places on the hub floor that must stay clear: plots, shops and their circles,
-- the spawn, and the open middle at the front where players launch.
local function hubSpotFree(x: number, z: number, plots: { CFrame }): boolean
	if math.abs(z) > Lane.hubHalfWidthAt(x) - 5 then
		return false -- outside the walls (the front corners are cut off)
	end
	for _, plot in plots do
		local offset = plot:PointToObjectSpace(Vector3.new(x, plot.Y, z))
		if math.abs(offset.X) < 30 and math.abs(offset.Z) < 22 then
			return false
		end
	end
	for _, shop in Shops.LIST do
		local zone = Shops.zoneCenter(shop)
		if (Vector2.new(x, z) - Vector2.new(shop.Position.X, shop.Position.Z)).Magnitude < 14
			or (Vector2.new(x, z) - Vector2.new(zone.X, zone.Z)).Magnitude < Shops.ZONE_RADIUS + 4
		then
			return false
		end
	end
	if x > -75 and math.abs(z) < 30 then
		return false -- the spawn and the open run up to the corridor
	end
	if (Vector2.new(x, z) - Vector2.new(-125, 0)).Magnitude < 34 then
		return false -- the plaza in the middle of the plots
	end
	return true
end

local function buildHubDecor(parent: Instance, plots: { CFrame })
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = parent

	local minX, maxX = Config.Hub.MinX, Config.Hub.MaxX
	-- Candy poles either side of the corridor's mouth and where it opens into the zones.
	for _, x in { Config.Hub.MaxX + 6, Config.Lane.StartX - 6 } do
		for _, side in { -1, 1 } do
			candyPole(decor, Vector3.new(x, 0, side * (Config.Lane.CorridorWidth / 2 - 4)), 1.2)
		end
	end
	local edge = Config.Hub.Width / 2

	-- Trees in the corners and along the side walls.
	for _, spot in { Vector2.new(-208, -98), Vector2.new(-208, 98), Vector2.new(-125, -100), Vector2.new(-125, 100), Vector2.new(-208, 0), Vector2.new(-80, -100), Vector2.new(-80, 100) } do
		if hubSpotFree(spot.X, spot.Y, plots) then
			tree(decor, Vector3.new(spot.X, 0, spot.Y), rng:NextNumber(1, 1.25))
		end
	end

	-- A hedge of bushes along the back wall, behind the plots.
	for z = -90, 90, 12 do
		if math.abs(z) > 10 then
			bush(decor, Vector3.new(minX + 5, 0, z + rng:NextNumber(-2, 2)), rng:NextNumber(0.9, 1.2))
		end
	end
	-- Bushes along the side walls.
	for x = minX + 20, Config.Hub.ChamferX - 6, 16 do
		for _, side in { -1, 1 } do
			local z = side * (edge - 5)
			if rng:NextNumber() < 0.7 then
				bush(decor, Vector3.new(x + rng:NextNumber(-3, 3), 0, z), rng:NextNumber(0.8, 1.1))
			end
		end
	end

	-- Little clusters of flowers.
	local clusters = 0
	local tries = 0
	while clusters < 18 and tries < 400 do
		tries += 1
		local x = rng:NextNumber(minX + 6, maxX - 6)
		local z = rng:NextNumber(-edge + 6, edge - 6)
		if hubSpotFree(x, z, plots) then
			clusters += 1
			local color = pick(FLOWER)
			for _ = 1, rng:NextInteger(3, 6) do
				local at = Vector3.new(x + rng:NextNumber(-2.5, 2.5), 0, z + rng:NextNumber(-2.5, 2.5))
				flower(decor, at, color)
			end
		end
	end

	-- Decor is just for looks: no bumping into flowers.
	for _, item in decor:GetDescendants() do
		if item:IsA("BasePart") and item.Size.Magnitude < 3 then
			item.CanCollide = false
		end
	end
end

--------------------------------------------------------------------------------
-- Lane
--------------------------------------------------------------------------------

-- Props sit in a band along the zigzag walls, this far in from the wall.
local EDGE_NEAR = 26
local EDGE_FAR = 7

-- A spot `inset` studs in from the wall on `side`, at X.
local function wallSpot(x: number, side: number, inset: number): Vector3
	return Vector3.new(x, 0.02, side * (Lane.halfWidthAt(x, side) - inset))
end

local function edgeSpot(startX: number): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local x = startX + rng:NextNumber(10, Config.Lane.ZoneLength - 10)
	if x < Config.Lane.StartX + 70 then
		x += 70 -- keep clear of the narrow flare where the corridor opens up
	end
	return wallSpot(x, side, rng:NextNumber(EDGE_FAR, EDGE_NEAR))
end

local function anySpot(startX: number): Vector3
	local x = startX + rng:NextNumber(5, Config.Lane.ZoneLength - 5)
	return Vector3.new(x, 0.02, rng:NextNumber(-Lane.halfWidthAt(x, -1) + 8, Lane.halfWidthAt(x, 1) - 8))
end

local function repeatAt(count: number, startX: number, build: (Vector3) -> ())
	for _ = 1, count do
		build(edgeSpot(startX))
	end
end

type Theme = (folder: Instance, startX: number, ground: Color3) -> ()

local THEMES: { [string]: Theme } = {
	-- Plain green land with a little river across it.
	Shore = function(folder, startX)
		local riverX = startX + Config.Lane.ZoneLength * 0.55
		local width = (Lane.MaxHalfWidth + 20) * 2
		part(folder, { Name = "Bank", Size = Vector3.new(18, 0.2, width), Position = Vector3.new(riverX, 0.04, 0), Color = Color3.fromRGB(240, 220, 160), CanCollide = false })
		local water = part(folder, { Name = "River", Size = Vector3.new(12, 0.2, width), Position = Vector3.new(riverX, 0.08, 0), Color = Color3.fromRGB(80, 190, 240), Material = Enum.Material.Glass, Transparency = 0.1, CanCollide = false })
		water:SetAttribute("Water", true)
		repeatAt(10, startX, function(at) bush(folder, at, rng:NextNumber(0.9, 1.3)) end)
		repeatAt(6, startX, function(at) rock(folder, at, rng:NextNumber(0.8, 1.4)) end)
		repeatAt(3, startX, function(at) tree(folder, at, rng:NextNumber(1, 1.3)) end)
	end,

	Meadow = function(folder, startX)
		repeatAt(10, startX, function(at) tree(folder, at, rng:NextNumber(1, 1.4)) end)
		repeatAt(12, startX, function(at) bush(folder, at, rng:NextNumber(0.9, 1.2)) end)
		for _ = 1, 70 do
			flower(folder, anySpot(startX))
		end
	end,

	Lagoon = function(folder, startX)
		for i = 1, 3 do
			local side = if i % 2 == 0 then 1 else -1
			pond(folder, wallSpot(startX + i * 70 - 20, side, 22), rng:NextNumber(18, 26))
		end
		repeatAt(10, startX, function(at) palm(folder, at, rng:NextNumber(1, 1.4)) end)
		repeatAt(5, startX, function(at) rock(folder, at, rng:NextNumber(0.8, 1.3), Color3.fromRGB(235, 215, 165)) end)
	end,

	Cloud = function(folder, startX)
		repeatAt(14, startX, function(at) cloudPuff(folder, at, rng:NextNumber(1, 1.6)) end)
		repeatAt(8, startX, function(at) cloudPuff(folder, at + Vector3.new(0, rng:NextNumber(20, 45), 0), rng:NextNumber(1.5, 2.5)) end)
		repeatAt(4, startX, function(at) lollipop(folder, at, rng:NextNumber(0.9, 1.3)) end)
	end,

	Rainbow = function(folder, startX)
		rainbowArch(folder, wallSpot(startX + 80, -1, 14), 22)
		rainbowArch(folder, wallSpot(startX + 180, 1, 14), 22)
		repeatAt(10, startX, function(at) lollipop(folder, at, rng:NextNumber(1, 1.5)) end)
		repeatAt(6, startX, function(at) candyPole(folder, at, rng:NextNumber(1, 1.4)) end)
	end,

	["Far edge"] = function(folder, startX)
		local colors = { Color3.fromRGB(180, 130, 255), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 140, 230) }
		repeatAt(14, startX, function(at) crystal(folder, at, rng:NextNumber(1, 1.6), pick(colors)) end)
		repeatAt(6, startX, function(at) rock(folder, at, rng:NextNumber(1, 1.5), Color3.fromRGB(120, 95, 170)) end)
	end,

	Starfall = function(folder, startX)
		repeatAt(18, startX, function(at) star(folder, at + Vector3.new(0, 1, 0), rng:NextNumber(0.6, 1)) end)
		repeatAt(12, startX, function(at) star(folder, at + Vector3.new(0, rng:NextNumber(15, 45), 0), rng:NextNumber(1.2, 2)) end)
		repeatAt(6, startX, function(at) crystal(folder, at, rng:NextNumber(1, 1.5), Color3.fromRGB(90, 110, 230)) end)
	end,

	["Moon Bay"] = function(folder, startX, ground)
		for _ = 1, 6 do
			crater(folder, edgeSpot(startX), rng:NextNumber(8, 16), ground)
		end
		for _ = 1, 5 do
			crater(folder, anySpot(startX), rng:NextNumber(6, 12), ground)
		end
		repeatAt(8, startX, function(at) rock(folder, at, rng:NextNumber(1, 1.8), Color3.fromRGB(175, 175, 190)) end)
	end,
}

local function buildLaneProps(lane: Instance)
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = lane
	for i, zone in Config.Zones do
		local folder = Instance.new("Folder")
		folder.Name = zone.Name
		folder.Parent = props
		local theme = THEMES[zone.Name]
		local startX = Lane.zoneStartX(i)
		if theme then
			theme(folder, startX, zone.Color)
		else
			repeatAt(10, startX, function(at) bush(folder, at, 1) end)
		end
	end
	-- Props never block a landing or trip a player.
	for _, item in props:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
		end
	end
end

--------------------------------------------------------------------------------
-- Out past the walls
--------------------------------------------------------------------------------

local function buildSkyline(map: Instance)
	-- Persistent so far-off pieces don't stream out and leave holes in the view.
	local skyline = Instance.new("Model")
	skyline.Name = "Skyline"
	skyline.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	skyline.Parent = map

	local laneEnd = Lane.EndX

	-- Floating islands on both sides, all the way down the lane and behind the hub.
	local islands: { { at: Vector3, size: number, candy: boolean } } = {
		{ at = Vector3.new(-330, 70, -40), size = 120, candy = true },
		{ at = Vector3.new(-260, 110, 260), size = 90, candy = false },
		{ at = Vector3.new(-150, 60, -280), size = 80, candy = true },
		{ at = Vector3.new(150, 85, 300), size = 110, candy = false },
		{ at = Vector3.new(420, 130, -340), size = 130, candy = true },
		{ at = Vector3.new(700, 70, 260), size = 90, candy = true },
		{ at = Vector3.new(950, 150, -300), size = 100, candy = false },
		{ at = Vector3.new(1250, 95, 340), size = 140, candy = true },
		{ at = Vector3.new(1500, 60, -260), size = 80, candy = true },
		{ at = Vector3.new(1750, 140, 300), size = 110, candy = false },
		{ at = Vector3.new(2050, 100, -340), size = 120, candy = true },
		{ at = Vector3.new(laneEnd + 220, 60, 220), size = 90, candy = false },
	}
	for _, spec in islands do
		island(skyline, spec.at, spec.size, spec.candy)
	end

	-- Giant lollipops and candy poles poking up over the walls.
	local giants = Instance.new("Folder")
	giants.Name = "GiantCandy"
	giants.Parent = skyline
	local edge = Config.Hub.Width / 2 + 18
	local laneEdge = Lane.MaxHalfWidth + 40
	for _, spec in { { -90, -edge }, { -170, edge }, { Config.Hub.MinX - 20, -40 }, { Config.Hub.MinX - 25, 55 }, { 350, -laneEdge }, { 650, laneEdge }, { 1100, -laneEdge }, { 1600, laneEdge } } do
		lollipop(giants, Vector3.new(spec[1], 0, spec[2]), rng:NextNumber(5, 7))
	end
	for _, spec in { { 40, edge }, { 60, -edge }, { 900, -laneEdge }, { 1400, laneEdge } } do
		candyPole(giants, Vector3.new(spec[1], 0, spec[2]), rng:NextNumber(5, 7))
	end
	for _, item in giants:GetDescendants() do
		if item:IsA("BasePart") then
			item.CastShadow = false
			item.CanCollide = false
			item.CanQuery = false
		end
	end

	-- A big moon past the end of the lane: the goal you can see from the hub.
	local moon = Instance.new("Model")
	moon.Name = "Moon"
	moon.Parent = skyline
	local center = Vector3.new(laneEnd + 450, 230, 0)
	local moonPart = ball(moon, center, 320, Color3.fromRGB(235, 236, 248))
	for _, spot in { Vector3.new(-0.9, 0.3, -0.2), Vector3.new(-0.85, -0.25, 0.4), Vector3.new(-0.7, 0.55, 0.45), Vector3.new(-0.95, -0.1, -0.3) } do
		local dir = spot.Unit
		disc(moon, center + dir * 157, rng:NextNumber(40, 70), 6, Color3.fromRGB(205, 206, 222)).CFrame = CFrame.lookAt(center + dir * 157, center + dir * 200) * CFrame.Angles(0, math.pi / 2, 0)
	end
	for _, item in moon:GetDescendants() do
		if item:IsA("BasePart") then
			item.CastShadow = false
			item.CanCollide = false
			item.CanQuery = false
		end
	end
	moonPart.Name = "MoonBall"
end

--------------------------------------------------------------------------------

function Scenery.build(map: Instance, plots: { CFrame })
	local hub = map:FindFirstChild("Hub")
	local lane = map:FindFirstChild("Lane")
	if hub then
		buildHubDecor(hub, plots)
	end
	if lane then
		buildLaneProps(lane)
	end
	buildSkyline(map)
end

return Scenery
