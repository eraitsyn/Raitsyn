--[[
	UpgradeService: buying upgrades (hatch slots, platforms, egg storage,
	hatch speed, luck, auto collect). Levels are saved; values and costs come
	from Config/Economy through the shared Upgrades module.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Gate = require(script.Parent.Parent.Gate)
local CurrencyService = require(script.Parent.CurrencyService)
local HatchService = require(script.Parent.HatchService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local UpgradeService = {}

local function upgrade(player: Player, id: string)
	local state = PlotService.Get(player)
	if state == nil then
		return
	end
	local definition = PetInfo.UpgradesById[id]
	local level = state.data.Upgrades[id] or 0
	local cost = Upgrades.Cost(definition, level)
	if cost == nil then
		return
	end
	if not CurrencyService.TrySpend(player, cost) then
		Gate.Notify(player, "TooPoor", nil)
		return
	end
	state.data.Upgrades[id] = level + 1

	if id == "HatchSlots" then
		HatchService.RefreshSlots(state)
	elseif id == "EquipSlots" then
		PetService.RefreshPlatforms(state)
	end
	StateService.Push(player)
	Gate.Notify(player, "Upgraded", id)
end

function UpgradeService.Init()
	local ids = {}
	for _, definition in Economy.Upgrades do
		table.insert(ids, definition.id)
	end
	Gate.Handle("Upgrade", { rate = { capacity = 6, perSecond = 3 }, args = { Validate.OneOf(ids) } }, upgrade)
end

return UpgradeService
