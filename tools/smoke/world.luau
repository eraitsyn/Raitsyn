--!strict
-- Smoke test for everything that builds Roblox instances on the server:
-- the map, every pet and egg model, and a fully stocked farm. It runs the
-- real modules from the built place file against Roblox's reflection data,
-- so invalid properties fail here instead of in a live server.
--
-- Usage (after `rojo build -o RollRNG.rbxl`): lune run tools/smoke/world -- RollRNG.rbxl

local process = require("@lune/process")
local PlaceRuntime = require("./PlaceRuntime")

local placePath = "RollRNG.rbxl"
for _, arg in process.args do
	if arg ~= "--" then
		placePath = arg
	end
end
local runtime = PlaceRuntime.load(placePath)
local game = runtime.game
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server
local Map = runtime.require(Shared.Config.Map)
local Pets = runtime.require(Shared.Config.Pets)
local Rarities = runtime.require(Shared.Config.Rarities)
local PetModel = runtime.require(Shared.Models.PetModel)
local EggModel = runtime.require(Shared.Models.EggModel)
local MapBuilder = runtime.require(Server.World.MapBuilder)
local FarmService = runtime.require(Server.Services.FarmService)
local Schema = runtime.require(Server.Data.Schema)

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print(`  FAIL  {message}`)
	end
end

print("World")
local world = MapBuilder.build(game:GetService("Workspace"))
check(#world.plots == 8, "eight plots")
local partCount = 0
for _, d in world.model:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
print(`  built {partCount} parts`)
check(partCount < 6000, "world stays under 6,000 parts")

-- Plots must not overlap each other, the hub stations, or the map edge.
local half = Map.bounds / 2
local rects = {}
for _, plot in world.plots do
	local p = plot.cframe.Position
	local rect = {
		x0 = p.X - Map.plotWidth / 2,
		x1 = p.X + Map.plotWidth / 2,
		z0 = p.Z - Map.plotDepth / 2,
		z1 = p.Z + Map.plotDepth / 2,
	}
	check(
		rect.x0 >= -half.X and rect.x1 <= half.X and rect.z0 >= -half.Y and rect.z1 <= half.Y,
		`plot {plot.index} inside the map`
	)
	for _, other in rects do
		local overlap = rect.x0 < other.x1 and other.x0 < rect.x1 and rect.z0 < other.z1 and other.z0 < rect.z1
		check(not overlap, `plot {plot.index} overlaps another plot`)
	end
	for _, station in { Map.plaza, Map.upgradeShop, Map.rebirthStation, Map.indexBoard, Map.dailyKiosk } do
		local inside = station.X > rect.x0 and station.X < rect.x1 and station.Z > rect.z0 and station.Z < rect.z1
		check(not inside, `plot {plot.index} covers a hub station`)
	end
	table.insert(rects, rect)
	-- gate faces the hub: the gate point is closer to the origin than the plot centre
	local gate = (plot.cframe * PlaceRuntime.CFrame.new(Map.gate)).Position
	check(gate.Magnitude < p.Magnitude, `plot {plot.index} gate faces the hub`)
	check(#plot.pads == 24 and #plot.incubators == 4, `plot {plot.index} has 24 pads and 4 incubators`)
	-- pads sit inside the plot
	for _, pad in plot.pads do
		local local_ = plot.cframe:PointToObjectSpace(pad.CFrame.Position)
		check(
			math.abs(local_.X) < Map.plotWidth / 2 and math.abs(local_.Z) < Map.plotDepth / 2,
			`pad inside plot {plot.index}`
		)
	end
end
-- Straight-line distance from each gate to the plaza edge: about 10 seconds
-- at most at the default walk speed (the HUD also has Home and Hub teleports).
for _, plot in world.plots do
	local gate = (plot.cframe * PlaceRuntime.CFrame.new(Map.gate)).Position
	local walk = gate.Magnitude - Map.plazaRadius
	check(walk < 170, `plot {plot.index} gate is a short walk from the Plaza ({math.floor(walk)} studs)`)
end

print("Models")
local modelCount = 0
for _, species in Pets.list do
	for _, variant in Pets.variants do
		local model, height = PetModel.build(species.id, variant.id)
		check(model.PrimaryPart ~= nil, `{species.id} has a PrimaryPart`)
		check(height > 1 and height < 12, `{species.id} height {height} is sensible`)
		local target = PlaceRuntime.CFrame.new(10, 5, 10)
		model:PivotTo(target)
		local body = model:FindFirstChild("Body")
		check(body ~= nil, `{species.id} has a Body part`)
		if body then
			check(body.CFrame.Position.Y > 5, `{species.id} stands above its pivot`)
		end
		model:Destroy()
		modelCount += 1
	end
end
for _, rarity in Rarities.list do
	local egg = EggModel.build(rarity.id)
	egg:PivotTo(PlaceRuntime.CFrame.new(0, 10, 0))
	local shell = egg:FindFirstChild("Shell")
	check(shell ~= nil and math.abs(shell.CFrame.Position.Y - 11.5) < 1e-3, `{rarity.id} egg sits on its pivot`)
	egg:Destroy()
	modelCount += 1
end
print(`  built {modelCount} models`)

print("Farm render")
local data = Schema.template()
local species = Pets.list
for pad = 1, 24 do
	local id = `p{pad}`
	data.pets[id] = { s = species[(pad - 1) % #species + 1].id, v = pad % 3, t = pad, lk = false }
	data.placed[tostring(pad)] = id
end
for i, rarity in { "Common", "Epic", "Mythic", "Secret" } do
	data.incubator[i] = { r = rarity, start = 0, done = 10 }
end
local plot = world.plots[3]
FarmService.render(plot, { data = data, padSlots = 24, incubators = 4, incomeMultiplier = 2 })
local pets, eggs = 0, 0
for _, child in plot.petsFolder:GetChildren() do
	if child:GetAttribute("PetId") then
		pets += 1
		check(child:FindFirstChild("Label") ~= nil, "placed pet has a label")
	elseif child:GetAttribute("Incubator") then
		eggs += 1
	end
end
check(pets == 24, `24 pets rendered (got {pets})`)
check(eggs == 4, `4 eggs rendered (got {eggs})`)
-- re-render with fewer pads: extra pets disappear, nothing duplicates
FarmService.render(plot, { data = data, padSlots = 6, incubators = 1, incomeMultiplier = 2 })
pets = 0
for _, child in plot.petsFolder:GetChildren() do
	if child:GetAttribute("PetId") then
		pets += 1
	end
end
check(pets == 6, `6 pets after pads shrink (got {pets})`)
check(plot.padLocks[7].Enabled and not plot.padLocks[6].Enabled, "pad 7 shows a lock, pad 6 does not")
FarmService.clear(plot)
check(#plot.petsFolder:GetChildren() == 0, "clearing a farm removes every model")

if failures > 0 then
	print(`\n{failures} smoke checks failed`)
	process.exit(1)
end
print("\nSmoke checks passed")
