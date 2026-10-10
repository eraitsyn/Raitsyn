--[[
	DataSchema: the saved player data shape and its load-time cleanup.

	Pedestals, PedestalCash, PedestalMutations and Incubators are keyed by slot number as a string
	("1".."8"). String keys keep each table a dictionary, which DataStores save
	reliably even with gaps.
	No Roblox dependencies, so it is unit tested outside Studio.
]]

export type Incubation = { egg: string, readyAt: number } -- readyAt is os.time() seconds

export type PlayerData = {
	Version: number,
	Cash: number,
	LuckLevel: number,
	Pedestals: { [string]: string }, -- pedestal key -> pet id
	PedestalCash: { [string]: number }, -- pedestal key -> uncollected cash
	PedestalMutations: { [string]: string }, -- pedestal key -> mutation id (absent for normal pets)
	Incubators: { [string]: Incubation }, -- incubator key -> egg waiting to hatch
	LastSeen: number, -- os.time() of the last income tick, for offline earnings (0 = never)
}

export type Limits = {
	pets: { [string]: any },
	eggs: { [string]: any },
	mutations: { [string]: any },
	pedestals: number,
	incubators: number,
	maxLuckLevel: number,
	maxCash: number,
}

local DataSchema = {}

DataSchema.Version = 4

DataSchema.Template = {
	Version = 4,
	Cash = 100,
	LuckLevel = 0,
	Pedestals = {},
	PedestalCash = {},
	PedestalMutations = {},
	Incubators = {},
	LastSeen = 0,
} :: PlayerData

-- Fields from earlier prototypes (dropper tycoon, gods tycoon).
local RETIRED_FIELDS = { "Purchased", "Rebirths", "Slots", "StoredCash" }

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Fixes a loaded profile in place: whole, in-range numbers, only known pets and
-- eggs in valid slots, and no fields left over from older versions.
function DataSchema.Sanitize(data: any, limits: Limits)
	data.Version = DataSchema.Version
	data.Cash = wholeNumber(data.Cash, limits.maxCash)
	data.LuckLevel = wholeNumber(data.LuckLevel, limits.maxLuckLevel)
	data.LastSeen = wholeNumber(data.LastSeen, 2 ^ 40)

	local oldPedestals = if type(data.Pedestals) == "table" then data.Pedestals else {}
	local oldCash = if type(data.PedestalCash) == "table" then data.PedestalCash else {}
	local oldMutations = if type(data.PedestalMutations) == "table" then data.PedestalMutations else {}
	local pedestals, pedestalCash, mutations = {}, {}, {}
	for index = 1, limits.pedestals do
		local key = tostring(index)
		local petId = oldPedestals[key]
		if type(petId) == "string" and limits.pets[petId] ~= nil then
			pedestals[key] = petId
			local cash = wholeNumber(oldCash[key], limits.maxCash)
			if cash > 0 then
				pedestalCash[key] = cash
			end
			local mutation = oldMutations[key]
			if type(mutation) == "string" and limits.mutations[mutation] ~= nil then
				mutations[key] = mutation
			end
		end
	end
	data.Pedestals = pedestals
	data.PedestalCash = pedestalCash
	data.PedestalMutations = mutations

	local oldIncubators = if type(data.Incubators) == "table" then data.Incubators else {}
	local incubators = {}
	for index = 1, limits.incubators do
		local key = tostring(index)
		local incubation = oldIncubators[key]
		if
			type(incubation) == "table"
			and type(incubation.egg) == "string"
			and limits.eggs[incubation.egg] ~= nil
			and type(incubation.readyAt) == "number"
			and incubation.readyAt == incubation.readyAt
		then
			incubators[key] = { egg = incubation.egg, readyAt = math.floor(incubation.readyAt) }
		end
	end
	data.Incubators = incubators

	for _, field in RETIRED_FIELDS do
		data[field] = nil
	end
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

return DataSchema
