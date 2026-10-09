local DataSchema = require("../src/server/DataSchema")
local T = require("./TestKit")

local KNOWN = { Dropper1 = {}, Conveyor1 = {} }
local MAX = 2 ^ 53

return {
	["clamps and floors numbers"] = function()
		local data: any = { Cash = -5, StoredCash = 12.9, Rebirths = 0 / 0, Purchased = {} }
		DataSchema.Sanitize(data, KNOWN, MAX)
		T.equal(data.Cash, 0)
		T.equal(data.StoredCash, 12)
		T.equal(data.Rebirths, 0)
		T.equal(data.Version, DataSchema.Version)
	end,
	["caps cash at the maximum"] = function()
		local data: any = { Cash = math.huge, StoredCash = 0, Rebirths = 0, Purchased = {} }
		DataSchema.Sanitize(data, KNOWN, MAX)
		T.equal(data.Cash, MAX)
	end,
	["drops unknown and non-true purchases"] = function()
		local data: any = {
			Cash = 0,
			StoredCash = 0,
			Rebirths = 0,
			Purchased = { Dropper1 = true, Removed = true, Conveyor1 = "yes" },
		}
		DataSchema.Sanitize(data, KNOWN, MAX)
		T.equal(data.Purchased.Dropper1, true)
		T.equal(data.Purchased.Removed, nil)
		T.equal(data.Purchased.Conveyor1, nil)
	end,
	["replaces a corrupt Purchased value"] = function()
		local data: any = { Cash = 0, StoredCash = 0, Rebirths = 0, Purchased = "broken" }
		DataSchema.Sanitize(data, KNOWN, MAX)
		T.equal(type(data.Purchased), "table")
	end,
}
