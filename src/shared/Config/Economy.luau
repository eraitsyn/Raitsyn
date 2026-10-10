-- Tunable numbers. All are starting defaults to adjust in play.

return {
	MaxCash = 2 ^ 53, -- largest whole number a double holds exactly
	SellPerIncome = 10, -- selling a pet pays this many seconds of its income
	MaxPets = 300, -- pet inventory size

	-- Rolling: seconds between rolls on one station.
	RollCooldown = 0.8,
	RollRevealDelay = 0.9, -- how long the client's roll animation runs

	-- Offline earnings: while away, equipped pets earn this share, for at most this long.
	OfflineRate = 0.5,
	OfflineCapSeconds = 8 * 60 * 60,

	-- Upgrades. Level 0 is the start; level n+1 costs baseCost * growth ^ n.
	-- start + perLevel * level is the value at a level (HatchSpeed and Luck are multipliers).
	Upgrades = {
		{
			id = "HatchSlots",
			name = "Hatch Slots",
			description = "Hatch more eggs at once",
			start = 2,
			perLevel = 1,
			maxLevel = 6,
			baseCost = 400,
			growth = 9,
		},
		{
			id = "EquipSlots",
			name = "Pet Platforms",
			description = "Equip more pets that earn money",
			start = 3,
			perLevel = 1,
			maxLevel = 9,
			baseCost = 250,
			growth = 7,
		},
		{
			id = "EggStorage",
			name = "Egg Storage",
			description = "Hold more eggs in your inventory",
			start = 10,
			perLevel = 5,
			maxLevel = 10,
			baseCost = 150,
			growth = 6,
		},
		{
			id = "HatchSpeed",
			name = "Hatch Speed",
			description = "Eggs hatch faster",
			start = 1,
			perLevel = -0.06,
			maxLevel = 10,
			baseCost = 800,
			growth = 7,
		},
		{
			id = "Luck",
			name = "Luck",
			description = "Rarer eggs and pets",
			start = 1,
			perLevel = 0.25,
			maxLevel = 20,
			baseCost = 500,
			growth = 4,
		},
		{
			id = "AutoCollect",
			name = "Auto Collect",
			description = "Income goes straight to your cash",
			start = 0,
			perLevel = 1,
			maxLevel = 1,
			baseCost = 250000,
			growth = 1,
		},
	},

	-- Prompts and range checks
	PromptDistance = 10, -- studs, ProximityPrompt.MaxActivationDistance
	ReachDistance = 16, -- studs, server backstop for every prompt
	StationDistance = 18, -- studs from a roll station to use its panel
}
