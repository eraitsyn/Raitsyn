--!strict
-- Builds the whole world from Config/Map at server start: ground, border,
-- the hub with its stations, and eight identical plots. Everything is plain
-- anchored parts in a bright low-poly style, so it can be swapped for
-- Studio-built models later without touching game logic (other code only
-- relies on the names and attributes set here).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared:WaitForChild("Config"):WaitForChild("Map"))
local RollTiers = require(Shared:WaitForChild("Config"):WaitForChild("RollTiers"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))

local HEADING_FONT = Font.fromEnum(Enum.Font.FredokaOne)

local Palette = {
	grass = Color3.fromRGB(120, 196, 92),
	grassDark = Color3.fromRGB(96, 170, 74),
	plotGrass = Color3.fromRGB(132, 206, 100),
	path = Color3.fromRGB(236, 214, 160),
	pathEdge = Color3.fromRGB(214, 186, 128),
	stone = Color3.fromRGB(226, 222, 214),
	stoneDark = Color3.fromRGB(176, 170, 162),
	hedge = Color3.fromRGB(62, 140, 70),
	wood = Color3.fromRGB(176, 120, 76),
	woodDark = Color3.fromRGB(130, 84, 52),
	fence = Color3.fromRGB(250, 246, 236),
	soil = Color3.fromRGB(150, 104, 70),
	pad = Color3.fromRGB(196, 150, 104),
	padLocked = Color3.fromRGB(120, 112, 104),
	trunk = Color3.fromRGB(122, 84, 56),
	leaves = { Color3.fromRGB(86, 168, 82), Color3.fromRGB(110, 186, 88), Color3.fromRGB(72, 150, 92) },
	coin = Color3.fromRGB(255, 200, 40),
	roof = Color3.fromRGB(232, 92, 84),
	hexGlow = Color3.fromRGB(120, 210, 255),
	portal = Color3.fromRGB(190, 120, 255),
	board = Color3.fromRGB(64, 70, 92),
	white = Color3.new(1, 1, 1),
}

-- One accent colour per plot for banners and the gate.
local PLOT_COLOURS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(255, 176, 76),
	Color3.fromRGB(255, 222, 90),
	Color3.fromRGB(120, 210, 120),
	Color3.fromRGB(96, 196, 255),
	Color3.fromRGB(140, 140, 255),
	Color3.fromRGB(206, 130, 255),
	Color3.fromRGB(255, 136, 200),
}

export type PlotHandles = {
	index: number,
	model: Model,
	cframe: CFrame,
	colour: Color3,
	pads: { BasePart },
	padLocks: { BillboardGui },
	sectionSigns: { BillboardGui },
	sectionGates: { BasePart },
	signName: TextLabel,
	signInfo: TextLabel,
	signAvatar: ImageLabel,
	spawn: SpawnLocation,
	rollStation: BasePart,
	hatchPlatform: BasePart,
	incubators: { BasePart },
	petsFolder: Folder,
}

export type HubHandles = {
	model: Model,
	plaza: BasePart,
	upgradeShop: BasePart,
	rebirthStation: BasePart,
	indexBoard: BasePart,
	dailyKiosk: BasePart,
	leaderboards: { BasePart },
}

local MapBuilder = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A part that is purely decorative: no collisions, no touch or raycast cost.
local function decor(parent: Instance, props: { [string]: any }): Part
	local p = part(parent, props)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = HEADING_FONT
	label.TextColor3 = Palette.white
	label.TextScaled = true
	label.Size = UDim2.fromScale(1, 1)
	for key, value in props do
		(label :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 40, 60)
	stroke.Transparency = 0.2
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A floating label above a part, visible within `distance` studs.
local function billboard(
	adornee: BasePart,
	text: string,
	height: number,
	distance: number,
	width: number?
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 8, 2)
	-- StudsOffsetWorldSpace is in the adornee's own axes, so convert "up" for
	-- rotated parts such as the cylinder station bases.
	gui.StudsOffsetWorldSpace = adornee.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
	gui.MaxDistance = distance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	textLabel(gui, { Text = text })
	gui.Parent = adornee
	return gui
end

