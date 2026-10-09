local DataSchema = require("../src/server/DataSchema")
local T = require("./TestKit")

local KNOWN = { Zeus = {}, Pan = {} }
local SLOTS = 8
local MAX = 2 ^ 53

local function sanitize(data: any)
	DataSchema.Sanitize(data, KNOWN, SLOTS, MAX)
	return data
end

return {
	["clamps and floors numbers"] = function()
		local data = sanitize({ Cash = -5, StoredCash = 12.9, Slots = {} })
		T.equal(data.Cash, 0)
		T.equal(data.StoredCash, 12)
		T.equal(data.Version, DataSchema.Version)
	end,
	["rejects NaN and caps at the maximum"] = function()
		local data = sanitize({ Cash = math.huge, StoredCash = 0 / 0, Slots = {} })
		T.equal(data.Cash, MAX)
		T.equal(data.StoredCash, 0)
	end,
	["keeps only known gods in valid slots"] = function()
		local data = sanitize({
			Cash = 0,
			StoredCash = 0,
			Slots = { ["1"] = "Zeus", ["2"] = "Removed", ["3"] = 5, ["9"] = "Pan", [4] = "Pan", ["8"] = "Pan" },
		})
		T.equal(data.Slots["1"], "Zeus")
		T.equal(data.Slots["2"], nil)
		T.equal(data.Slots["3"], nil)
		T.equal(data.Slots["9"], nil)
		T.equal(data.Slots[4], nil)
		T.equal(data.Slots["8"], "Pan")
	end,
	["replaces corrupt Slots and drops version 1 fields"] = function()
		local data = sanitize({ Cash = 0, StoredCash = 0, Slots = "broken", Purchased = {}, Rebirths = 3 })
		T.equal(type(data.Slots), "table")
		T.equal(data.Purchased, nil)
		T.equal(data.Rebirths, nil)
	end,
	["FreeSlot returns the lowest empty slot, or nil when full"] = function()
		T.equal(DataSchema.FreeSlot({ Slots = { ["1"] = "Pan", ["3"] = "Pan" } } :: any, 3), "2")
		T.equal(DataSchema.FreeSlot({ Slots = { ["1"] = "Pan", ["2"] = "Pan" } } :: any, 2), nil)
	end,
}
