--[[
	IncubatorService: eggs waiting to hatch, and hatching them.

	An egg's hatch time is saved as an os.time() timestamp, so eggs keep
	counting down while the player is offline. The pet is rolled on the server
	at the moment of hatching, with the owner's current luck.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Luck = require(ReplicatedStorage.Shared.Luck)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

-- The client counts down every egg with this tag, reading its ReadyAt attribute.
local EGG_TAG = "IncubatingEgg"
local ANNOUNCE_RARITIES = { Mythical = true, Secret = true }
local ANNOUNCE_MUTATIONS = { Rainbow = true }

local random = Random.new()
local eggsById = PetInfo.EggsById

local function rarityOf(petId: string): string
	return PetConfig.Pets[petId].rarity
end

local IncubatorService = {}

local function clearModel(state: PlotState, key: string)
	local model = state.eggs[key]
	if model then
		state.eggs[key] = nil
		model:Destroy()
	end
end

local function tryHatch(player: Player, state: PlotState, key: string, model: Model)
	if state.eggs[key] ~= model or not PetService.CanAct(player, state, model:GetPivot().Position) then
		return
	end
	local incubation = state.data.Incubators[key]
	if os.time() < incubation.readyAt then
		Gate.Notify(player, "NotReady", incubation.egg)
		return
	end
	if not PetService.HasFreePedestal(state) then
		Gate.Notify(player, "PedestalsFull", nil)
		return
	end

	local luck = Luck.Multiplier(Economy, state.data.LuckLevel)
	local entries = Rolls.WithLuck(eggsById[incubation.egg].pets, rarityOf, PetConfig.LuckyRarities, luck)
	local function nextNumber()
		return random:NextNumber()
	end
	local petId = Rolls.Pick(entries, nextNumber)
	local mutationId = Rolls.Mutation(PetConfig.Mutations, nextNumber)
	local chance = 0
	for _, entry in Rolls.Chances(entries) do
		if entry.id == petId then
			chance = entry.chance
		end
	end

	-- Nothing above yields, so the egg cannot be hatched twice.
	state.data.Incubators[key] = nil
	clearModel(state, key)
	PetService.Give(state, petId, mutationId)

	local details = { egg = incubation.egg, mutation = mutationId, odds = Rolls.OneIn(chance) }
	Gate.Notify(player, "Hatched", petId, details)
	if ANNOUNCE_RARITIES[rarityOf(petId)] or ANNOUNCE_MUTATIONS[mutationId or ""] then
		Gate.NotifyAll("ServerHatch", petId, player, details)
	end
end

-- Shows the egg saved in this incubator. Call after changing data.Incubators[key].
function IncubatorService.ShowIncubator(state: PlotState, key: string)
	clearModel(state, key)
	local incubation = state.data.Incubators[key]
	if incubation == nil then
		return
	end
	local egg = eggsById[incubation.egg]
	local model = ModelFactory.BuildEgg(incubation.egg)
	ModelFactory.StandOn(model, PlotService.Part(state.plot, "Incubators", "Incubator", key))
	local shell = model.PrimaryPart :: BasePart

	local tag = ModelFactory.Tag(shell, 3, {
		{ egg.name, Color3.new(1, 1, 1) },
		{ "", Color3.fromRGB(255, 230, 120) },
	})
	-- Line2 is filled in by the client from ReadyAt (os.time() seconds, which
	-- match workspace:GetServerTimeNow() on the client).
	tag.Name = "EggTag"
	shell:SetAttribute("ReadyAt", incubation.readyAt)
	CollectionService:AddTag(shell, EGG_TAG)
	model.Parent = state.plot
	state.eggs[key] = model

	local prompt = PetService.OwnerPrompt(shell, "Hatch", state.player)
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.name
	prompt.HoldDuration = 0.5
	prompt.Triggered:Connect(function(player: Player)
		tryHatch(player, state, key, model)
	end)
end

-- Puts a new egg in the lowest free incubator. Returns its key, or nil when all are full.
function IncubatorService.Add(state: PlotState, eggId: string): string?
	local key = DataSchema.FreeKey(state.data.Incubators, Economy.IncubatorCount)
	if key then
		state.data.Incubators[key] = { egg = eggId, readyAt = os.time() + eggsById[eggId].hatchTime }
		IncubatorService.ShowIncubator(state, key)
	end
	return key
end

function IncubatorService.HasFreeIncubator(state: PlotState): boolean
	return DataSchema.FreeKey(state.data.Incubators, Economy.IncubatorCount) ~= nil
end

function IncubatorService.Setup(state: PlotState)
	for index = 1, Economy.IncubatorCount do
		IncubatorService.ShowIncubator(state, tostring(index))
	end
	state.janitor:Add(function()
		for key in state.eggs do
			clearModel(state, key)
		end
	end)
end

return IncubatorService
