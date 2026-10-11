local Test = require("../lib/Test")
local Game = require("../lib/Game")
local Rng = require("../lib/Rng")
local describe, it, expect = Test.describe, Test.it, Test.expect

local Session = Game.get("ServerScriptService.Server.Game.Session")
local Schema = Game.get("ServerScriptService.Server.Data.Schema")
local Costs = Game.get("ReplicatedStorage.Shared.Logic.Costs")
local Economy = Game.get("ReplicatedStorage.Shared.Config.Economy")
local HexTree = Game.get("ReplicatedStorage.Shared.Config.HexTree")
local Pets = Game.get("ReplicatedStorage.Shared.Config.Pets")
local Rarities = Game.get("ReplicatedStorage.Shared.Config.Rarities")
local Income = Game.get("ReplicatedStorage.Shared.Logic.Income")

-- A session with a controllable clock and random source. `queue` values are
-- returned first by random(), then a seeded PRNG takes over.
local function make(setup: ((any) -> ())?)
	local data = Schema.template()
	if setup then
		setup(data)
	end
	local env = { time = 1_000_000, queue = {}, changes = {} }
	local rng = Rng.new(12345)
	local session = Session.new(data, {
		now = function()
			return env.time
		end,
		random = function()
			if #env.queue > 0 then
				return table.remove(env.queue, 1)
			end
			return rng()
		end,
		onChange = function(key, sub)
			table.insert(env.changes, if sub then `{key}.{sub}` else key)
		end,
	})
	return session, data, env
end

local function petOf(data, species: string, variant: number?)
	local id = `p{data.nextPetId}`
	data.nextPetId += 1
	data.pets[id] = { s = species, v = variant or 0, t = data.nextPetId, lk = false }
	return id
end

describe("Session: starter and rolling", function()
	it("grants starting coins and a free egg exactly once", function()
		local s, data = make()
		expect(s:grantStarter()).toBe(true)
		expect(data.coins).toBe(Economy.startingCoins)
		expect(data.eggs.Common).toBe(1)
		expect(s:grantStarter()).toBe(false)
		expect(data.coins).toBe(Economy.startingCoins)
	end)

	it("charges the tier price and adds an egg of the server-picked rarity", function()
		local s, data, env = make(function(d)
			d.coins = 1000
		end)
		env.queue = { 0.9 } -- high u lands on Common
		local result, err = s:roll("Basic")
		expect(err).toBe(nil)
		expect(result.rarity).toBe("Common")
		expect(data.coins).toBe(1000 - Costs.rollPrice("Basic", 0))
		expect(data.eggs.Common).toBe(1)
		expect(data.rollCount).toBe(1)
	end)

	it("can land on Secret when the random number is tiny", function()
		local s, data, env = make(function(d)
			d.coins = 1000
		end)
		env.queue = { 0 }
		local result = s:roll("Basic")
		expect(result.rarity).toBe("Secret")
		expect(data.eggs.Secret).toBe(1)
	end)

	it("refuses unknown and locked tiers, and missing coins, without charging", function()
		local s, data = make(function(d)
			d.coins = 40
		end)
		local _, err1 = s:roll("Mega")
		expect(err1).toBe("Unknown roll")
		local _, err2 = s:roll("Silver")
		expect(err2).toBe("Silver Roll is locked")
		local _, err3 = s:roll("Basic")
		expect(err3).toBe("Need $10 more")
		expect(data.coins).toBe(40)
		expect(next(data.eggs)).toBe(nil)
	end)

	it("unlocks a tier from lifetime coins, and Cosmic needs a rebirth too", function()
		local s, data = make(function(d)
			d.coins = 1e12
			d.lifetimeCoins = 1e12
		end)
		expect((s:roll("Diamond")) ~= nil).toBeTruthy()
		local _, err = s:roll("Cosmic")
		expect(err).toBe("Cosmic Roll is locked")
		data.rebirths = 1
		s:_refresh()
		local _, err2 = s:roll("Cosmic")
		expect(err2).toBe("Rolling too fast")
	end)

	it("enforces the cooldown from the server clock, and spam never beats it", function()
		local s, _, env = make(function(d)
			d.coins = 1e9
		end)
		local successes = 0
		-- 10 seconds of a client firing every 10 ms
		for _ = 1, 1000 do
			if s:roll("Basic") then
				successes += 1
			end
			env.time += 0.01
		end
		-- 2.5 s cooldown: at most 10 / 2.5 + 1 rolls in 10 seconds
		expect(successes <= 5).toBeTruthy()
		expect(successes >= 4).toBeTruthy()
	end)

	it("accepts a slightly early request but never lets earliness add up", function()
		local s, _, env = make(function(d)
			d.coins = 1e9
		end)
		expect(s:roll("Basic") ~= nil).toBeTruthy()
		env.time += 2.5 - 0.15
		expect(s:roll("Basic") ~= nil).toBeTruthy() -- jitter is forgiven once
		env.time += 2.5 - 0.15
		local _, err = s:roll("Basic") -- now 0.3 s ahead of schedule
		expect(err).toBe("Rolling too fast")
		local successes = 2
		for _ = 1, 100 do
			if s:roll("Basic") then
				successes += 1
			end
			env.time += 0.05
		end
		-- 5 s of spam after 4.7 s: the schedule allows at most 4 more rolls
		expect(successes <= 6).toBeTruthy()
	end)

	it("blocks rolling when egg storage is full and says why", function()
		local s, data = make(function(d)
			d.coins = 1e6
			d.eggs.Common = Economy.baseEggCapacity
		end)
		local _, err = s:roll("Basic")
		expect(err).toBe("Egg storage full: hatch some eggs first")
		expect(data.coins).toBe(1e6)
	end)

	it("applies the Lucky Tenth multiplier on every 10th roll once owned", function()
		local s, data, env = make(function(d)
			d.coins = 1e9
			d.hex.LuckyTenth1 = 1
			d.rollCount = 9
		end)
		local result = s:roll("Basic")
		expect(result.lucky).toBe(true)
		env.time += 10
		expect(s:roll("Basic").lucky).toBe(false)
		expect(data.rollCount).toBe(11)
	end)
end)

