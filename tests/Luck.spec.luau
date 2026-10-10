local Luck = require("../src/shared/Luck")
local Economy = require("../src/shared/Config/Economy")
local T = require("./TestKit")

local CONFIG = { LuckPerLevel = 0.25, LuckBaseCost = 200, LuckCostGrowth = 2.5, MaxLuckLevel = 3 }

return {
	["multiplier grows by LuckPerLevel"] = function()
		T.equal(Luck.Multiplier(CONFIG, 0), 1)
		T.equal(Luck.Multiplier(CONFIG, 2), 1.5)
	end,
	["cost grows and stops at the max level"] = function()
		T.equal(Luck.UpgradeCost(CONFIG, 0), 200)
		T.equal(Luck.UpgradeCost(CONFIG, 1), 500)
		T.equal(Luck.UpgradeCost(CONFIG, 2), 1250)
		T.equal(Luck.UpgradeCost(CONFIG, 3), nil)
	end,
	["text rounds to two places"] = function()
		T.equal(Luck.Text(1), "x1")
		T.equal(Luck.Text(1.25), "x1.25")
		T.equal(Luck.Text(1.3333), "x1.33")
	end,
	["shipped economy stays within whole, safe costs"] = function()
		for level = 0, Economy.MaxLuckLevel - 1 do
			local cost = Luck.UpgradeCost(Economy, level)
			T.truthy(cost and cost > 0 and cost < Economy.MaxCash, `level {level} cost`)
		end
	end,
}
