--[[
	PetService: the pet inventory, equipping pets onto platforms, income, the
	Collector and selling.

	Pets live in the saved Pets table, keyed by a uid. Equipped pets stand on
	the lane's platforms, best earner first, and add their income to the
	Collector once a second (or straight to cash with Auto Collect). The owner
	steps on the Collector to collect.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

type PlotState = PlotService.PlotState

local PLATFORM_COUNT = 12
local UID = Validate.String(12)

local PetService = {}

-- A prompt only the lane's owner can use. The client hides it from everyone
-- else; the server checks the owner on every trigger regardless.
function PetService.OwnerPrompt(parent: Instance, kind: string, owner: Player): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = `{kind}Prompt`
	prompt.MaxActivationDistance = Economy.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = parent
	return prompt
end

-- True when `player` owns the lane, is in reach of `position`, and is not spamming.
function PetService.CanAct(player: Player, state: PlotState, position: Vector3): boolean
	return Gate.AllowPrompt(player)
		and player == state.player
		and PlotService.Get(player) == state
		and Reach.Within(player, position, Economy.ReachDistance)
end

function PetService.EquipCapacity(state: PlotState): number
	return PetInfo.UpgradeValue(state.data.Upgrades, "EquipSlots")
end

-- Shows equipped pets on the platforms, best earner on Platform1. Locked
-- platforms (beyond the equip capacity) are greyed out.
function PetService.RefreshPlatforms(state: PlotState)
	for _, model in state.petModels do
		model:Destroy()
	end
	table.clear(state.petModels)

	local uids = {}
	for uid in state.data.Equipped do
		table.insert(uids, uid)
	end
	PetInfo.SortByIncome(state.data.Pets, uids)

	local capacity = PetService.EquipCapacity(state)
	for index = 1, PLATFORM_COUNT do
		local key = tostring(index)
		local platform = PlotService.Part(state.plot, "Platforms", "Platform", key)
		local unlocked = index <= capacity
		platform.Color = if unlocked then Color3.fromRGB(90, 160, 240) else Color3.fromRGB(110, 110, 120)
		platform.Transparency = if unlocked then 0 else 0.5
		local uid = uids[index]
		if uid and unlocked then
			local owned = state.data.Pets[uid]
			local model = ModelFactory.BuildPet(owned.pet, owned.mutation)
			ModelFactory.StandOn(model, platform)
			model.Parent = state.plot
			state.petModels[key] = model
		end
	end
	state.player:SetAttribute("Income", PetInfo.TotalIncome(state.data.Pets, state.data.Equipped))
end

local function changed(state: PlotState)
	PetService.RefreshPlatforms(state)
	StateService.Push(state.player)
end

-- Adds a hatched pet to the inventory and equips it when a platform is free.
-- Returns its uid, or nil when the inventory is full.
function PetService.Give(state: PlotState, petId: string, mutationId: string?): string?
	local data = state.data
	if DataSchema.Count(data.Pets) >= Economy.MaxPets then
		return nil
	end
	local uid = tostring(data.NextPetId)
	data.NextPetId += 1
	data.Pets[uid] = { pet = petId, mutation = mutationId }
	data.Discovered[petId] = true
	if DataSchema.Count(data.Equipped) < PetService.EquipCapacity(state) then
		data.Equipped[uid] = true
	end
	changed(state)
	return uid
end

function PetService.HasRoom(state: PlotState): boolean
	return DataSchema.Count(state.data.Pets) < Economy.MaxPets
end

local function equip(player: Player, uid: string)
	local state = PlotService.Get(player)
	if state == nil or state.data.Pets[uid] == nil or state.data.Equipped[uid] then
		return
	end
	if DataSchema.Count(state.data.Equipped) >= PetService.EquipCapacity(state) then
		Gate.Notify(player, "EquipFull", nil)
		return
	end
	state.data.Equipped[uid] = true
	changed(state)
end

local function unequip(player: Player, uid: string)
	local state = PlotService.Get(player)
	if state == nil or not state.data.Equipped[uid] then
		return
	end
	state.data.Equipped[uid] = nil
	changed(state)
end

-- Fills the platforms with the highest-earning pets the player owns.
function PetService.EquipBest(state: PlotState)
	local uids = {}
	for uid in state.data.Pets do
		table.insert(uids, uid)
	end
	PetInfo.SortByIncome(state.data.Pets, uids)
	table.clear(state.data.Equipped)
	for index = 1, math.min(#uids, PetService.EquipCapacity(state)) do
		state.data.Equipped[uids[index]] = true
	end
	changed(state)
end

local function sell(player: Player, uid: string)
	local state = PlotService.Get(player)
	local owned = state and state.data.Pets[uid]
	if state == nil or owned == nil then
		return
	end
	local payout = PetInfo.SellValue(owned.pet, owned.mutation)
	state.data.Pets[uid] = nil
	state.data.Equipped[uid] = nil
	CurrencyService.Add(player, payout)
	Gate.Notify(player, "Sold", owned.pet, { mutation = owned.mutation, amount = payout })
	changed(state)
end

local function updateCollector(state: PlotState)
	state.player:SetAttribute("Collector", state.data.Collector)
	local collector = state.plot:FindFirstChild("Collector") :: BasePart
	local tag = collector:FindFirstChild("CollectorTag")
	local label = tag and tag:FindFirstChild("Line2")
	if label and label:IsA("TextLabel") then
		label.Text = Format.Cash(state.data.Collector)
	end
end

local function collect(state: PlotState)
	local cash = state.data.Collector
	if cash > 0 then
		state.data.Collector = 0
		CurrencyService.Add(state.player, cash)
		updateCollector(state)
		Gate.Notify(state.player, "Collected", nil, { amount = cash })
	end
end

-- Adds what equipped pets earned while the player was away into the Collector.
local function payOffline(state: PlotState)
	local now = os.time()
	local lastSeen = state.data.LastSeen
	state.data.LastSeen = now
	if lastSeen <= 0 or lastSeen >= now then
		return
	end
	local seconds = math.min(now - lastSeen, Economy.OfflineCapSeconds)
	local income = PetInfo.TotalIncome(state.data.Pets, state.data.Equipped)
	local earned = math.floor(income * seconds * Economy.OfflineRate)
	if earned > 0 then
		state.data.Collector = math.min(Economy.MaxCash, state.data.Collector + earned)
		Gate.Notify(state.player, "OfflineEarned", nil, { amount = earned, seconds = seconds })
	end
end

-- Places equipped pets and wires the Collector. Undone by the lane's janitor.
function PetService.Setup(state: PlotState)
	payOffline(state)

	local collector = state.plot:FindFirstChild("Collector") :: BasePart
	local tag = state.janitor:Add(ModelFactory.Tag(collector, 4, {
		{ "Collector", Color3.new(1, 1, 1) },
		{ "$0", Color3.fromRGB(120, 255, 120) },
	}))
	tag.Name = "CollectorTag"
	tag.Size = UDim2.fromOffset(220, 70)
	state.janitor:Add(collector.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character and Players:GetPlayerFromCharacter(character) == state.player then
			collect(state)
		end
	end))

	-- Hide platforms' pets when the lane is released.
	state.janitor:Add(function()
		for _, model in state.petModels do
			model:Destroy()
		end
		table.clear(state.petModels)
		for index = 1, PLATFORM_COUNT do
			local platform = PlotService.Part(state.plot, "Platforms", "Platform", tostring(index))
			platform.Color = Color3.fromRGB(90, 160, 240)
			platform.Transparency = 0
		end
	end)

	PetService.RefreshPlatforms(state)
	updateCollector(state)
end

function PetService.Init()
	Gate.Handle("Equip", { rate = { capacity = 10, perSecond = 5 }, args = { UID } }, equip)
	Gate.Handle("Unequip", { rate = { capacity = 10, perSecond = 5 }, args = { UID } }, unequip)
	Gate.Handle("Sell", { rate = { capacity = 10, perSecond = 5 }, args = { UID } }, sell)
	Gate.Handle("EquipBest", { rate = { capacity = 2, perSecond = 1 }, args = {} }, function(player)
		local state = PlotService.Get(player)
		if state then
			PetService.EquipBest(state)
		end
	end)

	-- Income: once a second, equipped pets add their income to the Collector.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, state in PlotService.All() do
				state.data.LastSeen = now
				local income = PetInfo.TotalIncome(state.data.Pets, state.data.Equipped)
				if income > 0 then
					if PetInfo.UpgradeValue(state.data.Upgrades, "AutoCollect") >= 1 then
						CurrencyService.Add(state.player, math.min(income, Economy.MaxCash))
					else
						state.data.Collector = math.min(Economy.MaxCash, state.data.Collector + income)
						updateCollector(state)
					end
				end
			end
		end
	end)
end

return PetService
