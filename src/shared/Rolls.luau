--[[
	Rolls: weighted random picks for egg hatches, with luck.

	The random source is passed in (a function returning a number in [0, 1)), so
	the server can use Random.new() and tests can use fixed sequences.
	No Roblox dependencies.
]]

export type Entry = { id: string, weight: number }
export type Chance = { id: string, chance: number }
export type Mutation = { id: string, oneIn: number }

local Rolls = {}

-- The egg's entries with luck applied: every pet whose rarity is lucky has its
-- weight multiplied by `luck`. Returns new entries; the config is not changed.
function Rolls.WithLuck(
	entries: { Entry },
	rarityOf: (id: string) -> string,
	luckyRarities: { [string]: boolean },
	luck: number
): { Entry }
	local result = {}
	for _, entry in entries do
		local weight = entry.weight
		if luckyRarities[rarityOf(entry.id)] then
			weight *= luck
		end
		table.insert(result, { id = entry.id, weight = weight })
	end
	return result
end

-- Each entry's chance between 0 and 1, in the same order.
function Rolls.Chances(entries: { Entry }): { Chance }
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local chances = {}
	for _, entry in entries do
		table.insert(chances, { id = entry.id, chance = if total > 0 then entry.weight / total else 0 })
	end
	return chances
end

-- Picks one entry id by weight.
function Rolls.Pick(entries: { Entry }, random: () -> number): string
	assert(#entries > 0, "nothing to roll")
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = random() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll < 0 then
			return entry.id
		end
	end
	return entries[#entries].id
end

-- Rolls a mutation: each one has its own 1-in-N chance, checked rarest first
-- with one random number. Returns the mutation id, or nil for a normal pet.
function Rolls.Mutation(mutations: { Mutation }, random: () -> number): string?
	local roll = random()
	local edge = 0
	for _, mutation in mutations do
		edge += 1 / mutation.oneIn
		if roll < edge then
			return mutation.id
		end
	end
	return nil
end

-- "1 in N" text for a chance, rounded so small odds stay readable.
function Rolls.OneIn(chance: number): string
	if chance <= 0 then
		return "never"
	end
	local n = 1 / chance
	if n < 10 then
		return `1 in {math.floor(n * 10 + 0.5) / 10}`
	end
	return `1 in {math.floor(n + 0.5)}`
end

return Rolls
