--!strict
-- Pet income. A pet's base rate is rarity income x species multiplier x
-- variant multiplier; the farm's rate applies the player's income multiplier
-- (pet income, Collector's Bonus, global multiplier and rebirths) to the sum.

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Pets = require(Config.Pets)

local Income = {}

function Income.petBase(speciesId: string, variantId: string): number
	local species = Pets.byId[speciesId]
	if species == nil then
		return 0
	end
	local variant = Pets.variantById[variantId] or Pets.variantById.Normal
	return Rarities.byId[species.rarity].baseIncome * species.incomeMultiplier * variant.incomeMultiplier
end

-- What one pet shows above its head: its base rate with the player's multiplier.
function Income.petRate(speciesId: string, variantId: string, incomeMultiplier: number): number
	return Income.petBase(speciesId, variantId) * incomeMultiplier
end

export type PlacedPet = { species: string, variant: string }

function Income.farmRate(placed: { PlacedPet }, incomeMultiplier: number): number
	local sum = 0
	for _, pet in placed do
		sum += Income.petBase(pet.species, pet.variant)
	end
	return sum * incomeMultiplier
end

-- One second of income. `u` decides the critical roll (u < critChance).
function Income.tick(rate: number, critChance: number, critMultiplier: number, u: number): (number, boolean)
	if u < critChance then
		return rate * critMultiplier, true
	end
	return rate, false
end

-- Long-run average including crits, used for offline earnings and the sim.
function Income.expectedRate(rate: number, critChance: number, critMultiplier: number): number
	return rate * (1 + critChance * (critMultiplier - 1))
end

return Income
