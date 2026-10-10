--[[
	Biomes, rarities, pets and eggs.

	Every biome lists its own pets. Its three eggs (Standard, Rare, Royal) are
	built from those pets below, so prices, hatch times and odds all follow the
	numbers in this file. Luck multiplies the weight of every entry whose rarity
	is in LuckyRarities, for egg offers and for hatches.

	Colors are RGB 0-255 and materials are Enum.Material names, so this file has
	no Roblox types and is unit tested outside Studio.

	Pet, egg, biome and mutation ids are saved in player data. Renaming one
	removes it from existing saves, so add new ids instead.
]]

local RARITIES = {
	-- weight: base chance inside an egg; income: multiplier over the biome's Common income
	{ name = "Common", color = { 200, 200, 200 }, weight = 50, income = 1 },
	{ name = "Uncommon", color = { 90, 210, 90 }, weight = 25, income = 2 },
	{ name = "Rare", color = { 70, 140, 255 }, weight = 12.5, income = 4 },
	{ name = "Epic", color = { 170, 80, 255 }, weight = 6.7, income = 8 },
	{ name = "Legendary", color = { 255, 170, 40 }, weight = 3.3, income = 16 },
	{ name = "Mythic", color = { 255, 60, 80 }, weight = 1, income = 40 },
	{ name = "Exotic", color = { 255, 110, 200 }, weight = 0.2, income = 100 },
	{ name = "Divine", color = { 255, 240, 170 }, weight = 0.04, income = 300 },
	{ name = "Secret", color = { 25, 25, 25 }, weight = 0.0067, income = 1000 },
	{ name = "Cosmic", color = { 120, 60, 255 }, weight = 0.001, income = 5000 },
}

