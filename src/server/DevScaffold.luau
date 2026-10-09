--[[
	DevScaffold: builds a placeholder map in Studio when none exists, so the
	game can be played without any building first.

	It never runs in a live server (Main only calls it in Studio) and never
	touches a place that already has workspace.Plots or workspace.Lane.
	Replace the placeholders with real builds that keep the same names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local PLOT_ORIGINS = {
	CFrame.new(-55, 0, 60),
	CFrame.new(55, 0, 60),
	CFrame.new(-55, 0, -60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(55, 0, -60) * CFrame.Angles(0, math.pi, 0),
}
local PLOT_COLORS = {
	Color3.fromRGB(110, 160, 90),
	Color3.fromRGB(90, 140, 170),
	Color3.fromRGB(170, 130, 90),
	Color3.fromRGB(150, 100, 160),
}
local SLOT_COLUMNS = { -27, -9, 9, 27 }
local SLOT_ROWS = { -14, 2, 18 } -- front row faces the lane (local -Z)

local DevScaffold = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Color = color
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.Parent = parent
	return newPart
end

local function buildLane(): Model
	local lane = Instance.new("Model")
	lane.Name = "Lane"
	part("Belt", Vector3.new(220, 1, 10), CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 40, 45), lane)
	local laneStart =
		part("LaneStart", Vector3.new(4, 1, 10), CFrame.new(-108, 0.5, 0), Color3.fromRGB(255, 200, 60), lane)
	laneStart.Material = Enum.Material.Neon
	local laneEnd = part("LaneEnd", Vector3.new(4, 1, 10), CFrame.new(108, 0.5, 0), Color3.fromRGB(255, 80, 80), lane)
	laneEnd.Material = Enum.Material.Neon
	return lane
end

local function buildPlot(index: number): Model
	local origin = PLOT_ORIGINS[index]
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`

	local base = part("Base", Vector3.new(80, 1, 60), origin, PLOT_COLORS[index], plot)
	plot.PrimaryPart = base
	part("Spawn", Vector3.new(6, 1, 6), origin * CFrame.new(0, 1, 22), Color3.fromRGB(220, 220, 220), plot)
	local collectPad = part(
		"CollectPad",
		Vector3.new(8, 0.4, 8),
		origin * CFrame.new(-34, 0.7, 24),
		Color3.fromRGB(60, 200, 120),
		plot
	)
	collectPad.Material = Enum.Material.Neon

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	local slotIndex = 0
	for _, z in SLOT_ROWS do
		for _, x in SLOT_COLUMNS do
			slotIndex += 1
			if slotIndex > Economy.SlotsPerBase then
				break
			end
			part(
				`Slot{slotIndex}`,
				Vector3.new(10, 0.4, 10),
				origin * CFrame.new(x, 0.7, z),
				Color3.fromRGB(235, 235, 235),
				slots
			)
		end
	end
	slots.Parent = plot
	return plot
end

function DevScaffold.BuildIfMissing()
	assert(Economy.SlotsPerBase <= #SLOT_COLUMNS * #SLOT_ROWS, "DevScaffold has room for 12 slots")
	if workspace:FindFirstChild("Lane") == nil then
		buildLane().Parent = workspace
		warn("[DevScaffold] built placeholder workspace.Lane")
	end
	if workspace:FindFirstChild("Plots") == nil then
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		for index in PLOT_ORIGINS do
			buildPlot(index).Parent = plots
		end
		plots.Parent = workspace
		warn("[DevScaffold] built placeholder workspace.Plots")
	end
end

return DevScaffold
