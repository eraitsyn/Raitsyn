--[[
	Panels: the Eggs, Pets, Upgrades and Teleport windows. One is open at a
	time; each is rebuilt from Store whenever the server sends new state. Every
	button only asks the server, which checks it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Panels = {}

local openName: string? = nil

local window = Ui.Frame("Window", Ui.Gui, Ui.Dark, 0.03)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(660, 460)
window.Visible = false
window.ZIndex = 3
Ui.Corner(window, 18)
Ui.Stroke(window, 4, Color3.new(1, 1, 1))

local title = Ui.Label("Title", window, "", Color3.new(1, 1, 1))
title.Position = UDim2.fromOffset(20, 10)
title.Size = UDim2.new(1, -90, 0, 40)
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Ui.Button("Close", window, "X", Ui.Red, function()
	Panels.Toggle(openName or "")
end)
closeButton.Position = UDim2.new(1, -58, 0, 10)
closeButton.Size = UDim2.fromOffset(44, 44)

local subtitle = Ui.Label("Subtitle", window, "", Color3.fromRGB(210, 210, 230))
subtitle.Position = UDim2.fromOffset(20, 52)
subtitle.Size = UDim2.new(1, -200, 0, 24)
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local action = Ui.Button("Action", window, "", Ui.Green, function()
	if openName == "Pets" then
		Remotes.Get("EquipBest"):FireServer()
	end
end)
action.Position = UDim2.new(1, -176, 0, 50)
action.Size = UDim2.fromOffset(156, 34)

local content = Ui.Scroll("Content", window)
content.Position = UDim2.fromOffset(16, 92)
content.Size = UDim2.new(1, -32, 1, -108)

local function clear()
	for _, child in content:GetChildren() do
		if not child:IsA("UIScale") then
			child:Destroy()
		end
	end
end

local function row(name: string, order: number, height: number): Frame
	local frame = Ui.Frame(name, content, Ui.Panel)
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -12, 0, height)
	Ui.Corner(frame, 12)
	return frame
end

local function count(set: { [string]: any }): number
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

-- Eggs -----------------------------------------------------------------------------

local function buildEggs()
	local state = Store.State
	Ui.List(content, 8)
	local slots = PetInfo.UpgradeValue(state.upgrades, "HatchSlots")
	local storage = PetInfo.UpgradeValue(state.upgrades, "EggStorage")
	local eggTotal = 0
	for _, number in state.eggs do
		eggTotal += number
	end
	subtitle.Text = `Eggs {eggTotal}/{storage}  •  Hatch slots {count(state.hatching)}/{slots} in use`
	action.Visible = false

	local order = 0
	for _, egg in PetConfig.Eggs do
		local owned = state.eggs[egg.id]
		if owned and owned > 0 then
			order += 1
			local frame = row(egg.id, order, 64)
			local icon = Ui.Frame("Icon", frame, Ui.Rgb(egg.color))
			icon.Position = UDim2.fromOffset(10, 6)
			icon.Size = UDim2.fromOffset(42, 52)
			Ui.Corner(icon, 26)
			Ui.Stroke(icon, 3, Ui.RarityTextColor(egg.rarity))
			local name = Ui.Label("Name", frame, `{egg.name}  x{owned}`, Ui.RarityTextColor(egg.rarity))
			name.Position = UDim2.fromOffset(64, 6)
			name.Size = UDim2.new(1, -220, 0, 30)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local info = Ui.Label(
				"Info",
				frame,
				`{egg.rarity}  •  hatches in {Format.Duration(
					egg.hatchTime * PetInfo.UpgradeValue(state.upgrades, "HatchSpeed")
				)}`,
				Color3.fromRGB(210, 210, 230)
			)
			info.Position = UDim2.fromOffset(64, 36)
			info.Size = UDim2.new(1, -220, 0, 22)
			info.TextXAlignment = Enum.TextXAlignment.Left
			local place = Ui.Button("Place", frame, "Place", Ui.Green, function()
				Remotes.Get("PlaceEgg"):FireServer(egg.id)
			end)
			place.Position = UDim2.new(1, -140, 0, 10)
			place.Size = UDim2.fromOffset(126, 44)
			if count(state.hatching) >= slots then
				place.BackgroundColor3 = Ui.Gray
			end
		end
	end
	if order == 0 then
		local empty =
			Ui.Label("Empty", content, "No eggs yet. Buy one at an Egg Station!", Color3.fromRGB(210, 210, 230))
		empty.Size = UDim2.new(1, -12, 0, 30)
	end
end

-- Pets ----------------------------------------------------------------------------

local sellConfirm: string? = nil

local function buildPets()
	local state = Store.State
	local capacity = PetInfo.UpgradeValue(state.upgrades, "EquipSlots")
	subtitle.Text =
		`Pets {count(state.pets)}/{Economy.MaxPets}  •  Equipped {count(state.equipped)}/{capacity}  •  Click a pet to equip`
	action.Visible = true
	action.Text = "Equip Best"
	action.BackgroundColor3 = Ui.Green

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(142, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	local uids = {}
	for uid in state.pets do
		table.insert(uids, uid)
	end
	-- Equipped pets first, each group best earner first.
	local equippedList, rest = {}, {}
	for _, uid in PetInfo.SortByIncome(state.pets, uids) do
		table.insert(if state.equipped[uid] then equippedList else rest, uid)
	end
	table.move(rest, 1, #rest, #equippedList + 1, equippedList)

	for order, uid in equippedList do
		local owned = state.pets[uid]
		local pet = PetConfig.Pets[owned.pet]
		local mutation = owned.mutation and PetInfo.MutationsById[owned.mutation]
		local isEquipped = state.equipped[uid] == true
		local card = Instance.new("TextButton")
		card.Name = uid
		card.LayoutOrder = order
		card.Text = ""
		card.AutoButtonColor = true
		card.BackgroundColor3 = if isEquipped then Color3.fromRGB(40, 90, 60) else Ui.Panel
		card.Parent = content
		Ui.Corner(card, 14)
		Ui.Stroke(card, 3, Ui.RarityTextColor(pet.rarity))
		card.Activated:Connect(function()
			Remotes.Get(if isEquipped then "Unequip" else "Equip"):FireServer(uid)
		end)

		local icon = Ui.Frame("Icon", card, Ui.Rgb(if mutation then mutation.color else pet.color))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		icon.Size = UDim2.fromOffset(52, 44)
		Ui.Corner(icon, 12)
		local name = Ui.Label(
			"Name",
			card,
			PetInfo.Name(owned.pet, owned.mutation),
			if mutation then Ui.Rgb(mutation.color) else Color3.new(1, 1, 1)
		)
		name.Position = UDim2.fromOffset(6, 56)
		name.Size = UDim2.new(1, -12, 0, 24)
		local rarity = Ui.Label("Rarity", card, pet.rarity, Ui.RarityTextColor(pet.rarity))
		rarity.Position = UDim2.fromOffset(6, 80)
		rarity.Size = UDim2.new(1, -12, 0, 20)
		local income = Ui.Label("Income", card, `{Format.Cash(PetInfo.Income(owned.pet, owned.mutation))}/s`, Ui.Money)
		income.Position = UDim2.fromOffset(6, 100)
		income.Size = UDim2.new(1, -12, 0, 22)
		local sell = Ui.Button(
			"Sell",
			card,
			if sellConfirm == uid then "Sure?" else `Sell {Format.Cash(PetInfo.SellValue(owned.pet, owned.mutation))}`,
			Ui.Red,
			function()
				if sellConfirm == uid then
					sellConfirm = nil
					Remotes.Get("Sell"):FireServer(uid)
				else
					sellConfirm = uid
					Panels.Refresh()
					task.delay(3, function()
						if sellConfirm == uid then
							sellConfirm = nil
							Panels.Refresh()
						end
					end)
				end
			end
		)
		sell.Position = UDim2.new(0, 8, 1, -38)
		sell.Size = UDim2.new(1, -16, 0, 30)
		if isEquipped then
			local badge = Ui.Label("Equipped", card, "EQUIPPED", Ui.Green)
			badge.Position = UDim2.fromOffset(4, 2)
			badge.Size = UDim2.fromOffset(70, 14)
		end
	end
	if #equippedList == 0 then
		local empty = Ui.Label("Empty", content, "No pets yet. Hatch an egg!", Color3.fromRGB(210, 210, 230))
		empty.Size = UDim2.fromOffset(400, 30)
	end
end

-- Upgrades --------------------------------------------------------------------

local function valueText(definition: any, level: number): string
	local value = Upgrades.Value(definition, level)
	if definition.id == "Luck" then
		return Format.Multiplier(value)
	elseif definition.id == "HatchSpeed" then
		return `{math.floor((1 - value) * 100 + 0.5)}% faster`
	elseif definition.id == "AutoCollect" then
		return if value >= 1 then "On" else "Off"
	end
	return tostring(value)
end

local function buildUpgrades()
	local state = Store.State
	Ui.List(content, 8)
	subtitle.Text = `Cash: {Format.Cash(Store.Cash())}`
	action.Visible = false
	for order, definition in Economy.Upgrades do
		local level = state.upgrades[definition.id] or 0
		local cost = Upgrades.Cost(definition, level)
		local frame = row(definition.id, order, 64)
		local name =
			Ui.Label("Name", frame, `{definition.name}  (level {level}/{definition.maxLevel})`, Color3.new(1, 1, 1))
		name.Position = UDim2.fromOffset(14, 6)
		name.Size = UDim2.new(1, -220, 0, 28)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local now = valueText(definition, level)
		local nextText = if cost then `{now}  →  {valueText(definition, level + 1)}` else now
		local info = Ui.Label("Info", frame, `{definition.description}: {nextText}`, Color3.fromRGB(210, 210, 230))
		info.Position = UDim2.fromOffset(14, 36)
		info.Size = UDim2.new(1, -220, 0, 22)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local affordable = cost ~= nil and Store.Cash() >= cost
		local buy = Ui.Button(
			"Buy",
			frame,
			if cost then Format.Cash(cost) else "MAX",
			if affordable then Ui.Green else Ui.Gray,
			function()
				if cost then
					Remotes.Get("Upgrade"):FireServer(definition.id)
				end
			end
		)
		buy.Position = UDim2.new(1, -170, 0, 10)
		buy.Size = UDim2.fromOffset(156, 44)
	end
end

-- Teleport ----------------------------------------------------------------------

local function buildTeleport()
	local state = Store.State
	subtitle.Text = `{state.unlocked}/{#PetConfig.Biomes} biomes unlocked`
	action.Visible = false
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(190, 60)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	local base = Ui.Button("Base", content, "My Base", Ui.Gold, function()
		Remotes.Get("Teleport"):FireServer("Base")
		Panels.Toggle("Teleport")
	end)
	base.LayoutOrder = 0
	for _, biome in PetConfig.Biomes do
		local unlocked = biome.index <= state.unlocked
		local text = if unlocked then biome.name else `{biome.name} ({Format.Cash(biome.unlockCost)})`
		local button = Ui.Button(biome.id, content, text, if unlocked then Ui.Rgb(biome.accent) else Ui.Gray, function()
			if unlocked then
				Remotes.Get("Teleport"):FireServer(biome.id)
				Panels.Toggle("Teleport")
			end
		end)
		button.LayoutOrder = biome.index
	end
end

-- Opening and refreshing ---------------------------------------------------------

local BUILDERS = { Eggs = buildEggs, Pets = buildPets, Upgrades = buildUpgrades, Teleport = buildTeleport }

function Panels.Refresh()
	if openName == nil then
		return
	end
	local position = content.CanvasPosition
	clear()
	title.Text = openName
	BUILDERS[openName]()
	content.CanvasPosition = position
end

-- Opens the named window, or closes it when it is already open.
function Panels.Toggle(name: string)
	if openName == name or BUILDERS[name] == nil then
		openName = nil
		window.Visible = false
		return
	end
	openName = name
	window.Visible = true
	content.CanvasPosition = Vector2.zero
	Panels.Refresh()
	Ui.Pop(window)
end

Store.Changed:Connect(Panels.Refresh)
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: IntValue
	cash.Changed:Connect(function()
		if openName == "Upgrades" or openName == "Teleport" then
			Panels.Refresh()
		end
	end)
end)

-- The Upgrade Station in the base opens the Upgrades window.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("Kind") == "OpenUpgrades" and openName ~= "Upgrades" then
		Panels.Toggle("Upgrades")
	end
end)

return Panels
