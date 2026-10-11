local Test = require("../lib/Test")
local Game = require("../lib/Game")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Stats = Game.get("ReplicatedStorage.Shared.Logic.Stats")
local HexGraph = Game.get("ReplicatedStorage.Shared.Logic.HexGraph")
local Costs = Game.get("ReplicatedStorage.Shared.Logic.Costs")
local Odds = Game.get("ReplicatedStorage.Shared.Logic.Odds")
local HexTree = Game.get("ReplicatedStorage.Shared.Config.HexTree")
local RollTiers = Game.get("ReplicatedStorage.Shared.Config.RollTiers")
local Rarities = Game.get("ReplicatedStorage.Shared.Config.Rarities")
local Economy = Game.get("ReplicatedStorage.Shared.Config.Economy")

local function fresh()
	return { hex = {}, keystones = {}, rebirths = 0, speciesFound = 0 }
end

local function maxed(rebirths)
	local p = fresh()
	p.rebirths = rebirths or 10
	p.speciesFound = 26
	for _, t in HexTree.tiles do
		if t.keystone then
			p.keystones[t.id] = true
		elseif t.id ~= HexTree.coreId then
			p.hex[t.id] = t.maxLevel
		end
	end
	return p
end

describe("Stats", function()
	it("starts from the base economy values", function()
		local s = Stats.compute(fresh())
		expect(s.padSlots).toBe(3)
		expect(s.rollCooldown).toBe(2.5)
		expect(s.luck).toBe(1)
		expect(s.incomeMultiplier).toBe(1)
		expect(s.incubators).toBe(1)
		expect(s.offlineRate).toBe(0)
		expect(s.critChance).toBe(0)
		expect(s.luckyRollMultiplier).toBe(1)
		expect(s.autoRoll).toBe(0)
		expect(s.hatchTimeFactor).toBe(1)
	end)

	it("caps everything sensibly when the whole tree is owned", function()
		local s = Stats.compute(maxed(10))
		expect(s.padSlots).toBe(24)
		expect(s.eggDiscount).toBeNear(0.30, 1e-12)
		expect(s.critChance).toBeNear(0.10, 1e-12)
		expect(s.critMultiplier).toBe(6)
		expect(s.luckyRollMultiplier).toBe(5)
		expect(s.rollCooldown).toBeNear(0.75, 1e-12)
		expect(s.incubators).toBe(4)
		expect(s.offlineCapHours).toBeNear(8, 1e-12)
		expect(s.offlineRate).toBeNear(0.50, 1e-12)
		expect(s.petCapacity).toBe(150)
		expect(s.eggCapacity).toBe(100)
		expect(s.hatchTimeFactor).toBeNear(0.25 * 0.75, 1e-12)
		expect(s.secretWeightMultiplier).toBeNear(2.5 * 1.5, 1e-12)
	end)

	it("applies rebirths additively to income and luck", function()
		local p = fresh()
		p.rebirths = 4
		local s = Stats.compute(p)
		expect(s.incomeMultiplier).toBeNear(3, 1e-12)
		expect(s.luck).toBeNear(1.4, 1e-12)
	end)

	it("only counts keystones from the keystone set, and ignores junk levels", function()
		local p = fresh()
		p.hex.Overgrowth = 1 -- keystones in the normal table must not count
		p.hex.PetIncome1 = 99 -- clamped to max level
		p.hex.NotATile = 3
		local s = Stats.compute(p)
		expect(s.globalMultiplier).toBe(1)
		expect(s.petIncomeAdd).toBeNear(0.5, 1e-12)
	end)

	it("adds the Collector's Bonus per discovered species", function()
		local p = fresh()
		p.hex.CollectorsBonus = 1
		p.speciesFound = 10
		expect(Stats.compute(p).incomeMultiplier).toBeNear(1.10, 1e-12)
	end)
end)

