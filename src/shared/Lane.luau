--!strict
-- Lane geometry: which zone a launch distance lands in.

local Config = require(script.Parent.Config)

local Lane = {}

Lane.Length = Config.Lane.ZoneLength * #Config.Zones

-- Zone index (1 to 8) for a distance in studs from the start of the lane.
function Lane.zoneAt(distance: number): number
	local index = math.floor(distance / Config.Lane.ZoneLength) + 1
	return math.clamp(index, 1, #Config.Zones)
end

-- Whether a position is over the hub floor, where players can launch from.
function Lane.isInHub(position: Vector3): boolean
	return position.X >= Config.Hub.MinX
		and position.X <= Config.Hub.MaxX
		and math.abs(position.Z) <= Config.Hub.Width / 2
end

-- X position of the near edge of a zone.
function Lane.zoneStartX(index: number): number
	return Config.Lane.StartX + (index - 1) * Config.Lane.ZoneLength
end

return Lane
