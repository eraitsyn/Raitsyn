--!strict
-- Seven-day login streak. Coin rewards scale with the player's current income
-- (minutes of income), with a floor so brand-new players still get something.
-- A claim is allowed once `claimCooldownHours` have passed since the last one;
-- missing more than `streakResetHours` restarts the streak at day 1.

export type Reward = {
	day: number,
	incomeMinutes: number?,
	minimumCoins: number?,
	egg: string?,
}

local rewards: { Reward } = {
	{ day = 1, incomeMinutes = 5, minimumCoins = 500 },
	{ day = 2, incomeMinutes = 10, minimumCoins = 1_000 },
	{ day = 3, egg = "Rare" },
	{ day = 4, incomeMinutes = 15, minimumCoins = 2_500 },
	{ day = 5, incomeMinutes = 20, minimumCoins = 5_000 },
	{ day = 6, incomeMinutes = 30, minimumCoins = 10_000 },
	{ day = 7, egg = "Epic", incomeMinutes = 30, minimumCoins = 10_000 },
}

return table.freeze({
	rewards = table.freeze(rewards),
	claimCooldownHours = 20,
	streakResetHours = 48,
})
