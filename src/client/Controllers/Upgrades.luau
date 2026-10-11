--!strict
-- The hexagon upgrade tree: a full-screen blueprint canvas with all 43 tiles
-- on their axial coordinates, connection lines that light up as you buy,
-- five tile states (locked, milestone-locked, available, owned, maxed),
-- drag or swipe to pan, wheel or pinch to zoom, and a side sheet with the
-- selected tile's effect now and next, its price and a Buy button.
-- Availability comes from the shared HexGraph, the same code the server
-- checks purchases with.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Costs = require(Logic:WaitForChild("Costs"))
local Describe = require(Logic:WaitForChild("Describe"))
local Format = require(Logic:WaitForChild("Format"))
local HexGraph = require(Logic:WaitForChild("HexGraph"))
local HexTree = require(Config:WaitForChild("HexTree"))
local Stats = require(Logic:WaitForChild("Stats"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))
local Sfx = require(Client:WaitForChild("Sfx"))

local Upgrades = {}

local R = 54 -- hex circumradius in pixels
local SPACING = 1.12 -- gap between hexes
local CANVAS = 1400 -- canvas half-size in pixels
local MIN_ZOOM, MAX_ZOOM = 0.5, 1.5

local CATEGORY_COLOURS: { [string]: Color3 } = {
	Core = Color3.fromRGB(255, 200, 40),
	Income = Color3.fromRGB(88, 204, 104),
	Luck = Color3.fromRGB(46, 196, 170),
	Rolling = Color3.fromRGB(74, 156, 255),
	Hatching = Color3.fromRGB(255, 150, 60),
	Farm = Color3.fromRGB(164, 196, 64),
	Economy = Color3.fromRGB(255, 110, 160),
}

-- An icon per tile, from its first effect.
local STAT_ICONS: { [string]: string } = {
	petIncomeAdd = "💰",
	globalMultiplier = "✖️",
	critChance = "⚡",
	critMultiplier = "⚡",
	collectorBonusPerSpecies = "📖",
	luckAdd = "🍀",
	luckMultiplier = "🍀",
	secretLuckAdd = "🔮",
	secretLuckMultiplier = "🔮",
	luckyRollMultiplier = "🎯",
	variantChanceAdd = "✨",
	rollCooldownReduction = "⏩",
	rollCooldownFloor = "⏩",
	autoRoll = "🔁",
	hatchTimeReduction = "⏱️",
	hatchTimeMultiplier = "⏱️",
	incubators = "🥚",
	autoHatch = "🐣",
	padSlots = "🌾",
	petCapacity = "🎒",
	eggCapacity = "🧺",
	eggDiscount = "🏷️",
	offlineRate = "🌙",
	offlineCapHours = "🌙",
}

type TileView = {
	tile: HexTree.Tile,
	root: Frame,
	border: { Frame },
	fill: { Frame },
	icon: TextLabel,
	level: TextLabel,
	lock: TextLabel,
	glow: UIStroke?,
}

type LineView = { frame: Frame, a: string, b: string }

local function hexCentre(tile: HexTree.Tile): Vector2
	local x = R * SPACING * 1.5 * tile.q
	local y = R * SPACING * math.sqrt(3) * (tile.r + tile.q / 2)
	return Vector2.new(x, y)
end

-- A flat-topped hexagon made of three rotated rectangles.
local function hexagon(parent: Instance, radius: number, colour: Color3, z: number): { Frame }
	local parts = {}
	for i = 0, 2 do
		parts[i + 1] = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius, radius * math.sqrt(3)),
			Rotation = 60 * i,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = parent,
		})
	end
	return parts
end

local function paint(parts: { Frame }, colour: Color3, transparency: number)
	for _, part in parts do
		part.BackgroundColor3 = colour
		part.BackgroundTransparency = transparency
	end
end

local function progress()
	return Stats.progressOf(State.data)
end

