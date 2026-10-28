--!strict
-- Decides what hatches from an egg: the zone's drop rates (with the egg's Luck
-- boosting the rarer columns), the near-the-line bonus, and a mutation roll.
-- Adds the pet to the player's data and merges three of a kind into a Big pet.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Lane = require(Shared.Lane)
local Pets = require(Shared.Pets)
local DataService = require(script.Parent.DataService)

local HatchService = {}

local random = Random.new()

-- Picks an index from a list of weights.
local function pickWeighted(weights: { number }): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = random:NextNumber() * total
	for i, w in weights do
		roll -= w
		if roll < 0 then
			return i
		end
	end
	return #weights
end

-- Which zone's drop table to use for a landing distance. Landing just short
-- of the next zone's line sometimes counts as that zone.
function HatchService.dropZone(distance: number): number
	local zone = Lane.zoneAt(distance)
	if zone < #Config.Zones then
		local toNextLine = Lane.zoneStartX(zone + 1) - (Config.Lane.StartX + distance)
		if toNextLine <= Config.Hatching.NearLineDistance and random:NextNumber() < Config.Hatching.NearLineChance then
			return zone + 1
		end
	end
	return zone
end

-- Luck scales each rarity's chance by Luck ^ (how rare it is, 0 to 1): Common
-- stays the same, Secret gets the full Luck. With 1000x Luck, Rare pets are 10x
-- as likely, Legendary 100x and Secret 1000x (before the shares are rebalanced).
function HatchService.rollRarity(zone: number, luck: number): number
	local rates = Config.Zones[zone].DropRates
	local weights = {}
	for i, rate in rates do
		weights[i] = rate * luck ^ ((i - 1) / (#rates - 1))
	end
	return pickWeighted(weights)
end

function HatchService.rollMutation(): number?
	for i = #Config.Mutations, 1, -1 do
		if random:NextNumber() * 100 < Config.Mutations[i].Chance then
			return i
		end
	end
	return nil
end

local function samePet(a: Pets.Pet, b: Pets.Pet): boolean
	return a.Id == b.Id and a.Mutation == b.Mutation and not a.Big and not b.Big
end

-- Merges three matching normal pets into one Big pet. Returns the Big pet, if made.
local function combine(data: DataService.Data, pet: Pets.Pet): Pets.Pet?
	local matches = {}
	for i, owned in data.Pets do
		if samePet(owned, pet) then
			table.insert(matches, i)
		end
	end
	if #matches < Config.Combine.Count then
		return nil
	end
	for n = Config.Combine.Count, 1, -1 do
		table.remove(data.Pets, matches[n])
	end
	local big: Pets.Pet = { Id = pet.Id, Mutation = pet.Mutation, Big = true }
	table.insert(data.Pets, big)
	return big
end

-- Hatches an egg that landed `distance` studs down the lane.
-- Returns the new pet, whether it was merged into a Big pet, whether it was
-- kept (a full inventory only keeps pets better than the weakest one), and
-- whether it's the first of its kind for the player's Index.
function HatchService.hatch(player: Player, distance: number): (Pets.Pet?, boolean, boolean, boolean)
	local data = DataService.get(player)
	if not data then
		return nil, false, false, false
	end

	local zone = HatchService.dropZone(distance)
	local luckPass = if player:GetAttribute("Pass_Luck2x") == true then Config.RobuxShop.LuckPassMultiplier else 1
	local luck = Economy.eggLuck(data.EggLevel) * luckPass
	local rarity = HatchService.rollRarity(zone, luck)
	local pet: Pets.Pet = { Id = Pets.idFor(zone, rarity), Mutation = HatchService.rollMutation() }
	local isNew = not data.Discovered[pet.Id]
	data.Discovered[pet.Id] = true

	if #data.Pets >= Config.Plot.MaxPets then
		-- Inventory full: swap out the weakest pet if the new one is better.
		local weakest, weakestRate = 1, math.huge
		for i, owned in data.Pets do
			local rate = Pets.earnRate(owned)
			if rate < weakestRate then
				weakest, weakestRate = i, rate
			end
		end
		if Pets.earnRate(pet) <= weakestRate then
			return pet, false, false, isNew
		end
		table.remove(data.Pets, weakest)
	end

	table.insert(data.Pets, pet)
	local big = combine(data, pet)
	return big or pet, big ~= nil, true, isNew
end

return HatchService
