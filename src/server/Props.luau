--[[
	Props: small low-poly scenery for each biome, built from parts. Used for
	the biome areas and for the decorations a base earns as biomes unlock.

	Each builder returns a Model standing on y = 0 around the origin.
]]

local ModelFactory = require(script.Parent.ModelFactory)

local block = ModelFactory.Block

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function ball(
	model: Model,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = block(model, name, Vector3.one * diameter, position, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function cylinder(
	model: Model,
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = block(
		model,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function tree(model: Model, trunk: Color3, leaves: Color3, height: number)
	block(model, "Trunk", Vector3.new(1.2, height, 1.2), Vector3.new(0, height / 2, 0), trunk, Enum.Material.Wood)
	block(model, "Leaves", Vector3.new(5, 4, 5), Vector3.new(0, height + 1.5, 0), leaves, Enum.Material.Grass)
	block(model, "LeavesTop", Vector3.new(3, 2, 3), Vector3.new(0, height + 4, 0), leaves, Enum.Material.Grass)
end

local function pine(model: Model, leaves: Color3, snow: boolean)
	block(model, "Trunk", Vector3.new(1, 3, 1), Vector3.new(0, 1.5, 0), rgb(100, 70, 40), Enum.Material.Wood)
	for index, size in { 6, 4.5, 3 } do
		local tier = block(
			model,
			`Tier{index}`,
			Vector3.new(size, 2.4, size),
			Vector3.new(0, 2.5 + index * 2.1, 0),
			leaves,
			Enum.Material.Grass
		)
		if snow then
			block(
				model,
				`Snow{index}`,
				Vector3.new(size * 0.8, 0.4, size * 0.8),
				tier.Position + Vector3.new(0, 1.3, 0),
				rgb(250, 250, 255),
				Enum.Material.Snow
			)
		end
	end
end

local function rock(model: Model, color: Color3, size: number, material: Enum.Material?)
	block(
		model,
		"Rock",
		Vector3.new(size, size * 0.7, size * 0.9),
		CFrame.new(0, size * 0.3, 0) * CFrame.Angles(0, 0.5, 0.1),
		color,
		material or Enum.Material.Slate
	)
end

local PROPS: { [string]: { (model: Model, random: Random) -> () } } = {
	Farm = {
		function(model)
			block(model, "Barn", Vector3.new(8, 6, 7), Vector3.new(0, 3, 0), rgb(190, 50, 40), Enum.Material.WoodPlanks)
			block(model, "Roof", Vector3.new(9, 1, 8), Vector3.new(0, 6.5, 0), rgb(240, 240, 240))
			block(model, "Door", Vector3.new(3, 4, 0.2), Vector3.new(0, 2, -3.55), rgb(250, 250, 250))
		end,
		function(model)
			block(
				model,
				"Hay",
				Vector3.new(3, 2.2, 2.2),
				Vector3.new(0, 1.1, 0),
				rgb(235, 200, 90),
				Enum.Material.Fabric
			)
		end,
		function(model)
			for index = -1, 1 do
				block(
					model,
					`Post{index}`,
					Vector3.new(0.5, 2.4, 0.5),
					Vector3.new(index * 3, 1.2, 0),
					rgb(240, 230, 210),
					Enum.Material.Wood
				)
			end
			block(
				model,
				"Rail",
				Vector3.new(6.5, 0.4, 0.3),
				Vector3.new(0, 1.8, 0),
				rgb(240, 230, 210),
				Enum.Material.Wood
			)
		end,
		function(model)
			tree(model, rgb(110, 75, 45), rgb(90, 170, 60), 4)
		end,
	},
	Forest = {
		function(model)
			pine(model, rgb(40, 110, 50), false)
		end,
		function(model)
			tree(model, rgb(100, 70, 40), rgb(60, 140, 50), 6)
		end,
		function(model)
			cylinder(model, "Log", 5, 1.4, Vector3.new(0, 0.7, 0), rgb(120, 85, 50), Enum.Material.Wood)
		end,
		function(model)
			block(model, "Stem", Vector3.new(0.5, 1.2, 0.5), Vector3.new(0, 0.6, 0), rgb(240, 230, 210))
			ball(model, "Cap", 1.8, Vector3.new(0, 1.4, 0), rgb(220, 50, 50))
		end,
	},
	Desert = {
		function(model)
			block(
				model,
				"Cactus",
				Vector3.new(1.4, 6, 1.4),
				Vector3.new(0, 3, 0),
				rgb(80, 150, 70),
				Enum.Material.Grass
			)
			block(
				model,
				"ArmL",
				Vector3.new(1, 2.5, 1),
				Vector3.new(-1.3, 3.8, 0),
				rgb(80, 150, 70),
				Enum.Material.Grass
			)
			block(model, "ArmR", Vector3.new(1, 2, 1), Vector3.new(1.3, 4.6, 0), rgb(80, 150, 70), Enum.Material.Grass)
		end,
		function(model)
			block(
				model,
				"Dune",
				Vector3.new(10, 2, 6),
				CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, 0.12),
				rgb(230, 195, 120),
				Enum.Material.Sand
			)
		end,
		function(model)
			rock(model, rgb(190, 140, 90), 3, Enum.Material.Sandstone)
		end,
		function(model)
			block(
				model,
				"Pyramid1",
				Vector3.new(6, 1.5, 6),
				Vector3.new(0, 0.75, 0),
				rgb(220, 190, 110),
				Enum.Material.Sandstone
			)
			block(
				model,
				"Pyramid2",
				Vector3.new(4.2, 1.5, 4.2),
				Vector3.new(0, 2.25, 0),
				rgb(220, 190, 110),
				Enum.Material.Sandstone
			)
			block(
				model,
				"Pyramid3",
				Vector3.new(2.4, 1.5, 2.4),
				Vector3.new(0, 3.75, 0),
				rgb(220, 190, 110),
				Enum.Material.Sandstone
			)
		end,
	},
	Snow = {
		function(model)
			pine(model, rgb(40, 100, 70), true)
		end,
		function(model)
			ball(model, "Bottom", 2.6, Vector3.new(0, 1.3, 0), rgb(250, 250, 255), Enum.Material.Snow)
			ball(model, "Middle", 1.9, Vector3.new(0, 3.1, 0), rgb(250, 250, 255), Enum.Material.Snow)
			ball(model, "Head", 1.3, Vector3.new(0, 4.5, 0), rgb(250, 250, 255), Enum.Material.Snow)
			block(model, "Nose", Vector3.new(0.25, 0.25, 0.7), Vector3.new(0, 4.5, -0.8), rgb(255, 140, 30))
		end,
		function(model)
			block(
				model,
				"Ice",
				Vector3.new(2, 5, 2),
				CFrame.new(0, 2.3, 0) * CFrame.Angles(0.2, 0.4, 0.15),
				rgb(170, 220, 255),
				Enum.Material.Ice
			)
		end,
		function(model)
			rock(model, rgb(220, 230, 245), 3.5, Enum.Material.Snow)
		end,
	},
	Jungle = {
		function(model)
			block(
				model,
				"Trunk",
				Vector3.new(1, 8, 1),
				CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, 0.12),
				rgb(130, 95, 60),
				Enum.Material.Wood
			)
			for index = 0, 3 do
				local angle = index * math.pi / 2
				block(
					model,
					`Frond{index}`,
					Vector3.new(1.2, 0.3, 5),
					CFrame.new(0.5, 8, 0)
						* CFrame.Angles(0, angle, 0)
						* CFrame.new(0, 0, 2.2)
						* CFrame.Angles(-0.35, 0, 0),
					rgb(40, 150, 60),
					Enum.Material.Grass
				)
			end
		end,
		function(model)
			tree(model, rgb(90, 60, 35), rgb(30, 120, 50), 7)
		end,
		function(model)
			for index = 0, 2 do
				block(
					model,
					`Leaf{index}`,
					Vector3.new(0.3, 3, 2),
					CFrame.new(0, 1.3, 0) * CFrame.Angles(0, index * 2.1, 0.5),
					rgb(50, 170, 70),
					Enum.Material.Grass
				)
			end
			ball(model, "Flower", 0.9, Vector3.new(0, 2.6, 0), rgb(255, 90, 160), Enum.Material.Neon)
		end,
		function(model)
			rock(model, rgb(90, 110, 80), 3, Enum.Material.Slate)
		end,
	},
	Ocean = {
		function(model)
			block(
				model,
				"Water",
				Vector3.new(12, 0.4, 8),
				Vector3.new(0, 0.2, 0),
				rgb(40, 140, 230),
				Enum.Material.Glass
			).Transparency =
				0.3
		end,
		function(model)
			for index = 0, 3 do
				block(
					model,
					`Coral{index}`,
					Vector3.new(0.6, 1.5 + index * 0.6, 0.6),
					CFrame.new(index * 0.5 - 0.7, 1, 0) * CFrame.Angles(0, 0, index * 0.3 - 0.4),
					rgb(255, 110, 120),
					Enum.Material.SmoothPlastic
				)
			end
		end,
		function(model)
			block(model, "Shell", Vector3.new(2, 0.6, 1.6), Vector3.new(0, 0.3, 0), rgb(250, 220, 210))
			block(
				model,
				"Chest",
				Vector3.new(2.6, 1.6, 1.8),
				Vector3.new(3, 0.8, 0),
				rgb(140, 90, 40),
				Enum.Material.WoodPlanks
			)
		end,
		function(model)
			block(
				model,
				"Trunk",
				Vector3.new(1, 7, 1),
				CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, -0.15),
				rgb(150, 110, 70),
				Enum.Material.Wood
			)
			ball(model, "Coconuts", 1.4, Vector3.new(-0.9, 7, 0), rgb(110, 70, 40))
			block(
				model,
				"Fronds",
				Vector3.new(6, 0.4, 6),
				Vector3.new(-1, 7.4, 0),
				rgb(50, 160, 70),
				Enum.Material.Grass
			)
		end,
	},
	Volcano = {
		function(model)
			block(model, "Lava", Vector3.new(8, 0.4, 6), Vector3.new(0, 0.2, 0), rgb(255, 90, 20), Enum.Material.Neon)
		end,
		function(model)
			rock(model, rgb(40, 35, 35), 4, Enum.Material.Basalt)
			block(
				model,
				"Glow",
				Vector3.new(0.6, 2, 0.6),
				Vector3.new(0.8, 2.4, 0),
				rgb(255, 120, 0),
				Enum.Material.Neon
			)
		end,
		function(model)
			block(model, "Cone1", Vector3.new(7, 3, 7), Vector3.new(0, 1.5, 0), rgb(70, 50, 45), Enum.Material.Basalt)
			block(
				model,
				"Cone2",
				Vector3.new(4.5, 3, 4.5),
				Vector3.new(0, 4.5, 0),
				rgb(70, 50, 45),
				Enum.Material.Basalt
			)
			block(
				model,
				"Crater",
				Vector3.new(2.5, 0.4, 2.5),
				Vector3.new(0, 6.1, 0),
				rgb(255, 100, 0),
				Enum.Material.Neon
			)
		end,
		function(model)
			block(
				model,
				"Crystal",
				Vector3.new(1, 4, 1),
				CFrame.new(0, 2, 0) * CFrame.Angles(0.2, 0, 0.2),
				rgb(60, 20, 80),
				Enum.Material.Glass
			)
		end,
	},
	Prehistoric = {
		function(model)
			for index = 0, 2 do
				block(
					model,
					`Frond{index}`,
					Vector3.new(0.3, 4, 1.6),
					CFrame.new(0, 2, 0) * CFrame.Angles(0, index * 2.1, 0.45),
					rgb(70, 140, 50),
					Enum.Material.Grass
				)
			end
		end,
		function(model)
			for index = 0, 3 do
				block(
					model,
					`Rib{index}`,
					Vector3.new(0.4, 3, 0.4),
					CFrame.new(0, 1.5, index * 1.2) * CFrame.Angles(0, 0, 0.6),
					rgb(240, 235, 215)
				)
				block(
					model,
					`RibR{index}`,
					Vector3.new(0.4, 3, 0.4),
					CFrame.new(0, 1.5, index * 1.2) * CFrame.Angles(0, 0, -0.6),
					rgb(240, 235, 215)
				)
			end
		end,
		function(model)
			tree(model, rgb(110, 80, 50), rgb(90, 150, 60), 8)
		end,
		function(model)
			rock(model, rgb(120, 100, 80), 4, Enum.Material.Rock)
		end,
	},
	Kingdom = {
		function(model)
			block(
				model,
				"Tower",
				Vector3.new(4, 10, 4),
				Vector3.new(0, 5, 0),
				rgb(170, 170, 180),
				Enum.Material.Cobblestone
			)
			block(model, "Roof", Vector3.new(5, 2, 5), Vector3.new(0, 11, 0), rgb(60, 70, 160))
			block(model, "Flag", Vector3.new(0.2, 1.4, 2), Vector3.new(0, 13, 1), rgb(220, 40, 40))
		end,
		function(model)
			block(
				model,
				"Wall",
				Vector3.new(10, 4, 1.5),
				Vector3.new(0, 2, 0),
				rgb(160, 160, 170),
				Enum.Material.Cobblestone
			)
			for index = -2, 2 do
				block(
					model,
					`Battlement{index}`,
					Vector3.new(1.2, 1, 1.5),
					Vector3.new(index * 2, 4.5, 0),
					rgb(160, 160, 170),
					Enum.Material.Cobblestone
				)
			end
		end,
		function(model)
			tree(model, rgb(100, 70, 40), rgb(70, 150, 70), 3)
		end,
		function(model)
			block(model, "Banner", Vector3.new(0.4, 6, 0.4), Vector3.new(0, 3, 0), rgb(200, 170, 60))
			block(model, "Cloth", Vector3.new(0.1, 3, 2), Vector3.new(0, 4.2, 1), rgb(160, 30, 60))
		end,
	},
	Skylands = {
		function(model, random)
			local height = 5 + random:NextNumber() * 5
			for index = 0, 2 do
				ball(
					model,
					`Puff{index}`,
					3 + index,
					Vector3.new(index * 2 - 2, height, 0),
					rgb(255, 255, 255),
					Enum.Material.SmoothPlastic
				)
			end
		end,
		function(model, random)
			local height = 4 + random:NextNumber() * 6
			block(
				model,
				"Island",
				Vector3.new(6, 2, 6),
				Vector3.new(0, height, 0),
				rgb(120, 200, 100),
				Enum.Material.Grass
			)
			block(
				model,
				"Under",
				Vector3.new(4, 2, 4),
				Vector3.new(0, height - 2, 0),
				rgb(130, 100, 80),
				Enum.Material.Rock
			)
		end,
		function(model)
			block(
				model,
				"Pillar",
				Vector3.new(1.6, 7, 1.6),
				Vector3.new(0, 3.5, 0),
				rgb(245, 245, 250),
				Enum.Material.Marble
			)
		end,
		function(model)
			ball(model, "Orb", 1.6, Vector3.new(0, 3, 0), rgb(150, 210, 255), Enum.Material.Neon)
		end,
	},
	Cosmic = {
		function(model, random)
			local planet = ball(
				model,
				"Planet",
				4 + random:NextNumber() * 3,
				Vector3.new(0, 8 + random:NextNumber() * 6, 0),
				rgb(120 + random:NextInteger(0, 120), 80, 200),
				Enum.Material.Neon
			)
			cylinder(
				model,
				"PlanetRing",
				0.2,
				planet.Size.X * 1.7,
				planet.Position,
				rgb(230, 200, 255),
				Enum.Material.Neon
			).Transparency =
				0.4
		end,
		function(model)
			block(
				model,
				"Crystal",
				Vector3.new(1.2, 5, 1.2),
				CFrame.new(0, 2.4, 0) * CFrame.Angles(0.15, 0.6, 0.2),
				rgb(170, 110, 255),
				Enum.Material.Neon
			)
		end,
		function(model, random)
			ball(
				model,
				"Star",
				0.8,
				Vector3.new(0, 6 + random:NextNumber() * 10, 0),
				rgb(255, 250, 200),
				Enum.Material.Neon
			)
		end,
		function(model)
			rock(model, rgb(60, 50, 90), 3.5, Enum.Material.Slate)
		end,
	},
}

local Props = {}

-- A random prop for the biome, from a seeded Random so the map is the same every time.
function Props.Build(biomeId: string, random: Random, choice: number?): Model
	local builders = PROPS[biomeId]
	local model = Instance.new("Model")
	model.Name = `{biomeId}Prop`
	builders[choice or random:NextInteger(1, #builders)](model, random)
	model.WorldPivot = CFrame.new()
	return model
end

return Props
