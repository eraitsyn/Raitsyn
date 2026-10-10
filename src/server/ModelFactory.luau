--[[
	ModelFactory: original low-poly pet and egg models built from parts, with
	rarity effects and name tags. Swap BuildPet and BuildEgg for real models
	later; the rest of the game only needs a Model with a PrimaryPart, built
	around the origin, facing -Z, standing on y = 0.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)

-- The client animates parts with these tags.
local RAINBOW_TAG = "RainbowPart"
local GLITCH_TAG = "GlitchPart"

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local rarityColors: { [string]: Color3 } = {}
for _, rarity in PetConfig.Rarities do
	rarityColors[rarity.name] = rgb(rarity.color)
end

local ModelFactory = {}

ModelFactory.RarityColor = rarityColors
ModelFactory.Rgb = rgb

-- An anchored, non-colliding part in `model`, positioned relative to the model's origin.
function ModelFactory.Block(
	model: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame | Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end
local block = ModelFactory.Block

local function ball(model: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = block(model, name, Vector3.one * math.min(size.X, size.Y, size.Z), position, color)
	part.Shape = Enum.PartType.Ball
	if size.X ~= size.Y or size.Y ~= size.Z then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size / math.min(size.X, size.Y, size.Z)
		mesh.Parent = part
	end
	return part
end

-- A billboard with one text row per line: { text, color }.
function ModelFactory.Tag(adornee: BasePart, height: number, lines: { { any } }): BillboardGui
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(190, 24 * #lines)
	tag.StudsOffset = Vector3.new(0, height, 0)
	tag.MaxDistance = 90
	tag.Adornee = adornee
	for index, line in lines do
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = `Line{index}`
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1 / #lines)
		textLabel.Position = UDim2.fromScale(0, (index - 1) / #lines)
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextScaled = true
		textLabel.TextColor3 = line[2]
		textLabel.TextStrokeTransparency = 0.2
		textLabel.Text = line[1]
		textLabel.Parent = tag
	end
	tag.Parent = adornee
	return tag
end

-- Pet bodies --------------------------------------------------------------------

local function eyes(model: Model, y: number, z: number, spread: number)
	local black = Color3.fromRGB(20, 20, 20)
	block(model, "LeftEye", Vector3.new(0.3, 0.35, 0.1), Vector3.new(-spread, y, z), black)
	block(model, "RightEye", Vector3.new(0.3, 0.35, 0.1), Vector3.new(spread, y, z), black)
end

local BODIES: { [string]: (model: Model, color: Color3, accent: Color3) -> BasePart } = {
	beast = function(model, color, accent)
		local body = block(model, "Body", Vector3.new(2, 1.6, 3), Vector3.new(0, 1.8, 0), color)
		block(model, "Head", Vector3.new(1.7, 1.6, 1.6), Vector3.new(0, 2.8, -1.7), color)
		block(model, "Snout", Vector3.new(0.9, 0.6, 0.4), Vector3.new(0, 2.5, -2.6), accent)
		block(model, "LeftEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(-0.55, 3.9, -1.6), color)
		block(model, "RightEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(0.55, 3.9, -1.6), color)
		block(model, "Tail", Vector3.new(0.35, 0.35, 1.2), CFrame.new(0, 2.3, 1.9) * CFrame.Angles(0.6, 0, 0), color)
		eyes(model, 3.05, -2.55, 0.4)
		for index, offset in
			{
				Vector3.new(-0.7, 0.5, -1),
				Vector3.new(0.7, 0.5, -1),
				Vector3.new(-0.7, 0.5, 1),
				Vector3.new(0.7, 0.5, 1),
			}
		do
			block(model, `Leg{index}`, Vector3.new(0.55, 1, 0.55), offset, color)
		end
		return body
	end,
	bird = function(model, color, accent)
		local body = ball(model, "Body", Vector3.new(2.2, 2.2, 2.6), Vector3.new(0, 1.9, 0), color)
		ball(model, "Head", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 3.3, -0.9), color)
		block(model, "Beak", Vector3.new(0.5, 0.35, 0.7), Vector3.new(0, 3.2, -1.8), Color3.fromRGB(255, 170, 40))
		block(
			model,
			"LeftWing",
			Vector3.new(0.3, 1.2, 1.8),
			CFrame.new(-1.2, 2.1, 0.1) * CFrame.Angles(0, 0, 0.3),
			accent
		)
		block(
			model,
			"RightWing",
			Vector3.new(0.3, 1.2, 1.8),
			CFrame.new(1.2, 2.1, 0.1) * CFrame.Angles(0, 0, -0.3),
			accent
		)
		block(model, "LeftLeg", Vector3.new(0.2, 0.8, 0.2), Vector3.new(-0.4, 0.4, 0), Color3.fromRGB(255, 170, 40))
		block(model, "RightLeg", Vector3.new(0.2, 0.8, 0.2), Vector3.new(0.4, 0.4, 0), Color3.fromRGB(255, 170, 40))
		eyes(model, 3.5, -1.6, 0.35)
		return body
	end,
	fish = function(model, color, accent)
		local body = ball(model, "Body", Vector3.new(1.8, 2, 3.6), Vector3.new(0, 2.2, 0), color)
		block(model, "Tail", Vector3.new(0.3, 1.6, 1), CFrame.new(0, 2.2, 2.1) * CFrame.Angles(0.4, 0, 0), accent)
		block(model, "Fin", Vector3.new(0.25, 0.9, 1), Vector3.new(0, 3.3, 0.2), accent)
		block(model, "Stand", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 0.6, 0), Color3.fromRGB(80, 80, 90))
		eyes(model, 2.5, -1.6, 0.55)
		return body
	end,
	blob = function(model, color, accent)
		local body = ball(model, "Body", Vector3.new(3, 2.4, 3), Vector3.new(0, 1.2, 0), color)
		ball(model, "Top", Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, 2.5, 0), color)
		block(model, "Mouth", Vector3.new(0.8, 0.15, 0.1), Vector3.new(0, 1.3, -1.45), accent)
		eyes(model, 1.9, -1.4, 0.45)
		return body
	end,
}

-- Gives a pet its mutation look: gold, see-through diamond, or cycling rainbow.
local function applyMutation(model: Model, mutation: any)
	local mutationColor = rgb(mutation.color)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and not string.find(child.Name, "Eye") then
			if mutation.id == "Golden" then
				child.Color = mutationColor
				child.Material = Enum.Material.Foil
				child.Reflectance = 0.3
			elseif mutation.id == "Diamond" then
				child.Color = mutationColor
				child.Material = Enum.Material.Glass
				child.Transparency = 0.25
				child.Reflectance = 0.4
			else
				child.Material = Enum.Material.Neon
				CollectionService:AddTag(child, RAINBOW_TAG)
			end
		end
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = mutationColor
	sparkles.Parent = model.PrimaryPart
end

-- Effects that grow with rarity: sparkles, light, particles, a ring, a halo,
-- and animated colors for Secret and Cosmic.
local function applyRarity(model: Model, body: BasePart, tier: number, color: Color3)
	if tier >= 3 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Enabled = tier >= 4
		sparkles.Parent = body
	end
	if tier >= 5 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8 + tier * 2
		light.Brightness = 1 + tier * 0.3
		light.Parent = body
	end
	if tier >= 6 then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(color)
		particles.LightEmission = 1
		particles.Rate = 4 + tier * 2
		particles.Lifetime = NumberRange.new(1, 1.6)
		particles.Speed = NumberRange.new(1, 3)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.35, 0)
		particles.Parent = body
	end
	if tier >= 7 then
		local ring = block(
			model,
			"Ring",
			Vector3.new(0.2, 5, 5),
			CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.Material.Neon
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.35
	end
	if tier >= 8 then
		local halo = block(
			model,
			"Halo",
			Vector3.new(0.15, 1.8, 1.8),
			CFrame.new(0, 4.6, -0.6) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(255, 235, 140),
			Enum.Material.Neon
		)
		halo.Shape = Enum.PartType.Cylinder
	end
	if tier == 9 then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and not string.find(child.Name, "Eye") then
				CollectionService:AddTag(child, GLITCH_TAG)
			end
		end
	elseif tier >= 10 then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and not string.find(child.Name, "Eye") then
				child.Material = Enum.Material.Neon
				CollectionService:AddTag(child, RAINBOW_TAG)
			end
		end
	end
end

function ModelFactory.BuildPet(petId: string, mutationId: string?): Model
	local pet = PetConfig.Pets[petId]
	assert(pet, `Unknown pet {petId}`)
	local mutation = mutationId and PetInfo.MutationsById[mutationId]
	local tier = PetConfig.RarityIndex[pet.rarity]
	local color = rgb(pet.color)
	local accent = color:Lerp(Color3.new(1, 1, 1), 0.35)
	local rarityColor = rarityColors[pet.rarity]

	local model = Instance.new("Model")
	model.Name = petId
	local body = (BODIES[pet.shape] or BODIES.beast)(model, color, accent)
	model.PrimaryPart = body
	-- Pivot at the model's origin (its feet), so StandOn and ScaleTo work from the ground up.
	body.PivotOffset = body.CFrame:Inverse()

	if mutation then
		applyMutation(model, mutation)
	end
	applyRarity(model, body, tier, rarityColor)
	-- Rarer pets are a little bigger.
	model:ScaleTo(1 + 0.07 * (tier - 1))

	ModelFactory.Tag(body, 3.5 + 0.2 * tier, {
		{ PetInfo.Name(petId, mutationId), if mutation then rgb(mutation.color) else Color3.new(1, 1, 1) },
		{ pet.rarity, if tier == 9 then Color3.fromRGB(255, 60, 60) else rarityColor },
		{ `{Format.Cash(PetInfo.Income(petId, mutationId))}/s`, Color3.fromRGB(120, 255, 120) },
	})
	return model
end

-- Eggs ---------------------------------------------------------------------------

function ModelFactory.BuildEgg(eggId: string): Model
	local egg = PetConfig.EggsById[eggId]
	assert(egg, `Unknown egg {eggId}`)
	local model = Instance.new("Model")
	model.Name = eggId
	local shell = ball(model, "Shell", Vector3.new(2.4, 3, 2.4), Vector3.new(0, 1.5, 0), rgb(egg.color))
	-- Two bands of the accent color, so each biome's eggs look different.
	for index, y in { 1.1, 2.0 } do
		local band = ball(model, `Band{index}`, Vector3.new(2.5, 0.35, 2.5), Vector3.new(0, y, 0), rgb(egg.accent))
		band.Material = if egg.kind == "Standard" then Enum.Material.SmoothPlastic else Enum.Material.Neon
	end
	if egg.kind == "Royal" then
		block(
			model,
			"Crown",
			Vector3.new(1, 0.5, 1),
			Vector3.new(0, 3.1, 0),
			Color3.fromRGB(255, 215, 60),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 120)
		light.Range = 10
		light.Parent = shell
	end
	model.PrimaryPart = shell
	shell.PivotOffset = shell.CFrame:Inverse()
	return model
end

-- Places a model so it stands on top of `surface`, facing the same way.
function ModelFactory.StandOn(model: Model, surface: BasePart)
	model:PivotTo(surface.CFrame * CFrame.new(0, surface.Size.Y / 2, 0))
end

return ModelFactory