-- Each biome: its look, and its pets as { id, name, rarity, shape, color }.
-- shape is one of "beast", "bird", "fish", "blob".
local BIOMES = {
	{
		id = "Farm",
		name = "Farm",
		ground = { 110, 190, 70 },
		material = "Grass",
		accent = { 200, 60, 50 },
		pets = {
			{ "Chick", "Chick", "Common", "bird", { 255, 230, 90 } },
			{ "Piglet", "Piglet", "Common", "beast", { 250, 170, 180 } },
			{ "Lamb", "Lamb", "Uncommon", "beast", { 245, 245, 240 } },
			{ "Cow", "Cow", "Uncommon", "beast", { 240, 240, 240 } },
			{ "Goat", "Goat", "Rare", "beast", { 180, 160, 130 } },
			{ "Horse", "Horse", "Epic", "beast", { 140, 90, 50 } },
			{ "GoldenRooster", "Golden Rooster", "Legendary", "bird", { 255, 200, 40 } },
			{ "BullKing", "Bull King", "Mythic", "beast", { 120, 40, 30 } },
		},
	},
	{
		id = "Forest",
		name = "Forest",
		ground = { 60, 120, 50 },
		material = "Grass",
		accent = { 100, 70, 40 },
		pets = {
			{ "Squirrel", "Squirrel", "Common", "beast", { 190, 110, 50 } },
			{ "Hedgehog", "Hedgehog", "Common", "blob", { 130, 100, 80 } },
			{ "Rabbit", "Rabbit", "Uncommon", "beast", { 210, 200, 190 } },
			{ "Fox", "Fox", "Uncommon", "beast", { 230, 110, 40 } },
			{ "Deer", "Deer", "Rare", "beast", { 170, 120, 70 } },
			{ "Owl", "Owl", "Epic", "bird", { 150, 120, 90 } },
			{ "Bear", "Bear", "Legendary", "beast", { 100, 70, 45 } },
			{ "AncientTreant", "Ancient Treant", "Mythic", "blob", { 70, 110, 50 } },
		},
	},
	{
		id = "Desert",
		name = "Desert",
		ground = { 235, 205, 140 },
		material = "Sand",
		accent = { 200, 140, 70 },
		pets = {
			{ "Lizard", "Lizard", "Common", "beast", { 170, 180, 90 } },
			{ "Scorpion", "Scorpion", "Common", "beast", { 120, 70, 40 } },
			{ "Camel", "Camel", "Uncommon", "beast", { 210, 170, 110 } },
			{ "Fennec", "Fennec", "Rare", "beast", { 240, 200, 140 } },
			{ "Vulture", "Vulture", "Epic", "bird", { 90, 70, 60 } },
			{ "SphinxCat", "Sphinx Cat", "Legendary", "beast", { 230, 190, 100 } },
			{ "SandSerpent", "Sand Serpent", "Mythic", "fish", { 200, 160, 80 } },
			{ "PharaohJackal", "Pharaoh Jackal", "Exotic", "beast", { 40, 40, 60 } },
		},
	},
	{
		id = "Snow",
		name = "Snow",
		ground = { 240, 245, 255 },
		material = "Snow",
		accent = { 150, 210, 255 },
		pets = {
			{ "Penguin", "Penguin", "Common", "bird", { 40, 40, 50 } },
			{ "SnowHare", "Snow Hare", "Common", "beast", { 250, 250, 255 } },
			{ "ArcticFox", "Arctic Fox", "Uncommon", "beast", { 235, 240, 250 } },
			{ "Seal", "Seal", "Rare", "fish", { 150, 160, 170 } },
			{ "Husky", "Husky", "Epic", "beast", { 140, 150, 170 } },
			{ "PolarBear", "Polar Bear", "Legendary", "beast", { 250, 250, 245 } },
			{ "Yeti", "Yeti", "Mythic", "blob", { 220, 235, 255 } },
			{ "FrostPhoenix", "Frost Phoenix", "Exotic", "bird", { 120, 200, 255 } },
		},
	},
	{
		id = "Jungle",
		name = "Jungle",
		ground = { 40, 140, 60 },
		material = "LeafyGrass",
		accent = { 255, 200, 50 },
		pets = {
			{ "Frog", "Frog", "Common", "blob", { 80, 200, 80 } },
			{ "Parrot", "Parrot", "Uncommon", "bird", { 230, 50, 50 } },
			{ "Monkey", "Monkey", "Rare", "beast", { 130, 90, 60 } },
			{ "Jaguar", "Jaguar", "Epic", "beast", { 230, 170, 60 } },
			{ "Gorilla", "Gorilla", "Legendary", "beast", { 60, 60, 60 } },
			{ "EmeraldSerpent", "Emerald Serpent", "Mythic", "fish", { 30, 200, 110 } },
			{ "SpiritJaguar", "Spirit Jaguar", "Exotic", "beast", { 120, 255, 200 } },
			{ "DivineToucan", "Divine Toucan", "Divine", "bird", { 255, 230, 120 } },
		},
	},
	{
		id = "Ocean",
		name = "Ocean",
		ground = { 240, 220, 170 },
		material = "Sand",
		accent = { 40, 140, 230 },
		pets = {
			{ "Clownfish", "Clownfish", "Common", "fish", { 255, 130, 40 } },
			{ "Crab", "Crab", "Uncommon", "blob", { 230, 70, 50 } },
			{ "Turtle", "Turtle", "Rare", "beast", { 80, 160, 90 } },
			{ "Dolphin", "Dolphin", "Epic", "fish", { 120, 160, 200 } },
			{ "Shark", "Shark", "Legendary", "fish", { 110, 120, 140 } },
			{ "Octopus", "Octopus", "Mythic", "blob", { 200, 80, 160 } },
			{ "Kraken", "Kraken", "Exotic", "blob", { 90, 30, 110 } },
			{ "PoseidonWhale", "Poseidon Whale", "Divine", "fish", { 60, 180, 255 } },
		},
	},
	{
		id = "Volcano",
		name = "Volcano",
		ground = { 60, 50, 50 },
		material = "Basalt",
		accent = { 255, 90, 20 },
		pets = {
			{ "EmberSlug", "Ember Slug", "Common", "blob", { 255, 120, 50 } },
			{ "LavaLizard", "Lava Lizard", "Uncommon", "beast", { 220, 70, 30 } },
			{ "FireBat", "Fire Bat", "Rare", "bird", { 120, 30, 30 } },
			{ "MagmaHound", "Magma Hound", "Epic", "beast", { 200, 50, 20 } },
			{ "LavaGolem", "Lava Golem", "Legendary", "blob", { 90, 40, 30 } },
			{ "FireDragon", "Fire Dragon", "Mythic", "beast", { 255, 70, 0 } },
			{ "InfernoPhoenix", "Inferno Phoenix", "Exotic", "bird", { 255, 140, 0 } },
			{ "ObsidianTitan", "Obsidian Titan", "Divine", "blob", { 30, 20, 40 } },
			{ "CoreKing", "Core King", "Secret", "beast", { 255, 40, 0 } },
		},
	},
	{
		id = "Prehistoric",
		name = "Prehistoric",
		ground = { 120, 150, 70 },
		material = "Ground",
		accent = { 230, 220, 190 },
		pets = {
			{ "Dodo", "Dodo", "Common", "bird", { 150, 140, 130 } },
			{ "Trilobite", "Trilobite", "Uncommon", "blob", { 140, 110, 90 } },
			{ "Raptor", "Raptor", "Rare", "beast", { 110, 150, 80 } },
			{ "Stegosaurus", "Stegosaurus", "Epic", "beast", { 90, 140, 110 } },
			{ "Triceratops", "Triceratops", "Legendary", "beast", { 160, 120, 80 } },
			{ "Pterodactyl", "Pterodactyl", "Mythic", "bird", { 170, 110, 90 } },
			{ "Spinosaurus", "Spinosaurus", "Exotic", "beast", { 70, 100, 140 } },
			{ "Mammoth", "Mammoth", "Divine", "beast", { 130, 90, 60 } },
			{ "TRexKing", "T-Rex King", "Secret", "beast", { 60, 90, 50 } },
		},
	},
	{
		id = "Kingdom",
		name = "Kingdom",
		ground = { 160, 160, 170 },
		material = "Cobblestone",
		accent = { 230, 190, 50 },
		pets = {
			{ "RoyalCorgi", "Royal Corgi", "Common", "beast", { 230, 160, 80 } },
			{ "CastleCat", "Castle Cat", "Uncommon", "beast", { 120, 120, 130 } },
			{ "KnightPup", "Knight Pup", "Rare", "beast", { 190, 190, 200 } },
			{ "Unicorn", "Unicorn", "Epic", "beast", { 250, 210, 245 } },
			{ "Griffin", "Griffin", "Legendary", "bird", { 190, 150, 80 } },
			{ "RoyalLion", "Royal Lion", "Mythic", "beast", { 230, 180, 60 } },
			{ "GoldenPegasus", "Golden Pegasus", "Exotic", "bird", { 255, 215, 90 } },
			{ "KingDragon", "King Dragon", "Divine", "beast", { 160, 30, 50 } },
			{ "CrownPhantom", "Crown Phantom", "Secret", "blob", { 40, 30, 60 } },
		},
	},
	{
		id = "Skylands",
		name = "Skylands",
		ground = { 230, 240, 255 },
		material = "SmoothPlastic",
		accent = { 140, 200, 255 },
		pets = {
			{ "CloudPuff", "Cloud Puff", "Common", "blob", { 250, 250, 255 } },
			{ "SkyBunny", "Sky Bunny", "Uncommon", "beast", { 190, 220, 255 } },
			{ "WindFox", "Wind Fox", "Rare", "beast", { 160, 230, 220 } },
			{ "StormOwl", "Storm Owl", "Epic", "bird", { 90, 100, 140 } },
			{ "ThunderWolf", "Thunder Wolf", "Legendary", "beast", { 80, 90, 160 } },
			{ "SkyWhale", "Sky Whale", "Mythic", "fish", { 150, 190, 255 } },
			{ "AuroraPhoenix", "Aurora Phoenix", "Exotic", "bird", { 120, 255, 200 } },
			{ "CelestialPegasus", "Celestial Pegasus", "Divine", "bird", { 255, 250, 220 } },
			{ "SkyEmperor", "Sky Emperor", "Secret", "beast", { 30, 40, 80 } },
			{ "StarbornSeraph", "Starborn Seraph", "Cosmic", "bird", { 200, 160, 255 } },
		},
	},
	{
		id = "Cosmic",
		name = "Cosmic",
		ground = { 30, 20, 60 },
		material = "Slate",
		accent = { 180, 120, 255 },
		pets = {
			{ "StarCat", "Star Cat", "Common", "beast", { 255, 230, 120 } },
			{ "MoonBunny", "Moon Bunny", "Uncommon", "beast", { 220, 220, 240 } },
			{ "CometFox", "Comet Fox", "Rare", "beast", { 120, 200, 255 } },
			{ "AlienBlob", "Alien Blob", "Epic", "blob", { 120, 255, 120 } },
			{ "NebulaWolf", "Nebula Wolf", "Legendary", "beast", { 160, 80, 220 } },
			{ "GalaxyWhale", "Galaxy Whale", "Mythic", "fish", { 60, 40, 140 } },
			{ "SupernovaDragon", "Supernova Dragon", "Exotic", "beast", { 255, 120, 60 } },
			{ "BlackHoleBeast", "Black Hole Beast", "Divine", "blob", { 15, 10, 25 } },
			{ "VoidEmperor", "Void Emperor", "Secret", "beast", { 50, 0, 80 } },
			{ "CosmicOverlord", "Cosmic Overlord", "Cosmic", "beast", { 140, 80, 255 } },
		},
	},
}