local function prompt(parent: BasePart, action: string, objectText: string, name: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

-- A hexagon as the union of three rotated blocks (circumradius `radius`).
local function hexagon(parent: Instance, centre: CFrame, radius: number, height: number, props: { [string]: any })
	local width = radius * math.sqrt(3)
	for i = 0, 2 do
		local block = part(parent, props)
		block.Size = Vector3.new(radius, height, width)
		block.CFrame = centre * CFrame.Angles(0, math.rad(60 * i), 0)
	end
end

local function cylinder(
	parent: Instance,
	centre: Vector3,
	diameter: number,
	height: number,
	props: { [string]: any }
): Part
	local p = part(parent, props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function tree(parent: Instance, position: Vector3, scale: number, rng: Random)
	local m = model(parent, "Tree")
	local trunkHeight = 6 * scale
	decor(m, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.trunk,
	})
	for i = 1, 3 do
		local size = (6 - i) * scale * (0.9 + rng:NextNumber() * 0.3)
		decor(m, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(position + Vector3.new(0, trunkHeight + (i - 1) * 2.4 * scale, 0)),
			Color = Palette.leaves[(i + rng:NextInteger(0, 2)) % #Palette.leaves + 1],
		})
	end
end

local function hayBale(parent: Instance, cframe: CFrame)
	decor(parent, {
		Name = "HayBale",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 3.2, 3.2),
		CFrame = cframe * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(236, 200, 96),
	})
end

--------------------------------------------------------------------------------
-- Ground, border and decoration

local function buildGround(world: Model)
	local bounds = Map.bounds
	part(world, {
		Name = "Ground",
		Size = Vector3.new(bounds.X + 160, 2, bounds.Y + 160),
		CFrame = CFrame.new(0, -1, 0),
		Color = Palette.grass,
		Material = Enum.Material.Grass,
	})
	-- The avenue ring that every plot gate opens onto.
	local avenueZ = Map.plots[1].cframe.Position.Z + Map.plotDepth / 2 + 8 -- just outside the north gates
	for _, sign in { -1, 1 } do
		part(world, {
			Name = "Avenue",
			Size = Vector3.new(460, 0.2, 16),
			CFrame = CFrame.new(0, 0.1, math.abs(avenueZ) * sign),
			Color = Palette.path,
			CanCollide = false,
		})
	end
	for _, sign in { -1, 1 } do
		part(world, {
			Name = "Avenue",
			Size = Vector3.new(16, 0.2, math.abs(avenueZ) * 2 + 16),
			CFrame = CFrame.new(230 * sign, 0.1, 0),
			Color = Palette.path,
			CanCollide = false,
		})
	end

	-- Invisible walls on the map bounds keep everyone on the island.
	local half = bounds / 2
	local walls = folder(world, "Walls")
	for _, data in
		{
			{ Vector3.new(bounds.X + 40, 120, 4), Vector3.new(0, 60, -half.Y - 2) },
			{ Vector3.new(bounds.X + 40, 120, 4), Vector3.new(0, 60, half.Y + 2) },
			{ Vector3.new(4, 120, bounds.Y + 40), Vector3.new(-half.X - 2, 60, 0) },
			{ Vector3.new(4, 120, bounds.Y + 40), Vector3.new(half.X + 2, 60, 0) },
		}
	do
		part(walls, {
			Name = "Wall",
			Size = data[1],
			CFrame = CFrame.new(data[2]),
			Transparency = 1,
			CastShadow = false,
			CanQuery = false,
		})
	end

	-- Low hills and trees just outside the walls frame the map.
	local rng = Random.new(20261011)
	local edge = folder(world, "Edge")
	local step = 26
	local function ringPoint(t: number): Vector3
		-- walks the rectangle perimeter, t in [0, perimeter)
		local w, d = bounds.X + 30, bounds.Y + 30
		if t < w then
			return Vector3.new(-w / 2 + t, 0, -d / 2)
		end
		t -= w
		if t < d then
			return Vector3.new(w / 2, 0, -d / 2 + t)
		end
		t -= d
		if t < w then
			return Vector3.new(w / 2 - t, 0, d / 2)
		end
		t -= w
		return Vector3.new(-w / 2, 0, d / 2 - t)
	end
	local perimeter = 2 * (bounds.X + 30 + bounds.Y + 30)
	local t = 0
	while t < perimeter do
		local p = ringPoint(t)
		local outward = Vector3.new(math.sign(p.X), 0, math.sign(p.Z)) * rng:NextNumber(4, 14)
		decor(edge, {
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(30, 46),
			CFrame = CFrame.new(p + outward * 1.5 + Vector3.new(0, -10, 0)),
			Color = Palette.grassDark,
			Material = Enum.Material.Grass,
		})
		tree(
			edge,
			p + outward + Vector3.new(rng:NextNumber(-6, 6), 2, rng:NextNumber(-6, 6)),
			rng:NextNumber(1, 1.5),
			rng
		)
		t += step + rng:NextNumber(-6, 6)
	end
