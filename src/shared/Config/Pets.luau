--[[
	Pets, eggs and rarity odds.

	Each egg lists the pets it can hatch with a weight. A pet's chance is its
	weight divided by the egg's total weight; luck multiplies the weight of
	every pet whose rarity is in LuckyRarities (see Rolls.EggChances).

	price      whole number of cash to buy the egg
	hatchTime  seconds the egg sits in an incubator before it can hatch
	income     cash per second a pet earns on a pedestal
	color      RGB 0-255; plain numbers keep this file free of Roblox types

	Pet and egg ids are saved in player data. Renaming one removes it from
	existing saves, so add new ids instead.
]]

return {
	Rarities = {
		{ name = "Common", color = { 200, 200, 200 } },
		{ name = "Uncommon", color = { 90, 200, 90 } },
		{ name = "Rare", color = { 70, 140, 255 } },
		{ name = "Epic", color = { 170, 80, 255 } },
		{ name = "Legendary", color = { 255, 170, 40 } },
		{ name = "Mythical", color = { 255, 60, 90 } },
		{ name = "Secret", color = { 30, 30, 30 } },
	},

	-- Luck boosts only these, so it makes rare pets likelier without touching commons.
	LuckyRarities = { Rare = true, Epic = true, Legendary = true, Mythical = true, Secret = true },

	Pets = {
		Puppy = { name = "Puppy", rarity = "Common", income = 2, color = { 200, 160, 110 } },
		Kitty = { name = "Kitty", rarity = "Common", income = 3, color = { 250, 180, 90 } },
		Bunny = { name = "Bunny", rarity = "Uncommon", income = 6, color = { 245, 245, 245 } },
		Fox = { name = "Fox", rarity = "Rare", income = 15, color = { 230, 110, 40 } },
		Panda = { name = "Panda", rarity = "Epic", income = 40, color = { 30, 30, 30 } },
		Unicorn = { name = "Unicorn", rarity = "Legendary", income = 120, color = { 250, 200, 240 } },

		Lion = { name = "Lion", rarity = "Uncommon", income = 60, color = { 220, 170, 70 } },
		Tiger = { name = "Tiger", rarity = "Rare", income = 120, color = { 240, 140, 30 } },
		Wolf = { name = "Wolf", rarity = "Rare", income = 150, color = { 130, 130, 145 } },
		Phoenix = { name = "Phoenix", rarity = "Epic", income = 400, color = { 255, 90, 30 } },
		Griffin = { name = "Griffin", rarity = "Legendary", income = 1200, color = { 180, 140, 80 } },
		Pegasus = { name = "Pegasus", rarity = "Mythical", income = 4000, color = { 200, 230, 255 } },

		StarCat = { name = "Star Cat", rarity = "Epic", income = 3000, color = { 255, 230, 120 } },
		CometFox = { name = "Comet Fox", rarity = "Legendary", income = 8000, color = { 120, 200, 255 } },
		NebulaDragon = { name = "Nebula Dragon", rarity = "Mythical", income = 25000, color = { 160, 80, 220 } },
		GalaxyWhale = { name = "Galaxy Whale", rarity = "Secret", income = 100000, color = { 40, 30, 90 } },
	},

	-- Shop order is the order of this list.
	Eggs = {
		{
			id = "Basic",
			name = "Basic Egg",
			price = 50,
			hatchTime = 10,
			color = { 240, 235, 220 },
			pets = {
				{ id = "Puppy", weight = 40 },
				{ id = "Kitty", weight = 35 },
				{ id = "Bunny", weight = 15 },
				{ id = "Fox", weight = 7 },
				{ id = "Panda", weight = 2.5 },
				{ id = "Unicorn", weight = 0.5 },
			},
		},
		{
			id = "Golden",
			name = "Golden Egg",
			price = 2500,
			hatchTime = 60,
			color = { 255, 200, 50 },
			pets = {
				{ id = "Lion", weight = 45 },
				{ id = "Tiger", weight = 25 },
				{ id = "Wolf", weight = 18 },
				{ id = "Phoenix", weight = 9 },
				{ id = "Griffin", weight = 2.5 },
				{ id = "Pegasus", weight = 0.5 },
			},
		},
		{
			id = "Cosmic",
			name = "Cosmic Egg",
			price = 100000,
			hatchTime = 300,
			color = { 90, 60, 200 },
			pets = {
				{ id = "StarCat", weight = 70 },
				{ id = "CometFox", weight = 25 },
				{ id = "NebulaDragon", weight = 4.9 },
				{ id = "GalaxyWhale", weight = 0.1 },
			},
		},
	},
}
