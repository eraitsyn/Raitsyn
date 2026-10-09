--[[
	The god roster and rarity odds.

	weight   relative chance a rarity is rolled for the conveyor
	price    whole number of cash to buy from the conveyor
	income   cash per second while placed in a base slot
	color    RGB 0-255; plain numbers keep this file free of Roblox types

	God ids are saved in player data. Renaming one removes it from existing
	saves, so add new ids instead.
]]

return {
	Rarities = {
		{ name = "Common", weight = 50, color = { 200, 200, 200 } },
		{ name = "Uncommon", weight = 25, color = { 90, 200, 90 } },
		{ name = "Rare", weight = 14, color = { 70, 140, 255 } },
		{ name = "Epic", weight = 7, color = { 170, 80, 255 } },
		{ name = "Legendary", weight = 3, color = { 255, 170, 40 } },
		{ name = "Mythic", weight = 0.9, color = { 255, 60, 90 } },
		{ name = "Secret", weight = 0.1, color = { 20, 20, 20 } },
	},

	Gods = {
		Pan = { name = "Pan", rarity = "Common", price = 10, income = 1, color = { 140, 110, 70 } },
		Bastet = { name = "Bastet", rarity = "Common", price = 25, income = 2, color = { 230, 200, 120 } },
		Hermes = {
			name = "Hermes",
			rarity = "Uncommon",
			price = 100,
			income = 5,
			color = { 120, 200, 230 },
		},
		Freyja = {
			name = "Freyja",
			rarity = "Uncommon",
			price = 150,
			income = 7,
			color = { 240, 170, 200 },
		},
		Apollo = { name = "Apollo", rarity = "Rare", price = 500, income = 15, color = { 255, 220, 90 } },
		Anubis = { name = "Anubis", rarity = "Rare", price = 700, income = 20, color = { 40, 40, 50 } },
		Athena = { name = "Athena", rarity = "Epic", price = 2500, income = 50, color = { 180, 180, 210 } },
		Loki = { name = "Loki", rarity = "Epic", price = 3500, income = 65, color = { 60, 140, 70 } },
		Poseidon = {
			name = "Poseidon",
			rarity = "Legendary",
			price = 10000,
			income = 150,
			color = { 40, 120, 200 },
		},
		Thor = { name = "Thor", rarity = "Legendary", price = 15000, income = 200, color = { 200, 60, 50 } },
		Ra = { name = "Ra", rarity = "Mythic", price = 50000, income = 500, color = { 255, 140, 20 } },
		Odin = { name = "Odin", rarity = "Mythic", price = 75000, income = 700, color = { 110, 90, 160 } },
		Zeus = {
			name = "Zeus",
			rarity = "Secret",
			price = 300000,
			income = 2000,
			color = { 250, 250, 255 },
		},
		Kronos = {
			name = "Kronos",
			rarity = "Secret",
			price = 500000,
			income = 3000,
			color = { 90, 70, 50 },
		},
	},
}
