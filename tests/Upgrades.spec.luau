local Upgrades = require("../src/shared/Upgrades")
local Economy = require("../src/shared/Config/Economy")
local T = require("./TestKit")

local SLOTS = { id = "Slots", start = 2, perLevel = 1, maxLevel = 2, baseCost = 100, growth = 3 }

return {
	["value grows by perLevel"] = function()
		T.equal(Upgrades.Value(SLOTS, 0), 2)
		T.equal(Upgrades.Value(SLOTS, 2), 4)
	end,
	["cost grows and stops at the max level"] = function()
		T.equal(Upgrades.Cost(SLOTS, 0), 100)
		T.equal(Upgrades.Cost(SLOTS, 1), 300)
		T.equal(Upgrades.Cost(SLOTS, 2), nil)
	end,
	["Find looks up by id"] = function()
		T.equal(Upgrades.Find({ SLOTS }, "Slots"), SLOTS)
		T.equal(Upgrades.Find({ SLOTS }, "Nope"), nil)
	end,
	["shipped upgrades have whole, safe costs and sensible values"] = function()
		local seen = {}
		for _, definition in Economy.Upgrades do
			T.falsy(seen[definition.id], `duplicate upgrade {definition.id}`)
			seen[definition.id] = true
			for level = 0, definition.maxLevel - 1 do
				local cost = Upgrades.Cost(definition, level)
				T.truthy(cost and cost > 0 and cost < Economy.MaxCash, `{definition.id} level {level} cost`)
			end
			T.truthy(Upgrades.Value(definition, definition.maxLevel) >= 0, `{definition.id} max value`)
		end
		T.truthy(Upgrades.Value(Upgrades.Find(Economy.Upgrades, "HatchSpeed") :: any, 10) > 0.2, "hatch speed floor")
	end,
}
