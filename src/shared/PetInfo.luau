--[[
	PetInfo: lookups and derived numbers for pets, eggs, mutations and
	upgrades, shared by the server and the client so both show the same values.
]]

local Economy = require(script.Parent.Config.Economy)
local PetConfig = require(script.Parent.Config.Pets)
local Upgrades = require(script.Parent.Upgrades)

local mutationsById: { [string]: any } = {}
for _, mutation in PetConfig.Mutations do
	mutationsById[mutation.id] = mutation
end
local upgradesById: { [string]: any } = {}
for _, definition in Economy.Upgrades do
	upgradesById[definition.id] = definition
end

local PetInfo = {}

PetInfo.EggsById = PetConfig.EggsById
PetInfo.BiomesById = PetConfig.BiomesById
PetInfo.MutationsById = mutationsById
PetInfo.UpgradesById = upgradesById

-- Cash per second for a pet with an optional mutation.
function PetInfo.Income(petId: string, mutationId: string?): number
	local mutation = mutationId and mutationsById[mutationId]
	return PetConfig.Pets[petId].income * (if mutation then mutation.multiplier else 1)
end

function PetInfo.SellValue(petId: string, mutationId: string?): number
	return math.min(Economy.MaxCash, PetInfo.Income(petId, mutationId) * Economy.SellPerIncome)
end

-- "Golden Fox", or "Fox" for a normal pet.
function PetInfo.Name(petId: string, mutationId: string?): string
	local mutation = mutationId and mutationsById[mutationId]
	local name = PetConfig.Pets[petId].name
	return if mutation then `{mutation.name} {name}` else name
end

-- An upgrade's current value from a player's saved upgrade levels.
function PetInfo.UpgradeValue(levels: { [string]: number }, id: string): number
	return Upgrades.Value(upgradesById[id], levels[id] or 0)
end

-- Total cash per second from equipped pets.
function PetInfo.TotalIncome(pets: { [string]: any }, equipped: { [string]: boolean }): number
	local total = 0
	for uid in equipped do
		local owned = pets[uid]
		if owned then
			total += PetInfo.Income(owned.pet, owned.mutation)
		end
	end
	return total
end

-- Equipped and other pet uids, best income first (ties by uid so the order is stable).
function PetInfo.SortByIncome(pets: { [string]: any }, uids: { string }): { string }
	table.sort(uids, function(a, b)
		local incomeA = PetInfo.Income(pets[a].pet, pets[a].mutation)
		local incomeB = PetInfo.Income(pets[b].pet, pets[b].mutation)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return uids
end

return PetInfo
