--!strict
-- One player's game rules over their saved profile. Every action a client can
-- request (roll, hatch, place, buy a tile, rebirth, ...) is a method here that
-- checks the rules with the shared Logic modules, mutates the profile and
-- reports which keys changed.
--
-- The module never touches Roblox services: the clock, the random source and
-- the change listener are injected, which is what lets the Lune tests drive a
-- whole play session (and every exploit case) outside Studio. Location checks
-- (standing at your own Roll Station) are the calling service's job.
--
-- No method yields, so two requests from the same player can never interleave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")

local Costs = require(Logic:WaitForChild("Costs"))
local Daily = require(Config:WaitForChild("Daily"))
local Economy = require(Config:WaitForChild("Economy"))
local HexGraph = require(Logic:WaitForChild("HexGraph"))
local HexTree = require(Config:WaitForChild("HexTree"))
local Income = require(Logic:WaitForChild("Income"))
local Odds = require(Logic:WaitForChild("Odds"))
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))
local RollTiers = require(Config:WaitForChild("RollTiers"))
local Rules = require(Logic:WaitForChild("Rules"))
local Stats = require(Logic:WaitForChild("Stats"))
local Schema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Schema"))

type Profile = Schema.Profile
type PetRecord = Schema.PetRecord

export type Deps = {
	now: () -> number, -- server time in seconds (fractional)
	random: () -> number, -- uniform in [0, 1)
	onChange: (key: string, sub: string?) -> (), -- a profile key (and optional sub-key) changed
}

-- Early arrival allowed on the roll cooldown, to absorb network jitter.
-- Rolls are scheduled from the previous allowed time, so it never adds up.
local ROLL_TOLERANCE = 0.2
-- Income catch-up after a server hitch never pays more than this many ticks.
local MAX_CATCH_UP_TICKS = 5
local MAX_RELEASE_BATCH = 100

export type Error = string

export type RollResult = {
	rarity: string,
	tier: string,
	lucky: boolean,
	price: number,
	rollCount: number,
	nextRollAt: number,
}

export type HatchedPet = {
	id: string,
	species: string,
	variant: string,
	rarity: string,
	isNew: boolean, -- first time this species was found
	isNewVariant: boolean, -- first time this species was found in this variant
	score: number,
}

export type TickResult = {
	income: number,
	crit: boolean,
	hatched: { HatchedPet },
}

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable(
	{} :: {
		data: Profile,
		deps: Deps,
		stats: Stats.Stats,
		rate: number, -- farm income per second before crits, cached
		petCount: number,
		nextRollAt: number,
		lastIncomeAt: number,
	},
	Session
))

local function variantOrder(variantId: string): number
	local variant = Pets.variantById[variantId]
	return if variant then variant.order else 0
end

local function variantIdOf(order: number): string
	local variant = Pets.variants[order + 1]
	return if variant then variant.id else "Normal"
end

local function eggTotal(eggs: { [string]: number }): number
	local total = 0
	for _, count in eggs do
		total += count
	end
	return total
end

function Session.new(data: Profile, deps: Deps): Session
	local self = setmetatable({
		data = data,
		deps = deps,
		stats = Stats.compute(Stats.progressOf(data)),
		rate = 0,
		petCount = 0,
		nextRollAt = -math.huge,
		lastIncomeAt = deps.now(),
	}, Session)
	for _ in data.pets do
		self.petCount += 1
	end
	self:_refresh()
	return self
end

-- Recomputes the cached stat block and farm rate. Call after anything that
-- can change them: tiles, keystones, rebirths, the Index, placements.
function Session._refresh(self: Session)
	self.stats = Stats.compute(Stats.progressOf(self.data))
	local placed = {}
	for _, petId in self.data.placed do
		local pet = self.data.pets[petId]
		if pet then
			table.insert(placed, { species = pet.s, variant = variantIdOf(pet.v) })
		end
	end
	self.rate = Income.farmRate(placed, self.stats.incomeMultiplier)
end

function Session._changed(self: Session, key: string, sub: string?)
	self.deps.onChange(key, sub)
end

function Session._addCoins(self: Session, amount: number, countsAsEarned: boolean)
	if amount <= 0 then
		return
	end
	self.data.coins += amount
	self:_changed("coins")
	if countsAsEarned then
		self.data.lifetimeCoins += amount
		self:_changed("lifetimeCoins")
	end
end

function Session._spend(self: Session, amount: number): boolean
	if self.data.coins < amount then
		return false
	end
	self.data.coins -= amount
	self:_changed("coins")
	return true
end