describe("Session: hatching", function()
	it("starts an egg, hatches it when the time is up, and records the Index", function()
		local s, data, env = make(function(d)
			d.eggs.Rare = 1
		end)
		local started, err = s:hatch("Rare", 1)
		expect(err).toBe(nil)
		expect(started).toBe(1)
		expect(data.eggs.Rare).toBe(nil)
		expect(#data.incubator).toBe(1)
		expect(#s:tick().hatched).toBe(0)
		env.time += Rarities.byId.Rare.hatchSeconds
		env.queue = { 0, 0.5 } -- first species in the pool, Normal variant
		local hatched = s:tick().hatched
		expect(#hatched).toBe(1)
		local pet = hatched[1]
		expect(pet.rarity).toBe("Rare")
		expect(pet.species).toBe(Pets.byRarity.Rare[1].id)
		expect(pet.variant).toBe("Normal")
		expect(pet.isNew).toBe(true)
		expect(data.pets[pet.id].s).toBe(pet.species)
		expect(data.index[pet.species]).toBe(1)
		expect(#data.incubator).toBe(0)
		expect(data.stats.rarestScore > 0).toBeTruthy()
	end)

	it("locks Shiny and Rainbow pets on hatch so bulk tools never touch them", function()
		local s, data, env = make(function(d)
			d.eggs.Common = 1
		end)
		s:hatch("Common", 1)
		env.time += 100
		env.queue = { 0.1, 0 } -- u = 0 rolls the rarest variant
		local pet = s:tick().hatched[1]
		expect(pet.variant).toBe("Rainbow")
		expect(data.pets[pet.id].lk).toBe(true)
		expect(data.index[pet.species]).toBe(4)
	end)

	it("uses one incubator at the start and refuses more", function()
		local s, _ = make(function(d)
			d.eggs.Common = 5
		end)
		expect(s:hatch(nil, 5)).toBe(1)
		local _, err = s:hatch("Common", 1)
		expect(err).toBe("All incubators are busy")
	end)

	it("hatches the rarest egg first when no rarity is given", function()
		local s, data = make(function(d)
			d.eggs.Common = 3
			d.eggs.Epic = 1
			d.hex.TwinIncubator = 1
		end)
		expect(s:hatch(nil, 5)).toBe(2)
		expect(data.incubator[1].r).toBe("Epic")
		expect(data.incubator[2].r).toBe("Common")
	end)

	it("refuses when pet storage (counting eggs in incubators) is full", function()
		local s = make(function(d)
			d.eggs.Common = 1
			for _ = 1, Economy.basePetCapacity do
				petOf(d, "BarnChick")
			end
		end)
		local _, err = s:hatch("Common", 1)
		expect(err).toBe("Pet storage full: release or place some pets")
	end)

	it("applies hatching speed upgrades to the finish time", function()
		local s, data, env = make(function(d)
			d.eggs.Legendary = 1
			d.hex.HatchingSpeed1 = 5
		end)
		s:hatch("Legendary", 1)
		local slot = data.incubator[1]
		expect(slot.done - env.time).toBeLessThan(Rarities.byId.Legendary.hatchSeconds)
	end)

	it("keeps hatching automatically once Auto Hatch is owned", function()
		local s, data, env = make(function(d)
			d.eggs.Common = 3
			d.hex.AutoHatch = 1
		end)
		s:hatch(nil, 1)
		for _ = 1, 10 do
			env.time += 5
			s:tick()
		end
		expect(data.eggs.Common).toBe(nil)
		expect(s.petCount).toBe(3)
	end)
end)

describe("Session: farm and income", function()
	it("places pets only on unlocked pads and pays their income every second", function()
		local s, data, env = make()
		local chick = petOf(data, "BarnChick")
		s = Session.new(data, s.deps)
		local ok, err = s:place(chick, Economy.basePadSlots + 1)
		expect(ok).toBe(false)
		expect(err).toBe("That pad is locked")
		expect((s:place(chick, 1))).toBe(true)
		local rate = Income.petBase("BarnChick", "Normal")
		expect(s.rate).toBeNear(rate, 1e-9)
		env.time += 1
		env.queue = { 0.99 } -- no crit
		local result = s:tick()
		expect(result.income).toBeNear(rate, 1e-9)
		expect(data.coins).toBeNear(rate, 1e-9)
		expect(data.lifetimeCoins).toBeNear(rate, 1e-9)
	end)

	it("moves a pet between pads instead of duplicating it", function()
		local s, data = make()
		local id = petOf(data, "MossGoat")
		s = Session.new(data, s.deps)
		s:place(id, 1)
		s:place(id, 2)
		expect(data.placed["1"]).toBe(nil)
		expect(data.placed["2"]).toBe(id)
		expect(s.rate).toBeNear(Income.petBase("MossGoat", "Normal"), 1e-9)
	end)

	it("swaps the old pet back to storage when a pad is reused", function()
		local s, data = make()
		local a = petOf(data, "MossGoat")
		local b = petOf(data, "GoldenStag")
		s = Session.new(data, s.deps)
		s:place(a, 1)
		s:place(b, 1)
		expect(data.placed["1"]).toBe(b)
		expect(s:padOf(a)).toBe(nil)
	end)

	it("caps income catch-up after a long server hitch", function()
		local s, data, env = make()
		local id = petOf(data, "GoldenStag")
		s = Session.new(data, s.deps)
		s:place(id, 1)
		env.time += 600
		env.queue = { 0.99, 0.99, 0.99, 0.99, 0.99 }
		local result = s:tick()
		expect(result.income).toBeNear(s.rate * 5, 1e-6)
	end)

	it("pays critical ticks at the crit multiplier", function()
		local s, data, env = make(function(d)
			d.hex.CriticalIncome1 = 5
		end)
		local id = petOf(data, "BarnChick")
		s = Session.new(data, s.deps)
		s:place(id, 1)
		env.time += 1
		env.queue = { 0 }
		local result = s:tick()
		expect(result.crit).toBe(true)
		expect(result.income).toBeNear(s.rate * Economy.critMultiplier, 1e-9)
	end)

	it("Place Best fills every unlocked pad with the highest earners", function()
		local s, data = make()
		local low = petOf(data, "BarnChick")
		local mid = petOf(data, "MossGoat")
		local high = petOf(data, "GoldenStag")
		local shiny = petOf(data, "SunflowerFox", 1)
		s = Session.new(data, s.deps)
		s:place(low, 1)
		expect(s:placeBest()).toBe(3)
		expect(data.placed["1"]).toBe(high)
		expect(data.placed["2"]).toBe(shiny)
		expect(data.placed["3"]).toBe(mid)
		expect(s:padOf(low)).toBe(nil)
	end)

	it("takes a following pet off the farm and limits followers", function()
		local s, data = make()
		local ids = {}
		for i = 1, 4 do
			ids[i] = petOf(data, "BarnChick")
		end
		s = Session.new(data, s.deps)
		s:place(ids[1], 1)
		expect((s:setFollowing(ids[1], true))).toBe(true)
		expect(s:padOf(ids[1])).toBe(nil)
		s:setFollowing(ids[2], true)
		s:setFollowing(ids[3], true)
		local ok, err = s:setFollowing(ids[4], true)
		expect(ok).toBe(false)
		expect(err).toBe("Only 3 pets can follow you")
		s:place(ids[2], 1)
		expect(table.find(data.following, ids[2])).toBe(nil)
	end)
end)

describe("Session: release", function()
	it("refunds the flat per-rarity amount and removes the pets", function()
		local s, data = make()
		local a = petOf(data, "BarnChick")
		local b = petOf(data, "GoldenStag")
		s = Session.new(data, s.deps)
		local refund = s:release({ a, b })
		expect(refund).toBe(Rarities.byId.Common.releaseRefund + Rarities.byId.Legendary.releaseRefund)
		expect(data.pets[a]).toBe(nil)
		expect(s.petCount).toBe(0)
	end)

	it("is all-or-nothing and refuses locked, placed, duplicate or foreign ids", function()
		local s, data = make()
		local a = petOf(data, "BarnChick")
		local locked = petOf(data, "BarnChick")
		local placed = petOf(data, "BarnChick")
		data.pets[locked].lk = true
		s = Session.new(data, s.deps)
		s:place(placed, 1)
		local cases = {
			{ { a, locked }, "Unlock a pet before releasing it" },
			{ { a, placed }, "Take the pet off your farm first" },
			{ { a, a }, "You don't have that pet" },
			{ { a, "p999" }, "You don't have that pet" },
		}
		for _, case in cases do
			local refund, err = s:release(case[1])
			expect(refund).toBe(nil)
			expect(err).toBe(case[2])
			expect(data.pets[a] ~= nil).toBeTruthy()
		end
		expect(data.coins).toBe(0)
	end)

	it("bulk release skips locked, placed, following and variant pets", function()
		local s, data = make()
		local free1 = petOf(data, "BarnChick")
		local free2 = petOf(data, "CloverBunny")
		local shiny = petOf(data, "BarnChick", 1)
		local locked = petOf(data, "BarnChick")
		local placed = petOf(data, "BarnChick")
		local follower = petOf(data, "BarnChick")
		local other = petOf(data, "MossGoat")
		data.pets[locked].lk = true
		s = Session.new(data, s.deps)
		s:place(placed, 1)
		s:setFollowing(follower, true)
		local refund = s:releaseRarity("Common")
		expect(refund).toBe(2 * Rarities.byId.Common.releaseRefund)
		expect(data.pets[free1]).toBe(nil)
		expect(data.pets[free2]).toBe(nil)
		for _, kept in { shiny, locked, placed, follower, other } do
			expect(data.pets[kept] ~= nil).toBeTruthy()
		end
	end)
end)

describe("Session: hex tree and rebirth", function()
	it("buys a ring-1 tile, charges its price and applies its effect", function()
		local s, data = make(function(d)
			d.coins = 10_000
		end)
		local before = s.stats.padSlots
		local level, err = s:buyTile("FarmCapacity1")
		expect(err).toBe(nil)
		expect(level).toBe(1)
		expect(data.coins).toBe(10_000 - Costs.tileCost("FarmCapacity1", 1))
		expect(s.stats.padSlots).toBe(before + 1)
	end)

	it("refuses tiles that are not connected, missing coins, and unknown ids", function()
		local s, data = make(function(d)
			d.coins = 100
		end)
		local _, err1 = s:buyTile("PetIncome2")
		expect(err1).toBe("Buy a neighbouring tile first")
		local _, err2 = s:buyTile("PetIncome1")
		expect(err2).toBe(`Need ${Costs.tileCost("PetIncome1", 1) - 100} more`)
		local _, err3 = s:buyTile("NotATile")
		expect(err3).toBe("Unknown upgrade")
		local _, err4 = s:buyTile(HexTree.coreId)
		expect(err4).toBe("Not an upgrade")
		expect(data.coins).toBe(100)
	end)

	it("stops at max level", function()
		local s = make(function(d)
			d.coins = 1e12
			d.hex.PetIncome1 = 5
		end)
		local _, err = s:buyTile("PetIncome1")
		expect(err).toBe("Fully upgraded")
	end)

	it("holds keystones behind their milestone and keeps them through rebirth", function()
		local s, data = make(function(d)
			d.coins = 1e15
			d.hex.FarmCapacity1 = 3
			d.hex.FarmExpansion1 = 1
			d.hex.FarmCapacity2 = 3
			d.hex.FarmExpansion2 = 1
			d.hex.FarmCapacity3 = 3
		end)
		local _, err = s:buyTile("FarmExpansion3")
		expect(err).toBe("Needs Rebirth 1")
		data.rebirths = 1
		expect(s:buyTile("FarmExpansion3")).toBe(1)
		expect(data.keystones.FarmExpansion3).toBe(true)
		data.coins = Costs.rebirthCost(1)
		s:rebirth()
		expect(data.keystones.FarmExpansion3).toBe(true)
		expect(next(data.hex)).toBe(nil)
		-- the keystone's pads stay, the tree's do not
		expect(s.stats.padSlots).toBe(Economy.basePadSlots + 6)
	end)

	it("rebirths only with enough coins, then resets coins, tree and farm but keeps pets", function()
		local s, data = make(function(d)
			d.hex.PetIncome1 = 2
		end)
		local id = petOf(data, "GoldenStag")
		data.eggs.Rare = 2
		s = Session.new(data, s.deps)
		s:place(id, 1)
		data.coins = Costs.rebirthCost(0) - 1
		local _, err = s:rebirth()
		expect(err).toBe("Need $1 more")
		data.coins = Costs.rebirthCost(0)
		expect(s:rebirth()).toBe(1)
		expect(data.coins).toBe(Economy.startingCoins)
		expect(next(data.hex)).toBe(nil)
		expect(next(data.placed)).toBe(nil)
		expect(data.pets[id] ~= nil).toBeTruthy()
		expect(data.eggs.Rare).toBe(2)
		expect(s.stats.incomeMultiplier).toBeNear(1 + Economy.rebirth.incomePerRebirth, 1e-9)
	end)
end)

describe("Session: daily, offline, settings", function()
	it("pays the daily reward once per window and advances the streak", function()
		local s, data, env = make()
		local result = s:claimDaily()
		expect(result.day).toBe(1)
		expect(result.coins).toBe(500)
		local _, err = s:claimDaily()
		expect(err).toBe("Come back later")
		env.time += 21 * 3600
		expect(s:claimDaily().day).toBe(2)
		env.time += 21 * 3600
		local day3 = s:claimDaily()
		expect(day3.egg).toBe("Rare")
		expect(data.eggs.Rare).toBe(1)
		env.time += 72 * 3600
		expect(s:claimDaily().day).toBe(1)
	end)

	it("pays offline earnings only with the Offline tiles, capped by time", function()
		local s, data, env = make(function(d)
			d.hex.OfflineEarnings1 = 1
		end)
		local id = petOf(data, "GoldenStag")
		s = Session.new(data, s.deps)
		s:place(id, 1)
		s:markLogout()
		local rate = data.offline.rate
		expect(rate > 0).toBeTruthy()
		env.time += 10 * 3600
		local fresh = Session.new(data, s.deps)
		local coinsBefore = data.coins
		local paid, seconds = fresh:applyOffline()
		expect(seconds).toBe(fresh.stats.offlineCapHours * 3600)
		expect(paid).toBe(math.floor(rate * fresh.stats.offlineRate * seconds))
		expect(data.coins).toBe(coinsBefore + paid)
		-- consumed: a second call pays nothing
		expect((fresh:applyOffline())).toBe(0)
	end)

	it("pays nothing offline without the tiles", function()
		local s, data, env = make()
		local id = petOf(data, "GoldenStag")
		s = Session.new(data, s.deps)
		s:place(id, 1)
		s:markLogout()
		env.time += 3600
		expect((Session.new(data, s.deps):applyOffline())).toBe(0)
	end)

	it("accepts only known settings with the right types", function()
		local s, data = make()
		expect((s:setSetting("autoHatch", false))).toBe(true)
		expect(data.settings.autoHatch).toBe(false)
		expect((s:setSetting("autoHatch", "yes"))).toBe(false)
		expect((s:setSetting("coins", 5))).toBe(false)
		expect((s:setSetting("sfxVolume", 0 / 0))).toBe(false)
		expect((s:setSetting("sfxVolume", 2))).toBe(false)
		expect((s:setSetting("sfxVolume", 0.5))).toBe(true)
	end)

	it("only moves the tutorial forward", function()
		local s, data = make()
		expect((s:setTutorial(2))).toBe(true)
		expect((s:setTutorial(1))).toBe(false)
		expect(data.tutorial).toBe(2)
	end)
end)

describe("Session: invariants under random play", function()
	it("never breaks the profile across 20,000 random actions", function()
		local s, data, env = make()
		s:grantStarter()
		data.coins = 1e6
		local rng = Rng.new(777)
		local function pick(list)
			return list[math.floor(rng() * #list) + 1]
		end
		local function anyPet(): string
			local ids = {}
			for id in data.pets do
				table.insert(ids, id)
			end
			table.insert(ids, "p999999")
			return pick(ids)
		end
		local tiles = {}
		for _, tile in HexTree.tiles do
			table.insert(tiles, tile.id)
		end
		local rarities = {}
		for _, r in Rarities.list do
			table.insert(rarities, r.id)
		end
		local actions = {
			function()
				s:roll(pick({ "Basic", "Silver", "Gold", "Nope" }))
			end,
			function()
				s:hatch(if rng() < 0.5 then nil else pick(rarities), math.floor(rng() * 4) + 1)
			end,
			function()
				s:place(anyPet(), math.floor(rng() * 30) - 2)
			end,
			function()
				s:remove(math.floor(rng() * 26))
			end,
			function()
				s:placeBest()
			end,
			function()
				s:setFollowing(anyPet(), rng() < 0.6)
			end,
			function()
				s:setLocked(anyPet(), rng() < 0.3)
			end,
			function()
				s:release({ anyPet(), anyPet() })
			end,
			function()
				s:releaseRarity(pick(rarities))
			end,
			function()
				s:buyTile(pick(tiles))
			end,
			function()
				if rng() < 0.01 then
					data.coins += Costs.rebirthCost(data.rebirths)
					s:rebirth()
				end
			end,
			function()
				s:claimDaily()
			end,
			function()
				env.time += rng() * 3
				s:tick()
			end,
		}
		for _ = 1, 20_000 do
			pick(actions)()
			if rng() < 0.002 then
				data.coins += 1e7
			end
		end

		-- invariants
		expect(data.coins >= 0 and data.coins == data.coins).toBeTruthy()
		local count = 0
		for _ in data.pets do
			count += 1
		end
		expect(count).toBe(s.petCount)
		local seen = {}
		for pad, id in data.placed do
			local n = tonumber(pad)
			expect(n ~= nil and n >= 1 and n <= s.stats.padSlots).toBeTruthy()
			expect(data.pets[id] ~= nil).toBeTruthy()
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
		for _, id in data.following do
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
		expect(#data.following <= Economy.maxFollowers).toBeTruthy()
		expect(Schema.repair(data, s.stats.padSlots, Economy.maxFollowers)).toBe(0)
		expect(data.stats.hatches > 50).toBeTruthy()
		expect(data.rebirths >= 1).toBeTruthy()
	end)
end)

return nil
