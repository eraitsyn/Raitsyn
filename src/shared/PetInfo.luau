--[[
	PetInfo: lookups and derived numbers for pets, eggs and mutations, shared by
	the server and the client so both show the same values.
	No Roblox dependencies, so it is unit tested outside Studio.
]]

local Economy = require(script.Parent.Config.Economy)
local PetConfig = require(script.Parent.Config.Pets)

local eggsById: { [string]: any } = {}
for _, egg in PetConfig.Eggs do
	eggsById[egg.id] = egg
end
local mutationsById: { [string]: any } = {}
for _, mutation in PetConfig.Mutations do
	mutationsById[mutation.id] = mutation
end

local PetInfo = {}

PetInfo.EggsById = eggsById
PetInfo.MutationsById = mutationsById

-- Cash per second for a pet with an optional mutation.
function PetInfo.Income(petId: string, mutationId: string?): number
	local mutation = mutationId and mutationsById[mutationId]
	return PetConfig.Pets[petId].income * (if mutation then mutation.multiplier else 1)
end

function PetInfo.SellValue(petId: string, mutationId: string?): number
	return PetInfo.Income(petId, mutationId) * Economy.SellPerIncome
end

-- "Golden Fox", or "Fox" for a normal pet.
function PetInfo.Name(petId: string, mutationId: string?): string
	local mutation = mutationId and mutationsById[mutationId]
	local name = PetConfig.Pets[petId].name
	return if mutation then `{mutation.name} {name}` else name
end

return PetInfo
