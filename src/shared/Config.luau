--!strict
-- All game tuning lives here. Numbers are starting points from the design doc;
-- change them freely while playtesting.

local Config = {}

-- Hub layout: the hub floor runs from MinX up to MaxX and is centred on Z = 0.
-- MaxX meets the start of the lane, so there is no gap to fall through.
-- Players launch from anywhere on the hub floor.
-- The front corners are cut off diagonally, narrowing into the corridor.
Config.Hub = {
	MinX = -220,
	MaxX = 0,
	Width = 220, -- studs, along Z
	ChamferX = -60, -- the side walls turn in diagonally from here to the corridor
}

-- Lane layout (Tmuk's sketch): a narrow walled corridor runs from the hub's front
-- (X = 0) to StartX, then opens into the wide zone area with jagged walls.
-- Zone 1 starts at StartX, and launch distance is measured from there.
Config.Lane = {
	StartX = 100,
	CorridorWidth = 80, -- studs, along Z
	ZoneLength = 250, -- studs per zone
	Width = 300, -- typical width of the zone area; the jagged walls wander +-30 around it
}

-- The 8 zones, nearest first. Drop rates are percentages per rarity and add up to 100.
-- EarnMultiplier makes pets from farther zones earn more than the same rarity nearby.
-- It grows 8x per zone, so income climbs exponentially the farther you can launch.
-- Rarity order: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret
Config.Zones = {
	{ Name = "Shore", EarnMultiplier = 1, Color = Color3.fromRGB(140, 210, 120), DropRates = { 70, 22, 6, 1.5, 0.4, 0.09, 0.01 } },
	{ Name = "Meadow", EarnMultiplier = 8, Color = Color3.fromRGB(190, 230, 120), DropRates = { 40, 40, 14, 4.5, 1.2, 0.27, 0.03 } },
	{ Name = "Lagoon", EarnMultiplier = 64, Color = Color3.fromRGB(80, 200, 210), DropRates = { 20, 35, 33, 9, 2.4, 0.55, 0.05 } },
	{ Name = "Cloud", EarnMultiplier = 512, Color = Color3.fromRGB(235, 240, 255), DropRates = { 10, 25, 35, 24, 5, 0.9, 0.1 } },
	{ Name = "Rainbow", EarnMultiplier = 4096, Color = Color3.fromRGB(255, 170, 210), DropRates = { 5, 15, 30, 33, 15, 1.8, 0.2 } },
	{ Name = "Far edge", EarnMultiplier = 32768, Color = Color3.fromRGB(170, 140, 240), DropRates = { 2, 8, 20, 35, 28, 6.5, 0.5 } },
	{ Name = "Starfall", EarnMultiplier = 262144, Color = Color3.fromRGB(60, 60, 120), DropRates = { 0, 4, 12, 30, 37, 15, 2 } },
	{ Name = "Moon Bay", EarnMultiplier = 2097152, Color = Color3.fromRGB(120, 120, 150), DropRates = { 0, 0, 6, 24, 40, 25, 5 } },
}

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(255, 255, 255), EarnRate = 1 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), EarnRate = 3 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), EarnRate = 10 },
	{ Name = "Epic", Color = Color3.fromRGB(170, 90, 255), EarnRate = 30 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 40), EarnRate = 100 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 110, 200), EarnRate = 400 },
	{ Name = "Secret", Color = Color3.fromRGB(255, 70, 70), EarnRate = 1500 },
}

-- Mutations roll separately after the rarity. Chance is a percentage; at most one
-- mutation applies, checked from the rarest down.
Config.Mutations = {
	{ Name = "Golden", Multiplier = 2, Chance = 5, Color = Color3.fromRGB(255, 205, 60) },
	{ Name = "Diamond", Multiplier = 3, Chance = 2.5, Color = Color3.fromRGB(150, 235, 255) },
	{ Name = "Rainbow", Multiplier = 5, Chance = 1, Color = Color3.fromRGB(255, 120, 220) },
	{ Name = "Blocky", Multiplier = 7, Chance = 0.5, Color = Color3.fromRGB(110, 200, 90) },
	{ Name = "Galaxy", Multiplier = 10, Chance = 0.2, Color = Color3.fromRGB(80, 40, 160) },
	{ Name = "Divine", Multiplier = 20, Chance = 0.05, Color = Color3.fromRGB(255, 250, 220) },
}

Config.Hatching = {
	-- Landing this close before the next zone's line gives a chance at that zone's drop rates.
	NearLineDistance = 15,
	NearLineChance = 0.25,
	ShowBeamFromRarity = 4, -- Epic and up get a light beam everyone can see
	ShowBeamFromMutation = 3, -- and so do Rainbow, Blocky, Galaxy and Divine pets
	RevealSeconds = 3.5, -- how long a normal hatch keeps the egg on the lane
	BigRevealSeconds = 5.5, -- the longer show for pets that get a light beam
	BuildSeconds = 2.6, -- glow-and-spin build before a beam pet cracks out
}

