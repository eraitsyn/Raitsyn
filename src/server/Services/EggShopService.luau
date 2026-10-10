--[[
	EggShopService: each base's own egg shop.

	Every stand shows its egg, its price, and each pet's odds at the owner's
	current luck. Buying puts the egg in a free incubator; the pet inside is
	not decided until it hatches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local CurrencyService = require(script.Parent.CurrencyService)
local IncubatorService = require(script.Parent.IncubatorService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)

type PlotState = PlotService.PlotState

local function rarityOf(petId: string): string
	return PetConfig.Pets[petId].rarity
end

local EggShopService = {}

local function stand(state: PlotState, eggId: string): BasePart
	return (state.plot:FindFirstChild("Shop") :: Folder):FindFirstChild(eggId) :: BasePart
end

-- Rebuilds the odds sign on every stand. Call after the owner's luck changes.
function EggShopService.RefreshSigns(state: PlotState)
	local luck = Luck.Multiplier(Economy, state.data.LuckLevel)
	for _, egg in PetConfig.Eggs do
		local part = stand(state, egg.id)
		local old = part:FindFirstChild("OddsTag")
		if old then
			old:Destroy()
		end

		local lines = { { `{egg.name}  {Format.Cash(egg.price)}`, Color3.new(1, 1, 1) } }
		local chances = Rolls.Chances(Rolls.WithLuck(egg.pets, rarityOf, PetConfig.LuckyRarities, luck))
		for _, chance in chances do
			local pet = PetConfig.Pets[chance.id]
			table.insert(lines, {
				`{pet.name} ({pet.rarity})  {Rolls.OneIn(chance.chance)}`,
				ModelFactory.RarityColor[pet.rarity],
			})
		end
		local tag = ModelFactory.Tag(part, 9, lines)
		tag.Name = "OddsTag"
		-- Sized in studs so neighbouring stands' signs never overlap from far away.
		tag.Size = UDim2.fromScale(12, 0.9 * #lines)
		state.janitor:Add(tag)
	end
end

local function tryBuy(player: Player, state: PlotState, egg: any)
	if not PetService.CanAct(player, state, stand(state, egg.id).Position) then
		return
	end
	if not IncubatorService.HasFreeIncubator(state) then
		Gate.Notify(player, "IncubatorsFull", nil)
		return
	end
	if not CurrencyService.TrySpend(player, egg.price) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	IncubatorService.Add(state, egg.id)
	Gate.Notify(player, "BoughtEgg", egg.id)
end

function EggShopService.Setup(state: PlotState)
	for _, egg in PetConfig.Eggs do
		local part = stand(state, egg.id)

		local display = state.janitor:Add(ModelFactory.BuildEgg(egg.id))
		ModelFactory.StandOn(display, part)
		display.Parent = state.plot

		local prompt = state.janitor:Add(PetService.OwnerPrompt(part, "Buy", state.player))
		prompt.ActionText = "Buy"
		prompt.ObjectText = `{egg.name} ({Format.Cash(egg.price)})`
		prompt.HoldDuration = 0
		prompt.Triggered:Connect(function(player: Player)
			tryBuy(player, state, egg)
		end)
	end
	EggShopService.RefreshSigns(state)
end

return EggShopService
