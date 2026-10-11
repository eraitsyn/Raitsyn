--!strict
-- The roll panel (shown while standing at your Roll Station or on the
-- Plaza) and the reel reveal. Pressing ROLL starts the reel at once; the
-- server's answer arrives a moment later and the reel slows onto that
-- rarity. The odds table uses the same shared functions the server rolls
-- with, for the selected tier and the player's current luck.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Logic = Shared:WaitForChild("Logic")
local Costs = require(Logic:WaitForChild("Costs"))
local Economy = require(Config:WaitForChild("Economy"))
local Format = require(Logic:WaitForChild("Format"))
local Odds = require(Logic:WaitForChild("Odds"))
local Rarities = require(Config:WaitForChild("Rarities"))
local RollTiers = require(Config:WaitForChild("RollTiers"))
local Rules = require(Logic:WaitForChild("Rules"))

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local Kit = require(Client:WaitForChild("UI"):WaitForChild("Kit"))
local Root = require(Client:WaitForChild("UI"):WaitForChild("Root"))
local Theme = require(Client:WaitForChild("UI"):WaitForChild("Theme"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Sfx = require(Client:WaitForChild("Sfx"))

local Roll = {}

local TILE = 92 -- reel tile width in pixels
local selectedTier = "Basic"
local rolling = false
local autoOn = false

local function luckFor(tierId: string, lucky: boolean): number
	local tier = RollTiers.byId[tierId]
	return Odds.rollLuck(tier.luck, State.stats.luck, if lucky then State.stats.luckyRollMultiplier else 1)
end

local function chancesFor(tierId: string): { Odds.Chance }
	local lucky = State.stats.luckyRollMultiplier > 1 and (State.data.rollCount + 1) % Economy.luckyRollEvery == 0
	return Odds.chances(luckFor(tierId, lucky), State.stats.secretWeightMultiplier)
end

local function unlockText(tierId: string): string
	local tier = RollTiers.byId[tierId]
	local parts = {}
	if State.data.lifetimeCoins < tier.unlockLifetimeCoins then
		table.insert(parts, `earn {Format.coins(tier.unlockLifetimeCoins)} in total`)
	end
	if State.data.rebirths < tier.unlockRebirths then
		table.insert(parts, `reach Rebirth {tier.unlockRebirths}`)
	end
	return "To unlock: " .. table.concat(parts, " and ")
end

--------------------------------------------------------------------------------
-- Reel

local reel: Frame
local strip: Frame
local reelTiles: { Frame } = {}

local function makeTile(rarityId: string, index: number): Frame
	local colour = Theme.rarity(rarityId)
	local tile = Kit.new("Frame", {
		Name = `Tile{index}`,
		BackgroundColor3 = colour,
		Size = UDim2.fromOffset(TILE - 10, 92),
		Position = UDim2.fromOffset((index - 1) * TILE + 5, 9),
		Parent = strip,
	}, { Kit.corner(UDim.new(0, 12)), Kit.stroke(Theme.shade(colour, 0.4), 3) })
	Kit.label({
		Text = Theme.icon.egg,
		TextSize = 40,
		Size = UDim2.new(1, 0, 0.62, 0),
		Parent = tile,
	})
	Kit.label({
		Text = Rarities.byId[rarityId].name,
		FontFace = Theme.font.heading,
		TextSize = 14,
		TextColor3 = Theme.color.white,
		Size = UDim2.new(1, -4, 0.36, 0),
		Position = UDim2.new(0, 2, 0.62, 0),
		Parent = tile,
	}, true)
	return tile
end

local function buildReel()
	reel = Kit.new("Frame", {
		Name = "Reel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(TILE * 7, 110),
		BackgroundColor3 = Theme.color.panel,
		ClipsDescendants = true,
		Visible = false,
		Parent = Root.reveal,
	}, { Kit.corner(UDim.new(0, 16)), Kit.stroke() })
	strip = Kit.new("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(TILE * 60, 110),
		Parent = reel,
	})
	-- centre marker
	Kit.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Theme.color.coin,
		ZIndex = 3,
		Parent = reel,
	})
	for _, side in { 0, 1 } do
		Kit.new("Frame", {
			Name = "Pointer",
			AnchorPoint = Vector2.new(0.5, side),
			Position = UDim2.fromScale(0.5, side),
			Size = UDim2.fromOffset(18, 18),
			Rotation = 45,
			BackgroundColor3 = Theme.color.coin,
			ZIndex = 3,
			Parent = reel,
		}, { Kit.stroke(Theme.color.coinDark, 2) })
	end
