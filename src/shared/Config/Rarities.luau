--!strict
-- Egg / pet rarity tiers. Order matters: index 1 is the most common.
-- `weight` is the base roll weight at luck 1 (weights are normalised, so they
-- read as percentages). `luckExponent` controls how strongly luck scales that
-- tier's weight: 0 means luck never makes it more likely.

export type Rarity = {
	id: string,
	name: string,
	order: number,
	weight: number,
	luckExponent: number,
	baseIncome: number, -- coins per second for a x1.0 species, no variant
	hatchSeconds: number,
	releaseRefund: number, -- coins for releasing a pet; kept tiny so roll-and-release never profits
	color: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Rarity } = {
	{
		id = "Common",
		name = "Common",
		order = 1,
		weight = 55,
		luckExponent = 0,
		baseIncome = 1,
		hatchSeconds = 2,
		releaseRefund = 1,
		color = rgb(184, 192, 204),
	},
	{
		id = "Uncommon",
		name = "Uncommon",
		order = 2,
		weight = 28,
		luckExponent = 0.5,
		baseIncome = 3,
		hatchSeconds = 3,
		releaseRefund = 2,
		color = rgb(91, 209, 106),
	},
	{
		id = "Rare",
		name = "Rare",
		order = 3,
		weight = 12,
		luckExponent = 0.8,
		baseIncome = 10,
		hatchSeconds = 5,
		releaseRefund = 4,
		color = rgb(63, 169, 245),
	},
	{
		id = "Epic",
		name = "Epic",
		order = 4,
		weight = 4,
		luckExponent = 1,
		baseIncome = 35,
		hatchSeconds = 8,
		releaseRefund = 8,
		color = rgb(166, 107, 255),
	},
	{
		id = "Legendary",
		name = "Legendary",
		order = 5,
		weight = 0.9,
		luckExponent = 1,
		baseIncome = 150,
		hatchSeconds = 12,
		releaseRefund = 15,
		color = rgb(255, 176, 46),
	},
	{
		id = "Mythic",
		name = "Mythic",
		order = 6,
		weight = 0.099,
		luckExponent = 1,
		baseIncome = 700,
		hatchSeconds = 20,
		releaseRefund = 25,
		color = rgb(255, 77, 109),
	},
	{
		id = "Secret",
		name = "Secret",
		order = 7,
		weight = 0.001,
		luckExponent = 0.85,
		baseIncome = 5000,
		hatchSeconds = 30,
		releaseRefund = 50,
		color = rgb(20, 20, 28), -- drawn with an animated prism gradient in UI
	},
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = rarity
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	secretId = "Secret",
})
