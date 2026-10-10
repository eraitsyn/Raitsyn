--[[
	HatchService: hatch slots in the base, placing eggs from the egg inventory,
	and opening them.

	An egg's hatch time is saved as an os.time() timestamp, so eggs keep
	counting down while the player is offline. The pet is rolled on the server
	when the egg is opened, with the owner's current luck.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

type PlotState = PlotService.PlotState

-- The client counts down every egg with this tag, reading its ReadyAt attribute.
local EGG_TAG = "IncubatingEgg"
local SLOT_COUNT = 8
local ANNOUNCE_TIER = PetConfig.RarityIndex.Secret

local random = Random.new()

local function rarityOf(petId: string): string
	return PetConfig.Pets[petId].rarity
end

local HatchService = {}

function HatchService.SlotCount(state: PlotState): number
	return PetInfo.UpgradeValue(state.data.Upgrades, "HatchSlots")
end

local function clearModel(state: PlotState, key: string)
	local model = state.eggModels[key]
	if model then
		state.eggModels[key] = nil
		model:Destroy()
	end
end

local function tryOpen(player: Player, state: PlotState, key: string, model: Model)
	if state.eggModels[key] ~= model or not PetService.CanAct(player, state, model:GetPivot().Position) then
		return
	end
	local incubation = state.data.Hatching[key]
	if os.time() < incubation.readyAt then
		Gate.Notify(player, "NotReady", incubation.egg)
		return
	end
	if not PetService.HasRoom(state) then
		Gate.Notify(player, "PetsFull", nil)
		return
	end

	local egg = PetConfig.EggsById[incubation.egg]
	local luck = PetInfo.UpgradeValue(state.data.Upgrades, "Luck")
	local entries = Rolls.WithLuck(egg.pets, rarityOf, PetConfig.LuckyRarities, luck)
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
	local isNew = not state.data.Discovered[petId]

	-- Nothing above yields, so the egg cannot be opened twice.
	state.data.Hatching[key] = nil
	clearModel(state, key)
	PetService.Give(state, petId, mutationId)

	local details = { egg = incubation.egg, mutation = mutationId, odds = Rolls.OneIn(chance), new = isNew }
	Gate.Notify(player, "Hatched", petId, details)
	if PetConfig.RarityIndex[rarityOf(petId)] >= ANNOUNCE_TIER or mutationId == "Rainbow" then
		Gate.NotifyAll("ServerHatch", petId, player, details)
	end
end

local function slotPart(state: PlotState, key: string): BasePart
	return PlotService.Part(state.plot, "HatchSlots", "Slot", key)
end

-- Shows the egg saved in this slot, or an empty/locked slot.
function HatchService.ShowSlot(state: PlotState, key: string)
	clearModel(state, key)
	local part = slotPart(state, key)
	local unlocked = tonumber(key) :: number <= HatchService.SlotCount(state)
	part.Transparency = if unlocked then 0.1 else 0.7
	local incubation = state.data.Hatching[key]
	if incubation == nil then
		return
	end
	local egg = PetConfig.EggsById[incubation.egg]
	local model = ModelFactory.BuildEgg(incubation.egg)
	ModelFactory.StandOn(model, part)
	local shell = model.PrimaryPart :: BasePart

	local tag = ModelFactory.Tag(shell, 3.2, {
		{ egg.name, ModelFactory.RarityColor[egg.rarity] },
		{ "", Color3.fromRGB(255, 230, 120) },
	})
	-- Line2 is filled in by the client from ReadyAt (os.time() seconds, which
	-- match workspace:GetServerTimeNow() on the client).
	tag.Name = "EggTag"
	shell:SetAttribute("ReadyAt", incubation.readyAt)
	CollectionService:AddTag(shell, EGG_TAG)
	model.Parent = state.plot
	state.eggModels[key] = model

	local prompt = PetService.OwnerPrompt(shell, "Open", state.player)
	prompt.ActionText = "Open"
	prompt.ObjectText = egg.name
	prompt.HoldDuration = 0.3
	prompt.Triggered:Connect(function(player: Player)
		tryOpen(player, state, key, model)
	end)
end

function HatchService.RefreshSlots(state: PlotState)
	for index = 1, SLOT_COUNT do
		HatchService.ShowSlot(state, tostring(index))
	end
end

-- Moves one egg from the inventory into the lowest free unlocked slot.
local function placeEgg(player: Player, eggId: string)
	local state = PlotService.Get(player)
	if state == nil or (state.data.Eggs[eggId] or 0) <= 0 then
		return
	end
	local key = DataSchema.FreeKey(state.data.Hatching, HatchService.SlotCount(state))
	if key == nil then
		Gate.Notify(player, "SlotsFull", nil)
		return
	end
	local egg = PetConfig.EggsById[eggId]
	local speed = PetInfo.UpgradeValue(state.data.Upgrades, "HatchSpeed")
	state.data.Eggs[eggId] -= 1
	if state.data.Eggs[eggId] <= 0 then
		state.data.Eggs[eggId] = nil
	end
	state.data.Hatching[key] = { egg = eggId, readyAt = os.time() + math.ceil(egg.hatchTime * speed) }
	HatchService.ShowSlot(state, key)
	StateService.Push(player)
	Gate.Notify(player, "Placed", eggId)
end

function HatchService.Setup(state: PlotState)
	HatchService.RefreshSlots(state)
	state.janitor:Add(function()
		for key in state.eggModels do
			clearModel(state, key)
		end
		for index = 1, SLOT_COUNT do
			slotPart(state, tostring(index)).Transparency = 0.1
		end
	end)
end

function HatchService.Init()
	local eggIds = {}
	for id in PetConfig.EggsById do
		table.insert(eggIds, id)
	end
	Gate.Handle("PlaceEgg", { rate = { capacity = 8, perSecond = 4 }, args = { Validate.OneOf(eggIds) } }, placeEgg)
end

return HatchService
