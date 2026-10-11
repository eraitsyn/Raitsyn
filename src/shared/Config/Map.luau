--!strict
-- World layout in studs. The hub sits at the origin; two rows of four plots
-- face it from the north and south. Plot-local positions use a frame whose +Z
-- points out of the plot's gate toward the hub, so every plot is identical
-- and only its CFrame differs. MapBuilder (server) builds from this, and the
-- client reads the same numbers for station ranges and camera framing.

export type PlotSlot = {
	index: number,
	-- Plot centre at ground level. LookVector points into the plot, away from
	-- the hub, so plot-local +Z points out of the gate and local +X is the
	-- right-hand side for someone who just walked in.
	cframe: CFrame,
}

local PLOT_WIDTH = 100
local PLOT_DEPTH = 120
local ROW_Z = 150 -- distance from the hub centre to a plot row's centre line
local PLOT_XS = { -174, -58, 58, 174 }

local plots: { PlotSlot } = {}
local function facingAwayFromHub(position: Vector3): CFrame
	local away = Vector3.new(0, 0, math.sign(position.Z))
	return CFrame.lookAt(position, position + away)
end

for i, x in PLOT_XS do
	table.insert(plots, { index = i, cframe = facingAwayFromHub(Vector3.new(x, 0, -ROW_Z)) }) -- north row
end
for i, x in PLOT_XS do
	table.insert(plots, { index = #PLOT_XS + i, cframe = facingAwayFromHub(Vector3.new(x, 0, ROW_Z)) }) -- south row
end

-- Pads: four fenced sections of six (3 columns x 2 rows), unlocked in order.
-- Section order: front-left, front-right, back-left, back-right, as seen by
-- someone walking in through the gate.
local SECTION_CENTRES = {
	Vector3.new(-24, 0, -2),
	Vector3.new(24, 0, -2),
	Vector3.new(-24, 0, -40),
	Vector3.new(24, 0, -40),
}
local PAD_COLUMNS = { -13, 0, 13 }
local PAD_ROWS = { 6, -6 }

local padOffsets: { Vector3 } = {}
for _, centre in SECTION_CENTRES do
	for _, row in PAD_ROWS do
		for _, column in PAD_COLUMNS do
			table.insert(padOffsets, centre + Vector3.new(column, 0, row))
		end
	end
end

return table.freeze({
	plotWidth = PLOT_WIDTH,
	plotDepth = PLOT_DEPTH,
	plots = table.freeze(plots),
	maxPlayers = #plots,

	-- Plot-local positions (Vector3 offsets from the plot CFrame).
	gate = Vector3.new(0, 0, PLOT_DEPTH / 2),
	spawn = Vector3.new(0, 0, 46),
	rollStation = Vector3.new(-18, 0, 38),
	hatchPlatform = Vector3.new(18, 0, 38),
	sectionCentres = table.freeze(SECTION_CENTRES),
	sectionSize = Vector2.new(42, 26),
	padsPerSection = 6,
	padOffsets = table.freeze(padOffsets),
	padSize = 10,
	incubatorOffsets = table.freeze({ -- around the hatch platform centre
		Vector3.new(-4.5, 0, -4.5),
		Vector3.new(4.5, 0, -4.5),
		Vector3.new(-4.5, 0, 4.5),
		Vector3.new(4.5, 0, 4.5),
	}),

	-- Hub, world positions.
	plaza = Vector3.new(0, 0, 0),
	plazaRadius = 34,
	upgradeShop = Vector3.new(-150, 0, 0),
	rebirthStation = Vector3.new(150, 0, 0),
	indexBoard = Vector3.new(0, 0, -66),
	dailyKiosk = Vector3.new(-104, 0, -56),
	leaderboards = table.freeze({
		Vector3.new(-104, 0, 62),
		Vector3.new(0, 0, 68),
		Vector3.new(104, 0, 62),
	}),

	-- Whole map bounds (walls sit on these).
	bounds = Vector2.new(520, 470),

	-- Interaction ranges, in studs from a station's centre. The server allows a
	-- little more than the client uses to show its panel, so lag at the edge
	-- of the range never turns into a refused request.
	stationRange = 16,
	serverStationRange = 24,
	plazaRange = 40,
})
