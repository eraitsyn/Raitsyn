--[[
	Client entry point. The client only shows state; every action is a
	ProximityPrompt that the server checks. Hiding other players' prompts here
	is for clarity only.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local PetInfo = require(ReplicatedStorage.Shared.PetInfo)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local EGG_TAG = "IncubatingEgg"
local RAINBOW_TAG = "RainbowPart"

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local rarityColors: { [string]: Color3 } = {}
for _, rarity in PetConfig.Rarities do
	rarityColors[rarity.name] = rgb(rarity.color)
end

local function stringField(message: any, field: string): string?
	local value = message[field]
	return if type(value) == "string" then value else nil
end

local function numberField(message: any, field: string): number?
	local value = message[field]
	return if type(value) == "number" and value == value then value else nil
end

local function petName(id: string?, mutation: string?): string
	if id == nil or PetConfig.Pets[id] == nil then
		return "pet"
	end
	return PetInfo.Name(id, if mutation and PetInfo.MutationsById[mutation] then mutation else nil)
end

local function duration(seconds: number): string
	if seconds >= 3600 then
		return `{math.floor(seconds / 3600)}h {math.floor(seconds % 3600 / 60)}m`
	elseif seconds >= 60 then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	return `{seconds}s`
end

-- Toast text for each message kind; nil means no toast.
local MESSAGES: { [string]: (message: any) -> string? } = {
	BoughtEgg = function(message)
		local egg = PetInfo.EggsById[stringField(message, "id") or ""]
		return `{if egg then egg.name else "Egg"} is in your incubator!`
	end,
	NotReady = function()
		return "This egg is not ready yet."
	end,
	ServerHatch = function(message)
		local id = stringField(message, "id")
		local pet = id and PetConfig.Pets[id]
		local name = petName(id, stringField(message, "mutation"))
		return `{stringField(message, "by") or "Someone"} hatched a {if pet then pet.rarity .. " " else ""}{name}!`
	end,
	Sold = function(message)
		return `Sold {petName(stringField(message, "id"), stringField(message, "mutation"))}.`
	end,
	TooPoor = function()
		return "Not enough cash."
	end,
	IncubatorsFull = function()
		return "Your incubators are full. Hatch an egg first."
	end,
	PedestalsFull = function()
		return "Your pedestals are full. Sell a pet to make room."
	end,
	LuckUp = function()
		return "Luck upgraded!"
	end,
	OfflineEarned = function(message)
		local amount = numberField(message, "amount") or 0
		local seconds = numberField(message, "seconds") or 0
		return `While you were away ({duration(seconds)}) your pets made {Format.Cash(amount)}! Collect it on the green buttons.`
	end,
}

-- HUD --------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "EggHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function stroke(parent: Instance, thickness: number)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = thickness
	uiStroke.Color = Color3.new(0, 0, 0)
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Parent = parent
end

local function label(name: string, parent: Instance): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextScaled = true
	textLabel.Parent = parent
	return textLabel
end

local toast = label("Toast", gui)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 70)
toast.Size = UDim2.fromOffset(520, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.2
toast.Font = Enum.Font.GothamBold
toast.Visible = false
corner(toast, UDim.new(0, 10))

local cashFrame = Instance.new("Frame")
cashFrame.Name = "Cash"
cashFrame.AnchorPoint = Vector2.new(0, 0.5)
cashFrame.Position = UDim2.new(0, 16, 0.5, 0)
cashFrame.Size = UDim2.fromOffset(220, 56)
cashFrame.BackgroundColor3 = Color3.fromRGB(30, 140, 50)
cashFrame.Parent = gui
corner(cashFrame, UDim.new(0, 12))
stroke(cashFrame, 3)
local cashLabel = label("Amount", cashFrame)
cashLabel.Size = UDim2.new(1, -16, 1, -10)
cashLabel.Position = UDim2.fromOffset(8, 5)
cashLabel.Text = "$0"
stroke(cashLabel, 2)

local luckLabel = label("Luck", gui)
luckLabel.AnchorPoint = Vector2.new(0, 0.5)
luckLabel.Position = UDim2.new(0, 16, 0.5, 64)
luckLabel.Size = UDim2.fromOffset(160, 40)
luckLabel.BackgroundTransparency = 0
luckLabel.BackgroundColor3 = Color3.fromRGB(60, 120, 230)
luckLabel.Text = "Luck: x1"
corner(luckLabel, UDim.new(0, 10))
stroke(luckLabel, 2)

gui.Parent = player:WaitForChild("PlayerGui")

local toastSerial = 0
local function showToast(text: string)
	toastSerial += 1
	local serial = toastSerial
	toast.Text = text
	toast.Visible = true
	task.delay(4, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

-- A "+$1.2K" that floats up from the cash display.
local function floatCash(amount: number)
	local popup = label("Gain", gui)
	popup.AnchorPoint = Vector2.new(0, 0.5)
	popup.Position = UDim2.new(0, 240, 0.5, 0)
	popup.Size = UDim2.fromOffset(160, 36)
	popup.TextColor3 = Color3.fromRGB(120, 255, 120)
	popup.Text = `+{Format.Cash(amount)}`
	stroke(popup, 2)
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(popup, info, { Position = UDim2.new(0, 240, 0.5, -50), TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		popup:Destroy()
	end)
end

-- Cash comes from leaderstats, which the server keeps in sync with saved data.
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash") :: IntValue
	local function update()
		cashLabel.Text = Format.Cash(cash.Value)
	end
	cash.Changed:Connect(update)
	update()
end)

local function updateLuck()
	local luck = player:GetAttribute("Luck")
	luckLabel.Text = `Luck: {Luck.Text(if type(luck) == "number" then luck else 1)}`
end
player:GetAttributeChangedSignal("Luck"):Connect(updateLuck)
updateLuck()

-- Hatch animation ----------------------------------------------------------

local overlay = Instance.new("Frame")
overlay.Name = "Hatch"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Visible = false
overlay.ZIndex = 10
overlay.Parent = gui

local eggFrame = Instance.new("Frame")
eggFrame.Name = "Egg"
eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
eggFrame.Position = UDim2.fromScale(0.5, 0.45)
eggFrame.Size = UDim2.fromOffset(160, 200)
eggFrame.ZIndex = 11
eggFrame.Parent = overlay
corner(eggFrame, UDim.new(0.5, 0))
stroke(eggFrame, 4)

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 12
flash.Parent = overlay

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.45)
card.Size = UDim2.fromOffset(420, 220)
card.BackgroundTransparency = 1
card.ZIndex = 13
card.Visible = false
card.Parent = overlay

local cardLines: { TextLabel } = {}
for index, height in { 70, 40, 34, 34 } do
	local line = label(`Line{index}`, card)
	line.ZIndex = 13
	line.Size = UDim2.new(1, 0, 0, height)
	line.LayoutOrder = index
	stroke(line, 3)
	cardLines[index] = line
end
local cardLayout = Instance.new("UIListLayout")
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardLayout.Padding = UDim.new(0, 6)
cardLayout.Parent = card

local hatchQueue: { any } = {}
local hatchRunning = false

local function playHatch(message: any)
	local id = stringField(message, "id")
	local pet = id and PetConfig.Pets[id]
	if pet == nil then
		return
	end
	local mutationId = stringField(message, "mutation")
	local mutation = mutationId and PetInfo.MutationsById[mutationId]
	local egg = PetInfo.EggsById[stringField(message, "egg") or ""]
	local rarityColor = rarityColors[pet.rarity]

	overlay.Visible = true
	card.Visible = false
	eggFrame.Visible = true
	eggFrame.Rotation = 0
	eggFrame.Size = UDim2.fromOffset(160, 200)
	eggFrame.BackgroundColor3 = if egg then rgb(egg.color) else Color3.new(1, 1, 1)
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()

	-- Wobble harder and faster, then grow just before it cracks.
	for step = 1, 14 do
		local angle = 6 + step * 1.6
		eggFrame.Rotation = if step % 2 == 0 then angle else -angle
		task.wait(0.14 - step * 0.006)
	end
	eggFrame.Rotation = 0
	TweenService:Create(eggFrame, TweenInfo.new(0.2), { Size = UDim2.fromOffset(200, 250) }):Play()
	task.wait(0.2)

	flash.BackgroundTransparency = 0
	eggFrame.Visible = false
	cardLines[1].Text = PetInfo.Name(id, if mutation then mutationId else nil)
	cardLines[1].TextColor3 = if mutation then rgb(mutation.color) else Color3.new(1, 1, 1)
	cardLines[2].Text = string.upper(pet.rarity)
	cardLines[2].TextColor3 = rarityColor
	cardLines[3].Text = `{stringField(message, "odds") or ""}{if mutation
		then `  •  {mutation.name} x{mutation.multiplier}!`
		else ""}`
	cardLines[4].Text = `{Format.Cash(PetInfo.Income(id, if mutation then mutationId else nil))}/s`
	cardLines[4].TextColor3 = Color3.fromRGB(120, 255, 120)
	card.Visible = true
	card.Size = UDim2.fromOffset(210, 110)
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 220) }):Play()

	task.wait(2.6)
	card.Visible = false
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	task.wait(0.25)
	overlay.Visible = false
