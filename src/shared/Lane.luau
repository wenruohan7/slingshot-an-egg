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

-- X position of the near edge of a zone.
function Lane.zoneStartX(index: number): number
	return Config.Lane.StartX + (index - 1) * Config.Lane.ZoneLength
end

return Lane
