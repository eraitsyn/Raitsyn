--[[
	Hud: cash, income per second, the Collector total, the next goal, the menu
	buttons, toasts and the "+$" popups.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Store = require(script.Parent.Store)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Hud = {}

-- Set by Main: called with "Eggs", "Pets", "Upgrades" or "Teleport".
Hud.OnMenu = function(_name: string) end

-- Cash and income -------------------------------------------------------------

local stats = Ui.Frame("Stats", Ui.Gui, Ui.Dark, 0.15)
stats.Position = UDim2.fromOffset(16, 60)
stats.Size = UDim2.fromOffset(250, 112)
Ui.Corner(stats, 14)
Ui.Stroke(stats, 3)

local cashLabel = Ui.Label("Cash", stats, "$0", Ui.Money)
cashLabel.Position = UDim2.fromOffset(12, 6)
cashLabel.Size = UDim2.new(1, -24, 0, 46)
cashLabel.TextXAlignment = Enum.TextXAlignment.Left

local incomeLabel = Ui.Label("Income", stats, "$0/s", Color3.fromRGB(200, 255, 200))
incomeLabel.Position = UDim2.fromOffset(12, 52)
incomeLabel.Size = UDim2.new(1, -24, 0, 26)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

local collectorLabel = Ui.Label("Collector", stats, "Collector: $0", Color3.fromRGB(255, 240, 160))
collectorLabel.Position = UDim2.fromOffset(12, 80)
collectorLabel.Size = UDim2.new(1, -24, 0, 24)
collectorLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Next goal --------------------------------------------------------------------

local goal = Ui.Frame("Goal", Ui.Gui, Ui.Dark, 0.2)
goal.AnchorPoint = Vector2.new(0.5, 0)
goal.Position = UDim2.new(0.5, 0, 0, 12)
goal.Size = UDim2.fromOffset(520, 40)
Ui.Corner(goal, 12)
local goalLabel = Ui.Label("Text", goal, "", Color3.new(1, 1, 1))
goalLabel.Position = UDim2.fromOffset(12, 4)
goalLabel.Size = UDim2.new(1, -24, 1, -8)

-- Menu buttons ---------------------------------------------------------------

local menu = Ui.Frame("Menu", Ui.Gui, Ui.Dark, 1)
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 16, 0.5, 40)
menu.Size = UDim2.fromOffset(130, 4 * 58)
Ui.List(menu, 8)
for index, entry in
	{
		{ "Eggs", Color3.fromRGB(250, 170, 60) },
		{ "Pets", Ui.Blue },
		{ "Upgrades", Color3.fromRGB(170, 90, 240) },
		{ "Teleport", Color3.fromRGB(40, 180, 160) },
	}
do
	local button = Ui.Button(entry[1], menu, entry[1], entry[2], function()
		Hud.OnMenu(entry[1])
	end)
	button.LayoutOrder = index
	button.Size = UDim2.new(1, 0, 0, 50)
end

-- Toasts and popups ----------------------------------------------------------

local toast = Ui.Label("Toast", Ui.Gui, "", Color3.new(1, 1, 1))
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 60)
toast.Size = UDim2.fromOffset(560, 40)
toast.BackgroundColor3 = Ui.Dark
toast.BackgroundTransparency = 0.15
toast.Visible = false
toast.ZIndex = 5
Ui.Corner(toast, 10)

local toastSerial = 0
function Hud.Toast(text: string, color: Color3?)
	toastSerial += 1
	local serial = toastSerial
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.Visible = true
	Ui.Pop(toast)
	task.delay(3.5, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

function Hud.FloatCash(amount: number)
	local popup = Ui.Label("Gain", Ui.Gui, `+{Format.Cash(amount)}`, Ui.Money)
	popup.Position = UDim2.fromOffset(270, 60)
	popup.Size = UDim2.fromOffset(180, 40)
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(popup, info, { Position = UDim2.fromOffset(270, 10), TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		popup:Destroy()
	end)
end

-- Updating ---------------------------------------------------------------------

local function nextGoal(): string
	local state = Store.State
	local now = workspace:GetServerTimeNow()
	for _, incubation in state.hatching do
		if incubation.readyAt <= now then
			return "An egg is ready! Open it at your hatch slots."
		end
	end
	local eggCount = 0
	for _, count in state.eggs do
		eggCount += count
	end
	local slots = PetInfo.UpgradeValue(state.upgrades, "HatchSlots")
	local used = 0
	for _ in state.hatching do
		used += 1
	end
	if eggCount > 0 and used < slots then
		return "Place your egg in a hatch slot: open Eggs and press Place."
	end
	local hasPets = next(state.pets) ~= nil
	if not hasPets and used == 0 then
		return "Go to the Farm Egg Station and roll your first egg!"
	end
	local nextBiome = PetConfig.Biomes[state.unlocked + 1]
	if nextBiome then
		return `Next goal: unlock {nextBiome.name} ({Format.Cash(Store.Cash())} / {Format.Cash(nextBiome.unlockCost)})`
	end
	return "All biomes unlocked! Hunt for a Cosmic pet."
end

local function update()
	cashLabel.Text = Format.Cash(Store.Cash())
	incomeLabel.Text = `{Format.Cash(Store.State.income)}/s`
	local collector = player:GetAttribute("Collector")
	local autoCollect = PetInfo.UpgradeValue(Store.State.upgrades, "AutoCollect") >= 1
	collectorLabel.Text = if autoCollect
		then "Auto Collect on"
		else `Collector: {Format.Cash(if type(collector) == "number" then collector else 0)}`
	goalLabel.Text = nextGoal()
end

Store.Changed:Connect(update)
player:GetAttributeChangedSignal("Collector"):Connect(update)
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash") :: IntValue
	cash.Changed:Connect(function()
		update()
		Ui.Pop(cashLabel)
	end)
	update()
end)
task.spawn(function()
	while true do
		task.wait(1)
		goalLabel.Text = nextGoal()
	end
end)

return Hud
