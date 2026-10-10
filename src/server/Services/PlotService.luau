--[[
	PlotService: assigns lanes and owns each player's server-side PlotState.

	Expected lane layout (see MapBuilder and README):
	  workspace.Lanes.<Lane>                 Model, PrimaryPart = Base
	    Base, Spawn, Collector, UpgradeStation
	    Platforms/Platform1..12, HatchSlots/Slot1..8, Decor/<biome id>
	    Biomes/<biome id>/Station, Arrival, and Gate on every biome after the first
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Janitor = require(ReplicatedStorage.Shared.Janitor)
local DataSchema = require(script.Parent.Parent.DataSchema)

export type PlotState = {
	player: Player,
	plot: Model, -- the player's lane
	data: DataSchema.PlayerData, -- the saved profile data; the source of truth
	janitor: Janitor.Janitor, -- every connection, thread and instance tied to this lane
	offers: { [string]: string }, -- biome id -> egg id on offer at that station
	lastRoll: { [string]: number }, -- biome id -> os.clock() of the last roll
	petModels: { [string]: Model }, -- platform key -> pet model shown there
	eggModels: { [string]: Model }, -- hatch slot key -> egg model shown there
}

local REQUIRED_PARTS = { "Base", "Spawn", "Collector", "UpgradeStation" }
local PLATFORM_COUNT = 12
local HATCH_SLOT_COUNT = 8

local states: { [Player]: PlotState } = {}
local freePlots: { Model } = {}

local PlotService = {}

local function checkPlot(plot: Instance)
	local name = plot:GetFullName()
	assert(plot:IsA("Model"), `{name} must be a Model`)
	assert(plot.PrimaryPart, `{name} needs PrimaryPart set to Base`)
	for _, partName in REQUIRED_PARTS do
		local part = plot:FindFirstChild(partName)
		assert(part and part:IsA("BasePart"), `{name} is missing part {partName}`)
	end
	local function requireNumbered(folderName: string, prefix: string, count: number)
		local folder = plot:FindFirstChild(folderName)
		assert(folder, `{name} is missing folder {folderName}`)
		for index = 1, count do
			local part = folder:FindFirstChild(`{prefix}{index}`)
			assert(part and part:IsA("BasePart"), `{name} is missing {folderName}.{prefix}{index}`)
		end
	end
	requireNumbered("Platforms", "Platform", PLATFORM_COUNT)
	requireNumbered("HatchSlots", "Slot", HATCH_SLOT_COUNT)

	for _, biome in PetConfig.Biomes do
		local biomeFolder = plot:FindFirstChild("Biomes") and plot.Biomes:FindFirstChild(biome.id)
		assert(biomeFolder, `{name} is missing Biomes.{biome.id}`)
		local required = { "Station", "Arrival" }
		if biome.index > 1 then
			table.insert(required, "Gate")
		end
		for _, partName in required do
			local part = biomeFolder:FindFirstChild(partName)
			assert(part and part:IsA("BasePart"), `{name} is missing Biomes.{biome.id}.{partName}`)
		end
		assert(
			plot:FindFirstChild("Decor") and plot.Decor:FindFirstChild(biome.id),
			`{name} is missing Decor.{biome.id}`
		)
	end
end

-- A numbered part, such as Part(plot, "Platforms", "Platform", "3").
function PlotService.Part(plot: Model, folderName: string, prefix: string, key: string): BasePart
	return (plot:FindFirstChild(folderName) :: Folder):FindFirstChild(`{prefix}{key}`) :: BasePart
end

-- A part inside a biome's folder, such as BiomePart(plot, "Forest", "Gate").
function PlotService.BiomePart(plot: Model, biomeId: string, name: string): BasePart
	return ((plot:FindFirstChild("Biomes") :: Folder):FindFirstChild(biomeId) :: Folder):FindFirstChild(
			name
		) :: BasePart
end

function PlotService.Init()
	local folder = workspace:WaitForChild("Lanes")
	local plots = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	for _, plot in plots do
		checkPlot(plot)
		plot:SetAttribute("OwnerUserId", 0)
		table.insert(freePlots, plot :: Model)
	end
	assert(#freePlots > 0, "workspace.Lanes has no lanes")
end

-- Gives the player a free lane. Returns nil when every lane is taken.
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
		janitor = Janitor.new(),
		offers = {},
		lastRoll = {},
		petModels = {},
		eggModels = {},
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

-- Cleans up everything tied to the lane and returns it to the free list.
function PlotService.Release(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	states[player] = nil
	state.janitor:Destroy()
	state.plot:SetAttribute("OwnerUserId", 0)
	state.plot:SetAttribute("OwnerName", nil)
	table.insert(freePlots, state.plot)
end

return PlotService