-- Three copies of the same pet (and mutation) merge into one Big pet.
Config.Combine = {
	Count = 3,
	BigMultiplier = 4,
}

-- Pedestals on each plot. The best pets fill them automatically.
Config.Plot = {
	StartPedestals = 3,
	MaxPedestals = 12,
	MaxPets = 200, -- inventory size
}

-- Slingshots, bought one after another in the Shop. Each one is a new item in
-- your hand. Power multiplies Slingshot.BasePower. Frame, Accent, Band and
-- Material colour the built-in model; a real model with the same Name in
-- ReplicatedStorage.SlingshotModels replaces it (see the README).
Config.Slingshots = {
	{ Name = "Wooden Slingshot", Power = 1, Cost = 0, Frame = Color3.fromRGB(176, 122, 78), Accent = Color3.fromRGB(255, 120, 160), Band = Color3.fromRGB(235, 60, 110), Material = Enum.Material.Wood },
	{ Name = "Sturdy Slingshot", Power = 1.16, Cost = 100, Frame = Color3.fromRGB(120, 80, 50), Accent = Color3.fromRGB(240, 240, 240), Band = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Wood },
	{ Name = "Leafy Slingshot", Power = 1.35, Cost = 600, Frame = Color3.fromRGB(100, 160, 70), Accent = Color3.fromRGB(255, 220, 90), Band = Color3.fromRGB(80, 200, 90), Material = Enum.Material.SmoothPlastic },
	{ Name = "Iron Slingshot", Power = 1.57, Cost = 3000, Frame = Color3.fromRGB(150, 155, 165), Accent = Color3.fromRGB(70, 75, 85), Band = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal },
	{ Name = "Candy Slingshot", Power = 1.82, Cost = 15000, Frame = Color3.fromRGB(255, 150, 200), Accent = Color3.fromRGB(255, 255, 255), Band = Color3.fromRGB(120, 210, 255), Material = Enum.Material.SmoothPlastic },
	{ Name = "Golden Slingshot", Power = 2.1, Cost = 80000, Frame = Color3.fromRGB(255, 200, 60), Accent = Color3.fromRGB(255, 240, 160), Band = Color3.fromRGB(200, 40, 40), Material = Enum.Material.Foil },
	{ Name = "Ice Slingshot", Power = 2.45, Cost = 400000, Frame = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(255, 255, 255), Band = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Ice },
	{ Name = "Lava Slingshot", Power = 2.85, Cost = 2500000, Frame = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 110, 30), Band = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Basalt },
	{ Name = "Crystal Slingshot", Power = 3.3, Cost = 15000000, Frame = Color3.fromRGB(190, 140, 255), Accent = Color3.fromRGB(255, 255, 255), Band = Color3.fromRGB(150, 90, 255), Material = Enum.Material.Glass },
	{ Name = "Rainbow Slingshot", Power = 3.85, Cost = 100000000, Frame = Color3.fromRGB(255, 120, 200), Accent = Color3.fromRGB(120, 230, 255), Band = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Neon },
	{ Name = "Galaxy Slingshot", Power = 4.5, Cost = 800000000, Frame = Color3.fromRGB(60, 30, 120), Accent = Color3.fromRGB(150, 220, 255), Band = Color3.fromRGB(255, 120, 255), Material = Enum.Material.Neon },
	{ Name = "Moon Slingshot", Power = 5.3, Cost = 6000000000, Frame = Color3.fromRGB(230, 230, 245), Accent = Color3.fromRGB(255, 230, 120), Band = Color3.fromRGB(140, 160, 255), Material = Enum.Material.Marble },
}

-- Eggs, bought one after another in the Shop. Each one changes the egg you
-- launch. Luck makes rarer pets more likely: Secret pets get the full Luck,
-- each rarity below a smaller share of it, and Common none (HatchService). A real model (a
-- MeshPart) with the same Name in ReplicatedStorage.EggModels replaces the
-- built-in look.
Config.Eggs = {
	{ Name = "Plain Egg", Luck = 1, Cost = 0, Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.SmoothPlastic },
	{ Name = "Mint Egg", Luck = 3, Cost = 500, Color = Color3.fromRGB(170, 240, 200), Material = Enum.Material.SmoothPlastic },
	{ Name = "Sky Egg", Luck = 10, Cost = 5000, Color = Color3.fromRGB(140, 200, 255), Material = Enum.Material.SmoothPlastic },
	{ Name = "Golden Egg", Luck = 30, Cost = 50000, Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Foil },
	{ Name = "Crystal Egg", Luck = 100, Cost = 750000, Color = Color3.fromRGB(200, 160, 255), Material = Enum.Material.Glass },
	{ Name = "Rainbow Egg", Luck = 250, Cost = 12000000, Color = Color3.fromRGB(255, 130, 210), Material = Enum.Material.Neon },
	{ Name = "Galaxy Egg", Luck = 500, Cost = 250000000, Color = Color3.fromRGB(90, 50, 180), Material = Enum.Material.Neon },
	{ Name = "Divine Egg", Luck = 1000, Cost = 5000000000, Color = Color3.fromRGB(255, 245, 200), Material = Enum.Material.Neon },
}

