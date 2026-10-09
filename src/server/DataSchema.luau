--[[
	DataSchema: the saved player data shape and its load-time cleanup.

	Slots maps a slot number as a string ("1".."8") to a god id. String keys keep
	the table a dictionary, which DataStores save reliably even with gaps.
	No Roblox dependencies, so it is unit tested outside Studio.
]]

export type PlayerData = {
	Version: number,
	Cash: number,
	StoredCash: number,
	Slots: { [string]: string },
}

local DataSchema = {}

DataSchema.Version = 2

DataSchema.Template = {
	Version = 2,
	Cash = 50,
	StoredCash = 0,
	Slots = {},
} :: PlayerData

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Fixes a loaded profile in place: whole, in-range numbers, only known gods in
-- valid slots, and no fields left over from older versions.
function DataSchema.Sanitize(data: any, knownGods: { [string]: any }, slotCount: number, maxCash: number)
	data.Version = DataSchema.Version
	data.Cash = wholeNumber(data.Cash, maxCash)
	data.StoredCash = wholeNumber(data.StoredCash, maxCash)

	local slots = {}
	if type(data.Slots) == "table" then
		for index = 1, slotCount do
			local key = tostring(index)
			local godId = data.Slots[key]
			if type(godId) == "string" and knownGods[godId] ~= nil then
				slots[key] = godId
			end
		end
	end
	data.Slots = slots

	-- Version 1 fields (dropper tycoon).
	data.Purchased = nil
	data.Rebirths = nil
end

-- The lowest empty slot key, or nil when the base is full.
function DataSchema.FreeSlot(data: PlayerData, slotCount: number): string?
	for index = 1, slotCount do
		local key = tostring(index)
		if data.Slots[key] == nil then
			return key
		end
	end
	return nil
end

return DataSchema
