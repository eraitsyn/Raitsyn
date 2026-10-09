--[[
	PlotService: assigns plots and owns each player's server-side PlotState.

	Expected plot layout (see README):
	  workspace.Plots.<Plot>          Model, PrimaryPart = Base
	    Base, Spawn, Collector, CollectPad   BaseParts
	    Buttons/<buttonId>             one BasePart pad per button id
	    Items/                         purchased items are cloned here
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Shared.Config.Buttons)
local Janitor = require(ReplicatedStorage.Shared.Janitor)
local DataSchema = require(script.Parent.Parent.DataSchema)

export type PlotState = {
	player: Player,
	plot: Model,
	data: DataSchema.PlayerData, -- the saved profile data; Purchased and StoredCash live here
	busy: boolean, -- purchase and rebirth lock
	janitor: Janitor.Janitor, -- every connection, thread and instance tied to this plot
}

local REQUIRED_PARTS = { "Base", "Spawn", "Collector", "CollectPad" }

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
	assert(plot:FindFirstChild("Items"), `{plot:GetFullName()} is missing folder Items`)
	local pads = plot:FindFirstChild("Buttons")
	assert(pads, `{plot:GetFullName()} is missing folder Buttons`)
	for id in Buttons do
		local pad = pads:FindFirstChild(id)
		assert(pad and pad:IsA("BasePart"), `{plot:GetFullName()} is missing button pad {id}`)
	end
end

-- Hides every pad and removes every purchased item.
function PlotService.ResetPlot(plot: Model)
	local items = plot:FindFirstChild("Items") :: Folder
	local pads = plot:FindFirstChild("Buttons") :: Folder
	items:ClearAllChildren()
	for _, pad in pads:GetChildren() do
		if pad:IsA("BasePart") then
			pad.Transparency = 1
			pad.CanCollide = false
		end
	end
	plot:SetAttribute("StoredCash", 0)
end

function PlotService.Init()
	local folder = workspace:WaitForChild("Plots")
	local plots = folder:GetChildren()
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	for _, plot in plots do
		checkPlot(plot)
		for _, pad in plot.Buttons:GetChildren() do
			if pad:IsA("BasePart") and pad:GetAttribute("ShownTransparency") == nil then
				pad:SetAttribute("ShownTransparency", pad.Transparency)
			end
		end
		plot:SetAttribute("OwnerUserId", 0)
		PlotService.ResetPlot(plot)
		table.insert(freePlots, plot)
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
	local state: PlotState = {
		player = player,
		plot = plot,
		data = data,
		busy = false,
		janitor = Janitor.new(),
	}
	states[player] = state
	return state
end

function PlotService.Get(player: Player): PlotState?
	return states[player]
end

-- Cleans up everything tied to the plot and returns it to the free list.
function PlotService.Release(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	states[player] = nil
	state.janitor:Destroy()
	PlotService.ResetPlot(state.plot)
	state.plot:SetAttribute("OwnerUserId", 0)
	table.insert(freePlots, state.plot)
end

return PlotService
