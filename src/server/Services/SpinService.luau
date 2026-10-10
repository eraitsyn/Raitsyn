--[[
	SpinService: the egg spinner in each base.

	Spinning picks a random egg on the server (rarer eggs are likelier with more
	luck). After the spin animation the egg appears on the spinner with its
	price; the owner can buy it, which puts it in a free incubator, or spin
	again for a different egg. The pet inside is not decided until it hatches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local CurrencyService = require(script.Parent.CurrencyService)
local IncubatorService = require(script.Parent.IncubatorService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

local random = Random.new()

local spinEntries = {}
for _, egg in PetConfig.Eggs do
	table.insert(spinEntries, { id = egg.id, weight = egg.spinWeight })
end

local function eggRarity(eggId: string): string
	return PetInfo.EggsById[eggId].rarity
end

local function petRarity(petId: string): string
	return PetConfig.Pets[petId].rarity
end

local function luckOf(state: PlotState): number
	return Luck.Multiplier(Economy, state.data.LuckLevel)
end

local function spinner(state: PlotState): BasePart
	return state.plot:FindFirstChild("Spinner") :: BasePart
end

local SpinService = {}

-- Removes the egg on offer, if any.
local function clearOffer(state: PlotState)
	state.offer = nil
	if state.offerModel then
		state.offerModel:Destroy()
		state.offerModel = nil
	end
end

-- The sign over the spinner: every egg's chance at the owner's current luck.
local function refreshSpinnerSign(state: PlotState)
	local part = spinner(state)
	local old = part:FindFirstChild("SpinTag")
	if old then
		old:Destroy()
	end
	local lines = { { "SPIN FOR AN EGG!", Color3.fromRGB(255, 230, 120) } }
	local entries = Rolls.WithLuck(spinEntries, eggRarity, PetConfig.LuckyRarities, luckOf(state))
	for _, chance in Rolls.Chances(entries) do
		local egg = PetInfo.EggsById[chance.id]
		table.insert(lines, {
			`{egg.name} ({egg.rarity})  {Rolls.OneIn(chance.chance)}`,
			ModelFactory.RarityColor[egg.rarity],
		})
	end
	local tag = ModelFactory.Tag(part, 17, lines)
	tag.Name = "SpinTag"
	tag.Size = UDim2.fromScale(14, 1 * #lines)
	state.janitor:Add(tag)
end

-- The sign over the egg on offer: its price and each pet's chance.
local function offerLines(state: PlotState, eggId: string): { { any } }
	local egg = PetInfo.EggsById[eggId]
	local lines = {
		{ `{string.upper(egg.rarity)} {egg.name}`, ModelFactory.RarityColor[egg.rarity] },
		{ `Price: {Format.Cash(egg.price)}`, Color3.fromRGB(120, 255, 120) },
	}
	local entries = Rolls.WithLuck(egg.pets, petRarity, PetConfig.LuckyRarities, luckOf(state))
	for _, chance in Rolls.Chances(entries) do
		local pet = PetConfig.Pets[chance.id]
		table.insert(lines, {
			`{pet.name} ({pet.rarity})  {Rolls.OneIn(chance.chance)}`,
			ModelFactory.RarityColor[pet.rarity],
		})
	end
	return lines
end

local function tryBuy(player: Player, state: PlotState, model: Model)
	if state.offerModel ~= model or not PetService.CanAct(player, state, model:GetPivot().Position) then
		return
	end
	local eggId = state.offer :: string
	local egg = PetInfo.EggsById[eggId]
	if not IncubatorService.HasFreeIncubator(state) then
		Gate.Notify(player, "IncubatorsFull", nil)
		return
	end
	if not CurrencyService.TrySpend(player, egg.price) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	clearOffer(state)
	IncubatorService.Add(state, eggId)
	Gate.Notify(player, "BoughtEgg", eggId)
end

-- Puts the spun egg on top of the spinner with a Buy prompt.
local function showOffer(state: PlotState, eggId: string)
	local model = ModelFactory.BuildEgg(eggId)
	model:ScaleTo(1.4)
	ModelFactory.StandOn(model, spinner(state))
	local shell = model.PrimaryPart :: BasePart
	local tag = ModelFactory.Tag(shell, 6, offerLines(state, eggId))
	tag.Name = "OfferTag"
	tag.Size = UDim2.fromScale(10, 0.8 * #tag:GetChildren())
	model.Parent = state.plot
	state.offerModel = model

	local egg = PetInfo.EggsById[eggId]
	local prompt = PetService.OwnerPrompt(shell, "Buy", state.player)
	prompt.ActionText = `Buy for {Format.Cash(egg.price)}`
	prompt.ObjectText = egg.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player: Player)
		tryBuy(player, state, model)
	end)
end

local function trySpin(player: Player, state: PlotState)
	if not PetService.CanAct(player, state, spinner(state).Position) then
		return
	end
	local now = os.clock()
	if now - state.lastSpin < Economy.SpinCooldown then
		return
	end
	state.lastSpin = now

	local entries = Rolls.WithLuck(spinEntries, eggRarity, PetConfig.LuckyRarities, luckOf(state))
	local eggId = Rolls.Pick(entries, function()
		return random:NextNumber()
	end)
	clearOffer(state)
	state.offer = eggId
	state.spinSerial += 1
	local serial = state.spinSerial
	Gate.Notify(player, "Spun", eggId, { reveal = Economy.SpinRevealDelay })

	-- The egg appears when the client's spin animation lands on it.
	task.delay(Economy.SpinRevealDelay, function()
		if state.spinSerial == serial and state.offer == eggId and PlotService.Get(player) == state then
			showOffer(state, eggId)
		end
	end)
end

-- Rebuilds the odds signs. Call after the owner's luck changes.
function SpinService.RefreshSigns(state: PlotState)
	refreshSpinnerSign(state)
	if state.offerModel and state.offer then
		local shell = state.offerModel.PrimaryPart :: BasePart
		local old = shell:FindFirstChild("OfferTag")
		if old then
			old:Destroy()
		end
		local tag = ModelFactory.Tag(shell, 6, offerLines(state, state.offer))
		tag.Name = "OfferTag"
		tag.Size = UDim2.fromScale(10, 0.8 * #tag:GetChildren())
	end
end

function SpinService.Setup(state: PlotState)
	local prompt = state.janitor:Add(PetService.OwnerPrompt(spinner(state), "Spin", state.player))
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Egg Spinner"
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player: Player)
		trySpin(player, state)
	end)
	state.janitor:Add(function()
		state.spinSerial += 1
		clearOffer(state)
	end)
	refreshSpinnerSign(state)
end

return SpinService
