--!strict
-- Every price in the game, computed from config and the player's stats.
-- Prices are whole coins.

local Config = script.Parent.Parent.Config
local Economy = require(Config.Economy)
local HexTree = require(Config.HexTree)
local Rarities = require(Config.Rarities)
local RollTiers = require(Config.RollTiers)

local Costs = {}

local function whole(n: number): number
	return math.floor(n + 0.5)
end

function Costs.rollPrice(tierId: string, eggDiscount: number): number
	local tier = RollTiers.byId[tierId]
	assert(tier ~= nil, `unknown roll tier {tierId}`)
	local discount = math.clamp(eggDiscount, 0, Economy.maxEggDiscount)
	return math.max(1, whole(tier.price * (1 - discount)))
end

-- Price of buying `level` (1-based) of a tile.
function Costs.tileCost(tileId: string, level: number): number
	local tile = HexTree.byId[tileId]
	assert(tile ~= nil, `unknown tile {tileId}`)
	assert(level >= 1 and level <= tile.maxLevel, `level {level} out of range for {tileId}`)
	return whole(tile.baseCost * tile.growth ^ (level - 1))
end

function Costs.rebirthCost(rebirths: number): number
	return whole(Economy.rebirth.baseCost * Economy.rebirth.costGrowth ^ rebirths)
end

function Costs.releaseRefund(rarityId: string): number
	local rarity = Rarities.byId[rarityId]
	if rarity == nil then
		return 0
	end
	return rarity.releaseRefund
end

return Costs
