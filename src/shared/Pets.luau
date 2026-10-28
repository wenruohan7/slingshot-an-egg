--!strict
-- The 56 pets (7 per zone, one for each rarity) and how much each one earns.
-- Names are placeholders until the pet style is decided.

local Config = require(script.Parent.Config)

export type PetDef = {
	Id: string,
	Name: string,
	Zone: number,
	Rarity: number,
}

-- An owned pet, as stored in player data.
export type Pet = {
	Id: string,
	Mutation: number?, -- index into Config.Mutations, nil for none
	Big: boolean?, -- made by combining three of the same pet
}

-- One row per zone, Common to Secret.
local NAMES: { { string } } = {
	{ "Puddle Frog", "River Otter", "Clover Bunny", "Mossy Turtle", "Golden Koi", "Willow Fox", "Old Shore Spirit" },
	{ "Bumble Bee", "Daisy Lamb", "Windmill Mouse", "Petal Fawn", "Sunflower Lion", "Meadow Unicorn", "Queen Bloom" },
	{ "Lily Duck", "Bubble Crab", "Splash Seal", "Coral Turtle", "Lagoon Dolphin", "Pearl Narwhal", "Deep Kraken" },
	{ "Puff Chick", "Cloud Sheep", "Balloon Pig", "Sky Owl", "Thunder Pup", "Cloud Dragon", "Storm King" },
	{ "Candy Snail", "Gumdrop Cat", "Lollipop Panda", "Sprinkle Bear", "Rainbow Pony", "Prism Phoenix", "Sugar Titan" },
	{ "Crystal Beetle", "Gem Hedgehog", "Shard Fox", "Glow Bat", "Amethyst Wolf", "Crystal Griffin", "Edge Guardian" },
	{ "Star Bug", "Comet Kitty", "Twinkle Owl", "Meteor Pup", "Nova Lion", "Starlight Stag", "Cosmo Whale" },
	{ "Moon Moth", "Crater Bunny", "Lunar Seal", "Moonbeam Fox", "Eclipse Panther", "Moon Dragon", "The Moon Keeper" },
}

local Pets = {}

Pets.All = {} :: { PetDef }
Pets.ById = {} :: { [string]: PetDef }

for zone, row in NAMES do
	for rarity, name in row do
		local def: PetDef = { Id = `z{zone}r{rarity}`, Name = name, Zone = zone, Rarity = rarity }
		table.insert(Pets.All, def)
		Pets.ById[def.Id] = def
	end
end

function Pets.idFor(zone: number, rarity: number): string
	return `z{zone}r{rarity}`
end

-- Coins per second this pet earns, before the rebirth multiplier.
function Pets.earnRate(pet: Pet): number
	local def = Pets.ById[pet.Id]
	if not def then
		return 0
	end
	local rate = Config.Rarities[def.Rarity].EarnRate * Config.Zones[def.Zone].EarnMultiplier
	if pet.Mutation then
		local mutation = Config.Mutations[pet.Mutation]
		rate *= if mutation then mutation.Multiplier else 1
	end
	if pet.Big then
		rate *= Config.Combine.BigMultiplier
	end
	return rate
end

-- Rare enough for the long hatch show and a light beam everyone can see.
function Pets.isNotable(pet: Pet): boolean
	local def = Pets.ById[pet.Id]
	if def and def.Rarity >= Config.Hatching.ShowBeamFromRarity then
		return true
	end
	return pet.Mutation ~= nil and pet.Mutation >= Config.Hatching.ShowBeamFromMutation
end

-- The colour that stands for this pet: its mutation's, or else its rarity's.
function Pets.color(pet: Pet): Color3
	local mutation = if pet.Mutation then Config.Mutations[pet.Mutation] else nil
	if mutation then
		return mutation.Color
	end
	local def = Pets.ById[pet.Id]
	return Config.Rarities[if def then def.Rarity else 1].Color
end

-- Display name, e.g. "Golden Big Bubble Crab".
function Pets.displayName(pet: Pet): string
	local def = Pets.ById[pet.Id]
	local name = if def then def.Name else "???"
	if pet.Big then
		name = "Big " .. name
	end
	if pet.Mutation and Config.Mutations[pet.Mutation] then
		name = Config.Mutations[pet.Mutation].Name .. " " .. name
	end
	return name
end

return Pets
