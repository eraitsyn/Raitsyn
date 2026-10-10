--[[
	PlotService: assigns plots and owns each player's server-side PlotState.

	Expected plot layout (see README):
	  workspace.Plots.<Plot>              Model, PrimaryPart = Base
	    Base, Spawn, LuckBoard, Spinner   BaseParts
	    Incubators/Incubator1..N          N = Economy.IncubatorCount
	    Pedestals/Pedestal1..N            N = Economy.PedestalCount
	    Buttons/Button1..N                the collect button for each pedestal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Janitor = require(ReplicatedStorage.Shared.Janitor)
local DataSchema = require(script.Parent.Parent.DataSchema)

export type PlotState = {
	player: Player,
	plot: Model,
	data: DataSchema.PlayerData, -- the saved profile data; the source of truth
	pets: { [string]: Model }, -- pedestal key -> pet model (a picture of data.Pedestals)
	eggs: { [string]: Model }, -- incubator key -> egg model (a picture of data.Incubators)
	janitor: Janitor.Janitor, -- every connection, thread and instance tied to this plot
	offer: string?, -- egg id the last spin landed on, until bought or spun again
	offerModel: Model?, -- the egg on the spinner, once the spin animation has finished
	lastSpin: number, -- os.clock() of the last spin, for the cooldown
	spinSerial: number, -- bumped on every spin so a stale reveal does nothing
}

local REQUIRED_PARTS = { "Base", "Spawn", "LuckBoard", "Spinner" }

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
	local function requireNumbered(folderName: string, prefix: string, count: number)
		local folder = plot:FindFirstChild(folderName)
		assert(folder, `{plot:GetFullName()} is missing folder {folderName}`)
		for index = 1, count do
			local part = folder:FindFirstChild(`{prefix}{index}`)
			assert(part and part:IsA("BasePart"), `{plot:GetFullName()} is missing {folderName}.{prefix}{index}`)
		end
	end
	requireNumbered("Pedestals", "Pedestal", Economy.PedestalCount)
	requireNumbered("Buttons", "Button", Economy.PedestalCount)
	requireNumbered("Incubators", "Incubator", Economy.IncubatorCount)
end

-- A numbered part, such as Part(plot, "Pedestals", "Pedestal", "3").
function PlotService.Part(plot: Model, folderName: string, prefix: string, key: string): BasePart
	return (plot:FindFirstChild(folderName) :: Folder):FindFirstChild(`{prefix}{key}`) :: BasePart
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
		pets = {},
		eggs = {},
		janitor = Janitor.new(),
		offer = nil,
		offerModel = nil,
		lastSpin = 0,
		spinSerial = 0,
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
	table.clear(state.pets)
	table.clear(state.eggs)
	state.plot:SetAttribute("OwnerUserId", 0)
	state.plot:SetAttribute("OwnerName", nil)
	table.insert(freePlots, state.plot)
end

return PlotService
