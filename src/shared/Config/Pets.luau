--!strict
-- Every pet species. `weight` is the chance within its rarity pool (relative),
-- `incomeMultiplier` scales the rarity's base income. Within a pool the better
-- species is the rarer one, so each rarity keeps a small chase of its own.
-- `archetype` and `colors` drive the procedural model builder.

export type Archetype = "Bird" | "Small" | "Quadruped" | "Large" | "Fish" | "Insect" | "Dragon"

export type Species = {
	id: string,
	name: string,
	rarity: string,
	weight: number,
	incomeMultiplier: number,
	archetype: Archetype,
	colors: { Color3 },
}

export type Variant = {
	id: string,
	name: string,
	order: number,
	baseChance: number, -- per hatch, before Shiny Luck
	incomeMultiplier: number,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Species } = {
	-- Common
	{
		id = "BarnChick",
		name = "Barn Chick",
		rarity = "Common",
		weight = 30,
		incomeMultiplier = 0.9,
		archetype = "Bird",
		colors = { rgb(255, 221, 87), rgb(255, 140, 50) },
	},
	{
		id = "CloverBunny",
		name = "Clover Bunny",
		rarity = "Common",
		weight = 25,
		incomeMultiplier = 1.0,
		archetype = "Small",
		colors = { rgb(245, 245, 240), rgb(120, 200, 110) },
	},
	{
		id = "MudPiglet",
		name = "Mud Piglet",
		rarity = "Common",
		weight = 20,
		incomeMultiplier = 1.05,
		archetype = "Quadruped",
		colors = { rgb(255, 170, 180), rgb(140, 95, 70) },
	},
	{
		id = "HayMouse",
		name = "Hay Mouse",
		rarity = "Common",
		weight = 15,
		incomeMultiplier = 1.15,
		archetype = "Small",
		colors = { rgb(180, 160, 140), rgb(230, 200, 110) },
	},
	{
		id = "PondDuckling",
		name = "Pond Duckling",
		rarity = "Common",
		weight = 10,
		incomeMultiplier = 1.3,
		archetype = "Bird",
		colors = { rgb(255, 235, 120), rgb(90, 170, 230) },
	},
	-- Uncommon
	{
		id = "WoolLamb",
		name = "Wool Lamb",
		rarity = "Uncommon",
		weight = 30,
		incomeMultiplier = 0.9,
		archetype = "Quadruped",
		colors = { rgb(250, 248, 240), rgb(60, 55, 60) },
	},
	{
		id = "MossGoat",
		name = "Moss Goat",
		rarity = "Uncommon",
		weight = 25,
		incomeMultiplier = 1.0,
		archetype = "Quadruped",
		colors = { rgb(200, 190, 170), rgb(100, 160, 80) },
	},
	{
		id = "PumpkinPup",
		name = "Pumpkin Pup",
		rarity = "Uncommon",
		weight = 20,
		incomeMultiplier = 1.05,
		archetype = "Quadruped",
		colors = { rgb(255, 150, 40), rgb(80, 140, 60) },
	},
	{
		id = "DewFrog",
		name = "Dew Frog",
		rarity = "Uncommon",
		weight = 15,
		incomeMultiplier = 1.15,
		archetype = "Small",
		colors = { rgb(110, 210, 120), rgb(180, 240, 255) },
	},
	{
		id = "HoneyBee",
		name = "Honey Bee",
		rarity = "Uncommon",
		weight = 10,
		incomeMultiplier = 1.3,
		archetype = "Insect",
		colors = { rgb(255, 200, 40), rgb(40, 35, 30) },
	},
	-- Rare
	{
		id = "SunflowerFox",
		name = "Sunflower Fox",
		rarity = "Rare",
		weight = 35,
		incomeMultiplier = 0.9,
		archetype = "Quadruped",
		colors = { rgb(255, 130, 50), rgb(255, 220, 60) },
	},
	{
		id = "ThistleHedgehog",
		name = "Thistle Hedgehog",
		rarity = "Rare",
		weight = 30,
		incomeMultiplier = 1.0,
		archetype = "Small",
		colors = { rgb(150, 110, 180), rgb(120, 90, 70) },
	},
	{
		id = "CopperCalf",
		name = "Copper Calf",
		rarity = "Rare",
		weight = 22,
		incomeMultiplier = 1.1,
		archetype = "Quadruped",
		colors = { rgb(200, 120, 70), rgb(250, 240, 230) },
	},
	{
		id = "BerryBat",
		name = "Berry Bat",
		rarity = "Rare",
		weight = 13,
		incomeMultiplier = 1.3,
		archetype = "Bird",
		colors = { rgb(110, 60, 150), rgb(230, 60, 110) },
	},
	-- Epic
	{
		id = "LanternOwl",
		name = "Lantern Owl",
		rarity = "Epic",
		weight = 35,
		incomeMultiplier = 0.9,
		archetype = "Bird",
		colors = { rgb(120, 90, 70), rgb(255, 210, 90) },
	},
	{
		id = "CrystalRam",
		name = "Crystal Ram",
		rarity = "Epic",
		weight = 30,
		incomeMultiplier = 1.0,
		archetype = "Quadruped",
		colors = { rgb(235, 240, 255), rgb(140, 210, 255) },
	},
	{
		id = "EmberPony",
		name = "Ember Pony",
		rarity = "Epic",
		weight = 22,
		incomeMultiplier = 1.1,
		archetype = "Large",
		colors = { rgb(60, 40, 40), rgb(255, 110, 40) },
	},
	{
		id = "TideTurtle",
		name = "Tide Turtle",
		rarity = "Epic",
		weight = 13,
		incomeMultiplier = 1.3,
		archetype = "Small",
		colors = { rgb(60, 170, 160), rgb(40, 100, 160) },
	},
	-- Legendary
	{
		id = "GoldenStag",
		name = "Golden Stag",
		rarity = "Legendary",
		weight = 45,
		incomeMultiplier = 0.9,
		archetype = "Large",
		colors = { rgb(255, 200, 70), rgb(255, 250, 220) },
	},
	{
		id = "StormRooster",
		name = "Storm Rooster",
		rarity = "Legendary",
		weight = 35,
		incomeMultiplier = 1.05,
		archetype = "Bird",
		colors = { rgb(70, 80, 120), rgb(120, 220, 255) },
	},
	{
		id = "AuroraKoi",
		name = "Aurora Koi",
		rarity = "Legendary",
		weight = 20,
		incomeMultiplier = 1.3,
		archetype = "Fish",
		colors = { rgb(255, 120, 160), rgb(120, 255, 210) },
	},
	-- Mythic
	{
		id = "StarlightAlpaca",
		name = "Starlight Alpaca",
		rarity = "Mythic",
		weight = 45,
		incomeMultiplier = 0.9,
		archetype = "Large",
		colors = { rgb(60, 60, 120), rgb(255, 245, 180) },
	},
	{
		id = "PhoenixHen",
		name = "Phoenix Hen",
		rarity = "Mythic",
		weight = 35,
		incomeMultiplier = 1.05,
		archetype = "Bird",
		colors = { rgb(255, 80, 40), rgb(255, 210, 60) },
	},
	{
		id = "CelestialOx",
		name = "Celestial Ox",
		rarity = "Mythic",
		weight = 20,
		incomeMultiplier = 1.3,
		archetype = "Large",
		colors = { rgb(40, 30, 80), rgb(170, 140, 255) },
	},
	-- Secret
	{
		id = "CosmicCow",
		name = "Cosmic Cow",
		rarity = "Secret",
		weight = 65,
		incomeMultiplier = 0.9,
		archetype = "Large",
		colors = { rgb(20, 20, 40), rgb(255, 255, 255) },
	},
	{
		id = "HarvestWyrm",
		name = "Harvest Wyrm",
		rarity = "Secret",
		weight = 35,
		incomeMultiplier = 1.3,
		archetype = "Dragon",
		colors = { rgb(240, 180, 60), rgb(110, 60, 30) },
	},
}

local variants: { Variant } = {
	{ id = "Normal", name = "Normal", order = 0, baseChance = 1, incomeMultiplier = 1 },
	{ id = "Shiny", name = "Shiny", order = 1, baseChance = 1 / 50, incomeMultiplier = 2.5 },
	{ id = "Rainbow", name = "Rainbow", order = 2, baseChance = 1 / 1000, incomeMultiplier = 6 },
}

local byId: { [string]: Species } = {}
local byRarity: { [string]: { Species } } = {}
for _, species in list do
	assert(byId[species.id] == nil, `duplicate species id {species.id}`)
	byId[species.id] = species
	local pool = byRarity[species.rarity]
	if pool == nil then
		pool = {}
		byRarity[species.rarity] = pool
	end
	table.insert(pool, species)
end

local variantById: { [string]: Variant } = {}
for _, variant in variants do
	variantById[variant.id] = variant
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	byRarity = table.freeze(byRarity),
	variants = table.freeze(variants),
	variantById = table.freeze(variantById),
})
