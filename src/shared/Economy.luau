--!strict
-- Prices and effects of upgrades and rebirth. Shared so the server charges the
-- same numbers the client shows in the Shop.
-- SlingshotLevel and EggLevel count from 0: level 0 is the first slingshot or egg.

local Config = require(script.Parent.Config)

local Economy = {}

-- The things the Shop sells, and the player data field each one levels up.
Economy.UPGRADE_FIELDS = {
	Slingshot = "SlingshotLevel",
	Egg = "EggLevel",
	Luck = "LuckLevel",
}

type UpgradeInfo = { Cost: number, Growth: number, MaxLevel: number? }

-- The slingshot or egg for a level, kept in range.
function Economy.slingshot(level: number)
	return Config.Slingshots[math.clamp(level + 1, 1, #Config.Slingshots)]
end
function Economy.egg(level: number)
	return Config.Eggs[math.clamp(level + 1, 1, #Config.Eggs)]
end

-- Price of the next slingshot, egg or Luck level, or nil when there's nothing left to buy.
function Economy.upgradeCost(kind: string, level: number): number?
	if kind == "Slingshot" then
		local nextOne = Config.Slingshots[level + 2]
		return if nextOne then nextOne.Cost else nil
	elseif kind == "Egg" then
		local nextOne = Config.Eggs[level + 2]
		return if nextOne then nextOne.Cost else nil
	end
	local info = (Config.Upgrades :: any)[kind] :: UpgradeInfo?
	if not info or (info.MaxLevel and level >= info.MaxLevel) then
		return nil
	end
	return math.floor(info.Cost * info.Growth ^ level)
end

-- How many levels an upgrade has in all (slingshots and eggs: how many there are).
function Economy.maxLevel(kind: string): number
	if kind == "Slingshot" then
		return #Config.Slingshots - 1
	elseif kind == "Egg" then
		return #Config.Eggs - 1
	end
	return (Config.Upgrades :: any)[kind].MaxLevel
end

-- Price of the next pedestal, or nil when the plot is full.
function Economy.pedestalCost(owned: number): number?
	if owned >= Config.Plot.MaxPedestals then
		return nil
	end
	local info = Config.Upgrades.Pedestal
	return math.floor(info.Cost * info.Growth ^ math.max(owned - Config.Plot.StartPedestals, 0))
end

function Economy.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.Cost * Config.Rebirth.Growth ^ rebirths)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.CoinBonus * rebirths
end

-- Studs flown at Power = 1 with the slingshot at this level.
function Economy.launchPower(level: number): number
	return Config.Slingshot.BasePower * Economy.slingshot(level).Power
end

-- Multiplier on the Rare-and-up drop rates from the Egg upgrade.
function Economy.eggBoost(level: number): number
	return Economy.egg(level).Odds
end

-- Multiplier on mutation chances from the Luck upgrade.
function Economy.luckBoost(level: number): number
	return 1 + Config.Upgrades.Luck.LuckPerLevel * level
end

return Economy
