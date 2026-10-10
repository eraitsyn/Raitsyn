--[[
	RollService: the egg roll station in each of a player's biomes.

	Rolling picks a random egg from that biome's three eggs on the server
	(rarer eggs are likelier with more luck) and keeps it as the player's offer
	there. The player can buy exactly that egg, which goes into their egg
	inventory, or reroll for another. Only the lane's owner can use its
	stations, only in biomes they have unlocked, and only standing near them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

type PlotState = PlotService.PlotState

local random = Random.new()

local function eggRarity(eggId: string): string
	return PetConfig.EggsById[eggId].rarity
end

local offerEntries: { [string]: { Rolls.Entry } } = {}
local biomeIds = {}
for _, biome in PetConfig.Biomes do
	table.insert(biomeIds, biome.id)
	local entries = {}
	for _, eggId in biome.eggIds do
		table.insert(entries, { id = eggId, weight = PetConfig.EggsById[eggId].offerWeight })
	end
	offerEntries[biome.id] = entries
end

local RollService = {}

-- The player's lane state when they may use this biome's station right now.
local function usableState(player: Player, biomeId: string): PlotState?
	local state = PlotService.Get(player)
	if state == nil then
		return nil
	end
	local biome = PetConfig.BiomesById[biomeId]
	if biome.index > state.data.Unlocked then
		return nil
	end
	local station = PlotService.BiomePart(state.plot, biomeId, "Station")
	if not Reach.Within(player, station.Position, Economy.StationDistance + 4) then
		return nil
	end
	return state
end

local function roll(player: Player, biomeId: string)
	local state = usableState(player, biomeId)
	if state == nil then
		return
	end
	local now = os.clock()
	if now - (state.lastRoll[biomeId] or 0) < Economy.RollCooldown then
		return
	end
	state.lastRoll[biomeId] = now

	local luck = PetInfo.UpgradeValue(state.data.Upgrades, "Luck")
	local entries = Rolls.WithLuck(offerEntries[biomeId], eggRarity, PetConfig.LuckyRarities, luck)
	local eggId = Rolls.Pick(entries, function()
		return random:NextNumber()
	end)
	state.offers[biomeId] = eggId
	Gate.Notify(player, "Rolled", eggId, { biome = biomeId })
	StateService.Push(player)
end

local function buy(player: Player, biomeId: string)
	local state = usableState(player, biomeId)
	local eggId = state and state.offers[biomeId]
	if state == nil or eggId == nil then
		return
	end
	local egg = PetConfig.EggsById[eggId]
	local storage = PetInfo.UpgradeValue(state.data.Upgrades, "EggStorage")
	if DataSchema.EggCount(state.data) >= storage then
		Gate.Notify(player, "EggsFull", nil)
		return
	end
	if not CurrencyService.TrySpend(player, egg.price) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	state.data.Eggs[eggId] = (state.data.Eggs[eggId] or 0) + 1
	state.offers[biomeId] = nil
	Gate.Notify(player, "BoughtEgg", eggId)
	StateService.Push(player)
end

function RollService.Init()
	local biomeCheck = Validate.OneOf(biomeIds)
	Gate.Handle("Roll", { rate = { capacity = 6, perSecond = 3 }, args = { biomeCheck } }, roll)
	Gate.Handle("Buy", { rate = { capacity = 6, perSecond = 3 }, args = { biomeCheck } }, buy)
end

return RollService
