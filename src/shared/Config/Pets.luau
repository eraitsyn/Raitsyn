--[[
	Pets, eggs and rarity odds.

	Spinning picks one egg by spinWeight (luck boosts eggs whose rarity is in
	LuckyRarities); the player can then buy that egg or spin again.

	Each egg lists the pets it can hatch with a weight. A pet's chance is its
	weight divided by the egg's total weight; luck multiplies the weight of
	every pet whose rarity is in LuckyRarities (see Rolls.EggChances).

	price      whole number of cash to buy the egg
	hatchTime  seconds the egg sits in an incubator before it can hatch
	income     cash per second a pet earns on a pedestal
	color      RGB 0-255; plain numbers keep this file free of Roblox types

	Mutations are rolled separately on every hatch. oneIn is the chance of that
	mutation ("1 in 20"); a pet with none is a normal pet. A mutation multiplies
	the pet's income and sell value.

	Pet, egg and mutation ids are saved in player data. Renaming one removes it from
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

	-- Rarest first. Luck does not change these.
	Mutations = {
		{ id = "Rainbow", name = "Rainbow", oneIn = 500, multiplier = 10, color = { 255, 120, 220 } },
		{ id = "Diamond", name = "Diamond", oneIn = 100, multiplier = 5, color = { 150, 230, 255 } },
		{ id = "Golden", name = "Golden", oneIn = 20, multiplier = 2, color = { 255, 200, 40 } },
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

		Lion = { name = "Lion", rarity = "Uncommon", income = 12, color = { 220, 170, 70 } },
		Tiger = { name = "Tiger", rarity = "Rare", income = 24, color = { 240, 140, 30 } },
		Wolf = { name = "Wolf", rarity = "Rare", income = 30, color = { 130, 130, 145 } },
		Phoenix = { name = "Phoenix", rarity = "Epic", income = 80, color = { 255, 90, 30 } },
		Griffin = { name = "Griffin", rarity = "Legendary", income = 240, color = { 180, 140, 80 } },
		Pegasus = { name = "Pegasus", rarity = "Mythical", income = 800, color = { 200, 230, 255 } },

		StarCat = { name = "Star Cat", rarity = "Epic", income = 150, color = { 255, 230, 120 } },
		CometFox = { name = "Comet Fox", rarity = "Legendary", income = 400, color = { 120, 200, 255 } },
		NebulaDragon = { name = "Nebula Dragon", rarity = "Mythical", income = 1250, color = { 160, 80, 220 } },
		GalaxyWhale = { name = "Galaxy Whale", rarity = "Secret", income = 5000, color = { 40, 30, 90 } },

		Salamander = { name = "Salamander", rarity = "Rare", income = 800, color = { 255, 110, 50 } },
		LavaHound = { name = "Lava Hound", rarity = "Epic", income = 1800, color = { 200, 50, 20 } },
		MagmaGolem = { name = "Magma Golem", rarity = "Legendary", income = 5000, color = { 90, 40, 30 } },
		FireDragon = { name = "Fire Dragon", rarity = "Mythical", income = 18000, color = { 255, 70, 0 } },
		InfernoKing = { name = "Inferno King", rarity = "Secret", income = 80000, color = { 255, 30, 30 } },

		ShadowCat = { name = "Shadow Cat", rarity = "Epic", income = 7500, color = { 50, 40, 70 } },
		VoidBat = { name = "Void Bat", rarity = "Legendary", income = 20000, color = { 90, 30, 140 } },
		AbyssSerpent = { name = "Abyss Serpent", rarity = "Mythical", income = 75000, color = { 20, 60, 90 } },
		EclipseDragon = { name = "Eclipse Dragon", rarity = "Secret", income = 400000, color = { 10, 10, 20 } },
	},

	-- Spin odds come from spinWeight; the order is the order shown on the spinner sign.
	Eggs = {
		{
			id = "Basic",
			name = "Basic Egg",
			rarity = "Common",
			spinWeight = 55,
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
			rarity = "Uncommon",
			spinWeight = 28,
			price = 500,
			hatchTime = 30,
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
			rarity = "Rare",
			spinWeight = 12,
			price = 5000,
			hatchTime = 60,
			color = { 90, 60, 200 },
			pets = {
				{ id = "StarCat", weight = 70 },
				{ id = "CometFox", weight = 25 },
				{ id = "NebulaDragon", weight = 4.9 },
				{ id = "GalaxyWhale", weight = 0.1 },
			},
		},
		{
			id = "Volcano",
			name = "Volcano Egg",
			rarity = "Epic",
			spinWeight = 4.5,
			price = 50000,
			hatchTime = 120,
			color = { 230, 70, 20 },
			pets = {
				{ id = "Salamander", weight = 60 },
				{ id = "LavaHound", weight = 28 },
				{ id = "MagmaGolem", weight = 10 },
				{ id = "FireDragon", weight = 1.9 },
				{ id = "InfernoKing", weight = 0.1 },
			},
		},
		{
			id = "Void",
			name = "Void Egg",
			rarity = "Legendary",
			spinWeight = 0.5,
			price = 500000,
			hatchTime = 300,
			color = { 40, 10, 60 },
			pets = {
				{ id = "ShadowCat", weight = 65 },
				{ id = "VoidBat", weight = 28 },
				{ id = "AbyssSerpent", weight = 6.9 },
				{ id = "EclipseDragon", weight = 0.1 },
			},
		},
	},
}
