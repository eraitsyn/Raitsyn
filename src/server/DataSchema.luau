--[[
	DataSchema: the saved player data shape and its load-time cleanup.

	Slot tables (Hatching) are keyed by slot number as a string ("1".."8") and
	pets by their id as a string, so every table is a dictionary, which
	DataStores save reliably even with gaps.
	No Roblox dependencies, so it is unit tested outside Studio.
]]

export type Incubation = { egg: string, readyAt: number } -- readyAt is os.time() seconds
export type OwnedPet = { pet: string, mutation: string? }

export type PlayerData = {
	Version: number,
	Cash: number,
	Unlocked: number, -- how many biomes are unlocked, in order (1 = Farm only)
	Upgrades: { [string]: number }, -- upgrade id -> level
	Eggs: { [string]: number }, -- egg id -> how many are in the egg inventory
	Pets: { [string]: OwnedPet }, -- pet uid -> pet
	NextPetId: number, -- uid for the next hatched pet
	Equipped: { [string]: boolean }, -- pet uid -> true when on a platform
	Hatching: { [string]: Incubation }, -- hatch slot key -> egg in it
	Collector: number, -- income waiting at the Collector
	Discovered: { [string]: boolean }, -- pet id -> hatched at least once
	LastSeen: number, -- os.time() of the last income tick, for offline earnings (0 = never)
}

export type Limits = {
	pets: { [string]: any },
	eggs: { [string]: any },
	mutations: { [string]: any },
	upgrades: { [string]: number }, -- upgrade id -> max level
	biomes: number,
	maxCash: number,
	maxPets: number,
	maxEggs: number,
	hatchSlots: number,
	equipSlots: number,
}

local DataSchema = {}

DataSchema.Version = 5

DataSchema.Template = {
	Version = 5,
	Cash = 150,
	Unlocked = 1,
	Upgrades = {},
	Eggs = {},
	Pets = {},
	NextPetId = 1,
	Equipped = {},
	Hatching = {},
	Collector = 0,
	Discovered = {},
	LastSeen = 0,
} :: PlayerData

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

local function tableOrEmpty(value: any): { [any]: any }
	return if type(value) == "table" then value else {}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Fixes a loaded profile in place: whole, in-range numbers, only known ids, and
-- valid slots. Saves from older prototypes (Version < 5) start over.
function DataSchema.Sanitize(data: any, limits: Limits)
	if data.Version ~= DataSchema.Version then
		table.clear(data)
		for key, value in DataSchema.Template :: any do
			data[key] = deepCopy(value)
		end
	end

	data.Cash = wholeNumber(data.Cash, limits.maxCash)
	data.Collector = wholeNumber(data.Collector, limits.maxCash)
	data.Unlocked = math.max(1, wholeNumber(data.Unlocked, limits.biomes))
	data.LastSeen = wholeNumber(data.LastSeen, 2 ^ 40)

	local upgrades = {}
	for id, level in tableOrEmpty(data.Upgrades) do
		local maxLevel = limits.upgrades[id]
		if type(id) == "string" and maxLevel then
			local whole = wholeNumber(level, maxLevel)
			if whole > 0 then
				upgrades[id] = whole
			end
		end
	end
	data.Upgrades = upgrades

	local eggs, eggTotal = {}, 0
	for id, count in tableOrEmpty(data.Eggs) do
		if type(id) == "string" and limits.eggs[id] then
			local whole = wholeNumber(count, limits.maxEggs - eggTotal)
			if whole > 0 then
				eggs[id] = whole
				eggTotal += whole
			end
		end
	end
	data.Eggs = eggs

	local pets, petCount, highestId = {}, 0, 0
	for uid, owned in tableOrEmpty(data.Pets) do
		local number = tonumber(uid)
		if
			petCount < limits.maxPets
			and type(uid) == "string"
			and number
			and number % 1 == 0
			and number > 0
			and type(owned) == "table"
			and type(owned.pet) == "string"
			and limits.pets[owned.pet]
		then
			local mutation = if type(owned.mutation) == "string" and limits.mutations[owned.mutation]
				then owned.mutation
				else nil
			pets[uid] = { pet = owned.pet, mutation = mutation }
			petCount += 1
			highestId = math.max(highestId, number)
		end
	end
	data.Pets = pets
	data.NextPetId = math.max(highestId + 1, wholeNumber(data.NextPetId, 2 ^ 40))

	local equipped, equippedCount = {}, 0
	for uid, on in tableOrEmpty(data.Equipped) do
		if on == true and pets[uid] and equippedCount < limits.equipSlots then
			equipped[uid] = true
			equippedCount += 1
		end
	end
	data.Equipped = equipped

	local oldHatching = tableOrEmpty(data.Hatching)
	local hatching = {}
	for index = 1, limits.hatchSlots do
		local key = tostring(index)
		local incubation = oldHatching[key]
		if
			type(incubation) == "table"
			and type(incubation.egg) == "string"
			and limits.eggs[incubation.egg]
			and type(incubation.readyAt) == "number"
			and incubation.readyAt == incubation.readyAt
		then
			hatching[key] = { egg = incubation.egg, readyAt = math.floor(incubation.readyAt) }
		end
	end
	data.Hatching = hatching

	local discovered = {}
	for id, seen in tableOrEmpty(data.Discovered) do
		if seen == true and type(id) == "string" and limits.pets[id] then
			discovered[id] = true
		end
	end
	data.Discovered = discovered

	data.Version = DataSchema.Version
end

-- The lowest empty key in a slot table, or nil when every slot is used.
function DataSchema.FreeKey(slots: { [string]: any }, count: number): string?
	for index = 1, count do
		local key = tostring(index)
		if slots[key] == nil then
			return key
		end
	end
	return nil
end

-- How many eggs are in the egg inventory.
function DataSchema.EggCount(data: PlayerData): number
	local total = 0
	for _, count in data.Eggs do
		total += count
	end
	return total
end

-- How many pets are owned / equipped.
function DataSchema.Count(set: { [string]: any }): number
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

return DataSchema