describe("HexGraph", function()
	it("opens ring 1 and nothing else at the start", function()
		local p = fresh()
		for _, t in HexTree.tiles do
			local ring = HexGraph.ring(t)
			local ok = HexGraph.canUpgrade(p, t.id)
			expect(ok).toBe(ring == 1)
		end
		expect(HexGraph.state(p, "FarmHeart")).toBe("Maxed")
	end)

	it("opens neighbours once a tile has a level", function()
		local p = fresh()
		expect(HexGraph.canUpgrade(p, "CriticalIncome1")).toBe(false)
		p.hex.PetIncome1 = 1
		expect(HexGraph.canUpgrade(p, "CriticalIncome1")).toBe(true)
		expect(HexGraph.state(p, "PetIncome1")).toBe("Owned")
		expect(HexGraph.state(p, "PetIncome2")).toBe("Available")
	end)

	it("enforces tier order even when a neighbour is owned", function()
		local p = fresh()
		p.hex.EggDiscount1 = 1
		p.hex.OfflineEarnings1 = 1 -- neighbour of Egg Discount II's ring-3 spot
		p.hex.ExtraInventory1 = 1
		-- Egg Discount II needs Egg Discount I: owned, so fine.
		expect(HexGraph.canUpgrade(p, "EggDiscount2")).toBe(true)
		-- Extra Inventory II needs Extra Inventory I: owned.
		expect(HexGraph.canUpgrade(p, "ExtraInventory2")).toBe(true)
		-- Farm Capacity II next to Twin Incubator but without Farm Capacity I.
		local q = fresh()
		q.hex.HatchingSpeed1 = 1
		q.hex.TwinIncubator = 1
		local ok, reason = HexGraph.canUpgrade(q, "FarmCapacity2")
		expect(ok).toBe(false)
		expect(reason).toBe("Requires Farm Capacity I")
	end)

	it("gates milestone tiles and reports them as milestone-locked", function()
		local p = fresh()
		p.hex.RollingLuck1 = 1
		p.hex.RollingLuck2 = 1
		local ok, reason = HexGraph.canUpgrade(p, "SecretLuck")
		expect(ok).toBe(false)
		expect(reason).toBe("Needs Rebirth 1")
		expect(HexGraph.state(p, "SecretLuck")).toBe("MilestoneLocked")
		p.rebirths = 1
		expect(HexGraph.canUpgrade(p, "SecretLuck")).toBe(true)
	end)

	it("does not let an owned keystone open its neighbours after rebirth", function()
		local p = fresh()
		p.rebirths = 3
		p.keystones.HatcheryMaster = true
		expect(HexGraph.canUpgrade(p, "AutoHatch")).toBe(false)
		expect(HexGraph.state(p, "HatcheryMaster")).toBe("Maxed")
	end)

	it("refuses the core, unknown tiles and maxed tiles", function()
		local p = fresh()
		expect(HexGraph.canUpgrade(p, "FarmHeart")).toBe(false)
		expect(HexGraph.canUpgrade(p, "Nope")).toBe(false)
		p.hex.AutoRoll = 1
		p.hex.RollingSpeed1 = 1
		local ok, reason = HexGraph.canUpgrade(p, "AutoRoll")
		expect(ok).toBe(false)
		expect(reason).toBe("Fully upgraded")
	end)

	it("lets every tile be reached by buying outward from the centre", function()
		local p = maxed(10)
		p.hex = {}
		p.keystones = {}
		-- Buy greedily: any tile whose next level is allowed, until nothing changes.
		local changed = true
		while changed do
			changed = false
			for _, t in HexTree.tiles do
				if t.id ~= HexTree.coreId and HexGraph.canUpgrade(p, t.id) then
					if t.keystone then
						p.keystones[t.id] = true
					else
						p.hex[t.id] = (p.hex[t.id] or 0) + 1
					end
					changed = true
				end
			end
		end
		for _, t in HexTree.tiles do
			expect(HexGraph.state(p, t.id)).toBe("Maxed")
		end
	end)
end)

describe("Costs", function()
	it("prices rolls with the discount, capped at 30%", function()
		expect(Costs.rollPrice("Basic", 0)).toBe(50)
		expect(Costs.rollPrice("Basic", 0.15)).toBe(43)
		expect(Costs.rollPrice("Silver", 0.9)).toBe(1050)
	end)

	it("grows tile costs geometrically by level", function()
		expect(Costs.tileCost("PetIncome1", 1)).toBe(300)
		expect(Costs.tileCost("PetIncome1", 2)).toBe(510)
		expect(Costs.tileCost("FarmCapacity1", 3)).toBe(6750)
		expect(function()
			Costs.tileCost("PetIncome1", 6)
		end).toThrow()
	end)

	it("triples the rebirth cost each time", function()
		expect(Costs.rebirthCost(0)).toBe(10_000_000)
		expect(Costs.rebirthCost(1)).toBe(30_000_000)
		expect(Costs.rebirthCost(3)).toBe(270_000_000)
	end)

	it("never lets roll-and-release make money, even at maximum luck and discount", function()
		local s = Stats.compute(maxed(20))
		for _, tier in RollTiers.list do
			local luck = Odds.rollLuck(tier.luck, s.luck, s.luckyRollMultiplier)
			local ev = 0
			for _, c in Odds.chances(luck, s.secretWeightMultiplier) do
				ev += c.chance * Costs.releaseRefund(c.rarity)
			end
			expect(ev).toBeLessThan(Costs.rollPrice(tier.id, s.eggDiscount) * 0.5)
		end
	end)

	it("refunds by rarity and nothing for unknown rarities", function()
		expect(Costs.releaseRefund("Common")).toBe(Rarities.byId.Common.releaseRefund)
		expect(Costs.releaseRefund("Secret")).toBe(Rarities.byId.Secret.releaseRefund)
		expect(Costs.releaseRefund("Bogus")).toBe(0)
	end)
end)

return nil
