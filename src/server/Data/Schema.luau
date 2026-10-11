--!strict
-- The saved player profile: template, migrations and a repair pass.
-- ProfileStore stores exactly this table. Bump VERSION and add a migration
-- whenever the shape changes; never edit an old migration.

export type PetRecord = {
	s: string, -- species id
	v: number, -- variant order (0 Normal, 1 Shiny, 2 Rainbow)
	t: number, -- server time obtained
	lk: boolean, -- locked against release
}

export type IncubatorSlot = {
	r: string, -- rarity id
	start: number, -- server time (seconds) the egg went in
	done: number, -- server time when it finishes
}

export type Profile = {
	version: number,
	coins: number,
	lifetimeCoins: number,
	rebirths: number,
	hex: { [string]: number },
	keystones: { [string]: boolean },
	pets: { [string]: PetRecord },
	placed: { [string]: string }, -- pad index (as string, DataStore-safe) -> pet id
	following: { string },
	eggs: { [string]: number },
	incubator: { IncubatorSlot },
	index: { [string]: number }, -- species id -> bitmask of variants found
	rollCount: number,
	nextPetId: number,
	daily: { streak: number, last: number },
	offline: { rate: number, logout: number },
	stats: { rolls: number, hatches: number, rarestScore: number },
	tutorial: number,
	starterGranted: boolean,
	settings: { skipCommonReveals: boolean, autoHatch: boolean, sfxVolume: number },
}

local VERSION = 1

local function template(): Profile
	return {
		version = VERSION,
		coins = 0, -- starting coins are granted by the first-join flow
		lifetimeCoins = 0,
		rebirths = 0,
		hex = {},
		keystones = {},
		pets = {},
		placed = {},
		following = {},
		eggs = {},
		incubator = {},
		index = {},
		rollCount = 0,
		nextPetId = 1,
		daily = { streak = 0, last = 0 },
		offline = { rate = 0, logout = 0 },
		stats = { rolls = 0, hatches = 0, rarestScore = 0 },
		tutorial = 0,
		starterGranted = false,
		settings = { skipCommonReveals = false, autoHatch = true, sfxVolume = 1 },
	}
end

-- migrations[n] upgrades a profile from version n to n + 1.
local migrations: { (any) -> () } = {}

local Schema = {}

Schema.VERSION = VERSION
Schema.template = template

-- Fills any missing keys from the template without touching existing values.
local function reconcile(target: { [any]: any }, source: { [any]: any })
	for key, value in source do
		if target[key] == nil then
			if type(value) == "table" then
				local copy = {}
				reconcile(copy, value)
				target[key] = copy
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

export type LoadResult = "ok" | "future"

-- Brings a loaded profile up to date in place. Returns "future" for data
-- written by a newer server version, which must not be modified.
function Schema.migrate(data: { [string]: any }): LoadResult
	local version = if type(data.version) == "number" then data.version else 0
	if version > VERSION then
		return "future"
	end
	if version == 0 then
		version = 1 -- brand-new profile from ProfileStore: template handles it
	end
	while version < VERSION do
		migrations[version](data)
		version += 1
	end
	data.version = VERSION
	reconcile(data, template() :: any)
	return "ok"
end

-- Repairs values that should be impossible (a crash mid-edit, a bad
-- migration): negative coins, placements pointing at missing pets, a pet both
-- placed and following. Returns the number of fixes so the server can log it.
function Schema.repair(data: Profile, maxPads: number, maxFollowers: number): number
	local fixes = 0
	if type(data.coins) ~= "number" or data.coins ~= data.coins or data.coins < 0 then
		data.coins = 0
		fixes += 1
	end
	local used: { [string]: boolean } = {}
	-- Walk pads in numeric order so a pet on two pads keeps the lower one.
	local pads = {}
	for pad in data.placed do
		table.insert(pads, pad)
	end
	table.sort(pads, function(a, b)
		return (tonumber(a) or math.huge) < (tonumber(b) or math.huge)
	end)
	for _, pad in pads do
		local petId = data.placed[pad]
		local index = tonumber(pad)
		if index == nil or index < 1 or index > maxPads or data.pets[petId] == nil or used[petId] then
			data.placed[pad] = nil
			fixes += 1
		else
			used[petId] = true
		end
	end
	local following = {}
	for _, petId in data.following do
		if #following < maxFollowers and data.pets[petId] ~= nil and not used[petId] then
			used[petId] = true
			table.insert(following, petId)
		else
			fixes += 1
		end
	end
	data.following = following
	for rarity, count in data.eggs do
		if type(count) ~= "number" or count <= 0 then
			data.eggs[rarity] = nil
			fixes += 1
		end
	end
	return fixes
end

return Schema