function Upgrades.start()
	-- Full-screen panel
	local root = Kit.new("Frame", {
		Name = "Upgrades",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.blueprint,
		ClipsDescendants = true,
		Visible = false,
	})
	local handle: Root.PanelHandle = { root = root, fullscreen = true }
	App.registerPanel("Upgrades", handle)

	-- Blueprint grid lines
	local grid = Kit.new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	for i = 1, 40 do
		Kit.new("Frame", {
			BackgroundColor3 = Theme.color.blueprintLine,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.fromScale(i / 40, 0),
			Parent = grid,
		})
		Kit.new("Frame", {
			BackgroundColor3 = Theme.color.blueprintLine,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, i / 40),
			Parent = grid,
		})
	end

	-- Canvas holding lines and tiles. Its centre is the Farm Heart.
	local viewport = Kit.new("Frame", {
		Name = "Viewport",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	local canvas = Kit.new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS * 2, CANVAS * 2),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = viewport,
	})
	local zoomScale = Kit.new("UIScale", { Parent = canvas })
	local pan = Vector2.zero
	local zoom = 1

	local function applyView()
		canvas.Position = UDim2.new(0.5, pan.X, 0.5, pan.Y)
		zoomScale.Scale = zoom
	end

	-- Connection lines between every pair of neighbouring tiles.
	local lines: { LineView } = {}
	for _, tile in HexTree.tiles do
		for _, other in HexGraph.neighbours(tile.id) do
			-- draw each pair once
			if tile.q < other.q or (tile.q == other.q and tile.r < other.r) then
				local a, b = hexCentre(tile), hexCentre(other)
				local mid = (a + b) / 2
				local delta = b - a
				local frame = Kit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(CANVAS + mid.X, CANVAS + mid.Y),
					Size = UDim2.fromOffset(delta.Magnitude, 6),
					Rotation = math.deg(math.atan2(delta.Y, delta.X)),
					BackgroundColor3 = Theme.color.blueprintLine,
					BorderSizePixel = 0,
					ZIndex = 1,
					Parent = canvas,
				})
				table.insert(lines, { frame = frame, a = tile.id, b = other.id })
			end
		end
	end

	-- Tiles
	local views: { [string]: TileView } = {}
	local selected: string = HexTree.coreId
	local selectTile: (tileId: string) -> ()
	for _, tile in HexTree.tiles do
		local centre = hexCentre(tile)
		local radius = if tile.keystone then R * 1.08 else R
		local frame = Kit.new("Frame", {
			Name = tile.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CANVAS + centre.X, CANVAS + centre.Y),
			Size = UDim2.fromOffset(radius * 2, radius * 2),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = canvas,
		})
		local border = hexagon(frame, radius, Theme.color.white, 2)
		local fill = hexagon(frame, radius - 6, Theme.color.blueprint, 3)
		local firstStat = tile.effects[1] and tile.effects[1].stat or ""
		local icon = Kit.label({
			Text = if tile.id == HexTree.coreId then "❤️" else (STAT_ICONS[firstStat] or "⬢"),
			TextSize = if tile.keystone then 40 else 34,
			Size = UDim2.fromOffset(radius * 1.4, radius),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -8),
			ZIndex = 5,
			Parent = frame,
		})
		local level = Kit.label({
			Text = "",
			FontFace = Theme.font.heading,
			TextSize = 16,
			TextColor3 = Theme.color.white,
			Size = UDim2.fromOffset(radius * 1.4, 20),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 16),
			ZIndex = 5,
			Parent = frame,
		}, true)
		local lock = Kit.label({
			Text = Theme.icon.lock,
			TextSize = 20,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0.5, 14, 0.5, -38),
			ZIndex = 6,
			Visible = false,
			Parent = frame,
		})
		local hit = Kit.new("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius * 1.7, radius * 1.7),
			ZIndex = 7,
			Parent = frame,
		})
		hit.Activated:Connect(function()
			selectTile(tile.id)
		end)
		views[tile.id] = {
			tile = tile,
			root = frame,
			border = border,
			fill = fill,
			icon = icon,
			level = level,
			lock = lock,
		}
	end

	-- Selection outline: a slightly larger white hexagon behind the tile.
	local ring = Kit.new("Frame", {
		Name = "Selection",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(R * 2.4, R * 2.4),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = canvas,
	})
	local ringParts = hexagon(ring, R * 1.2, Theme.color.coin, 1)

	-- Header
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.color.blueprint,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 10,
		Parent = root,
	})
	Kit.label({
		Text = `{Theme.icon.upgrades} Upgrade Tree`,
		FontFace = Theme.font.heading,
		TextSize = 32,
		TextColor3 = Theme.color.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(360, 64),
		Position = UDim2.fromOffset(110, 0),
		ZIndex = 11,
		Parent = header,
	}, true)
	local coins = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 28,
		TextColor3 = Theme.color.coin,
		Size = UDim2.fromOffset(240, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		ZIndex = 11,
		Parent = header,
	}, true)
	local availableButton = Kit.button({
		text = "0 available",
		colour = Theme.color.green,
		size = UDim2.fromOffset(170, 48),
		position = UDim2.new(1, -330, 0, 8),
		textSize = 18,
		parent = header,
	})
	availableButton.root.ZIndex = 11
	Kit.button({
		text = "Recenter",
		colour = Theme.color.blue,
		size = UDim2.fromOffset(120, 48),
		position = UDim2.new(1, -152, 0, 8),
		textSize = 18,
		parent = header,
		onClick = function()
			pan = Vector2.zero
			zoom = 1
			applyView()
		end,
	}).root.ZIndex =
		11
	Kit.button({
		text = Theme.icon.close,
		colour = Theme.color.red,
		size = UDim2.fromOffset(48, 48),
		position = UDim2.new(1, -24, 0, 8),
		anchor = Vector2.new(1, 0),
		textSize = 24,
		parent = header,
		onClick = Root.closePanel,
	}).root.ZIndex =
		11

	-- Legend (bottom left)
	local legend = Kit.new("Frame", {
		Name = "Legend",
		BackgroundColor3 = Theme.color.blueprint,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(0, 110, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 10,
		Parent = root,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(Theme.color.blueprintLine, 2),
		Kit.padding(12, 0),
		Kit.list(Enum.FillDirection.Horizontal, 14),
	})
	local legendEntries: { { name: string, colour: Color3 } } = {
		{ name = "Available", colour = Theme.color.white },
		{ name = "Owned", colour = Theme.color.green },
		{ name = "Maxed", colour = Theme.color.coin },
		{ name = "Needs a milestone", colour = Color3.fromRGB(190, 120, 255) },
		{ name = "Locked", colour = Theme.color.greyDark },
	}
	for i, entry in legendEntries do
		Kit.label({
			Text = `● {entry.name}`,
			FontFace = Theme.font.bold,
			TextSize = 16,
			TextColor3 = entry.colour,
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			TextWrapped = false,
			LayoutOrder = i,
			ZIndex = 11,
			Parent = legend,
		})
	end

	-- Detail sheet (right side; bottom on phones)
	local sheet = Kit.new("Frame", {
		Name = "Sheet",
		BackgroundColor3 = Theme.color.panel,
		Size = UDim2.new(0, 340, 1, -96),
		Position = UDim2.new(1, -356, 0, 80),
		ZIndex = 10,
		Parent = root,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke() })
	local sheetBody = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 1, -100),
		Position = UDim2.fromOffset(16, 14),
		ZIndex = 11,
		Parent = sheet,
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })
	local function sheetLabel(order: number, font: Font, size: number, colour: Color3): TextLabel
		return Kit.label({
			FontFace = font,
			TextSize = size,
			TextColor3 = colour,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			ZIndex = 11,
			Parent = sheetBody,
		})
	end
	local sheetName = sheetLabel(1, Theme.font.heading, 28, Theme.color.text)
	local sheetCategory = sheetLabel(2, Theme.font.bold, 17, Theme.color.muted)
	local sheetDescription = sheetLabel(3, Theme.font.body, 19, Theme.color.text)
	local sheetLevel = sheetLabel(4, Theme.font.bold, 19, Theme.color.text)
	local sheetEffects = sheetLabel(5, Theme.font.body, 18, Theme.color.text)
	sheetEffects.RichText = true
	local sheetPrice = sheetLabel(6, Theme.font.heading, 24, Theme.color.coinDark)
	local sheetReason = sheetLabel(7, Theme.font.bold, 17, Theme.color.red)
	local buyButton = Kit.button({
		text = "Buy",
		colour = Theme.color.green,
		size = UDim2.new(1, -32, 0, 64),
		position = UDim2.new(0, 16, 1, -80),
		textSize = 28,
		parent = sheet,
	})
	buyButton.root.ZIndex = 11

	local function refreshSheet()
		local tile = HexTree.byId[selected]
		local p = progress()
		local level = Stats.levelOf(p, tile.id)
		local colour = CATEGORY_COLOURS[tile.category] or Theme.color.blue
		sheetName.Text = tile.name
		sheetName.TextColor3 = Theme.shade(colour, 0.15)
		sheetCategory.Text = string.upper(tile.category)
			.. (if tile.keystone then " · KEYSTONE (kept through rebirth)" else "")
		sheetDescription.Text = tile.description
		if tile.id == HexTree.coreId then
			sheetLevel.Text = "Owned from the start"
			sheetEffects.Text = "Every path grows out from here. Buy a neighbouring tile to start."
			sheetPrice.Text = ""
			sheetReason.Text = ""
			buyButton.root.Visible = false
			return
		end
		buyButton.root.Visible = true
		sheetLevel.Text = `Level {level}/{tile.maxLevel}`
		local effectLines = {}
		for _, line in Describe.tile(tile.id, level) do
			if line.next then
				table.insert(effectLines, `{line.label}: <b>{line.now}</b>  →  <b>{line.next}</b>`)
			else
				table.insert(effectLines, `{line.label}: <b>{line.now}</b>`)
			end
		end
		sheetEffects.Text = table.concat(effectLines, "\n")
		if level >= tile.maxLevel then
			sheetPrice.Text = "Fully upgraded"
			sheetPrice.TextColor3 = Theme.color.greenDark
			sheetReason.Text = ""
			buyButton.setText("Maxed")
			buyButton.setEnabled(false)
			return
		end
		local price = Costs.tileCost(tile.id, level + 1)
		local ok, reason = HexGraph.canUpgrade(p, tile.id)
		local affordable = State.data.coins >= price
		sheetPrice.Text = `{Theme.icon.coin} {Format.coins(price)}`
		sheetPrice.TextColor3 = if affordable then Theme.color.coinDark else Theme.color.red
		if not ok then
			sheetReason.Text = reason or "Locked"
		elseif not affordable then
			sheetReason.Text = `Need {Format.coins(price - State.data.coins)} more`
		else
			sheetReason.Text = ""
		end
		buyButton.setText(if level > 0 then "Upgrade" else "Buy")
		buyButton.setEnabled(ok and affordable)
	end

	local function refreshTiles()
		local p = progress()
		local available = 0
		for id, view in views do
			local tile = view.tile
			local state = HexGraph.state(p, id)
			local level = Stats.levelOf(p, id)
			local colour = CATEGORY_COLOURS[tile.category] or Theme.color.blue
			view.lock.Visible = state == "Locked" or state == "MilestoneLocked"
			view.icon.TextTransparency = 0
			if id == HexTree.coreId or state == "Maxed" then
				paint(view.border, Theme.color.coin, 0)
				paint(view.fill, colour, 0)
				view.level.Text = if id == HexTree.coreId then "" else "MAX"
			elseif state == "Owned" then
				paint(view.border, Theme.color.white, 0)
				paint(view.fill, colour, 0)
				view.level.Text = `{level}/{tile.maxLevel}`
			elseif state == "Available" then
				paint(view.border, Theme.color.white, 0)
				paint(view.fill, Theme.shade(colour, 0.55), 0)
				view.level.Text = Format.coins(Costs.tileCost(id, level + 1))
			elseif state == "MilestoneLocked" then
				paint(view.border, Color3.fromRGB(190, 120, 255), 0)
				paint(view.fill, Theme.color.blueprint, 0)
				view.level.Text = ""
				view.icon.TextTransparency = 0.4
			else
				paint(view.border, Theme.color.blueprintLine, 0)
				paint(view.fill, Theme.color.blueprint, 0)
				view.level.Text = ""
				view.icon.TextTransparency = 0.6
			end
			-- affordable next steps
			if state == "Available" or state == "Owned" then
				local ok = HexGraph.canUpgrade(p, id)
				if ok and State.data.coins >= Costs.tileCost(id, level + 1) then
					available += 1
				end
			end
		end
		for _, line in lines do
			local la, lb = Stats.levelOf(p, line.a) > 0, Stats.levelOf(p, line.b) > 0
			if la and lb then
				line.frame.BackgroundColor3 = Theme.color.coin
				line.frame.BackgroundTransparency = 0
			elseif la or lb then
				line.frame.BackgroundColor3 = Theme.color.white
				line.frame.BackgroundTransparency = 0.5
			else
				line.frame.BackgroundColor3 = Theme.color.blueprintLine
				line.frame.BackgroundTransparency = 0.2
			end
		end
		availableButton.setText(`{available} affordable`)
		availableButton.setColour(if available > 0 then Theme.color.green else Theme.color.grey)
		coins.Text = Format.coins(State.data.coins)
		refreshSheet()
	end

	selectTile = function(tileId: string)
		selected = tileId
		local view = views[tileId]
		ring.Position = view.root.Position
		local size = if view.tile.keystone then 1.08 else 1
		ring.Size = UDim2.fromOffset(R * 2.4 * size, R * 2.4 * size)
		for _, part in ringParts do
			part.Size = UDim2.fromOffset(R * 1.2 * size, R * 1.2 * size * math.sqrt(3))
		end
		refreshSheet()
	end

	-- Centres the view on a tile.
	local function focus(tileId: string)
		local centre = hexCentre(HexTree.byId[tileId])
		pan = -centre * zoom
		applyView()
		selectTile(tileId)
	end

	-- The cheapest tile you could buy right now (or the cheapest open one).
	local function cheapestOpen(affordableOnly: boolean): string?
		local p = progress()
		local best, bestPrice = nil, math.huge
		for _, tile in HexTree.tiles do
			local level = Stats.levelOf(p, tile.id)
			if level < tile.maxLevel and HexGraph.canUpgrade(p, tile.id) then
				local price = Costs.tileCost(tile.id, level + 1)
				if price < bestPrice and (not affordableOnly or price <= State.data.coins) then
					best, bestPrice = tile.id, price
				end
			end
		end
		return best
	end

	local cycle = 0
	availableButton.face.Activated:Connect(function()
		-- step through affordable tiles, cheapest first
		local p = progress()
		local list = {}
		for _, tile in HexTree.tiles do
			local level = Stats.levelOf(p, tile.id)
			if level < tile.maxLevel and HexGraph.canUpgrade(p, tile.id) then
				local price = Costs.tileCost(tile.id, level + 1)
				if price <= State.data.coins then
					table.insert(list, { id = tile.id, price = price })
				end
			end
		end
		if #list == 0 then
			Root.toast("Nothing affordable yet. Keep farming!", "info")
			return
		end
		table.sort(list, function(a, b)
			return a.price < b.price
		end)
		cycle = cycle % #list + 1
		focus(list[cycle].id)
	end)

	local buying = false
	buyButton.face.Activated:Connect(function()
		if buying or not buyButton.enabled() then
			return
		end
		buying = true
		local tileId = selected
		local response = Net.request("BuyTile", tileId)
		buying = false
		if not response.ok then
			Root.toastError(response.err)
			return
		end
		Sfx.play("buy", 1 + math.random() * 0.1)
		-- a little pop on the tile that was bought
		local view = views[tileId]
		local pop = view.root:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = view.root })
		pop.Scale = 1.25
		Kit.tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- Pan: drag on empty canvas. Zoom: mouse wheel or pinch.
	local dragging: InputObject? = nil
	local dragStart = Vector2.zero
	local panStart = Vector2.zero
	viewport.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = pan
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not root.Visible then
			return
		end
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or (input.UserInputType == Enum.UserInputType.Touch and input == dragging)
			)
		then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			-- the canvas lives inside the global UIScale, so convert screen pixels
			pan = panStart + delta / (Root.gui:FindFirstChildOfClass("UIScale") :: UIScale).Scale
			applyView()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom + input.Position.Z * 0.1, MIN_ZOOM, MAX_ZOOM)
			applyView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
	UserInputService.TouchPinch:Connect(
		function(_positions: { Vector2 }, scale: number, _velocity: number, inputState: Enum.UserInputState)
			if not root.Visible then
				return
			end
			if inputState == Enum.UserInputState.Begin then
				dragging = nil
			end
			zoom = math.clamp(zoom * (1 + (scale - 1) * 0.08), MIN_ZOOM, MAX_ZOOM)
			applyView()
		end
	)

	-- Phones get the sheet along the bottom so the tree keeps the full width.
	local function layout()
		if Root.isPhone() then
			sheet.Size = UDim2.new(1, -220, 0, 210)
			sheet.Position = UDim2.new(0, 110, 1, -222)
			legend.Visible = false
		else
			sheet.Size = UDim2.new(0, 340, 1, -96)
			sheet.Position = UDim2.new(1, -356, 0, 80)
			legend.Visible = true
		end
	end

	-- Gentle pulse on available tiles so the frontier is obvious.
	local t = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not root.Visible then
			return
		end
		t += dt
		local pulse = 0.5 + 0.5 * math.sin(t * 4)
		local p = progress()
		for id, view in views do
			if HexGraph.state(p, id) == "Available" then
				paint(view.border, Theme.color.white:Lerp(Theme.color.coin, pulse), 0)
			end
		end
	end)

	State.watch({ "coins", "hex", "keystones", "rebirths", "index" }, function()
		if root.Visible then
			refreshTiles()
		end
	end)

	handle.onOpen = function()
		layout()
		refreshTiles()
		local start = cheapestOpen(true) or cheapestOpen(false) or HexTree.coreId
		zoom = 1
		focus(start)
	end
end

return Upgrades
