--[[
	Rolls: weighted random picks for the conveyor.

	The random source is passed in (a function returning a number in [0, 1)), so
	the server can use Random.new() and tests can use fixed sequences.
	No Roblox dependencies.
]]

export type Rarity = { name: string, weight: number }
export type God = { rarity: string }

local Rolls = {}

-- Picks a rarity name by weight.
function Rolls.PickRarity(rarities: { Rarity }, random: () -> number): string
	local total = 0
	for _, rarity in rarities do
		total += rarity.weight
	end
	local roll = random() * total
	for _, rarity in rarities do
		roll -= rarity.weight
		if roll < 0 then
			return rarity.name
		end
	end
	return rarities[#rarities].name
end

-- Sorted god ids per rarity name, so picks are the same on every server.
function Rolls.GroupByRarity(gods: { [string]: God }): { [string]: { string } }
	local groups: { [string]: { string } } = {}
	for id, god in gods do
		groups[god.rarity] = groups[god.rarity] or {}
		table.insert(groups[god.rarity], id)
	end
	for _, ids in groups do
		table.sort(ids)
	end
	return groups
end

-- Rolls a rarity, then picks a god of that rarity uniformly.
-- Rarities with no gods are skipped by rerolling against only the filled ones.
function Rolls.RollGod(rarities: { Rarity }, groups: { [string]: { string } }, random: () -> number): string
	local filled = {}
	for _, rarity in rarities do
		if groups[rarity.name] and #groups[rarity.name] > 0 then
			table.insert(filled, rarity)
		end
	end
	assert(#filled > 0, "no gods to roll")
	local ids = groups[Rolls.PickRarity(filled, random)]
	local index = math.clamp(math.floor(random() * #ids) + 1, 1, #ids)
	return ids[index]
end

return Rolls
