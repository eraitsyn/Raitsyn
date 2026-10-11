--!strict
-- Economy simulator. Plays the game second by second using the real config
-- and shared logic modules, so it tests the numbers the game actually uses.
--
-- The simulated player is active and greedy: income is split 50/50 between a
-- rolling budget and an upgrade budget; they roll the best unlocked tier that
-- costs under 90 seconds of income, buy the cheapest open hex level, keep their
-- best pets on the farm, and rebirth as soon as they can afford it.
-- It ignores hatch time, offline earnings and daily rewards.
--
-- Usage (from the repo root):
--   lune run tools/sim/economy              -- report, 30 seeds, 4 rebirth cycles
--   lune run tools/sim/economy -- --check   -- CI gate: first rebirth median in range

local process = require("@lune/process")
local Game = require("../../tests/lib/Game")
local Rng = require("../../tests/lib/Rng")

local Stats = Game.get("ReplicatedStorage.Shared.Logic.Stats")
local Odds = Game.get("ReplicatedStorage.Shared.Logic.Odds")
local Costs = Game.get("ReplicatedStorage.Shared.Logic.Costs")
local Income = Game.get("ReplicatedStorage.Shared.Logic.Income")
local HexGraph = Game.get("ReplicatedStorage.Shared.Logic.HexGraph")
local Rules = Game.get("ReplicatedStorage.Shared.Logic.Rules")
local HexTree = Game.get("ReplicatedStorage.Shared.Config.HexTree")
local RollTiers = Game.get("ReplicatedStorage.Shared.Config.RollTiers")
local Economy = Game.get("ReplicatedStorage.Shared.Config.Economy")

type Player = {
	progress: any,
	coins: number,
	lifetime: number,
	pets: { number }, -- base incomes, best first
	found: { [string]: boolean },
	rollCount: number,
}

local MAX_KEPT_PETS = 60

local function newPlayer(): Player
	return {
		progress = { hex = {}, keystones = {}, rebirths = 0, speciesFound = 0 },
		coins = Economy.startingCoins,
		lifetime = 0,
		pets = { Income.petBase("BarnChick", "Normal") }, -- the starter egg
		found = {},
		rollCount = 0,
	}
end

