--!strict
-- Turns a player's progress (hex levels, keystones, rebirths, Index count)
-- into one flat block of numbers every other system reads. The server and the
-- client both use this, so the UI always shows the values the server applies.

local Config = script.Parent.Parent.Config
local Economy = require(Config.Economy)
local HexTree = require(Config.HexTree)

export type Progress = {
	hex: { [string]: number },
	keystones: { [string]: boolean },
	rebirths: number,
	speciesFound: number,
}

export type Stats = {
	-- income
	petIncomeAdd: number,
	collectorBonusPerSpecies: number,
	globalMultiplier: number,
	rebirthIncomeMultiplier: number,
	incomeMultiplier: number, -- everything above combined
	critChance: number,
	critMultiplier: number,
	-- luck
	luckAdd: number,
	luckMultiplier: number,
	rebirthLuckMultiplier: number,
	luck: number, -- player luck before the roll tier and lucky-roll bonus
	secretLuckAdd: number,
	secretLuckMultiplier: number,
	secretWeightMultiplier: number,
	luckyRollMultiplier: number, -- 1 until Lucky Tenth is owned
	variantChanceAdd: number,
	-- rolling and hatching
	rollCooldownReduction: number,
	rollCooldownFloor: number,
	rollCooldown: number,
	eggDiscount: number,
	hatchTimeReduction: number,
	hatchTimeMultiplier: number,
	hatchTimeFactor: number, -- multiply a rarity's hatch seconds by this
	incubators: number,
	autoRoll: number,
	autoHatch: number,
	-- storage and farm
	padSlots: number,
	petCapacity: number,
	eggCapacity: number,
	-- offline
	offlineRate: number,
	offlineCapHours: number,
}

local Stats = {}

-- Level of a tile in this progress. Keystones live in their own set because
-- they survive rebirth; the core is always owned.
function Stats.levelOf(progress: Progress, tileId: string): number
	if tileId == HexTree.coreId then
		return 1
	end
	local tile = HexTree.byId[tileId]
	if tile == nil then
		return 0
	end
	if tile.keystone then
		return if progress.keystones[tileId] then 1 else 0
	end
	local level = progress.hex[tileId]
	if type(level) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(level), 0, tile.maxLevel)
end

function Stats.compute(progress: Progress): Stats
	local s: { [string]: number } = {
		petIncomeAdd = 0,
		collectorBonusPerSpecies = 0,
		globalMultiplier = 1,
		critChance = 0,
		critMultiplier = Economy.critMultiplier,
		luckAdd = 0,
		luckMultiplier = 1,
		secretLuckAdd = 0,
		secretLuckMultiplier = 1,
		luckyRollMultiplier = 1,
		variantChanceAdd = 0,
		rollCooldownReduction = 0,
		rollCooldownFloor = Economy.rollCooldownFloor,
		eggDiscount = 0,
		hatchTimeReduction = 0,
		hatchTimeMultiplier = 1,
		incubators = Economy.baseIncubators,
		autoRoll = 0,
		autoHatch = 0,
		padSlots = Economy.basePadSlots,
		petCapacity = Economy.basePetCapacity,
		eggCapacity = Economy.baseEggCapacity,
		offlineRate = 0,
		offlineCapHours = Economy.offlineBaseCapHours,
	}

	for _, tile in HexTree.tiles do
		local level = Stats.levelOf(progress, tile.id)
		if level > 0 then
			for _, effect in tile.effects do
				local current = s[effect.stat]
				assert(current ~= nil, `tile {tile.id} modifies unknown stat {effect.stat}`)
				if effect.mode == "add" then
					s[effect.stat] = current + effect.value * level
				elseif effect.mode == "mul" then
					s[effect.stat] = current * effect.value ^ level
				else -- "set": the strongest owned value wins (e.g. Lucky Tenth II over I)
					if effect.stat == "rollCooldownFloor" then
						s[effect.stat] = math.min(current, effect.value)
					else
						s[effect.stat] = math.max(current, effect.value)
					end
				end
			end
		end
	end

	local rebirths = math.max(0, progress.rebirths)
	local rebirthIncome = 1 + Economy.rebirth.incomePerRebirth * rebirths
	local rebirthLuck = 1 + Economy.rebirth.luckPerRebirth * rebirths
	local collector = s.collectorBonusPerSpecies * math.max(0, progress.speciesFound)

	local result: Stats = {
		petIncomeAdd = s.petIncomeAdd,
		collectorBonusPerSpecies = s.collectorBonusPerSpecies,
		globalMultiplier = s.globalMultiplier,
		rebirthIncomeMultiplier = rebirthIncome,
		incomeMultiplier = (1 + s.petIncomeAdd + collector) * s.globalMultiplier * rebirthIncome,
		critChance = math.min(s.critChance, Economy.maxCritChance),
		critMultiplier = s.critMultiplier,
		luckAdd = s.luckAdd,
		luckMultiplier = s.luckMultiplier,
		rebirthLuckMultiplier = rebirthLuck,
		luck = (1 + s.luckAdd) * s.luckMultiplier * rebirthLuck,
		secretLuckAdd = s.secretLuckAdd,
		secretLuckMultiplier = s.secretLuckMultiplier,
		secretWeightMultiplier = (1 + s.secretLuckAdd) * s.secretLuckMultiplier,
		luckyRollMultiplier = s.luckyRollMultiplier,
		variantChanceAdd = s.variantChanceAdd,
		rollCooldownReduction = s.rollCooldownReduction,
		rollCooldownFloor = s.rollCooldownFloor,
		rollCooldown = math.max(s.rollCooldownFloor, Economy.rollCooldown - s.rollCooldownReduction),
		eggDiscount = math.min(s.eggDiscount, Economy.maxEggDiscount),
		hatchTimeReduction = s.hatchTimeReduction,
		hatchTimeMultiplier = s.hatchTimeMultiplier,
		hatchTimeFactor = math.max(0.05, 1 - s.hatchTimeReduction) * s.hatchTimeMultiplier,
		incubators = s.incubators,
		autoRoll = s.autoRoll,
		autoHatch = s.autoHatch,
		padSlots = math.min(s.padSlots, Economy.maxPadSlots),
		petCapacity = s.petCapacity,
		eggCapacity = s.eggCapacity,
		offlineRate = s.offlineRate,
		offlineCapHours = s.offlineCapHours,
	}
	return result
end

return Stats
