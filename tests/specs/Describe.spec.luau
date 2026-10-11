local Test = require("../lib/Test")
local Game = require("../lib/Game")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Describe = Game.get("ReplicatedStorage.Shared.Logic.Describe")
local HexTree = Game.get("ReplicatedStorage.Shared.Config.HexTree")

describe("Describe: upgrade text", function()
	it("has a label for every stat any tile changes", function()
		for _, tile in HexTree.tiles do
			for _, effect in tile.effects do
				expect(Describe.known(effect.stat)).toBeTruthy()
			end
		end
	end)

	it("describes every tile at every level, with no next value when maxed", function()
		for _, tile in HexTree.tiles do
			for level = 0, tile.maxLevel do
				for _, line in Describe.tile(tile.id, level) do
					expect(#line.label > 0 and #line.now > 0).toBeTruthy()
					expect(line.next == nil).toBe(level >= tile.maxLevel)
				end
			end
		end
	end)

	it("formats the common kinds of effect", function()
		expect(Describe.tile("PetIncome1", 2)[1].now).toBe("+20%")
		expect(Describe.tile("PetIncome1", 2)[1].next).toBe("+30%")
		expect(Describe.tile("RollingSpeed1", 1)[1].now).toBe("-0.15s")
		expect(Describe.tile("EggDiscount1", 3)[1].now).toBe("-9%")
		expect(Describe.tile("FarmCapacity1", 0)[1].next).toBe("+1")
		expect(Describe.tile("AutoRoll", 0)[1].now).toBe("Off")
		expect(Describe.tile("PetIncome1", 0)[1].now).toBe("0%")
		expect(Describe.tile("FarmCapacity1", 0)[1].now).toBe("+0")
		expect(Describe.tile("AutoRoll", 0)[1].next).toBe("On")
		expect(Describe.tile("GlobalMultiplier1", 2)[1].now).toBe("x1.21")
		expect(Describe.tile("LuckyTenth1", 1)[1].now).toBe("x3")
	end)
end)

return nil
