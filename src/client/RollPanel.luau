--[[
	RollPanel: the BUY / REROLL panel that opens when you stand at one of your
	own egg roll stations. The server picks every offer; this only shows it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local RollPanel = {}

local currentBiome: string? = nil
local animating = false
local rollSerial = 0

local panel = Ui.Frame("RollPanel", Ui.Gui, Ui.Dark, 0.05)
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -16)
panel.Size = UDim2.fromOffset(560, 330)
panel.Visible = false
Ui.Corner(panel, 18)
local panelStroke = Ui.Stroke(panel, 4, Color3.new(1, 1, 1))

local title = Ui.Label("Title", panel, "Egg Station", Color3.new(1, 1, 1))
title.Position = UDim2.fromOffset(16, 8)
title.Size = UDim2.new(1, -32, 0, 30)

local eggIcon = Ui.Frame("EggIcon", panel, Color3.new(1, 1, 1))
eggIcon.Position = UDim2.fromOffset(20, 48)
eggIcon.Size = UDim2.fromOffset(84, 104)
Ui.Corner(eggIcon, 50)
local eggIconStroke = Ui.Stroke(eggIcon, 4)
local eggBand = Ui.Frame("Band", eggIcon, Color3.new(1, 1, 1))
eggBand.AnchorPoint = Vector2.new(0.5, 0.5)
eggBand.Position = UDim2.fromScale(0.5, 0.55)
eggBand.Size = UDim2.new(1, 0, 0, 12)

local eggName = Ui.Label("EggName", panel, "", Color3.new(1, 1, 1))
eggName.Position = UDim2.fromOffset(120, 46)
eggName.Size = UDim2.new(1, -136, 0, 38)
eggName.TextXAlignment = Enum.TextXAlignment.Left

local eggRarity = Ui.Label("EggRarity", panel, "", Color3.new(1, 1, 1))
eggRarity.Position = UDim2.fromOffset(120, 84)
eggRarity.Size = UDim2.new(1, -136, 0, 26)
eggRarity.TextXAlignment = Enum.TextXAlignment.Left

local eggPrice = Ui.Label("EggPrice", panel, "", Ui.Money)
eggPrice.Position = UDim2.fromOffset(120, 112)
eggPrice.Size = UDim2.new(1, -136, 0, 30)
eggPrice.TextXAlignment = Enum.TextXAlignment.Left

local odds = Ui.Scroll("Odds", panel)
odds.Position = UDim2.fromOffset(20, 160)
odds.Size = UDim2.new(1, -40, 0, 100)
Ui.List(odds, 2)

local buyButton = Ui.Button("Buy", panel, "BUY", Ui.Green, function()
	if currentBiome and not animating then
		Remotes.Get("Buy"):FireServer(currentBiome)
	end
end)
buyButton.Position = UDim2.new(0, 20, 1, -62)
buyButton.Size = UDim2.new(0.5, -30, 0, 50)

local rerollButton = Ui.Button("Reroll", panel, "REROLL", Ui.Blue, function()
	if currentBiome then
		Remotes.Get("Roll"):FireServer(currentBiome)
	end
end)
rerollButton.Position = UDim2.new(0.5, 10, 1, -62)
rerollButton.Size = UDim2.new(0.5, -30, 0, 50)

local function luck(): number
	return PetInfo.UpgradeValue(Store.State.upgrades, "Luck")
end

local function rarityOf(petId: string): string
	return PetConfig.Pets[petId].rarity
end

local function showEgg(eggId: string)
	local egg = PetConfig.EggsById[eggId]
	local rarityColor = Ui.RarityTextColor(egg.rarity)
	eggIcon.BackgroundColor3 = Ui.Rgb(egg.color)
	eggBand.BackgroundColor3 = Ui.Rgb(egg.accent)
	eggIconStroke.Color = rarityColor
	panelStroke.Color = rarityColor
	eggName.Text = egg.name
	eggName.TextColor3 = rarityColor
	eggRarity.Text = `{string.upper(egg.rarity)} EGG  •  hatches in {Format.Duration(
		egg.hatchTime * PetInfo.UpgradeValue(Store.State.upgrades, "HatchSpeed")
	)}`
	eggRarity.TextColor3 = rarityColor
	local affordable = Store.Cash() >= egg.price
	eggPrice.Text = Format.Cash(egg.price)
	eggPrice.TextColor3 = if affordable then Ui.Money else Ui.Red
	buyButton.BackgroundColor3 = if affordable then Ui.Green else Ui.Gray
end

local function showOdds(eggId: string)
	for _, child in odds:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local egg = PetConfig.EggsById[eggId]
	local chances = Rolls.Chances(Rolls.WithLuck(egg.pets, rarityOf, PetConfig.LuckyRarities, luck()))
	for index, chance in chances do
		local pet = PetConfig.Pets[chance.id]
		local discovered = Store.State.discovered[chance.id] == true
		local row = Ui.Label(`Row{index}`, odds, "", Ui.RarityTextColor(pet.rarity))
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -12, 0, 22)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text =
			`{if discovered then pet.name else "???"}  •  {pet.rarity}  •  {Rolls.OneIn(chance.chance)}  •  {Format.Cash(
				pet.income
			)}/s`
	end
