--[[
	TycoonService: joins, leaves, respawns and rebirths.

	Starting a plot and tearing it down each happen in one place, and rebirth
	reuses both, so there is only one teardown path to get right.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Gate = require(script.Parent.Parent.Gate)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DropperService = require(script.Parent.DropperService)
local PlotService = require(script.Parent.PlotService)
local PurchaseService = require(script.Parent.PurchaseService)

local TycoonService = {}

local function moveToPlot(state: PlotService.PlotState, character: Model)
	local spawnPart = state.plot:FindFirstChild("Spawn") :: BasePart
	character:PivotTo(spawnPart.CFrame * CFrame.new(0, 4, 0))
end

-- Everything here is added to the plot's janitor, so Stop undoes all of it.
local function start(state: PlotService.PlotState)
	DropperService.Setup(state)
	PurchaseService.Setup(state)

	local player = state.player
	state.janitor:Add(player.CharacterAdded:Connect(function(character)
		-- Wait one frame so the default spawn location does not override the move.
		task.defer(moveToPlot, state, character)
	end))
	if player.Character then
		moveToPlot(state, player.Character)
	end
end

local function onPlayerAdded(player: Player)
	local data = DataService.Load(player)
	if data == nil then
		return
	end

	local state = PlotService.Claim(player, data)
	if state == nil then
		DataService.Release(player)
		player:Kick("This server is full. Please join another server.")
		return
	end

	CurrencyService.Attach(player, data)
	start(state)
end

local function onPlayerRemoving(player: Player)
	PlotService.Release(player)
	CurrencyService.Detach(player)
	DataService.Release(player)
end

function TycoonService.Rebirth(player: Player)
	local state = PlotService.Get(player)
	if state == nil or state.busy then
		return
	end
	if state.data.Cash < Economy.RebirthCost then
		Gate.Notify(player, "TooPoor", "Rebirth")
		return
	end

	state.busy = true
	state.janitor:Cleanup()
	PlotService.ResetPlot(state.plot)
	state.data.Purchased = {}
	state.data.StoredCash = 0
	state.data.Rebirths += 1
	CurrencyService.Reset(player)
	start(state)
	state.busy = false

	Gate.Notify(player, "Rebirthed", nil)
end

function TycoonService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Gate.Handle("RequestPurchase", {
		rate = { capacity = 6, perSecond = 4 },
		args = { Validate.String(64) },
	}, function(player, buttonId)
		PurchaseService.TryPurchase(player, buttonId, "remote")
	end)

	Gate.Handle("RequestRebirth", {
		rate = { capacity = 1, perSecond = 0.2 },
		args = {},
	}, TycoonService.Rebirth)
end

return TycoonService
