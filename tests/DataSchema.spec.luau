local DataSchema = require("../src/server/DataSchema")
local T = require("./TestKit")

local LIMITS = {
	pets = { Chick = {}, Cow = {} },
	eggs = { FarmStandard = {}, FarmRoyal = {} },
	mutations = { Golden = {} },
	upgrades = { HatchSlots = 6, Luck = 20 },
	biomes = 11,
	maxCash = 2 ^ 53,
	maxPets = 3,
	maxEggs = 10,
	hatchSlots = 8,
	equipSlots = 2,
}

local function sanitize(data: any)
	data.Version = data.Version or DataSchema.Version
	DataSchema.Sanitize(data, LIMITS)
	return data
end

return {
	["old prototype saves start over"] = function()
		local data = { Version = 4, Cash = 999, Pedestals = { ["1"] = "Fox" } }
		DataSchema.Sanitize(data, LIMITS)
		T.equal(data.Version, DataSchema.Version)
		T.equal(data.Cash, DataSchema.Template.Cash)
		T.equal(data.Pedestals, nil)
		T.equal(data.Unlocked, 1)
		T.truthy(data.Pets ~= DataSchema.Template.Pets, "template tables are copied")
	end,
	["clamps numbers"] = function()
		local data = sanitize({ Cash = -5, Unlocked = 99.7, Collector = 0 / 0, LastSeen = "x" })
		T.equal(data.Cash, 0)
		T.equal(data.Unlocked, 11)
		T.equal(data.Collector, 0)
		T.equal(data.LastSeen, 0)
		T.equal(sanitize({ Unlocked = 0 }).Unlocked, 1)
	end,
	["keeps known upgrades within their max level"] = function()
		local data = sanitize({ Upgrades = { HatchSlots = 9, Luck = 2.5, Fake = 3, Zero = 0 } })
		T.equal(data.Upgrades.HatchSlots, 6)
		T.equal(data.Upgrades.Luck, 2)
		T.equal(data.Upgrades.Fake, nil)
	end,
	["keeps known eggs and caps the total"] = function()
		local data = sanitize({ Eggs = { FarmStandard = 8, FarmRoyal = 8, Fake = 2, Bad = -1 } })
		local total = (data.Eggs.FarmStandard or 0) + (data.Eggs.FarmRoyal or 0)
		T.equal(total, 10)
		T.equal(data.Eggs.Fake, nil)
	end,
	["keeps valid pets, their mutations, and moves NextPetId past them"] = function()
		local data = sanitize({
			Pets = {
				["1"] = { pet = "Chick", mutation = "Golden" },
				["7"] = { pet = "Cow", mutation = "Fake" },
				["x"] = { pet = "Chick" },
				["2"] = { pet = "Removed" },
				["3"] = "broken",
			},
			NextPetId = 2,
		})
		T.equal(data.Pets["1"].mutation, "Golden")
		T.equal(data.Pets["7"].pet, "Cow")
		T.equal(data.Pets["7"].mutation, nil)
		T.equal(data.Pets["x"], nil)
		T.equal(data.Pets["2"], nil)
		T.equal(data.Pets["3"], nil)
		T.equal(data.NextPetId, 8)
	end,
	["caps the pet inventory"] = function()
		local pets = {}
		for index = 1, 5 do
			pets[tostring(index)] = { pet = "Chick" }
		end
		T.equal(DataSchema.Count(sanitize({ Pets = pets }).Pets), 3)
	end,
	["equipped only holds owned pets, up to the equip limit"] = function()
		local data = sanitize({
			Pets = { ["1"] = { pet = "Chick" }, ["2"] = { pet = "Cow" }, ["3"] = { pet = "Cow" } },
			Equipped = { ["1"] = true, ["2"] = true, ["3"] = true, ["9"] = true },
		})
		T.equal(DataSchema.Count(data.Equipped), 2)
		T.equal(data.Equipped["9"], nil)
	end,
	["keeps only valid hatching eggs"] = function()
		local data = sanitize({
			Hatching = {
				["1"] = { egg = "FarmStandard", readyAt = 1000.9 },
				["2"] = { egg = "Unknown", readyAt = 1 },
				["3"] = { egg = "FarmStandard", readyAt = "soon" },
				["9"] = { egg = "FarmStandard", readyAt = 1 },
			},
		})
		T.equal(data.Hatching["1"].readyAt, 1000)
		T.equal(data.Hatching["2"], nil)
		T.equal(data.Hatching["3"], nil)
		T.equal(data.Hatching["9"], nil)
	end,
	["replaces corrupt tables"] = function()
		local data =
			sanitize({ Pets = "broken", Eggs = 5, Hatching = true, Discovered = { Chick = true, Nope = true } })
		T.equal(type(data.Pets), "table")
		T.equal(type(data.Eggs), "table")
		T.equal(type(data.Hatching), "table")
		T.equal(data.Discovered.Chick, true)
		T.equal(data.Discovered.Nope, nil)
	end,
	["FreeKey returns the lowest empty key, or nil when full"] = function()
		T.equal(DataSchema.FreeKey({ ["1"] = "x", ["3"] = "x" }, 3), "2")
		T.equal(DataSchema.FreeKey({ ["1"] = "x", ["2"] = "x" }, 2), nil)
	end,
}