local function needMore(missing: number): Error
	return `Need ${math.ceil(missing)} more`
end

-- Expected income per second including crits: what offline earnings and the
-- daily reward scale with.
function Session.expectedRate(self: Session): number
	return Income.expectedRate(self.rate, self.stats.critChance, self.stats.critMultiplier)
end

-- First join: starting coins plus one free Common egg for the tutorial.
function Session.grantStarter(self: Session): boolean
	if self.data.starterGranted then
		return false
	end
	self.data.starterGranted = true
	self.data.coins += Economy.startingCoins
	self.data.eggs[Economy.starterEgg] = (self.data.eggs[Economy.starterEgg] or 0) + 1
	self:_changed("starterGranted")
	self:_changed("coins")
	self:_changed("eggs", Economy.starterEgg)
	return true
end

--------------------------------------------------------------------------------
-- Rolling

function Session.roll(self: Session, tierId: string): (RollResult?, Error?)
	local tier = RollTiers.byId[tierId]
	if tier == nil then
		return nil, "Unknown roll"
	end
	local data = self.data
	if not Rules.tierUnlocked(tierId, data.lifetimeCoins, data.rebirths) then
		return nil, `{tier.name} is locked`
	end
	local now = self.deps.now()
	if now < self.nextRollAt - ROLL_TOLERANCE then
		return nil, "Rolling too fast"
	end
	if eggTotal(data.eggs) >= self.stats.eggCapacity then
		return nil, "Egg storage full: hatch some eggs first"
	end
	local price = Costs.rollPrice(tierId, self.stats.eggDiscount)
	if data.coins < price then
		return nil, needMore(price - data.coins)
	end

	self:_spend(price)
	self.nextRollAt = math.max(now, self.nextRollAt) + self.stats.rollCooldown
	data.rollCount += 1
	data.stats.rolls += 1
	local lucky = self.stats.luckyRollMultiplier > 1 and data.rollCount % Economy.luckyRollEvery == 0
	local luck = Odds.rollLuck(tier.luck, self.stats.luck, if lucky then self.stats.luckyRollMultiplier else 1)
	local rarity = Odds.pickRarity(Odds.chances(luck, self.stats.secretWeightMultiplier), self.deps.random())
	data.eggs[rarity] = (data.eggs[rarity] or 0) + 1
	self:_changed("rollCount")
	self:_changed("stats")
	self:_changed("eggs", rarity)

	return {
		rarity = rarity,
		tier = tierId,
		lucky = lucky,
		price = price,
		rollCount = data.rollCount,
		nextRollAt = self.nextRollAt,
	},
		nil
end

--------------------------------------------------------------------------------
-- Hatching

