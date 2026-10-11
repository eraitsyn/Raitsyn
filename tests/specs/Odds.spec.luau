local Test = require("../lib/Test")
local Game = require("../lib/Game")
local Rng = require("../lib/Rng")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Odds = Game.get("ReplicatedStorage.Shared.Logic.Odds")
local RollTiers = Game.get("ReplicatedStorage.Shared.Config.RollTiers")
local Pets = Game.get("ReplicatedStorage.Shared.Config.Pets")

local function chanceOf(chances, rarity)
	for _, c in chances do
		if c.rarity == rarity then
			return c.chance
		end
	end
	error("missing " .. rarity)
end

describe("Odds: published chances", function()
	it("matches the design doc at Basic tier with no upgrades", function()
		local c = Odds.chances(1)
		expect(chanceOf(c, "Common")).toBeNear(0.55, 1e-12)
		expect(chanceOf(c, "Uncommon")).toBeNear(0.28, 1e-12)
		expect(chanceOf(c, "Rare")).toBeNear(0.12, 1e-12)
		expect(chanceOf(c, "Epic")).toBeNear(0.04, 1e-12)
		expect(Odds.oneIn(chanceOf(c, "Legendary"))).toBe(111)
		expect(Odds.oneIn(chanceOf(c, "Mythic"))).toBe(1010)
		expect(Odds.oneIn(chanceOf(c, "Secret"))).toBe(100000)
	end)

	it("matches the design doc's roll tier table", function()
		local expected = {
			Silver = { Legendary = 61, Mythic = 553, Secret = 62758 },
			Gold = { Legendary = 38, Mythic = 343, Secret = 44462 },
			Diamond = { Legendary = 25, Mythic = 231, Secret = 34342 },
			Cosmic = { Legendary = 18, Mythic = 167, Secret = 28763 },
		}
		for tierId, row in expected do
			local c = Odds.chances(RollTiers.byId[tierId].luck)
			for rarity, oneIn in row do
				expect(Odds.oneIn(chanceOf(c, rarity))).toBe(oneIn)
			end
		end
	end)

	it("always sums to 1", function()
		for _, luck in { 1, 1.7, 6, 40, 500 } do
			local total = 0
			for _, c in Odds.chances(luck, 2.5) do
				total += c.chance
			end
			expect(total).toBeNear(1, 1e-12)
		end
	end)

	it("never makes Common more likely as luck rises", function()
		local previous = 1
		for luck = 1, 100, 3 do
			local common = chanceOf(Odds.chances(luck), "Common")
			expect(common <= previous + 1e-15).toBeTruthy()
			previous = common
		end
	end)

	it("only lets Secret Luck move the Secret weight up", function()
		local base = Odds.chances(6, 1)
		local boosted = Odds.chances(6, 2.5)
		expect(chanceOf(boosted, "Secret")).toBeGreaterThan(chanceOf(base, "Secret") * 2.4)
		expect(chanceOf(boosted, "Common")).toBeLessThan(chanceOf(base, "Common") + 1e-12)
	end)

	it("treats luck below 1 as 1", function()
		expect(Odds.rollLuck(1, 0.5, 1)).toBe(1)
		expect(Odds.rollLuck(6, 1.5, 3)).toBeNear(27, 1e-12)
	end)
end)

describe("Odds: pickers", function()
	it("maps the bottom and top of [0, 1) to the right ends", function()
		local c = Odds.chances(1)
		-- Pickers walk from the rarest tier, so u = 0 is Secret and u near 1 is Common.
		expect(Odds.pickRarity(c, 0)).toBe("Secret")
		expect(Odds.pickRarity(c, 0.9999999)).toBe("Common")
		expect(Odds.pickRarity(c, 1)).toBe("Common")
	end)

	it("lands within tolerance of the published chances over 1,000,000 rolls", function()
		local rng = Rng.new(12345)
		local luck = 6
		local c = Odds.chances(luck)
		local counts = {}
		local n = 1_000_000
		for _ = 1, n do
			local r = Odds.pickRarity(c, rng())
			counts[r] = (counts[r] or 0) + 1
		end
		for _, entry in c do
			local expected = entry.chance * n
			-- 5 standard deviations of a binomial: fails ~1 in 3.5 million by chance.
			local sd = math.sqrt(n * entry.chance * (1 - entry.chance))
			expect(math.abs((counts[entry.rarity] or 0) - expected) <= 5 * sd + 1).toBeTruthy()
		end
	end)

	it("picks species by pool weight", function()
		local rng = Rng.new(99)
		local counts = {}
		local n = 200_000
		for _ = 1, n do
			local s = Odds.pickSpecies("Common", rng())
			counts[s] = (counts[s] or 0) + 1
		end
		local pool = Pets.byRarity.Common
		local total = 0
		for _, s in pool do
			total += s.weight
		end
		for _, s in pool do
			expect((counts[s.id] or 0) / n).toBeNear(s.weight / total, 0.005)
		end
	end)

	it("only picks species from the requested pool", function()
		for _, u in { 0, 0.3, 0.6, 0.99999 } do
			expect(Pets.byId[Odds.pickSpecies("Mythic", u)].rarity).toBe("Mythic")
		end
	end)

	it("picks variants at their published chances", function()
		local rng = Rng.new(7)
		local n = 500_000
		local shiny, rainbow = 0, 0
		for _ = 1, n do
			local v = Odds.pickVariant(0, rng())
			if v == "Shiny" then
				shiny += 1
			elseif v == "Rainbow" then
				rainbow += 1
			end
		end
		expect(shiny / n).toBeNear(1 / 50, 0.001)
		expect(rainbow / n).toBeNear(1 / 1000, 0.0003)
	end)

	it("raises variant chances with Shiny Luck", function()
		local chances = Odds.variantChances(1.0)
		expect(chances.Shiny).toBeNear(2 / 50, 1e-12)
		expect(chances.Rainbow).toBeNear(2 / 1000, 1e-12)
	end)
end)

return nil
