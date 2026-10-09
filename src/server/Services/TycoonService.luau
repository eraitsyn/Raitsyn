--[[
	TycoonService: joins, leaves and respawns.

	Everything set up for a plot is added to its janitor, so leaving tears it
	all down in one call.
]]

local Players = game:GetService("Players")

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local GodService = require(script.Parent.GodService)
local PlotService = require(script.Parent.PlotService)

local TycoonService = {}

local function moveToPlot(state: PlotService.PlotState, character: Model)
	local spawnPart = state.plot:FindFirstChild("Spawn") :: BasePart
	character:PivotTo(spawnPart.CFrame * CFrame.new(0, 4, 0))
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
	GodService.Setup(state)

	state.janitor:Add(player.CharacterAdded:Connect(function(character)
		-- Wait one frame so the default spawn location does not override the move.
		task.defer(moveToPlot, state, character)
	end))
	if player.Character then
		moveToPlot(state, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	PlotService.Release(player)
	CurrencyService.Detach(player)
	DataService.Release(player)
end

function TycoonService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return TycoonService
