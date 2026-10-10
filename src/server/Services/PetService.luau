--[[
	PetService: pets on pedestals, their income, collect buttons and selling.

	A pet's id lives in the saved Pedestals table; the model is only a picture
	of it. Income is added on the server once a second into each pedestal's
	own PedestalCash, and the owner steps on that pedestal's button to collect.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

local PetService = {}

-- A prompt only the plot's owner can use. The client hides it from everyone
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

-- True when `player` owns the plot, is in reach of `position`, and is not spamming.
function PetService.CanAct(player: Player, state: PlotState, position: Vector3): boolean
	return Gate.AllowPrompt(player)
		and player == state.player
		and PlotService.Get(player) == state
		and Reach.Within(player, position, Economy.ReachDistance)
end

local function buttonLabel(state: PlotState, key: string): TextLabel?
	local button = PlotService.Part(state.plot, "Buttons", "Button", key)
	local tag = button:FindFirstChild("CashTag")
	return tag and tag:FindFirstChildOfClass("TextLabel")
end

local function updateButton(state: PlotState, key: string)
	local textLabel = buttonLabel(state, key)
	if textLabel then
		local cash = state.data.PedestalCash[key] or 0
		textLabel.Text = if state.data.Pedestals[key] then Format.Cash(cash) else ""
	end
end

local function clearModel(state: PlotState, key: string)
	local model = state.pets[key]
	if model then
		state.pets[key] = nil
		model:Destroy()
	end
end

local function trySell(player: Player, state: PlotState, key: string, model: Model)
	if state.pets[key] ~= model or not PetService.CanAct(player, state, model:GetPivot().Position) then
		return
	end
	local petId = state.data.Pedestals[key]
	local mutationId = state.data.PedestalMutations[key]
	-- Pay out what the pedestal earned too, so selling never loses cash.
	local payout = PetInfo.SellValue(petId, mutationId) + (state.data.PedestalCash[key] or 0)
	state.data.Pedestals[key] = nil
	state.data.PedestalCash[key] = nil
	state.data.PedestalMutations[key] = nil
	clearModel(state, key)
	updateButton(state, key)
	CurrencyService.Add(player, payout)
	Gate.Notify(player, "Sold", petId, { mutation = mutationId, amount = payout })
end

-- Shows the pet saved on this pedestal. Call after changing data.Pedestals[key].
function PetService.ShowPedestal(state: PlotState, key: string)
	clearModel(state, key)
	updateButton(state, key)
	local petId = state.data.Pedestals[key]
	if petId == nil then
		return
	end
	local mutationId = state.data.PedestalMutations[key]
	local model = ModelFactory.BuildPet(petId, mutationId)
	ModelFactory.StandOn(model, PlotService.Part(state.plot, "Pedestals", "Pedestal", key))
	model.Parent = state.plot
	state.pets[key] = model

	local prompt = PetService.OwnerPrompt(model.PrimaryPart :: BasePart, "Sell", state.player)
	prompt.ActionText = "Sell"
	prompt.ObjectText = `{PetInfo.Name(petId, mutationId)} for {Format.Cash(PetInfo.SellValue(petId, mutationId))}`
	prompt.HoldDuration = 1
	prompt.Triggered:Connect(function(player: Player)
		trySell(player, state, key, model)
	end)
end

-- Puts a pet on the lowest free pedestal. Returns its key, or nil when all are full.
function PetService.Give(state: PlotState, petId: string, mutationId: string?): string?
	local key = DataSchema.FreeKey(state.data.Pedestals, Economy.PedestalCount)
	if key then
		state.data.Pedestals[key] = petId
		state.data.PedestalMutations[key] = mutationId
		PetService.ShowPedestal(state, key)
	end
	return key
end

function PetService.HasFreePedestal(state: PlotState): boolean
	return DataSchema.FreeKey(state.data.Pedestals, Economy.PedestalCount) ~= nil
end

-- Adds what the pets earned while the player was away into their pedestals.
local function payOffline(state: PlotState)
	local now = os.time()
	local lastSeen = state.data.LastSeen
	state.data.LastSeen = now
	if lastSeen <= 0 or lastSeen >= now then
		return
	end
	local seconds = math.min(now - lastSeen, Economy.OfflineCapSeconds)
	local total = 0
	for key, petId in state.data.Pedestals do
		local earned =
			math.floor(PetInfo.Income(petId, state.data.PedestalMutations[key]) * seconds * Economy.OfflineRate)
		state.data.PedestalCash[key] = math.min(Economy.MaxCash, (state.data.PedestalCash[key] or 0) + earned)
		total += earned
	end
	if total > 0 then
		Gate.Notify(state.player, "OfflineEarned", nil, { amount = total, seconds = seconds })
	end
end

-- Places saved pets and wires the collect buttons. Undone by the plot's janitor.
function PetService.Setup(state: PlotState)
	payOffline(state)
	for index = 1, Economy.PedestalCount do
		local key = tostring(index)
		local button = PlotService.Part(state.plot, "Buttons", "Button", key)

		local tag = state.janitor:Add(Instance.new("BillboardGui"))
		tag.Name = "CashTag"
		tag.Size = UDim2.fromOffset(140, 36)
		tag.StudsOffset = Vector3.new(0, 2.5, 0)
		tag.MaxDistance = 60
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		textLabel.TextStrokeTransparency = 0.3
		textLabel.Parent = tag
		tag.Parent = button

		state.janitor:Add(button.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent
			if character == nil or Players:GetPlayerFromCharacter(character) ~= state.player then
				return
			end
			local cash = state.data.PedestalCash[key]
			if cash and cash > 0 then
				state.data.PedestalCash[key] = nil
				updateButton(state, key)
				CurrencyService.Add(state.player, cash)
				Gate.Notify(state.player, "Collected", nil, { amount = cash, key = key })
			end
		end))

		PetService.ShowPedestal(state, key)
	end

	state.janitor:Add(function()
		for key in state.pets do
			clearModel(state, key)
		end
	end)
end

-- Income: once a second, every pet adds its income to its own pedestal.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, state in PlotService.All() do
			state.data.LastSeen = now
			for key, petId in state.data.Pedestals do
				local income = PetInfo.Income(petId, state.data.PedestalMutations[key])
				local cash = (state.data.PedestalCash[key] or 0) + income
				state.data.PedestalCash[key] = math.min(Economy.MaxCash, cash)
				updateButton(state, key)
			end
		end
	end
end)

return PetService
