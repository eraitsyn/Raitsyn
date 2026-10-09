--[[
	GodFactory: builds placeholder god models from config, with a name tag
	showing rarity and income. Swap Build for real models later; nothing else
	depends on the shape beyond a Model with PrimaryPart.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GodConfig = require(ReplicatedStorage.Shared.Config.Gods)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local rarityColors: { [string]: Color3 } = {}
for _, rarity in GodConfig.Rarities do
	rarityColors[rarity.name] = rgb(rarity.color)
end

local GodFactory = {}

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

local function label(parent: Instance, name: string, text: string, color: Color3, order: number)
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1 / 3)
	textLabel.Position = UDim2.fromScale(0, order / 3)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Text = text
	textLabel.Parent = parent
end

-- A god model built around the origin, facing -Z, standing on y = 0.
function GodFactory.Build(godId: string): Model
	local god = GodConfig.Gods[godId]
	assert(god, `Unknown god {godId}`)
	local rarityColor = rarityColors[god.rarity]
	local bodyColor = rgb(god.color)

	local model = Instance.new("Model")
	model.Name = godId

	local root = block(model, "Root", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), bodyColor)
	block(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), Color3.fromRGB(245, 205, 170))
	block(model, "LeftLeg", Vector3.new(0.9, 2, 1), Vector3.new(-0.5, 1, 0), bodyColor)
	block(model, "RightLeg", Vector3.new(0.9, 2, 1), Vector3.new(0.5, 1, 0), bodyColor)
	block(model, "LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 3, 0), bodyColor)
	block(model, "RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 3, 0), bodyColor)
	local crown = block(model, "Crown", Vector3.new(1.4, 0.3, 1.4), Vector3.new(0, 5.35, 0), rarityColor)
	crown.Material = Enum.Material.Neon

	if god.rarity == "Mythic" or god.rarity == "Secret" then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 12
		light.Brightness = 2
		light.Parent = root
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(160, 66)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.MaxDistance = 80
	tag.Adornee = root
	label(tag, "GodName", god.name, Color3.new(1, 1, 1), 0)
	label(tag, "Rarity", god.rarity, rarityColor, 1)
	label(tag, "Income", `${god.income}/s`, Color3.fromRGB(120, 255, 120), 2)
	tag.Parent = root

	model.PrimaryPart = root
	model.WorldPivot = CFrame.new()
	return model
end

-- Places a model so it stands on top of `surface` facing the same way.
function GodFactory.StandOn(model: Model, surface: BasePart)
	model:PivotTo(surface.CFrame * CFrame.new(0, surface.Size.Y / 2, 0))
end

return GodFactory
