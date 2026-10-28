--!strict
-- The shop stands in the hub and the zone on the floor in front of each one.
-- Standing in a zone opens that shop (MenuController), and the server only
-- sells a shop's items to players standing in its zone. Shared so the map,
-- the client and the server agree on where the zones are.

local Shops = {}

export type Shop = {
	Kind: string, -- what it sells: "Slingshot", "Egg", "Luck" or "Rebirth"
	Title: string,
	Color: Color3,
	Position: Vector3, -- the counter, on the hub floor
}

local LIST: { Shop } = {
	{ Kind = "Slingshot", Title = "Slingshot Shop", Color = Color3.fromRGB(255, 120, 160), Position = Vector3.new(-55, 0, -45) },
	{ Kind = "Egg", Title = "Egg Shop", Color = Color3.fromRGB(255, 205, 80), Position = Vector3.new(-55, 0, 0) },
	{ Kind = "Luck", Title = "Luck Shop", Color = Color3.fromRGB(110, 210, 110), Position = Vector3.new(-55, 0, 45) },
	{ Kind = "Rebirth", Title = "Rebirth", Color = Color3.fromRGB(150, 110, 255), Position = Vector3.new(-100, 0, 62) },
}
Shops.LIST = LIST

Shops.ZONE_SIZE = 16 -- studs across; the zone is square
local ZONE_OFFSET = Vector3.new(11, 0, 0) -- in front of the counter, on the side facing the lane
local ZONE_HEIGHT = 10 -- counts as inside up to this high (jumping)

function Shops.get(kind: string): Shop?
	for _, shop in Shops.LIST do
		if shop.Kind == kind then
			return shop
		end
	end
	return nil
end

-- Centre of a shop's zone, on the floor.
function Shops.zoneCenter(shop: Shop): Vector3
	return shop.Position + ZONE_OFFSET
end

-- Whether a position is in this shop's zone. `margin` widens it (the server
-- allows a little extra for players who just stepped out).
function Shops.isInZone(shop: Shop, position: Vector3, margin: number?): boolean
	local offset = position - Shops.zoneCenter(shop)
	local half = Shops.ZONE_SIZE / 2 + (margin or 0)
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y >= -2 and offset.Y <= ZONE_HEIGHT
end

-- The shop whose zone this position is in, or nil.
function Shops.at(position: Vector3, margin: number?): Shop?
	for _, shop in Shops.LIST do
		if Shops.isInZone(shop, position, margin) then
			return shop
		end
	end
	return nil
end

return Shops
