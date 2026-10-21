--!strict
-- Prices and effects of upgrades and rebirth. Shared so the server charges the
-- same numbers the client shows on the stands.

local Config = require(script.Parent.Config)

local Economy = {}

-- The three hub stands, and the player data field each one levels up.
Economy.UPGRADE_FIELDS = {
	Slingshot = "SlingshotLevel",
	Egg = "EggLevel",
	Luck = "LuckLevel",
}

type UpgradeInfo = { Cost: number, Growth: number, MaxLevel: number? }

-- Price of the next level of a stand upgrade, or nil at max level.
function Economy.upgradeCost(kind: string, level: number): number?
	local info = (Config.Upgrades :: any)[kind] :: UpgradeInfo?
	if not info or (info.MaxLevel and level >= info.MaxLevel) then
		return nil
	end
	return math.floor(info.Cost * info.Growth ^ level)
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

-- Studs flown at Power = 1 for a slingshot level.
function Economy.launchPower(level: number): number
	return Config.Slingshot.BasePower * Config.Slingshot.LevelGrowth ^ level
end

-- Multiplier on the Rare-and-up drop rates from the Egg upgrade.
function Economy.eggBoost(level: number): number
	return 1 + Config.Upgrades.Egg.OddsPerLevel * level
end

-- Multiplier on mutation chances from the Luck upgrade.
function Economy.luckBoost(level: number): number
	return 1 + Config.Upgrades.Luck.LuckPerLevel * level
end

return Economy