local function farmRate(p: Player, stats): number
	local sum = 0
	for i = 1, math.min(stats.padSlots, #p.pets) do
		sum += p.pets[i]
	end
	return Income.expectedRate(sum * stats.incomeMultiplier, stats.critChance, stats.critMultiplier)
end

local function addPet(p: Player, base: number)
	-- insert keeping descending order
	local i = #p.pets + 1
	while i > 1 and p.pets[i - 1] < base do
		i -= 1
	end
	table.insert(p.pets, i, base)
	if #p.pets > MAX_KEPT_PETS then
		table.remove(p.pets)
	end
end

-- Stats the simulator can feel. Tiles that only change storage, hatching,
-- offline pay or automation are "comfort" buys: the player takes them when they
-- cost under two minutes of income, like a real player would.
local SIM_STATS = {
	petIncomeAdd = true,
	globalMultiplier = true,
	critChance = true,
	critMultiplier = true,
	luckAdd = true,
	luckMultiplier = true,
	padSlots = true,
	rollCooldownReduction = true,
	eggDiscount = true,
	luckyRollMultiplier = true,
	collectorBonusPerSpecies = true,
	secretLuckAdd = true,
	variantChanceAdd = true,
}

local function isComfort(tileId: string): boolean
	for _, effect in HexTree.byId[tileId].effects do
		if SIM_STATS[effect.stat] then
			return false
		end
	end
	return true
end

-- Cheapest open level; comfort tiles only when cheap relative to income.
-- Comfort tiles still count for adjacency, so they are bought eventually.
local function cheapestUpgrade(p: Player, rate: number?): (string?, number)
	local bestId, bestCost = nil, math.huge
	for _, tile in HexTree.tiles do
		if HexGraph.canUpgrade(p.progress, tile.id) then
			local cost = Costs.tileCost(tile.id, Stats.levelOf(p.progress, tile.id) + 1)
			if isComfort(tile.id) and cost > (rate or 0) * 120 then
				cost *= 20 -- deprioritise, but never strand the frontier
			end
			if cost < bestCost then
				bestId, bestCost = tile.id, cost
			end
		end
	end
	if bestId then
		bestCost = Costs.tileCost(bestId, Stats.levelOf(p.progress, bestId) + 1)
	end
	return bestId, bestCost
end

local function ringComplete(p: Player, ring: number): boolean
	for _, tile in HexTree.tiles do
		if HexGraph.ring(tile) == ring and Stats.levelOf(p.progress, tile.id) < tile.maxLevel then
			return false
		end
	end
	return true
end

-- Plays one rebirth cycle; returns milestone times in seconds.
local function playCycle(p: Player, rng: () -> number, maxSeconds: number): { [string]: number }
	local marks: { [string]: number } = {}
	local stats = Stats.compute(p.progress)
	local rollBudget, upgradeBudget = 0, 0
	local cooldown = 0
	local nextId, nextCost = cheapestUpgrade(p, farmRate(p, stats))
	local lastPick = 0
	local rebirthCost = Costs.rebirthCost(p.progress.rebirths)

	for t = 0, maxSeconds do
		local rate = farmRate(p, stats)
		p.coins += rate
		p.lifetime += rate
		rollBudget += rate * 0.5
		upgradeBudget += rate * 0.5

		if p.coins >= rebirthCost then
			marks.rebirth = t
			return marks
		end

		-- Upgrades (re-pick every 30 s: what counts as cheap moves with income)
		if t - lastPick >= 30 then
			nextId, nextCost = cheapestUpgrade(p, rate)
			lastPick = t
		end
		while nextId and nextCost <= upgradeBudget and nextCost <= p.coins do
			upgradeBudget -= nextCost
			p.coins -= nextCost
			local tile = HexTree.byId[nextId]
			if tile.keystone then
				p.progress.keystones[nextId] = true
			else
				p.progress.hex[nextId] = (p.progress.hex[nextId] or 0) + 1
			end
			stats = Stats.compute(p.progress)
			nextId, nextCost = cheapestUpgrade(p, farmRate(p, stats))
			for ring = 1, 3 do
				if marks[`ring{ring}`] == nil and ringComplete(p, ring) then
					marks[`ring{ring}`] = t
				end
			end
		end

		-- Rolling
		cooldown -= 1
		while cooldown <= 0 do
			local tier = RollTiers.list[1]
			for _, candidate in RollTiers.list do
				if Rules.tierUnlocked(candidate.id, p.lifetime, p.progress.rebirths) then
					if marks[candidate.id] == nil then
						marks[candidate.id] = t
					end
					if Costs.rollPrice(candidate.id, stats.eggDiscount) <= math.max(rate * 90, 60) then
						tier = candidate
					end
				end
			end
			local price = Costs.rollPrice(tier.id, stats.eggDiscount)
			if price > rollBudget or price > p.coins then
				break
			end
			rollBudget -= price
			p.coins -= price
			p.rollCount += 1
			local lucky = if p.rollCount % Economy.luckyRollEvery == 0 then stats.luckyRollMultiplier else 1
			local luck = Odds.rollLuck(tier.luck, stats.luck, lucky)
			local rarity = Odds.pickRarity(Odds.chances(luck, stats.secretWeightMultiplier), rng())
			local species = Odds.pickSpecies(rarity, rng())
			local variant = Odds.pickVariant(stats.variantChanceAdd, rng())
			addPet(p, Income.petBase(species, variant))
			if marks[`first{rarity}`] == nil then
				marks[`first{rarity}`] = t
			end
			if not p.found[species] then
				p.found[species] = true
				p.progress.speciesFound += 1
				stats = Stats.compute(p.progress)
			end
			cooldown += stats.rollCooldown
		end
	end
	return marks
end

local function rebirth(p: Player)
	p.coins = Economy.startingCoins
	p.progress.rebirths += 1
	p.progress.hex = {}
end

local function percentile(values: { number }, q: number): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.floor(q * (#sorted - 1) + 1.5), 1, #sorted)]
end

local args = process.args
local check = table.find(args, "--check") ~= nil
local seeds = if check then 20 else 30
local cycles = if check then 1 else 4
local MAX = 8 * 3600

local results: { { [string]: { number } } } = {}
local counts: { { [string]: number } } = {}
for cycle = 1, cycles do
	results[cycle] = {}
	counts[cycle] = {}
end

for seed = 1, seeds do
	local p = newPlayer()
	local rng = Rng.new(seed * 7919)
	for cycle = 1, cycles do
		local marks = playCycle(p, rng, MAX)
		for key, seconds in marks do
			results[cycle][key] = results[cycle][key] or {}
			table.insert(results[cycle][key], seconds / 60)
			counts[cycle][key] = (counts[cycle][key] or 0) + 1
		end
		if marks.rebirth == nil then
			break
		end
		rebirth(p)
	end
end

local order = {
	"firstUncommon",
	"firstRare",
	"firstEpic",
	"firstLegendary",
	"Silver",
	"ring1",
	"firstMythic",
	"Gold",
	"ring2",
	"Diamond",
	"firstSecret",
	"Cosmic",
	"ring3",
	"rebirth",
}
for cycle = 1, cycles do
	print(`\nCycle {cycle} (rebirth {cycle - 1} -> {cycle}), minutes, {seeds} seeds`)
	print(string.format("  %-16s %8s %8s %8s %8s", "milestone", "p10", "median", "p90", "reached"))
	for _, key in order do
		local values = results[cycle][key]
		if values and #values > 0 then
			local reached = `{#values}/{seeds}`
			if #values >= seeds / 2 then
				print(
					string.format(
						"  %-16s %8.1f %8.1f %8.1f %8s",
						key,
						percentile(values, 0.1),
						percentile(values, 0.5),
						percentile(values, 0.9),
						reached
					)
				)
			else
				print(string.format("  %-16s %8s %8s %8s %8s", key, "-", "-", "-", reached))
			end
		end
	end
end

if check then
	local values = results[1].rebirth or {}
	if #values < seeds then
		print(`\nCHECK FAILED: only {#values}/{seeds} runs reached the first rebirth within {MAX / 3600} h`)
		process.exit(1)
	end
	local median = percentile(values, 0.5)
	if median < 60 or median > 120 then
		print(string.format("\nCHECK FAILED: first rebirth median %.1f min is outside 60-120 min", median))
		process.exit(1)
	end
	print(string.format("\nCHECK OK: first rebirth median %.1f min", median))
end
