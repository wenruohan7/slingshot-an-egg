--!strict
-- Charge meter math, shared by the client (to draw the needle)
-- and the server (to decide the real result from hold time).

local Config = require(script.Parent.Config)

export type Stage = {
	Name: string,
	Min: number,
	Power: number,
	Color: Color3,
}

local Charge = {}

-- Meter value (0 to 1) after holding for `held` seconds.
-- The needle rises to the top, falls back down, and repeats.
function Charge.valueAt(held: number): number
	local phase = (math.max(held, 0) / Config.Charge.FillTime) % 2
	return if phase <= 1 then phase else 2 - phase
end

function Charge.stageFor(value: number): Stage
	for _, stage in Config.Charge.Stages do
		if value >= stage.Min then
			return stage
		end
	end
	return Config.Charge.Stages[#Config.Charge.Stages]
end

return Charge
