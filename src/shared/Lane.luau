--!strict
-- Lane geometry: which zone a launch distance lands in, and where the walls are.
--
-- Layout, looking down the lane (+X): the hub, whose front corners narrow in to
-- the lane, then one straight lane of Config.Lane.Width: a walkway up to
-- Config.Lane.StartX, then the zones.

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
	return half + (Config.Lane.Width / 2 - half) * t
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

-- The lane's walls are straight, so its half width is the same everywhere.
-- (Kept as functions so the walls could bend later without touching callers.)
Lane.MaxHalfWidth = Config.Lane.Width / 2

-- Wall corners for each side (-1 = -Z side, 1 = +Z side), as Vector2(x, distance
-- from the middle line), from the start of the zones to the lane's end.
Lane.Edges = {
	[-1] = { Vector2.new(Config.Lane.StartX, Config.Lane.Width / 2), Vector2.new(Lane.EndX, Config.Lane.Width / 2) },
	[1] = { Vector2.new(Config.Lane.StartX, Config.Lane.Width / 2), Vector2.new(Lane.EndX, Config.Lane.Width / 2) },
} :: { [number]: { Vector2 } }

-- How far the wall on `side` (-1 or 1) is from the middle line at an X position.
function Lane.halfWidthAt(_x: number, _side: number): number
	return Config.Lane.Width / 2
end

return Lane
