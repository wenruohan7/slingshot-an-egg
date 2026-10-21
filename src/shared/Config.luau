--!strict
-- All game tuning lives here. Numbers are starting points from the design doc;
-- change them freely while playtesting.

local Config = {}

-- Lane layout: the lane starts at X = 0 (right next to the hub) and runs toward +X.
Config.Lane = {
	StartX = 0,
	ZoneLength = 120, -- studs per zone
	Width = 200, -- studs, along Z
}

-- The 8 zones, nearest first. Drop rates are percentages per rarity and add up to 100.
-- Rarity order: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret
Config.Zones = {
	{ Name = "Shore", Color = Color3.fromRGB(140, 210, 120), DropRates = { 70, 22, 6, 1.5, 0.4, 0.09, 0.01 } },
	{ Name = "Meadow", Color = Color3.fromRGB(190, 230, 120), DropRates = { 40, 40, 14, 4.5, 1.2, 0.27, 0.03 } },
	{ Name = "Lagoon", Color = Color3.fromRGB(80, 200, 210), DropRates = { 20, 35, 33, 9, 2.4, 0.55, 0.05 } },
	{ Name = "Cloud", Color = Color3.fromRGB(235, 240, 255), DropRates = { 10, 25, 35, 24, 5, 0.9, 0.1 } },
	{ Name = "Rainbow", Color = Color3.fromRGB(255, 170, 210), DropRates = { 5, 15, 30, 33, 15, 1.8, 0.2 } },
	{ Name = "Far edge", Color = Color3.fromRGB(170, 140, 240), DropRates = { 2, 8, 20, 35, 28, 6.5, 0.5 } },
	{ Name = "Starfall", Color = Color3.fromRGB(60, 60, 120), DropRates = { 0, 4, 12, 30, 37, 15, 2 } },
	{ Name = "Moon Bay", Color = Color3.fromRGB(120, 120, 150), DropRates = { 0, 0, 6, 24, 40, 25, 5 } },
}

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(255, 255, 255), EarnRate = 1 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), EarnRate = 3 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), EarnRate = 10 },
	{ Name = "Epic", Color = Color3.fromRGB(170, 90, 255), EarnRate = 30 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 40), EarnRate = 100 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 110, 200), EarnRate = 400 },
	{ Name = "Secret", Color = Color3.fromRGB(20, 20, 20), EarnRate = 1500 },
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

-- Slingshot launch power, in studs flown at Power = 1.
-- Each slingshot upgrade level multiplies it by LevelGrowth.
Config.Slingshot = {
	BasePower = 150,
	LevelGrowth = 1.12,
	LaunchRange = 25, -- how close a player must stand to their pad to launch
}

return Config
