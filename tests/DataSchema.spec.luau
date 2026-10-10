local DataSchema = require("../src/server/DataSchema")
local T = require("./TestKit")

local LIMITS = {
	pets = { Puppy = {}, Unicorn = {} },
	eggs = { Basic = {} },
	pedestals = 8,
	incubators = 4,
	maxLuckLevel = 20,
	maxCash = 2 ^ 53,
}

local function sanitize(data: any)
	DataSchema.Sanitize(data, LIMITS)
	return data
end

return {
	["clamps and floors numbers"] = function()
		local data = sanitize({ Cash = -5, LuckLevel = 99.7 })
		T.equal(data.Cash, 0)
		T.equal(data.LuckLevel, 20)
		T.equal(data.Version, DataSchema.Version)
	end,
	["rejects NaN and caps cash"] = function()
		local data = sanitize({ Cash = math.huge, LuckLevel = 0 / 0 })
		T.equal(data.Cash, LIMITS.maxCash)
		T.equal(data.LuckLevel, 0)
	end,
	["keeps only known pets on valid pedestals, and their cash"] = function()
		local data = sanitize({
			Pedestals = { ["1"] = "Puppy", ["2"] = "Removed", ["9"] = "Puppy", [3] = "Puppy", ["8"] = "Unicorn" },
			PedestalCash = { ["1"] = 12.5, ["2"] = 50, ["8"] = -3 },
		})
		T.equal(data.Pedestals["1"], "Puppy")
		T.equal(data.Pedestals["2"], nil)
		T.equal(data.Pedestals["9"], nil)
		T.equal(data.Pedestals[3], nil)
		T.equal(data.Pedestals["8"], "Unicorn")
		T.equal(data.PedestalCash["1"], 12)
		T.equal(data.PedestalCash["2"], nil) -- no pet there any more
		T.equal(data.PedestalCash["8"], nil)
	end,
	["keeps only valid incubations"] = function()
		local data = sanitize({
			Incubators = {
				["1"] = { egg = "Basic", readyAt = 1000.9 },
				["2"] = { egg = "Unknown", readyAt = 1 },
				["3"] = { egg = "Basic", readyAt = "soon" },
				["4"] = { egg = "Basic", readyAt = 0 / 0 },
				["5"] = { egg = "Basic", readyAt = 1 },
			},
		})
		T.equal(data.Incubators["1"].readyAt, 1000)
		T.equal(data.Incubators["2"], nil)
		T.equal(data.Incubators["3"], nil)
		T.equal(data.Incubators["4"], nil)
		T.equal(data.Incubators["5"], nil)
	end,
	["replaces corrupt tables and drops retired fields"] = function()
		local data = sanitize({ Pedestals = "broken", Incubators = 5, Slots = {}, StoredCash = 3, Purchased = {} })
		T.equal(type(data.Pedestals), "table")
		T.equal(type(data.Incubators), "table")
		T.equal(data.Slots, nil)
		T.equal(data.StoredCash, nil)
		T.equal(data.Purchased, nil)
	end,
	["FreeKey returns the lowest empty key, or nil when full"] = function()
		T.equal(DataSchema.FreeKey({ ["1"] = "x", ["3"] = "x" }, 3), "2")
		T.equal(DataSchema.FreeKey({ ["1"] = "x", ["2"] = "x" }, 2), nil)
	end,
}
