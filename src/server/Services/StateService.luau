--[[
	StateService: sends each player their own data so the screens can show it.

	The client never sends this back; it is only a picture of the server's data.
	Many changes in one frame are sent as one snapshot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)

local pending: { [Player]: boolean } = {}

local StateService = {}

local function send(player: Player)
	pending[player] = nil
	local state = PlotService.Get(player)
	if state == nil then
		return
	end
	local data = state.data
	Remotes.Get("State"):FireClient(player, {
		unlocked = data.Unlocked,
		upgrades = data.Upgrades,
		eggs = data.Eggs,
		pets = data.Pets,
		equipped = data.Equipped,
		hatching = data.Hatching,
		discovered = data.Discovered,
		offers = state.offers,
		income = PetInfo.TotalIncome(data.Pets, data.Equipped),
	})
end

-- Sends the player's state at the end of this frame.
function StateService.Push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(send, player)
end

return StateService