-- Numbers that set the whole curve. Biome n (1-based) costs PRICE_GROWTH^(n-1) times biome 1.
local FIRST_EGG_PRICE = 100
local PRICE_GROWTH = 8
local FIRST_UNLOCK_COST = 5000 -- biome 2; later biomes grow by PRICE_GROWTH
local PAYBACK_SECONDS = 40 -- a Common from a Standard egg earns its price back in this long
local HATCH_TIMES = { 15, 30, 45, 60, 90, 120, 180, 240, 300, 420, 600 }

-- The three eggs every biome's station offers.
local EGG_KINDS = {
	-- offer: weight on the roll station; minTier: lowest pet rarity inside;
	-- skipTop: leave out the biome's best pet; tierBoost: weight multiplier per rarity step up
	{
		suffix = "Standard",
		label = "",
		rarity = "Common",
		offer = 75,
		price = 1,
		hatch = 1,
		tierBoost = 1,
		minTier = 1,
		skipTop = true,
	},
	{
		suffix = "Rare",
		label = "Rare ",
		rarity = "Rare",
		offer = 20,
		price = 5,
		hatch = 2,
		tierBoost = 1.25,
		minTier = 1,
		skipTop = false,
	},
	{
		suffix = "Royal",
		label = "Royal ",
		rarity = "Legendary",
		offer = 5,
		price = 25,
		hatch = 4,
		tierBoost = 1.4,
		minTier = 3,
		skipTop = false,
	},
}