function Session.freeIncubators(self: Session): number
	return math.max(0, self.stats.incubators - #self.data.incubator)
end

-- Starts up to `count` eggs. With no rarity, the rarest eggs go first.
-- Returns how many started.
function Session.hatch(self: Session, rarityId: string?, count: number): (number?, Error?)
	local data = self.data
	if rarityId ~= nil and Rarities.byId[rarityId] == nil then
		return nil, "Unknown egg"
	end
	if self:freeIncubators() == 0 then
		return nil, "All incubators are busy"
	end
	local room = self.stats.petCapacity - self.petCount - #data.incubator
	if room <= 0 then
		return nil, "Pet storage full: release or place some pets"
	end

	local started = 0
	local now = self.deps.now()
	local limit = math.min(count, self:freeIncubators(), room)
	while started < limit do
		local chosen: string? = nil
		if rarityId then
			if (data.eggs[rarityId] or 0) > 0 then
				chosen = rarityId
			end
		else
			for index = #Rarities.list, 1, -1 do
				local id = Rarities.list[index].id
				if (data.eggs[id] or 0) > 0 then
					chosen = id
					break
				end
			end
		end
		if chosen == nil then
			break
		end
		local rarity = Rarities.byId[chosen]
		data.eggs[chosen] -= 1
		if data.eggs[chosen] <= 0 then
			data.eggs[chosen] = nil
		end
		self:_changed("eggs", chosen)
		table.insert(data.incubator, {
			r = chosen,
			start = now,
			done = now + rarity.hatchSeconds * self.stats.hatchTimeFactor,
		})
		started += 1
	end
	if started == 0 then
		return nil, if rarityId then `No {Rarities.byId[rarityId].name} eggs` else "No eggs to hatch"
	end
	self:_changed("incubator")
	return started, nil
end

function Session._newPetId(self: Session): string
	local id = `p{self.data.nextPetId}`
	self.data.nextPetId += 1
	self:_changed("nextPetId")
	return id
end

-- Creates the pet for a finished egg: species and variant are decided here,
-- on the server, at the moment the egg cracks.
function Session._hatchOne(self: Session, rarityId: string): HatchedPet
	local data = self.data
	local speciesId = Odds.pickSpecies(rarityId, self.deps.random())
	local variantId = Odds.pickVariant(self.stats.variantChanceAdd, self.deps.random())
	local order = variantOrder(variantId)
	local id = self:_newPetId()
	data.pets[id] = { s = speciesId, v = order, t = math.floor(self.deps.now()), lk = order > 0 }
	self.petCount += 1
	self:_changed("pets", id)

	local mask = data.index[speciesId] or 0
	local bit = bit32.lshift(1, order)
	local isNew = mask == 0
	local isNewVariant = bit32.band(mask, bit) == 0
	if isNewVariant then
		data.index[speciesId] = bit32.bor(mask, bit)
		self:_changed("index", speciesId)
	end

	local score = Odds.rarityScore(speciesId, variantId)
	data.stats.hatches += 1
	if score > data.stats.rarestScore then
		data.stats.rarestScore = score
	end
	self:_changed("stats")
	if isNew then
		self:_refresh() -- Collector's Bonus counts species found
	end
	return {
		id = id,
		species = speciesId,
		variant = variantId,
		rarity = rarityId,
		isNew = isNew,
		isNewVariant = isNewVariant,
		score = score,
	}
end

function Session._finishHatches(self: Session, now: number): { HatchedPet }
	local hatched = {}
	local incubator = self.data.incubator
	local index = 1
	while index <= #incubator do
		local slot = incubator[index]
		if slot.done <= now then
			table.remove(incubator, index)
			table.insert(hatched, self:_hatchOne(slot.r))
		else
			index += 1
		end
	end
	if #hatched > 0 then
		self:_changed("incubator")
	end
	if self.stats.autoHatch > 0 and self.data.settings.autoHatch and self:freeIncubators() > 0 then
		if eggTotal(self.data.eggs) > 0 and self.stats.petCapacity - self.petCount - #incubator > 0 then
			self:hatch(nil, self:freeIncubators())
		end
	end
	return hatched
end

--------------------------------------------------------------------------------
-- Income and time

-- Called by the server loop (about every second). Pays whole seconds of
-- income and finishes any eggs whose time is up.
function Session.tick(self: Session): TickResult
	local now = self.deps.now()
	local income = 0
	local crit = false
	local ticks = math.floor(now - self.lastIncomeAt)
	if ticks >= 1 then
		self.lastIncomeAt += ticks
		if ticks > MAX_CATCH_UP_TICKS then
			ticks = MAX_CATCH_UP_TICKS
			self.lastIncomeAt = now
		end
		if self.rate > 0 then
			for _ = 1, ticks do
				local payout, wasCrit =
					Income.tick(self.rate, self.stats.critChance, self.stats.critMultiplier, self.deps.random())
				income += payout
				crit = crit or wasCrit
			end
			self:_addCoins(income, true)
		end
	end
	return { income = income, crit = crit, hatched = self:_finishHatches(now) }
end

-- Pays offline earnings from the rate saved at logout. Call once after load.
function Session.applyOffline(self: Session): (number, number)
	local offline = self.data.offline
	local coins, seconds = Rules.offlineEarnings(
		offline.rate,
		self.stats.offlineRate,
		self.stats.offlineCapHours,
		offline.logout,
		math.floor(self.deps.now())
	)
	offline.logout = 0
	offline.rate = 0
	self:_addCoins(coins, true)
	return coins, seconds
end

-- Records what offline earnings will be based on. Called on every save and
-- on leave, so a crash still leaves a recent logout time behind.
function Session.markLogout(self: Session)
	self.data.offline.rate = self:expectedRate()
	self.data.offline.logout = math.floor(self.deps.now())
end

--------------------------------------------------------------------------------
-- Farm

function Session.padOf(self: Session, petId: string): string?
	for pad, id in self.data.placed do
		if id == petId then
			return pad
		end
	end
	return nil
end

function Session._unfollow(self: Session, petId: string): boolean
	local following = self.data.following
	local index = table.find(following, petId)
	if index then
		table.remove(following, index)
		self:_changed("following")
		return true
	end
	return false
end

-- Puts a pet on a pad. A pet already on another pad moves; a pet already on
-- the target pad goes back to storage.
function Session.place(self: Session, petId: string, pad: number): (boolean, Error?)
	local data = self.data
	if data.pets[petId] == nil then
		return false, "You don't have that pet"
	end
	if pad < 1 or pad > self.stats.padSlots or pad ~= math.floor(pad) then
		return false, "That pad is locked"
	end
	local key = tostring(pad)
	if data.placed[key] == petId then
		return true, nil
	end
	local oldPad = self:padOf(petId)
	if oldPad then
		data.placed[oldPad] = nil
		self:_changed("placed", oldPad)
	end
	self:_unfollow(petId)
	data.placed[key] = petId
	self:_changed("placed", key)
	self:_refresh()
	return true, nil
end

function Session.remove(self: Session, pad: number): (boolean, Error?)
	local key = tostring(pad)
	if self.data.placed[key] == nil then
		return false, "That pad is empty"
	end
	self.data.placed[key] = nil
	self:_changed("placed", key)
	self:_refresh()
	return true, nil
end

function Session.removeAll(self: Session): (boolean, Error?)
	if next(self.data.placed) == nil then
		return false, "Your farm is empty"
	end
	for key in self.data.placed do
		self.data.placed[key] = nil
		self:_changed("placed", key)
	end
	self:_refresh()
	return true, nil
end

-- Pets sorted best first: income, then rarity order, then newest.
function Session.rankedPets(self: Session): { string }
	local ids = {}
	local value: { [string]: number } = {}
	for id, pet in self.data.pets do
		table.insert(ids, id)
		value[id] = Income.petBase(pet.s, variantIdOf(pet.v))
	end
	table.sort(ids, function(a, b)
		if value[a] ~= value[b] then
			return value[a] > value[b]
		end
		local pa, pb = self.data.pets[a], self.data.pets[b]
		if pa.t ~= pb.t then
			return pa.t > pb.t
		end
		return a < b
	end)
	return ids
end

-- Fills every unlocked pad with the highest earners.
function Session.placeBest(self: Session): (number?, Error?)
	local ranked = self:rankedPets()
	if #ranked == 0 then
		return nil, "You have no pets yet"
	end
	local data = self.data
	for key in data.placed do
		data.placed[key] = nil
		self:_changed("placed", key)
	end
	local placedCount = 0
	for pad = 1, math.min(self.stats.padSlots, #ranked) do
		local petId = ranked[pad]
		self:_unfollow(petId)
		data.placed[tostring(pad)] = petId
		self:_changed("placed", tostring(pad))
		placedCount += 1
	end
	self:_refresh()
	return placedCount, nil
end

--------------------------------------------------------------------------------
-- Inventory

function Session.setLocked(self: Session, petId: string, locked: boolean): (boolean, Error?)
	local pet = self.data.pets[petId]
	if pet == nil then
		return false, "You don't have that pet"
	end
	pet.lk = locked
	self:_changed("pets", petId)
	return true, nil
end

-- Toggles a pet walking with you. Following pets leave the farm.
function Session.setFollowing(self: Session, petId: string, follow: boolean): (boolean, Error?)
	if self.data.pets[petId] == nil then
		return false, "You don't have that pet"
	end
	if not follow then
		return self:_unfollow(petId), nil
	end
	if table.find(self.data.following, petId) then
		return true, nil
	end
	if #self.data.following >= Economy.maxFollowers then
		return false, `Only {Economy.maxFollowers} pets can follow you`
	end
	local pad = self:padOf(petId)
	if pad then
		self.data.placed[pad] = nil
		self:_changed("placed", pad)
		self:_refresh()
	end
	table.insert(self.data.following, petId)
	self:_changed("following")
	return true, nil
end

-- Releases pets for a small refund. All-or-nothing: if any id is not
-- releasable the whole request is refused and nothing changes.
function Session.release(self: Session, petIds: { string }): (number?, Error?)
	if #petIds == 0 or #petIds > MAX_RELEASE_BATCH then
		return nil, "Pick between 1 and 100 pets"
	end
	local data = self.data
	local refund = 0
	local seen: { [string]: boolean } = {}
	for _, id in petIds do
		local pet = data.pets[id]
		if pet == nil or seen[id] then
			return nil, "You don't have that pet"
		end
		seen[id] = true
		if pet.lk then
			return nil, "Unlock a pet before releasing it"
		end
		if self:padOf(id) or table.find(data.following, id) then
			return nil, "Take the pet off your farm first"
		end
		refund += Costs.releaseRefund(Pets.byId[pet.s] and Pets.byId[pet.s].rarity or "")
	end
	for _, id in petIds do
		data.pets[id] = nil
		self.petCount -= 1
		self:_changed("pets", id)
	end
	self:_addCoins(refund, false)
	return refund, nil
end

-- Every unlocked, stored, Normal pet of one rarity.
function Session.bulkReleasable(self: Session, rarityId: string): { string }
	local ids = {}
	local busy: { [string]: boolean } = {}
	for _, id in self.data.placed do
		busy[id] = true
	end
	for _, id in self.data.following do
		busy[id] = true
	end
	for id, pet in self.data.pets do
		local species = Pets.byId[pet.s]
		if species and species.rarity == rarityId and not pet.lk and pet.v == 0 and not busy[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

function Session.releaseRarity(self: Session, rarityId: string): (number?, Error?)
	if Rarities.byId[rarityId] == nil then
		return nil, "Unknown rarity"
	end
	local ids = self:bulkReleasable(rarityId)
	if #ids == 0 then
		return nil, "Nothing to release"
	end
	local released = 0
	local refund = 0
	while released < #ids do
		local batch = table.move(ids, released + 1, math.min(#ids, released + MAX_RELEASE_BATCH), 1, {})
		local paid, err = self:release(batch)
		if paid == nil then
			return nil, err
		end
		refund += paid
		released += #batch
	end
	return refund, nil
end

--------------------------------------------------------------------------------
-- Hex tree

function Session.buyTile(self: Session, tileId: string): (number?, Error?)
	local tile = HexTree.byId[tileId]
	if tile == nil then
		return nil, "Unknown upgrade"
	end
	local data = self.data
	local progress = Stats.progressOf(data)
	local ok, reason = HexGraph.canUpgrade(progress, tileId)
	if not ok then
		return nil, reason
	end
	local level = Stats.levelOf(progress, tileId) + 1
	local price = Costs.tileCost(tileId, level)
	if data.coins < price then
		return nil, needMore(price - data.coins)
	end
	self:_spend(price)
	if tile.keystone then
		data.keystones[tileId] = true
		self:_changed("keystones", tileId)
	else
		data.hex[tileId] = level
		self:_changed("hex", tileId)
	end
	self:_refresh()
	return level, nil
end

--------------------------------------------------------------------------------
-- Rebirth

function Session.rebirth(self: Session): (number?, Error?)
	local data = self.data
	local price = Costs.rebirthCost(data.rebirths)
	if data.coins < price then
		return nil, needMore(price - data.coins)
	end
	data.rebirths += 1
	data.coins = Economy.startingCoins
	for tileId in data.hex do
		data.hex[tileId] = nil
	end
	for key in data.placed do
		data.placed[key] = nil
	end
	self:_changed("rebirths")
	self:_changed("coins")
	self:_changed("hex")
	self:_changed("placed")
	self:_refresh()
	return data.rebirths, nil
end

--------------------------------------------------------------------------------
-- Daily reward

export type DailyResult = { day: number, coins: number, egg: string? }

function Session.claimDaily(self: Session): (DailyResult?, Error?)
	local data = self.data
	local now = math.floor(self.deps.now())
	local state = Rules.daily(data.daily.streak, data.daily.last, now)
	if not state.canClaim then
		return nil, "Come back later"
	end
	local reward = Daily.rewards[state.nextDay]
	local coins = Rules.dailyCoins(state.nextDay, self:expectedRate())
	data.daily.streak = state.nextDay
	data.daily.last = now
	self:_changed("daily")
	self:_addCoins(coins, true)
	if reward.egg then
		-- Gifts may go over egg storage; rolling waits until there is room.
		data.eggs[reward.egg] = (data.eggs[reward.egg] or 0) + 1
		self:_changed("eggs", reward.egg)
	end
	return { day = state.nextDay, coins = coins, egg = reward.egg }, nil
end

--------------------------------------------------------------------------------
-- Settings and tutorial

function Session.setSetting(self: Session, key: string, value: any): (boolean, Error?)
	local settings = self.data.settings :: any
	if key == "skipCommonReveals" or key == "autoHatch" then
		if type(value) ~= "boolean" then
			return false, "Invalid setting"
		end
	elseif key == "sfxVolume" then
		if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
			return false, "Invalid setting"
		end
	else
		return false, "Invalid setting"
	end
	settings[key] = value
	self:_changed("settings")
	return true, nil
end

-- Tutorial progress only moves forward, one step at a time or to "skipped".
function Session.setTutorial(self: Session, step: number): (boolean, Error?)
	if step <= self.data.tutorial or step > 99 then
		return false, "Invalid step"
	end
	self.data.tutorial = step
	self:_changed("tutorial")
	return true, nil
end

return Session
