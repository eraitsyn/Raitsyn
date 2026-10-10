--[[
	MapBuilder: builds the world when the place has no workspace.Lanes.

	Every player gets a lane of their own: a base at the front, then all eleven
	biomes in order behind it, each with its own roll station and an unlock
	gate. Lanes are side by side. Everything is parts built in code, so the game
	runs straight away; replace any part with a real build that keeps its name.

	Lane layout, in the lane's own space (biomes run toward -Z):
	  Base (z 0..90), Spawn, Collector, UpgradeStation,
	  Platforms/Platform1..12, HatchSlots/Slot1..8, Decor/<biome id>,
	  Biomes/<biome id>/{Ground, Station, Arrival, Gate (not on the first biome)}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local ModelFactory = require(script.Parent.ModelFactory)
local Props = require(script.Parent.Props)

local LANE_COUNT = 6
local LANE_SPACING = 130
local LANE_WIDTH = 100
local BASE_DEPTH = 90
local BIOME_DEPTH = 80
local WALL_HEIGHT = 16
local PROPS_PER_BIOME = 12

local MapBuilder = {}

MapBuilder.LaneCount = LANE_COUNT

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.CFrame = cframe
	newPart.Color = color
	newPart.Material = material or Enum.Material.SmoothPlastic
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

local function sign(adornee: BasePart, text: string, color: Color3, size: Vector2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = size
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

local function buildBase(lane: Model, origin: CFrame)
	local center = origin * CFrame.new(0, 0, BASE_DEPTH / 2)
	local base = part(
		"Base",
		Vector3.new(LANE_WIDTH, 1, BASE_DEPTH),
		center,
		Color3.fromRGB(205, 160, 110),
		lane,
		Enum.Material.WoodPlanks
	)
	lane.PrimaryPart = base
	-- A low rim so the base reads as one place.
	for _, side in { -1, 1 } do
		part(
			"Rim",
			Vector3.new(1, 2, BASE_DEPTH),
			origin * CFrame.new(side * LANE_WIDTH / 2, 1, BASE_DEPTH / 2),
			Color3.fromRGB(150, 110, 70),
			lane,
			Enum.Material.Wood
		)
	end
	part(
		"Rim",
		Vector3.new(LANE_WIDTH, 2, 1),
		origin * CFrame.new(0, 1, BASE_DEPTH),
		Color3.fromRGB(150, 110, 70),
		lane,
		Enum.Material.Wood
	)

	local spawnPart =
		part("Spawn", Vector3.new(8, 1, 8), origin * CFrame.new(0, 0.6, 14), Color3.fromRGB(255, 255, 255), lane)
	spawnPart.Transparency = 0.5
	spawnPart.CanCollide = false

	local collector = part(
		"Collector",
		Vector3.new(9, 1, 9),
		origin * CFrame.new(38, 1, 12),
		Color3.fromRGB(70, 230, 90),
		lane,
		Enum.Material.Neon
	)
	collector.Shape = Enum.PartType.Block

	local station = part(
		"UpgradeStation",
		Vector3.new(10, 7, 1.5),
		origin * CFrame.new(38, 4, 28) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(60, 120, 230),
		lane
	)
	sign(station, "UPGRADES", Color3.new(1, 1, 1), Vector2.new(400, 200))

	local platforms = folder("Platforms", lane)
	local slot = 0
	for _, z in { 32, 50, 68 } do
		for _, x in { -27, -9, 9, 27 } do
			slot += 1
			local platform = part(
				`Platform{slot}`,
				Vector3.new(11, 1.5, 11),
				origin * CFrame.new(x, 1.25, z),
				Color3.fromRGB(90, 160, 240),
				platforms
			)
			platform.Material = Enum.Material.SmoothPlastic
		end
	end
	assert(
		slot >= Economy.Upgrades[2].start + Economy.Upgrades[2].perLevel * Economy.Upgrades[2].maxLevel,
		"not enough platforms"
	)

	local hatchSlots = folder("HatchSlots", lane)
	for index = 1, 8 do
		local slotPart = part(
			`Slot{index}`,
			Vector3.new(7, 1, 7),
			origin * CFrame.new(-43, 1, 6 + index * 9.5),
			Color3.fromRGB(250, 170, 60),
			hatchSlots,
			Enum.Material.Neon
		)
		slotPart.Transparency = 0.1
	end

	local decor = folder("Decor", lane)
	for index, biome in PetConfig.Biomes do
		local anchor = part(
			biome.id,
			Vector3.new(6, 0.2, 6),
			origin * CFrame.new(-34 + (index - 1) * 7, 0.6, BASE_DEPTH - 6),
			Color3.new(1, 1, 1),
			decor
		)
		anchor.Transparency = 1
		anchor.CanCollide = false
	end
end

local function buildBiome(origin: CFrame, biome: any, biomesFolder: Folder, laneIndex: number)
	local biomeFolder = folder(biome.id, biomesFolder)
	local startZ = -(biome.index - 1) * BIOME_DEPTH
	local centerZ = startZ - BIOME_DEPTH / 2

	part(
		"Ground",
		Vector3.new(LANE_WIDTH, 1, BIOME_DEPTH),
		origin * CFrame.new(0, 0, centerZ),
		rgb(biome.ground),
		biomeFolder,
		Enum.Material[biome.material]
	)
	for _, side in { -1, 1 } do
		local wall = part(
			"Wall",
			Vector3.new(1, WALL_HEIGHT, BIOME_DEPTH),
			origin * CFrame.new(side * LANE_WIDTH / 2, WALL_HEIGHT / 2, centerZ),
			rgb(biome.accent),
			biomeFolder
		)
		wall.Transparency = 0.85
	end

	-- The roll station: a round pad with an arch and a big name sign.
	local station = part(
		"Station",
		Vector3.new(2, 12, 12),
		origin * CFrame.new(0, 1.5, centerZ) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(biome.accent),
		biomeFolder,
		Enum.Material.SmoothPlastic
	)
	station.Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		part(
			"ArchPost",
			Vector3.new(1.5, 12, 1.5),
			origin * CFrame.new(side * 7, 6, centerZ + 4),
			Color3.fromRGB(255, 255, 255),
			biomeFolder
		)
	end
	local archTop = part(
		"ArchSign",
		Vector3.new(16, 3.5, 1),
		origin * CFrame.new(0, 13, centerZ + 4),
		rgb(biome.accent),
		biomeFolder
	)
	sign(archTop, `{biome.name} Eggs`, Color3.new(1, 1, 1), Vector2.new(600, 130))
	local back = part(
		"ArchSignBack",
		Vector3.new(16, 3.5, 0.1),
		origin * CFrame.new(0, 13, centerZ + 4.55) * CFrame.Angles(0, math.pi, 0),
		rgb(biome.accent),
		biomeFolder
	)
	back.CanCollide = false
	sign(back, `{biome.name} Eggs`, Color3.new(1, 1, 1), Vector2.new(600, 130))

	local arrival = part(
		"Arrival",
		Vector3.new(4, 1, 4),
		origin * CFrame.new(0, 0.55, startZ - 10),
		Color3.new(1, 1, 1),
		biomeFolder
	)
	arrival.Transparency = 1
	arrival.CanCollide = false

	if biome.index > 1 then
		local gate = part(
			"Gate",
			Vector3.new(LANE_WIDTH, WALL_HEIGHT, 2),
			origin * CFrame.new(0, WALL_HEIGHT / 2, startZ),
			rgb(biome.accent),
			biomeFolder,
			Enum.Material.ForceField
		)
		gate.Transparency = 0.3
		local label = ModelFactory.Tag(gate, 2, {
			{ `{biome.name}`, Color3.new(1, 1, 1) },
			{ `Unlock: {Format.Cash(biome.unlockCost)}`, Color3.fromRGB(120, 255, 120) },
		})
		label.Name = "GateTag"
		label.Size = UDim2.fromScale(24, 6)
		label.MaxDistance = 200
	end

	local random = Random.new(laneIndex * 1000 + biome.index)
	local props = folder("Props", biomeFolder)
	for _ = 1, PROPS_PER_BIOME do
		local side = if random:NextNumber() < 0.5 then -1 else 1
		local x = side * random:NextNumber(14, LANE_WIDTH / 2 - 6)
		local z = centerZ + random:NextNumber(-BIOME_DEPTH / 2 + 6, BIOME_DEPTH / 2 - 6)
		local prop = Props.Build(biome.id, random)
		prop:PivotTo(origin * CFrame.new(x, 0.5, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
		prop.Parent = props
	end
end

local function buildLane(index: number): Model
	local origin = CFrame.new((index - (LANE_COUNT + 1) / 2) * LANE_SPACING, 0, 0)
	local lane = Instance.new("Model")
	lane.Name = `Lane{index}`
	buildBase(lane, origin)
	local biomes = folder("Biomes", lane)
	for _, biome in PetConfig.Biomes do
		buildBiome(origin, biome, biomes, index)
	end
	-- Close the far end so nobody can walk around the gates.
	local endWall = part(
		"EndWall",
		Vector3.new(LANE_WIDTH, WALL_HEIGHT, 1),
		origin * CFrame.new(0, WALL_HEIGHT / 2, -#PetConfig.Biomes * BIOME_DEPTH),
		Color3.fromRGB(255, 255, 255),
		biomes
	)
	endWall.Transparency = 0.85
	lane.WorldPivot = origin
	return lane
end

function MapBuilder.BuildIfMissing()
	if workspace:FindFirstChild("Lanes") then
		return
	end
	local lanes = Instance.new("Folder")
	lanes.Name = "Lanes"
	for index = 1, LANE_COUNT do
		buildLane(index).Parent = lanes
	end
	-- A plain floor between lanes and in front of the bases.
	local floor = part(
		"Floor",
		Vector3.new(LANE_COUNT * LANE_SPACING + 60, 1, BASE_DEPTH + #PetConfig.Biomes * BIOME_DEPTH + 60),
		CFrame.new(0, -0.6, (BASE_DEPTH - #PetConfig.Biomes * BIOME_DEPTH) / 2),
		Color3.fromRGB(120, 190, 90),
		lanes,
		Enum.Material.Grass
	)
	floor.Name = "Floor"
	lanes.Parent = workspace
end

return MapBuilder
