--!strict
-- Base numbers that the hex tree, rebirths and other systems modify.
-- Everything a designer may want to rebalance lives here or in the other
-- Config modules; game code never hard-codes these values.

return table.freeze({
	startingCoins = 150,
	starterEgg = "Common", -- one free egg on first join, used by the tutorial

	-- Rolling
	rollCooldown = 2.5, -- seconds
	rollCooldownFloor = 1.0,
	maxEggDiscount = 0.30,
	luckyRollEvery = 10, -- every Nth roll gets the Lucky Tenth multiplier (once unlocked)

	-- Farm and storage
	basePadSlots = 3,
	maxPadSlots = 24,
	padsPerSection = 6,
	basePetCapacity = 50,
	baseEggCapacity = 25,
	maxFollowers = 3,
	baseIncubators = 1,

	-- Income
	critMultiplier = 3, -- payout of a critical tick before Critical Income II
	maxCritChance = 0.10,

	-- Offline earnings (rate is 0 until the Offline Earnings tiles are bought)
	offlineBaseCapHours = 2,

	-- Rebirth
	rebirth = table.freeze({
		baseCost = 10_000_000,
		costGrowth = 3,
		incomePerRebirth = 0.5, -- additive: rebirth 2 => x2.0 income
		luckPerRebirth = 0.1, -- additive: rebirth 2 => x1.2 luck
	}),
})
