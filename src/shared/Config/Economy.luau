-- Tunable numbers. All are starting defaults to adjust in play.

return {
	MaxCash = 2 ^ 53, -- largest whole number a double holds exactly
	PromptDistance = 10, -- studs, ProximityPrompt.MaxActivationDistance
	PurchaseDistance = 12, -- studs, server backstop for prompt purchases
	MaxDropsPerPlot = 60,
	DropLifetime = 20, -- seconds before an uncollected drop is removed
	RebirthCost = 10000,
	RebirthBonus = 0.25, -- income multiplier added per rebirth
}
