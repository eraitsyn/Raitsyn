--[[
	DataSchema: the saved player data shape and its load-time cleanup.

	No Roblox dependencies, so it is unit tested outside Studio.
]]

export type PlayerData = {
	Version: number,
	Cash: number,
	StoredCash: number,
	Purchased: { [string]: boolean },
	Rebirths: number,
}

local DataSchema = {}

DataSchema.Version = 1

DataSchema.Template = {
	Version = 1,
	Cash = 0,
	StoredCash = 0,
	Purchased = {},
	Rebirths = 0,
} :: PlayerData

local function wholeNumber(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Fixes a loaded profile in place: whole, in-range numbers and only known button ids.
function DataSchema.Sanitize(data: PlayerData, knownButtons: { [string]: any }, maxCash: number)
	data.Version = DataSchema.Version
	data.Cash = wholeNumber(data.Cash, maxCash)
	data.StoredCash = wholeNumber(data.StoredCash, maxCash)
	data.Rebirths = wholeNumber(data.Rebirths, maxCash)

	local purchased = {}
	if type(data.Purchased) == "table" then
		for id, owned in data.Purchased do
			if owned == true and knownButtons[id] ~= nil then
				purchased[id] = true
			end
		end
	end
	data.Purchased = purchased
end

return DataSchema
