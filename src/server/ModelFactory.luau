--[[
	ModelFactory: placeholder pet and egg models built from config, with name
	tags. Swap BuildPet and BuildEgg for real models later; the rest of the game
	only needs a Model with a PrimaryPart, built around the origin, facing -Z,
	standing on y = 0.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local rarityColors: { [string]: Color3 } = {}
for _, rarity in PetConfig.Rarities do
	rarityColors[rarity.name] = rgb(rarity.color)
end

local eggsById: { [string]: any } = {}
for _, egg in PetConfig.Eggs do
	eggsById[egg.id] = egg
end

local ModelFactory = {}

ModelFactory.RarityColor = rarityColors

local function block(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A billboard with one text row per line: { text, color }.
function ModelFactory.Tag(adornee: BasePart, height: number, lines: { { any } }): BillboardGui
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(170, 24 * #lines)
	tag.StudsOffset = Vector3.new(0, height, 0)
	tag.MaxDistance = 80
	tag.Adornee = adornee
	for index, line in lines do
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = `Line{index}`
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1 / #lines)
		textLabel.Position = UDim2.fromScale(0, (index - 1) / #lines)
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.TextColor3 = line[2]
		textLabel.TextStrokeTransparency = 0.3
		textLabel.Text = line[1]
		textLabel.Parent = tag
	end
	tag.Parent = adornee
	return tag
end

function ModelFactory.BuildPet(petId: string): Model
	local pet = PetConfig.Pets[petId]
	assert(pet, `Unknown pet {petId}`)
	local color = rgb(pet.color)
	local rarityColor = rarityColors[pet.rarity]

	local model = Instance.new("Model")
	model.Name = petId
	local body = block(model, "Body", Vector3.new(2, 1.6, 3), Vector3.new(0, 1.8, 0), color)
	block(model, "Head", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 2.8, -1.6), color)
	block(model, "LeftEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(-0.5, 3.9, -1.6), color)
	block(model, "RightEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(0.5, 3.9, -1.6), color)
	block(model, "LeftEye", Vector3.new(0.3, 0.3, 0.1), Vector3.new(-0.4, 3, -2.45), Color3.new(0, 0, 0))
	block(model, "RightEye", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0.4, 3, -2.45), Color3.new(0, 0, 0))
	for index, offset in
		{ Vector3.new(-0.7, 0.5, -1), Vector3.new(0.7, 0.5, -1), Vector3.new(-0.7, 0.5, 1), Vector3.new(0.7, 0.5, 1) }
	do
		block(model, `Leg{index}`, Vector3.new(0.5, 1, 0.5), offset, color)
	end
	if pet.rarity == "Legendary" or pet.rarity == "Mythical" or pet.rarity == "Secret" then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 12
		light.Brightness = 2
		light.Parent = body
	end

	ModelFactory.Tag(body, 3.5, {
		{ pet.name, Color3.new(1, 1, 1) },
		{ pet.rarity, rarityColor },
		{ `${pet.income}/s`, Color3.fromRGB(120, 255, 120) },
	})

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

function ModelFactory.BuildEgg(eggId: string): Model
	local egg = eggsById[eggId]
	assert(egg, `Unknown egg {eggId}`)
	local model = Instance.new("Model")
	model.Name = eggId
	local shell = block(model, "Shell", Vector3.new(2.4, 3, 2.4), Vector3.new(0, 1.5, 0), rgb(egg.color))
	shell.Shape = Enum.PartType.Ball
	-- A ball takes its smallest axis, so stretch it with a mesh instead.
	shell.Size = Vector3.new(2.4, 2.4, 2.4)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.25, 1)
	mesh.Parent = shell
	model.PrimaryPart = shell
	model.WorldPivot = CFrame.new()
	return model
end

-- Places a model so it stands on top of `surface`, facing the same way.
function ModelFactory.StandOn(model: Model, surface: BasePart)
	model:PivotTo(surface.CFrame * CFrame.new(0, surface.Size.Y / 2, 0))
end

return ModelFactory
