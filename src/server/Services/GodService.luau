--[[
	GodService: gods placed in base slots, their income, selling, and the
	collect pad.

	A placed god's id lives in the saved Slots table; the model in the slot is
	only a picture of it. Income is added on the server once a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GodConfig = require(ReplicatedStorage.Shared.Config.Gods)
local DataSchema = require(script.Parent.Parent.DataSchema)
local Gate = require(script.Parent.Parent.Gate)
local GodFactory = require(script.Parent.Parent.GodFactory)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

local GodService = {}

-- Set by StealService so it can attach its own prompt to every placed god.
GodService.OnPlaced = nil :: ((state: PlotState, key: string, model: Model) -> ())?

local function makePrompt(parent: BasePart, kind: string, owner: Player): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = `{kind}Prompt`
	prompt.MaxActivationDistance = Economy.PromptDistance
	prompt.RequiresLineOfSight = false
	-- Read by the client only to hide prompts that do not apply to the viewer.
	prompt:SetAttribute("Kind", kind)
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = parent
	return prompt
end

-- Removes the god model from a slot. Does not change saved data.
function GodService.ClearModel(state: PlotState, key: string)
	local model = state.gods[key]
	if model then
		state.gods[key] = nil
		model:Destroy()
	end
end

-- Shows the god saved in this slot. Call after changing data.Slots[key].
function GodService.ShowSlot(state: PlotState, key: string)
	GodService.ClearModel(state, key)
	local godId = state.data.Slots[key]
	if godId == nil then
		return
	end

	local god = GodConfig.Gods[godId]
	local model = GodFactory.Build(godId)
	GodFactory.StandOn(model, PlotService.SlotPart(state.plot, key))
	model.Parent = state.plot
	state.gods[key] = model

	local sellPrompt = makePrompt(model.PrimaryPart :: BasePart, "Sell", state.player)
	sellPrompt.ActionText = "Sell"
	sellPrompt.ObjectText = `{god.name} for ${math.floor(god.price * Economy.SellRefund)}`
	sellPrompt.HoldDuration = 1
	sellPrompt.Triggered:Connect(function(who: Player)
		GodService.TrySell(who, state, key, model)
	end)

	if GodService.OnPlaced then
		GodService.OnPlaced(state, key, model)
	end
end

-- Puts a god in the lowest free slot. Returns the slot key, or nil if the base is full.
function GodService.Give(state: PlotState, godId: string): string?
	local key = DataSchema.FreeSlot(state.data, Economy.SlotsPerBase)
	if key == nil then
		return nil
	end
	state.data.Slots[key] = godId
	GodService.ShowSlot(state, key)
	return key
end

-- Removes the god from a slot in saved data and in the world.
function GodService.Take(state: PlotState, key: string): string?
	local godId = state.data.Slots[key]
	state.data.Slots[key] = nil
	GodService.ClearModel(state, key)
	return godId
end

function GodService.TrySell(player: Player, state: PlotState, key: string, model: Model)
	-- Only the owner sells, only the god still in that slot, and only within reach.
	if
		not Gate.AllowPrompt(player)
		or player ~= state.player
		or state.gods[key] ~= model
		or model:GetAttribute("Stealing")
	then
		return
	end
	if not Reach.Within(player, model:GetPivot().Position, Economy.ReachDistance) then
		return
	end
	local godId = GodService.Take(state, key)
	if godId then
		CurrencyService.Add(player, math.floor(GodConfig.Gods[godId].price * Economy.SellRefund))
		Gate.Notify(player, "Sold", godId)
	end
end

local function updateCollectLabel(state: PlotState)
	state.plot:SetAttribute("StoredCash", state.data.StoredCash)
	local pad = state.plot:FindFirstChild("CollectPad") :: BasePart
	local billboard = pad:FindFirstChild("CollectTag")
	local textLabel = billboard and billboard:FindFirstChildOfClass("TextLabel")
	if textLabel then
		textLabel.Text = `Collect ${state.data.StoredCash}`
	end
end

-- Places saved gods and wires the collect pad. Undone by the plot's janitor.
function GodService.Setup(state: PlotState)
	for index = 1, Economy.SlotsPerBase do
		GodService.ShowSlot(state, tostring(index))
	end
	state.janitor:Add(function()
		for key in state.gods do
			GodService.ClearModel(state, key)
		end
	end)

	local pad = state.plot:FindFirstChild("CollectPad") :: BasePart
	local billboard = state.janitor:Add(Instance.new("BillboardGui"))
	billboard.Name = "CollectTag"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 60
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Parent = billboard
	billboard.Parent = pad
	updateCollectLabel(state)

	state.janitor:Add(pad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character == nil or Players:GetPlayerFromCharacter(character) ~= state.player then
			return
		end
		local stored = state.data.StoredCash
		if stored > 0 then
			state.data.StoredCash = 0
			updateCollectLabel(state)
			CurrencyService.Add(state.player, stored)
		end
	end))
end

-- Income: once a second, every placed god adds its income to its base's stored cash.
task.spawn(function()
	while true do
		task.wait(1)
		for _, state in PlotService.All() do
			local income = 0
			for _, godId in state.data.Slots do
				income += GodConfig.Gods[godId].income
			end
			if income > 0 then
				state.data.StoredCash = math.min(Economy.MaxCash, state.data.StoredCash + income)
				updateCollectLabel(state)
			end
		end
	end
end)

return GodService
