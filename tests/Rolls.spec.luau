local Rolls = require("../src/shared/Rolls")
local PetConfig = require("../src/shared/Config/Pets")
local T = require("./TestKit")

local function sequence(values: { number })
	local index = 0
	return function()
		index += 1
		return values[index]
	end
end

local ENTRIES = { { id = "Common", weight = 75 }, { id = "Rare", weight = 25 } }
local RARITY = { Common = "Common", Rare = "Rare" }
local function rarityOf(id)
	return RARITY[id]
end

local function chanceOf(chances, id)
	for _, chance in chances do
		if chance.id == id then
			return chance.chance
		end
	end
	return 0
end

return {
	["Pick follows the weights"] = function()
		T.equal(Rolls.Pick(ENTRIES, sequence({ 0 })), "Common")
		T.equal(Rolls.Pick(ENTRIES, sequence({ 0.749 })), "Common")
		T.equal(Rolls.Pick(ENTRIES, sequence({ 0.75 })), "Rare")
		T.equal(Rolls.Pick(ENTRIES, sequence({ 0.999999 })), "Rare")
	end,
	["WithLuck boosts only lucky rarities and leaves the config alone"] = function()
		local boosted = Rolls.WithLuck(ENTRIES, rarityOf, { Rare = true }, 3)
		T.equal(boosted[1].weight, 75)
		T.equal(boosted[2].weight, 75)
		T.equal(ENTRIES[2].weight, 25)
		local chances = Rolls.Chances(boosted)
		T.equal(chanceOf(chances, "Rare"), 0.5)
	end,
	["luck 1 changes nothing"] = function()
		local chances = Rolls.Chances(Rolls.WithLuck(ENTRIES, rarityOf, { Rare = true }, 1))
		T.equal(chanceOf(chances, "Common"), 0.75)
	end,
	["Mutation checks rarest first and is usually nil"] = function()
		local mutations = { { id = "Rainbow", oneIn = 100 }, { id = "Golden", oneIn = 10 } }
		T.equal(Rolls.Mutation(mutations, sequence({ 0 })), "Rainbow")
		T.equal(Rolls.Mutation(mutations, sequence({ 0.0099 })), "Rainbow")
		T.equal(Rolls.Mutation(mutations, sequence({ 0.01 })), "Golden")
		T.equal(Rolls.Mutation(mutations, sequence({ 0.1099 })), "Golden")
		T.equal(Rolls.Mutation(mutations, sequence({ 0.11 })), nil)
	end,
	["shipped mutations are rarest first with whole multipliers"] = function()
		local total, last = 0, math.huge
		for _, mutation in PetConfig.Mutations do
			T.truthy(mutation.oneIn <= last, `{mutation.id} is out of order`)
			T.truthy(mutation.multiplier > 1 and mutation.multiplier % 1 == 0, `{mutation.id} multiplier`)
			last = mutation.oneIn
			total += 1 / mutation.oneIn
		end
		T.truthy(total < 1, "mutation chances add up to 1 or more")
	end,
	["OneIn formats odds"] = function()
		T.equal(Rolls.OneIn(0.5), "1 in 2")
		T.equal(Rolls.OneIn(0.4), "1 in 2.5")
		T.equal(Rolls.OneIn(0.001), "1 in 1000")
		T.equal(Rolls.OneIn(0), "never")
	end,
	["shipped eggs only contain known pets with sane numbers"] = function()
		local seen = {}
		for _, egg in PetConfig.Eggs do
			T.falsy(seen[egg.id], `duplicate egg {egg.id}`)
			seen[egg.id] = true
			T.truthy(egg.price > 0 and egg.price % 1 == 0, `{egg.id} price`)
			T.truthy(egg.hatchTime > 0, `{egg.id} hatchTime`)
			T.truthy(#egg.pets > 0, `{egg.id} has no pets`)
			for _, entry in egg.pets do
				T.truthy(PetConfig.Pets[entry.id], `{egg.id} lists unknown pet {entry.id}`)
				T.truthy(entry.weight > 0, `{egg.id}.{entry.id} weight`)
			end
		end
		local rarities = {}
		for _, rarity in PetConfig.Rarities do
			rarities[rarity.name] = true
		end
		for id, pet in PetConfig.Pets do
			T.truthy(rarities[pet.rarity], `{id} has unknown rarity {pet.rarity}`)
			T.truthy(pet.income > 0 and pet.income % 1 == 0, `{id} income`)
		end
	end,
}
