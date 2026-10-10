--[[
	BiomeService: unlocking biomes in order, the gates, teleporting, and the
	decorations a base earns for each unlocked biome.

	Gates stay solid on the server. The client makes its own unlocked gates
	passable (the character is simulated on the client) and the server refuses
	station actions in any biome that is still locked, so walking through a
	locked gate gains nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Gate = require(script.Parent.Parent.Gate)
local Props = require(script.Parent.Parent.Props)
local Reach = require(script.Parent.Parent.Reach)
local CurrencyService = require(script.Parent.CurrencyService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

type PlotState = PlotService.PlotState

local BiomeService = {}

local function gateLabel(state: PlotState, biome: any): TextLabel?
	local gate = PlotService.BiomePart(state.plot, biome.id, "Gate")
	local tag = gate:FindFirstChild("GateTag")
	local line = tag and tag:FindFirstChild("Line2")
	return if line and line:IsA("TextLabel") then line else nil
end

-- Builds the base decoration for every unlocked biome and updates the gates.
function BiomeService.Refresh(state: PlotState)
	state.player:SetAttribute("Unlocked", state.data.Unlocked)
	for _, biome in PetConfig.Biomes do
		local anchor = (state.plot:FindFirstChild("Decor") :: Folder):FindFirstChild(biome.id) :: BasePart
		local unlocked = biome.index <= state.data.Unlocked
		local existing = anchor:FindFirstChild("Decoration")
		if unlocked and existing == nil then
			local prop = Props.Build(biome.id, Random.new(biome.index), 1)
			prop.Name = "Decoration"
			prop:ScaleTo(0.6)
			prop:PivotTo(anchor.CFrame)
			prop.Parent = anchor
			state.janitor:Add(prop)
		end
		if biome.index > 1 then
			local gate = PlotService.BiomePart(state.plot, biome.id, "Gate")
			gate:SetAttribute("Unlocked", unlocked)
			local prompt = gate:FindFirstChild("UnlockPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = not unlocked
			end
			local line = gateLabel(state, biome)
			if line then
				line.Text = if unlocked then "Unlocked!" else `Unlock: {Format.Cash(biome.unlockCost)}`
			end
		end
	end
end

local function tryUnlock(player: Player, state: PlotState, biome: any)
	local gate = PlotService.BiomePart(state.plot, biome.id, "Gate")
	if not PetService.CanAct(player, state, gate.Position) then
		return
	end
	if biome.index ~= state.data.Unlocked + 1 then
		Gate.Notify(player, "UnlockInOrder", biome.id)
		return
	end
	if not CurrencyService.TrySpend(player, biome.unlockCost) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	state.data.Unlocked = biome.index
	BiomeService.Refresh(state)
	StateService.Push(player)
	Gate.Notify(player, "Unlocked", biome.id)
end

local function teleport(player: Player, target: string)
	local state = PlotService.Get(player)
	local root = Reach.Root(player)
	if state == nil or root == nil then
		return
	end
	local destination: BasePart
	if target == "Base" then
		destination = state.plot:FindFirstChild("Spawn") :: BasePart
	else
		local biome = PetConfig.BiomesById[target]
		if biome.index > state.data.Unlocked then
			return
		end
		destination = PlotService.BiomePart(state.plot, target, "Arrival")
	end
	(player.Character :: Model):PivotTo(destination.CFrame * CFrame.new(0, 4, 0))
end

function BiomeService.Setup(state: PlotState)
	for _, biome in PetConfig.Biomes do
		if biome.index > 1 then
			local gate = PlotService.BiomePart(state.plot, biome.id, "Gate")
			local prompt = state.janitor:Add(PetService.OwnerPrompt(gate, "Unlock", state.player))
			prompt.ActionText = `Unlock {biome.name}`
			prompt.ObjectText = Format.Cash(biome.unlockCost)
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 14
			prompt.Triggered:Connect(function(player: Player)
				tryUnlock(player, state, biome)
			end)
		end
	end
	state.janitor:Add(function()
		for _, biome in PetConfig.Biomes do
			if biome.index > 1 then
				PlotService.BiomePart(state.plot, biome.id, "Gate"):SetAttribute("Unlocked", false)
				local line = gateLabel(state, biome)
				if line then
					line.Text = `Unlock: {Format.Cash(biome.unlockCost)}`
				end
			end
		end
	end)
	BiomeService.Refresh(state)
end

function BiomeService.Init()
	local targets = { "Base" }
	for _, biome in PetConfig.Biomes do
		table.insert(targets, biome.id)
	end
	Gate.Handle("Teleport", { rate = { capacity = 3, perSecond = 1 }, args = { Validate.OneOf(targets) } }, teleport)
end

return BiomeService
