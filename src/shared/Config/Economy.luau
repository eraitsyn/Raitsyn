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

	-- Prompts
	PromptDistance = 10, -- studs, ProximityPrompt.MaxActivationDistance
	ReachDistance = 14, -- studs, server backstop for every prompt
}