end

local function render()
	if currentBiome == nil then
		panel.Visible = false
		return
	end
	local biome = PetConfig.BiomesById[currentBiome]
	title.Text = `{biome.name} Egg Station`
	panel.Visible = true
	if animating then
		return
	end
	local offer = Store.State.offers[currentBiome]
	if offer and PetConfig.EggsById[offer] then
		showEgg(offer)
		showOdds(offer)
		buyButton.Visible = true
	else
		eggName.Text = "Rolling..."
		eggRarity.Text = ""
		eggPrice.Text = ""
		buyButton.Visible = false
	end
end

-- Flicks through the biome's eggs, slowing down, then lands on the server's pick.
function RollPanel.PlayRoll(eggId: string, biomeId: string)
	if biomeId ~= currentBiome or PetConfig.EggsById[eggId] == nil then
		return
	end
	rollSerial += 1
	local serial = rollSerial
	animating = true
	buyButton.Visible = false
	local biome = PetConfig.BiomesById[biomeId]
	local started = os.clock()
	local gap = 0.04
	while os.clock() - started + gap < Economy.RollRevealDelay do
		if rollSerial ~= serial then
			return -- a newer roll took over the animation
		end
		showEgg(biome.eggIds[math.random(1, #biome.eggIds)])
		task.wait(gap)
		gap *= 1.25
	end
	if rollSerial ~= serial then
		return
	end
	animating = false
	render()
	Ui.Pop(eggIcon)
	Ui.Pop(eggName)
end

-- Which of the player's own unlocked stations they are standing at, if any.
local function nearbyStation(): string?
	local lane = Store.Lane()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if lane == nil or root == nil then
		return nil
	end
	local biomes = lane:FindFirstChild("Biomes")
	for _, biome in PetConfig.Biomes do
		if biome.index <= Store.State.unlocked then
			local folder = biomes and biomes:FindFirstChild(biome.id)
			local station = folder and folder:FindFirstChild("Station")
			if station and station:IsA("BasePart") then
				if (root.Position - station.Position).Magnitude <= Economy.StationDistance then
					return biome.id
				end
			end
		end
	end
	return nil
end

local lastCheck = 0
local lastAutoRoll = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastCheck < 0.2 then
		return
	end
	lastCheck = now
	local biomeId = nearbyStation()
	if biomeId ~= currentBiome then
		currentBiome = biomeId
		render()
	end
	-- No offer yet (first visit, or the last one was bought): ask for one.
	if currentBiome and Store.State.offers[currentBiome] == nil and not animating then
		if now - lastAutoRoll > Economy.RollCooldown + 0.3 then
			lastAutoRoll = now
			Remotes.Get("Roll"):FireServer(currentBiome)
		end
	end
end)

Store.Changed:Connect(render)
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: IntValue
	cash.Changed:Connect(render)
end)

return RollPanel
