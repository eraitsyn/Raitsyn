--[[
	DevScaffold: builds placeholder bases in Studio when none exist, so the game
	can be played without any building first.

	It never runs in a live server (Main only calls it in Studio) and never
	touches a place that already has workspace.Plots. Replace the placeholders
	with real builds that keep the same names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)

-- Four bases in a square, each with its front (local -Z) facing the middle.
local PLOT_ORIGINS = {
	CFrame.new(-50, 0, 45),
	CFrame.new(50, 0, 45),
	CFrame.new(-50, 0, -45) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(50, 0, -45) * CFrame.Angles(0, math.pi, 0),
}
local FLOOR = Color3.fromRGB(190, 120, 70)
local PEDESTAL = Color3.fromRGB(90, 160, 240)
local BUTTON = Color3.fromRGB(80, 230, 80)

local PEDESTAL_COLUMNS = { -18, -6, 6, 18 }
local PEDESTAL_ROWS = { -4, 12 }
local INCUBATOR_ROWS = { -10, -1, 8, 17 }
local SHOP_COLUMNS = { -20, 0, 20 }

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

local function folder(name: string, parent: Instance): Folder
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

local function buildPlot(index: number): Model
	local origin = PLOT_ORIGINS[index]
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`

	local base = part("Base", Vector3.new(80, 1, 60), origin, FLOOR, plot)
	base.Material = Enum.Material.WoodPlanks
	plot.PrimaryPart = base
	part("Spawn", Vector3.new(6, 1, 6), origin * CFrame.new(0, 1, 24), Color3.fromRGB(230, 230, 230), plot)
	local luckBoard =
		part("LuckBoard", Vector3.new(6, 6, 1), origin * CFrame.new(34, 4, -10), Color3.fromRGB(60, 200, 90), plot)
	luckBoard.Material = Enum.Material.SmoothPlastic

	local shop = folder("Shop", plot)
	assert(#PetConfig.Eggs <= #SHOP_COLUMNS, "DevScaffold has room for 3 egg stands")
	for position, egg in PetConfig.Eggs do
		part(egg.id, Vector3.new(6, 2, 6), origin * CFrame.new(SHOP_COLUMNS[position], 1.5, -22), PEDESTAL, shop)
	end

	local incubators = folder("Incubators", plot)
	for slot = 1, Economy.IncubatorCount do
		local incubator = part(
			`Incubator{slot}`,
			Vector3.new(6, 1, 6),
			origin * CFrame.new(-34, 1, INCUBATOR_ROWS[slot]),
			Color3.fromRGB(250, 170, 60),
			incubators
		)
		incubator.Material = Enum.Material.Neon
	end

	local pedestals = folder("Pedestals", plot)
	local buttons = folder("Buttons", plot)
	local slot = 0
	for _, z in PEDESTAL_ROWS do
		for _, x in PEDESTAL_COLUMNS do
			slot += 1
			part(`Pedestal{slot}`, Vector3.new(8, 1.5, 8), origin * CFrame.new(x, 1.25, z), PEDESTAL, pedestals)
			-- A flat round button in front of the pedestal (cylinders run along X, so stand it up).
			local button = part(
				`Button{slot}`,
				Vector3.new(0.4, 4, 4),
				origin * CFrame.new(x, 0.7, z - 6.5) * CFrame.Angles(0, 0, math.pi / 2),
				BUTTON,
				buttons
			)
			button.Shape = Enum.PartType.Cylinder
			button.Material = Enum.Material.Neon
		end
	end

	return plot
end

function DevScaffold.BuildIfMissing()
	assert(Economy.PedestalCount == #PEDESTAL_COLUMNS * #PEDESTAL_ROWS, "DevScaffold lays out 8 pedestals")
	assert(Economy.IncubatorCount <= #INCUBATOR_ROWS, "DevScaffold has room for 4 incubators")
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