end

--------------------------------------------------------------------------------
-- Hub

local function buildPlaza(hub: Model): BasePart
	local plaza = model(hub, "Plaza")
	local floor = cylinder(plaza, Vector3.new(0, 0.15, 0), Map.plazaRadius * 2, 0.3, {
		Name = "Floor",
		Color = Palette.stone,
	})
	cylinder(plaza, Vector3.new(0, 0.2, 0), Map.plazaRadius * 2 - 6, 0.3, {
		Name = "Inlay",
		Color = Palette.stoneDark,
		CanCollide = false,
	})
	cylinder(plaza, Vector3.new(0, 0.25, 0), Map.plazaRadius * 2 - 10, 0.3, {
		Name = "InlayCentre",
		Color = Palette.stone,
		CanCollide = false,
	})

	-- The big rolling machine.
	local machine = model(plaza, "RollMachine")
	local base = cylinder(machine, Vector3.new(0, 2, 0), 16, 4, { Name = "Base", Color = Palette.roof })
	cylinder(
		machine,
		Vector3.new(0, 4.3, 0),
		13,
		0.6,
		{ Name = "Rim", Color = Palette.coin, Material = Enum.Material.Neon }
	)
	decor(machine, {
		Name = "Globe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 11,
		CFrame = CFrame.new(0, 9.5, 0),
		Color = Color3.fromRGB(190, 230, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		decor(machine, {
			Name = "Egg",
			Size = Vector3.new(1.6, 2, 1.6),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(math.cos(angle) * 2.6, 7 + (i % 2), math.sin(angle) * 2.6),
			Color = PLOT_COLOURS[i],
		})
	end
	decor(machine, {
		Name = "Topper",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		CFrame = CFrame.new(0, 15.5, 0),
		Color = Palette.coin,
		Material = Enum.Material.Neon,
	})
	base:SetAttribute("Station", "Plaza")
	billboard(base, "ROLL HERE", 17, 120, 12)

	-- One pillar per roll tier, showing its price.
	for i, tier in RollTiers.list do
		local angle = math.rad(-90 + (i - 1) * (360 / #RollTiers.list))
		local position = Vector3.new(math.cos(angle) * 24, 0, math.sin(angle) * 24)
		local pillar = part(plaza, {
			Name = `Pillar{tier.id}`,
			Size = Vector3.new(3, 7, 3),
			CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)),
			Color = Palette.stone,
		})
		decor(plaza, {
			Name = "PillarCap",
			Size = Vector3.new(3.6, 0.8, 3.6),
			CFrame = CFrame.new(position + Vector3.new(0, 7.4, 0)),
			Color = Palette.coin,
			Material = Enum.Material.Neon,
		})
		billboard(pillar, `{tier.name}\n{Format.coins(tier.price)}`, 6, 70, 7)
	end
	return floor
end

local function buildUpgradeShop(hub: Model): BasePart
	local shop = model(hub, "UpgradeShop")
	local centre = CFrame.new(Map.upgradeShop)
	hexagon(shop, centre * CFrame.new(0, 0.3, 0), 22, 0.6, { Name = "Floor", Color = Palette.board })
	hexagon(shop, centre * CFrame.new(0, 0.45, 0), 17, 0.6, {
		Name = "Glow",
		Color = Palette.hexGlow,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	hexagon(
		shop,
		centre * CFrame.new(0, 0.55, 0),
		15,
		0.6,
		{ Name = "Inner", Color = Palette.board, CanCollide = false }
	)
	for i = 0, 5 do
		local angle = math.rad(60 * i + 30)
		local position = Map.upgradeShop + Vector3.new(math.cos(angle) * 19, 0, math.sin(angle) * 19)
		part(shop, {
			Name = "Column",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 2.4, 2.4),
			CFrame = CFrame.new(position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Palette.fence,
		})
	end
	hexagon(shop, centre * CFrame.new(0, 16.6, 0), 23, 1.2, { Name = "Roof", Color = Palette.hexGlow })
	hexagon(shop, centre * CFrame.new(0, 17.8, 0), 14, 1.2, { Name = "Roof2", Color = Palette.board })
	local core = decor(shop, {
		Name = "Core",
		Size = Vector3.new(4, 4, 4),
		CFrame = centre * CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = Palette.hexGlow,
		Material = Enum.Material.Neon,
	})
	local anchor = part(shop, {
		Name = "PromptAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = centre * CFrame.new(0, 2, 0),
		Transparency = 1,
		CanCollide = false,
	})
	anchor:SetAttribute("Station", "UpgradeShop")
	prompt(anchor, "Open Upgrades", "Upgrade Shop", "OpenUpgrades").MaxActivationDistance = 20
	billboard(core, "UPGRADES", 14, 160, 12)
	return anchor
end

local function buildRebirthStation(hub: Model): BasePart
	local station = model(hub, "RebirthStation")
	local centre = CFrame.lookAt(Map.rebirthStation, Vector3.zero)
	cylinder(station, Map.rebirthStation + Vector3.new(0, 0.3, 0), 30, 0.6, { Name = "Floor", Color = Palette.board })
	for _, side in { -1, 1 } do
		part(station, {
			Name = "Leg",
			Size = Vector3.new(3, 20, 3),
			CFrame = centre * CFrame.new(side * 8, 10, 0),
			Color = Palette.stone,
		})
	end
	part(station, {
		Name = "Lintel",
		Size = Vector3.new(19, 3, 3.4),
		CFrame = centre * CFrame.new(0, 21.5, 0),
		Color = Palette.portal,
	})
	local portal = decor(station, {
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 15, 15),
		CFrame = centre * CFrame.new(0, 11, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = Palette.portal,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Rate = 18
	swirl.Lifetime = NumberRange.new(1.2, 1.8)
	swirl.Speed = NumberRange.new(1, 2)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.RotSpeed = NumberRange.new(90, 180)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	swirl.Color = ColorSequence.new(Palette.portal, Palette.white)
	swirl.LightEmission = 0.8
	swirl.Parent = portal
	local anchor = part(station, {
		Name = "PromptAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = centre * CFrame.new(0, 2, -4),
		Transparency = 1,
		CanCollide = false,
	})
	anchor:SetAttribute("Station", "Rebirth")
	prompt(anchor, "Rebirth", "Rebirth Station", "OpenRebirth").MaxActivationDistance = 18
	billboard(portal, "REBIRTH", 12, 160, 12)
	return anchor
end

local function buildBoard(hub: Model, name: string, position: Vector3, size: Vector2, colour: Color3): BasePart
	local board = model(hub, name)
	-- Boards face the plaza (their front face is the CFrame's LookVector).
	local facing = CFrame.lookAt(position, Vector3.zero)
	for _, side in { -1, 1 } do
		part(board, {
			Name = "Post",
			Size = Vector3.new(1.4, size.Y + 4, 1.4),
			CFrame = facing * CFrame.new(side * (size.X / 2 + 0.7), (size.Y + 4) / 2, 0),
			Color = Palette.wood,
		})
	end
	local panel = part(board, {
		Name = "Screen",
		Size = Vector3.new(size.X, size.Y, 0.8),
		CFrame = facing * CFrame.new(0, size.Y / 2 + 3, 0),
		Color = colour,
	})
	decor(board, {
		Name = "Trim",
		Size = Vector3.new(size.X + 1.4, 1, 1.2),
		CFrame = facing * CFrame.new(0, size.Y + 3.5, 0),
		Color = Palette.coin,
	})
	return panel
end

local function buildDailyKiosk(hub: Model): BasePart
	local kiosk = model(hub, "DailyKiosk")
	local centre = CFrame.lookAt(Map.dailyKiosk, Vector3.zero)
	part(kiosk, {
		Name = "Counter",
		Size = Vector3.new(10, 4, 5),
		CFrame = centre * CFrame.new(0, 2, 0),
		Color = Palette.fence,
	})
	for _, side in { -1, 1 } do
		part(kiosk, {
			Name = "Post",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = centre * CFrame.new(side * 4.6, 4.5, 2),
			Color = Palette.woodDark,
		})
	end
	decor(kiosk, {
		Name = "Awning",
		Size = Vector3.new(11, 0.6, 6),
		CFrame = centre * CFrame.new(0, 9.2, 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = Palette.roof,
	})
	local gift = decor(kiosk, {
		Name = "Gift",
		Size = Vector3.new(3, 3, 3),
		CFrame = centre * CFrame.new(0, 5.6, 0),
		Color = Color3.fromRGB(120, 200, 255),
	})
	decor(kiosk, {
		Name = "Ribbon",
		Size = Vector3.new(3.1, 3.1, 0.6),
		CFrame = gift.CFrame,
		Color = Palette.coin,
	})
	decor(kiosk, {
		Name = "Ribbon",
		Size = Vector3.new(0.6, 3.1, 3.1),
		CFrame = gift.CFrame,
		Color = Palette.coin,
	})
	gift:SetAttribute("Station", "Daily")
	local anchor = part(kiosk, {
		Name = "PromptAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = centre * CFrame.new(0, 2, -3),
		Transparency = 1,
		CanCollide = false,
	})
	prompt(anchor, "Claim", "Daily Reward", "OpenDaily")
	billboard(gift, "DAILY GIFT", 4, 120, 10)
	return gift
end

local function buildHub(world: Model): HubHandles
	local hub = model(world, "Hub")
	local plaza = buildPlaza(hub)
	local shop = buildUpgradeShop(hub)
	local rebirth = buildRebirthStation(hub)
	local index = buildBoard(hub, "IndexBoard", Map.indexBoard, Vector2.new(34, 14), Palette.board)
	local indexPrompt = prompt(index, "Open", "Pet Index", "OpenIndex")
	indexPrompt.MaxActivationDistance = 20
	billboard(index, "PET INDEX", 10, 160, 12)
	local daily = buildDailyKiosk(hub)
	local boards = {}
	for i, position in Map.leaderboards do
		local board = buildBoard(hub, `Leaderboard{i}`, position, Vector2.new(16, 20), Palette.board)
		table.insert(boards, board)
	end

	-- Paths from the plaza toward each side of the avenue.
	for _, target in { Vector3.new(0, 0, -90), Vector3.new(0, 0, 90), Vector3.new(-140, 0, 0), Vector3.new(140, 0, 0) } do
		local length = target.Magnitude - Map.plazaRadius + 4
		local mid = target.Unit * (Map.plazaRadius - 2 + length / 2)
		part(hub, {
			Name = "Path",
			Size = Vector3.new(10, 0.2, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), target + Vector3.new(0, 0.1, 0)),
			Color = Palette.path,
			CanCollide = false,
		})
	end

	-- A few props so the hub reads as a village square.
	local rng = Random.new(7)
	local props = folder(hub, "Props")
	for _, position in
		{
			Vector3.new(-60, 0, -40),
			Vector3.new(60, 0, -40),
			Vector3.new(-60, 0, 40),
			Vector3.new(60, 0, 40),
			Vector3.new(-200, 0, -60),
			Vector3.new(200, 0, -60),
			Vector3.new(-200, 0, 60),
			Vector3.new(200, 0, 60),
		}
	do
		tree(props, position, 1.2, rng)
	end
	for _, position in { Vector3.new(-40, 1.6, -52), Vector3.new(40, 1.6, 52), Vector3.new(-120, 1.6, 40) } do
		hayBale(props, CFrame.new(position))
		hayBale(props, CFrame.new(position + Vector3.new(3.4, 0, 0)))
		hayBale(props, CFrame.new(position + Vector3.new(1.7, 3, 0)))
	end

	return {
		model = hub,
		plaza = plaza,
		upgradeShop = shop,
		rebirthStation = rebirth,
		indexBoard = index,
		dailyKiosk = daily,
		leaderboards = boards,
	}
end

--------------------------------------------------------------------------------
-- Plots

local function fenceLine(parent: Instance, from: Vector3, to: Vector3, cf: CFrame)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local mid = (from + to) / 2
	local look = CFrame.lookAt(cf * mid, cf * to)
	for _, height in { 1.2, 2.4 } do
		decor(parent, {
			Name = "Rail",
			Size = Vector3.new(0.3, 0.35, length),
			CFrame = look + Vector3.new(0, height + 0.4, 0),
			Color = Palette.fence,
		})
	end
	local posts = math.max(1, math.floor(length / 4))
	for i = 0, posts do
		local p = from:Lerp(to, i / posts)
		decor(parent, {
			Name = "Post",
			Size = Vector3.new(0.6, 3.2, 0.6),
			CFrame = cf * CFrame.new(p + Vector3.new(0, 2, 0)),
			Color = Palette.fence,
		})
	end
	-- One invisible collider per side keeps players off the posts' gaps.
	part(parent, {
		Name = "FenceCollider",
		Size = Vector3.new(0.6, 3.2, length),
		CFrame = look + Vector3.new(0, 2, 0),
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
	})
end

local function buildSection(plot: Model, cf: CFrame, sectionIndex: number): (BasePart, BillboardGui)
	local section = model(plot, `Section{sectionIndex}`)
	local centre = Map.sectionCentres[sectionIndex]
	local size = Map.sectionSize
	part(section, {
		Name = "Soil",
		Size = Vector3.new(size.X, 0.3, size.Y),
		CFrame = cf * CFrame.new(centre + Vector3.new(0, 0.5, 0)),
		Color = Palette.soil,
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
	-- The fence opens toward the cross path in the middle of the farm.
	local hx, hz = size.X / 2, size.Y / 2
	local gateSide = if centre.X < 0 then 1 else -1 -- the side facing the centre line
	local corners = {
		Vector3.new(-hx, 0, -hz),
		Vector3.new(hx, 0, -hz),
		Vector3.new(hx, 0, hz),
		Vector3.new(-hx, 0, hz),
	}
	local fences = folder(section, "Fence")
	for i = 1, 4 do
		local a, b = centre + corners[i], centre + corners[i % 4 + 1]
		local isGateSide = math.abs(a.X - b.X) < 0.01 and math.sign(a.X - centre.X) == gateSide
		if isGateSide then
			-- leave a 6-stud opening in the middle for the gate
			local mid = (a + b) / 2
			local dir = (b - a).Unit
			fenceLine(fences, a, mid - dir * 3, cf)
			fenceLine(fences, mid + dir * 3, b, cf)
		else
			fenceLine(fences, a, b, cf)
		end
	end
	local gateCentre = centre + Vector3.new(gateSide * hx, 0, 0)
	local gate = part(section, {
		Name = "Gate",
		Size = Vector3.new(0.4, 2.8, 6),
		CFrame = cf * CFrame.new(gateCentre + Vector3.new(0, 1.8, 0)),
		Color = Palette.wood,
	})
	gate:SetAttribute("ClosedCFrame", gate.CFrame)
	local signPost = decor(section, {
		Name = "Sign",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = cf * CFrame.new(centre + Vector3.new(0, 3, 0)),
		Transparency = 1,
	})
	local sign = billboard(signPost, "", 3, 90, 14)
	sign.Name = "LockSign"
	return gate, sign
end

local function buildPad(plot: Instance, cf: CFrame, padIndex: number): (BasePart, BillboardGui)
	local offset = Map.padOffsets[padIndex]
	local pad = part(plot, {
		Name = `Pad{padIndex}`,
		Size = Vector3.new(Map.padSize, 0.5, Map.padSize),
		CFrame = cf * CFrame.new(offset + Vector3.new(0, 0.85, 0)),
		Color = Palette.pad,
		CanCollide = false,
	})
	pad:SetAttribute("PadIndex", padIndex)
	decor(plot, {
		Name = "PadRim",
		Size = Vector3.new(Map.padSize + 0.8, 0.4, Map.padSize + 0.8),
		CFrame = pad.CFrame * CFrame.new(0, -0.1, 0),
		Color = Palette.woodDark,
	})
	local lock = Instance.new("BillboardGui")
	lock.Name = "Lock"
	lock.Size = UDim2.fromScale(3, 3)
	lock.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	lock.MaxDistance = 70
	lock.LightInfluence = 0
	lock.Adornee = pad
	textLabel(lock, { Text = "🔒" })
	lock.Parent = pad
	return pad, lock
end

local function buildRollStation(plot: Model, cf: CFrame, colour: Color3): BasePart
	local station = model(plot, "RollStation")
	local at = cf * CFrame.new(Map.rollStation)
	local base = part(station, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 9, 9),
		CFrame = at * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.stone,
	})
	part(station, {
		Name = "Body",
		Size = Vector3.new(5, 5, 5),
		CFrame = at * CFrame.new(0, 3.9, 0),
		Color = colour,
	})
	decor(station, {
		Name = "Band",
		Size = Vector3.new(5.2, 0.8, 5.2),
		CFrame = at * CFrame.new(0, 5.2, 0),
		Color = Palette.coin,
		Material = Enum.Material.Neon,
	})
	decor(station, {
		Name = "Globe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		CFrame = at * CFrame.new(0, 8.6, 0),
		Color = Color3.fromRGB(200, 236, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	})
	decor(station, {
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2.6, 2),
		CFrame = at * CFrame.new(0, 8.4, 0),
		Color = Palette.fence,
	})
	base:SetAttribute("Station", "Roll")
	billboard(base, "ROLL", 12, 90, 6)
	return base
end

local function buildHatchPlatform(plot: Model, cf: CFrame): (BasePart, { BasePart })
	local hatchery = model(plot, "HatchPlatform")
	local at = cf * CFrame.new(Map.hatchPlatform)
	local base = part(hatchery, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 18, 18),
		CFrame = at * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.fence,
	})
	local incubators: { BasePart } = {}
	for i, offset in Map.incubatorOffsets do
		local pedestal = part(hatchery, {
			Name = `Incubator{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 4, 4),
			CFrame = at * CFrame.new(offset + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Palette.stoneDark,
		})
		pedestal:SetAttribute("IncubatorIndex", i)
		decor(hatchery, {
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4.4, 4.4),
			CFrame = pedestal.CFrame * CFrame.new(0.85, 0, 0),
			Color = Palette.coin,
			Material = Enum.Material.Neon,
		})
		table.insert(incubators, pedestal)
	end
	base:SetAttribute("Station", "Hatch")
	billboard(base, "HATCHERY", 9, 90, 8)
	return base, incubators
end

local function buildGateArch(plot: Model, cf: CFrame, colour: Color3): (TextLabel, TextLabel, ImageLabel)
	local arch = model(plot, "GateArch")
	local at = cf * CFrame.new(Map.gate)
	for _, side in { -1, 1 } do
		part(arch, {
			Name = "Post",
			Size = Vector3.new(2, 14, 2),
			CFrame = at * CFrame.new(side * 11, 7, 0),
			Color = Palette.wood,
		})
		decor(arch, {
			Name = "Banner",
			Size = Vector3.new(0.3, 7, 3),
			CFrame = at * CFrame.new(side * 12.2, 8, 0),
			Color = colour,
		})
	end
	part(arch, {
		Name = "Beam",
		Size = Vector3.new(26, 1.6, 2.4),
		CFrame = at * CFrame.new(0, 14.4, 0),
		Color = Palette.woodDark,
	})
	local board = decor(arch, {
		Name = "SignBoard",
		Size = Vector3.new(18, 5, 0.6),
		CFrame = at * CFrame.new(0, 11, 0.8),
		Color = colour,
	})
	-- The sign faces the avenue (plot-local +Z is out of the gate).
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerSign"
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(720, 200)
	gui.LightInfluence = 0
	gui.Parent = board
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.Size = UDim2.fromOffset(170, 170)
	avatar.Position = UDim2.fromOffset(16, 15)
	avatar.Image = ""
	avatar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = avatar
	local name = textLabel(gui, {
		Name = "OwnerName",
		Text = "Open plot",
		Size = UDim2.fromOffset(510, 110),
		Position = UDim2.fromOffset(196, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local info = textLabel(gui, {
		Name = "Info",
		Text = "",
		Size = UDim2.fromOffset(510, 60),
		Position = UDim2.fromOffset(196, 126),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 248, 220),
	})
	return name, info, avatar
end

local function buildPlot(world: Model, slotIndex: number): PlotHandles
	local slot = Map.plots[slotIndex]
	local cf = slot.cframe
	local colour = PLOT_COLOURS[slotIndex]
	local plot = model(world, `Plot{slotIndex}`)
	plot:SetAttribute("PlotIndex", slotIndex)
	plot:SetAttribute("OwnerUserId", 0)

	part(plot, {
		Name = "Floor",
		Size = Vector3.new(Map.plotWidth, 0.4, Map.plotDepth),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = Palette.plotGrass,
		Material = Enum.Material.Grass,
	})
	-- Path from the gate through the front yard to the farm's cross path.
	part(plot, {
		Name = "Path",
		Size = Vector3.new(8, 0.2, Map.plotDepth - 4),
		CFrame = cf * CFrame.new(0, 0.5, 2),
		Color = Palette.path,
		CanCollide = false,
	})
	part(plot, {
		Name = "CrossPath",
		Size = Vector3.new(Map.plotWidth - 8, 0.2, 8),
		CFrame = cf * CFrame.new(0, 0.5, -21),
		Color = Palette.path,
		CanCollide = false,
	})
	part(plot, {
		Name = "Yard",
		Size = Vector3.new(60, 0.2, 22),
		CFrame = cf * CFrame.new(0, 0.48, 38),
		Color = Palette.pathEdge,
		CanCollide = false,
	})

	-- Hedges on three sides and either side of the gate.
	local hedges = folder(plot, "Hedges")
	local hw, hd = Map.plotWidth / 2, Map.plotDepth / 2
	for _, data in
		{
			{ Vector3.new(3, 4, Map.plotDepth), Vector3.new(-hw + 1.5, 2.4, 0) },
			{ Vector3.new(3, 4, Map.plotDepth), Vector3.new(hw - 1.5, 2.4, 0) },
			{ Vector3.new(Map.plotWidth, 4, 3), Vector3.new(0, 2.4, -hd + 1.5) },
			{ Vector3.new(hw - 12, 4, 3), Vector3.new(-(hw + 12) / 2, 2.4, hd - 1.5) },
			{ Vector3.new(hw - 12, 4, 3), Vector3.new((hw + 12) / 2, 2.4, hd - 1.5) },
		}
	do
		part(hedges, {
			Name = "Hedge",
			Size = data[1],
			CFrame = cf * CFrame.new(data[2]),
			Color = Palette.hedge,
			Material = Enum.Material.Grass,
		})
	end

	local signName, signInfo, signAvatar = buildGateArch(plot, cf, colour)
	local rollStation = buildRollStation(plot, cf, colour)
	local hatchPlatform, incubators = buildHatchPlatform(plot, cf)

	local pads, padLocks = {}, {}
	local padFolder = folder(plot, "Pads")
	for i = 1, #Map.padOffsets do
		local pad, lock = buildPad(padFolder, cf, i)
		pads[i] = pad
		padLocks[i] = lock
	end
	local sectionGates, sectionSigns = {}, {}
	for i = 1, #Map.sectionCentres do
		local gate, sign = buildSection(plot, cf, i)
		sectionGates[i] = gate
		sectionSigns[i] = sign
	end

	-- Decoration: hay bales and a little tree in the front yard corners.
	local yard = folder(plot, "Decor")
	hayBale(yard, cf * CFrame.new(-40, 2.1, 50))
	hayBale(yard, cf * CFrame.new(-36.6, 2.1, 50))
	hayBale(yard, cf * CFrame.new(-38.3, 5.1, 50))
	tree(yard, (cf * CFrame.new(40, 0.4, 50)).Position, 0.9, Random.new(slotIndex))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = cf * CFrame.new(Map.spawn + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(180), 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Enabled = false -- used only through Player.RespawnLocation
	spawn.Parent = plot
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local petsFolder = folder(plot, "Pets")

	return {
		index = slotIndex,
		model = plot,
		cframe = cf,
		colour = colour,
		pads = pads,
		padLocks = padLocks,
		sectionSigns = sectionSigns,
		sectionGates = sectionGates,
		signName = signName,
		signInfo = signInfo,
		signAvatar = signAvatar,
		spawn = spawn,
		rollStation = rollStation,
		hatchPlatform = hatchPlatform,
		incubators = incubators,
		petsFolder = petsFolder,
	}
end

--------------------------------------------------------------------------------

export type World = {
	model: Model,
	hub: HubHandles,
	plots: { PlotHandles },
}

function MapBuilder.build(parent: Instance): World
	local world = model(parent, "World")
	buildGround(world)
	local hub = buildHub(world)
	local plotsModel = model(world, "Plots")
	local plots = {}
	for i = 1, #Map.plots do
		plots[i] = buildPlot(plotsModel, i)
	end
	return { model = world, hub = hub, plots = plots }
end

MapBuilder.Palette = Palette

return MapBuilder
