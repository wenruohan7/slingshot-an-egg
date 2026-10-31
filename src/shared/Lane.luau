--!strict
-- Lane geometry: which zone a launch distance lands in, and where the walls are.
--
-- Layout, looking down the lane (+X): the hub, then a narrow corridor from X = 0
-- to Config.Lane.StartX, then the wide zone area whose side walls zigzag.
-- The zigzag uses a fixed seed, so the server and every client agree on it.

local Config = require(script.Parent.Config)

local Lane = {}

Lane.Length = Config.Lane.ZoneLength * #Config.Zones
Lane.EndX = Config.Lane.StartX + Lane.Length

-- Zone index (1 to 8) for a distance in studs from the start of the lane.
function Lane.zoneAt(distance: number): number
	local index = math.floor(distance / Config.Lane.ZoneLength) + 1
	return math.clamp(index, 1, #Config.Zones)
end

-- Half the hub's width at an X position, taking the cut-off front corners into account.
function Lane.hubHalfWidthAt(x: number): number
	local half = Config.Hub.Width / 2
	local chamfer = Config.Hub.ChamferX
	if x <= chamfer then
		return half
	end
	local t = math.clamp((x - chamfer) / (Config.Hub.MaxX - chamfer), 0, 1)
	return half + (Config.Lane.CorridorWidth / 2 - half) * t
end

-- Whether a position is over the hub floor, where players can launch from.
function Lane.isInHub(position: Vector3): boolean
	return position.X >= Config.Hub.MinX
		and position.X <= Config.Hub.MaxX
		and math.abs(position.Z) <= Lane.hubHalfWidthAt(position.X)
end

-- X position of the near edge of a zone.
function Lane.zoneStartX(index: number): number
	return Config.Lane.StartX + (index - 1) * Config.Lane.ZoneLength
end

-- The zigzag wall corners for each side (-1 = -Z side, 1 = +Z side), as
-- Vector2(x, distance from the middle line), from the corridor's end to the lane's end.
local EDGE_JITTER = 30
local edges: { [number]: { Vector2 } } = {}
do
	local rng = Random.new(1031)
	for _, side in { -1, 1 } do
		local points = { Vector2.new(Config.Lane.StartX, Config.Lane.CorridorWidth / 2) }
		local x = Config.Lane.StartX + 70 -- the first run flares out diagonally from the corridor
		while x < Lane.EndX - 60 do
			table.insert(points, Vector2.new(x, Config.Lane.Width / 2 + rng:NextNumber(-EDGE_JITTER, EDGE_JITTER)))
			x += rng:NextNumber(90, 170)
		end
		table.insert(points, Vector2.new(Lane.EndX, Config.Lane.Width / 2 + rng:NextNumber(-EDGE_JITTER, EDGE_JITTER)))
		edges[side] = points
	end
end
Lane.Edges = edges

-- The widest the zone area ever gets from the middle line, for sizing the ground.
Lane.MaxHalfWidth = Config.Lane.Width / 2 + EDGE_JITTER

-- How far the wall on `side` (-1 or 1) is from the middle line at an X position.
function Lane.halfWidthAt(x: number, side: number): number
	if x <= Config.Lane.StartX then
		return Config.Lane.CorridorWidth / 2
	end
	local points = edges[if side < 0 then -1 else 1]
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if x <= b.X then
			return a.Y + (b.Y - a.Y) * (x - a.X) / (b.X - a.X)
		end
	end
	return points[#points].Y
end

return Lane
