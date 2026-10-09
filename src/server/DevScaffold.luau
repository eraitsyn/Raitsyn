--[[
	DevScaffold: builds placeholder plots and items in Studio when none exist,
	so the systems can be played without any building first.

	It never runs in a live server (Main only calls it in Studio) and never
	touches a place that already has workspace.Plots or ServerStorage.Items.
	Replace the placeholders with real models that follow the same names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Buttons = require(ReplicatedStorage.Shared.Config.Buttons)
local ButtonGraph = require(ReplicatedStorage.Shared.ButtonGraph)

local PLOT_COUNT = 4
local PLOT_SPACING = 120

local DevScaffold = {}

local function part(props: { [string]: any }): Part
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(newPart :: any)[key] = value
	end
	return newPart
end

-- Item templates are built around the origin; PurchaseService moves them onto the plot.
local function buildItems(): Folder
	local items = Instance.new("Folder")
	items.Name = "Items"

	local function model(name: string, parts: { Part }): Model
		local newModel = Instance.new("Model")
		newModel.Name = name
		for _, child in parts do
			child.Parent = newModel
		end
		newModel.WorldPivot = CFrame.new()
		newModel.Parent = items
		return newModel
	end

	model("Conveyor1", {
		part({
			Name = "Belt",
			Size = Vector3.new(60, 1, 4),
			Position = Vector3.new(-2, 1, 0),
			Color = Color3.fromRGB(40, 40, 40),
			AssemblyLinearVelocity = Vector3.new(10, 0, 0),
		}),
	})
	model("Dropper1", {
		part({
			Name = "DropOrigin",
			Size = Vector3.new(3, 3, 3),
			Position = Vector3.new(-26, 8, 0),
			Color = Color3.fromRGB(90, 140, 220),
		}),
	})
	model("Dropper2", {
		part({
			Name = "DropOrigin",
			Size = Vector3.new(3, 3, 3),
			Position = Vector3.new(-16, 8, 0),
			Color = Color3.fromRGB(150, 90, 220),
		}),
	})
	model("Upgrader1", {
		part({
			Name = "UpgradeZone",
			Size = Vector3.new(2, 3, 5),
			Position = Vector3.new(10, 3, 0),
			Color = Color3.fromRGB(240, 200, 60),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			CanCollide = false,
		}),
	})

	return items
end

local function buildPlot(index: number): Model
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`
	local origin = CFrame.new((index - 1) * PLOT_SPACING, 0, 0)

	local function add(child: Instance, offset: Vector3?)
		if offset and child:IsA("BasePart") then
			child.CFrame = origin * CFrame.new(offset)
		end
		child.Parent = plot
		return child
	end

	local base = add(
		part({ Name = "Base", Size = Vector3.new(100, 1, 100), Color = Color3.fromRGB(110, 160, 90) }),
		Vector3.zero
	) :: Part
	plot.PrimaryPart = base
	add(
		part({ Name = "Spawn", Size = Vector3.new(6, 1, 6), Color = Color3.fromRGB(200, 200, 200) }),
		Vector3.new(0, 1, 40)
	)
	add(
		part({ Name = "Collector", Size = Vector3.new(4, 4, 6), Color = Color3.fromRGB(220, 80, 80) }),
		Vector3.new(30, 2, 0)
	)
	add(
		part({ Name = "CollectPad", Size = Vector3.new(6, 0.2, 6), Color = Color3.fromRGB(60, 200, 120) }),
		Vector3.new(30, 0.6, 14)
	)

	local pads = Instance.new("Folder")
	pads.Name = "Buttons"
	for position, id in ButtonGraph.Order(Buttons) do
		local pad = part({
			Name = id,
			Size = Vector3.new(6, 0.2, 6),
			Color = Color3.fromRGB(60, 200, 120),
			Material = Enum.Material.Neon,
		})
		pad.CFrame = origin * CFrame.new(-36 + (position - 1) * 12, 0.6, -40)
		pad.Parent = pads
	end
	add(pads)

	local items = Instance.new("Folder")
	items.Name = "Items"
	add(items)

	return plot
end

function DevScaffold.BuildIfMissing()
	if ServerStorage:FindFirstChild("Items") == nil then
		buildItems().Parent = ServerStorage
		warn("[DevScaffold] built placeholder ServerStorage.Items")
	end
	if workspace:FindFirstChild("Plots") == nil then
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		for index = 1, PLOT_COUNT do
			buildPlot(index).Parent = plots
		end
		plots.Parent = workspace
		warn("[DevScaffold] built placeholder workspace.Plots")
	end
end

return DevScaffold
