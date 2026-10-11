--!strict
-- Builds a low-poly pet from primitives, from its species' archetype and two
-- colours. The server uses it for pets on farms; the client uses it for the
-- hatch reveal and inventory previews, so a pet looks the same everywhere.
--
-- The model's pivot is the point on the ground under its feet, facing -Z
-- (its LookVector), so callers place it with model:PivotTo(cframe). Rarer
-- pets are slightly bigger. Parts are anchored, massless and ignore
-- collisions, touches and raycasts.

local Config = script.Parent.Parent:WaitForChild("Config")
local Pets = require(Config:WaitForChild("Pets"))
local Rarities = require(Config:WaitForChild("Rarities"))

local PetModel = {}

local BLACK = Color3.fromRGB(30, 30, 36)
local WHITE = Color3.new(1, 1, 1)
local SHINY_GOLD = Color3.fromRGB(255, 214, 90)

type Builder = {
	model: Model,
	scale: number,
	body: Color3,
	accent: Color3,
}

local function piece(
	b: Builder,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	paint: string?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size * b.scale
	p.CFrame = CFrame.new(cframe.Position * b.scale) * cframe.Rotation
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	if paint then
		p:SetAttribute("Paint", paint) -- "Body" or "Accent", used by the Rainbow effect
	end
	p.Parent = b.model
	return p
end

local function ball(b: Builder, name: string, size: Vector3, position: Vector3, colour: Color3, paint: string?): Part
	return piece(b, name, Enum.PartType.Ball, size, CFrame.new(position), colour, paint)
end

local function block(b: Builder, name: string, size: Vector3, cframe: CFrame, colour: Color3, paint: string?): Part
	return piece(b, name, Enum.PartType.Block, size, cframe, colour, paint)
end

local function wedge(b: Builder, name: string, size: Vector3, cframe: CFrame, colour: Color3, paint: string?): Part
	return piece(b, name, Enum.PartType.Wedge, size, cframe, colour, paint)
end

local function leg(b: Builder, position: Vector3, length: number, thickness: number, colour: Color3)
	piece(
		b,
		"Leg",
		Enum.PartType.Cylinder,
		Vector3.new(length, thickness, thickness),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		colour,
		"Accent"
	)
end

-- Two eyes with a highlight, on a head of radius r centred at `head`.
local function eyes(b: Builder, head: Vector3, r: number, spread: number?)
	local s = spread or 0.42
	for _, side in { -1, 1 } do
		local at = head + Vector3.new(side * r * s, r * 0.18, -r * 0.82)
		ball(b, "Eye", Vector3.one * r * 0.34, at, BLACK)
		ball(b, "Shine", Vector3.one * r * 0.12, at + Vector3.new(side * r * 0.05, r * 0.08, -r * 0.14), WHITE)
	end
end

local function earPair(b: Builder, head: Vector3, r: number, tall: boolean)
	for _, side in { -1, 1 } do
		local size = if tall then Vector3.new(0.35, 1.5, 0.6) * r else Vector3.new(0.4, 0.7, 0.6) * r
		block(
			b,
			"Ear",
			size,
			CFrame.new(head + Vector3.new(side * r * 0.5, r * 0.95, 0)) * CFrame.Angles(0, 0, math.rad(-side * 15)),
			b.accent,
			"Accent"
		)
	end
end

local builders: { [string]: (Builder) -> number } = {}

-- Each builder returns the height of the pet's top (for label placement).
builders.Bird = function(b)
	ball(b, "Body", Vector3.new(2.4, 2.2, 2.6), Vector3.new(0, 1.7, 0), b.body, "Body")
	ball(b, "Head", Vector3.one * 1.7, Vector3.new(0, 3.1, -0.7), b.body, "Body")
	eyes(b, Vector3.new(0, 3.1, -0.7), 0.85)
	wedge(
		b,
		"Beak",
		Vector3.new(0.4, 0.4, 0.7),
		CFrame.new(0, 2.9, -1.7) * CFrame.Angles(0, math.rad(180), 0),
		b.accent,
		"Accent"
	)
	for _, side in { -1, 1 } do
		block(
			b,
			"Wing",
			Vector3.new(0.25, 1.2, 1.7),
			CFrame.new(side * 1.25, 1.9, 0.1) * CFrame.Angles(math.rad(10), 0, math.rad(side * 12)),
			b.accent,
			"Accent"
		)
		leg(b, Vector3.new(side * 0.45, 0.35, 0), 0.7, 0.25, b.accent)
	end
	wedge(b, "Tail", Vector3.new(1.2, 0.9, 0.9), CFrame.new(0, 2, 1.4), b.accent, "Accent")
	ball(b, "Crest", Vector3.new(0.3, 0.7, 0.6), Vector3.new(0, 4, -0.6), b.accent, "Accent")
	return 4.4
end

builders.Small = function(b)
	ball(b, "Body", Vector3.new(2.2, 1.9, 2.6), Vector3.new(0, 1.2, 0.2), b.body, "Body")
	ball(b, "Head", Vector3.one * 1.8, Vector3.new(0, 2.4, -0.9), b.body, "Body")
	eyes(b, Vector3.new(0, 2.4, -0.9), 0.9)
	ball(b, "Nose", Vector3.one * 0.3, Vector3.new(0, 2.25, -1.8), b.accent, "Accent")
	earPair(b, Vector3.new(0, 2.4, -0.9), 0.9, true)
	for _, x in { -0.6, 0.6 } do
		for _, z in { -0.6, 0.9 } do
			ball(b, "Foot", Vector3.new(0.6, 0.4, 0.7), Vector3.new(x, 0.2, z), b.accent, "Accent")
		end
	end
	ball(b, "Tail", Vector3.one * 0.8, Vector3.new(0, 1.3, 1.5), b.accent, "Accent")
	return 3.8
end

local function quadruped(b: Builder, big: boolean): number
	local k = if big then 1.25 else 1
	local bodyY = 2.3 * k
	ball(b, "Body", Vector3.new(2.6, 2.4, 3.8) * k, Vector3.new(0, bodyY, 0), b.body, "Body")
	local head = Vector3.new(0, bodyY + 1.3 * k, -1.9 * k)
	ball(b, "Head", Vector3.one * 2 * k, head, b.body, "Body")
	eyes(b, head, 1 * k)
	block(
		b,
		"Snout",
		Vector3.new(1, 0.7, 0.8) * k,
		CFrame.new(head + Vector3.new(0, -0.35 * k, -0.9 * k)),
		b.accent,
		"Accent"
	)
	earPair(b, head, 1 * k, false)
	for _, x in { -0.75, 0.75 } do
		for _, z in { -1.1, 1.1 } do
			leg(b, Vector3.new(x * k, 0.75 * k, z * k), 1.5 * k, 0.6 * k, b.accent)
		end
	end
	block(
		b,
		"Tail",
		Vector3.new(0.3, 0.3, 1.2) * k,
		CFrame.new(0, bodyY + 0.4 * k, 2.2 * k) * CFrame.Angles(math.rad(35), 0, 0),
		b.accent,
		"Accent"
	)
	return head.Y + 1.4 * k
end

builders.Quadruped = function(b)
	return quadruped(b, false)
end

builders.Large = function(b)
	local top = quadruped(b, true)
	-- horns or antlers make the big ones read as special
	local head = Vector3.new(0, 2.3 * 1.25 + 1.3 * 1.25, -1.9 * 1.25)
	for _, side in { -1, 1 } do
		block(
			b,
			"Horn",
			Vector3.new(0.3, 1.4, 0.3),
			CFrame.new(head + Vector3.new(side * 0.6, 1.4, 0.1)) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			b.accent,
			"Accent"
		)
		block(
			b,
			"Tine",
			Vector3.new(0.25, 0.8, 0.25),
			CFrame.new(head + Vector3.new(side * 1.05, 2, 0.1)) * CFrame.Angles(0, 0, math.rad(side * 30)),
			b.accent,
			"Accent"
		)
	end
	return top + 0.8
end

builders.Fish = function(b)
	local y = 2.4
	ball(b, "Body", Vector3.new(1.8, 2.2, 3.6), Vector3.new(0, y, 0), b.body, "Body")
	eyes(b, Vector3.new(0, y + 0.1, -0.9), 0.95, 0.75)
	wedge(b, "TailFin", Vector3.new(0.25, 1.8, 1.4), CFrame.new(0, y, 2.1) * CFrame.Angles(0, 0, 0), b.accent, "Accent")
	wedge(b, "Dorsal", Vector3.new(0.2, 0.9, 1.4), CFrame.new(0, y + 1.3, 0.2), b.accent, "Accent")
	for _, side in { -1, 1 } do
		block(
			b,
			"Fin",
			Vector3.new(0.15, 0.5, 0.9),
			CFrame.new(side * 0.95, y - 0.4, -0.2) * CFrame.Angles(0, 0, math.rad(side * 40)),
			b.accent,
			"Accent"
		)
	end
	-- a faint bubble ring under the fish so it reads as floating on purpose
	local bubble = piece(
		b,
		"Bubble",
		Enum.PartType.Cylinder,
		Vector3.new(0.1, 2.2, 2.2),
		CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(170, 230, 255),
		nil
	)
	bubble.Transparency = 0.5
	return y + 2
end

builders.Insect = function(b)
	local y = 2.2
	ball(b, "Body", Vector3.new(1.8, 1.7, 2.4), Vector3.new(0, y, 0.3), b.body, "Body")
	for _, z in { 0, 0.7 } do
		block(b, "Stripe", Vector3.new(1.75, 1.6, 0.3), CFrame.new(0, y, z), b.accent, "Accent")
	end
	ball(b, "Head", Vector3.one * 1.3, Vector3.new(0, y + 0.3, -1.1), b.accent, "Accent")
	eyes(b, Vector3.new(0, y + 0.3, -1.1), 0.65)
	for _, side in { -1, 1 } do
		local wing = block(
			b,
			"Wing",
			Vector3.new(0.1, 1.5, 1.3),
			CFrame.new(side * 0.8, y + 1.2, 0.2) * CFrame.Angles(0, 0, math.rad(side * 35)),
			Color3.fromRGB(220, 240, 255),
			nil
		)
		wing.Transparency = 0.35
		block(
			b,
			"Antenna",
			Vector3.new(0.12, 0.9, 0.12),
			CFrame.new(side * 0.3, y + 1.1, -1.3) * CFrame.Angles(math.rad(-20), 0, math.rad(side * 15)),
			BLACK,
			nil
		)
	end
	return y + 2.4
end

builders.Dragon = function(b)
	local top = quadruped(b, true)
	for _, side in { -1, 1 } do
		wedge(
			b,
			"Wing",
			Vector3.new(0.25, 2.6, 3),
			CFrame.new(side * 2, 4.4, 0.2) * CFrame.Angles(0, 0, math.rad(side * 30)),
			b.accent,
			"Accent"
		)
	end
	for i = 0, 3 do
		wedge(b, "Spike", Vector3.new(0.3, 0.7, 0.7), CFrame.new(0, 4.3 - i * 0.15, -0.9 + i * 0.8), b.accent, "Accent")
	end
	return top + 0.6
end

-- Scale grows a little with rarity, so a Mythic stands out on a farm.
function PetModel.scaleFor(rarityId: string): number
	local rarity = Rarities.byId[rarityId]
	local order = if rarity then rarity.order else 1
	return 0.9 + 0.08 * (order - 1)
end

-- Builds the model and returns it with the height of its top in studs.
function PetModel.build(speciesId: string, variantId: string?): (Model, number)
	local species = Pets.byId[speciesId]
	assert(species ~= nil, `unknown species {speciesId}`)
	local model = Instance.new("Model")
	model.Name = species.name
	local b: Builder = {
		model = model,
		scale = PetModel.scaleFor(species.rarity),
		body = species.colors[1],
		accent = species.colors[2] or species.colors[1],
	}
	local variant = variantId or "Normal"
	if variant == "Shiny" then
		b.accent = SHINY_GOLD
	end
	local top = builders[species.archetype](b) * b.scale

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new() -- the pivot: ground point under the feet
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("Height", top)
	if variant == "Shiny" or variant == "Rainbow" then
		local body = model:FindFirstChild("Body") :: BasePart?
		if body then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "VariantSparkle"
			sparkle.Rate = if variant == "Rainbow" then 10 else 6
			sparkle.Lifetime = NumberRange.new(0.6, 1.2)
			sparkle.Speed = NumberRange.new(0.5, 1.5)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparkle.LightEmission = 1
			sparkle.Color = if variant == "Rainbow"
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 140, 255)),
				})
				else ColorSequence.new(SHINY_GOLD)
			sparkle.Parent = body
		end
	end
	return model, top
end

return PetModel