local rarityIndex: { [string]: number } = {}
for index, rarity in RARITIES do
	rarityIndex[rarity.name] = index
end

local pets: { [string]: any } = {}
local eggs: { any } = {}
local eggsById: { [string]: any } = {}
local biomesById: { [string]: any } = {}

for biomeIndex, biome in BIOMES do
	local growth = PRICE_GROWTH ^ (biomeIndex - 1)
	local basePrice = FIRST_EGG_PRICE * growth
	local commonIncome = basePrice / PAYBACK_SECONDS

	biome.index = biomeIndex
	biome.unlockCost = if biomeIndex == 1 then 0 else math.floor(FIRST_UNLOCK_COST * PRICE_GROWTH ^ (biomeIndex - 2))
	biome.petIds = {}
	biome.eggIds = {}
	biomesById[biome.id] = biome

	local topTier = 0
	for _, entry in biome.pets do
		topTier = math.max(topTier, rarityIndex[entry[3]])
	end
	biome.topRarity = RARITIES[topTier].name

	for _, entry in biome.pets do
		local id, name, rarity, shape, color = entry[1], entry[2], entry[3], entry[4], entry[5]
		assert(rarityIndex[rarity], `{id} has unknown rarity {rarity}`)
		pets[id] = {
			id = id,
			name = name,
			rarity = rarity,
			shape = shape,
			color = color,
			biome = biome.id,
			income = math.max(1, math.floor(commonIncome * RARITIES[rarityIndex[rarity]].income)),
		}
		table.insert(biome.petIds, id)
	end

	for _, kind in EGG_KINDS do
		local eggPets = {}
		for _, petId in biome.petIds do
			local tier = rarityIndex[pets[petId].rarity]
			if tier >= kind.minTier and not (kind.skipTop and tier == topTier) then
				table.insert(eggPets, { id = petId, weight = RARITIES[tier].weight * kind.tierBoost ^ (tier - 1) })
			end
		end
		local egg = {
			id = `{biome.id}{kind.suffix}`,
			name = `{kind.label}{biome.name} Egg`,
			biome = biome.id,
			kind = kind.suffix,
			rarity = kind.rarity,
			offerWeight = kind.offer,
			price = math.floor(basePrice * kind.price),
			hatchTime = HATCH_TIMES[biomeIndex] * kind.hatch,
			color = if kind.suffix == "Royal" then { 255, 210, 60 } else biome.ground,
			accent = if kind.suffix == "Standard" then biome.accent else RARITIES[rarityIndex[kind.rarity]].color,
			pets = eggPets,
		}
		table.insert(eggs, egg)
		eggsById[egg.id] = egg
		table.insert(biome.eggIds, egg.id)
	end
end

return {
	Rarities = RARITIES,
	RarityIndex = rarityIndex,

	-- Luck boosts only these, so it makes rare eggs and pets likelier without touching commons.
	LuckyRarities = {
		Rare = true,
		Epic = true,
		Legendary = true,
		Mythic = true,
		Exotic = true,
		Divine = true,
		Secret = true,
		Cosmic = true,
	},

	-- Rolled on every hatch, rarest first. A mutation multiplies income and sell value.
	Mutations = {
		{ id = "Rainbow", name = "Rainbow", oneIn = 500, multiplier = 10, color = { 255, 120, 220 } },
		{ id = "Diamond", name = "Diamond", oneIn = 100, multiplier = 5, color = { 150, 230, 255 } },
		{ id = "Golden", name = "Golden", oneIn = 20, multiplier = 2, color = { 255, 200, 40 } },
	},

	Biomes = BIOMES,
	BiomesById = biomesById,
	Pets = pets,
	Eggs = eggs,
	EggsById = eggsById,
}
