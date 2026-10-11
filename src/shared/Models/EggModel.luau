--!strict
-- A rarity-coloured egg built from primitives, used in incubators, the roll
-- reveal and the egg inventory. Pivot is the bottom of the egg.

local Config = script.Parent.Parent:WaitForChild("Config")
local Rarities = require(Config:WaitForChild("Rarities"))

local EggModel = {}

local function shell(model: Model, name: string, size: Vector3, position: Vector3, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = model
	return p
end

function EggModel.build(rarityId: string, scale: number?): Model
	local rarity = Rarities.byId[rarityId] or Rarities.byId.Common
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = `{rarity.name}Egg`
	local isSecret = rarity.id == Rarities.secretId
	local base = rarity.color
	local spots = if isSecret then Color3.fromRGB(200, 120, 255) else base:Lerp(Color3.new(1, 1, 1), 0.55)

	local body = shell(model, "Shell", Vector3.new(2.4, 3, 2.4) * k, Vector3.new(0, 1.5 * k, 0), base)
	if rarity.order >= 4 then
		body.Material = Enum.Material.Glass
		body.Reflectance = 0.1
	end
	-- Spots around the egg; rarer eggs get glowing ones.
	local rng = Random.new(rarity.order * 97)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local height = rng:NextNumber(0.9, 2.1) * k
		local radius = 1.05 * k * math.sin(math.acos(math.clamp((height - 1.5 * k) / (1.5 * k), -1, 1)))
		local spot = shell(
			model,
			"Spot",
			Vector3.new(0.5, 0.5, 0.5) * k,
			Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius),
			spots
		)
		if rarity.order >= 5 then
			spot.Material = Enum.Material.Neon
		end
	end
	if rarity.order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = if isSecret then spots else base
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = body
	end
	body.PivotOffset = CFrame.new(0, -1.5 * k, 0) -- pivot at the bottom of the egg
	model.PrimaryPart = body
	model:SetAttribute("Rarity", rarity.id)
	return model
end

return EggModel
