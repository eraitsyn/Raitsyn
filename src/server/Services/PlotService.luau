--[[
	PlotService: assigns plots and owns each player's server-side PlotState.

	Expected plot layout (see README):
	  workspace.Plots.<Plot>        Model, PrimaryPart = Base
	    Base, Spawn, CollectPad     BaseParts
	    Slots/Slot1..SlotN          one BasePart per base slot (N = Economy.SlotsPerBase)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Janitor = require(ReplicatedStorage.Shared.Janitor)
local DataSchema = require(script.Parent.Parent.DataSchema)

export type PlotState = {
	player: Player,
	plot: Model,
	data: DataSchema.PlayerData, -- the saved profile data; Slots and StoredCash live here
	gods: { [string]: Model }, -- slot key -> placed god model
	lockedUntil: number, -- os.clock() time; stealing is blocked before it
	lockReadyAt: number, -- os.clock() time the lock can be used again
	janitor: Janitor.Janitor, -- every connection, thread and instance tied to this plot
}

local REQUIRED_PARTS = { "Base", "Spawn", "CollectPad" }

local states: { [Player]: PlotState } = {}
local freePlots: { Model } = {}

local PlotService = {}

local function checkPlot(plot: Instance)
	assert(plot:IsA("Model"), `{plot:GetFullName()} must be a Model`)
	assert(plot.PrimaryPart, `{plot:GetFullName()} needs PrimaryPart set to Base`)
	for _, name in REQUIRED_PARTS do
		local part = plot:FindFirstChild(name)
		assert(part and part:IsA("BasePart"), `{plot:GetFullName()} is missing part {name}`)
	end
	local slots = plot:FindFirstChild("Slots")
	assert(slots, `{plot:GetFullName()} is missing folder Slots`)
	for index = 1, Economy.SlotsPerBase do
		local slot = slots:FindFirstChild(`Slot{index}`)
		assert(slot and slot:IsA("BasePart"), `{plot:GetFullName()} is missing Slots.Slot{index}`)
	end
end

function PlotService.SlotPart(plot: Model, key: string): BasePart
	return (plot:FindFirstChild("Slots") :: Folder):FindFirstChild(`Slot{key}`) :: BasePart
end

-- True when the position is over the plot's Base, ignoring height.
function PlotService.IsOnPlot(plot: Model, position: Vector3): boolean
	local base = plot:FindFirstChild("Base") :: BasePart
	local localPosition = base.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= base.Size.X / 2 and math.abs(localPosition.Z) <= base.Size.Z / 2
end

function PlotService.Init()
	local folder = workspace:WaitForChild("Plots")
	local plots = folder:GetChildren()
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	for _, plot in plots do
		checkPlot(plot)
		plot:SetAttribute("OwnerUserId", 0)
		table.insert(freePlots, plot :: Model)
	end
	assert(#freePlots > 0, "workspace.Plots has no plots")
end

-- Gives the player a free plot. Returns nil when every plot is taken.
function PlotService.Claim(player: Player, data: DataSchema.PlayerData): PlotState?
	local plot = table.remove(freePlots, 1)
	if plot == nil then
		return nil
	end
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.DisplayName)
	local state: PlotState = {
		player = player,
		plot = plot,
		data = data,
		gods = {},
		lockedUntil = 0,
		lockReadyAt = 0,
		janitor = Janitor.new(),
	}
	states[player] = state
	return state
end

function PlotService.Get(player: Player): PlotState?
	return states[player]
end

function PlotService.All(): { [Player]: PlotState }
	return states
end

-- Cleans up everything tied to the plot and returns it to the free list.
function PlotService.Release(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	states[player] = nil
	state.janitor:Destroy()
	table.clear(state.gods)
	state.plot:SetAttribute("OwnerUserId", 0)
	state.plot:SetAttribute("OwnerName", nil)
	state.plot:SetAttribute("StoredCash", 0)
	state.plot:SetAttribute("LockedUntil", nil)
	table.insert(freePlots, state.plot)
end

return PlotService
