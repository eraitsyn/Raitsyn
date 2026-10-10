--[[
	PlayerService: joins, leaves and respawns.

	Everything set up for a lane is added to its janitor, so leaving tears it
	all down in one call.
]]

local Players = game:GetService("Players")

local BiomeService = require(script.Parent.BiomeService)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local HatchService = require(script.Parent.HatchService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local PlayerService = {}

local function moveToLane(state: PlotService.PlotState, character: Model)
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
	player:SetAttribute("LaneName", state.plot.Name)

	CurrencyService.Attach(player, data)
	PetService.Setup(state)
	HatchService.Setup(state)
	BiomeService.Setup(state)
	StateService.Push(player)

	-- Opens the Upgrades window on the owner's screen; upgrades themselves go through the Upgrade remote.
	local upgradePrompt = state.janitor:Add(
		PetService.OwnerPrompt(state.plot:FindFirstChild("UpgradeStation") :: BasePart, "OpenUpgrades", player)
	)
	upgradePrompt.ActionText = "Upgrades"
	upgradePrompt.ObjectText = "Upgrade Station"

	state.janitor:Add(player.CharacterAdded:Connect(function(character)
		-- Wait one frame so the default spawn location does not override the move.
		task.defer(moveToLane, state, character)
	end))
	if player.Character then
		moveToLane(state, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	PlotService.Release(player)
	CurrencyService.Detach(player)
	DataService.Release(player)
end

function PlayerService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
