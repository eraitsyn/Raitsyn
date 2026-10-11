--!strict
-- The client's read-only mirror of its own profile. It starts from the
-- server's snapshot and applies the server's patches; nothing on the client
-- ever writes to it directly. Derived values (the stat block, the farm's
-- income rate) are recomputed with the same shared modules the server uses,
-- so every number on screen matches what the server applies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Config = Shared:WaitForChild("Config")
local Income = require(Logic:WaitForChild("Income"))
local Pets = require(Config:WaitForChild("Pets"))
local Stats = require(Logic:WaitForChild("Stats"))
local Signal = require(script.Parent:WaitForChild("Signal"))

export type Pet = { s: string, v: number, t: number, lk: boolean }
export type Slot = { r: string, start: number, done: number }
export type Data = {
	coins: number,
	lifetimeCoins: number,
	rebirths: number,
	hex: { [string]: number },
	keystones: { [string]: boolean },
	pets: { [string]: Pet },
	placed: { [string]: string },
	following: { string },
	eggs: { [string]: number },
	incubator: { Slot },
	index: { [string]: number },
	rollCount: number,
	daily: { streak: number, last: number },
	stats: { rolls: number, hatches: number, rarestScore: number },
	tutorial: number,
	settings: { skipCommonReveals: boolean, autoHatch: boolean, sfxVolume: number },
	[string]: any,
}

export type Snapshot = {
	profile: Data,
	plot: number,
	serverTime: number,
	saving: boolean,
	studio: boolean,
	offline: { coins: number, seconds: number }?,
	nextRollAt: number,
}

local State = {}

State.data = (nil :: any) :: Data
State.plotIndex = 0
State.saving = true
State.studio = false
State.stats = Stats.compute({ hex = {}, keystones = {}, rebirths = 0, speciesFound = 0 })
State.rate = 0
State.nextRollAt = -math.huge

-- Fires with the top-level key that changed (after derived values update).
State.changed = Signal.new() :: Signal.Signal<string>

-- Keys whose change alters the stat block or the farm rate.
local STAT_KEYS = { hex = true, keystones = true, rebirths = true, index = true }
local RATE_KEYS = { placed = true, pets = true }

function State.variantId(order: number): string
	local variant = Pets.variants[order + 1]
	return if variant then variant.id else "Normal"
end

local function recomputeStats()
	State.stats = Stats.compute(Stats.progressOf(State.data))
end

local function recomputeRate()
	local placed = {}
	for _, petId in State.data.placed do
		local pet = State.data.pets[petId]
		if pet then
			table.insert(placed, { species = pet.s, variant = State.variantId(pet.v) })
		end
	end
	State.rate = Income.farmRate(placed, State.stats.incomeMultiplier)
end

function State.load(snapshot: Snapshot)
	State.data = snapshot.profile
	State.plotIndex = snapshot.plot
	State.saving = snapshot.saving
	State.studio = snapshot.studio
	State.nextRollAt = snapshot.nextRollAt
	recomputeStats()
	recomputeRate()
end

export type PatchEntry = { k: string, s: string?, v: any }

function State.applyPatch(patch: { PatchEntry })
	local data = State.data :: any
	local touched: { [string]: boolean } = {}
	for _, entry in patch do
		if entry.s ~= nil then
			local container = data[entry.k]
			if type(container) ~= "table" then
				container = {}
				data[entry.k] = container
			end
			container[entry.s] = entry.v
		else
			data[entry.k] = entry.v
		end
		touched[entry.k] = true
	end
	local statsChanged, rateChanged = false, false
	for key in touched do
		statsChanged = statsChanged or STAT_KEYS[key] == true
		rateChanged = rateChanged or RATE_KEYS[key] == true
	end
	if statsChanged then
		recomputeStats()
	end
	if statsChanged or rateChanged then
		recomputeRate()
	end
	for key in touched do
		State.changed:Fire(key)
	end
	if statsChanged then
		State.changed:Fire("@stats")
	end
	if statsChanged or rateChanged then
		State.changed:Fire("@rate")
	end
end

-- Calls fn now and whenever one of the keys changes. "@stats" and "@rate"
-- are the derived values.
function State.watch(keys: { string }, fn: () -> ()): Signal.Connection
	local set = {}
	for _, key in keys do
		set[key] = true
	end
	fn()
	return State.changed:Connect(function(key)
		if set[key] then
			fn()
		end
	end)
end

function State.now(): number
	return workspace:GetServerTimeNow()
end

function State.eggTotal(): number
	local total = 0
	for _, count in State.data.eggs do
		total += count
	end
	return total
end

function State.petCount(): number
	local count = 0
	for _ in State.data.pets do
		count += 1
	end
	return count
end

function State.padOf(petId: string): number?
	for pad, id in State.data.placed do
		if id == petId then
			return tonumber(pad)
		end
	end
	return nil
end

function State.isFollowing(petId: string): boolean
	return table.find(State.data.following, petId) ~= nil
end

function State.speciesFound(): number
	local found = 0
	for _, mask in State.data.index do
		if mask > 0 then
			found += 1
		end
	end
	return found
end

return State
