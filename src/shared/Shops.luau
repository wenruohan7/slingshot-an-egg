--!strict
-- The shop stands in the hub and the glowing circle on the floor in front of
-- each one. Standing in a circle opens that shop (MenuController), and the
-- server only sells a shop's items to players standing in its circle. Shared
-- so the map, the client and the server agree on where the circles are.

local Shops = {}

export type Shop = {
	Kind: string, -- what it sells: "Slingshot", "Egg" or "Rebirth"
	Title: string,
	Color: Color3,
	Position: Vector3, -- the counter, on the hub floor
	Facing: Vector3, -- the way the counter faces; the circle is on that side
}

-- The Slingshot and Egg shops stand against the two diagonal walls at the hub's
-- front corners (where it narrows into the corridor), facing in toward the middle.
-- Rebirth stands in front of the last plot, facing the lane.
local LIST: { Shop } = {
	{
		Kind = "Slingshot",
		Title = "Bow Shop",
		Color = Color3.fromRGB(255, 120, 160),
		Position = Vector3.new(-33.8, 0, -73.7),
		Facing = Vector3.new(-0.759, 0, 0.651).Unit,
	},
	{
		Kind = "Egg",
		Title = "Egg Shop",
		Color = Color3.fromRGB(255, 205, 80),
		Position = Vector3.new(-33.8, 0, 73.7),
		Facing = Vector3.new(-0.759, 0, -0.651).Unit,
	},
	{
		Kind = "Rebirth",
		Title = "Rebirth",
		Color = Color3.fromRGB(150, 110, 255),
		Position = Vector3.new(-100, 0, 62),
		Facing = Vector3.xAxis,
	},
}
Shops.LIST = LIST

Shops.ZONE_RADIUS = 8 -- studs
local ZONE_DISTANCE = 12 -- from the counter to the circle's centre
local ZONE_HEIGHT = 10 -- counts as inside up to this high (jumping)

function Shops.get(kind: string): Shop?
	for _, shop in LIST do
		if shop.Kind == kind then
			return shop
		end
	end
	return nil
end

-- Centre of a shop's circle, on the floor.
function Shops.zoneCenter(shop: Shop): Vector3
	return shop.Position + shop.Facing * ZONE_DISTANCE
end

-- Whether a position is in this shop's circle. `margin` widens it (the server
-- allows a little extra for players who just stepped out).
function Shops.isInZone(shop: Shop, position: Vector3, margin: number?): boolean
	local offset = position - Shops.zoneCenter(shop)
	local flat = Vector3.new(offset.X, 0, offset.Z)
	return flat.Magnitude <= Shops.ZONE_RADIUS + (margin or 0) and offset.Y >= -2 and offset.Y <= ZONE_HEIGHT
end

-- The shop whose circle this position is in, or nil.
function Shops.at(position: Vector3, margin: number?): Shop?
	for _, shop in LIST do
		if Shops.isInZone(shop, position, margin) then
			return shop
		end
	end
	return nil
end

return Shops
