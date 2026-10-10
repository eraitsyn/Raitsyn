--[[
	LuckService: the luck upgrade board in each base.

	Luck multiplies the weight of rare pets when an egg hatches (see Rolls and
	Config/Pets). The level is saved; the multiplier and cost come from Economy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Gate = require(script.Parent.Parent.Gate)
local ModelFactory = require(script.Parent.Parent.ModelFactory)
local CurrencyService = require(script.Parent.CurrencyService)
local EggShopService = require(script.Parent.EggShopService)
local PetService = require(script.Parent.PetService)

type PlotState = any

local LuckService = {}

local function refreshBoard(state: PlotState, prompt: ProximityPrompt)
	local board = state.plot:FindFirstChild("LuckBoard") :: BasePart
	local old = board:FindFirstChild("LuckTag")
	if old then
		old:Destroy()
	end
	local level = state.data.LuckLevel
	local cost = Luck.UpgradeCost(Economy, level)
	local luckText = Luck.Text(Luck.Multiplier(Economy, level))
	local tag = ModelFactory.Tag(board, 2, {
		{ `Luck: {luckText}`, Color3.fromRGB(120, 255, 120) },
		{ if cost then `Next: {Format.Cash(cost)}` else "Max luck!", Color3.new(1, 1, 1) },
	})
	tag.Name = "LuckTag"
	state.janitor:Add(tag)

	prompt.ObjectText = if cost then `Luck {luckText} for {Format.Cash(cost)}` else "Max luck"
	prompt.Enabled = cost ~= nil
	state.player:SetAttribute("Luck", Luck.Multiplier(Economy, level))
end

local function tryUpgrade(player: Player, state: PlotState, prompt: ProximityPrompt)
	local board = state.plot:FindFirstChild("LuckBoard") :: BasePart
	if not PetService.CanAct(player, state, board.Position) then
		return
	end
	local cost = Luck.UpgradeCost(Economy, state.data.LuckLevel)
	if cost == nil then
		return
	end
	if not CurrencyService.TrySpend(player, cost) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	state.data.LuckLevel += 1
	refreshBoard(state, prompt)
	EggShopService.RefreshSigns(state)
	Gate.Notify(player, "LuckUp", nil)
end

function LuckService.Setup(state: PlotState)
	local board = state.plot:FindFirstChild("LuckBoard") :: BasePart
	local prompt = state.janitor:Add(PetService.OwnerPrompt(board, "Luck", state.player))
	prompt.ActionText = "Upgrade Luck"
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player: Player)
		tryUpgrade(player, state, prompt)
	end)
	refreshBoard(state, prompt)
end

return LuckService