end

local function randomRarity(chances: { Odds.Chance }): string
	return Odds.pickRarity(chances, math.random())
end

-- Starts the reel spinning before the result is known; returns a function
-- that lands it on the result (or hides it if the roll failed).
local function spinReel(tierId: string): (rarity: string?, lucky: boolean) -> ()
	for _, tile in reelTiles do
		tile:Destroy()
	end
	table.clear(reelTiles)
	local chances = chancesFor(tierId)
	for i = 1, 60 do
		reelTiles[i] = makeTile(randomRarity(chances), i)
	end
	strip.Position = UDim2.fromOffset(0, 0)
	reel.Visible = true

	local x = 0
	local spinning = true
	local lastTile = 0
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		if spinning then
			x -= dt * 1400
			if x < -TILE * 20 then
				x += TILE * 10 -- loop the early part of the strip while waiting
			end
			strip.Position = UDim2.fromOffset(x, 0)
		end
		-- a soft tick each time a tile passes the marker
		local tile = math.floor(-strip.Position.X.Offset / TILE)
		if tile ~= lastTile then
			lastTile = tile
			Sfx.play("tick", 0.9 + math.random() * 0.2)
		end
	end)

	return function(rarity: string?, lucky: boolean)
		spinning = false
		if rarity == nil then
			connection:Disconnect()
			reel.Visible = false
			return
		end
		local order = Fx.order(rarity)
		local landing = 45
		reelTiles[landing]:Destroy()
		reelTiles[landing] = makeTile(rarity, landing)
		-- near misses: the tiles right after the landing spot are often rarer
		local next = Rarities.list[math.min(#Rarities.list, order + 1)].id
		if math.random() < 0.5 then
			reelTiles[landing + 1]:Destroy()
			reelTiles[landing + 1] = makeTile(next, landing + 1)
		end
		-- put the landing tile's centre under the marker in the middle of the reel
		local target = -((landing - 1) * TILE + TILE / 2) + (TILE * 7) / 2
		local seconds = Fx.revealSeconds[order]
		Kit.tween(strip, seconds, { Position = UDim2.fromOffset(target, 0) }, Enum.EasingStyle.Quint)
		task.delay(seconds, function()
			connection:Disconnect()
			Fx.celebrate(rarity)
			local name = Rarities.byId[rarity].name
			Fx.title(
				if lucky then `LUCKY {string.upper(name)} EGG!` else `{string.upper(name)} EGG!`,
				Theme.rarity(rarity),
				if order >= 5 then 2 else 0.9,
				0.36
			)
			task.wait(if order >= 5 then 1.6 else 0.6)
			reel.Visible = false
		end)
	end
end

--------------------------------------------------------------------------------
-- Panel

function Roll.start()
	buildReel()

	local panel = Kit.new("Frame", {
		Name = "RollPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(600, 176),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = Root.context,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke() })

	-- Tier tabs
	local tabs = Kit.new("Frame", {
		Name = "Tiers",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.fromOffset(12, 10),
		Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local tabButtons: { [string]: Kit.Button } = {}
	local tierColours = {
		Basic = Theme.color.green,
		Silver = Color3.fromRGB(150, 170, 196),
		Gold = Color3.fromRGB(240, 180, 40),
		Diamond = Color3.fromRGB(80, 200, 240),
		Cosmic = Color3.fromRGB(150, 90, 240),
	}
	local refresh: () -> ()
	for i, tier in RollTiers.list do
		tabButtons[tier.id] = Kit.button({
			text = tier.id,
			colour = tierColours[tier.id],
			size = UDim2.fromOffset(110, 48),
			textSize = 18,
			layoutOrder = i,
			parent = tabs,
			onClick = function()
				if Rules.tierUnlocked(tier.id, State.data.lifetimeCoins, State.data.rebirths) then
					selectedTier = tier.id
					refresh()
				else
					Root.toast(unlockText(tier.id), "info")
				end
			end,
		})
	end

	local rollButton = Kit.button({
		text = "ROLL",
		colour = Theme.color.green,
		size = UDim2.fromOffset(250, 92),
		position = UDim2.fromOffset(12, 70),
		textSize = 30,
		parent = panel,
	})
	-- Cooldown overlay that shrinks as the next roll becomes available.
	local cooldown = Kit.new("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 3,
		Parent = rollButton.face,
	}, { Kit.corner() })

	local info = Kit.new("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(310, 92),
		Position = UDim2.fromOffset(276, 70),
		Parent = panel,
	})
	local eggText = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(170, 28),
		Parent = info,
	})
	local luckyText = Kit.label({
		FontFace = Theme.font.bold,
		TextSize = 18,
		TextColor3 = Theme.color.greenDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(170, 26),
		Position = UDim2.fromOffset(0, 30),
		Parent = info,
	})
	local luckText = Kit.label({
		FontFace = Theme.font.body,
		TextSize = 17,
		TextColor3 = Theme.color.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(170, 26),
		Position = UDim2.fromOffset(0, 58),
		Parent = info,
	})
	local oddsButton = Kit.button({
		text = "Odds",
		colour = Theme.color.blue,
		size = UDim2.fromOffset(124, 44),
		position = UDim2.fromOffset(186, 0),
		textSize = 20,
		parent = info,
	})
	local autoButton = Kit.button({
		text = "Auto: Off",
		colour = Theme.color.grey,
		size = UDim2.fromOffset(124, 44),
		position = UDim2.fromOffset(186, 48),
		textSize = 18,
		parent = info,
	})

	-- Odds table, above the panel
	local odds = Kit.new("Frame", {
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -198),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = Root.context,
	}, {
		Kit.corner(UDim.new(0, 16)),
		Kit.stroke(),
		Kit.padding(14, 10),
		Kit.list(Enum.FillDirection.Vertical, 4),
	})
	local oddsTitle = Kit.label({
		FontFace = Theme.font.heading,
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 0,
		Parent = odds,
	})
	local oddsRows: { [string]: { chance: TextLabel, oneIn: TextLabel } } = {}
	for i, rarity in Rarities.list do
		local row = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = i,
			Parent = odds,
		})
		Kit.new("Frame", {
			BackgroundColor3 = Theme.rarity(rarity.id),
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(0, 5),
			Parent = row,
		}, { Kit.corner(UDim.new(1, 0)) })
		Kit.label({
			Text = rarity.name,
			FontFace = Theme.font.bold,
			TextSize = 19,
			TextColor3 = Theme.rarity(rarity.id),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(130, 28),
			Position = UDim2.fromOffset(28, 0),
			Parent = row,
		})
		local chance = Kit.label({
			FontFace = Theme.font.bold,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(100, 28),
			Position = UDim2.fromOffset(160, 0),
			Parent = row,
		})
		local oneIn = Kit.label({
			FontFace = Theme.font.body,
			TextSize = 17,
			TextColor3 = Theme.color.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(120, 28),
			Position = UDim2.new(1, -120, 0, 0),
			Parent = row,
		})
		oddsRows[rarity.id] = { chance = chance, oneIn = oneIn }
	end

	oddsButton.face.Activated:Connect(function()
		odds.Visible = not odds.Visible
	end)

	refresh = function()
		local stats = State.stats
		for _, tier in RollTiers.list do
			local unlocked = Rules.tierUnlocked(tier.id, State.data.lifetimeCoins, State.data.rebirths)
			local button = tabButtons[tier.id]
			button.setEnabled(unlocked)
			button.setText(if unlocked then tier.id else `{Theme.icon.lock} {tier.id}`)
			button.root.Size = if tier.id == selectedTier then UDim2.fromOffset(110, 50) else UDim2.fromOffset(110, 44)
			button.label.TextColor3 = if tier.id == selectedTier
				then Theme.color.white
				else Color3.fromRGB(240, 240, 240)
		end
		local price = Costs.rollPrice(selectedTier, stats.eggDiscount)
		rollButton.setText(`ROLL  {Format.coins(price)}`)
		rollButton.setEnabled(State.data.coins >= price and State.eggTotal() < stats.eggCapacity)
		eggText.Text = `{Theme.icon.egg} Eggs {State.eggTotal()}/{stats.eggCapacity}`
		if stats.luckyRollMultiplier > 1 then
			local left = Economy.luckyRollEvery - (State.data.rollCount % Economy.luckyRollEvery)
			luckyText.Text = if left == 1
				then `{Theme.icon.luck} Next roll is LUCKY (x{stats.luckyRollMultiplier})`
				else `{Theme.icon.luck} Lucky roll in {left}`
		else
			luckyText.Text = ""
		end
		luckText.Text = string.format("Luck x%.2f", luckFor(selectedTier, false))
		autoButton.root.Visible = stats.autoRoll > 0
		if stats.autoRoll <= 0 then
			autoOn = false
		end
		autoButton.setText(if autoOn then "Auto: On" else "Auto: Off")
		autoButton.setColour(if autoOn then Theme.color.green else Theme.color.grey)

		oddsTitle.Text = `{RollTiers.byId[selectedTier].name} odds`
		for _, entry in chancesFor(selectedTier) do
			local row = oddsRows[entry.rarity]
			row.chance.Text = Format.percent(entry.chance)
			row.oneIn.Text = `1 in {Format.commas(Odds.oneIn(entry.chance))}`
		end
	end

	local function doRoll(auto: boolean)
		if rolling then
			return
		end
		local stats = State.stats
		local price = Costs.rollPrice(selectedTier, stats.eggDiscount)
		if State.data.coins < price then
			if not auto then
				Root.toast(`Need {Format.coins(price - State.data.coins)} more`, "error")
			end
			return
		end
		if State.eggTotal() >= stats.eggCapacity then
			if not auto then
				Root.toast("Egg storage full: hatch some eggs first", "error")
			end
			return
		end
		if State.now() < State.nextRollAt - 0.1 then
			return
		end
		rolling = true
		local land = spinReel(selectedTier)
		local response = Net.request("Roll", selectedTier)
		if response.ok then
			local result = response.data
			State.nextRollAt = result.nextRollAt
			land(result.rarity, result.lucky)
			task.wait(Fx.revealSeconds[Fx.order(result.rarity)] + 0.2)
		else
			land(nil, false)
			Root.toastError(response.err)
			if auto then
				autoOn = false
				refresh()
			end
		end
		rolling = false
	end

	rollButton.face.Activated:Connect(function()
		task.spawn(doRoll, false)
	end)
	autoButton.face.Activated:Connect(function()
		autoOn = not autoOn
		refresh()
	end)

	State.watch({ "coins", "eggs", "rollCount", "lifetimeCoins", "rebirths", "@stats" }, refresh)

	-- Show the panel near a roll spot; drive the cooldown bar and Auto Roll.
	RunService.Heartbeat:Connect(function()
		local spot = App.rollSpot()
		local show = spot ~= nil and not Root.anyPanelOpen()
		panel.Visible = show
		if not show then
			odds.Visible = false
		end
		local remaining = State.nextRollAt - State.now()
		local fraction = if remaining > 0 then remaining / math.max(0.1, State.stats.rollCooldown) else 0
		cooldown.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if autoOn and show and not rolling and remaining <= 0 then
			task.spawn(doRoll, true)
		end
	end)
end

return Roll
