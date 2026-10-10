-- Tunable numbers. All are starting defaults to adjust in play.

return {
	MaxCash = 2 ^ 53, -- largest whole number a double holds exactly
	PedestalCount = 8,
	IncubatorCount = 4,
	SellPerIncome = 10, -- selling a pet pays this many seconds of its income

	-- Luck upgrades: luck = 1 + LuckPerLevel * level; level n+1 costs LuckBaseCost * LuckCostGrowth ^ n.
	LuckPerLevel = 0.25,
	LuckBaseCost = 200,
	LuckCostGrowth = 2.5,
	MaxLuckLevel = 20,

	-- Spinning: seconds between spins, and how long the spin animation runs before the egg appears.
	SpinCooldown = 2,
	SpinRevealDelay = 1.6,

	-- Offline earnings: while away, pets earn this share of their income, for at most this long.
	OfflineRate = 0.5,
	OfflineCapSeconds = 8 * 60 * 60,

	-- Prompts
	PromptDistance = 10, -- studs, ProximityPrompt.MaxActivationDistance
	ReachDistance = 14, -- studs, server backstop for every prompt
}