-- Pedestals: price is Cost * Growth ^ (pedestals bought so far).
Config.Upgrades = {
	Pedestal = { Cost = 150, Growth = 5 }, -- price of the next pedestal past the starting ones
}

-- Rebirth multiplies coins by CoinMultiplier ^ rebirths (2.5x, 6.25x, 15.6x...), and
-- its price grows a little faster (Cost * Growth ^ rebirths), so each rebirth takes
-- a bit longer than the last. Around rebirth 27 prices reach septillions (Sp).
Config.Rebirth = {
	Cost = 5e9,
	Growth = 3.5,
	CoinMultiplier = 2.5,
	-- Rebirth resets coins, slingshots and eggs, and keeps pets.
	-- Bought pedestals are kept too, so a rebirth never lowers income; set this to
	-- false to reset them to StartPedestals as well.
	KeepPedestals = true,
}

Config.Offline = {
	MaxHours = 2, -- offline earnings stop after this long
	Rate = 0.5, -- share of normal income earned while offline
}

-- Charge meter. The needle bounces up and down while the button is held;
-- releasing it decides the stage. Stages are checked from the top down,
-- and Min is the lowest meter value (0 to 1) that counts for that stage.
Config.Charge = {
	FillTime = 1.0, -- seconds for the needle to go from bottom to top
	Stages = {
		{ Name = "Perfect", Min = 0.88, Power = 1.08, Color = Color3.fromRGB(255, 215, 60) },
		{ Name = "Amazing", Min = 0.78, Power = 0.97, Color = Color3.fromRGB(255, 120, 200) },
		{ Name = "Great", Min = 0.64, Power = 0.9, Color = Color3.fromRGB(150, 110, 255) },
		{ Name = "Normal", Min = 0.46, Power = 0.8, Color = Color3.fromRGB(80, 170, 255) },
		{ Name = "Not bad", Min = 0.26, Power = 0.65, Color = Color3.fromRGB(110, 210, 110) },
		{ Name = "Poor", Min = 0, Power = 0.5, Color = Color3.fromRGB(190, 190, 190) },
	},
}

-- Slingshot launch power, in studs flown at Power = 1, before the slingshot's own Power.
Config.Slingshot = {
	BasePower = 320, -- first slingshot: Poor and Not bad land in Shore, Normal and up in Meadow, all clear of the zone line

	-- Your own animations from Studio's Animation Editor, as "rbxassetid://123". Left empty, the
	-- arms are posed from code instead. Charge plays while the button is held (make it Looping),
	-- Launch plays once on release. Publish them from the account (or group) that owns the game.
	ChargeAnimationId = "",
	LaunchAnimationId = "",
}

-- The Robux shop (the Shop button). Create each item on the Creator Dashboard
-- (your experience > Monetization > Passes or Developer Products) and paste its
-- id here. Items with Id = 0 show as "Coming soon". Price is only the label;
-- Roblox charges what the Dashboard says, so keep them the same.
-- Effect is what the game does with it (see MonetizationService).
Config.RobuxShop = {
	Passes = {
		{ Key = "Luck2x", Name = "2x Luck", Text = "Double the Luck of every egg, forever", Icon = "🍀", Price = 249, Id = 0 },
		{ Key = "VIP", Name = "VIP", Text = "1.5x coins, forever", Icon = "👑", Price = 399, Id = 0 },
		{ Key = "AutoLaunch", Name = "Auto-Launch", Text = "Launches for you (coming in a later update)", Icon = "🔁", Price = 199, Id = 0 },
		{ Key = "ExtraPedestals", Name = "Extra Pedestals", Text = "+4 pet slots (coming in a later update)", Icon = "🏛️", Price = 149, Id = 0 },
	},
	Products = {
		-- Coin packs give this many seconds of your current income at once.
		{ Key = "CoinsSmall", Name = "Bag of Coins", Text = "30 minutes of coins", Icon = "💰", Price = 25, Id = 0, IncomeSeconds = 1800 },
		{ Key = "CoinsBig", Name = "Chest of Coins", Text = "6 hours of coins", Icon = "💎", Price = 199, Id = 0, IncomeSeconds = 21600 },
	},
	VipCoinMultiplier = 1.5,
	LuckPassMultiplier = 2,
}

return Config
