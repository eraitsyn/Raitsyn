--!strict
-- Roll odds. The server uses these functions to decide results and the client
-- uses the same functions to display them, so the odds shown are the odds used.
--
-- Luck scales each rarity's base weight by luck ^ luckExponent, then all
-- weights are renormalised. Common has exponent 0, so luck never makes it more
-- likely. The Secret weight gets an extra multiplier from Secret Luck.
-- Pickers take a uniform number in [0, 1) instead of an RNG object so they are
-- deterministic and testable.

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Pets = require(Config.Pets)

export type Chance = {
	rarity: string,
	chance: number, -- 0..1
}

local Odds = {}

-- Total luck for one roll: tier luck x player luck x lucky-roll bonus.
function Odds.rollLuck(tierLuck: number, playerLuck: number, luckyRollMultiplier: number?): number
	return math.max(1, tierLuck * playerLuck * (luckyRollMultiplier or 1))
end

function Odds.chances(luck: number, secretWeightMultiplier: number?): { Chance }
	local secretMultiplier = secretWeightMultiplier or 1
	local weights = table.create(#Rarities.list)
	local total = 0
	for index, rarity in Rarities.list do
		local weight = rarity.weight * luck ^ rarity.luckExponent
		if rarity.id == Rarities.secretId then
			weight *= secretMultiplier
		end
		weights[index] = weight
		total += weight
	end
	local result: { Chance } = table.create(#Rarities.list)
	for index, rarity in Rarities.list do
		result[index] = { rarity = rarity.id, chance = weights[index] / total }
	end
	return result
end

-- Picks from a chance list with u in [0, 1). Walks from the rarest tier down
-- so floating point leftovers fall to Common, never to a rarer tier.
function Odds.pickRarity(chances: { Chance }, u: number): string
	local acc = 0
	for index = #chances, 1, -1 do
		acc += chances[index].chance
		if u < acc then
			return chances[index].rarity
		end
	end
	return chances[1].rarity
end

function Odds.pickSpecies(rarityId: string, u: number): string
	local pool = Pets.byRarity[rarityId]
	assert(pool ~= nil and #pool > 0, `no species for rarity {rarityId}`)
	local total = 0
	for _, species in pool do
		total += species.weight
	end
	local target = u * total
	local acc = 0
	for _, species in pool do
		acc += species.weight
		if target < acc then
			return species.id
		end
	end
	return pool[#pool].id
end

-- Chance of each special variant after Shiny Luck.
function Odds.variantChances(variantChanceAdd: number): { [string]: number }
	local result = {}
	for _, variant in Pets.variants do
		if variant.id ~= "Normal" then
			result[variant.id] = math.min(1, variant.baseChance * (1 + variantChanceAdd))
		end
	end
	return result
end

-- Rarest variant is checked first so its chance is exactly as published.
function Odds.pickVariant(variantChanceAdd: number, u: number): string
	local chances = Odds.variantChances(variantChanceAdd)
	local acc = 0
	for index = #Pets.variants, 1, -1 do
		local variant = Pets.variants[index]
		if variant.id ~= "Normal" then
			acc += chances[variant.id]
			if u < acc then
				return variant.id
			end
		end
	end
	return "Normal"
end

-- "1 in N" for display; N rounded to a readable integer.
function Odds.oneIn(chance: number): number
	if chance <= 0 then
		return math.huge
	end
	return math.max(1, math.floor(1 / chance + 0.5))
end

return Odds
