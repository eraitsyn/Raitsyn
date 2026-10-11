local Test = require("../lib/Test")
local Game = require("../lib/Game")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Rarities = Game.get("ReplicatedStorage.Shared.Config.Rarities")
local Pets = Game.get("ReplicatedStorage.Shared.Config.Pets")
local HexTree = Game.get("ReplicatedStorage.Shared.Config.HexTree")
local RollTiers = Game.get("ReplicatedStorage.Shared.Config.RollTiers")
local Economy = Game.get("ReplicatedStorage.Shared.Config.Economy")
local Daily = Game.get("ReplicatedStorage.Shared.Config.Daily")

describe("Config: rarities and pets", function()
	it("has seven rarities whose base weights sum to 100", function()
		expect(#Rarities.list).toBe(7)
		local total = 0
		for _, r in Rarities.list do
			total += r.weight
		end
		expect(total).toBeNear(100, 1e-9)
	end)

	it("orders rarities from most to least likely, with rising income and hatch time", function()
		for i = 2, #Rarities.list do
			local prev, cur = Rarities.list[i - 1], Rarities.list[i]
			expect(cur.weight).toBeLessThan(prev.weight)
			expect(cur.baseIncome).toBeGreaterThan(prev.baseIncome)
			expect(cur.hatchSeconds).toBeGreaterThan(prev.hatchSeconds)
			expect(cur.order).toBe(i)
		end
	end)

	it("gives every rarity a non-empty pet pool and 26 species in total", function()
		expect(#Pets.list).toBe(26)
		for _, r in Rarities.list do
			local pool = Pets.byRarity[r.id]
			expect(pool ~= nil and #pool > 0).toBeTruthy()
		end
	end)

	it("only references known rarities and archetypes, with at least one colour", function()
		local archetypes =
			{ Bird = true, Small = true, Quadruped = true, Large = true, Fish = true, Insect = true, Dragon = true }
		for _, s in Pets.list do
			expect(Rarities.byId[s.rarity] ~= nil).toBeTruthy()
			expect(archetypes[s.archetype]).toBeTruthy()
			expect(#s.colors >= 1).toBeTruthy()
			expect(s.weight).toBeGreaterThan(0)
		end
	end)

	it("defines variants Normal, Shiny, Rainbow with orders 0, 1, 2", function()
		expect(Pets.variants[1].id).toBe("Normal")
		expect(Pets.variants[2].id).toBe("Shiny")
		expect(Pets.variants[3].id).toBe("Rainbow")
		for i, v in Pets.variants do
			expect(v.order).toBe(i - 1)
		end
	end)
end)

describe("Config: roll tiers and daily", function()
	it("makes each tier cost more, give more luck and unlock later", function()
		for i = 2, #RollTiers.list do
			local prev, cur = RollTiers.list[i - 1], RollTiers.list[i]
			expect(cur.price).toBeGreaterThan(prev.price)
			expect(cur.luck).toBeGreaterThan(prev.luck)
			expect(cur.unlockLifetimeCoins).toBeGreaterThan(prev.unlockLifetimeCoins)
		end
		expect(RollTiers.list[1].unlockLifetimeCoins).toBe(0)
	end)

	it("has seven daily rewards that each pay coins or an egg", function()
		expect(#Daily.rewards).toBe(7)
		for i, reward in Daily.rewards do
			expect(reward.day).toBe(i)
			expect(reward.egg ~= nil or reward.incomeMinutes ~= nil).toBeTruthy()
			if reward.egg then
				expect(Rarities.byId[reward.egg] ~= nil).toBeTruthy()
			end
		end
	end)
end)

describe("Config: hex tree", function()
	local DIRS = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } }
	local function ring(t)
		return math.max(math.abs(t.q), math.abs(t.r), math.abs(t.q + t.r))
	end

	it("has 43 tiles: 1 + 6 + 12 + 18 on rings 0-3 and 6 keystones on ring 4", function()
		expect(#HexTree.tiles).toBe(43)
		local counts = { [0] = 0, 0, 0, 0, 0 }
		for _, t in HexTree.tiles do
			counts[ring(t)] += 1
			expect(ring(t) == 4).toBe(t.keystone == true)
		end
		expect(counts[0]).toBe(1)
		expect(counts[1]).toBe(6)
		expect(counts[2]).toBe(12)
		expect(counts[3]).toBe(18)
		expect(counts[4]).toBe(6)
	end)

	it("fills rings 1-3 completely", function()
		for q = -3, 3 do
			for r = -3, 3 do
				if math.abs(q + r) <= 3 then
					expect(HexTree.byCoord[`{q},{r}`] ~= nil).toBeTruthy()
				end
			end
		end
	end)

	it("has valid levels, costs and requirements", function()
		for _, t in HexTree.tiles do
			expect(t.maxLevel >= 1).toBeTruthy()
			if t.id ~= HexTree.coreId then
				expect(t.baseCost).toBeGreaterThan(0)
				expect(t.growth >= 1).toBeTruthy()
				expect(#t.effects >= 1).toBeTruthy()
			end
			if t.requires then
				expect(HexTree.byId[t.requires] ~= nil).toBeTruthy()
			end
		end
	end)

	it("connects every keystone to a non-keystone neighbour", function()
		for _, t in HexTree.tiles do
			if t.keystone then
				local found = false
				for _, d in DIRS do
					local n = HexTree.byCoord[`{t.q + d[1]},{t.r + d[2]}`]
					if n and not n.keystone then
						found = true
					end
				end
				expect(found).toBeTruthy()
			end
		end
	end)

	it("covers all twelve upgrade categories from the spec", function()
		local stats = {}
		for _, t in HexTree.tiles do
			for _, e in t.effects do
				stats[e.stat] = true
			end
		end
		for _, stat in
			{
				"luckAdd", -- Rolling Luck
				"rollCooldownReduction", -- Rolling Speed
				"padSlots", -- Farm Capacity and Farm Expansion
				"petIncomeAdd", -- Pet Income
				"hatchTimeReduction", -- Hatching Speed
				"eggDiscount", -- Egg Discount
				"offlineRate", -- Offline Earnings
				"critChance", -- Critical Income
				"petCapacity", -- Extra Inventory
				"secretLuckAdd", -- Secret Luck
				"globalMultiplier", -- Global Multiplier
			}
		do
			expect(stats[stat]).toBeTruthy()
		end
	end)

	it("can reach exactly the maximum pad count", function()
		local total = Economy.basePadSlots
		for _, t in HexTree.tiles do
			for _, e in t.effects do
				if e.stat == "padSlots" then
					total += e.value * t.maxLevel
				end
			end
		end
		expect(total).toBe(Economy.maxPadSlots)
	end)
end)

return nil