end

local function queueHatch(message: any)
	table.insert(hatchQueue, message)
	if hatchRunning then
		return
	end
	hatchRunning = true
	task.spawn(function()
		while #hatchQueue > 0 do
			local ok, err = pcall(playHatch, table.remove(hatchQueue, 1))
			if not ok then
				warn(`[Hatch] {err}`)
				overlay.Visible = false
			end
		end
		hatchRunning = false
	end)
end

-- Messages from the server ---------------------------------------------------

Remotes.Get("Notify").OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.kind) ~= "string" then
		return
	end
	if message.kind == "Hatched" then
		queueHatch(message)
		return
	end
	if message.kind == "Collected" or message.kind == "Sold" then
		local amount = numberField(message, "amount")
		if amount and amount > 0 then
			floatCash(amount)
		end
	end
	local format = MESSAGES[message.kind]
	local text = format and format(message)
	if text then
		showToast(text)
	end
end)

-- Egg countdowns and rainbow pets -------------------------------------------

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, shell in CollectionService:GetTagged(EGG_TAG) do
		local readyAt = shell:GetAttribute("ReadyAt")
		local tag = shell:FindFirstChild("EggTag")
		local line = tag and tag:FindFirstChild("Line2")
		if type(readyAt) == "number" and line and line:IsA("TextLabel") then
			local remaining = math.ceil(readyAt - now)
			line.Text = if remaining > 0 then duration(remaining) else "Ready to hatch!"
		end
	end

	local hue = (os.clock() * 0.25) % 1
	for _, part in CollectionService:GetTagged(RAINBOW_TAG) do
		if part:IsA("BasePart") then
			part.Color = Color3.fromHSV(hue, 0.8, 1)
		end
	end
end)

-- Prompts: only show your own base's prompts ----------------------------

local function filterPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("OwnerUserId") ~= nil then
		if prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			prompt.Enabled = false
		end
	end
end

workspace.DescendantAdded:Connect(filterPrompt)
for _, descendant in workspace:GetDescendants() do
	filterPrompt(descendant)
end
